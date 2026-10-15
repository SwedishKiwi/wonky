import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../text_editing/text_canvas_rig.dart';

/// The canvas edits layouts in masters mode with the regular tools
/// (Slides 05 §8.1; SL-28): selection, moving, text editing of the
/// placeholders' prompt text, and the placeholder chrome.
void main() {
  Future<(TextCanvasRig, String)> masters(WidgetTester tester) async {
    final r = await TextCanvasRig.pump(tester, size: const Size(1200, 700));
    final layout = r.f.b.layoutId('titleBody');
    await r.d.run('slides.view.setMode', {
      'mode': 'masters',
      'layoutId': layout,
    });
    await tester.pump();
    return (r, layout);
  }

  SlideElementRec placeholderOf(
    TextCanvasRig r,
    String owner,
    SlidePlaceholderType t,
  ) => r.model.elementsOf(owner).firstWhere((e) => e.placeholderType == t);

  testWidgets('Given masters mode on a layout when its title placeholder is '
      'clicked then it is selected (not a slide instance)', (tester) async {
    final (r, layout) = await masters(tester);
    final title = placeholderOf(r, layout, SlidePlaceholderType.title);
    final f = r.c.frameOf(title.id)!;

    await r.click(tester, f.cx, f.cy);

    expect(r.d.editor.selectedElementIds, [title.id]);
    expect(
      find.byKey(const ValueKey<String>('slides.masters.placeholderChrome')),
      findsOneWidget,
    );
  });

  testWidgets('Given masters mode when the body placeholder is dragged then '
      'the layout changes in one undo step and slides follow', (tester) async {
    final (r, layout) = await masters(tester);
    final body = placeholderOf(r, layout, SlidePlaceholderType.body);
    final f = r.c.frameOf(body.id)!;
    final y0 = body.y!;

    await r.drag(tester, Offset(f.cx, f.cy), Offset(f.cx, f.cy + 60));

    expect(r.model.element(body.id)!.y, greaterThan(y0));
    expect(r.d.undoLabels, hasLength(1));
    final instance = r.d.editor.resolver
        .resolve(r.f.placeholders)!
        .elements
        .firstWhere((e) => e.placeholderType == SlidePlaceholderType.body);
    expect(instance.frame.y, r.model.element(body.id)!.y);
  });

  testWidgets('Given masters mode when the title placeholder text is edited '
      'then the layout\'s prompt text changes', (tester) async {
    final (r, layout) = await masters(tester);
    final title = placeholderOf(r, layout, SlidePlaceholderType.title);
    final f = r.c.frameOf(title.id)!;

    await r.click(tester, f.cx, f.cy);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(r.text.elementId, title.id);
    await tester.typeImeText('!');
    await tester.pump(const Duration(milliseconds: 350));

    expect(r.textOf(title.id), contains('!'));
    expect(r.d.editor.mode, DeckViewMode.masters);
  });

  testWidgets('Given masters mode with nothing selected when Escape is '
      'pressed on the canvas then Normal view returns', (tester) async {
    final (r, _) = await masters(tester);
    r.d.editor.canvasFocus.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(r.d.editor.mode, DeckViewMode.normal);
  });
}
