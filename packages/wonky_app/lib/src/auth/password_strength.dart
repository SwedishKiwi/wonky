/// Password strength levels shown by the sign-up meter (suite 04 §1.1).
enum PasswordStrength { empty, weak, fair, good, strong }

/// Estimates password strength from length and character variety, penalizing
/// common passwords and repeated characters. Purely advisory: the server's
/// IDP password policy is authoritative.
PasswordStrength passwordStrength(
  String password, {
  List<String> context = const [],
}) {
  if (password.isEmpty) return PasswordStrength.empty;
  final lower = password.toLowerCase();
  const common = {
    'password',
    'password1',
    '12345678',
    '123456789',
    'qwerty123',
    'qwertyuiop',
    'iloveyou',
    'letmein1',
    'welcome1',
    'abc12345',
    '11111111',
    'sunshine',
  };
  if (common.contains(lower) || password.length < 8) {
    return PasswordStrength.weak;
  }
  for (final c in context) {
    final part = c.toLowerCase().split('@').first;
    if (part.length >= 4 && lower.contains(part)) return PasswordStrength.weak;
  }
  var classes = 0;
  if (RegExp('[a-z]').hasMatch(password)) classes++;
  if (RegExp('[A-Z]').hasMatch(password)) classes++;
  if (RegExp('[0-9]').hasMatch(password)) classes++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) classes++;
  final unique = password.split('').toSet().length;
  if (unique <= 3) return PasswordStrength.weak;
  var score = 0;
  if (password.length >= 10) score++;
  if (password.length >= 14) score++;
  if (password.length >= 18) score++;
  score += classes - 1;
  if (score <= 1) return PasswordStrength.fair;
  if (score <= 3) return PasswordStrength.good;
  return PasswordStrength.strong;
}
