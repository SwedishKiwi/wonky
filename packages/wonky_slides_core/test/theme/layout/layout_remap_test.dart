import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

RemapInstance inst(String id, SlidePlaceholderType t, {bool empty = false}) =>
    RemapInstance(id: id, type: t, isEmpty: empty);
RemapTarget target(String id, SlidePlaceholderType t) =>
    RemapTarget(id: id, type: t);

const title = SlidePlaceholderType.title;
const body = SlidePlaceholderType.body;
const subtitle = SlidePlaceholderType.subtitle;
const picture = SlidePlaceholderType.picture;

void main() {
  group('Given a two-column slide switched to title and content (05 §5.4)', () {
    final plan = LayoutRemapper.remap(
      [inst('t', title), inst('b1', body), inst('b2', body)],
      [target('T', title), target('B', body)],
    );

    test('when remapping then matches are re-pointed in order', () {
      expect(plan.repoint, {'t': 'T', 'b1': 'B'});
    });

    test(
      'when remapping then the unmatched body with content stays in place',
      () {
        expect(plan.materialize, ['b2']);
        expect(plan.delete, isEmpty);
        expect(plan.create, isEmpty);
      },
    );
  });

  group('Given an empty unmatched instance', () {
    test('when remapping then it is deleted', () {
      final plan = LayoutRemapper.remap(
        [inst('t', title), inst('s', subtitle, empty: true)],
        [target('T', title), target('B', body)],
      );
      expect(plan.delete, ['s']);
      expect(plan.create, ['B']);
    });
  });

  group('Given a layout with slide number and footer', () {
    test('when remapping then those placeholders are never instantiated', () {
      final plan = LayoutRemapper.remap(const [], [
        target('T', title),
        target('N', SlidePlaceholderType.slideNumber),
        target('F', SlidePlaceholderType.footer),
      ]);
      expect(plan.create, ['T']);
    });
  });

  group('Given the same layout applied again', () {
    test('when remapping then every instance is re-pointed to itself', () {
      final plan = LayoutRemapper.remap(
        [inst('t', title), inst('b', body, empty: true)],
        [target('T', title), target('B', body)],
      );
      expect(plan.repoint, {'t': 'T', 'b': 'B'});
      expect(
        plan.materialize.isEmpty && plan.delete.isEmpty && plan.create.isEmpty,
        isTrue,
      );
    });
  });

  group('Given another theme\'s layouts (05 §9 Apply theme)', () {
    final candidates = [
      for (final l in BuiltInLayouts.designGrid)
        LayoutCandidate(id: 'id-${l.key}', key: l.key, types: l.types),
    ];

    test('when the key exists then the layout with the same key is chosen', () {
      final m = LayoutMatcher.match(
        key: 'quote',
        types: const [],
        candidates: candidates,
      );
      expect(m!.key, 'quote');
    });

    test('when the key is unknown then the best signature match is chosen', () {
      final m = LayoutMatcher.match(
        key: 'custom-photo',
        types: const [picture, title, body],
        candidates: candidates,
      );
      expect(m!.key, 'imageLeft');
    });

    test(
      'when nothing matches a slide with placeholders then titleBody is chosen',
      () {
        final m = LayoutMatcher.match(
          key: null,
          types: const [SlidePlaceholderType.table],
          candidates: candidates,
        );
        expect(m!.key, 'titleBody');
      },
    );

    test(
      'when a layout without placeholders has no key match then blank is chosen',
      () {
        final m = LayoutMatcher.match(
          key: 'mine',
          types: const [],
          candidates: candidates,
        );
        expect(m!.key, 'blank');
      },
    );

    test('when there are no candidates then nothing is chosen', () {
      expect(
        LayoutMatcher.match(
          key: 'title',
          types: const [],
          candidates: const [],
        ),
        isNull,
      );
    });

    test(
      'when remapping every built-in layout to the same key in another theme then nothing is lost',
      () {
        final wonky = BuiltInThemes.package('wonky')!.masters.single;
        final swiss = BuiltInThemes.package('swiss')!.masters.single;
        for (final layout in wonky.layouts) {
          final target = swiss.layout(layout.key!)!;
          final plan = LayoutRemapper.remap(
            [
              for (final p in layout.placeholders)
                if (p.placeholderType!.isInstantiated)
                  inst(p.partKey, p.placeholderType!),
            ],
            [
              for (final p in target.placeholders)
                RemapTarget(id: p.partKey, type: p.placeholderType!),
            ],
          );
          expect(plan.materialize, isEmpty, reason: layout.key);
          expect(plan.delete, isEmpty, reason: layout.key);
          expect(plan.create, isEmpty, reason: layout.key);
        }
      },
    );
  });
}
