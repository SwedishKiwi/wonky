import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../bootstrap/app_urls.dart';

/// One "Continue with Google" attempt on web (suite 04 §1.6): Google's
/// authorization URL with PKCE (S256) and a random `state`.
///
/// Wonky runs the popup itself rather than through `flutter_web_auth_2`:
/// the apps are cross-origin isolated (COOP `same-origin`, suite 13 §3), so
/// the opener can't see the popup close and the plugin would wait out its
/// five-minute timeout, and a second attempt could take the first one's
/// result. Here a new attempt replaces the pending one in the same named
/// popup, and results are matched by `state`. The server side is
/// Serverpod's (`googleIdp.loginWithCode`, `/auth/callback`).
class GoogleAuthRequest {
  GoogleAuthRequest._({
    required this.url,
    required this.state,
    required this.codeVerifier,
    required this.redirectUri,
  });

  factory GoogleAuthRequest.create(
    GoogleSignInConfig config, {
    Random? random,
  }) {
    final r = random ?? Random.secure();
    String token(int bytes) => base64UrlEncode([
      for (var i = 0; i < bytes; i++) r.nextInt(256),
    ]).replaceAll('=', '');
    final verifier = token(48);
    final state = token(24);
    final challenge = base64UrlEncode(
      sha256.convert(ascii.encode(verifier)).bytes,
    ).replaceAll('=', '');
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'response_type': 'code',
      'scope': scopes.join(' '),
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'prompt': 'select_account',
      'access_type': 'online',
    });
    return GoogleAuthRequest._(
      url: url,
      state: state,
      codeVerifier: verifier,
      redirectUri: config.redirectUri,
    );
  }

  /// `openid` makes Google return the id token the server verifies.
  static const scopes = [
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];

  final Uri url;
  final String state;
  final String codeVerifier;
  final String redirectUri;

  /// Whether the callback URL [href] answers this request.
  bool answeredBy(String href) =>
      Uri.tryParse(href)?.queryParameters['state'] == state;

  /// The authorization code in the callback URL [href]: null when the user
  /// declined (`error=access_denied`); throws [GoogleAuthException] on other
  /// errors.
  static String? codeOf(String href) {
    final params = Uri.parse(href).queryParameters;
    final code = params['code'];
    if (code != null && code.isNotEmpty) return code;
    final error = params['error'];
    if (error == null || error == 'access_denied') return null;
    throw GoogleAuthException(error, params['error_description']);
  }
}

/// Google answered the authorization request with an error.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.error, [this.description]);

  final String error;
  final String? description;

  @override
  String toString() => 'GoogleAuthException($error, $description)';
}

/// The browser blocked the Google sign-in popup.
class GooglePopupBlockedException implements Exception {
  const GooglePopupBlockedException();
}
