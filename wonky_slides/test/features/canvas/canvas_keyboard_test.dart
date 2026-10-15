import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/slide_canvas.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';

import '../../support/deck_screen.dart';
import 'canvas_rig.dart';

/// The canvas inside the real editor screen: keyboard scope `slidesCanvas`
/// (03 §1.2, §3.3, §4.4, §10).
void main() {
  late CanvasFixture f;

  Future<DeckScreenRig> open(WidgetTester tester) async {
    f = CanvasFixture();
    final rig = await pumpDeckScreen(tester, fixture: f.b);
    expect(find.byType(SlideCanvas), findsOneWidget);
    rig.editor.canvasFocus.requestFocus();
    await tester.pump();
    return rig;
  }

  ({double x, double y}) pos(DeckScreenRig rig, String id) {
    final e = rig.session.model.element(id)!;
    return (x: e.x!, y: e.y!);
  }

  testWidgets('Given the editor screen when a deck opens then the canvas '
      'controller is attached and the canvas draws the slide', (tester) async {
    final rig = await open(tester);

    expect(SlideCanvasController.of(rig.editor), isNotNull);
    expect(find.byKey(const ValueKey('slides.canvas.overlay')), findsOneWidget);
    await rig.close(tester);
  });

  testWidgets('Given a selected shape when pressing arrows then it nudges by '
      '1 su, with Shift by 10 su, as one undo step', (tester) async {
    final rig = await open(tester);
    selectionOf(rig.editor).select([f.a]);
    await tester.pump();
    final id = f.a;
    final start = pos(rig, id);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    });
    await tester.pump();

    expect(pos(rig, id), (x: start.x + 1, y: start.y + 10));
    await rig.run('shell.edit.undo');
    expect(pos(rig, id), start);
    await rig.close(tester);
  });

  testWidgets('Given the canvas focused when pressing Tab, Esc and Mod+A then '
      'the selection cycles, clears and selects everything', (tester) async {
    final rig = await open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(rig.editor.selectedElementIds, hasLength(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(rig.editor.selectedElementIds, isEmpty);

    await rig.run('shell.edit.selectAll');
    await tester.pump();
    expect(rig.editor.selectedElementIds, hasLength(7));
    await rig.close(tester);
  });

  testWidgets('Given a selected shape when pressing Delete then it is '
      'deleted', (tester) async {
    final rig = await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final id = rig.editor.selectedElementIds.single;

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pump();

    expect(rig.session.model.element(id), isNull);
    await rig.close(tester);
  });
}
