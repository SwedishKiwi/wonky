import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// Resolves a host name (injectable for tests).
typedef HostLookup = Future<List<InternetAddress>> Function(String host);

/// SSRF-safe HTTP for `UrlFetchApp` (Sheets 09 §8.3), also usable for
/// image-by-URL.
///
/// Rules: https only (http when [allowHttp]); ports 443/80/8443; the host is
/// resolved **once** and every address must be public (no private,
/// loopback, link-local, CGNAT, multicast, unique-local, IPv4-mapped private
/// or metadata addresses); the connection goes to the resolved address
/// (TLS SNI and certificate checks still use the host name), so DNS
/// rebinding cannot redirect it; redirects (max 5) are followed manually and
/// re-validated; request headers ≤ 16 KB, payload ≤ 10 MB, response ≤ 10 MB
/// (aborted beyond), timeout ≤ 60 s; cookies and auth tokens of the user are
/// never forwarded; an allowlist (project settings) restricts the hosts.
final class UrlFetchProxy {
  /// Creates a proxy.
  UrlFetchProxy({
    this.allowHttp = false,
    this.maxResponseBytes = 10 * 1024 * 1024,
    this.maxPayloadBytes = 10 * 1024 * 1024,
    this.maxHeaderBytes = 16 * 1024,
    this.maxRedirects = 5,
    this.userAgent = 'WonkySheets-Script/1.0 (+https://wonky.work/scripts-ua)',
    this.deniedHosts = const {},
    HostLookup? lookup,
    this.allowedAddressesForTests = const {},
    this.ports = const {443, 80, 8443},
  }) : _lookup = lookup ?? InternetAddress.lookup;

  /// Allowed ports (443/80/8443; tests add the port of a local server).
  final Set<int> ports;

  /// Whether plain http is allowed (`sheets.scriptAllowHttp`).
  final bool allowHttp;

  /// Response size limit.
  final int maxResponseBytes;

  /// Request body limit.
  final int maxPayloadBytes;

  /// Request header limit.
  final int maxHeaderBytes;

  /// Redirect hops.
  final int maxRedirects;

  /// `User-Agent` of every request.
  final String userAgent;

  /// Server-wide denylist (host patterns), including the server's own hosts.
  final Set<String> deniedHosts;

  /// Addresses tests may use (local test servers). Never set in production.
  final Set<String> allowedAddressesForTests;

  final HostLookup _lookup;

  static const _metadataHosts = {
    'metadata.google.internal',
    'metadata',
    'instance-data',
    'instance-data.ec2.internal',
  };
  static const _strippedHeaders = {
    'cookie',
    'cookie2',
    'host',
    'connection',
    'content-length',
    'transfer-encoding',
    'proxy-authorization',
    'te',
    'upgrade',
  };

  /// Whether [address] must not be reached from scripts.
  static bool isBlockedAddress(InternetAddress address) {
    final raw = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) return _blockedV4(raw);
    if (raw.length != 16) return true;
    // IPv4-mapped (::ffff:a.b.c.d) and IPv4-compatible (::a.b.c.d).
    final prefixZero = raw.sublist(0, 10).every((b) => b == 0);
    if (prefixZero && raw[10] == 0xff && raw[11] == 0xff) {
      return _blockedV4(raw.sublist(12));
    }
    if (prefixZero && raw[10] == 0 && raw[11] == 0) {
      return true; // ::, ::1 and deprecated IPv4-compatible addresses
    }
    final b0 = raw[0], b1 = raw[1];
    if (b0 == 0xff) return true; // multicast
    if (b0 & 0xfe == 0xfc) return true; // unique local fc00::/7 (fd00:ec2::254)
    if (b0 == 0xfe && b1 & 0xc0 == 0x80) return true; // link-local fe80::/10
    if (b0 == 0xfe && b1 & 0xc0 == 0xc0) return true; // site-local fec0::/10
    if (b0 == 0x20 && b1 == 0x02) {
      return _blockedV4(raw.sublist(2, 6)); // 6to4 2002::/16
    }
    if (b0 == 0x00 && b1 == 0x64 && raw[2] == 0xff && raw[3] == 0x9b) {
      return _blockedV4(raw.sublist(12)); // NAT64 64:ff9b::/96
    }
    if (b0 == 0x20 && b1 == 0x01 && raw[2] == 0x0d && raw[3] == 0xb8) {
      return true; // documentation 2001:db8::/32
    }
    return false;
  }

  static bool _blockedV4(List<int> b) {
    final a = b[0], c = b[1];
    if (a == 0 || a == 10 || a == 127) return true;
    if (a == 169 && c == 254) return true; // link-local, metadata
    if (a == 172 && c >= 16 && c <= 31) return true;
    if (a == 192 && c == 168) return true;
    if (a == 100 && c >= 64 && c <= 127) return true; // CGNAT
    if (a == 192 && c == 0 && b[2] == 0) return true; // IETF protocol
    if (a == 192 && c == 0 && b[2] == 2) return true; // documentation
    if (a == 198 && (c == 18 || c == 19)) return true; // benchmarking
    if (a == 198 && c == 51 && b[2] == 100) return true;
    if (a == 203 && c == 0 && b[2] == 113) return true;
    if (a >= 224) return true; // multicast, reserved, broadcast
    return false;
  }

  /// Whether [host] matches a pattern (`example.com`, `*.example.com`).
  static bool hostMatches(String host, String pattern) {
    final h = host.toLowerCase();
    final p = pattern.trim().toLowerCase();
    if (p.startsWith('*.')) {
      final suffix = p.substring(1);
      return h.endsWith(suffix) || h == p.substring(2);
    }
    return h == p;
  }

  Never _blocked(String message) =>
      throw FetchFailure('Blocked: $message', code: 'url_fetch');

  /// Validates [uri]; returns the pinned address to connect to.
  Future<InternetAddress> _validate(Uri uri, List<String> allowlist) async {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && !(allowHttp && scheme == 'http')) {
      _blocked('only https URLs can be fetched (${uri.scheme}).');
    }
    final host = uri.host.toLowerCase();
    if (host.isEmpty) _blocked('the URL has no host.');
    if (uri.userInfo.isNotEmpty) {
      _blocked('credentials in URLs are not allowed.');
    }
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    if (!ports.contains(port) || (scheme == 'https' && port == 80)) {
      _blocked('port $port is not allowed.');
    }
    if (_metadataHosts.contains(host) ||
        host == 'localhost' ||
        host.endsWith('.localhost') ||
        host.endsWith('.internal') ||
        host.endsWith('.local')) {
      _blocked('$host is not a public host.');
    }
    if (deniedHosts.any((p) => hostMatches(host, p))) {
      _blocked('$host is denied by the server.');
    }
    if (allowlist.isNotEmpty && !allowlist.any((p) => hostMatches(host, p))) {
      _blocked('$host is not in the script URL allowlist.');
    }
    if (RegExp(r'^[0-9a-fA-FxX.]+$').hasMatch(host) &&
        RegExp(r'^[0-9xX.]').hasMatch(host) &&
        !RegExp(
          r'^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$',
        ).hasMatch(host)) {
      // Octal, hexadecimal and integer IPv4 forms resolve differently in
      // different libraries.
      _blocked('ambiguous numeric host $host.');
    }
    final literal = InternetAddress.tryParse(
      host.startsWith('[') ? host.substring(1, host.length - 1) : host,
    );
    final List<InternetAddress> addresses;
    try {
      addresses = literal != null ? [literal] : await _lookup(host);
    } on SocketException {
      throw FetchFailure('Could not resolve $host.');
    }
    if (addresses.isEmpty) throw FetchFailure('Could not resolve $host.');
    for (final a in addresses) {
      if (allowedAddressesForTests.contains(a.address)) continue;
      if (isBlockedAddress(a)) {
        _blocked('$host resolves to a private or reserved address.');
      }
    }
    return addresses.first;
  }

  /// Fetches [request]. [allowlist] comes from the project settings;
  /// custom functions need a non-empty allowlist (09 §8.3 rule 8).
  Future<FetchResponseData> fetch(
    FetchRequestData request, {
    List<String> allowlist = const [],
    bool customFunction = false,
  }) async {
    if (customFunction && allowlist.isEmpty) {
      throw const FetchFailure(
        'Custom functions can only fetch hosts in the script URL allowlist.',
        code: 'url_fetch',
      );
    }
    final payload = request.payload == null
        ? null
        : Uint8List.fromList(utf8.encode(request.payload!));
    if (payload != null && payload.length > maxPayloadBytes) {
      throw const FetchFailure('The request payload is larger than 10 MB.');
    }
    final headerBytes = request.headers.entries.fold<int>(
      0,
      (n, e) => n + e.key.length + e.value.length + 4,
    );
    if (headerBytes > maxHeaderBytes) {
      throw const FetchFailure('The request headers are larger than 16 KB.');
    }
    final timeout = Duration(seconds: request.timeoutSeconds.clamp(1, 60));
    var uri = Uri.tryParse(request.url);
    if (uri == null) throw FetchFailure('Invalid URL: ${request.url}');
    var method = request.method.toUpperCase();
    var body = payload;
    for (var hop = 0; ; hop++) {
      final address = await _validate(uri!, allowlist);
      final client = HttpClient()
        ..userAgent = userAgent
        ..autoUncompress = true
        ..connectionTimeout = timeout
        ..findProxy = (_) => 'DIRECT';
      final pinned = address;
      client.connectionFactory = (url, proxyHost, proxyPort) {
        final port = url.hasPort
            ? url.port
            : (url.scheme == 'https' ? 443 : 80);
        if (url.scheme == 'https') {
          return SecureSocket.startConnect(pinned, port);
        }
        return Socket.startConnect(pinned, port);
      };
      try {
        final req = await client.openUrl(method, uri).timeout(timeout);
        req.followRedirects = false;
        req.persistentConnection = false;
        for (final e in request.headers.entries) {
          if (_strippedHeaders.contains(e.key.toLowerCase())) continue;
          req.headers.set(e.key, e.value);
        }
        if (request.contentType != null) {
          req.headers.set(HttpHeaders.contentTypeHeader, request.contentType!);
        }
        if (body != null) {
          req.contentLength = body.length;
          req.add(body);
        }
        final res = await req.close().timeout(timeout);
        if (res.isRedirect && request.followRedirects) {
          final location = res.headers.value(HttpHeaders.locationHeader);
          await res.drain<void>();
          if (location == null) {
            throw const FetchFailure('Redirect without a location.');
          }
          if (hop + 1 > maxRedirects) {
            throw FetchFailure('Too many redirects (more than $maxRedirects).');
          }
          uri = uri.resolve(location);
          if (res.statusCode == 303 ||
              ((res.statusCode == 301 || res.statusCode == 302) &&
                  method == 'POST')) {
            method = 'GET';
            body = null;
          }
          continue;
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in res.timeout(timeout)) {
          bytes.add(chunk);
          if (bytes.length > maxResponseBytes) {
            throw const FetchFailure('The response is larger than 10 MB.');
          }
        }
        final data = bytes.takeBytes();
        final headers = <String, String>{};
        res.headers.forEach((name, values) {
          if (name == 'set-cookie') return;
          headers[name] = values.join(', ');
        });
        return FetchResponseData(
          statusCode: res.statusCode,
          headers: headers,
          bytes: data,
          contentText: _decode(data, res.headers.contentType?.charset),
        );
      } on TimeoutException {
        throw FetchFailure(
          'The request timed out after ${timeout.inSeconds} s.',
        );
      } on SocketException catch (e) {
        throw FetchFailure('Connection failed: ${e.message}');
      } on HandshakeException catch (e) {
        throw FetchFailure('TLS handshake failed: ${e.message}');
      } on HttpException catch (e) {
        throw FetchFailure('HTTP error: ${e.message}');
      } finally {
        client.close(force: true);
      }
    }
  }

  static String _decode(Uint8List data, String? charset) {
    final cs = charset?.toLowerCase();
    if (cs == 'iso-8859-1' || cs == 'latin1' || cs == 'us-ascii') {
      return latin1.decode(data, allowInvalid: true);
    }
    return utf8.decode(data, allowMalformed: true);
  }
}
