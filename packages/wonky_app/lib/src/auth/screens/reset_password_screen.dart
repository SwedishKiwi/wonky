import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../auth_controller.dart';
import '../password_strength.dart';
import 'auth_layout.dart';
import 'verify_email_screen.dart';

/// `/reset` (suite 04 §1.3): email → code → new password + confirm →
/// signed in.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.services});

  final ShellServices services;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = GlobalKey<CodeEntryState>();
  bool _busy = false;
  String? _error, _emailError, _passwordError, _confirmError;

  AuthController get auth => widget.services.auth;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() f) async {
    final l = WonkyAppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await f();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = authErrorText(l, e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final draft = auth.resetDraft;
    late final Widget body;
    late final String subtitle;
    if (draft == null) {
      subtitle = l.authResetSubtitle;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          if (_error != null) AuthErrorBanner(message: _error!),
          AuthField(
            label: l.authEmail,
            controller: _email,
            error: _emailError,
            autofocus: true,
            fieldKey: 'auth.reset.email',
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => _start(),
          ),
          ShadButton(
            key: const ValueKey<String>('auth.reset.send'),
            enabled: !_busy,
            onPressed: _start,
            child: Text(l.authSendCode),
          ),
        ],
      );
    } else if (draft.token == null) {
      subtitle = l.authVerifySubtitle(draft.email);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) AuthErrorBanner(message: _error!),
          CodeEntry(
            key: _code,
            fieldKey: 'auth.reset.code',
            sentAt: draft.codeSentAt,
            busy: _busy,
            onComplete: (c) =>
                _guard(() => auth.verifyResetCode(c.replaceAll(' ', ''))),
            onResend: () => _guard(() => auth.startReset(draft.email)),
          ),
          const SizedBox(height: 14),
          ShadButton(
            key: const ValueKey<String>('auth.reset.verify'),
            enabled: !_busy,
            onPressed: () => _guard(
              () => auth.verifyResetCode(
                (_code.currentState?.code ?? '').replaceAll(' ', ''),
              ),
            ),
            child: Text(l.authVerify),
          ),
        ],
      );
    } else {
      subtitle = l.authNewPasswordSubtitle;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          if (_error != null) AuthErrorBanner(message: _error!),
          PasswordField(
            label: l.authNewPassword,
            controller: _password,
            error: _passwordError,
            newPassword: true,
            autofocus: true,
            fieldKey: 'auth.reset.password',
            onChanged: (_) => setState(() {}),
          ),
          PasswordStrengthMeter(
            strength: passwordStrength(_password.text, context: [draft.email]),
          ),
          PasswordField(
            label: l.authConfirmPassword,
            controller: _confirm,
            error: _confirmError,
            newPassword: true,
            fieldKey: 'auth.reset.confirm',
            onSubmitted: (_) => _finish(),
          ),
          ShadButton(
            key: const ValueKey<String>('auth.reset.finish'),
            enabled: !_busy,
            onPressed: _finish,
            child: Text(l.authSetPassword),
          ),
        ],
      );
    }
    return AuthLayout(
      services: widget.services,
      title: l.authResetTitle,
      subtitle: subtitle,
      footer: ShadButton.link(
        onPressed: () {
          auth.cancelReset();
          context.go(authPathWithNext(widget.services, '/signin'));
        },
        child: Text(l.authBackToSignIn),
      ),
      child: body,
    );
  }

  void _start() {
    final l = WonkyAppLocalizations.of(context);
    setState(() => _emailError = validateEmail(l, _email.text));
    if (_emailError != null) return;
    _guard(() => auth.startReset(_email.text));
  }

  void _finish() {
    final l = WonkyAppLocalizations.of(context);
    setState(() {
      _passwordError = _password.text.length < 8
          ? l.authErrorPasswordShort
          : null;
      _confirmError = _confirm.text != _password.text
          ? l.authErrorPasswordMismatch
          : null;
    });
    if (_passwordError != null || _confirmError != null) return;
    _guard(() => auth.finishReset(_password.text));
  }
}
