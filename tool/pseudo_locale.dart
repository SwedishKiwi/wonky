// Pseudo-locale generator (specs/11-quality-testing-accessibility.md §4).
//
// Turns an English template ARB into an `en_XA` pseudo-locale ARB so the UI
// can be checked for hard-coded strings, truncation, concatenation and
// missing expansion room:
//
//   dart run tool/pseudo_locale.dart <in_en.arb> <out_en_XA.arb>
//   dart run tool/pseudo_locale.dart --self-test
//
// Every message becomes `[Ŝéţţîñĝš one two]`: Latin letters are accented,
// ~35% padding is appended and the whole message is bracketed. ICU syntax is
// preserved: `{placeholder}` names, `plural`/`select` keywords and case
// selectors (`=0`, `one`, `other`, …) and `#`. `@key` metadata is dropped
// (gen-l10n reads placeholders from the template only) and `@@locale` is set
// to `en_XA`. Dependency-free (dart:io + dart:convert), so any package can
// use it without a pubspec.

import 'dart:convert';
import 'dart:io';

const _accents = {
  'a': 'å', 'b': 'ƀ', 'c': 'ç', 'd': 'ð', 'e': 'é', 'f': 'ƒ', 'g': 'ĝ', //
  'h': 'ĥ', 'i': 'î', 'j': 'ĵ', 'k': 'ķ', 'l': 'ļ', 'm': 'ɱ', 'n': 'ñ',
  'o': 'ö', 'p': 'þ', 'q': 'ǫ', 'r': 'ŕ', 's': 'š', 't': 'ţ', 'u': 'û',
  'v': 'ṽ', 'w': 'ŵ', 'x': 'ẋ', 'y': 'ý', 'z': 'ž', 'A': 'Å', 'B': 'Ɓ',
  'C': 'Ç', 'D': 'Ð', 'E': 'É', 'F': 'Ƒ', 'G': 'Ĝ', 'H': 'Ĥ', 'I': 'Î',
  'J': 'Ĵ', 'K': 'Ķ', 'L': 'Ļ', 'M': 'Ṁ', 'N': 'Ñ', 'O': 'Ö', 'P': 'Þ',
  'Q': 'Ǫ', 'R': 'Ŕ', 'S': 'Š', 'T': 'Ţ', 'U': 'Û', 'V': 'Ṽ', 'W': 'Ŵ',
  'X': 'Ẋ', 'Y': 'Ý', 'Z': 'Ž',
};

/// Padding words; spaces let padded text wrap like real translations.
const _padWords = 'one two three four five six seven eight nine ten';

/// Expansion added to every message, relative to its visible text.
const expansion = 0.35;

/// Pseudo-localizes one ICU [message]. Throws a [FormatException] when the
/// message is not valid ICU (unbalanced braces).
String pseudoLocalize(String message) {
  final p = _Parser(message);
  final body = p.message(topLevel: true);
  final pad = (p.visible * expansion).ceil();
  return '[$body${pad == 0 ? '' : ' ${_padding(pad)}'}]';
}

String _padding(int n) {
  final b = StringBuffer();
  while (b.length < n) {
    if (b.isNotEmpty) b.write(' ');
    b.write(_padWords);
  }
  return b.toString().substring(0, n).trimRight();
}

class _Parser {
  _Parser(this.s);

  final String s;
  int i = 0;

  /// Visible characters transformed so far (drives the padding).
  int visible = 0;

  FormatException _error(String what) =>
      FormatException('$what at offset $i', s, i);

  /// Text and arguments up to the end (top level) or the closing `}` of a
  /// plural/select case, which is left unconsumed.
  String message({required bool topLevel}) {
    final out = StringBuffer();
    while (i < s.length) {
      final c = s[i];
      if (c == '{') {
        out.write(_argument());
      } else if (c == '}') {
        if (topLevel) throw _error('Unbalanced "}"');
        return out.toString();
      } else if (c == '#' && !topLevel) {
        out.write(c);
        i++;
      } else {
        out.write(_accents[c] ?? c);
        if (c.trim().isNotEmpty) visible++;
        i++;
      }
    }
    if (!topLevel) throw _error('Missing "}"');
    return out.toString();
  }

  /// `{name}`, `{name, plural|select|selectordinal, cases}` or any other
  /// formatted argument (copied verbatim).
  String _argument() {
    final start = i;
    i++; // {
    final name = _until(const {',', '}'});
    if (i >= s.length) throw _error('Missing "}"');
    if (s[i] == '}') {
      i++;
      return '{$name}';
    }
    i++; // ,
    final type = _until(const {',', '}'});
    final kind = type.trim();
    if (kind != 'plural' && kind != 'select' && kind != 'selectordinal') {
      // Another formatted argument (number, date, …): copy verbatim.
      var depth = 1;
      while (i < s.length && depth > 0) {
        if (s[i] == '{') depth++;
        if (s[i] == '}') depth--;
        i++;
      }
      if (depth > 0) throw _error('Missing "}"');
      return s.substring(start, i);
    }
    if (i >= s.length || s[i] != ',') throw _error('Missing cases');
    i++; // ,
    final out = StringBuffer('{$name,$type,');
    while (true) {
      final ws = _whitespace();
      if (i >= s.length) throw _error('Missing "}"');
      if (s[i] == '}') {
        i++;
        out
          ..write(ws)
          ..write('}');
        return out.toString();
      }
      final selector = _until(const {'{', '}', ' ', '\t', '\n', '\r'});
      if (selector.isEmpty) throw _error('Missing case selector');
      final ws2 = _whitespace();
      if (selector.startsWith('offset:')) {
        out.write('$ws$selector$ws2');
        continue;
      }
      if (i >= s.length || s[i] != '{') throw _error('Missing case body');
      i++; // {
      final body = message(topLevel: false);
      i++; // }
      out.write('$ws$selector$ws2{$body}');
    }
  }

  String _until(Set<String> stops) {
    final start = i;
    while (i < s.length && !stops.contains(s[i])) {
      i++;
    }
    return s.substring(start, i);
  }

  String _whitespace() {
    final start = i;
    while (i < s.length && s[i].trim().isEmpty) {
      i++;
    }
    return s.substring(start, i);
  }
}

/// Converts a decoded template ARB into the pseudo-locale ARB.
Map<String, Object?> pseudoArb(
  Map<String, Object?> template, {
  String locale = 'en_XA',
  String? source,
}) {
  final out = <String, Object?>{
    '@@locale': locale,
    '@@x-generated':
        'Generated by tool/pseudo_locale.dart'
        '${source == null ? '' : ' from $source'}. Do not edit.',
  };
  for (final MapEntry(:key, :value) in template.entries) {
    if (key.startsWith('@')) continue;
    if (value is! String) continue;
    try {
      out[key] = pseudoLocalize(value);
    } on FormatException catch (e) {
      stderr.writeln('pseudo_locale: "$key" kept unchanged: ${e.message}');
      out[key] = value;
    }
  }
  return out;
}

void main(List<String> args) {
  if (args.length == 1 && args.single == '--self-test') {
    exit(_selfTest());
  }
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/pseudo_locale.dart <in_en.arb> <out_en_XA.arb>\n'
      '       dart run tool/pseudo_locale.dart --self-test',
    );
    exit(64);
  }
  final input = File(args[0]);
  final template = jsonDecode(input.readAsStringSync()) as Map<String, Object?>;
  final arb = pseudoArb(template, source: input.uri.pathSegments.last);
  File(
    args[1],
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(arb)}\n');
  stdout.writeln(
    'pseudo_locale: wrote ${arb.length - 2} messages to ${args[1]}',
  );
}

int _selfTest() {
  var failures = 0;
  void check(String name, bool ok, [Object? detail]) {
    if (ok) return;
    failures++;
    stderr.writeln('FAIL $name${detail == null ? '' : ': $detail'}');
  }

  // Letters are accented and the message is bracketed and padded.
  final simple = pseudoLocalize('Settings');
  check('accents', simple.startsWith('[Šéţţîñĝš'), simple);
  check('brackets', simple.startsWith('[') && simple.endsWith(']'), simple);
  final inner = simple.substring(1, simple.length - 1);
  check('expansion', inner.length >= 'Settings'.length * 1.3, simple);

  // Placeholders keep their names.
  final ph = pseudoLocalize('{who} commented on {name}');
  check('placeholders', ph.contains('{who}') && ph.contains('{name}'), ph);
  check('placeholder text', ph.contains('çöɱɱéñţéð'), ph);

  // Plural keyword, selectors, nested placeholders and `#` survive.
  final pl = pseudoLocalize(
    '{count, plural, =0{None} =1{1 file} other{{count} files, # total}}',
  );
  check('plural keyword', pl.startsWith('[{count, plural, =0{'), pl);
  check('plural selector', pl.contains(' =1{1 ƒîļé}'), pl);
  check('plural other', pl.contains(' other{{count} ƒîļéš, # ţöţåļ}'), pl);

  // Select keywords and selectors survive.
  final sel = pseudoLocalize('{kind, select, doc{Document} other{File}}');
  check(
    'select',
    sel.startsWith('[{kind, select, doc{Ðöçûɱéñţ} other{Ƒîļé}}'),
    sel,
  );

  // Formatted arguments are copied verbatim.
  final num = pseudoLocalize('Used {n, number, percent}');
  check('number', num.contains('{n, number, percent}'), num);

  // Invalid ICU is reported.
  var threw = false;
  try {
    pseudoLocalize('Broken {name');
  } on FormatException {
    threw = true;
  }
  check('invalid', threw);

  // ARB conversion drops metadata and sets the locale.
  final arb = pseudoArb({
    '@@locale': 'en',
    'hello': 'Hello {name}',
    '@hello': {
      'placeholders': {'name': {}},
    },
  });
  check('arb locale', arb['@@locale'] == 'en_XA', arb);
  check('arb metadata', !arb.containsKey('@hello'), arb);
  check(
    'arb message',
    (arb['hello'] as String).startsWith('[Ĥéļļö {name}'),
    arb,
  );

  // Empty messages stay bracketed without padding.
  check('empty', pseudoLocalize('') == '[]', pseudoLocalize(''));

  stdout.writeln(
    failures == 0
        ? 'pseudo_locale: self-test passed'
        : 'pseudo_locale: $failures self-test failure(s)',
  );
  return failures == 0 ? 0 : 1;
}
