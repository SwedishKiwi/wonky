import 'dart:math';

import 'package:test/test.dart';
import 'package:wonky_code/wonky_code.dart';

import '../support/property.dart';

const _state1 = '''
int sum(List<int> items) {
  var count = 0;
  for (final i in items) {
    count += i;
  }
  print("done");
  return count;
}''';

/// 07 AC-6: rename a variable, add 3 lines, delete 1.
const _state2 = '''
int sum(List<int> items) {
  var total = 0;
  for (final i in items) {
    total += i;
    if (total > 100) {
      break;
    }
  }
  return total;
}''';

void main() {
  final seed = typingSeed('element-1', 'state-2');

  group('Given a state change with a rename, 3 added lines and a deleted '
      'line (07 AC-6)', () {
    late TypingScript script;
    setUp(
      () => script = TypingScript.build(
        _state1,
        _state2,
        seed: seed,
        language: 'dart',
      ),
    );

    test('when the script ends then the text is exactly the new state', () {
      expect(script.textAt(script.durationMs), _state2);
      expect(script.stateAt(script.durationMs).done, isTrue);
    });

    test('when it starts then the old text is shown without a caret', () {
      final f = script.stateAt(0);

      expect(f.text, _state1);
      expect(f.caretOpacity, 0);
    });

    test('when the caret moves between edits then it glides', () {
      final glide = script.events.firstWhere(
        (e) => e.kind == TypingEventKind.caretTo,
      );
      final mid = script.stateAt(glide.atMs + glide.durationMs / 2);

      expect(mid.caretFrom, isNotNull);
      expect(mid.caretGlide, greaterThan(0));
      expect(mid.caretGlide, lessThan(1));
    });

    test('when the renamed words are deleted then they are backspaced and '
        'the long deleted line is selected', () {
      final deletes = script.events
          .where((e) => e.kind == TypingEventKind.delete)
          .toList();

      // 3 × "count" backspaced + one selection delete of the print line.
      expect(deletes, hasLength(3 * 5 + 1));
      expect(
        script.events.where((e) => e.kind == TypingEventKind.select),
        hasLength(1),
      );
    });

    test('when insertions are typed then keystrokes have rhythm', () {
      final inserts = script.events
          .where((e) => e.kind == TypingEventKind.insert)
          .toList();
      final gaps = {
        for (var i = 1; i < inserts.length; i++)
          inserts[i].atMs - inserts[i - 1].atMs,
      };

      expect(gaps.length, greaterThan(3));
    });

    test('when replaying every event then each frame matches a direct '
        'replay', () {
      var text = _state1;
      for (final e in script.events) {
        switch (e.kind) {
          case TypingEventKind.delete:
            text = text.substring(0, e.start) + text.substring(e.end);
          case TypingEventKind.insert || TypingEventKind.paste:
            text =
                text.substring(0, e.start) + e.text + text.substring(e.start);
          default:
        }
        // Events sharing a timestamp: compare at the last of them.
        final same = script.events.lastWhere((x) => x.atMs == e.atMs);
        if (identical(same, e)) {
          expect(script.textAt(e.atMs), text, reason: 'at ${e.atMs} ms');
        }
      }
    });

    test('when the duration is reported then it includes the caret linger', () {
      expect(
        script.durationMs,
        script.textCompleteMs + TypingScript.caretHideMs,
      );
      expect(script.scale, 1);
    });
  });

  group('Given seeded jitter', () {
    test('when building twice with the same seed then the scripts are '
        'identical', () {
      final a = TypingScript.build(_state1, _state2, seed: seed);
      final b = TypingScript.build(_state1, _state2, seed: seed);

      expect(a.events, b.events);
      expect(a.durationMs, b.durationMs);
    });

    test('when the seed differs then the rhythm differs', () {
      final a = TypingScript.build(_state1, _state2, seed: 1);
      final b = TypingScript.build(_state1, _state2, seed: 2);

      expect(a.events.map((e) => e.atMs), isNot(b.events.map((e) => e.atMs)));
    });

    test('when jitter is off then keystrokes are evenly spaced', () {
      final s = TypingScript.build(
        'a',
        'abcdefgh',
        settings: const TypingSettings(jitter: 0, cps: 20),
      );
      final inserts = s.events
          .where((e) => e.kind == TypingEventKind.insert)
          .map((e) => e.atMs)
          .toList();

      for (var i = 1; i < inserts.length; i++) {
        expect(inserts[i] - inserts[i - 1], 50);
      }
    });

    test('when the seed comes from element and state ids then it is the '
        'stable FNV-1a hash', () {
      expect(typingSeed('a', 'b'), fnv1a32('a:b'));
      expect(fnv1a32(''), 0x811C9DC5);
      expect(fnv1a32('a'), 0xE40C292C);
    });
  });

  group('Given a long deletion', () {
    test('when deleting more than backspaceMax graphemes then the span is '
        'selected, then deleted at once', () {
      final s = TypingScript.build(
        'keep();\nremove_this_whole_line_please();\nkeep2();',
        'keep();\nkeep2();',
      );
      final kinds = s.events.map((e) => e.kind).toList();

      expect(kinds, contains(TypingEventKind.select));
      expect(kinds.where((k) => k == TypingEventKind.delete).length, 1);
      expect(s.textAt(s.durationMs), 'keep();\nkeep2();');
    });

    test('when the delete mode is backspace then every grapheme is a '
        'keystroke', () {
      final s = TypingScript.build(
        'abcdefghijklmnopqrstuvwxyz',
        '',
        settings: const TypingSettings(deleteMode: TypingDeleteMode.backspace),
      );

      expect(s.keystrokes, 26);
    });
  });

  group('Given a large insertion', () {
    test('when it has at least pasteLines lines then it is pasted', () {
      final block = List.generate(12, (i) => 'line $i;').join('\n');

      final s = TypingScript.build('start', 'start\n$block');

      final paste = s.events.singleWhere(
        (e) => e.kind == TypingEventKind.paste,
      );
      final mid = s.stateAt(paste.atMs + 100);
      expect(mid.fades.single.opacity, closeTo(0.4, 1e-9));
      expect(s.textAt(s.durationMs), 'start\n$block');
    });
  });

  group('Given auto-indent', () {
    test('when a newline is typed then the next line\'s indentation comes '
        'with it', () {
      final s = TypingScript.build('{\n}', '{\n    a;\n}');

      expect(
        s.events.where((e) => e.kind == TypingEventKind.insert).first.text,
        '\n    ',
      );
      expect(s.textAt(s.durationMs), '{\n    a;\n}');
    });
  });

  group('Given a very long change', () {
    test('when the natural duration exceeds maxDurationMs then delays scale '
        'down to fit', () {
      final to = List.generate(11, (i) => 'statement_number_$i();').join('\n');

      final s = TypingScript.build(
        '',
        to,
        settings: const TypingSettings(maxDurationMs: 3000),
      );

      expect(s.scale, lessThan(1));
      expect(s.durationMs, lessThanOrEqualTo(3000 + 1));
      expect(s.textAt(s.durationMs), to);
    });

    test('when even the minimum factor is too slow then the rest is '
        'pasted', () {
      final to = List.generate(11, (i) => 'x' * 120).join('\n');

      final s = TypingScript.build(
        '',
        to,
        settings: const TypingSettings(maxDurationMs: 500, pasteLines: 100),
      );

      expect(s.scale, 0.1);
      expect(s.events.any((e) => e.kind == TypingEventKind.paste), isTrue);
      expect(s.textAt(s.durationMs), to);
    });
  });

  group('Given reverse order', () {
    test('when edits are visited bottom-up then the result is the same '
        'text', () {
      final s = TypingScript.build(
        _state1,
        _state2,
        settings: const TypingSettings(order: TypingOrder.reverse),
      );

      expect(s.textAt(s.durationMs), _state2);
      final firstEdit = s.events.firstWhere((e) => e.changesText);
      expect(firstEdit.start, greaterThan(_state1.indexOf('count +=')));
    });
  });

  group('Given an in-build from an empty box', () {
    test('when typing the first state then it ends on it', () {
      final s = TypingScript.build('', 'void main() {}');

      expect(s.textAt(0), '');
      expect(s.textAt(s.durationMs), 'void main() {}');
    });
  });

  group('Given settings JSON', () {
    test('when parsing then given keys override the base and invalid ones '
        'are ignored', () {
      final s = TypingSettings.fromJson({
        'cps': 500,
        'mode': 'morph',
        'deleteMode': 'nope',
        'pauses': {'lineEnd': 10},
      });

      expect(s.cps, 200);
      expect(s.mode, CodeTransitionMode.morph);
      expect(s.deleteMode, TypingDeleteMode.auto);
      expect(s.pauses.lineEnd, 10);
      expect(s.pauses.betweenEdits, 300);
    });

    test('when round-tripping then the settings are equal', () {
      const s = TypingSettings(
        cps: 40,
        jitter: 0.1,
        order: TypingOrder.reverse,
      );

      expect(TypingSettings.fromJson(s.toJson()), s);
    });
  });

  propertyTest('when typing random changes then the end text is the target', (
    random,
    run,
  ) {
    final from = _code(random);
    final to = _code(random);

    final s = TypingScript.build(
      from,
      to,
      seed: random.nextInt(1 << 30),
      settings: TypingSettings(
        order: random.nextBool() ? TypingOrder.document : TypingOrder.reverse,
        pasteLines: 2 + random.nextInt(4),
      ),
    );

    expect(s.textAt(s.durationMs), to);
    expect(s.textAt(0), from);
    for (var i = 1; i < s.events.length; i++) {
      expect(s.events[i].atMs, greaterThanOrEqualTo(s.events[i - 1].atMs));
    }
  }, runs: 60);
}

String _code(Random r) => List.generate(
  r.nextInt(6),
  (_) => List.generate(
    r.nextInt(5),
    (_) => ['a', 'bb', '(', ');', 'if', '  ', 'x = 1', '"s"'][r.nextInt(8)],
  ).join(),
).join('\n');
