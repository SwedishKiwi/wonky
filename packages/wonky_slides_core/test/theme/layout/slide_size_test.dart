import 'package:test/test.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  group('Given the size presets of 05 §7', () {
    final cases = <(SlideSizeKind, double, double)>[
      (SlideSizeKind.widescreen16x9, 1920, 1080),
      (SlideSizeKind.standard4x3, 1440, 1080),
      (SlideSizeKind.wide16x10, 1728, 1080),
      (SlideSizeKind.square, 1080, 1080),
      (SlideSizeKind.portrait9x16, 1080, 1920),
      (SlideSizeKind.a4, 1527, 1080),
      (SlideSizeKind.letter, 1397, 1080),
    ];
    for (final (kind, w, h) in cases) {
      test('when creating ${kind.name} then it is $w × $h su and valid', () {
        final s = SlideSize.preset(kind);
        expect((s.width, s.height), (w, h));
        expect(SlideSize.validate(s.width, s.height), isNull);
      });
    }

    test(
      'when creating a custom size equal to a preset then the preset is named',
      () {
        expect(SlideSize.custom(1440, 1080).kind, SlideSizeKind.standard4x3);
        expect(SlideSize.custom(2000, 1000).kind, SlideSizeKind.custom);
      },
    );

    test(
      'when computing the PDF page then it is half the su size in points',
      () {
        expect(SlideSize.widescreen.pdfPageSize, (960.0, 540.0));
      },
    );
  });

  group('Given custom size limits (320–7,680 su, 1:4…4:1)', () {
    final invalid = <(double, double)>[
      (319, 1080),
      (7681, 1080),
      (4000, 999),
      (320, 1281),
    ];
    for (final (w, h) in invalid) {
      test('when validating $w × $h then it is refused', () {
        expect(SlideSize.validate(w, h), isNotNull);
        expect(() => SlideSize.custom(w, h), throwsArgumentError);
      });
    }

    test('when validating 4:1 and 1:4 exactly then they are accepted', () {
      expect(SlideSize.validate(4000, 1000), isNull);
      expect(SlideSize.validate(400, 1600), isNull);
    });
  });

  group('Given unit conversions (1 su = ½ pt)', () {
    test('when converting one inch then it is 144 su', () {
      expect(SlideUnits.toSu(1, SlideUnit.inch), 144);
    });

    test('when converting 96 px then it is one inch', () {
      expect(SlideUnits.toSu(96, SlideUnit.px), 144);
    });

    test('when converting 2.54 cm then it is one inch', () {
      expect(SlideUnits.toSu(2.54, SlideUnit.cm), closeTo(144, 1e-9));
    });

    test('when converting 1920 su to inches then it is 13.333 in', () {
      expect(SlideUnits.fromSu(1920, SlideUnit.inch), closeTo(13.333, 0.001));
    });
  });

  group('Given a 16:9 deck scaled to 4:3 (Scale content)', () {
    final s = SlideSizeScaling(
      SlideSize.widescreen,
      SlideSize.preset(SlideSizeKind.standard4x3),
    );

    test('when computing the scale then it is min(w\'/w, h\'/h) = 0.75', () {
      expect(s.scale, 0.75);
    });

    test('when mapping the full slide then it is letterboxed and centered', () {
      expect(
        s.mapRect(const SuRect(0, 0, 1920, 1080)),
        const SuRect(0, 135, 1440, 810),
      );
    });

    test('when scaling a font size then it is clamped to 6 su', () {
      expect(s.scaleLength(40), 30);
      expect(s.scaleFontSize(6), 6);
    });

    test('when scaling theme text styles then sizes follow', () {
      final styles = BuiltInThemes.defaultTheme.themeData().textStyles.scaled(
        s.scale,
      );
      expect(styles['title'].size, 72);
      expect(styles['body'].spaceAfter, 12);
      expect(styles.lists.indentPerLevel, 42);
    });
  });

  group('Given an identity size change', () {
    test('when scaling 16:9 to 16:9 then nothing changes', () {
      expect(
        SlideSizeScaling(SlideSize.widescreen, SlideSize.widescreen).isIdentity,
        isTrue,
      );
    });
  });
}
