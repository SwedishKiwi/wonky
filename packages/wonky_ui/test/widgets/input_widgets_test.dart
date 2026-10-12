import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

void main() {
  for (final b in Brightness.values) {
    group('Given input widgets in ${b.name}', () {
      testWidgets('when clicking the title and pressing Enter then onRename '
          'gets the trimmed title', (tester) async {
        String? renamed;
        await pumpWonky(
          tester,
          DocumentTitleField(
            title: 'Q3 planning',
            onRename: (t) => renamed = t,
          ),
          brightness: b,
          center: true,
        );
        await tester.tap(find.byKey(const ValueKey('titleField.text')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('titleField.input')),
          '  Q4 plan ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(renamed, 'Q4 plan');
      });

      testWidgets('when editing the title and pressing Esc then it reverts', (
        tester,
      ) async {
        String? renamed;
        final controller = DocumentTitleFieldController();
        await pumpWonky(
          tester,
          DocumentTitleField(
            title: 'Notes',
            controller: controller,
            onRename: (t) => renamed = t,
          ),
          brightness: b,
          center: true,
        );
        controller.startEditing();
        await tester.pumpAndSettle();
        expect(controller.isEditing, isTrue);
        await tester.enterText(
          find.byKey(const ValueKey('titleField.input')),
          'Other',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(renamed, isNull);
        expect(find.text('Notes'), findsOneWidget);
      });

      testWidgets('when read-only then the title cannot be edited', (
        tester,
      ) async {
        await pumpWonky(
          tester,
          const DocumentTitleField(
            title: '',
            readOnly: true,
            placeholder: 'Untitled document',
          ),
          brightness: b,
          center: true,
        );
        await tester.tap(find.text('Untitled document'));
        await tester.pump();
        expect(find.byKey(const ValueKey('titleField.input')), findsNothing);
      });

      testWidgets('when recording a shortcut then the chord with modifiers is '
          'reported', (tester) async {
        RecordedChord? chord;
        await pumpWonky(
          tester,
          KeyboardShortcutRecorder(
            labels: const ['Ctrl', 'B'],
            onRecorded: (c) => chord = c,
          ),
          brightness: b,
          center: true,
        );
        await tester.tap(find.byKey(const ValueKey('shortcutRecorder.field')));
        await tester.pump();
        expect(find.text('Press keys…'), findsOneWidget);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(
          chord,
          const RecordedChord(key: 'K', control: true, shift: true),
        );
      });

      testWidgets('when pressing Esc while recording then recording stops '
          'without a result', (tester) async {
        RecordedChord? chord;
        await pumpWonky(
          tester,
          KeyboardShortcutRecorder(
            labels: const [],
            onRecorded: (c) => chord = c,
            conflict: 'Already used',
          ),
          brightness: b,
          center: true,
        );
        expect(find.text('Already used'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('shortcutRecorder.field')));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(chord, isNull);
        expect(find.text('None'), findsOneWidget);
      });

      testWidgets(
        'when opening the font picker then fonts render in sections',
        (tester) async {
          String? picked;
          await pumpWonky(
            tester,
            FontPicker(
              value: 'Inter',
              fonts: const ['Inter', 'Lora', 'Roboto Mono'],
              recentFonts: const ['Lora'],
              onChanged: (f) => picked = f,
            ),
            brightness: b,
            center: true,
          );
          await tester.tap(find.byKey(const ValueKey('fontPicker.select')));
          await tester.pumpAndSettle();
          expect(find.text('Recent'), findsOneWidget);
          expect(find.text('All fonts'), findsOneWidget);
          await tester.tap(find.text('Roboto Mono').last);
          await tester.pumpAndSettle();
          expect(picked, 'Roboto Mono');
        },
      );

      testWidgets(
        'when a scroll area is scrolled then the top shadow appears',
        (tester) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);
          await pumpWonky(
            tester,
            SizedBox(
              height: 200,
              child: WonkyScrollArea(
                controller: controller,
                child: ListView(
                  controller: controller,
                  children: [
                    for (var i = 0; i < 50; i++)
                      SizedBox(height: 30, child: Text('row $i')),
                  ],
                ),
              ),
            ),
            brightness: b,
          );
          await tester.pumpAndSettle();
          double topOpacity() => tester
              .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
              .first
              .opacity;
          expect(topOpacity(), 0);
          controller.jumpTo(200);
          await tester.pumpAndSettle();
          expect(topOpacity(), 1);
        },
      );
    });
  }
}
