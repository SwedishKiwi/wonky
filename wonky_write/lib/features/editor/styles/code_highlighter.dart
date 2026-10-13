import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:syntax_highlight/syntax_highlight.dart';

/// Tokenizes code with the TextMate grammars of `syntax_highlight` (Write 04
/// §15.4) and maps their scopes to the theme's syntax token classes
/// (`keyword`, `string`, …; `EditorTheme.syntax`, Write 06 §2.5).
///
/// Grammars are loaded lazily from the package assets, once per grammar, the
/// first time a block needs them.
abstract final class CodeHighlighter {
  static final Map<String, Future<bool>> _loading = {};

  /// Whether [grammar] is loaded and [tokenize] can run synchronously.
  static bool isLoaded(String grammar) => Highlighter.isInitialized(grammar);

  /// Loads [grammar] from the `syntax_highlight` assets. Completes with
  /// `false` when it cannot be loaded (the block then stays plain).
  static Future<bool> load(String grammar) {
    if (isLoaded(grammar)) return SynchronousFuture(true);
    return _loading.putIfAbsent(grammar, () async {
      try {
        await Highlighter.initialize([grammar]);
        return true;
      } catch (e) {
        debugPrint('Loading the $grammar grammar failed: $e');
        return false;
      }
    });
  }

  /// Token spans `(start, end, tokenClass)` of [code] in the loaded
  /// [grammar]: sorted, disjoint, adjacent spans of one class merged. Empty
  /// when the grammar is not loaded or fails on [code].
  static List<(int, int, String)> tokenize(String code, String grammar) {
    if (!isLoaded(grammar) || code.isEmpty) return const [];
    try {
      final spans = <(int, int, String)>[];
      for (final span in Highlighter.parseScopes(grammar, code)) {
        final token = tokenForScopes(span.scopes);
        if (token == null || span.end <= span.start) continue;
        final start = span.start.clamp(0, code.length);
        final end = span.end.clamp(0, code.length);
        if (end <= start) continue;
        if (spans.isNotEmpty) {
          final (lastStart, lastEnd, lastToken) = spans.last;
          if (lastEnd == start && lastToken == token) {
            spans.last = (lastStart, end, token);
            continue;
          }
        }
        spans.add((start, end, token));
      }
      return spans;
    } catch (e) {
      debugPrint('Highlighting $grammar failed: $e');
      return const [];
    }
  }

  static final Map<String, _Rule?> _ruleCache = {};

  /// The token class of a span with TextMate [scopes] (outermost first), or
  /// `null` for plain text.
  ///
  /// The innermost scope with a rule decides. Punctuation is weak: a strong
  /// enclosing scope (string, comment, tag) wins over it. Embedded code
  /// (`${…}` in template strings, f-string expressions, `<script>` in HTML)
  /// does not inherit the color of its enclosing string or tag.
  static String? tokenForScopes(List<String> scopes) {
    String? weak;
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

  /// Scope prefix → token class, most specific first. A `null` token stops
  /// the search (embedded code); unmatched scopes (`source.*`, most `meta.*`,
  /// `invalid.*`) are skipped.
  static const _rules = <_Rule>[
    _Rule('meta.embedded', null),
    _Rule('meta.template.expression', null),
    _Rule('meta.fstring.expression', null),
    _Rule('string.interpolated.expression', 'variable'),
    _Rule('string.template.expression', 'variable'),
    _Rule('string.template.simple', 'variable'),
    _Rule('string.regexp', 'regexp'),
    _Rule('string', 'string'),
    _Rule('comment', 'comment'),
    _Rule('punctuation.definition.comment', 'comment'),
    _Rule('punctuation.definition.string', 'string'),
    _Rule('punctuation.definition.tag', 'tag'),
    _Rule('punctuation.support.type.property-name', 'attribute'),
    _Rule('punctuation', 'punctuation', weak: true),
    _Rule('constant.numeric', 'number'),
    _Rule('constant', 'literal'),
    _Rule('keyword.operator', 'operator'),
    _Rule('keyword', 'keyword'),
    _Rule('storage.type.annotation', 'meta'),
    _Rule('storage.type.primitive', 'type'),
    _Rule('storage.modifier.lifetime', 'symbol'),
    _Rule('storage', 'keyword'),
    _Rule('entity.name.function', 'function'),
    _Rule('entity.name.type', 'type'),
    _Rule('entity.name.class', 'type'),
    _Rule('entity.name.tag', 'tag'),
    _Rule('entity.name.selector', 'tag'),
    _Rule('entity.name.variable', 'variable'),
    _Rule('entity.other.attribute-name', 'attribute'),
    _Rule('entity', 'title'),
    _Rule('support.function', 'built_in'),
    _Rule('support.class', 'type'),
    _Rule('support.type.property-name', 'attribute'),
    _Rule('support.type', 'type'),
    _Rule('support.constant', 'literal'),
    _Rule('support', 'built_in'),
    _Rule('variable.language', 'keyword'),
    _Rule('variable', 'variable'),
    _Rule('meta.preprocessor', 'meta'),
    _Rule('meta.annotation', 'meta'),
    _Rule('meta.attribute', 'meta'),
    _Rule('markup.inserted', 'addition'),
    _Rule('markup.deleted', 'deletion'),
    _Rule('markup.heading', 'title'),
  ];
}

class _Rule {
  const _Rule(this.prefix, this.token, {this.weak = false});

  final String prefix;
  final String? token;
  final bool weak;
}
