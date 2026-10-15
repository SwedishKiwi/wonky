import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

/// What a [FileUrlTokens] token allows.
enum FileUrlPurpose {
  /// `GET /files/d/:fileUuid/:name` (Drive 02 §8).
  download,

  /// `PUT /files/upload/:fileUuid` (Drive 02 §3.3, suite 09 §4).
  upload,
}

/// A verified token.
class FileUrlGrant {
  const FileUrlGrant({
    required this.purpose,
    required this.fileUuid,
    required this.userId,
    required this.sizeBytes,
    required this.expiresAt,
  });

  final FileUrlPurpose purpose;
  final UuidValue fileUuid;

  /// The user the URL was issued to (UserProfile id).
  final int userId;

  /// Uploads: the declared size (bodies beyond it are refused).
  final int sizeBytes;
  final DateTime expiresAt;
}

/// Short-lived, user-bound URL tokens of the file routes (suite 13 §6):
/// `base64url(payload).base64url(HMAC-SHA256(key, payload))` with the
/// payload `v1|<purpose>|<fileUuid>|<userId>|<size>|<expiresAtMs>`.
///
/// The key is the `fileUrlSecret` password, or else derived from the JWT
/// signing key (shared by every instance), or else a random per-process key
/// (single instance; logged once).
abstract final class FileUrlTokens {
  static const lifetime = Duration(minutes: 15);

  /// Tests may set the key.
  static List<int>? keyOverride;

  static List<int>? _key;

  static List<int> get _secret {
    if (keyOverride != null) return keyOverride!;
    return _key ??= _loadKey();
  }

  static List<int> _loadKey() {
    String? secret;
    try {
      final pod = Serverpod.instance;
      secret =
          pod.getPassword('fileUrlSecret') ??
          pod.getPassword('jwtHmacSha512PrivateKey') ??
          pod.getPassword('serviceSecret');
    } on Object {
      secret = null;
    }
    if (secret != null && secret.isNotEmpty) {
      return Hmac(
        sha256,
        utf8.encode(secret),
      ).convert(utf8.encode('wonky.fileUrlTokens.v1')).bytes;
    }
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  static String issue({
    required FileUrlPurpose purpose,
    required UuidValue fileUuid,
    required int userId,
    int sizeBytes = 0,
    DateTime? expiresAt,
  }) {
    final exp = expiresAt ?? clock.now().toUtc().add(lifetime);
    final payload = utf8.encode(
      'v1|${purpose.name}|${fileUuid.uuid}|$userId|$sizeBytes|'
      '${exp.millisecondsSinceEpoch}',
    );
    final sig = Hmac(sha256, _secret).convert(payload).bytes;
    return '${_b64(payload)}.${_b64(sig)}';
  }

  /// The grant of [token] when it is authentic, unexpired, for [purpose]
  /// and [fileUuid]; else null.
  static FileUrlGrant? verify(
    String? token, {
    required FileUrlPurpose purpose,
    required UuidValue fileUuid,
  }) {
    if (token == null || token.length > 1024) return null;
    final dot = token.indexOf('.');
    if (dot <= 0) return null;
    final List<int> payload;
    final List<int> sig;
    try {
      payload = _unb64(token.substring(0, dot));
      sig = _unb64(token.substring(dot + 1));
    } on FormatException {
      return null;
    }
    final expected = Hmac(sha256, _secret).convert(payload).bytes;
    if (!_equal(sig, expected)) return null;
    final parts = utf8.decode(payload, allowMalformed: true).split('|');
    if (parts.length != 6 || parts[0] != 'v1') return null;
    if (parts[1] != purpose.name || parts[2] != fileUuid.uuid) return null;
    final userId = int.tryParse(parts[3]);
    final size = int.tryParse(parts[4]);
    final exp = int.tryParse(parts[5]);
    if (userId == null || size == null || exp == null) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp, isUtc: true);
    if (!expiresAt.isAfter(clock.now().toUtc())) return null;
    return FileUrlGrant(
      purpose: purpose,
      fileUuid: fileUuid,
      userId: userId,
      sizeBytes: size,
      expiresAt: expiresAt,
    );
  }

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64(String s) {
    final padded = s.padRight((s.length + 3) ~/ 4 * 4, '=');
    return base64Url.decode(padded);
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
