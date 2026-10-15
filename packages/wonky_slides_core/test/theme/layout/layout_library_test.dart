import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given the layout library', () {
    test(
      'when listing layouts then the 16 stable keys are in picker order',
      () {
        expect([
          for (final l in BuiltInLayouts.designGrid) l.key,
        ], builtInLayoutKeys);
        expect(builtInLayoutKeys, hasLength(16));
      },
    );

    test('when reading titleBody then its geometry matches 05 §4', () {
      final l = BuiltInLayouts.byKey('titleBody')!;
      expect(l.placeholders.map((p) => (p.type, p.rect)), [
        (SlidePlaceholderType.title, const SuRect(120, 72, 1680, 144)),
        (SlidePlaceholderType.body, const SuRect(120, 264, 1680, 720)),
      ]);
    });

    test('when reading comparison then it has two heading/body pairs', () {
      final l = BuiltInLayouts.byKey('comparison')!;
      expect(l.types, [
        SlidePlaceholderType.title,
        SlidePlaceholderType.subtitle,
        SlidePlaceholderType.body,
        SlidePlaceholderType.subtitle,
        SlidePlaceholderType.body,
      ]);
    });

    test('when reading blank then it has no placeholders', () {
      expect(BuiltInLayouts.byKey('blank')!.placeholders, isEmpty);
    });

    test(
      'when reading the master then it has title, body, slide number and footer',
      () {
        expect(
          [for (final p in BuiltInLayouts.masterDesignGrid) p.type],
          [
            SlidePlaceholderType.title,
            SlidePlaceholderType.body,
            SlidePlaceholderType.slideNumber,
            SlidePlaceholderType.footer,
          ],
        );
        expect(
          BuiltInLayouts.masterDesignGrid[2].rect,
          const SuRect(1680, 992, 120, 48),
        );
      },
    );
  });

  group('Given layout geometry per slide size', () {
    test('when generating 16:9 then the design grid is unchanged', () {
      final layouts = BuiltInLayouts.forSize(SlideSize.widescreen);
      for (var i = 0; i < layouts.length; i++) {
        for (var j = 0; j < layouts[i].placeholders.length; j++) {
          expect(
            layouts[i].placeholders[j].rect,
            BuiltInLayouts.designGrid[i].placeholders[j].rect,
          );
        }
      }
    });

    for (final kind in SlideSizeKind.values.where(
      (k) => k != SlideSizeKind.custom,
    )) {
      final size = SlideSize.preset(kind);
      group(kind.name, () {
        final layouts = BuiltInLayouts.forSize(size);

        test(
          'when generating then every placeholder lies inside the slide',
          () {
            for (final l in layouts) {
              for (final p in l.placeholders) {
                expect(
                  size.bounds.containsRect(p.rect),
                  isTrue,
                  reason: '${l.key}/${p.name} ${p.rect}',
                );
                expect(p.rect.width, greaterThan(0));
                expect(p.rect.height, greaterThan(0));
              }
            }
          },
        );

        test('when generating then the side margins stay 120 su', () {
          final body = layouts
              .firstWhere((l) => l.key == 'titleBody')
              .placeholders[1]
              .rect;
          expect(body.x, 120);
          expect(body.right, size.width - 120);
        });

        test('when generating then full-bleed pictures cover the slide', () {
          final pic = layouts
              .firstWhere((l) => l.key == 'imageFull')
              .placeholders
              .first
              .rect;
          expect(pic, size.bounds);
        });

        test('when generating two columns then they do not overlap', () {
          final ph = layouts
              .firstWhere((l) => l.key == 'twoColumns')
              .placeholders;
          expect(ph[1].rect.right, lessThan(ph[2].rect.x));
        });
      });
    }

    test(
      'when generating 4:3 then the 1080 su height keeps vertical positions',
      () {
        final l = BuiltInLayouts.forSize(
          SlideSize.preset(SlideSizeKind.standard4x3),
        );
        final title = l
            .firstWhere((l) => l.key == 'titleBody')
            .placeholders
            .first
            .rect;
        expect((title.y, title.height), (72.0, 144.0));
        expect(title.width, 1200);
      },
    );

    test(
      'when generating a double-size custom deck then everything scales by 2',
      () {
        final l = BuiltInLayouts.forSize(SlideSize.custom(3840, 2160));
        final body = l
            .firstWhere((l) => l.key == 'titleBody')
            .placeholders[1]
            .rect;
        expect(body, const SuRect(240, 528, 3360, 1440));
      },
    );

    test(
      'when generating portrait then titles stay at the top and bodies stretch',
      () {
        final l = BuiltInLayouts.forSize(
          SlideSize.preset(SlideSizeKind.portrait9x16),
        );
        final ph = l.firstWhere((l) => l.key == 'titleBody').placeholders;
        expect(ph[0].rect.y, 72);
        expect(ph[1].rect.bottom, greaterThan(1700));
      },
    );
  });
}
