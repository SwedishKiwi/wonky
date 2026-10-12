import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shad/shad.dart';

import '../../l10n/wonky_app_localizations.dart';
import '../../shell/shell_services.dart';
import '../auth_controller.dart';
import '../password_strength.dart';
import 'auth_layout.dart';

/// `/signup` (suite 04 §1.1): name, email, password with strength meter,
/// terms; then `/signup/verify`.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key, required this.services});

  final ShellServices services;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final _name = TextEditingController(
    text: widget.services.auth.signUpDraft?.displayName ?? '',
  );
  late final _email = TextEditingController(
    text: widget.services.auth.signUpDraft?.email ?? '',
  );
  final _password = TextEditingController();
  bool _terms = false;
  bool _busy = false;
  String? _nameError, _emailError, _passwordError, _termsError, _formError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = WonkyAppLocalizations.of(context);
    final strength = passwordStrength(
      _password.text,
      context: [_email.text, _name.text],
    );
    setState(() {
      _nameError = _name.text.trim().isEmpty ? l.errorRequired : null;
      _emailError = validateEmail(l, _email.text);
      _passwordError = _password.text.length < 8
          ? l.authErrorPasswordShort
          : strength == PasswordStrength.weak
          ? l.authErrorPasswordWeak
          : null;
      _termsError = _terms ? null : l.authErrorTerms;
      _formError = null;
    });
    if ([
      _nameError,
      _emailError,
      _passwordError,
      _termsError,
    ].any((e) => e != null)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.services.auth.startSignUp(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) context.go('/signup/verify');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _formError = authErrorText(l, e.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return AuthLayout(
      services: widget.services,
      title: l.authSignUpTitle,
      subtitle: l.authSignUpSubtitle,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(l.authHaveAccount),
          ShadButton.link(
            onPressed: () => context.go('/signin'),
            child: Text(l.authSignIn),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 14,
          children: [
            if (_formError != null) AuthErrorBanner(message: _formError!),
            AuthField(
              label: l.authDisplayName,
              controller: _name,
              error: _nameError,
              autofocus: true,
              fieldKey: 'auth.signUp.name',
              autofillHints: const [AutofillHints.name],
              onSubmitted: (_) => _submit(),
            ),
            AuthField(
              label: l.authEmail,
              controller: _email,
              error: _emailError,
              fieldKey: 'auth.signUp.email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _submit(),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                PasswordField(
                  label: l.authPassword,
                  controller: _password,
                  error: _passwordError,
                  newPassword: true,
                  fieldKey: 'auth.signUp.password',
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                PasswordStrengthMeter(
                  strength: passwordStrength(
                    _password.text,
                    context: [_email.text, _name.text],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShadCheckbox(
                  key: const ValueKey<String>('auth.signUp.terms'),
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v),
                  label: Text(l.authTerms),
                ),
                if (_termsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _termsError!,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.destructive,
                      ),
                    ),
                  ),
              ],
            ),
            ShadButton(
              key: const ValueKey<String>('auth.signUp.submit'),
              enabled: !_busy,
              onPressed: _submit,
              leading: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: ShadSpinner(size: 16),
                    )
                  : null,
              child: Text(l.authCreateAccount),
            ),
          ],
        ),
      ),
    );
  }
}
