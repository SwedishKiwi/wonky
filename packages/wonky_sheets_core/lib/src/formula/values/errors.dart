/// Spreadsheet error kinds (05 §6.6).
enum ErrorKind {
  nullRef('#NULL!', 1),
  div0('#DIV/0!', 2),
  value('#VALUE!', 3),
  ref('#REF!', 4),
  name('#NAME?', 5),
  num('#NUM!', 6),
  na('#N/A', 7),
  parse('#ERROR!', 8),
  spill('#SPILL!', 9),
  calc('#CALC!', 14);

  const ErrorKind(this.literal, this.typeCode);

  /// The error literal as displayed (`#N/A`).
  final String literal;

  /// The `ERROR.TYPE` code.
  final int typeCode;

  static final Map<String, ErrorKind> _byLiteral = {
    for (final k in ErrorKind.values) k.literal: k,
  };

  /// Parses an error literal (case-insensitive), or null.
  static ErrorKind? fromLiteral(String text) => _byLiteral[text.toUpperCase()];

  /// All literals, longest first (for scanning).
  static final List<String> literalsLongestFirst = [
    for (final k in ErrorKind.values) k.literal,
  ]..sort((a, b) => b.length.compareTo(a.length));
}

/// English error messages (Sheets wording). Localized by the UI layer (P2).
abstract final class ErrorMessages {
  static String unknownFunction(String name) => "Unknown function: '$name'.";
  static String unknownRange(String name) => "Unknown range name: '$name'.";
  static String wrongArgCount(String fn, int min, int max, int got) {
    String args(int n) => n == 1 ? '1 argument' : '$n arguments';
    if (min == max) {
      return 'Wrong number of arguments to $fn. Expected ${args(min)}, but got ${args(got)}.';
    }
    if (max >= 255) {
      return 'Wrong number of arguments to $fn. Expected at least ${args(min)}, but got '
          '${args(got)}.';
    }
    return 'Wrong number of arguments to $fn. Expected between $min and $max arguments, but '
        'got ${args(got)}.';
  }

  static String expectsNumber(String fn, int param, String text) =>
      "Function $fn parameter $param expects number values. But '$text' is a text and cannot "
      'be coerced to a number.';
  static String expectsBoolean(String fn, int param, String text) =>
      "Function $fn parameter $param expects boolean values. But '$text' is a text and cannot "
      'be coerced to a boolean.';
  static String divByZero(String fn, int param) =>
      'Function $fn parameter $param cannot be zero.';
  static String divZeroEval(String fn) =>
      'Evaluation of function $fn caused a divide by zero error.';
  static const String referenceDoesNotExist = 'Reference does not exist.';
  static const String circular =
      'Circular dependency detected. To resolve with iterative calculation, see File > Settings.';
  static String unresolvedSheet(String name) =>
      "Unresolved sheet name '$name'.";
  static String outOfBounds(String a1) => 'Range $a1 is out of bounds.';
  static const String parseError = 'Formula parse error.';
  static String spillBlocked(String a1) =>
      'Array result was not expanded because it would overwrite data in $a1.';
  static String spillRows(int n) =>
      'Result was not automatically expanded, please insert more rows ($n).';
  static String spillColumns(int n) =>
      'Result was not automatically expanded, please insert more columns ($n).';
  static const String lambdaResult =
      'Formula result is a function; did you forget to call it?';
  static const String recursionLimit = 'Recursion limit exceeded';
  static const String arrayValueNotFound = 'An array value could not be found.';
  static String arraySizeMismatch(String fn) =>
      'Array arguments to $fn are of different size.';
  static String didNotFind(String value, String fn) =>
      "Did not find value '$value' in $fn evaluation.";
  static const String loading = 'Loading…';
  static const String offline = 'This function needs an internet connection.';
  static const String resultTooLarge = 'Result too large';
  static String textTooLong(String fn) =>
      'Text result of $fn is longer than the limit of 50000 characters.';
  static const String noMatchFilter =
      'No matches are found in FILTER evaluation.';
  static String notAvailableYet(String fn) =>
      "$fn isn't available in Wonky Sheets yet.";
  static String notAvailable(String fn) =>
      "$fn isn't available in Wonky Sheets.";
  static const String rangeOperatorRequiresRefs =
      'Range operator requires references';
  static const String argumentMustBeRange = 'Argument must be a range.';
  static const String tooDeep = 'Formula is too deeply nested';
}
