import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_screen.dart';
import 'package:wonky_slides/features/print/png_export_dialog.dart';
import 'package:wonky_slides/features/print/slides_png_export.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';

import '../../support/deck_screen.dart';

/// *File › Download ▸ PNG* dialog (Slides 10 §13; SL-33): a
/// `WonkyDialogSpec` the MCP UI bridge can fill and press.
void main() {
  final l = slidesL10nEnglish;
  Finder key(String k) => find.byKey(ValueKey<String>(k));

  for (final (brightness, size) in [
    (Brightness.light, const Size(1440, 900)),
    (Brightness.dark, const Size(360, 720)),
  ]) {
    testWidgets('Given the PNG dialog in the ${brightness.name} theme at '
        '${size.width.round()} px when it is filled through the MCP bridge '
        'and Download is pressed then the chosen options are returned', (
      tester,
    ) async {
      final r = await pumpDeckScreen(
        tester,
        brightness: brightness,
        size: size,
      );
      final context = tester.element(find.byType(DeckEditorScreen));
      SlidesPngOptions? result;
      final done = showPngExportDialog(
        context,
        r.editor,
        const SlidesPngOptions(),
      ).then((o) => result = o);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(key('dialog.slides.downloadPng'), findsOneWidget);
      expect(find.text(l.pngDialogTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      final dialog = r.services.openDialogs.single;
      final fields = [
        for (final f in dialog.describe()['fields']! as List) (f as Map)['id'],
      ];
      expect(fields, ['range', 'scale', 'frames', 'transparent']);
      expect(dialog.setField('range', 'all'), isTrue);
      expect(dialog.setField('scale', '2'), isTrue);
      expect(dialog.setField('frames', 'builds'), isTrue);
      expect(dialog.setField('transparent', true), isTrue);
      expect(dialog.press('download'), isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await done;

      expect(result?.range, 'all');
      expect(result?.scale, 2);
      expect(result?.frames, SlidesImageFrames.builds);
      expect(result?.transparent, isTrue);
      expect(key('dialog.slides.downloadPng'), findsNothing);
      await r.close(tester);
    });
  }

  testWidgets('Given the PNG dialog when it is cancelled then nothing is '
      'returned', (tester) async {
    final r = await pumpDeckScreen(tester);
    final context = tester.element(find.byType(DeckEditorScreen));
    var closed = false;
    SlidesPngOptions? result;
    unawaited(
      showPngExportDialog(context, r.editor, const SlidesPngOptions()).then((
        o,
      ) {
        result = o;
        closed = true;
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(r.services.openDialogs.single.press('cancel'), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(closed, isTrue);
    expect(result, isNull);
    await r.close(tester);
  });

  test('Given PNG sizes when the slide is very wide then the image is capped '
      'at 7,680 px wide', () {
    expect(SlidesPngExport.sizeOf(1920, 1080, 4), (7680, 4320));
    expect(SlidesPngExport.sizeOf(4000, 1000, 4), (7680, 1920));
    expect(SlidesPngExport.sizeOf(1920, 1080, 2), (3840, 2160));
  });

  test('Given PNG options JSON when invalid values are given then defaults '
      'are used', () {
    final o = SlidesPngOptions.fromJson({
      'scale': 3,
      'frames': 'nope',
      'range': '  ',
    });

    expect(o.scale, 1);
    expect(o.frames, SlidesImageFrames.print);
    expect(o.range, 'current');
    expect(SlidesPngOptions.fromJson(o.toJson()).toJson(), o.toJson());
  });
}
