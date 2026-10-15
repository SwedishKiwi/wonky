import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/fonts.dart';
import 'package:wonky_fonts/wonky_fonts.dart';

/// An asset bundle answering every key with its UTF-16 code units, so
/// tests can tell which asset was read.
class _FakeBundle extends CachingAssetBundle {
  final List<String> loads = [];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    return ByteData.sublistView(Uint8List.fromList(key.codeUnits));
  }
}

void main() {
  group('Given an AssetFontRegistry with a fake engine', () {
    late _FakeBundle bundle;
    late List<(String, int)> registered;
    late AssetFontRegistry registry;

    setUp(() {
      bundle = _FakeBundle();
      registered = [];
      registry = AssetFontRegistry(
        bundle: bundle,
        register: (family, faces) async =>
            registered.add((family, faces.length)),
      );
    });

    test(
      'when ensuring a bundled family then all its faces load once',
      () async {
        expect(await registry.ensure('Montserrat', weight: 700), isTrue);
        expect(await registry.ensure('Montserrat'), isTrue);
        expect(registered, [
          ('Montserrat', BundledFonts.facesOf('Montserrat').length),
        ]);
        expect(
          bundle.loads,
          everyElement(startsWith('packages/wonky_fonts/fonts/Montserrat-')),
        );
        expect(registry.isLoaded('Montserrat'), isTrue);
        expect(registry.generation.value, 1);
      },
    );

    test('when ensuring an unbundled family then nothing loads', () async {
      expect(await registry.ensure('Inter'), isFalse);
      expect(registered, isEmpty);
    });

    test('when ensuring several families then each registers once', () async {
      await registry.ensureAll(['Nunito', 'Merriweather', 'Nunito']);
      expect(registered.map((r) => r.$1).toSet(), {'Nunito', 'Merriweather'});
    });
  });

  group('Given a BundledAssetFontProvider', () {
    test(
      'when loading a bundled face then the closest asset is read',
      () async {
        final bundle = _FakeBundle();
        final provider = BundledAssetFontProvider(bundle: bundle);
        final face = await provider.load(
          'Merriweather',
          weight: 600,
          italic: true,
        );
        expect(face.weight, 700);
        expect(face.italic, isTrue);
        expect(
          String.fromCharCodes(face.bytes),
          endsWith('Merriweather-BoldItalic.ttf'),
        );
      },
    );

    test(
      'when loading an unbundled serif then the serif substitute is used',
      () async {
        final bundle = _FakeBundle();
        final provider = BundledAssetFontProvider(bundle: bundle);
        final face = await provider.load('Source Serif 4');
        expect(face.family, 'Source Serif 4');
        expect(
          String.fromCharCodes(face.bytes),
          endsWith('EBGaramond-Regular.ttf'),
        );
      },
    );

    test('when asking for fallbacks then Open Sans is returned', () async {
      final provider = BundledAssetFontProvider(bundle: _FakeBundle());
      final faces = await provider.fallbacksFor('Привет');
      expect(faces.single.family, BundledFonts.openSans);
    });
  });
}
