import 'package:wonky_write_core/wonky_write_core.dart' show LinkPolicy;

/// Result of normalizing a link typed by the user (Write 04 §11.2).
sealed class LinkUrlResult {
  const LinkUrlResult();
}

class ValidLinkUrl extends LinkUrlResult {
  const ValidLinkUrl(this.url);
  final String url;
}

class InvalidLinkUrl extends LinkUrlResult {
  const InvalidLinkUrl(this.reason);

  /// User-facing reason ("This kind of link isn't allowed").
  final String reason;
}

/// Normalizes and validates link URLs (Write 04 §11.2): scheme allow-list,
/// missing schemes (`foo@bar.com` → `mailto:`, domains → `https://`,
/// `#slug` → this document's heading), own-host app URLs → `wonky://`,
/// max 2,048 characters.
class LinkUrlPolicy {
  const LinkUrlPolicy({this.documentUuid = '', this.appHosts = const {}});

  /// The current document (for `#slug` links).
  final String documentUuid;

  /// Hosts of this deployment (own-host URLs become internal links).
  final Set<String> appHosts;

  static const maxLength = 2048;
  static const allowedSchemes = {'http', 'https', 'mailto', 'tel', 'wonky'};
  static final _email = RegExp(r'^[^\s@/]+@[^\s@/]+\.[^\s@/]+$');
  static final _domain = RegExp(r'^([a-z0-9-]+\.)+[a-z]{2,}(:\d+)?([/?#].*)?$', caseSensitive: false);
  static final _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');
  static final _docPath = RegExp(r'^/(?:write/)?d/([0-9a-fA-F-]{36})/?$');
  static final _sheetPath = RegExp(r'^/(?:sheets/)?s/([0-9a-fA-F-]{36})/?$');

  LinkUrlResult normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return const InvalidLinkUrl('Enter a link');
    if (url.length > maxLength) return const InvalidLinkUrl('This link is too long');
    if (url.startsWith('#')) {
      if (documentUuid.isEmpty || url.length == 1) return const InvalidLinkUrl('Enter a heading');
      return ValidLinkUrl('wonky://doc/$documentUuid$url');
    }
    final scheme = _scheme.firstMatch(url)?.group(1)?.toLowerCase();
    if (scheme == null || (scheme.length > 1 && !url.contains('://') && !_isOpaqueScheme(scheme))) {
      if (_email.hasMatch(url)) {
        url = 'mailto:$url';
      } else if (_domain.hasMatch(url) || url.startsWith('localhost')) {
        url = 'https://$url';
      } else if (scheme == null) {
        return const InvalidLinkUrl("This doesn't look like a link");
      }
    }
    final finalScheme = _scheme.firstMatch(url)?.group(1)?.toLowerCase();
    if (finalScheme == null || !allowedSchemes.contains(finalScheme)) {
      return const InvalidLinkUrl("This kind of link isn't allowed");
    }

    final internal = _toInternal(url);
    if (internal != null) return ValidLinkUrl(internal);

    if (finalScheme == 'wonky') {
      return url.startsWith('wonky://doc/') || url.startsWith('wonky://sheet/')
          ? ValidLinkUrl(url)
          : const InvalidLinkUrl("This doesn't look like a link");
    }
    final normalized = LinkPolicy.normalizeLink(url);
    if (normalized == null) return const InvalidLinkUrl("This doesn't look like a link");
    return ValidLinkUrl(normalized);
  }

  static bool _isOpaqueScheme(String scheme) => scheme == 'mailto' || scheme == 'tel';

  String? _toInternal(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || !appHosts.contains(uri.host)) {
      return null;
    }
    final doc = _docPath.firstMatch(uri.path);
    if (doc != null) {
      final heading = uri.queryParameters['heading'];
      return 'wonky://doc/${doc.group(1)}${heading == null || heading.isEmpty ? '' : '#$heading'}';
    }
    final sheet = _sheetPath.firstMatch(uri.path);
    if (sheet != null) {
      return 'wonky://sheet/${sheet.group(1)}';
    }
    return null;
  }
}
