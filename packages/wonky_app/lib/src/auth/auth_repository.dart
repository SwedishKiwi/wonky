import 'package:flutter/foundation.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:wonky_client/wonky_client.dart';

/// Email/password authentication through Serverpod's email IDP (suite 04 §1).
abstract class AuthRepository implements Listenable {
  bool get isSignedIn;

  /// The Serverpod auth user id of the signed-in user.
  UuidValue? get authUserId;

  Future<void> signIn({required String email, required String password});

  /// Returns the account request id.
  Future<UuidValue> startRegistration(String email);

  /// Returns the registration token.
  Future<String> verifyRegistrationCode(UuidValue requestId, String code);

  /// Creates the account and signs in.
  Future<void> finishRegistration(String registrationToken, String password);

  Future<UuidValue> startPasswordReset(String email);

  Future<String> verifyPasswordResetCode(UuidValue requestId, String code);

  /// Sets the new password and signs in with it.
  Future<void> finishPasswordReset({
    required String token,
    required String newPassword,
    required String email,
  });

  /// Signs out (both apps share the session on web).
  Future<void> signOut({bool allDevices = false});
}

/// [AuthRepository] on the generated client (`emailIdp` + `client.auth`).
class ServerAuthRepository extends ChangeNotifier implements AuthRepository {
  ServerAuthRepository(this.client) {
    client.auth.authInfoListenable.addListener(notifyListeners);
  }

  final Client client;

  @override
  bool get isSignedIn => client.auth.isAuthenticated;

  @override
  UuidValue? get authUserId => client.auth.authInfo?.authUserId;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final success = await client.emailIdp.login(email: email, password: password);
    await client.auth.updateSignedInUser(success);
  }

  @override
  Future<UuidValue> startRegistration(String email) =>
      client.emailIdp.startRegistration(email: email);

  @override
  Future<String> verifyRegistrationCode(UuidValue requestId, String code) =>
      client.emailIdp.verifyRegistrationCode(
        accountRequestId: requestId,
        verificationCode: code,
      );

  @override
  Future<void> finishRegistration(String registrationToken, String password) async {
    final success = await client.emailIdp.finishRegistration(
      registrationToken: registrationToken,
      password: password,
    );
    await client.auth.updateSignedInUser(success);
  }

  @override
  Future<UuidValue> startPasswordReset(String email) =>
      client.emailIdp.startPasswordReset(email: email);

  @override
  Future<String> verifyPasswordResetCode(UuidValue requestId, String code) =>
      client.emailIdp.verifyPasswordResetCode(
        passwordResetRequestId: requestId,
        verificationCode: code,
      );

  @override
  Future<void> finishPasswordReset({
    required String token,
    required String newPassword,
    required String email,
  }) async {
    await client.emailIdp.finishPasswordReset(
      finishPasswordResetToken: token,
      newPassword: newPassword,
    );
    await signIn(email: email, password: newPassword);
  }

  @override
  Future<void> signOut({bool allDevices = false}) async {
    if (allDevices) {
      await client.auth.signOutAllDevices();
    } else {
      await client.auth.signOutDevice();
    }
  }

  @override
  void dispose() {
    client.auth.authInfoListenable.removeListener(notifyListeners);
    super.dispose();
  }
}
