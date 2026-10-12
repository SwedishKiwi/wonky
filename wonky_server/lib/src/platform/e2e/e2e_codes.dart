/// Verification codes recorded for E2E tests (specs/15 §9). Only codes of
/// `@example.test` addresses are kept; the endpoint serves them only in
/// development/test.
abstract final class E2eCodes {
  static const testDomain = '@example.test';
  static final Map<String, String> _registration = {};
  static final Map<String, String> _passwordReset = {};

  static bool isTestAddress(String email) =>
      email.trim().toLowerCase().endsWith(testDomain);

  static void recordRegistration(String email, String code) {
    if (isTestAddress(email)) {
      _registration[email.trim().toLowerCase()] = code;
    }
  }

  static void recordPasswordReset(String email, String code) {
    if (isTestAddress(email)) {
      _passwordReset[email.trim().toLowerCase()] = code;
    }
  }

  static String? registration(String email) =>
      _registration[email.trim().toLowerCase()];

  static String? passwordReset(String email) =>
      _passwordReset[email.trim().toLowerCase()];
}
