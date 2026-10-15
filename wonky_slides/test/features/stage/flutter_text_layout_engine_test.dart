import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/stage/flutter_text_layout_engine.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

void main() {
  final theme = DeckThemeResolver().resolve(
    BuiltInThemes.package(BuiltInThemes.defaultKey)!.theme,
    SlideAppearance.light,
  );
  final styles = TextStyleResolver().resolve(theme, defaultStyle: 'body');
  const long = 'The quick brown fox jumps over the lazy dog again and again';

  group('Given the Flutter text layout engine', () {
    late FlutterTextLayoutEngine engine;
    setUp(() => engine = FlutterTextLayoutEngine());

    test('when text is wider than the box then it wraps into lines whose '
        'ranges cover the text', () {
      final r = engine.layout(TextBody.plain(long), styles, width: 400);

      expect(r.lines.length, greaterThan(1));
      expect(r.lines.first.start, 0);
      expect(r.lines.last.end, long.length);
      for (var i = 1; i < r.lines.length; i++) {
        expect(r.lines[i].start, r.lines[i - 1].end);
        expect(r.lines[i].top, greaterThan(r.lines[i - 1].top));
      }
      expect(r.lines.expand((l) => l.runs).map((x) => x.text).join(), long);
    });

    test('when laid out then the paragraphs are kept for painting', () {
      final r = engine.layout(TextBody.plain('Hi\nThere'), styles, width: 400);

      expect(FlutterTextLayoutEngine.paragraphsOf(r)!.paragraphs, hasLength(2));
      expect(r.lines, hasLength(2));
      expect(r.lines[1].paragraph, 1);
    });

    test('when the same body is laid out again then the cached result is '
        'returned, and a font generation change lays out again', () {
      final gen = ValueNotifier(0);
      final e = FlutterTextLayoutEngine(fontGeneration: gen);

      final a = e.layout(TextBody.plain('Same'), styles, width: 300);
      final b = e.layout(TextBody.plain('Same'), styles, width: 300);
      gen.value++;
      final c = e.layout(TextBody.plain('Same'), styles, width: 300);

      expect(identical(a, b), isTrue);
      expect(identical(a, c), isFalse);
      expect(e.debugLayouts, 2);
    });

    test('when a list is laid out then the first line has the marker and the '
        'text is indented', () {
      final body = TextBody([
        {'insert': 'Item'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
      ]);

      final r = engine.layout(body, styles, width: 600);
      final line = r.lines.single;

      expect(line.bullet!.text, '1.');
      expect(line.left, greaterThan(0));
      expect(FlutterTextLayoutEngine.paragraphsOf(r)!.paragraphs, hasLength(2));
    });

    test('when an empty paragraph is laid out then it still has a line '
        'height', () {
      final r = engine.layout(TextBody.plain('a\n\nb'), styles, width: 300);

      expect(r.lines, hasLength(3));
      expect(r.lines[1].height, greaterThan(0));
      expect(r.lines[1].start, r.lines[1].end);
    });

    test('when scaled down then the text takes less height', () {
      final full = engine.layout(TextBody.plain(long), styles, width: 400);
      final half = engine.layout(
        TextBody.plain(long),
        styles,
        width: 400,
        scale: 0.5,
      );

      expect(half.height, lessThan(full.height));
      expect(half.fitScale, 0.5);
    });

    test('when an editing overlay lays out the same runs as spans (mapper '
        'fake) then its line breaks equal the static layout (03 §22, R4)', () {
      // The overlay (SL-13) renders the body from the same styled
      // paragraphs; a TextPainter over equivalent spans stands in for it.
      final body = TextBody([
        {'insert': 'Mixed '},
        {
          'insert': 'bold words',
          'attributes': {'bold': true},
        },
        {'insert': ' and plain text that wraps around in a box\n'},
      ]);
      final r = engine.layout(body, styles, width: 360);
      final p = TextParagraphs.build(body, styles).single;
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          children: [
            for (final run in p.runs)
              TextSpan(
                text: run.text,
                style: TextStyle(
                  fontFamily: run.fontFamily,
                  fontSize: run.fontSize,
                  fontWeight: FontWeight.values[(run.fontWeight ~/ 100) - 1],
                  height: p.lineHeight,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
          ],
        ),
      )..layout(maxWidth: 360);
      final overlayBreaks = <int>[];
      var offset = 0;
      for (var i = 0; i < painter.computeLineMetrics().length; i++) {
        final range = painter.getLineBoundary(TextPosition(offset: offset));
        overlayBreaks.add(range.end);
        offset = range.end;
      }

      expect(r.lineBreaks, overlayBreaks);
      painter.dispose();
    });
  });

  group('Given auto-fit with the Flutter engine', () {
    test('when shrinking a long body into a small box then it fits at a '
        'reduced scale', () {
      final engine = FlutterTextLayoutEngine();
      final body = TextBody.plain('$long $long $long');
      final fit = AutoFit.fit(
        layoutAt: (s) => engine.layout(body, styles, width: 300, scale: s),
        mode: AutoFitMode.shrink,
        available: 120,
        insetsY: 0,
      );

      expect(fit.scale, lessThan(1));
      expect(fit.contentHeight, lessThanOrEqualTo(120.5));
      expect(FlutterTextLayoutEngine.paragraphsOf(fit.layout), isNotNull);
    });
  });
}
