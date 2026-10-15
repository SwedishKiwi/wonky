import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../auth_controller.dart';
import 'auth_layout.dart';

/// `/signin` (suite 04 §1.2).
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.services,
    this.embedded = false,
    this.onSignedIn,
    this.initialEmail,
  });

  final ShellServices services;

  /// Inside the session-expired dialog (no layout, no links).
  final bool embedded;
  final VoidCallback? onSignedIn;
  final String? initialEmail;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final _email = TextEditingController(text: widget.initialEmail ?? '');
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _busy = false;
  bool _remember = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = WonkyAppLocalizations.of(context);
    setState(() {
      _emailError = validateEmail(l, _email.text);
      _passwordError = _password.text.isEmpty ? l.errorRequired : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;
    setState(() => _busy = true);
    try {
      await widget.services.auth.signIn(_email.text, _password.text);
      widget.onSignedIn?.call();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _formError = authErrorText(l, e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final form = AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 14,
        children: [
          if (_formError != null) AuthErrorBanner(message: _formError!),
          if (widget.services.auth.offersGoogleSignIn) ...[
            GoogleSignInButton(
              services: widget.services,
              onSignedIn: widget.onSignedIn,
              onError: (e) {
                if (mounted) setState(() => _formError = e);
              },
            ),
            AuthDivider(label: l.authOr),
          ],
          AuthField(
            label: l.authEmail,
            controller: _email,
            error: _emailError,
            autofocus: widget.initialEmail == null,
            fieldKey: 'auth.signIn.email',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            onSubmitted: (_) => _submit(),
          ),
          PasswordField(
            label: l.authPassword,
            controller: _password,
            error: _passwordError,
            autofocus: widget.initialEmail != null,
            fieldKey: 'auth.signIn.password',
            onSubmitted: (_) => _submit(),
          ),
          if (!widget.embedded)
            Row(
              children: [
                Expanded(
                  child: ShadCheckbox(
                    value: _remember,
                    onChanged: (v) => setState(() => _remember = v),
                    label: Text(l.authRememberMe),
                  ),
                ),
                ShadButton.link(
                  key: const ValueKey<String>('auth.signIn.forgot'),
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      context.go(authPathWithNext(widget.services, '/reset')),
                  child: Text(l.authForgotPassword),
                ),
              ],
            ),
          ShadButton(
            key: const ValueKey<String>('auth.signIn.submit'),
            enabled: !_busy,
            onPressed: _submit,
            leading: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: ShadSpinner(size: 16),
                  )
                : null,
            child: Text(l.authSignIn),
          ),
        ],
      ),
    );
    if (widget.embedded) return form;
    return AuthLayout(
      services: widget.services,
      title: l.authSignInTitle,
      subtitle: l.authSignInSubtitle,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(l.authNoAccount),
          ShadButton.link(
            key: const ValueKey<String>('auth.signIn.createAccount'),
            onPressed: () =>
                context.go(authPathWithNext(widget.services, '/signup')),
            child: Text(l.authCreateAccount),
          ),
        ],
      ),
      child: form,
    );
  }
}
