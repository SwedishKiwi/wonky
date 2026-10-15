import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/clipboard/paste_options.dart';
import 'package:wonky_slides/features/find/find_bar.dart';
import 'package:wonky_slides/features/find/find_controller.dart';
import 'package:wonky_slides/features/find/find_overlay.dart';
import 'package:wonky_slides/features/find/find_replace_panel.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';

void main() {
  late DeckHarness d;

  setUp(() {
    final b = DeckBuilder(title: 'Find');
    final s = b.slide(layoutKey: 'blank', notes: 'plan notes');
    b.textBox(s, 'plan one plan');
    d = DeckHarness.open(fixture: b);
  });

  tearDown(() => d.dispose());

  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    Size size = const Size(1440, 900),
  }) => pumpSlides(
    tester,
    d.h,
    SizedBox.expand(child: DeckCanvasOverlays(editor: d.editor)),
    brightness: brightness,
    size: size,
  );

  for (final brightness in Brightness.values) {
    for (final size in const [Size(1440, 900), Size(360, 640)]) {
      testWidgets('when the find bar is open (${brightness.name}, '
          '${size.width.toInt()} px) then typing counts the matches and '
          'Enter steps to the first', (tester) async {
        await pump(tester, brightness: brightness, size: size);
        await d.run('slides.find.open');
        await tester.pumpAndSettle();
        expect(find.byKey(SlidesFindBar.barKey), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('slides.findBar.query')),
          'plan',
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('3 matches'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('1 of 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(SlidesFindBar.barKey), findsNothing);
      });
    }
  }

  for (final size in const [Size(1440, 900), Size(360, 640)]) {
    testWidgets('when the find and replace panel is driven like MCP '
        '(${size.width.toInt()} px) then Replace all replaces in one step', (
      tester,
    ) async {
      await pump(tester, size: size, brightness: Brightness.dark);
      await d.run('slides.find.openReplace');
      await tester.pumpAndSettle();
      expect(find.byKey(FindReplacePanel.panelKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      final dialog = d.services.openDialogs.last;
      expect(dialog.describe()['title'], 'Find and replace');
      expect(dialog.setField('find', 'plan'), isTrue);
      expect(dialog.setField('replace', 'goal'), isTrue);
      expect(dialog.setField('includeNotes', false), isTrue);
      await tester.pumpAndSettle();
      expect(dialog.describe()['status'], '2 matches');
      expect(dialog.press('replaceAll'), isTrue);
      await tester.pumpAndSettle();
      expect(d.undoLabels, hasLength(1));
      final text = d.model.slides.first;
      expect(
        SlidesText.plainText(d.model.elementsOf(text.id).single.text).trim(),
        'goal one goal',
      );
      expect(SlidesText.plainText(text.notes).trim(), 'plan notes');
      expect(dialog.press('done'), isTrue);
      await tester.pumpAndSettle();
      expect(DeckFindController.of(d.editor).isOpen, isFalse);
    });
  }

  testWidgets('when a paste shows the options chip then it disappears after '
      '10 s', (tester) async {
    await pump(tester);
    PasteOptions.of(d.editor).show(
      const PasteOptionsState(
        kind: 'slides',
        modes: [PasteModes.useDestination, PasteModes.keepSource],
        current: PasteModes.useDestination,
        source: <String, Object?>{},
      ),
    );
    await tester.pump();
    expect(find.byKey(PasteOptionsChip.chipKey), findsOneWidget);
    expect(find.text('Use destination theme'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(find.byKey(PasteOptionsChip.chipKey), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('when the chip is shown at 360 px (${brightness.name}) then '
        'it fits', (tester) async {
      await pump(tester, size: const Size(360, 640), brightness: brightness);
      PasteOptions.of(d.editor).show(
        const PasteOptionsState(
          kind: 'sheetsChart',
          modes: [PasteModes.linked, PasteModes.unlinked],
          current: PasteModes.linked,
          source: <Object?>[],
        ),
      );
      await tester.pump();
      expect(find.text('Linked to the spreadsheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      PasteOptions.of(d.editor).hide();
      await tester.pump();
    });
  }
}
