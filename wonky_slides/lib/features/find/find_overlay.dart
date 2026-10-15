import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show ShadTheme;
import 'package:wonky_slides_core/find.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../canvas/slide_canvas_controller.dart';
import '../clipboard/paste_options.dart';
import '../editor_screen/deck_editor_controller.dart';
import 'find_bar.dart';
import 'find_controller.dart';
import 'find_replace_panel.dart';

/// The floating layer over the canvas region (Slides 03 §13, 04 §13.12):
/// the find match highlights, the find bar (top-right), the *Find and
/// replace* panel and the paste options chip. Outside the canvas' key
/// scope, so typing into the find fields never reaches canvas shortcuts;
/// transparent to the pointer where nothing is shown.
class DeckCanvasOverlays extends StatelessWidget {
  const DeckCanvasOverlays({super.key, required this.editor});

  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) {
    final find = DeckFindController.of(editor);
    return LayoutBuilder(
      builder: (context, c) => ListenableBuilder(
        listenable: find,
        builder: (context, _) {
          final narrow = c.maxWidth < 480;
          final panelWidth = math.min(420.0, math.max(0.0, c.maxWidth - 16));
          return Stack(
            children: [
              if (find.isOpen && find.matches.isNotEmpty)
                Positioned.fill(
                  key: const ValueKey('slides.find.highlightsLayer'),
                  child: IgnorePointer(
                    child: FindHighlights(editor: editor, find: find),
                  ),
                ),
              if (find.barOpen)
                Positioned(
                  key: const ValueKey('slides.findBar.slot'),
                  top: 8,
                  right: 8,
                  left: narrow ? 8 : null,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: SlidesFindBar(editor: editor),
                  ),
                ),
              if (find.panelOpen)
                Positioned(
                  key: const ValueKey('dialog.slides.findReplace.slot'),
                  top: 8,
                  right: 8,
                  width: panelWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.max(120, c.maxHeight - 16),
                    ),
                    child: FindReplacePanel(editor: editor),
                  ),
                ),
              Positioned.fill(
                key: const ValueKey('slides.pasteOptions.slot'),
                child: PasteOptionsChip(editor: editor),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Highlights of the find matches on the current slide's element and
/// cell bodies (`findMatch`, the current one `findMatchActive`; 03 §13),
/// drawn from the canvas scene's text layout in slide space.
class FindHighlights extends StatelessWidget {
  const FindHighlights({super.key, required this.editor, required this.find});

  final DeckEditorController editor;
  final DeckFindController find;

  static const highlightsKey = ValueKey<String>('slides.find.highlights');

  @override
  Widget build(BuildContext context) {
    final canvas = SlideCanvasController.of(editor);
    final slideId = editor.currentSlideId;
    if (canvas == null || slideId == null) return const SizedBox.shrink();
    final colors = ShadTheme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: canvas,
      builder: (context, _) => CustomPaint(
        key: highlightsKey,
        painter: _HighlightPainter(
          scene: canvas.scene,
          origin: canvas.viewport.origin,
          scale: canvas.viewport.scale,
          matches: find.matchesOnSlide(slideId),
          current: find.currentMatch,
          color: colors.findMatch,
          activeColor: colors.findMatchActive,
        ),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  _HighlightPainter({
    required this.scene,
    required this.origin,
    required this.scale,
    required this.matches,
    required this.current,
    required this.color,
    required this.activeColor,
  });

  final SlideScene? scene;
  final Offset origin;
  final double scale;
  final Map<String, List<DeckFindMatch>> matches;
  final DeckFindMatch? current;
  final Color color;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene;
    if (s == null || matches.isEmpty) return;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    for (final n in s.nodes) {
      _node(canvas, n);
    }
    canvas.restore();
  }

  void _node(Canvas canvas, SceneNode n) {
    switch (n) {
      case GroupNode():
        canvas.save();
        canvas.transform(n.transform.storage);
        for (final c in n.children) {
          _node(canvas, c);
        }
        canvas.restore();
      case TextNode():
        final id = n.elementId;
        if (id == null) return;
        final key = n.partId == null ? 'text:$id' : 'tableCell:$id|${n.partId}';
        final list = matches[key];
        if (list == null) return;
        for (final m in list) {
          final active =
              current != null &&
              current!.bodyKey == m.bodyKey &&
              current!.start == m.start;
          final paint = Paint()..color = active ? activeColor : color;
          for (final r in _rects(n, m.start, m.start + m.length)) {
            canvas.drawRect(r, paint);
          }
        }
      default:
        break;
    }
  }

  /// The rectangles of body range [a, b) of [n] (runs split
  /// proportionally per character).
  static Iterable<Rect> _rects(TextNode n, int a, int b) sync* {
    for (final line in n.layout.lines) {
      if (line.end <= a || line.start >= b) continue;
      for (final r in line.runs) {
        final len = r.text.length;
        if (len == 0) continue;
        final s = math.max(a, r.start), e = math.min(b, r.start + len);
        if (e <= s) continue;
        final x0 = r.width * (s - r.start) / len;
        final x1 = r.width * (e - r.start) / len;
        yield Rect.fromLTWH(
          n.originX + line.left + r.x + x0,
          n.originY + line.top,
          x1 - x0,
          line.height,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.scene != scene ||
      old.origin != origin ||
      old.scale != scale ||
      old.matches != matches ||
      old.current != current ||
      old.color != color;
}
