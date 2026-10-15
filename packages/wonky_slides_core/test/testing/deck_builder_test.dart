import 'package:test/test.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart';

void main() {
  group('Given every built-in theme', () {
    for (final def in BuiltInThemes.all) {
      test('when copying ${def.key} into a deck twice then the rows and ids '
          'are identical (deterministic, 02 §2.1)', () {
        List<SlidesRow> copy() => themePackageRows(
          BuiltInThemes.package(def.key)!,
          deckId: testDeckId,
          sourceKey: SlidesIds.builtinThemeSourceKey(def.key, def.version),
          ids: SequentialIdGenerator(),
          now: testNow,
        ).$1;

        final first = copy();
        final ids = {for (final (_, c) in first) c[SlidesCols.id]};
        expect(ids, hasLength(first.length));
        expect(
          [for (final (t, c) in copy()) '$t:${c[SlidesCols.id]}'],
          [for (final (t, c) in first) '$t:${c[SlidesCols.id]}'],
        );
      });
    }
  });

  group('Given a builder', () {
    test('when adding a title slide then every instantiated layout '
        'placeholder gets an instance with the deterministic id', () {
      final b = DeckBuilder();
      final slide = b.slide(layoutKey: 'title', title: 'Hi');
      final model = b.build();
      final layout = b.layoutId('title');

      final instances = model.elementsOf(slide);
      final defs = model
          .elementsOf(layout)
          .where((e) => e.placeholderType?.isInstantiated ?? false);
      expect(instances.map((e) => e.id).toSet(), {
        for (final d in defs) SlidesIds.placeholderInstanceId(slide, d.id),
      });
      final title = instances.firstWhere(
        (e) => e.placeholderType == SlidePlaceholderType.title,
      );
      expect(title.text, deltaOf('Hi'));
      expect(title.frame, isNull);
    });

    test('when building then every row has every column of its table', () {
      final b = DeckBuilder()..slide();
      for (final (t, c) in b.rows) {
        expect(
          c.keys.toSet().containsAll(SlidesTables.columns[t]!),
          isTrue,
          reason: '$t ${c.keys.toSet().difference(SlidesTables.columns[t]!)}',
        );
      }
    });
  });

  group('Given three clients connected to a relay', () {
    test('when each edits while one is offline then all converge after '
        'syncing', () {
      final b = DeckBuilder();
      final slide = b.slide(layoutKey: 'blank');
      final shape = b.shape(slide);
      MemoryDeck deck(int seed) => MemoryDeck(
        model: b.build(),
        userId: testUserId,
        planner: const FakeSlidesPlanner(),
        ids: SequentialIdGenerator(seed),
      );
      final relay = LwwSyncRelay();
      final a = relay.connect('A', deck(100));
      final c = relay.connect('C', deck(200));
      final d = relay.connect('D', deck(300));
      relay.sync();

      d.online = false;
      a.deck.execute(const SetDeckProps(title: 'From A'));
      d.deck.execute(const SetDeckProps(title: 'From D'));
      c.deck.applyChanges([], label: 'noop');
      relay.sync();
      expect(d.deck.model.deck!.title, 'From D');

      d.online = true;
      relay.sync();

      expect(c.deck.model.deck!.title, 'From D');
      expect(a.deck.model.dump(), d.deck.model.dump());
      expect(c.deck.model.dump(), relay.dump());
      expect(a.deck.model.element(shape), isNotNull);
    });
  });
}
