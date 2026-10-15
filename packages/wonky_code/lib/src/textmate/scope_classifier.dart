import '../syntax_token.dart';

/// Maps TextMate scopes to [SyntaxToken]s (Write 04 §15.4, moved from
/// Write's `CodeHighlighter.tokenForScopes`; Slides 07 §2.1).
abstract final class ScopeClassifier {
  static final Map<String, _Rule?> _ruleCache = {};

  /// The token class of a span with TextMate [scopes] (outermost first), or
  /// `null` for plain text.
  ///
  /// The innermost scope with a rule decides. Punctuation is weak: a strong
  /// enclosing scope (string, comment, tag) wins over it. Embedded code
  /// (`${…}` in template strings, f-string expressions, `<script>` in HTML)
  /// does not inherit the color of its enclosing string or tag.
  static SyntaxToken? tokenFor(List<String> scopes) {
    SyntaxToken? weak;
    for (var i = scopes.length - 1; i >= 0; i -= 1) {
      final scope = scopes[i];
      final rule = _ruleCache.putIfAbsent(scope, () => _ruleFor(scope));
      if (rule == null) continue;
      if (rule.token == null) return weak;
      if (rule.weak) {
        weak ??= rule.token;
        continue;
      }
      return rule.token;
    }
    return weak;
  }

  static _Rule? _ruleFor(String scope) {
    for (final rule in _rules) {
      if (scope == rule.prefix || scope.startsWith('${rule.prefix}.')) {
        return rule;
      }
    }
    return null;
  }

  /// Scope prefix → token, most specific first. A `null` token stops the
  /// search (embedded code); unmatched scopes (`source.*`, most `meta.*`,
  /// `invalid.*`) are skipped.
  static const _rules = <_Rule>[
    _Rule('meta.embedded', null),
    _Rule('meta.template.expression', null),
    _Rule('meta.fstring.expression', null),
    _Rule('string.interpolated.expression', SyntaxToken.variable),
    _Rule('string.template.expression', SyntaxToken.variable),
    _Rule('string.template.simple', SyntaxToken.variable),
    _Rule('string.regexp', SyntaxToken.regexp),
    _Rule('string', SyntaxToken.string),
    _Rule('comment', SyntaxToken.comment),
    _Rule('punctuation.definition.comment', SyntaxToken.comment),
    _Rule('punctuation.definition.string', SyntaxToken.string),
    _Rule('punctuation.definition.tag', SyntaxToken.tag),
    _Rule('punctuation.support.type.property-name', SyntaxToken.attribute),
    _Rule('punctuation', SyntaxToken.punctuation, weak: true),
    _Rule('constant.numeric', SyntaxToken.number),
    _Rule('constant', SyntaxToken.literal),
    _Rule('keyword.operator', SyntaxToken.operator),
    _Rule('keyword', SyntaxToken.keyword),
    _Rule('storage.type.annotation', SyntaxToken.meta),
    _Rule('storage.type.primitive', SyntaxToken.type),
    // Rust lifetimes (`'a`). Write's editor colored them with a `symbol`
    // class of its own, always the literal color of its default palettes.
    _Rule('storage.modifier.lifetime', SyntaxToken.literal),
    _Rule('storage', SyntaxToken.keyword),
    _Rule('entity.name.function', SyntaxToken.function),
    _Rule('entity.name.type', SyntaxToken.type),
    _Rule('entity.name.class', SyntaxToken.type),
    _Rule('entity.name.tag', SyntaxToken.tag),
    _Rule('entity.name.selector', SyntaxToken.tag),
    _Rule('entity.name.variable', SyntaxToken.variable),
    _Rule('entity.other.attribute-name', SyntaxToken.attribute),
    _Rule('entity', SyntaxToken.function),
    _Rule('support.function', SyntaxToken.builtin),
    _Rule('support.class', SyntaxToken.type),
    _Rule('support.type.property-name', SyntaxToken.attribute),
    _Rule('support.type', SyntaxToken.type),
    _Rule('support.constant', SyntaxToken.literal),
    _Rule('support', SyntaxToken.builtin),
    _Rule('variable.language', SyntaxToken.keyword),
    _Rule('variable', SyntaxToken.variable),
    _Rule('meta.preprocessor', SyntaxToken.meta),
    _Rule('meta.annotation', SyntaxToken.meta),
    _Rule('meta.attribute', SyntaxToken.meta),
    _Rule('markup.inserted', SyntaxToken.addition),
    _Rule('markup.deleted', SyntaxToken.deletion),
    _Rule('markup.heading', SyntaxToken.function),
  ];
}

class _Rule {
  const _Rule(this.prefix, this.token, {this.weak = false});

  final String prefix;
  final SyntaxToken? token;
  final bool weak;
}
