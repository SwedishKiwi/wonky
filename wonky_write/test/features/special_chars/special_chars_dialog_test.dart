import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/features/special_chars/special_chars_dialog.dart';

import 'support/special_chars_fixture.dart';

const _open = ValueKey<String>('test.open');

Future<(List<String>, MemoryStore)> _openDialog(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  MemoryStore? store,
  Size size = const Size(1280, 800),
}) async {
  final inserted = <String>[];
  final s = store ?? MemoryStore();
  final catalog = specialCharsFixture();
  await pumpWonky(
    tester,
    Builder(
      builder: (context) => ShadButton(
        key: _open,
        onPressed: () => showSpecialCharactersDialog(
          context,
          onInsert: inserted.add,
          store: s,
          catalog: catalog,
        ),
        child: const Text('Open'),
      ),
    ),
    brightness: brightness,
    size: size,
  );
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
  return (inserted, s);
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(SpecialCharsKeys.search),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pump();
}

void main() {
  for (final brightness in Brightness.values) {
    group('Given the special characters dialog (${brightness.name})', () {
      testWidgets('when searching "arrow" and clicking → then it is inserted '
          'and the dialog stays open', (tester) async {
        final (inserted, store) = await _openDialog(
          tester,
          brightness: brightness,
        );

        await _search(tester, 'arrow');
        expect(find.byKey(SpecialCharsKeys.cell(0x2014)), findsNothing);
        await tester.tap(find.byKey(SpecialCharsKeys.cell(0x2192)));
        await tester.pump();
        await tester.tap(find.byKey(SpecialCharsKeys.cell(0x2192)));
        await tester.pump();

        expect(inserted, ['→', '→']);
        expect(find.byKey(SpecialCharsKeys.dialog), findsOneWidget);
        expect(find.byKey(SpecialCharsKeys.recent(0x2192)), findsOneWidget);
        expect(await store.read(SpecialCharactersDialog.recentKey), ['→']);
      });
    });
  }

  group('Given the special characters dialog', () {
    testWidgets('when hovering a character then the preview shows its name '
        'and code point', (tester) async {
      await _openDialog(tester);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(
        tester.getCenter(find.byKey(SpecialCharsKeys.cell(0x2026))),
      );
      await tester.pump();

      final preview = find.byKey(SpecialCharsKeys.preview);
      expect(
        find.descendant(
          of: preview,
          matching: find.text('Horizontal ellipsis'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: preview, matching: find.text('U+2026')),
        findsOneWidget,
      );
    });

    testWidgets('when searching "U+00E9" then é is found and Enter inserts '
        'it', (tester) async {
      final (inserted, _) = await _openDialog(tester);

      await _search(tester, 'U+00E9');
      expect(find.byKey(SpecialCharsKeys.cell(0xE9)), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(inserted, ['é']);
      expect(find.byKey(SpecialCharsKeys.dialog), findsOneWidget);
    });

    testWidgets('when moving with the arrow keys and pressing Enter then the '
        'highlighted character is inserted', (tester) async {
      final (inserted, _) = await _openDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // into grid
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(inserted, ['…']);
    });

    testWidgets('when choosing the Latin category then its characters show', (
      tester,
    ) async {
      await _openDialog(tester);

      await tester.tap(find.byKey(SpecialCharsKeys.category));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SpecialCharsKeys.categoryOption(2)));
      await tester.pumpAndSettle();

      expect(find.byKey(SpecialCharsKeys.cell(0xE9)), findsOneWidget);
      expect(find.byKey(SpecialCharsKeys.cell(0x2014)), findsNothing);
    });

    testWidgets('when shown on a 360 px wide window then it fits without '
        'the preview', (tester) async {
      await _openDialog(tester, size: const Size(360, 740));

      expect(find.byKey(SpecialCharsKeys.grid), findsOneWidget);
      expect(find.byKey(SpecialCharsKeys.preview), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('when pressing Escape then the dialog closes', (tester) async {
      await _openDialog(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byKey(SpecialCharsKeys.dialog), findsNothing);
    });

    testWidgets('when clicking Close then the dialog closes', (tester) async {
      await _openDialog(tester);

      await tester.tap(find.byKey(SpecialCharsKeys.close));
      await tester.pumpAndSettle();

      expect(find.byKey(SpecialCharsKeys.dialog), findsNothing);
    });

    testWidgets('when recents were stored then they show in the recent row', (
      tester,
    ) async {
      final store = MemoryStore();
      await store.write(SpecialCharactersDialog.recentKey, ['—', 'é']);

      await _openDialog(tester, store: store);

      expect(find.byKey(SpecialCharsKeys.recent(0x2014)), findsOneWidget);
      expect(find.byKey(SpecialCharsKeys.recent(0xE9)), findsOneWidget);
    });
  });
}
