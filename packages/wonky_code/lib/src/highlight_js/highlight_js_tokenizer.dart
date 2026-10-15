/// highlight.js tokenization (Slides 07 §2.2): the fallback tokenizer for
/// languages without a TextMate grammar, and Write's export tokenizer until
/// M10 (Write 04 §15.5). Moved from `wonky_write_core` (its
/// `SyntaxHighlighter`).
///
/// Wraps the pure-Dart highlight.js port (`package:highlight`).
library;

import 'package:highlight/highlight_core.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/clojure.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/diff.dart';
import 'package:highlight/languages/dockerfile.dart';
import 'package:highlight/languages/elixir.dart';
import 'package:highlight/languages/erlang.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/gradle.dart';
import 'package:highlight/languages/graphql.dart';
import 'package:highlight/languages/groovy.dart';
import 'package:highlight/languages/haskell.dart';
import 'package:highlight/languages/http.dart';
import 'package:highlight/languages/ini.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/less.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/makefile.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/matlab.dart';
import 'package:highlight/languages/nginx.dart';
import 'package:highlight/languages/objectivec.dart';
import 'package:highlight/languages/perl.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/powershell.dart';
import 'package:highlight/languages/protobuf.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/r.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/scala.dart';
import 'package:highlight/languages/scss.dart';
import 'package:highlight/languages/shell.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

import '../code_tokenizer.dart';
import '../syntax_token.dart';

/// Tokenizes code into [SyntaxToken] ranges with highlight.js grammars
/// (Write 06 §2.5, §6.3; Slides 07 §2.2).
///
/// Supports the ~45 most common highlight.js grammars ([languages]); fence
/// info strings are resolved through [aliases] by [canonicalLanguage].
/// Unknown languages, `plaintext` and code longer than [maxLength] get no
/// highlighting. [tokenize] never throws and is deterministic.
///
/// ## Class mapping
///
/// highlight.js class names map to tokens as follows (compound names such as
/// `title.class_` are tried in full, then by their first part):
///
/// | highlight.js class | Token |
/// |---|---|
/// | `keyword` | [SyntaxToken.keyword] |
/// | `string`, `char`, `code`, `meta-string` | [SyntaxToken.string] |
/// | `number` | [SyntaxToken.number] |
/// | `comment`, `doctag`, `quote` | [SyntaxToken.comment] |
/// | `title` (not inside `class`), `title.function`, `section` | [SyntaxToken.function] |
/// | `title` inside `class`, `title.class`, `type`, `class-name` | [SyntaxToken.type] |
/// | `variable`, `template-variable` | [SyntaxToken.variable] |
/// | `operator` | [SyntaxToken.operator] |
/// | `punctuation` | [SyntaxToken.punctuation] |
/// | `built_in`, `builtin-name` | [SyntaxToken.builtin] |
/// | `literal`, `symbol`, `bullet` | [SyntaxToken.literal] |
/// | `meta`, `meta-keyword`, `annotation`, `decorator` | [SyntaxToken.meta] |
/// | `tag`, `name`, `selector-tag`, `template-tag` | [SyntaxToken.tag] |
/// | `attr`, `attribute`, `property`, `selector-id`, `selector-class`, `selector-attr`, `selector-pseudo` | [SyntaxToken.attribute] |
/// | `regexp`, `link` | [SyntaxToken.regexp] |
/// | `addition` | [SyntaxToken.addition] |
/// | `deletion` | [SyntaxToken.deletion] |
/// | `subst`, embedded sub-languages | no token, and the enclosing token does **not** apply (an interpolation inside a string is not string-colored) |
/// | `class`, `function`, `params`, `emphasis`, `strong`, anything else | transparent: the enclosing token applies |
///
/// Nested classes are flattened: each character gets the innermost class
/// that maps to a token, and adjacent ranges with equal tokens are merged.
final class HighlightJsTokenizer implements CodeTokenizer {
  /// Creates a highlighter that skips code longer than [maxLength] UTF-16
  /// code units (tokenizing huge blocks is too slow for an editor frame).
  const HighlightJsTokenizer({this.maxLength = 200000});

  /// The shared default highlighter.
  static const HighlightJsTokenizer instance = HighlightJsTokenizer();

  /// Code longer than this (in UTF-16 code units) is not highlighted.
  final int maxLength;

  /// Canonical language ids with their highlight.js grammar.
  static final Map<String, Mode> _modes = {
    'bash': bash,
    'clojure': clojure,
    'console': shell,
    'cpp': cpp,
    'csharp': cs,
    'css': css,
    'dart': dart,
    'diff': diff,
    'dockerfile': dockerfile,
    'elixir': elixir,
    'erlang': erlang,
    'go': go,
    'gradle': gradle,
    'graphql': graphql,
    'groovy': groovy,
    'haskell': haskell,
    'http': _patchedHttp(),
    'ini': _patchedIni(),
    'java': java,
    'javascript': javascript,
    'json': json,
    'kotlin': kotlin,
    'less': less,
    'lua': lua,
    'makefile': makefile,
    'markdown': markdown,
    'matlab': matlab,
    'nginx': nginx,
    'objectivec': objectivec,
    'perl': perl,
    'php': php,
    'powershell': powershell,
    'protobuf': protobuf,
    'python': python,
    'r': r,
    'ruby': ruby,
    'rust': rust,
    'scala': scala,
    'scss': scss,
    'sql': sql,
    'swift': swift,
    'typescript': typescript,
    'xml': _patchedXml(),
    'yaml': yaml,
  };

  /// Canonical id of the language that has no highlighting.
  static const String plaintext = 'plaintext';

  /// The canonical language ids, sorted (includes [plaintext]).
  static final List<String> languages = List.unmodifiable(
    [..._modes.keys, plaintext]..sort(),
  );

  /// Alternative names (lowercase) → canonical language id.
  ///
  /// Canonical ids resolve to themselves and are not listed here.
  static const Map<String, String> aliases = {
    // JavaScript / TypeScript.
    'js': 'javascript', 'jsx': 'javascript', 'mjs': 'javascript',
    'cjs': 'javascript', 'node': 'javascript', 'ecmascript': 'javascript',
    'ts': 'typescript', 'tsx': 'typescript', 'mts': 'typescript',
    'cts': 'typescript',
    // Python, Ruby, Perl, PHP.
    'py': 'python', 'py3': 'python', 'python3': 'python', 'gyp': 'python',
    'rb': 'ruby', 'gemspec': 'ruby', 'podspec': 'ruby',
    'pl': 'perl', 'pm': 'perl',
    'php3': 'php', 'php4': 'php', 'php5': 'php', 'php7': 'php',
    'php8': 'php',
    // JVM.
    'kt': 'kotlin', 'kts': 'kotlin',
    'sc': 'scala',
    'gvy': 'groovy',
    // C family (highlight 0.7 has one grammar for C and C++).
    'c': 'cpp', 'c++': 'cpp', 'cc': 'cpp', 'cxx': 'cpp', 'h': 'cpp',
    'hh': 'cpp', 'hpp': 'cpp', 'hxx': 'cpp', 'h++': 'cpp',
    'cs': 'csharp', 'c#': 'csharp',
    'objective-c': 'objectivec', 'objc': 'objectivec',
    'obj-c': 'objectivec', 'mm': 'objectivec',
    // Systems.
    'golang': 'go',
    'rs': 'rust',
    // Shells.
    'sh': 'bash', 'zsh': 'bash', 'shell': 'bash', 'ksh': 'bash',
    'shellscript': 'bash',
    'shellsession': 'console', 'shell-session': 'console',
    'terminal': 'console',
    'ps1': 'powershell', 'ps': 'powershell', 'pwsh': 'powershell',
    'psm1': 'powershell',
    // Data and markup.
    'jsonc': 'json',
    'yml': 'yaml',
    'html': 'xml', 'htm': 'xml', 'xhtml': 'xml', 'svg': 'xml',
    'plist': 'xml', 'rss': 'xml', 'atom': 'xml', 'xsl': 'xml',
    'md': 'markdown', 'mkd': 'markdown', 'mkdown': 'markdown',
    'toml': 'ini', 'cfg': 'ini',
    'gql': 'graphql',
    'proto': 'protobuf',
    'patch': 'diff',
    'text': 'plaintext', 'txt': 'plaintext', 'plain': 'plaintext',
    // Tooling and config.
    'docker': 'dockerfile',
    'make': 'makefile', 'mk': 'makefile', 'mak': 'makefile',
    'nginxconf': 'nginx',
    'https': 'http',
    // Others.
    'hs': 'haskell',
    'ex': 'elixir', 'exs': 'elixir',
    'erl': 'erlang',
    'clj': 'clojure', 'cljs': 'clojure', 'cljc': 'clojure', 'edn': 'clojure',
  };

  /// The private highlight.js engine with every grammar registered (also the
  /// embedded sub-languages, e.g. CSS/JS inside HTML).
  static final Highlight _engine = Highlight()..registerLanguages(_modes);

  /// Resolves a fence info string to a canonical language id, or `null` when
  /// unknown.
  ///
  /// Case-insensitive; surrounding whitespace is trimmed and only the first
  /// word is used (`"Dart title=x"` → `dart`).
  String? canonicalLanguage(String? language) {
    if (language == null) return null;
    var key = language.trim().toLowerCase();
    if (key.isEmpty) return null;
    final space = key.indexOf(RegExp(r'\s'));
    if (space > 0) key = key.substring(0, space);
    if (key == plaintext || _modes.containsKey(key)) return key;
    return aliases[key];
  }

  /// Whether [language] (or an alias of it) is a known language.
  ///
  /// `plaintext` is known but produces no spans.
  @override
  bool supports(String? language) => canonicalLanguage(language) != null;

  /// Returns the highlighted ranges of [code] in [language].
  ///
  /// Spans are sorted, non-overlapping, non-empty and within `code.length`;
  /// unclassified text has no span. Returns an empty list for unknown,
  /// `null` or empty languages, for `plaintext`, for code longer than
  /// [maxLength], and if the grammar fails. Never throws.
  @override
  List<CodeToken> tokenize(String code, String? language) {
    if (code.isEmpty || code.length > maxLength) return const [];
    final id = canonicalLanguage(language);
    if (id == null || id == plaintext) return const [];
    try {
      final result = _engine.parse(code, language: id);
      final nodes = result.nodes;
      if (nodes == null) return const [];
      final builder = _SpanBuilder();
      for (final node in nodes) {
        builder.visit(node, null, null);
      }
      // A grammar that lost or duplicated text would yield wrong offsets.
      if (builder.offset != code.length) return const [];
      return List.unmodifiable(builder.spans);
    } catch (_) {
      return const [];
    }
  }
}

/// highlight 0.7.0 re-tests a matched lexeme against each mode's `begin` in
/// isolation, so a `begin` ending in a lookahead never matches its own
/// lexeme. These grammars are copied with the affected top-level patterns
/// also accepting `$` (end of the lexeme), as the port's other grammars do.
/// The shared global modes are not modified.
///
/// Without the fix, embedded CSS/JavaScript in HTML is not highlighted, and
/// INI/TOML files fail as a whole on their first `key = value` line.
Mode _patchedXml() => _patchBegins(xml, const {
  r'<style(?=\s|>)': r'<style(?=\s|>|$)',
  r'<script(?=\s|>)': r'<script(?=\s|>|$)',
});

/// See [_patchedXml].
Mode _patchedIni() => _patchBegins(ini, const {
  r'^[a-z0-9\[\]_\.-]+(?=\s*=\s*)': r'^[a-z0-9\[\]_\.-]+(?=\s*=\s*|$)',
});

/// A copy of [language] whose top-level modes with a `begin` in [fixes] use
/// the replacement pattern instead.
Mode _patchBegins(Mode language, Map<String, String> fixes) =>
    _patchTopLevel(language, (mode) {
      final begin = fixes[mode.begin];
      return begin == null ? null : Mode.inherit(mode, Mode(begin: begin));
    });

/// The message body languages auto-detected in HTTP messages.
const List<String> _httpBodyLanguages = ['json', 'xml', 'javascript', 'css'];

/// A copy of highlight 0.7.0's `http` grammar that auto-detects the message
/// body only among [_httpBodyLanguages] instead of every registered grammar
/// (which costs one full parse per language).
Mode _patchedHttp() => _patchTopLevel(http, (mode) {
  final starts = mode.starts;
  if (starts == null || starts.subLanguage?.isEmpty != true) return null;
  return Mode.inherit(
    mode,
    Mode(
      starts: Mode.inherit(starts, Mode(subLanguage: _httpBodyLanguages))
        ..compiled = null,
    ),
  );
});

/// A copy of [language] whose top-level modes are replaced by [patch]
/// (`null` keeps a mode). Patched copies are recompiled on first use.
Mode _patchTopLevel(Mode language, Mode? Function(Mode mode) patch) {
  final contains = [
    for (final mode in language.contains ?? const <Mode?>[])
      if (mode == null)
        mode
      else if (patch(mode) case final patched?)
        patched
          ..compiled = null
          ..beginRe = null
          ..terminators = null
      else
        mode,
  ];
  return Mode.inherit(language, Mode(contains: contains))
    ..refs = language.refs
    ..compiled = null
    ..terminators = null;
}

/// How a highlight.js class affects the characters it covers.
sealed class _Effect {
  const _Effect();
}

/// The class maps to a token.
final class _Token extends _Effect {
  const _Token(this.token);
  final SyntaxToken token;
}

/// The class removes any enclosing token (sub-languages, interpolations).
final class _Reset extends _Effect {
  const _Reset();
}

/// highlight.js class name → token (see the table on [HighlightJsTokenizer]).
const Map<String, SyntaxToken> _classTokens = {
  'keyword': SyntaxToken.keyword,
  'string': SyntaxToken.string,
  'char': SyntaxToken.string,
  'code': SyntaxToken.string,
  'meta-string': SyntaxToken.string,
  'number': SyntaxToken.number,
  'comment': SyntaxToken.comment,
  'doctag': SyntaxToken.comment,
  'quote': SyntaxToken.comment,
  'title': SyntaxToken.function,
  'title.function': SyntaxToken.function,
  'title.function_': SyntaxToken.function,
  'section': SyntaxToken.function,
  'title.class': SyntaxToken.type,
  'title.class_': SyntaxToken.type,
  'type': SyntaxToken.type,
  'class-name': SyntaxToken.type,
  'variable': SyntaxToken.variable,
  'template-variable': SyntaxToken.variable,
  'operator': SyntaxToken.operator,
  'punctuation': SyntaxToken.punctuation,
  'built_in': SyntaxToken.builtin,
  'builtin-name': SyntaxToken.builtin,
  'literal': SyntaxToken.literal,
  'symbol': SyntaxToken.literal,
  'bullet': SyntaxToken.literal,
  'meta': SyntaxToken.meta,
  'meta-keyword': SyntaxToken.meta,
  'annotation': SyntaxToken.meta,
  'decorator': SyntaxToken.meta,
  'tag': SyntaxToken.tag,
  'name': SyntaxToken.tag,
  'selector-tag': SyntaxToken.tag,
  'template-tag': SyntaxToken.tag,
  'attr': SyntaxToken.attribute,
  'attribute': SyntaxToken.attribute,
  'property': SyntaxToken.attribute,
  'selector-id': SyntaxToken.attribute,
  'selector-class': SyntaxToken.attribute,
  'selector-attr': SyntaxToken.attribute,
  'selector-pseudo': SyntaxToken.attribute,
  'regexp': SyntaxToken.regexp,
  'link': SyntaxToken.regexp,
  'addition': SyntaxToken.addition,
  'deletion': SyntaxToken.deletion,
};

/// Classes that clear the enclosing token.
const Set<String> _resetClasses = {'subst'};

/// The effect of [className] given the nearest enclosing class
/// [parentClass]; `null` means transparent.
_Effect? _effectOf(String className, bool noPrefix, String? parentClass) {
  // Sub-language nodes carry the language id without the `hljs-` prefix.
  if (noPrefix) return const _Reset();
  final parts = className.split(RegExp(r'[ .]'));
  final head = parts.first;
  if (_resetClasses.contains(head)) return const _Reset();
  if (className == 'title' && parentClass == 'class') {
    return const _Token(SyntaxToken.type);
  }
  final token = _classTokens[className] ?? _classTokens[head];
  return token == null ? null : _Token(token);
}

/// Flattens a highlight.js node tree into merged, sorted spans.
final class _SpanBuilder {
  final List<CodeToken> spans = [];
  int offset = 0;

  void visit(Node node, SyntaxToken? inherited, String? parentClass) {
    var token = inherited;
    var classForChildren = parentClass;
    final className = node.className;
    if (className != null && className.isNotEmpty) {
      switch (_effectOf(className, node.noPrefix, parentClass)) {
        case _Token(token: final mapped):
          token = mapped;
        case _Reset():
          token = null;
        case null:
          break;
      }
      classForChildren = node.noPrefix ? null : className.split(' ').first;
    }
    final value = node.value;
    if (value != null) {
      _emit(value.length, token);
      return;
    }
    final children = node.children;
    if (children == null) return;
    for (final child in children) {
      visit(child, token, classForChildren);
    }
  }

  void _emit(int length, SyntaxToken? token) {
    if (length == 0) return;
    final start = offset;
    offset += length;
    if (token == null) return;
    if (spans.isNotEmpty) {
      final last = spans.last;
      if (last.end == start && last.token == token) {
        spans[spans.length - 1] = CodeToken(last.start, offset, token);
        return;
      }
    }
    spans.add(CodeToken(start, offset, token));
  }
}
