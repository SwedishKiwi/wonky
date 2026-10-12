import 'package:serverpod/serverpod.dart';

import '../common/errors.dart';
import 'e2e_codes.dart';

/// Test support for E2E journeys (specs/15 §9, 13 §1): the latest
/// verification codes of `@example.test` addresses. Refuses every call
/// outside the development and test run modes.
class E2eSupportEndpoint extends Endpoint {
  void _check(Session session, String email) {
    final mode = session.serverpod.runMode;
    if (mode != ServerpodRunMode.development && mode != ServerpodRunMode.test) {
      throw Errors.unavailable('Not available in this environment.');
    }
    if (!E2eCodes.isTestAddress(email)) {
      throw Errors.forbidden('Only ${E2eCodes.testDomain} addresses.');
    }
  }

  Future<String?> latestVerificationCode(Session session, String email) async {
    _check(session, email);
    return E2eCodes.registration(email);
  }

  Future<String?> latestPasswordResetCode(Session session, String email) async {
    _check(session, email);
    return E2eCodes.passwordReset(email);
  }
}
