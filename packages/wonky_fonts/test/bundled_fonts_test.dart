import 'dart:io';

import 'package:test/test.dart';
import 'package:wonky_fonts/wonky_fonts.dart';

void main() {
  group('Given the bundled font manifest', () {
    test('when listing the fonts folder then every TTF is in the manifest '
        'and every manifest file exists', () {
      final onDisk = {
        for (final f in Directory('fonts').listSync())
          if (f.path.endsWith('.ttf')) f.uri.pathSegments.last,
      };
      final listed = {for (final f in BundledFonts.faces) f.file};

      expect(listed, onDisk);
    });

    test('when reading every face then it is a static TrueType font', () {
      for (final f in BundledFonts.faces) {
        final bytes = File('fonts/${f.file}').readAsBytesSync();
        // sfnt version 1.0 (TrueType outlines; the pdf package cannot embed
        // CFF-flavoured OTF).
        expect(bytes.sublist(0, 4), [0x00, 0x01, 0x00, 0x00], reason: f.file);
      }
    });

    test('when looking up licenses then every family has an existing '
        'license file', () {
      for (final family in BundledFonts.families) {
        final file = BundledFonts.licenseFiles[family];
        expect(file, isNotNull, reason: family);
        expect(File('fonts/$file').existsSync(), isTrue, reason: file);
      }
    });

    test('when comparing with the server mirror then web/fonts holds the '
        'same files', () {
      final mirror = Directory('../../wonky_server/web/fonts');
      if (!mirror.existsSync()) {
        markTestSkipped('wonky_server/web/fonts not found');
        return;
      }
      for (final f in BundledFonts.faces) {
        expect(
          File('${mirror.path}/${f.file}').readAsBytesSync(),
          File('fonts/${f.file}').readAsBytesSync(),
          reason: f.file,
        );
      }
    });

    test('when building asset keys then they point into the package', () {
      expect(
        BundledFonts.assetKey('OpenSans-Regular.ttf'),
        'packages/wonky_fonts/fonts/OpenSans-Regular.ttf',
      );
      expect(
        BundledFonts.faces.first.assetKey,
        startsWith(BundledFonts.assetRoot),
      );
    });

    test('when finding the closest face then style wins over weight and '
        'weight ties pick the heavier face', () {
      expect(
        BundledFonts.closestFace(BundledFonts.openSans, weight: 500)?.weight,
        600,
      );
      expect(
        BundledFonts.closestFace(BundledFonts.robotoMono, italic: true)?.italic,
        isFalse,
      );
      expect(
        BundledFonts.closestFace(
          BundledFonts.ebGaramond,
          weight: 900,
          italic: true,
        )?.file,
        'EBGaramond-BoldItalic.ttf',
      );
      expect(BundledFonts.closestFace('Comic Sans'), isNull);
    });

    test('when listing families then the curated registry knows the '
        'document families', () {
      expect(BundledFonts.families, hasLength(10));
      for (final family in [
        BundledFonts.openSans,
        BundledFonts.ebGaramond,
        BundledFonts.jetBrainsMono,
      ]) {
        expect(FontRegistry.isSelectable(family), isTrue, reason: family);
      }
    });
  });

  group('Given the font registry', () {
    test('when snapping weights then the nearest shipped weight wins', () {
      expect(FontRegistry.snapWeight('Inter', 650), 700);
      expect(FontRegistry.snapWeight('Unknown', 432), 400);
    });

    test('when choosing fallbacks then the scripts of the text decide', () {
      final names = [
        for (final f in FontRegistry.fallbackFamiliesFor('a שלום 漢字 😀'))
          f.family,
      ];
      expect(names, [
        'Noto Sans',
        'Noto Sans Hebrew',
        'Noto Sans SC',
        'Noto Emoji',
      ]);
    });
  });
}
