import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_write/features/emoji/emoji_picker.dart';
import 'package:wonky_write/features/emoji/emoji_prefs.dart';

import 'support/emoji_fixture.dart';

class _Picked {
  final values = <String>[];
  var closed = 0;
}

Future<(_Picked, EmojiPrefs, MemoryStore)> _pumpPicker(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  final picked = _Picked();
  final store = MemoryStore();
  final prefs = EmojiPrefs(store);
  addTearDown(prefs.dispose);
  await pumpWonky(
    tester,
    SizedBox(
      width: 360,
      height: 420,
      child: WonkyEmojiPicker(
        catalog: emojiFixture(),
        prefs: prefs,
        onSelected: picked.values.add,
        onClose: () => picked.closed++,
      ),
    ),
    brightness: brightness,
    center: true,
  );
  await tester.pump();
  return (picked, prefs, store);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(EmojiPickerKeys.search),
      matching: find.byType(EditableText),
    ),
    text,
  );
  await tester.pump();
}

void main() {
  for (final brightness in Brightness.values) {
    group('Given the emoji picker (${brightness.name})', () {
      testWidgets('when searching and tapping a result then it is chosen '
          'and recorded as recent', (tester) async {
        final (picked, prefs, store) = await _pumpPicker(
          tester,
          brightness: brightness,
        );

        await _type(tester, 'wave');
        expect(find.byKey(EmojiPickerKeys.cell('😀')), findsNothing);
        await tester.tap(find.byKey(EmojiPickerKeys.cell('👋')));
        await tester.pump();

        expect(picked.values, ['👋']);
        expect(prefs.recent, ['👋']);
        expect(await store.read(EmojiPrefs.recentKey), ['👋']);
      });
    });
  }

  group('Given the emoji picker', () {
    testWidgets('when browsing then every category has a tab and a section', (
      tester,
    ) async {
      await _pumpPicker(tester);

      expect(find.byKey(EmojiPickerKeys.tabRecent), findsOneWidget);
      expect(find.byKey(EmojiPickerKeys.tab('people')), findsOneWidget);
      expect(find.text('Smileys & emotion'), findsOneWidget);
      expect(find.byKey(EmojiPickerKeys.cell('❤️')), findsOneWidget);
    });

    testWidgets('when moving with the arrow keys and pressing Enter then '
        'the highlighted emoji is chosen', (tester) async {
      final (picked, _, _) = await _pumpPicker(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // into grid
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight); // 😄
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // next row
      await tester.pump();
      expect(find.text('Person lifting weights'), findsOneWidget); // preview
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(picked.values, ['\u{1F3CB}️']);
    });

    testWidgets('when searching then the preview names the first result', (
      tester,
    ) async {
      await _pumpPicker(tester);

      await _type(tester, 'wave');

      expect(
        find.descendant(
          of: find.byKey(EmojiPickerKeys.preview),
          matching: find.text('Waving hand'),
        ),
        findsOneWidget,
      );
      expect(find.text(':wave:'), findsOneWidget);
    });

    testWidgets('when searching and pressing Enter then the first result is '
        'chosen', (tester) async {
      final (picked, _, _) = await _pumpPicker(tester);

      await _type(tester, 'heart');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(picked.values, ['❤️']);
    });

    testWidgets('when a skin tone is picked then toned emoji are inserted '
        'and the tone is stored', (tester) async {
      final (picked, prefs, store) = await _pumpPicker(tester);

      await tester.tap(find.byKey(EmojiPickerKeys.skinTone));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EmojiPickerKeys.skinToneOption(3)));
      await tester.pumpAndSettle();
      await _type(tester, 'wave');
      await tester.tap(find.byKey(EmojiPickerKeys.cell('👋')));
      await tester.pump();

      expect(prefs.skinTone, 3);
      expect(await store.read(EmojiPrefs.skinToneKey), 3);
      expect(picked.values, ['👋🏽']);
      expect(prefs.recent, ['👋🏽']);
    });

    testWidgets('when an emoji was used then it is listed under Recently '
        'used', (tester) async {
      final (_, prefs, _) = await _pumpPicker(tester);

      prefs.recordUse('👍');
      await tester.pump();

      expect(find.text('Recently used'), findsOneWidget);
      expect(find.byKey(EmojiPickerKeys.recent('👍')), findsOneWidget);
    });

    testWidgets('when pressing Escape then onClose is called', (tester) async {
      final (picked, _, _) = await _pumpPicker(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(picked.closed, 1);
    });

    testWidgets('when searching without matches then an empty state shows', (
      tester,
    ) async {
      await _pumpPicker(tester);

      await _type(tester, 'zzzz');

      expect(find.text('No emoji found'), findsOneWidget);
    });
  });

  group('Given the emoji picker dialog', () {
    testWidgets('when an emoji is chosen then the dialog closes and reports '
        'it', (tester) async {
      final picked = <String>[];
      final prefs = EmojiPrefs();
      addTearDown(prefs.dispose);
      final catalog = emojiFixture();
      await pumpWonky(
        tester,
        Builder(
          builder: (context) => ShadButton(
            key: const ValueKey<String>('test.open'),
            onPressed: () => showEmojiPickerDialog(
              context,
              prefs: prefs,
              catalog: catalog,
              onSelected: picked.add,
            ),
            child: const Text('Open'),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('test.open')));
      await tester.pumpAndSettle();
      expect(find.byKey(EmojiPickerKeys.dialog), findsOneWidget);
      await _type(tester, 'thumbs');
      await tester.tap(find.byKey(EmojiPickerKeys.cell('👍')));
      await tester.pumpAndSettle();

      expect(picked, ['👍']);
      expect(find.byKey(EmojiPickerKeys.dialog), findsNothing);
    });
  });

  group('Given the shortcode suggestion list', () {
    testWidgets('when shown then it lists at most 8 matches with the '
        'highlighted row and a tap chooses', (tester) async {
      final catalog = emojiFixture();
      final chosen = <String>[];
      await pumpWonky(
        tester,
        EmojiSuggestionList(
          matches: catalog.all,
          highlighted: 1,
          skinTone: 2,
          onChoose: chosen.add,
        ),
        center: true,
      );

      expect(find.byKey(EmojiPickerKeys.suggestion(7)), findsOneWidget);
      expect(find.byKey(EmojiPickerKeys.suggestion(8)), findsNothing);
      await tester.tap(find.byKey(EmojiPickerKeys.suggestion(3)));

      expect(chosen, ['👋🏼']);
    });
  });
}
