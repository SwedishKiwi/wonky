import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart';

import 'auth_repository.dart';

/// Where the session stands.
enum AuthStatus { signedOut, signedIn, sessionExpired }

/// Error codes surfaced by auth forms (mapped to localized messages).
enum AuthError {
  invalidCredentials,
  tooManyAttempts,
  invalidCode,
  expiredCode,
  passwordPolicy,
  network,
  unknown,
}

/// Exception carrying an [AuthError].
class AuthFailure implements Exception {
  const AuthFailure(this.error, [this.cause]);

  final AuthError error;
  final Object? cause;

  @override
  String toString() => 'AuthFailure($error, $cause)';

  static AuthFailure from(Object e) {
    if (e is AuthFailure) return e;
    if (e is EmailAccountLoginException) {
      return AuthFailure(switch (e.reason) {
        EmailAccountLoginExceptionReason.invalidCredentials => AuthError.invalidCredentials,
        EmailAccountLoginExceptionReason.tooManyAttempts => AuthError.tooManyAttempts,
        _ => AuthError.unknown,
      }, e);
    }
    if (e is EmailAccountRequestException) {
      return AuthFailure(switch (e.reason) {
        EmailAccountRequestExceptionReason.expired => AuthError.expiredCode,
        EmailAccountRequestExceptionReason.invalid => AuthError.invalidCode,
        EmailAccountRequestExceptionReason.policyViolation => AuthError.passwordPolicy,
        EmailAccountRequestExceptionReason.tooManyAttempts => AuthError.tooManyAttempts,
        _ => AuthError.unknown,
      }, e);
    }
    if (e is EmailAccountPasswordResetException) {
      return AuthFailure(switch (e.reason) {
        EmailAccountPasswordResetExceptionReason.expired => AuthError.expiredCode,
        EmailAccountPasswordResetExceptionReason.invalid => AuthError.invalidCode,
        EmailAccountPasswordResetExceptionReason.policyViolation => AuthError.passwordPolicy,
        EmailAccountPasswordResetExceptionReason.tooManyAttempts => AuthError.tooManyAttempts,
        _ => AuthError.unknown,
      }, e);
    }
    if (e is ServerpodClientNetworkException || e is TimeoutException) {
      return AuthFailure(AuthError.network, e);
    }
    return AuthFailure(AuthError.unknown, e);
  }
}

/// Drives the auth flows of suite 04 §1 and tracks session expiry (§1.5).
///
/// Sign-up collects name, email and password on the first screen, then
/// starts the email registration; the verify screen confirms the code and
/// finishes the registration with the remembered password (kept in memory
/// only). An unexpected loss of authentication while signed in becomes
/// [AuthStatus.sessionExpired], which the shell shows as a blocking dialog
/// over the current screen instead of navigating away.
class AuthController extends ChangeNotifier {
  AuthController(this.repository) {
    _status = repository.isSignedIn ? AuthStatus.signedIn : AuthStatus.signedOut;
    repository.addListener(_onAuthChanged);
  }

  final AuthRepository repository;

  AuthStatus _status = AuthStatus.signedOut;
  bool _expectSignOut = false;

  AuthStatus get status => _status;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// Called after sign-in/registration completes (profile bootstrap).
  Future<void> Function(SignUpDraft? draft)? onSignedIn;

  /// Called before sign-out clears local state.
  Future<void> Function()? onSigningOut;

  void _onAuthChanged() {
    final signedIn = repository.isSignedIn;
    if (signedIn) {
      if (_status != AuthStatus.signedIn) {
        _status = AuthStatus.signedIn;
        notifyListeners();
      }
      return;
    }
    if (_status == AuthStatus.signedIn) {
      _status = _expectSignOut ? AuthStatus.signedOut : AuthStatus.sessionExpired;
      _expectSignOut = false;
      notifyListeners();
    }
  }

  // ---- Sign in ----

  Future<void> signIn(String email, String password) async {
    try {
      await repository.signIn(email: email.trim(), password: password);
      _status = AuthStatus.signedIn;
      notifyListeners();
      await onSignedIn?.call(null);
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  // ---- Sign up ----

  SignUpDraft? _draft;
  SignUpDraft? get signUpDraft => _draft;

  Future<void> startSignUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final id = await repository.startRegistration(email.trim());
      _draft = SignUpDraft(
        displayName: displayName.trim(),
        email: email.trim(),
        password: password,
        requestId: id,
        codeSentAt: clock.now(),
      );
      notifyListeners();
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  /// Sends a new code (60 s cooldown enforced by the UI).
  Future<void> resendSignUpCode() async {
    final d = _draft ?? (throw const AuthFailure(AuthError.unknown));
    try {
      final id = await repository.startRegistration(d.email);
      _draft = d.copyWith(requestId: id, codeSentAt: clock.now());
      notifyListeners();
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  Future<void> verifySignUp(String code) async {
    final d = _draft ?? (throw const AuthFailure(AuthError.expiredCode));
    try {
      final token = await repository.verifyRegistrationCode(d.requestId, code.trim());
      await repository.finishRegistration(token, d.password);
      _status = AuthStatus.signedIn;
      final draft = d;
      _draft = null;
      notifyListeners();
      await onSignedIn?.call(draft);
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  void cancelSignUp() {
    _draft = null;
    notifyListeners();
  }

  // ---- Password reset ----

  ResetDraft? _reset;
  ResetDraft? get resetDraft => _reset;

  Future<void> startReset(String email) async {
    try {
      final id = await repository.startPasswordReset(email.trim());
      _reset = ResetDraft(email: email.trim(), requestId: id, codeSentAt: clock.now());
      notifyListeners();
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  Future<void> verifyResetCode(String code) async {
    final r = _reset ?? (throw const AuthFailure(AuthError.expiredCode));
    try {
      final token = await repository.verifyPasswordResetCode(r.requestId, code.trim());
      _reset = r.copyWith(token: token);
      notifyListeners();
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  Future<void> finishReset(String newPassword) async {
    final r = _reset;
    if (r?.token == null) throw const AuthFailure(AuthError.expiredCode);
    try {
      await repository.finishPasswordReset(
        token: r!.token!,
        newPassword: newPassword,
        email: r.email,
      );
      _reset = null;
      _status = AuthStatus.signedIn;
      notifyListeners();
      await onSignedIn?.call(null);
    } catch (e) {
      throw AuthFailure.from(e);
    }
  }

  void cancelReset() {
    _reset = null;
    notifyListeners();
  }

  // ---- Sign out / expiry ----

  Future<void> signOut() async {
    _expectSignOut = true;
    await onSigningOut?.call();
    try {
      await repository.signOut();
    } finally {
      _status = AuthStatus.signedOut;
      _expectSignOut = false;
      notifyListeners();
    }
  }

  /// The user chose "Sign in as someone else" in the session-expired dialog.
  void acknowledgeExpiry() {
    if (_status != AuthStatus.sessionExpired) return;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    repository.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// In-progress sign-up (memory only).
@immutable
class SignUpDraft {
  const SignUpDraft({
    required this.displayName,
    required this.email,
    required this.password,
    required this.requestId,
    required this.codeSentAt,
  });

  final String displayName;
  final String email;
  final String password;
  final UuidValue requestId;
  final DateTime codeSentAt;

  SignUpDraft copyWith({UuidValue? requestId, DateTime? codeSentAt}) => SignUpDraft(
    displayName: displayName,
    email: email,
    password: password,
    requestId: requestId ?? this.requestId,
    codeSentAt: codeSentAt ?? this.codeSentAt,
  );
}

/// In-progress password reset.
@immutable
class ResetDraft {
  const ResetDraft({
    required this.email,
    required this.requestId,
    required this.codeSentAt,
    this.token,
  });

  final String email;
  final UuidValue requestId;
  final DateTime codeSentAt;
  final String? token;

  ResetDraft copyWith({String? token}) =>
      ResetDraft(email: email, requestId: requestId, codeSentAt: codeSentAt, token: token ?? this.token);
}
