import 'dart:math';

import 'package:serverpod/serverpod.dart';

import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../e2e/e2e_codes.dart';
import 'user_service.dart';

/// The email/password identity provider (specs/04 §1): Serverpod Cloud
/// email delivery (codes logged in development), 6-digit codes, E2E code
/// capture and the sign-up hook creating the user profile and preferences.
EmailIdpConfig wonkyEmailIdpConfig() {
  final cloud = ServerpodCloudEmailIdpConfig(appDisplayName: 'Wonky Work');
  final random = Random.secure();
  String sixDigits() =>
      List.generate(6, (_) => random.nextInt(10).toString()).join();
  return EmailIdpConfigFromPasswords(
    registrationVerificationCodeGenerator: sixDigits,
    passwordResetVerificationCodeGenerator: sixDigits,
    sendRegistrationVerificationCode:
        (
          session, {
          required email,
          required accountRequestId,
          required verificationCode,
          required transaction,
        }) {
          E2eCodes.recordRegistration(email, verificationCode);
          return cloud.sendRegistrationVerificationCode?.call(
            session,
            email: email,
            accountRequestId: accountRequestId,
            verificationCode: verificationCode,
            transaction: transaction,
          );
        },
    sendPasswordResetVerificationCode:
        (
          session, {
          required email,
          required passwordResetRequestId,
          required verificationCode,
          required transaction,
        }) {
          E2eCodes.recordPasswordReset(email, verificationCode);
          return cloud.sendPasswordResetVerificationCode?.call(
            session,
            email: email,
            passwordResetRequestId: passwordResetRequestId,
            verificationCode: verificationCode,
            transaction: transaction,
          );
        },
    onPasswordResetCompleted: cloud.onPasswordResetCompleted,
    onAfterAccountCreated: _afterAccountCreated,
  );
}

Future<void> _afterAccountCreated(
  Session session, {
  required String email,
  required UuidValue authUserId,
  required UuidValue emailAccountId,
  required Transaction? transaction,
}) async {
  await UserService.ensureProfile(
    session,
    authUserId,
    email: email,
    transaction: transaction,
  );
}
