import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:wonky_fonts/wonky_fonts.dart';
import 'package:wonky_slides_core/pdf.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

import '../../support/pdf_fixture.dart';

StyledRun _run(
  String text, {
  String family = 'Open Sans',
  int weight = 400,
  bool italic = false,
  double size = 40,
  double letterSpacing = 0,
}) => StyledRun(
  text: text,
  start: 0,
  fontFamily: family,
  fontWeight: weight,
  fontSize: size,
  color: 0xff000000,
  italic: italic,
  letterSpacing: letterSpacing,
);

void main() {
  late BundledFileFontProvider provider;
  late TtfFaceSet faces;
  late TtfTextMeasurer measurer;

  setUpAll(() async {
    provider = await PdfFixture.fonts();
    faces = await TtfFaceSet.load(provider, [
      TtfFaceSet.keyOf('Open Sans', 400, false),
      TtfFaceSet.keyOf('Open Sans', 700, false),
      TtfFaceSet.keyOf('JetBrains Mono', 400, false),
      TtfFaceSet.keyOf('Inter', 400, false),
    ], fallbackText: 'é');
    measurer = TtfTextMeasurer(faces);
  });

  group('Given the bundled Open Sans face', () {
    test('when measuring a word then the width equals the embedded font\'s '
        'advance widths', () async {
      final face = await provider.load('Open Sans');
      final doc = PdfDocument();
      final font = PdfTtfFont(doc, ByteData.sublistView(face.bytes));

      final w = measurer.width('Hello, world', _run('Hello, world'));

      expect(
        w,
        closeTo(font.stringMetrics('Hello, world').advanceWidth * 40, 1e-6),
      );
    });

    test('when measuring bold then it is wider than regular', () {
      expect(
        measurer.width('Wonky', _run('Wonky', weight: 700)),
        greaterThan(measurer.width('Wonky', _run('Wonky'))),
      );
    });

    test('when letter spacing is set then each character adds it', () {
      final plain = measurer.width('abc', _run('abc'));

      expect(
        measurer.width('abc', _run('abc', letterSpacing: 2)),
        closeTo(plain + 6, 1e-9),
      );
    });

    test('when reading vertical metrics then ascent and descent come from '
        'the face', () {
      final m = measurer.metrics(_run('x'));

      expect(m.ascent, inInclusiveRange(0.9, 1.2));
      expect(m.descent, inInclusiveRange(0.2, 0.4));
    });
  });

  group('Given a family that is not bundled', () {
    test(
      'when measuring Inter then the sans substitute (Open Sans) is used',
      () {
        expect(
          measurer.width('Text', _run('Text', family: 'Inter')),
          measurer.width('Text', _run('Text')),
        );
      },
    );

    test('when a face was not loaded then the approximation is used', () {
      const approx = ApproxTextMeasurer();
      final run = _run('Text', family: 'Lato');

      expect(measurer.width('Text', run), approx.width('Text', run));
    });

    test('when loading Courier New then JetBrains Mono is drawn', () async {
      final face = await provider.load('Courier New');

      expect(face.family, BundledFonts.jetBrainsMono);
    });

    test('when a file is missing then the provider reports the family as '
        'unavailable', () {
      final empty = BundledFileFontProvider((_) async => null);

      expect(
        () => empty.load('Open Sans'),
        throwsA(isA<FontUnavailableException>()),
      );
    });
  });

  group('Given a monospace face', () {
    test('when measuring then every character has the same advance', () {
      final run = _run('iiii', family: 'JetBrains Mono');

      expect(
        measurer.width('iiii', run),
        closeTo(
          measurer.width('MMMM', _run('MMMM', family: 'JetBrains Mono')),
          1e-9,
        ),
      );
    });
  });

  group('Given the core layout with TTF metrics', () {
    test('when a paragraph is wider than the box then every line fits', () {
      final layout = SlideTextLayout(measurer: measurer);
      const text =
          'The quick brown fox jumps over the lazy dog and keeps on running '
          'across the wide green field until the sun goes down.';

      final r = layout.layout(TextBody.plain(text), _styles(), width: 600);

      expect(r.lines.length, greaterThan(1));
      for (final l in r.lines) {
        expect(l.width, lessThanOrEqualTo(600 + 1e-6));
      }
    });
  });

  group('Given a recording measurer', () {
    test('when measuring then it records faces and characters', () {
      final rec = RecordingTextMeasurer();

      rec.width('ab', _run('ab', weight: 700));
      rec.metrics(_run('x', family: 'Lato', italic: true));

      expect(rec.keys, {
        TtfFaceSet.keyOf('Open Sans', 700, false),
        TtfFaceSet.keyOf('Lato', 400, true),
      });
      expect(rec.runes, {0x61, 0x62});
    });
  });
}

ResolvedTextStyles _styles() {
  final face = SlidesFonts.resolve('Open Sans');
  final style = ResolvedTextStyle(
    key: 'body',
    font: face,
    size: 32,
    lineHeight: 1.2,
    letterSpacing: 0,
    color: 0xff000000,
    caps: null,
    align: 'left',
    spaceBefore: 0,
    spaceAfter: 0,
  );
  return ResolvedTextStyles(styles: {'body': style}, defaultStyle: 'body');
}
