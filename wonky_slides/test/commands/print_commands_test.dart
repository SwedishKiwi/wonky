import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show CommandState;
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides/features/print/slides_client_export.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';
import 'package:wonky_slides_core/model.dart' show SlideBuildKind;

import '../harness/deck_harness.dart';
import '../support/deck_screen.dart' show sampleDeck;

/// The print and PDF export commands (Slides 10 §11.6, §12, §14; SL-20)
/// through the real dispatcher on the deck harness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = slidesL10nEnglish;
  late DeckHarness d;

  setUp(() => d = DeckHarness.open(fixture: sampleDeck()));
  tearDown(() => d.dispose());

  String location() =>
      d.services.router.routeInformationProvider.value.uri.toString();
  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      d.services.dispatcher.stateOf(id, args);
  String deckPath() => '/p/${d.session.itemUuid.uuid}';

  group('Given an open deck', () {
    test('when Print is invoked then the print preview route opens', () async {
      final r = await d.run('slides.print.open');

      expect(r.isOk, isTrue);
      expect(location(), '${deckPath()}/print');
    });

    test(
      'when Print is invoked for notes then the route carries the layout',
      () async {
        await d.run('slides.print.open', {'layout': 'notes'});

        expect(location(), '${deckPath()}/print?layout=notes');
      },
    );

    test('when downloading a PDF then the print preview opens', () async {
      await d.run('slides.file.download', {'format': 'pdf'});

      expect(location(), '${deckPath()}/print');
    });

    test('when reading the download formats then PDF and PNG are offered '
        'and the Markdown outline is not available yet', () {
      expect(state('slides.file.download', {'format': 'png'}).enabled, isTrue);
      expect(
        state('slides.file.download', {'format': 'pngZip'}).enabled,
        isTrue,
      );
      final md = state('slides.file.download', {'format': 'markdown'});
      expect(md.enabled, isFalse);
      expect(md.disabledReason, l.reasonNotAvailableYet);
    });

    test('when no preview is open then Print PDF is disabled', () {
      expect(state('slides.print.print').enabled, isFalse);
    });

    test('when exporting immediately with options then the PDF is saved with '
        'the deck title and the options become the last used', () async {
      final saved = <(String, Uint8List)>[];
      final previous = SlidesClientExport.saver;
      SlidesClientExport.saver = (bytes, name) async {
        saved.add((name, bytes));
        return true;
      };
      addTearDown(() => SlidesClientExport.saver = previous);

      final r = await d.run('slides.file.download', {
        'format': 'pdf',
        'immediate': true,
        'options': {'layout': 'handouts', 'handoutsPerPage': 2},
      });

      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(saved.single.$1, 'Q3 review.pdf');
      expect(String.fromCharCodes(saved.single.$2.sublist(0, 5)), '%PDF-');
      expect((r.data! as Map)['pageCount'], 2);
      final stored = d.services.prefs.slidesDefaults['exportOptions'] as Map;
      expect(stored['layout'], 'handouts');
      expect(stored['handoutsPerPage'], 2);
      expect(location(), isNot(contains('/print')));
    });
  });

  group('Given an open deck and PNG downloads (SL-33)', () {
    late List<(String, Uint8List)> saved;
    late void Function() restore;
    setUp(() {
      saved = [];
      final previous = SlidesClientExport.saver;
      SlidesClientExport.saver = (bytes, name) async {
        saved.add((name, bytes));
        return true;
      };
      restore = () => SlidesClientExport.saver = previous;
    });
    tearDown(() => restore());

    bool isPng(Uint8List b) =>
        b.length > 8 && b[0] == 0x89 && String.fromCharCodes(b, 1, 4) == 'PNG';

    /// The names of the files of a stored ZIP (central directory).
    List<String> zipNames(Uint8List zip) {
      final out = <String>[];
      final data = ByteData.sublistView(zip);
      for (var i = 0; i + 46 <= zip.length; i++) {
        if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
        final n = data.getUint16(i + 28, Endian.little);
        out.add(utf8.decode(zip.sublist(i + 46, i + 46 + n)));
        i += 45 + n;
      }
      return out;
    }

    Future<(int, int, int)> sizeAndCornerAlpha(Uint8List png) async {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final rgba = await image.toByteData();
      return (image.width, image.height, rgba!.getUint8(3));
    }

    test('when downloading the current slide immediately then one PNG of '
        'the slide size is saved and the options are remembered', () async {
      final r = await d.run('slides.file.download', {
        'format': 'png',
        'immediate': true,
      });

      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(saved.single.$1, 'Q3 review.png');
      expect(isPng(saved.single.$2), isTrue);
      final (w, h, alpha) = await sizeAndCornerAlpha(saved.single.$2);
      expect((w, h), (1920, 1080));
      expect(alpha, 255);
      final stored =
          d.services.prefs.slidesDefaults['imageExportOptions'] as Map;
      expect(stored['scale'], 1);
    });

    test('when downloading at 2× with a transparent background then the '
        'image is twice as large and its background is clear', () async {
      await d.run('slides.file.download', {
        'format': 'png',
        'immediate': true,
        'options': {'scale': 2, 'transparent': true},
      });

      final (w, h, alpha) = await sizeAndCornerAlpha(saved.single.$2);
      expect((w, h), (3840, 2160));
      expect(alpha, 0);
    });

    test('when downloading all slides as a ZIP then every slide but the '
        'skipped one is an image named by its slide number', () async {
      final r = await d.run('slides.file.download', {
        'format': 'pngZip',
        'immediate': true,
      });

      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(saved.single.$1, 'Q3 review.zip');
      expect(zipNames(saved.single.$2), [
        'Slide 1.png',
        'Slide 2.png',
        // Skipped slides have no number: "Demo" is slide 3.
        'Slide 3.png',
      ]);
      expect((r.data! as Map)['images'], 3);
    });

    test('when an agent downloads PNG without immediate then no dialog '
        'opens and the image is saved', () async {
      final r = await d.h.invoke('slides.file.download', {
        'format': 'png',
      }, InvocationSource.mcp);

      expect(r.isOk, isTrue, reason: '${r.message}');
      expect(saved.single.$1, endsWith('.png'));
    });
  });

  group('Given a slide with two click builds', () {
    late DeckHarness b;
    setUp(() {
      final f = sampleDeck();
      final slide = f.slide(layoutKey: 'blank');
      for (final x in [100.0, 700.0]) {
        f.build_(slide, f.shape(slide, x: x));
      }
      f.build_(slide, f.shape(slide, x: 1300), kind: SlideBuildKind.buildIn);
      b = DeckHarness.open(fixture: f);
    });
    tearDown(() => b.dispose());

    test('when downloading each build stage of that slide then the ZIP '
        'holds one image per step', () async {
      final saved = <(String, Uint8List)>[];
      final previous = SlidesClientExport.saver;
      SlidesClientExport.saver = (bytes, name) async {
        saved.add((name, bytes));
        return true;
      };
      addTearDown(() => SlidesClientExport.saver = previous);

      final r = await b.run('slides.file.download', {
        'format': 'pngZip',
        'immediate': true,
        'options': {'range': '5', 'frames': 'builds'},
      });

      expect(r.isOk, isTrue, reason: '${r.message}');
      expect((r.data! as Map)['images'], 4);
      expect(saved.single.$1, 'Q3 review.zip');
    });
  });
}
