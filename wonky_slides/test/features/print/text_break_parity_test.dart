import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_fonts/wonky_fonts.dart';
import 'package:wonky_slides/features/stage/flutter_text_layout_engine.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/pdf.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/themes.dart';

/// Samples of slide text: titles, bullets, long paragraphs, numbers,
/// punctuation, accents.
const _samples = [
  'Quarterly review: revenue grew 18 % while costs stayed flat',
  'The quick brown fox jumps over the lazy dog again and again and again',
  'Wonky Slides keeps your presentations in sync across every device, '
      'online and offline, with real-time collaboration built in.',
  'Agenda — goals, numbers, risks, next steps and open questions',
  'Résumé of the café meeting: naïve façades, coöperation and déjà vu',
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
      'tempor incididunt ut labore et dolore magna aliqua.',
  'Customer satisfaction 94.5%, NPS +42, churn 1.8%, ARR \$12.4M',
  'Building a better product means listening to users, measuring what '
      'matters and shipping small improvements every single week.',
];

Future<Uint8List> _font(String file) async {
  final data = await rootBundle.load(BundledFonts.assetKey(file));
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TtfTextMeasurer measurer;

  setUpAll(() async {
    // Register every bundled face with the test engine (as the app's
    // AssetFontRegistry does on demand).
    final byFamily = <String, List<BundledFontFace>>{};
    for (final f in BundledFonts.faces) {
      (byFamily[f.family] ??= []).add(f);
    }
    for (final e in byFamily.entries) {
      final loader = FontLoader(e.key);
      for (final f in e.value) {
        loader.addFont(rootBundle.load(f.assetKey));
      }
      await loader.load();
    }
    final provider = BundledFileFontProvider(_font);
    final keys = <FontFaceKey>{
      for (final f in BundledFonts.faces)
        for (final w in [400, 700])
          for (final i in [false, true]) FontFaceKey(f.family, w, italic: i),
    };
    measurer = TtfTextMeasurer(await TtfFaceSet.load(provider, keys));
  });

  for (final themeKey in BuiltInThemes.keys) {
    for (final style in ['title', 'body']) {
      test(
        'Given the $themeKey theme\'s $style style when the stage engine and '
        'the PDF engine lay out sample text then the line breaks match '
        '(≤ 1 line apart, ≥ 85 % identical)',
        () {
          final theme = DeckThemeResolver().resolve(
            BuiltInThemes.package(themeKey)!.theme,
            SlideAppearance.light,
          );
          final styles = TextStyleResolver().resolve(
            theme,
            defaultStyle: style,
          );
          final flutter = FlutterTextLayoutEngine();
          final core = SlideTextLayout(measurer: measurer);
          var same = 0, total = 0;
          final diffs = <String>[];
          for (final text in _samples) {
            // Realistic box widths: titles span most of the slide.
            for (final width
                in style == 'title'
                    ? [1100.0, 1400.0, 1600.0, 1760.0]
                    : [520.0, 760.0, 1100.0, 1600.0]) {
              final body = TextBody.plain(text);
              final a = flutter.layout(body, styles, width: width).lineBreaks;
              final b = core.layout(body, styles, width: width).lineBreaks;
              total++;
              if (a.join(',') == b.join(',')) {
                same++;
              } else {
                diffs.add('$width "$text": $a vs $b');
              }
              expect(
                (a.length - b.length).abs(),
                lessThanOrEqualTo(1),
                reason: '$width "$text": $a vs $b',
              );
            }
          }
          expect(
            same / total,
            greaterThanOrEqualTo(0.85),
            reason: diffs.join('\n'),
          );
        },
      );
    }
  }
}
