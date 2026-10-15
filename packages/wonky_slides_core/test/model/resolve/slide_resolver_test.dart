import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_kit/rows.dart';

import '../../support/planner_fixture.dart';

void main() {
  final f = PlannerFixture();

  group('Given the fixture deck and a resolver', () {
    late DeckModel m;
    late SlideResolver resolver;
    setUp(() {
      m = f.session().model;
      resolver = SlideResolver(m);
    });

    test('when resolving a content slide then placeholder instances take the '
        'layout geometry and text styles', () {
      final r = resolver.resolve(f.g1)!;

      final body = r.elements.firstWhere(
        (e) => e.placeholderType == SlidePlaceholderType.body,
      );
      final def = m.element(body.record.placeholderOf!)!;
      expect(body.frame, def.frame);
      expect(body.textStyles!.defaultStyle, 'body');
      expect(r.layout!.key, 'titleBody');
      expect(r.theme.appearance, SlideAppearance.light);
      expect(r.number, 4);
    });

    test(
      'when a placeholder is empty then the prompt comes from the layout',
      () {
        final r = resolver.resolve(f.g1)!;

        final body = r.elements.firstWhere(
          (e) => e.placeholderType == SlidePlaceholderType.body,
        );
        expect(body.prompt, isNotNull);
        final title = r.elements.firstWhere(
          (e) => e.placeholderType == SlidePlaceholderType.title,
        );
        expect(title.prompt, isNull, reason: 'the title has text');
      },
    );

    test(
      'when resolving a group then children are mapped into slide space',
      () {
        final r = resolver.resolve(f.s3)!;

        final g = r.element(f.grp)!;
        expect(g.children.map((c) => c.id), [f.child1, f.child2]);
        expect(r.element(f.child1)!.frame, const SuRect(1000, 100, 100, 100));
      },
    );

    test('when the group is moved and scaled then its children follow', () {
      m.applyChanges([
        RowChange.update(
          SlidesTables.slideElement,
          f.grp,
          {ElementCols.x: 1000.0, ElementCols.width: 300.0},
          {ElementCols.x: 0.0, ElementCols.width: 600.0},
        ),
      ]);

      final c = resolver.resolve(f.s3)!.element(f.child2)!;
      expect(c.frame, const SuRect(400, 300, 200, 100));
    });

    test('when slide numbers are on then the number field is drawn with the '
        'slide number, except on title slides', () {
      m.applyChanges([
        RowChange.update(
          SlidesTables.deck,
          m.deckId,
          {DeckCols.showSlideNumbers: false},
          {DeckCols.showSlideNumbers: true},
        ),
      ]);

      final content = resolver.resolve(f.s2)!;
      final title = resolver.resolve(f.title)!;
      expect(
        content.masterElements
            .where((e) => e.fieldText != null)
            .map((e) => e.fieldText),
        ['2'],
      );
      expect(title.masterElements.where((e) => e.fieldText != null), isEmpty);
    });

    test('when the slide is unchanged then the resolution is memoized, and a '
        'theme change invalidates it', () {
      final a = resolver.resolve(f.s3);
      expect(identical(resolver.resolve(f.s3), a), isTrue);

      final deck = f.session();
      final r2 = SlideResolver(deck.model);
      final before = r2.resolve(f.s3)!;
      deck.execute(UpdateTheme(f.themeId, themeName: 'Renamed'));

      expect(identical(r2.resolve(f.s3), before), isFalse);
    });

    test(
      'when resolving for the dark appearance then the theme resolves dark',
      () {
        final r = resolver.resolve(f.s3, appearance: SlideAppearance.dark)!;

        expect(r.theme.appearance, SlideAppearance.dark);
      },
    );

    test('when a slide has its own background then it wins over the theme', () {
      m.applyChanges([
        RowChange.update(
          SlidesTables.slide,
          f.s3,
          {SlidesCols.backgroundJson: null},
          {
            SlidesCols.backgroundJson:
                '{"v":1,"fill":{"v":1,"type":"solid","color":"#112233"}}',
          },
        ),
      ]);

      final bg = resolver.resolve(f.s3)!.background.fill;
      expect(
        bg,
        isA<ResolvedSolidFill>().having((s) => s.color, 'color', 0xff112233),
      );
    });
  });

  group('Given text style resolution', () {
    test(
      'when a run is bold in a quote paragraph then the quote style and a '
      'bold weight apply, and box defaults only without a paragraph style',
      () {
        final m = f.session().model;
        final theme = SlideResolver(
          m,
        ).resolveTheme(m.defaultTheme, SlideAppearance.light);
        final resolver = TextStyleResolver();
        final styles = resolver.resolve(
          theme,
          box: const BoxTextStyle(defaults: {'size': 99, 'color': '#ff0000'}),
          defaultStyle: 'body',
        );

        final plain = resolver.run(theme, styles);
        final quoted = resolver.run(
          theme,
          styles,
          block: const {'style': 'quote'},
          inline: const {'bold': true},
        );

        expect(plain.size, 99);
        expect(plain.color, 0xffff0000);
        expect(quoted.size, theme.textStyle('quote').size);
        expect(quoted.font.weight, greaterThanOrEqualTo(600));
        expect(
          identical(
            resolver.resolve(
              theme,
              box: const BoxTextStyle(
                defaults: {'size': 99, 'color': '#ff0000'},
              ),
              defaultStyle: 'body',
            ),
            styles,
          ),
          isTrue,
        );
      },
    );
  });
}
