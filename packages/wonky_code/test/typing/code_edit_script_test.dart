import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

import '../support/property.dart';

void main() {
  group('Given two equal states', () {
    test('when computing the script then it is empty', () {
      final s = CodeEditScript.compute('a\nb', 'a\nb');

      expect(s.isEmpty, isTrue);
      expect(s.apply(), 'a\nb');
    });
  });

  group('Given a renamed variable', () {
    const from = 'final count = 1;\nprint(count);';
    const to = 'final total = 1;\nprint(total);';

    test('when computing the script then each line gets one whole-word '
        'edit', () {
      final s = CodeEditScript.compute(from, to, language: 'dart');

      expect(s.edits, hasLength(2));
      expect(s.edits[0].newText, 'total');
      expect(from.substring(s.edits[0].oldStart, s.edits[0].oldEnd), 'count');
      expect(s.edits[0].kind, CodeEditKind.replace);
      expect(s.apply(), to);
    });

    test('when computing the script then the paired lines count as '
        'changed', () {
      final s = CodeEditScript.compute(from, to);

      expect((s.stats.added, s.stats.removed, s.stats.changed), (0, 0, 2));
    });
  });

  group('Given a small change inside a word', () {
    test('when less than half of the word changes then only the letters are '
        'edited', () {
      final s = CodeEditScript.compute('items.length', 'itemz.length');

      expect(s.edits.single.newText, 'z');
      expect(s.edits.single.oldEnd - s.edits.single.oldStart, 1);
    });
  });

  group('Given edits close together on one line', () {
    test('when fewer than 3 kept characters separate them then they '
        'merge', () {
      final s = CodeEditScript.compute('f(a, b)', 'f(x, y)');

      expect(s.edits, hasLength(1));
      expect(s.apply(), 'f(x, y)');
    });
  });

  group('Given added and removed lines', () {
    const from = 'void main() {\n  a();\n  b();\n}';
    const to = 'void main() {\n  a();\n  log();\n  log2();\n  b();\n}';

    test('when lines are inserted then they are one insert edit at the end '
        'of the line before (Enter, then the lines)', () {
      final s = CodeEditScript.compute(from, to);

      expect(s.edits.single.kind, CodeEditKind.insert);
      expect(s.edits.single.oldStart, from.indexOf('a();') + 4);
      expect(s.edits.single.newText, '\n  log();\n  log2();');
      expect(s.stats.added, 2);
      expect(s.apply(), to);
    });

    test('when lines are deleted then they are one delete edit', () {
      final s = CodeEditScript.compute(to, from);

      expect(s.edits.single.kind, CodeEditKind.delete);
      expect(s.stats.removed, 2);
      expect(s.apply(), from);
    });

    test('when the last line is deleted then the line break before it '
        'goes too', () {
      final s = CodeEditScript.compute('a\nb\nzzzz', 'a\nb');

      expect(s.edits.single.oldStart, 3);
      expect(s.apply(), 'a\nb');
    });

    test('when a line is appended then the line break is inserted before '
        'it', () {
      final s = CodeEditScript.compute('a\nb', 'a\nb\nnew line');

      expect(s.edits.single.newText, '\nnew line');
      expect(s.apply(), 'a\nb\nnew line');
    });
  });

  group('Given a line replaced by an unrelated one', () {
    test('when computing the script then the line is replaced whole', () {
      final s = CodeEditScript.compute(
        'a\nreturn compute(x);\nb',
        'a\n// TODO\nb',
      );

      expect(s.edits.single.newText, '// TODO');
      expect(s.stats.added, 1);
      expect(s.stats.removed, 1);
    });
  });

  group('Given an empty old state', () {
    test('when typing in the first state then it is one insert', () {
      final s = CodeEditScript.compute('', 'a\nb');

      expect(s.edits.single.oldStart, 0);
      expect(s.apply(), 'a\nb');
    });
  });

  propertyTest(
    'when applying the script of random edits then the old text becomes the '
    'new one',
    (random, run) {
      final from = _randomCode(random);
      final to = _mutate(random, from);

      final s = CodeEditScript.compute(from, to, language: 'dart');

      expect(s.apply(), to, reason: 'from: ${_q(from)}\nto: ${_q(to)}');
      for (var i = 1; i < s.edits.length; i++) {
        expect(
          s.edits[i].oldStart,
          greaterThanOrEqualTo(s.edits[i - 1].oldEnd),
        );
      }
    },
    runs: 150,
  );
}

String _q(String s) => s.replaceAll('\n', r'\n');

const _words = [
  'final',
  'var',
  'count',
  'total',
  'x',
  'items',
  'print',
  '(',
  ')',
  '{',
  '}',
  ';',
  '=',
  '+',
  '1',
  '42',
  "'hi'",
  '// note',
  'return',
  '漢字',
  '😀',
  '\t',
];

String _randomCode(Random r) {
  final lines = r.nextInt(8);
  return List.generate(lines, (_) {
    final n = r.nextInt(6);
    return List.generate(
      n,
      (_) => _words[r.nextInt(_words.length)],
    ).join(r.nextBool() ? ' ' : '');
  }).join('\n');
}

String _mutate(Random r, String s) {
  var out = s;
  final n = 1 + r.nextInt(5);
  for (var i = 0; i < n; i++) {
    final pos = out.isEmpty ? 0 : r.nextInt(out.length + 1);
    switch (r.nextInt(4)) {
      case 0:
        out =
            out.substring(0, pos) +
            _words[r.nextInt(_words.length)] +
            out.substring(pos);
      case 1:
        final end = (pos + r.nextInt(6)).clamp(0, out.length);
        out = out.substring(0, pos) + out.substring(end);
      case 2:
        out = '${out.substring(0, pos)}\n${out.substring(pos)}';
      default:
        final lines = out.split('\n')..shuffle(r);
        out = lines.join('\n');
    }
  }
  // Never split a surrogate pair.
  return out.replaceAll(
    RegExp(
      r'[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]',
    ),
    '',
  );
}
