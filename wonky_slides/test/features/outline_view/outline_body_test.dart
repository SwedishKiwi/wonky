import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/outline_view/outline_body.dart';

String _delta(List<Map<String, Object?>> ops) => jsonEncode(ops);

/// The outline's paragraph model (Slides 04 §10; SL-34).
void main() {
  group('Given a body with formatted runs and two levels', () {
    late OutlineBody body;
    setUp(() {
      body = OutlineBody.parse(
        _delta([
          {'insert': 'Make '},
          {
            'insert': 'collaboration',
            'attributes': {'bold': true},
          },
          {'insert': ' easy'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'},
          },
          {'insert': 'Offline'},
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1},
          },
        ]),
      );
    });

    test('when parsed then each paragraph is a line with its level', () {
      expect(body.lines, ['Make collaboration easy', 'Offline']);
      expect(body[0].level, 0);
      expect(body[1].level, 1);
      expect(body[0].runs[1].bold, isTrue);
    });

    test('when text after the bold word changes then the bold run is '
        'kept', () {
      final next = body.withText(0, 'Make collaboration effortless');

      expect(next[0].runs.map((r) => r.text), [
        'Make ',
        'collaboration',
        ' effortless',
      ]);
      expect(next[0].runs[1].bold, isTrue);
      expect(next[0].block, {'list': 'bullet'});
    });

    test('when text is typed at the end of the bold word then it is bold '
        'too', () {
      final next = body.withText(0, 'Make collaborations easy');

      expect(next[0].runs[1].text, 'collaborations');
      expect(next[0].runs[1].bold, isTrue);
    });

    test('when a line is split then the tail keeps the block attributes '
        'and round-trips through JSON', () {
      final next = body.split(0, 5);

      expect(next.lines, ['Make ', 'collaboration easy', 'Offline']);
      expect(next[1].block, {'list': 'bullet'});
      expect(OutlineBody.parse(next.toJson()).lines, next.lines);
    });

    test('when line 1 is joined onto line 0 then one line remains with the '
        'first block', () {
      final next = body.join(1);

      expect(next.lines, ['Make collaboration easyOffline']);
      expect(next[0].level, 0);
    });

    test('when levels change, lines move and get removed then the body '
        'follows', () {
      expect(body.withLevel(1, 0)[1].level, 0);
      expect(body.withLevel(0, 12)[0].level, 8);
      expect(body.move(1, 0).lines, ['Offline', 'Make collaboration easy']);
      expect(body.removeAt(0).lines, ['Offline']);
      expect(body.titleOf(0)[0].block, isEmpty);
    });

    test('when written as Markdown then bold is kept', () {
      expect(body[0].toMarkdown(), 'Make **collaboration** easy');
    });
  });

  group('Given empty or malformed bodies', () {
    test('when parsed then there is one empty line', () {
      for (final json in [null, '', 'nope', '{}']) {
        final b = OutlineBody.parse(json);
        expect(b.lines, [''], reason: '$json');
        expect(b.isBlank, isTrue);
      }
    });

    test('when a blank body is concatenated then only the new lines '
        'remain, one level deeper', () {
      final b = OutlineBody.parse(
        null,
      ).concat(OutlineBody([OutlineParagraph.plain('A')]), levelDelta: 1);
      expect(b.lines, ['A']);
      expect(b[0].level, 1);
    });
  });
}
