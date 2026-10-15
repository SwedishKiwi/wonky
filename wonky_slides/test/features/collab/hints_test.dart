import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/collab/slides_hints.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/scene.dart' show TextBody;

import 'collab_rig.dart';

Map<String, Object?> _textHint(String elementId, String text) => {
  't': 'text',
  'target': {'kind': 'text', 'elementId': elementId},
  'delta': jsonDecode(TextBody.plain(text).toJson()),
  'diff': null,
  'hlcMillis': 1,
};

void main() {
  group('Given two users on one deck', () {
    testWidgets('when this user types in a text box then the body is sent as '
        'a text hint, at most 4 per second', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.doubleClick(tester, 400, 740);

      r.text.active!.insertText('!');
      await tester.pump();
      r.text.active!.insertText('?');
      await tester.pump(const Duration(milliseconds: 300));

      final hints = r.sentHints.where((h) => h['t'] == 'text').toList();
      expect(hints, isNotEmpty);
      expect(hints.length, lessThanOrEqualTo(2));
      final last = hints.last;
      expect((last['target']! as Map)['elementId'], r.f.box);
      final hinted = TextBody.fromJson(jsonEncode(last['delta'])).plainText;
      expect(hinted, contains('!?'));
      await r.close(tester);
    });

    testWidgets('when Anna\'s typing hint arrives then her text shows in the '
        'box before the sync, and the synced text replaces it without a '
        'change', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor(editing: r.claim(r.f.box)));

      await r.hints(tester, 'anna', [_textHint(r.f.box, 'Hello Anna')]);

      expect(r.collab.hints.textOf(r.f.box)?.sessionId, 'anna');
      expect(r.stageText(tester, r.f.box), 'Hello Anna');
      expect(r.textOf(r.f.box), 'Hello world\n');

      // The synced write of the same text arrives: the hint goes, the
      // stage shows the same text.
      r.d.session.applyRemote(
        r.d.session.planner
            .plan(
              SetText(
                ElementText(r.f.box),
                TextBody.plain('Hello Anna').toJson(),
              ),
              r.model,
              r.d.session.planContext(),
            )
            .changes,
      );
      await tester.pump();

      expect(r.collab.hints.textOf(r.f.box), isNull);
      expect(r.stageText(tester, r.f.box), 'Hello Anna');
      await r.close(tester);
    });

    testWidgets('when Anna stops editing then her hint goes 5 s later', (
      tester,
    ) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor(editing: r.claim(r.f.box)));
      await r.hints(tester, 'anna', [_textHint(r.f.box, 'Draft')]);
      expect(r.stageText(tester, r.f.box), 'Draft');

      await r.move(tester, 'anna', r.cursor());
      await tester.pump(const Duration(seconds: 2));
      expect(r.collab.hints.textOf(r.f.box), isNotNull);
      await tester.pump(SlidesHints.textLinger);
      await tester.pump(const Duration(seconds: 1));

      expect(r.collab.hints.textOf(r.f.box), isNull);
      expect(r.stageText(tester, r.f.box), 'Hello world');
      await r.close(tester);
    });

    testWidgets('when this user starts editing a hinted box then the local '
        'edit wins', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());
      await r.hints(tester, 'anna', [_textHint(r.f.box, 'Theirs')]);
      expect(r.collab.hints.textOf(r.f.box), isNotNull);

      await r.doubleClick(tester, 400, 740);

      expect(r.text.elementId, r.f.box);
      expect(r.collab.hints.textOf(r.f.box), isNull);
      await r.close(tester);
    });

    testWidgets('when Anna drags an element then its live frame is outlined '
        'until 2 s pass', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.join(tester, CollabRig.anna, r.cursor());

      await r.hints(tester, 'anna', [
        {
          't': 'transform',
          'slideId': r.f.slide,
          'frames': {
            r.f.plain: [100, 100, 300, 200, 0],
          },
        },
      ]);

      final t = r.collab.hints.transforms['anna'];
      expect(t?.frames[r.f.plain], const ElementFrame(100, 100, 300, 200));
      await tester.pump(const Duration(seconds: 3));
      expect(r.collab.hints.transforms, isEmpty);
      await r.close(tester);
    });

    testWidgets('when this user drags an element then the live frames are '
        'sent as transform hints', (tester) async {
      final r = await CollabRig.pump(tester);
      await r.click(tester, 1450, 250);
      final g = await tester.startGesture(r.at(tester, 1450, 250));
      for (var i = 1; i <= 4; i++) {
        await g.moveTo(r.at(tester, 1450 - i * 40.0, 250 + i * 20.0));
        await tester.pump(const Duration(milliseconds: 120));
      }

      final hints = r.sentHints.where((h) => h['t'] == 'transform').toList();
      expect(hints, isNotEmpty);
      expect((hints.last['frames']! as Map).keys, [r.f.plain]);
      expect((await r.lastSent(tester)).transform, isTrue);

      await g.up();
      await tester.pump();
      expect((await r.lastSent(tester)).transform, isFalse);
      await r.close(tester);
    });

    testWidgets('when a hint is from this session or for an unknown element '
        'then it is ignored', (tester) async {
      final r = await CollabRig.pump(tester);

      await r.hints(tester, 'me', [_textHint(r.f.box, 'Echo')]);
      await r.hints(tester, 'anna', [_textHint('nope', 'Unknown')]);

      expect(r.collab.hints.text, isEmpty);
      // Silence the unused widget import.
      expect(const SizedBox(), isA<Widget>());
      await r.close(tester);
    });
  });
}
