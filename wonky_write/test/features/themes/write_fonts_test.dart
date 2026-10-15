import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_write/features/themes/write_fonts.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Given the bundled Write fonts (package:wonky_fonts assets)', () {
    test('when listing the faces then Open Sans, EB Garamond and JetBrains '
        'Mono are bundled with their regular and bold faces', () {
      final families = {for (final f in WriteFonts.faces) f.family};

      expect(families, {
        WriteFonts.openSans,
        WriteFonts.ebGaramond,
        WriteFonts.jetBrainsMono,
      });
      for (final family in families) {
        final weights = {
          for (final f in WriteFonts.faces)
            if (f.family == family && !f.italic) f.weight,
        };
        expect(weights, containsAll([400, 700]), reason: family);
      }
    });

    test(
      'when loading every face then it is a real TTF package asset',
      () async {
        for (final f in WriteFonts.faces) {
          expect(f.asset, startsWith('packages/wonky_fonts/fonts/'));
          final bytes = await rootBundle.load(f.asset);
          // sfnt version 1.0 (TrueType outlines).
          expect(bytes.getUint32(0), 0x00010000, reason: f.asset);
        }
      },
    );

    test(
      'when loading the licenses then each bundled family has one',
      () async {
        for (final family in {for (final f in WriteFonts.faces) f.family}) {
          final file = BundledFonts.licenseFiles[family]!;
          final text = await rootBundle.loadString(BundledFonts.assetKey(file));
          expect(text, contains('SIL Open Font License'), reason: family);
        }
      },
    );

    test('when the provider loads a face then unbundled families are '
        'substituted by category', () async {
      final provider = AssetFontProvider();

      final serif = await provider.load('Lora', weight: 700);
      final mono = await provider.load('Courier Prime', italic: true);

      expect(WriteFonts.exportFamilyFor('Lora'), WriteFonts.ebGaramond);
      expect(serif.weight, 700);
      expect(serif.bytes, isNotEmpty);
      expect(
        WriteFonts.exportFamilyFor('Courier Prime'),
        WriteFonts.jetBrainsMono,
      );
      expect(mono.italic, isTrue);
    });
  });
}
