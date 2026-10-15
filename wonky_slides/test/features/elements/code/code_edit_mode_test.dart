import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';
import 'package:wonky_slides/features/elements/code/code_blocks.dart';
import 'package:wonky_slides/features/elements/code/code_canvas_mode.dart';
import 'package:wonky_slides_core/testing.dart' show DeckBuilder;
import 'package:wonky_ui/testing.dart';

import '../../../support/deck_screen.dart';

const _v1 = 'void main() {\n  print(1);\n}';

void main() {
  late String slide, code;

  DeckBuilder deck({List<String>? states, double height = 600}) {
    final b = DeckBuilder(title: 'Code');
    slide = b.slide(layoutKey: 'blank');
    (code, _) = b.codeBlock(
      slide,
      states: states ?? [_v1, 'void main() {\n  final x = 2;\n  print(x);\n}'],
      height: height,
      data: {'v': 1, 'language': 'dart', 'title': 'lib/main.dart'},
    );
    return b;
  }

  /// Lets re_editor's caret blink start, then closes the screen.
  Future<void> close(WidgetTester tester, DeckScreenRig r) async {
    await tester.pump(const Duration(milliseconds: 200));
    await settleTooltips(tester);
    await r.close(tester);
  }

  testWidgets('Given a selected code block when *Edit code* runs then the '
      'field edits the edit state, typing is written after a pause as one '
      '"Typing" step and Escape leaves', (tester) async {
    final r = await pumpDeckScreen(
      tester,
      fixture: deck(),
      initialSlideId: slide,
    );
    r.editor.selectElements([code]);
    await tester.pump();

    await r.run('slides.element.activate');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(CodeCanvasKeys.field), findsOneWidget);
    final field = tester.state<CodeEditorFieldState>(
      find.byType(CodeEditorField),
    );
    expect(field.text, _v1);

    field.typeAt(2, 1, '\n// done');
    await tester.pump(const Duration(milliseconds: 350));
    expect(r.editor.model.codeStatesOf(code).first.code, '$_v1\n// done');
    expect(r.h.undoLabels.first, 'Typing');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(CodeCanvasKeys.field), findsNothing);
    expect(CodeBlockView.of(r.editor).editing, isNull);
    expect(r.editor.selectedElementIds, [code]);
    await close(tester, r);
  });

  testWidgets('Given editing state 2 when undo runs then the field shows the '
      'restored code', (tester) async {
    final r = await pumpDeckScreen(
      tester,
      fixture: deck(),
      initialSlideId: slide,
    );
    r.editor.selectElements([code]);
    await r.run('slides.code.selectState', {'index': 1});
    await r.run('slides.code.edit');
    await tester.pump();
    await tester.pump();
    final field = tester.state<CodeEditorFieldState>(
      find.byType(CodeEditorField),
    );
    final before = field.text;
    field.typeAt(0, 0, '// top\n');
    await tester.pump(const Duration(milliseconds: 350));

    await r.run('shell.edit.undo');
    await tester.pump();
    expect(r.editor.model.codeStatesOf(code)[1].code, before);
    expect(field.text, before);
    await close(tester, r);
  });

  testWidgets('Given state 2 when its change is previewed then the canvas '
      'plays the type-in frames and settles', (tester) async {
    final r = await pumpDeckScreen(
      tester,
      fixture: deck(),
      initialSlideId: slide,
    );
    r.editor.selectElements([code]);
    await tester.pump();
    final mode = CodeCanvasMode.of(r.editor)!;

    await r.run('slides.code.preview', {'index': 1});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(mode.active, isTrue);
    expect(mode.previewElapsed, greaterThan(Duration.zero));

    await tester.pump(const Duration(seconds: 12));
    await tester.pump();
    expect(CodeBlockView.of(r.editor).preview, isNull);
    expect(mode.active, isFalse);
    await close(tester, r);
  });

  testWidgets('Given code that doesn\'t fit when selected then the overflow '
      'badge says how many lines are hidden', (tester) async {
    final long = [for (var i = 0; i < 80; i++) 'final v$i = $i;'].join('\n');
    final r = await pumpDeckScreen(
      tester,
      fixture: deck(states: [long], height: 300),
      initialSlideId: slide,
    );
    r.editor.selectElements([code]);
    await tester.pump();

    expect(find.byKey(CodeCanvasKeys.overflow), findsOneWidget);
    expect(find.textContaining('lines hidden'), findsOneWidget);
    await close(tester, r);
  });
}
