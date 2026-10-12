/// Syntax highlighting token kinds of the theme `syntax` palette (06 §2.5).
library;

/// A code token kind that a theme can color (06 §2.5).
///
/// The JSON key of each token is its [name] (e.g. `"keyword"`). Tokens the
/// theme does not list render in the `codeText` color.
enum SyntaxToken {
  /// Language keywords (`if`, `class`, `return`).
  keyword,

  /// String and character literals.
  string,

  /// Numeric literals.
  number,

  /// Comments and doc comments.
  comment,

  /// Function, method and section titles.
  function,

  /// Type and class names.
  type,

  /// Variables, parameters and template substitutions.
  variable,

  /// Operators.
  operator,

  /// Punctuation.
  punctuation,

  /// Built-in functions and objects.
  builtin,

  /// Literals such as `true`, `false`, `null`.
  literal,

  /// Meta information: preprocessor directives, annotations, shebangs.
  meta,

  /// Markup tags and tag names.
  tag,

  /// Markup and property attributes.
  attribute,

  /// Regular expression literals.
  regexp,

  /// Diff additions.
  addition,

  /// Diff deletions.
  deletion;

  /// The JSON key of this token in a theme `syntax` palette.
  String get jsonName => name;

  /// The token for JSON key [name], or `null` when unknown.
  static SyntaxToken? fromJsonName(String name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
