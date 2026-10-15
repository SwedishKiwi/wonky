import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Signs the GitHub App JWT (specs/16 §13.3): RS256, `iat` 60 s in the past
/// (clock drift), `exp` 9 minutes after now (GitHub allows at most 10), and
/// `iss` the App id. The key never leaves this object: [toString] does not
/// print it.
class GithubAppJwt {
  GithubAppJwt(this.appId, this._key);

  /// The key from a PEM (`-----BEGIN RSA PRIVATE KEY-----`, the format
  /// GitHub downloads, or PKCS#8). Literal `\n` sequences (a PEM pasted
  /// into a single-line secret) are turned into line breaks. Throws
  /// [FormatException] without echoing the key.
  factory GithubAppJwt.fromPem(int appId, String pem) {
    final text = normalizePem(pem);
    try {
      return GithubAppJwt(appId, RSAPrivateKey(text));
    } on Object {
      throw const FormatException(
        'githubAppPrivateKey is not a valid RSA private key (PEM).',
      );
    }
  }

  final int appId;
  final RSAPrivateKey _key;

  static const issuedAtSkew = Duration(seconds: 60);
  static const lifetime = Duration(minutes: 9);

  /// A PEM with real line breaks and no surrounding whitespace.
  static String normalizePem(String pem) =>
      pem.replaceAll(r'\n', '\n').replaceAll('\r\n', '\n').trim();

  /// The JWT for [now].
  String sign(DateTime now) {
    int seconds(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;
    final jwt = JWT({
      'iat': seconds(now.subtract(issuedAtSkew)),
      'exp': seconds(now.add(lifetime)),
      'iss': '$appId',
    });
    return jwt.sign(_key, algorithm: JWTAlgorithm.RS256, noIssueAt: true);
  }

  @override
  String toString() => 'GithubAppJwt(appId: $appId)';
}
