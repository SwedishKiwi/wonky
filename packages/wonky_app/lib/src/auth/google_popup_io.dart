/// Google sign-in runs in a popup on web only (suite 04 §1.6).
Future<String?> awaitGooglePopup(
  Uri url, {
  required bool Function(String href) accepts,
}) => throw UnsupportedError('Sign in with Google is web-only');

void cancelGooglePopup() {}
