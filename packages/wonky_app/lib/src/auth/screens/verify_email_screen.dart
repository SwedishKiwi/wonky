import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../auth_controller.dart';
import 'auth_layout.dart';

/// A 6-digit code input with a resend button and a 60 s cooldown.
class CodeEntry extends StatefulWidget {
  const CodeEntry({
    super.key,
    required this.onComplete,
    required this.onResend,
    required this.sentAt,
    this.busy = false,
    this.fieldKey = 'auth.code',
  });

  final ValueChanged<String> onComplete;
  final Future<void> Function() onResend;
  final DateTime sentAt;
  final bool busy;
  final String fieldKey;

  @override
  State<CodeEntry> createState() => CodeEntryState();
}

class CodeEntryState extends State<CodeEntry> {
  Timer? _tick;
  String _code = '';

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get code => _code;

  int get _remaining => (60 - clock.now().difference(widget.sentAt).inSeconds).clamp(0, 60);

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final remaining = _remaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShadInputOTP(
          key: ValueKey<String>(widget.fieldKey),
          maxLength: 6,
          keyboardType: TextInputType.number,
          onChanged: (v) {
            _code = v;
            if (v.replaceAll(' ', '').length == 6) widget.onComplete(v);
          },
          children: const [
            ShadInputOTPGroup(children: [ShadInputOTPSlot(), ShadInputOTPSlot(), ShadInputOTPSlot()]),
            Icon(LucideIcons.dot),
            ShadInputOTPGroup(children: [ShadInputOTPSlot(), ShadInputOTPSlot(), ShadInputOTPSlot()]),
          ],
        ),
        const SizedBox(height: 10),
        ShadButton.link(
          key: const ValueKey<String>('auth.code.resend'),
          enabled: remaining == 0 && !widget.busy,
          onPressed: () async {
            await widget.onResend();
            if (mounted) setState(() {});
          },
          child: Text(remaining == 0 ? l.authResendCode : l.authResendIn(remaining)),
        ),
      ],
    );
  }
}

/// `/signup/verify` (suite 04 §1.1 step 3).
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.services});

  final ShellServices services;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _key = GlobalKey<CodeEntryState>();
  bool _busy = false;
  String? _error;

  Future<void> _verify(String code) async {
    final l = WonkyAppLocalizations.of(context);
    final c = code.replaceAll(' ', '');
    if (c.length != 6) {
      setState(() => _error = l.authErrorCodeLength);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.services.auth.verifySignUp(c);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      if (e.error == AuthError.passwordPolicy) {
        widget.services.toasts.error(l.authErrorPasswordPolicy);
        context.go('/signup');
        return;
      }
      setState(() => _error = authErrorText(l, e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final draft = widget.services.auth.signUpDraft;
    if (draft == null) {
      return AuthLayout(
        services: widget.services,
        title: l.authVerifyTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.authVerifyNoDraft),
            const SizedBox(height: 12),
            ShadButton(onPressed: () => context.go('/signup'), child: Text(l.authBackToSignUp)),
          ],
        ),
      );
    }
    return AuthLayout(
      services: widget.services,
      title: l.authVerifyTitle,
      subtitle: l.authVerifySubtitle(draft.email),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) AuthErrorBanner(message: _error!),
          CodeEntry(
            key: _key,
            fieldKey: 'auth.verify.code',
            sentAt: draft.codeSentAt,
            busy: _busy,
            onComplete: _verify,
            onResend: () async {
              try {
                await widget.services.auth.resendSignUpCode();
                widget.services.toasts.show(l.authCodeResent);
              } on AuthFailure catch (e) {
                if (mounted) setState(() => _error = authErrorText(l, e.error));
              }
            },
          ),
          const SizedBox(height: 14),
          ShadButton(
            key: const ValueKey<String>('auth.verify.submit'),
            enabled: !_busy,
            onPressed: () => _verify(_key.currentState?.code ?? ''),
            leading: _busy ? const SizedBox.square(dimension: 16, child: ShadSpinner(size: 16)) : null,
            child: Text(l.authVerify),
          ),
          const SizedBox(height: 6),
          ShadButton.ghost(
            key: const ValueKey<String>('auth.verify.changeEmail'),
            onPressed: () => context.go('/signup'),
            child: Text(l.authChangeEmail),
          ),
        ],
      ),
    );
  }
}
