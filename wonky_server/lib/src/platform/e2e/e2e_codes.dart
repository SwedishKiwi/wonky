import 'package:serverpod/serverpod.dart';

/// Verification codes recorded for E2E tests (specs/15 §9). Only codes of
/// `@example.test` addresses are kept, and only in development/test.
abstract final class E2eCodes {
  static const testDomain = '@example.test';
  static final Map<String, String> _registration = {};
  static final Map<String, String> _passwordReset = {};

  static bool get enabled {
    try {
      final mode = Serverpod.instance.runMode;
      return mode == ServerpodRunMode.development ||
          mode == ServerpodRunMode.test;
    } catch (_) {
      return false;
    }
  }

  static bool isTestAddress(String email) =>
      email.trim().toLowerCase().endsWith(testDomain);

  static void recordRegistration(String email, String code) {
    if (enabled && isTestAddress(email)) {
      _registration[email.trim().toLowerCase()] = code;
    }
  }

  static void recordPasswordReset(String email, String code) {
    if (enabled && isTestAddress(email)) {
      _passwordReset[email.trim().toLowerCase()] = code;
    }
  }

  static String? registration(String email) =>
      _registration[email.trim().toLowerCase()];

  static String? passwordReset(String email) =>
      _passwordReset[email.trim().toLowerCase()];
}
