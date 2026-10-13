import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/auth/google_web_flow.dart';
import 'package:wonky_app/wonky_app.dart';

void main() {
  const config = GoogleSignInConfig(
    clientId: 'id.apps.googleusercontent.com',
    redirectUri: 'https://wonky.work/auth/callback',
  );

  group('Given a Google auth request', () {
    final request = GoogleAuthRequest.create(config, random: Random(1));

    test('when building the URL then it asks for a code with PKCE', () {
      final params = request.url.queryParameters;

      expect(request.url.host, 'accounts.google.com');
      expect(params['client_id'], config.clientId);
      expect(params['redirect_uri'], 'https://wonky.work/auth/callback');
      expect(params['response_type'], 'code');
      expect(params['scope'], contains('openid'));
      expect(params['state'], request.state);
      expect(params['code_challenge_method'], 'S256');
      final challenge = base64UrlEncode(
        sha256.convert(ascii.encode(request.codeVerifier)).bytes,
      ).replaceAll('=', '');
      expect(params['code_challenge'], challenge);
      expect(request.codeVerifier.length, inInclusiveRange(43, 128));
    });

    test('when a callback carries another state then it is not ours', () {
      final ours =
          'https://wonky.work/auth/callback?code=c&state=${request.state}';
      final stale = 'https://wonky.work/auth/callback?code=c&state=other';

      expect(request.answeredBy(ours), isTrue);
      expect(request.answeredBy(stale), isFalse);
    });

    test('when reading the callback then the code, a decline or an error '
        'comes out', () {
      expect(GoogleAuthRequest.codeOf('https://x/cb?code=abc&state=s'), 'abc');
      expect(
        GoogleAuthRequest.codeOf('https://x/cb?error=access_denied&state=s'),
        isNull,
      );
      expect(
        () => GoogleAuthRequest.codeOf('https://x/cb?error=invalid_request'),
        throwsA(isA<GoogleAuthException>()),
      );
    });
  });
}
