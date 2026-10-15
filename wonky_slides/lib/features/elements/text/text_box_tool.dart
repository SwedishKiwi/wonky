import 'package:flutter/widgets.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;

import '../../canvas/canvas_tools.dart';
import '../../editor_screen/deck_editor_controller.dart';

/// The armed text box tool (03 §6.1, `armedTool == 'text'`): a click
/// creates an auto-width box (`wrap: false`) at the press point, a drag a
/// fixed-width box of the dragged width; editing starts in it
/// (`slides.insert.textBox {x, y, width?, height?}`, one undo step).
class TextBoxTool extends CanvasTool {
  const TextBoxTool();

  /// The armed-tool name.
  static const name = 'text';

  /// The [CanvasTools] factory.
  static CanvasTool? factory(DeckEditorController ed, String armed) =>
      armed == name ? const TextBoxTool() : null;

  @override
  CanvasToolGesture get gesture => CanvasToolGesture.box;

  @override
  MouseCursor get cursor => SystemMouseCursors.text;

  @override
  Future<void> commit(
    DeckEditorController ed,
    CanvasToolStroke stroke,
    BuildContext context,
  ) async {
    final b = stroke.box;
    double r(double v) => (v * 100).roundToDouble() / 100;
    final sized = stroke.dragged && b.width >= 8;
    await ed.invokeCommand(
      'slides.insert.textBox',
      {
        'x': r(sized ? b.x : stroke.start.dx),
        'y': r(sized ? b.y : stroke.start.dy),
        if (sized) 'width': r(b.width),
        if (sized) 'height': r(b.height),
      },
      InvocationSource.ui,
      context.mounted ? context : null,
    );
  }
}
