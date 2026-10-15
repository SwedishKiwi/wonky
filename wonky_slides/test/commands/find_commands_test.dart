import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/find/find_controller.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';

import '../harness/deck_harness.dart';

/// "plan" in a title, a text box, a table cell and notes over three slides.
class _Fixture {
  _Fixture() {
    s1 = b.slide(layoutKey: 'title', title: 'The plan');
    // After the title placeholder (its own z key space).
    box = b.element(
      s1,
      ElementKind.text,
      columns: {
        SlidesCols.text: deltaOf('Plan B is a plan'),
        ElementCols.zKey: 'a5',
      },
    );
    s2 = b.slide(layoutKey: 'blank', notes: 'Explain the plan');
    final (t, rows, cols) = b.table(s2);
    table = t;
    b.cell(t, rows[0], cols[0], 'plan');
    s3 = b.slide(layoutKey: 'blank', skipped: true);
    b.textBox(s3, 'skipped plan');
  }

  final DeckBuilder b = DeckBuilder(title: 'Find');
  late final String s1, box, s2, table, s3;
}

class _Locks extends TextEditLocks {
  _Locks(this.held);
  final String held;

  @override
  String? heldBy(String elementId) => elementId == held ? 'Anna' : null;
}

String _plain(String? json) => SlidesText.plainText(json).trim();

void main() {
  late _Fixture f;
  late DeckHarness d;

  setUp(() {
    f = _Fixture();
    d = DeckHarness.open(fixture: f.b);
  });

  tearDown(() => d.dispose());

  Map<String, Object?> data(CommandResult r) =>
      (r.data! as Map).cast<String, Object?>();

  group('Given a deck with "plan" on slides, in a table and in notes', () {
    test('when the find bar opens with a query then it counts the matches '
        'in presentation order', () async {
      final r = await d.run('slides.find.open', {'query': 'plan'});
      expect(r.isOk, isTrue);
      final f0 = DeckFindController.of(d.editor);
      expect(f0.barOpen, isTrue);
      expect(data(r)['matches'], 6);
      expect(
        [for (final m in f0.matches) m.slideId],
        [f.s1, f.s1, f.s1, f.s2, f.s2, f.s3],
      );
    });

    test('when stepping with next then the match\'s slide becomes current '
        'and its element is selected; previous wraps around', () async {
      d.editor.setCurrentSlide(f.s1);
      await d.run('slides.find.open', {'query': 'plan'});
      final n1 = await d.run('slides.find.next');
      expect(data(n1)['current'], 1);
      await d.run('slides.find.next');
      final n3 = await d.run('slides.find.next');
      expect(data(n3)['current'], 3);
      expect(d.editor.selectedElementIds, [f.box]);
      final n4 = await d.run('slides.find.next');
      expect(data(n4)['slideId'], f.s2);
      expect(d.editor.currentSlideId, f.s2);
      final f0 = DeckFindController.of(d.editor);
      await d.run('slides.find.next');
      await d.run('slides.find.next');
      expect(f0.currentIndex, 5);
      await d.run('slides.find.next');
      expect(f0.currentIndex, 0, reason: 'wraps to the first match');
      await d.run('slides.find.previous');
      expect(f0.currentIndex, 5);
    });

    test('when Replace all runs then every body changes in one undo step '
        'with the stated message, and undo restores them', () async {
      final before = d.model.dump();
      final r = await d.run('slides.find.replaceAll', {
        'find': 'plan',
        'replace': 'goal',
      });
      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(data(r)['replaced'], 6);
      expect(data(r)['message'], 'Replaced 6 instances of “plan” with “goal”');
      expect(_plain(d.model.element(f.box)!.text), 'goal B is a goal');
      expect(_plain(d.model.slide(f.s2)!.notes), 'Explain the goal');
      expect(_plain(d.model.cellsOf(f.table).single.text), 'goal');
      expect(d.undoLabels, ['slides.find.replaceAll']);
      await d.undo();
      expect(d.model.dump(), before);
    });

    test('when matching case, whole words, without notes and skipped slides '
        'then only those matches are replaced', () async {
      final r = await d.run('slides.find.replaceAll', {
        'find': 'plan',
        'replace': 'idea',
        'matchCase': true,
        'wholeWords': true,
        'includeNotes': false,
        'includeSkipped': false,
      });
      expect(data(r)['replaced'], 3);
      expect(_plain(d.model.element(f.box)!.text), 'Plan B is a idea');
      expect(_plain(d.model.slide(f.s2)!.notes), 'Explain the plan');
    });

    test('when a body is edited by someone else then Replace all skips it '
        'and reports it', () async {
      textEditingOf(d.editor).locks = _Locks(f.box);
      final r = await d.run('slides.find.replaceAll', {
        'find': 'plan',
        'replace': 'goal',
      });
      expect(data(r)['replaced'], 4);
      expect(data(r)['skipped'], 2);
      expect(
        data(r)['skippedMessage'],
        '2 matches in text Anna is editing were skipped',
      );
      expect(_plain(d.model.element(f.box)!.text), 'Plan B is a plan');
    });

    test('when Replace runs then the current match changes in one step and '
        'the next match becomes current', () async {
      d.editor.setCurrentSlide(f.s2);
      await d.run('slides.find.open', {'query': 'plan'});
      await d.run('slides.find.next');
      final f0 = DeckFindController.of(d.editor);
      expect(f0.currentMatch!.slideId, f.s2);
      final r = await d.run('slides.find.replace', {'replace': 'goal'});
      expect(data(r)['replaced'], 1);
      expect(_plain(d.model.cellsOf(f.table).single.text), 'goal');
      expect(f0.matches, hasLength(5));
      expect(f0.currentMatch!.inNotes, isTrue);
      expect(d.undoLabels, ['slides.find.replace']);
    });

    test('when using a regular expression then groups are inserted', () async {
      await d.run('slides.find.replaceAll', {
        'find': r'(\w+) B',
        'replace': r'B $1',
        'useRegex': true,
      });
      expect(_plain(d.model.element(f.box)!.text), 'B Plan is a plan');
    });

    test('when the regular expression is invalid then the command fails '
        'with the message', () async {
      final r = await d.run('slides.find.next', {
        'query': '(',
        'useRegex': true,
      });
      expect(r.status, CommandStatus.failed);
      expect(r.message, 'This regular expression is not valid');
    });

    test('when the scope is the current slide then other slides are not '
        'searched', () async {
      d.editor.setCurrentSlide(f.s2);
      final r = await d.run('slides.find.replaceAll', {
        'find': 'plan',
        'replace': 'x',
        'scope': 'current',
      });
      expect(data(r)['replaced'], 2);
      expect(_plain(d.model.element(f.box)!.text), 'Plan B is a plan');
    });

    test(
      'when the panel opens and closes then the find state follows',
      () async {
        await d.run('slides.find.openReplace', {
          'find': 'plan',
          'replace': 'goal',
        });
        final f0 = DeckFindController.of(d.editor);
        expect((f0.panelOpen, f0.replacement), (true, 'goal'));
        expect(
          d.services.dispatcher.stateOf('slides.find.close').enabled,
          true,
        );
        await d.run('slides.find.close');
        expect(f0.isOpen, isFalse);
      },
    );
  });
}
