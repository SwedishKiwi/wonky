import 'package:serverpod_auth_idp_server/providers/google.dart';

/// Sign in with Google (specs/04 §1.6): `login` (native ID token) and
/// `loginWithCode` (web OAuth2 PKCE code, redirect `/auth/callback`).
/// Answers only when the `googleClientSecret` password is configured.
class GoogleIdpEndpoint extends GoogleIdpBaseEndpoint {}
