import 'api_index.dart';

/// What a [CompletionItem] completes.
enum CompletionKind {
  /// An API class.
  type,

  /// A method or function.
  method,

  /// A getter, field or setter.
  property,

  /// A constructor.
  constructor,

  /// A local variable or parameter.
  variable,

  /// A top-level function of the script project.
  projectFunction,

  /// A Dart keyword.
  keyword,
}

/// One completion proposal.
final class CompletionItem {
  /// Creates an item.
  const CompletionItem({
    required this.label,
    required this.insertText,
    required this.kind,
    this.detail = '',
    this.doc = '',
    this.cursorOffset,
  });

  /// Text shown in the list (the name).
  final String label;

  /// Text inserted in place of the typed prefix.
  final String insertText;

  /// Kind (icon).
  final CompletionKind kind;

  /// Signature or type.
  final String detail;

  /// First doc paragraph.
  final String doc;

  /// Cursor position inside [insertText] after inserting (null = end).
  final int? cursorOffset;

  @override
  String toString() => label;
}

/// Completions at a position: the typed [prefix] and the proposals.
final class CompletionResult {
  /// Creates a result.
  const CompletionResult(this.prefix, this.items, {this.receiverType});

  /// The identifier part already typed (replaced by the completion).
  final String prefix;

  /// Proposals, best first.
  final List<CompletionItem> items;

  /// The inferred type of the receiver for member completions.
  final String? receiverType;
}

/// What hovering an identifier shows.
final class HoverInfo {
  /// Creates the info.
  const HoverInfo({
    required this.title,
    required this.doc,
    required this.start,
    required this.end,
    this.className,
  });

  /// Signature (`Range getRange(String a1Notation)`) or class name.
  final String title;

  /// Doc comment (Markdown).
  final String doc;

  /// Identifier range in the text.
  final int start;
  final int end;

  /// Class of the member (or the class itself).
  final String? className;
}

/// A project symbol (exports metadata + local scan) for completions.
final class ProjectSymbol {
  /// Creates a symbol.
  const ProjectSymbol(this.name, {this.signature = '', this.doc = ''});

  /// Function name.
  final String name;

  /// `void archive()`.
  final String signature;

  /// Doc comment.
  final String doc;
}

/// Script editor autocomplete and hover docs (09 §14.4): member completion
/// after `.` with a small type inference over the expression chain from the
/// API return types (`SpreadsheetApp.active.` → `Spreadsheet`; `final s =
/// ss.sheetByName('x')!;` → `Sheet`), locals with explicit or inferred
/// types, API classes, project functions and keywords otherwise. Unknown
/// receivers fall back to every identifier of the file.
final class ScriptCompletion {
  /// Creates the engine over [index].
  ScriptCompletion({ApiIndex? index, this.project = const []})
    : index = index ?? ApiIndex.standard;

  /// The API index.
  final ApiIndex index;

  /// Project symbols (other files, exports).
  final List<ProjectSymbol> project;

  /// Maximum proposals returned.
  static const maxItems = 60;

  static const keywords = [
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'dynamic',
    'else',
    'enum',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'if',
    'implements',
    'import',
    'in',
    'is',
    'late',
    'new',
    'null',
    'required',
    'return',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'var',
    'void',
    'while',
    'bool',
    'int',
    'double',
    'num',
    'String',
    'List',
    'Map',
    'Set',
    'Object',
    'DateTime',
    'Duration',
    'print',
  ];

  // ------------------------------------------------------------ complete

  /// Completions for the cursor at [offset] of [text]; null when the
  /// cursor is not after an identifier or a `.` (or inside a string or a
  /// comment).
  CompletionResult? complete(String text, int offset) {
    if (offset < 0 || offset > text.length) return null;
    if (_inStringOrComment(text, offset)) return null;
    var start = offset;
    while (start > 0 && _isIdent(text.codeUnitAt(start - 1))) {
      start--;
    }
    final prefix = text.substring(start, offset);
    if (prefix.isNotEmpty && _isDigit(prefix.codeUnitAt(0))) return null;
    final dot = _dotBefore(text, start);
    if (dot != null) {
      final receiver = _typeOfExpressionEndingAt(text, dot, offset);
      final items = receiver == null
          ? _fallback(text, prefix, offset)
          : _memberItems(receiver, prefix);
      return CompletionResult(prefix, items, receiverType: receiver?.name);
    }
    if (prefix.isEmpty) return null;
    return CompletionResult(prefix, _globalItems(text, prefix, offset));
  }

  List<CompletionItem> _memberItems(_Type t, String prefix) {
    final members = index.membersOf(t.name, statics: t.isStatic);
    final out = <CompletionItem>[];
    for (final m in members) {
      if (!_matches(m.name, prefix)) continue;
      out.add(_memberItem(m, t.name));
    }
    out.sort((a, b) => _rank(a.label, prefix) - _rank(b.label, prefix));
    return out.take(maxItems).toList();
  }

  CompletionItem _memberItem(ApiMember m, String className) {
    final isCall =
        m.kind == ApiMemberKind.method || m.kind == ApiMemberKind.function;
    return CompletionItem(
      label: m.name,
      insertText: isCall ? '${m.name}()' : m.name,
      cursorOffset: isCall && m.params.isNotEmpty ? m.name.length + 1 : null,
      kind: switch (m.kind) {
        ApiMemberKind.method || ApiMemberKind.function => CompletionKind.method,
        ApiMemberKind.constructor => CompletionKind.constructor,
        _ => CompletionKind.property,
      },
      detail: m.signature(className),
      doc: m.summary,
    );
  }

  List<CompletionItem> _globalItems(String text, String prefix, int offset) {
    final out = <CompletionItem>[];
    final seen = <String>{};
    void add(CompletionItem i) {
      if (seen.add(i.label)) out.add(i);
    }

    for (final v in _locals(text, offset).entries) {
      if (_matches(v.key, prefix) && v.key != prefix) {
        add(
          CompletionItem(
            label: v.key,
            insertText: v.key,
            kind: CompletionKind.variable,
            detail: v.value ?? '',
          ),
        );
      }
    }
    for (final c in index.classes) {
      if (_matches(c.name, prefix)) {
        add(
          CompletionItem(
            label: c.name,
            insertText: c.name,
            kind: CompletionKind.type,
            detail: 'class ${c.name}',
            doc: c.summary,
          ),
        );
      }
    }
    for (final f in index.functions) {
      if (_matches(f.name, prefix)) add(_memberItem(f, ''));
    }
    for (final p in [...project, ..._scanFunctions(text)]) {
      if (_matches(p.name, prefix) && p.name != prefix) {
        add(
          CompletionItem(
            label: p.name,
            insertText: '${p.name}()',
            kind: CompletionKind.projectFunction,
            detail: p.signature,
            doc: p.doc,
          ),
        );
      }
    }
    for (final k in keywords) {
      if (_matches(k, prefix) && k != prefix) {
        add(
          CompletionItem(label: k, insertText: k, kind: CompletionKind.keyword),
        );
      }
    }
    out.sort((a, b) {
      final r = _rank(a.label, prefix) - _rank(b.label, prefix);
      if (r != 0) return r;
      return a.kind.index - b.kind.index;
    });
    return out.take(maxItems).toList();
  }

  /// Unknown receiver: every identifier of the file.
  List<CompletionItem> _fallback(String text, String prefix, int offset) {
    final names = <String>{};
    for (final m in RegExp(r'[A-Za-z_]\w*').allMatches(text)) {
      if (m.start <= offset && m.end >= offset) continue;
      final w = m.group(0)!;
      if (w.length > 1 && _matches(w, prefix) && w != prefix) names.add(w);
    }
    final sorted = names.toList()
      ..sort((a, b) => _rank(a, prefix) - _rank(b, prefix));
    return [
      for (final n in sorted.take(maxItems))
        CompletionItem(label: n, insertText: n, kind: CompletionKind.variable),
    ];
  }

  // --------------------------------------------------------------- hover

  /// Hover docs for the identifier at [offset], or null.
  HoverInfo? hover(String text, int offset) {
    if (offset < 0 || offset >= text.length) return null;
    if (!_isIdent(text.codeUnitAt(offset))) return null;
    if (_inStringOrComment(text, offset)) return null;
    var start = offset, end = offset;
    while (start > 0 && _isIdent(text.codeUnitAt(start - 1))) {
      start--;
    }
    while (end < text.length && _isIdent(text.codeUnitAt(end))) {
      end++;
    }
    final word = text.substring(start, end);
    final dot = _dotBefore(text, start);
    if (dot != null) {
      final t = _typeOfExpressionEndingAt(text, dot, start);
      if (t == null) return null;
      final m = _member(t, word);
      if (m == null) return null;
      return HoverInfo(
        title: m.signature(t.name),
        doc: m.doc,
        start: start,
        end: end,
        className: t.name,
      );
    }
    final cls = index.classNamed(word);
    if (cls != null) {
      return HoverInfo(
        title: cls.superclass == null
            ? 'class ${cls.name}'
            : 'class ${cls.name} extends ${cls.superclass}',
        doc: cls.doc,
        start: start,
        end: end,
        className: cls.name,
      );
    }
    for (final f in index.functions) {
      if (f.name == word) {
        return HoverInfo(
          title: f.signature(),
          doc: f.doc,
          start: start,
          end: end,
        );
      }
    }
    for (final p in project) {
      if (p.name == word && p.signature.isNotEmpty) {
        return HoverInfo(
          title: p.signature,
          doc: p.doc,
          start: start,
          end: end,
        );
      }
    }
    final local = _locals(text, start)[word];
    if (local != null) {
      return HoverInfo(title: '$local $word', doc: '', start: start, end: end);
    }
    return null;
  }

  ApiMember? _member(_Type t, String name) {
    for (final m in index.membersOf(t.name, statics: t.isStatic)) {
      if (m.name == name && m.kind != ApiMemberKind.setter) return m;
    }
    return index.member(t.name, name);
  }

  // ------------------------------------------------------ type inference

  /// The type of the expression ending just before the `.` at [dot].
  _Type? _typeOfExpressionEndingAt(String text, int dot, int cursor) {
    final segments = _chain(text, dot);
    if (segments == null || segments.isEmpty) return null;
    return _typeOfChain(text, segments, cursor, 0);
  }

  _Type? _typeOfChain(
    String text,
    List<_Segment> segments,
    int cursor,
    int depth,
  ) {
    if (depth > 6) return null;
    final first = segments.first;
    _Type? t;
    if (first.name == 'this' || first.name == 'super') return null;
    final cls = index.classNamed(first.name);
    if (first.literal != null) {
      t = _Type(first.literal!);
    } else if (cls != null && !first.call) {
      t = _Type(cls.name, isStatic: true);
    } else if (cls != null && first.call) {
      t = _Type(cls.name);
    } else {
      final local = _localType(text, first.name, cursor, depth);
      if (local != null) {
        t = _Type(local);
      } else {
        for (final f in index.functions) {
          if (f.name == first.name) t = _typeOf(f.type);
        }
      }
    }
    for (final s in segments.skip(1)) {
      if (t == null) return null;
      if (s.name.isEmpty) {
        // `[i]` on a list.
        t = _elementType(t.name);
        continue;
      }
      if (s.isNamedConstructor && t.isStatic) {
        final ctor = index
            .classNamed(t.name)
            ?.members
            .where(
              (m) => m.kind == ApiMemberKind.constructor && m.name == s.name,
            )
            .firstOrNull;
        if (ctor != null) {
          t = _Type(t.name);
          continue;
        }
      }
      final m = _member(t, s.name);
      if (m == null) return null;
      t = _typeOf(m.type);
      for (var i = 0; i < s.indexes; i++) {
        t = t == null ? null : _elementType(t.name);
      }
    }
    if (t == null) return null;
    for (var i = 0; i < first.indexes && segments.length == 1; i++) {
      t = _elementType(t!.name);
      if (t == null) return null;
    }
    return t;
  }

  _Type? _typeOf(String type) {
    final name = _bare(type);
    if (name.isEmpty || name == 'void' || name == 'dynamic') return null;
    return _Type(name);
  }

  /// `List<Range>?` → `Range` (element of a list).
  _Type? _elementType(String type) {
    final m = RegExp(r'^List<(.+)>$').firstMatch(type);
    if (m == null) return null;
    return _typeOf(m.group(1)!);
  }

  /// `Sheet?` → `Sheet`; `List<Range>` stays.
  static String _bare(String type) {
    var t = type.trim();
    while (t.endsWith('?') || t.endsWith('!')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  /// The declared or inferred type of the local [name] visible at
  /// [cursor] (the closest declaration before it).
  String? _localType(String text, String name, int cursor, int depth) {
    final before = text.substring(0, cursor.clamp(0, text.length));
    String? found;
    var foundAt = -1;
    final esc = RegExp.escape(name);
    // Explicit types: `Sheet s =`, `(Range r)`, `final Range r;`.
    final explicit = RegExp(
      r'(?:^|[\s(,{;])((?:[A-Z]\w*|int|double|num|bool|String)(?:<[\w<>?, ]*>)?\??)\s+' +
          esc +
          r'\s*(?=[=;,)\]:]|\s+in\b)',
      multiLine: true,
    );
    for (final m in explicit.allMatches(before)) {
      if (m.start > foundAt) {
        found = m.group(1);
        foundAt = m.start;
      }
    }
    // `final s = expr;` / `var s = expr;`.
    final inferred = RegExp(
      r'\b(?:final|var|const)\s+' + esc + r'\s*=\s*([^;]+);',
    );
    for (final m in inferred.allMatches(before)) {
      if (m.start <= foundAt) continue;
      final expr = m.group(1)!.trim();
      final t = _typeOfSource(expr, text, m.start, depth + 1);
      if (t != null) {
        found = t;
        foundAt = m.start;
      }
    }
    // `for (final x in expr)`.
    final forIn = RegExp(
      r'for\s*\(\s*(?:final|var)\s+' + esc + r'\s+in\s+([^)]+)\)',
    );
    for (final m in forIn.allMatches(before)) {
      if (m.start <= foundAt) continue;
      final t = _typeOfSource(m.group(1)!.trim(), text, m.start, depth + 1);
      final e = t == null ? null : _elementType(t);
      if (e != null) {
        found = e.name;
        foundAt = m.start;
      }
    }
    return found == null ? null : _bare(found);
  }

  String? _typeOfSource(String expr, String text, int at, int depth) {
    var e = expr;
    while (e.endsWith('!')) {
      e = e.substring(0, e.length - 1).trimRight();
    }
    // Strip a trailing call-free cascade or `as T`.
    final asMatch = RegExp(r'\bas\s+([\w<>?]+)$').firstMatch(e);
    if (asMatch != null) return asMatch.group(1);
    if (RegExp(r'^\d+$').hasMatch(e)) return 'int';
    if (RegExp(r'^\d*\.\d+$').hasMatch(e)) return 'double';
    if (e.startsWith("'") || e.startsWith('"')) return 'String';
    if (e == 'true' || e == 'false') return 'bool';
    final padded = '$e.';
    final segments = _chain(padded, padded.length - 1);
    if (segments == null || segments.isEmpty) return null;
    final t = _typeOfChain(text, segments, at, depth);
    if (t == null || t.isStatic) return null;
    return t.name;
  }

  /// Local variable names with their types (null = unknown) visible at
  /// [offset].
  Map<String, String?> _locals(String text, int offset) {
    final before = text.substring(0, offset.clamp(0, text.length));
    final out = <String, String?>{};
    for (final m in RegExp(
      r'\b(?:final|var|const)\s+([A-Za-z_]\w*)\s*(?:=|in\b)',
    ).allMatches(before)) {
      final n = m.group(1)!;
      out[n] = _localType(text, n, offset, 0);
    }
    for (final m in RegExp(
      r'(?:^|[\s(,{;])((?:[A-Z]\w*|int|double|num|bool|String)(?:<[\w<>?, ]*>)?\??)\s+([a-z_]\w*)\s*(?=[=;,)])',
      multiLine: true,
    ).allMatches(before)) {
      out[m.group(2)!] = _bare(m.group(1)!);
    }
    return out;
  }

  /// Top-level functions declared in [text].
  static List<ProjectSymbol> _scanFunctions(String text) => [
    for (final m in RegExp(
      r'^(?:[\w<>?,\s]+?)\s+([A-Za-z_]\w*)\s*\(([^)]*)\)\s*(?:async\s*)?(?:\{|=>)',
      multiLine: true,
    ).allMatches(text))
      if (!const {'if', 'for', 'while', 'switch', 'catch'}.contains(m.group(1)))
        ProjectSymbol(
          m.group(1)!,
          signature: text
              .substring(m.start, m.end - 2)
              .trim()
              .replaceAll(RegExp(r'\s+'), ' '),
        ),
  ];

  /// Splits the receiver expression ending at [end] (exclusive, the `.`)
  /// into segments: `SpreadsheetApp.active.sheetByName('x')!` →
  /// [SpreadsheetApp, active, sheetByName()]. Null when it cannot be read.
  static List<_Segment>? _chain(String text, int end) {
    final segments = <_Segment>[];
    var i = end - 1;
    while (true) {
      // Skip whitespace and null assertions / `?` of `?.`.
      while (i >= 0 &&
          (text[i] == '!' ||
              text[i] == '?' ||
              text[i] == ' ' ||
              text[i] == '\n')) {
        i--;
      }
      if (i < 0) break;
      var call = false;
      var indexes = 0;
      String? literal;
      // Trailing `(...)` and `[...]`.
      while (i >= 0 && (text[i] == ')' || text[i] == ']')) {
        final open = _matching(text, i);
        if (open == null) return null;
        if (text[i] == ')') {
          call = true;
        } else {
          indexes++;
        }
        i = open - 1;
        while (i >= 0 && (text[i] == '!' || text[i] == ' ')) {
          i--;
        }
      }
      if (i >= 0 && (text[i] == "'" || text[i] == '"')) {
        // A string literal receiver.
        final q = text[i];
        var j = i - 1;
        while (j >= 0 && text[j] != q) {
          j--;
        }
        if (j < 0) return null;
        literal = 'String';
        i = j - 1;
        segments.insert(
          0,
          _Segment('', call: false, indexes: indexes, literal: literal),
        );
        break;
      }
      var s = i;
      while (s >= 0 && _isIdent(text.codeUnitAt(s))) {
        s--;
      }
      final name = text.substring(s + 1, i + 1);
      if (name.isEmpty) {
        if (call && indexes == 0) return null; // `(expr).`
        if (indexes > 0 && segments.isEmpty) return null;
        break;
      }
      if (_isDigit(name.codeUnitAt(0))) return null;
      segments.insert(0, _Segment(name, call: call, indexes: indexes));
      i = s;
      while (i >= 0 && (text[i] == ' ' || text[i] == '\n')) {
        i--;
      }
      if (i >= 0 && text[i] == '.') {
        if (i > 0 && text[i - 1] == '.') break; // cascade `..`
        i--;
        if (i >= 0 && text[i] == '?') i--;
        continue;
      }
      break;
    }
    for (var k = 1; k < segments.length; k++) {
      final prev = segments[k - 1];
      if (index0IsClassLike(prev.name) && !prev.call && segments[k].call) {
        segments[k] = segments[k].asNamedConstructor();
      }
    }
    return segments;
  }

  static bool index0IsClassLike(String name) =>
      name.isNotEmpty && name.codeUnitAt(0) >= 65 && name.codeUnitAt(0) <= 90;

  static int? _matching(String text, int close) {
    final c = text[close];
    final o = c == ')' ? '(' : '[';
    var depth = 0;
    for (var i = close; i >= 0; i--) {
      final ch = text[i];
      if (ch == c) depth++;
      if (ch == o) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static int? _dotBefore(String text, int start) {
    var i = start - 1;
    while (i >= 0 && (text[i] == ' ' || text[i] == '\n')) {
      i--;
    }
    if (i >= 0 && text[i] == '.') {
      if (i > 0 && text[i - 1] == '.') return null;
      return i;
    }
    return null;
  }

  /// Whether [offset] is inside a string literal or a comment (line-based).
  static bool _inStringOrComment(String text, int offset) {
    // At offset 0 there is nothing before the cursor (lastIndexOf rejects
    // a negative start).
    final lineStart = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
    final line = text.substring(lineStart, offset);
    String? quote;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (quote != null) {
        if (ch == r'\') {
          i++;
        } else if (ch == quote) {
          quote = null;
        }
        continue;
      }
      if (ch == '/' && i + 1 < line.length && line[i + 1] == '/') return true;
      if (ch == "'" || ch == '"') quote = ch;
    }
    return quote != null;
  }

  static bool _matches(String name, String prefix) {
    if (prefix.isEmpty) return true;
    if (name.startsWith(prefix)) return true;
    return name.toLowerCase().startsWith(prefix.toLowerCase());
  }

  static int _rank(String name, String prefix) {
    if (prefix.isEmpty) return 0;
    if (name.startsWith(prefix)) return 0;
    return 1;
  }

  static bool _isIdent(int c) =>
      (c >= 48 && c <= 57) ||
      (c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95 ||
      c == 36;

  static bool _isDigit(int c) => c >= 48 && c <= 57;
}

final class _Type {
  const _Type(this.name, {this.isStatic = false});

  /// Class or type name (`Sheet`, `List<Range>`).
  final String name;

  /// Static access through the class name.
  final bool isStatic;
}

final class _Segment {
  const _Segment(
    this.name, {
    required this.call,
    required this.indexes,
    this.literal,
    this.isNamedConstructor = false,
  });

  final String name;
  final bool call;
  final int indexes;
  final String? literal;
  final bool isNamedConstructor;

  _Segment asNamedConstructor() => _Segment(
    name,
    call: call,
    indexes: indexes,
    literal: literal,
    isNamedConstructor: true,
  );
}
