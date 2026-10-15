import 'package:test/test.dart';
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_sync_models/ids.dart';

/// `ImportTheme.themeEntry` (SL-17): *Duplicate theme* and *Import theme
/// from a presentation* copy every row of a deck theme (05 §9).
void main() {
  MemoryDeck open(DeckBuilder b) => MemoryDeck(
    model: b.build(),
    userId: b.userId,
    planner: const SlidesPlanner(),
    ids: SequentialIdGenerator(5000),
  );

  int rowsOfTheme(DeckModel m, String themeId) {
    var n = 1;
    for (final master in m.mastersOf(themeId)) {
      n += 1 + m.allElementsOf(master.id).length;
      for (final l in m.layoutsOf(master.id)) {
        n += 1 + m.allElementsOf(l.id).length;
      }
    }
    return n;
  }

  group('Given a deck with the Paper theme', () {
    late DeckBuilder b;
    late MemoryDeck deck;
    late DeckThemeRec paper;

    setUp(() {
      b = DeckBuilder()..theme('paper');
      b.slide(layoutKey: 'title', title: 'Hi');
      deck = open(b);
      paper = deck.model.themes.single;
    });

    test('when the theme is duplicated then a renamed copy with fresh ids '
        'and every master, layout and element is added in one plan', () {
      final entry = SlidesClipboardCodec.themeEntry(deck.model, paper);
      final plan = deck.execute(
        ImportTheme(themeEntry: entry, themeName: 'Paper copy'),
      );

      expect(plan.label, 'Duplicate theme');
      final id = plan.result['themeId']! as String;
      expect(id, isNot(paper.id));
      final copy = deck.model.theme(id)!;
      expect(copy.name, 'Paper copy');
      expect(copy.sourceKey, isNull);
      expect(copy.themeColumns, paper.themeColumns);
      expect(rowsOfTheme(deck.model, id), rowsOfTheme(deck.model, paper.id));
      final layouts = plan.result['layoutIds']! as Map;
      expect(layouts.keys, containsAll(['title', 'titleBody', 'blank']));
      // Layout placeholders still refine the copy's own master placeholders.
      for (final l in deck.model.indexes.themes.layoutsOfTheme(id)) {
        for (final e in deck.model.allElementsOf(l.id)) {
          final of = e.placeholderOf;
          if (of == null) continue;
          expect(deck.model.element(of)?.masterId, isNotNull);
          expect(
            deck.model.indexes.themes
                .themeOf(deck.model.master(deck.model.element(of)!.masterId!)!)
                ?.id,
            id,
          );
        }
      }
      // Slides keep their theme; the default theme is unchanged.
      expect(deck.model.deck!.themeId, paper.id);
    });

    test('when an empty name is given then the planner refuses', () {
      final entry = SlidesClipboardCodec.themeEntry(deck.model, paper);
      expect(
        () => deck.execute(ImportTheme(themeEntry: entry, themeName: ' ')),
        throwsA(isA<PlanException>()),
      );
    });

    test('when it is imported into another deck twice then the second import '
        'adds nothing (deterministic ids, 05 §9)', () {
      final other = open(
        DeckBuilder(deckId: '01923456-789a-7bcd-8ef0-1234567890ff')
          ..slide(layoutKey: 'title', title: 'Other'),
      );
      const item = '01923456-789a-7bcd-8ef0-123456789abc';
      final source = SlidesIds.deckThemeSourceKey(item, paper.id);
      final entry = SlidesClipboardCodec.themeEntry(deck.model, paper);
      final first = other.execute(
        ImportTheme(themeEntry: entry, sourceKey: source),
      );
      final id = first.result['themeId']! as String;

      expect(first.label, 'Import theme');
      expect(id, SlidesIds.themeCopyId(other.model.deckId, source));
      expect(other.model.theme(id)!.sourceKey, source);
      expect(other.model.theme(id)!.name, paper.name);
      expect(rowsOfTheme(other.model, id), rowsOfTheme(deck.model, paper.id));
      final again = other.planner.plan(
        ImportTheme(themeEntry: entry, sourceKey: source),
        other.model,
        other.planContext(),
      );
      expect(again.changes, isEmpty);
      expect(other.model.count(SlidesTables.deckTheme), 2);
    });
  });
}
