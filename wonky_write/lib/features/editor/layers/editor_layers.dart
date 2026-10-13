import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_ui/wonky_ui.dart'
    show RemoteCaret, RemoteSelectionPainter;

import '../controller/write_editor_controller.dart';
import '../mapping/document_mirror.dart';
import '../model/document_queries.dart';
import '../styles/editor_theme.dart';
import '../view/editor_view_state.dart';
import 'document_geometry.dart';

/// Rectangles painted under the document text.
class _UnderlayData {
  const _UnderlayData({
    required this.findRects,
    required this.activeFindRects,
    required this.pendingCommentRects,
    required this.remoteSelections,
    required this.blockSelectionRects,
  });

  final List<Rect> findRects;
  final List<Rect> activeFindRects;
  final List<Rect> pendingCommentRects;
  final List<(Color, List<Rect>)> remoteSelections;
  final List<Rect> blockSelectionRects;
}

/// Underlay: find matches (`findMatch` / `findMatchActive`), the pending
/// comment range (dashed underline), collaborators' selections (presence
/// color at 20 %, 10 % when unfocused) and the block-selection ring
/// (Write 04 §22.3, §25.3, §33, §34.2).
class WonkyHighlightLayerBuilder implements SuperEditorLayerBuilder {
  const WonkyHighlightLayerBuilder({
    required this.controller,
    required this.theme,
  });

  final WriteEditorController controller;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperEditorContext editContext,
  ) => _HighlightLayer(controller: controller, theme: theme);
}

/// The same layer for `SuperReader`.
class WonkyReaderHighlightLayerBuilder
    implements SuperReaderDocumentLayerBuilder {
  const WonkyReaderHighlightLayerBuilder({
    required this.controller,
    required this.theme,
  });

  final WriteEditorController controller;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperReaderContext readerContext,
  ) => _HighlightLayer(controller: controller, theme: theme);
}

class _HighlightLayer extends DocumentLayoutLayerStatefulWidget {
  const _HighlightLayer({required this.controller, required this.theme});

  final WriteEditorController controller;
  final EditorTheme theme;

  @override
  DocumentLayoutLayerState<_HighlightLayer, _UnderlayData> createState() =>
      _HighlightLayerState();
}

class _HighlightLayerState
    extends DocumentLayoutLayerState<_HighlightLayer, _UnderlayData> {
  @override
  void initState() {
    super.initState();
    widget.controller.view.addListener(_onChange);
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_HighlightLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.view.removeListener(_onChange);
      oldWidget.controller.removeListener(_onChange);
      widget.controller.view.addListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.view.removeListener(_onChange);
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  _UnderlayData? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final controller = widget.controller;
    final mirror = controller.mirror;
    final view = controller.view;
    final theme = widget.theme;
    List<Rect> rects(HighlightRange range) => DocumentGeometry.rectsForRange(
      documentLayout,
      mirror,
      range.start,
      range.end,
    );

    final find = <Rect>[];
    final active = <Rect>[];
    final matches = view.findMatches;
    for (var i = 0; i < matches.length && i < 2000; i += 1) {
      (i == view.activeFindMatch ? active : find).addAll(rects(matches[i]));
    }

    final remote = <(Color, List<Rect>)>[];
    if (view.showRemoteCursors) {
      var count = 0;
      for (final cursor in view.remoteCursors) {
        if (cursor.selection.isCollapsed || count >= 50) continue;
        count += 1;
        final color = cursor.colorIndex == null
            ? theme.presenceColorFor(cursor.userKey)
            : theme.presenceColors[cursor.colorIndex! %
                  theme.presenceColors.length];
        remote.add((
          cursor.focused ? color : color.withValues(alpha: 0.5),
          rects(HighlightRange(cursor.selection.start, cursor.selection.end)),
        ));
      }
    }

    final blockRects = <Rect>[];
    final selection = controller.selection;
    if (view.blockSelection && selection != null) {
      for (final block in mirror.blocksInSelection(selection)) {
        final rect = documentLayout.getRectForSelection(
          DocumentPosition(
            nodeId: block.id,
            nodePosition: block.node.beginningPosition,
          ),
          DocumentPosition(
            nodeId: block.id,
            nodePosition: block.node.endPosition,
          ),
        );
        if (rect != null) blockRects.add(rect);
      }
    }

    return _UnderlayData(
      findRects: find,
      activeFindRects: active,
      pendingCommentRects: view.pendingComment == null
          ? const []
          : rects(view.pendingComment!),
      remoteSelections: remote,
      blockSelectionRects: blockRects,
    );
  }

  @override
  Widget doBuild(BuildContext context, _UnderlayData? layoutData) {
    if (layoutData == null) return const SizedBox();
    final theme = widget.theme;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: RemoteSelectionPainter(
                selections: layoutData.remoteSelections,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _RectsPainter(
                fills: [
                  (theme.findMatch, layoutData.findRects),
                  (theme.findMatchActive, layoutData.activeFindRects),
                  (
                    theme.selectionColor.withValues(alpha: 0.3),
                    layoutData.blockSelectionRects,
                  ),
                ],
                rings: [(theme.ringColor, layoutData.blockSelectionRects)],
                dashedUnderlines: [
                  (theme.ringColor, layoutData.pendingCommentRects),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RectsPainter extends CustomPainter {
  _RectsPainter({
    required this.fills,
    required this.rings,
    required this.dashedUnderlines,
  });

  final List<(Color, List<Rect>)> fills;
  final List<(Color, List<Rect>)> rings;
  final List<(Color, List<Rect>)> dashedUnderlines;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (color, rects) in fills) {
      final paint = Paint()..color = color;
      for (final rect in rects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
    }
    for (final (color, rects) in rings) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final rect in rects) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(3)),
          paint,
        );
      }
    }
    for (final (color, rects) in dashedUnderlines) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      for (final rect in rects) {
        var x = rect.left;
        while (x < rect.right) {
          final end = (x + 4).clamp(rect.left, rect.right);
          canvas.drawLine(
            Offset(x, rect.bottom),
            Offset(end, rect.bottom),
            paint,
          );
          x += 7;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_RectsPainter oldDelegate) => true;
}

/// Overlay: collaborators' carets with name flags (`RemoteCaret` from
/// `wonky_ui`, Write 04 §34.2). Hidden when the collaborator is unfocused;
/// 50 % alpha when idle.
class WonkyRemoteCaretLayerBuilder implements SuperEditorLayerBuilder {
  const WonkyRemoteCaretLayerBuilder({
    required this.controller,
    required this.theme,
  });

  final WriteEditorController controller;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperEditorContext editContext,
  ) => _RemoteCaretLayer(controller: controller, theme: theme);
}

class WonkyReaderRemoteCaretLayerBuilder
    implements SuperReaderDocumentLayerBuilder {
  const WonkyReaderRemoteCaretLayerBuilder({
    required this.controller,
    required this.theme,
  });

  final WriteEditorController controller;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperReaderContext readerContext,
  ) => _RemoteCaretLayer(controller: controller, theme: theme);
}

class _CaretData {
  const _CaretData(this.cursor, this.rect, this.color);

  final RemoteCursor cursor;
  final Rect rect;
  final Color color;
}

class _RemoteCaretLayer extends DocumentLayoutLayerStatefulWidget {
  const _RemoteCaretLayer({required this.controller, required this.theme});

  final WriteEditorController controller;
  final EditorTheme theme;

  @override
  DocumentLayoutLayerState<_RemoteCaretLayer, List<_CaretData>> createState() =>
      _RemoteCaretLayerState();
}

class _RemoteCaretLayerState
    extends DocumentLayoutLayerState<_RemoteCaretLayer, List<_CaretData>> {
  @override
  void initState() {
    super.initState();
    widget.controller.view.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.view.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  List<_CaretData>? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final view = widget.controller.view;
    if (!view.showRemoteCursors) return const [];
    final mirror = widget.controller.mirror;
    final theme = widget.theme;
    final carets = <_CaretData>[];
    for (final cursor in view.remoteCursors) {
      if (!cursor.focused || carets.length >= 50) continue;
      final offset = cursor.selection.extent.clamp(0, mirror.length - 1);
      final rect = DocumentGeometry.caretRect(documentLayout, mirror, offset);
      if (rect == null) continue;
      var color = cursor.colorIndex == null
          ? theme.presenceColorFor(cursor.userKey)
          : theme.presenceColors[cursor.colorIndex! %
                theme.presenceColors.length];
      if (cursor.idle) color = color.withValues(alpha: 0.5);
      carets.add(_CaretData(cursor, rect, color));
    }
    return carets;
  }

  @override
  Widget doBuild(BuildContext context, List<_CaretData>? layoutData) {
    if (layoutData == null || layoutData.isEmpty) return const SizedBox();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final caret in layoutData)
          Positioned(
            key: ValueKey('write.editor.remoteCaret.${caret.cursor.sessionId}'),
            left: caret.rect.left,
            top: caret.rect.top,
            child: RemoteCaret(
              name: caret.cursor.isAgent
                  ? '${caret.cursor.name} ✦'
                  : caret.cursor.name,
              color: caret.color,
              height: caret.rect.height,
              lastActivity: caret.cursor.lastActivity ?? caret.cursor.selection,
            ),
          ),
      ],
    );
  }
}

/// Overlay: the ⋮⋮ block handle left of the hovered or caret block (Write 04
/// §22.1). Tapping it calls [onTap] with the node id and the handle's global
/// rect (the host opens the block menu).
class WonkyBlockHandleLayerBuilder implements SuperEditorLayerBuilder {
  const WonkyBlockHandleLayerBuilder({
    required this.controller,
    required this.theme,
    required this.onTap,
    required this.hoveredNodeId,
    this.drag,
  });

  final WriteEditorController controller;
  final EditorTheme theme;
  final void Function(String nodeId, Rect globalRect) onTap;

  /// Drag-to-reorder callbacks (Write 04 §22.5).
  final BlockHandleDrag? drag;

  /// The node under the pointer (maintained by the editor widget).
  final ValueNotifier<String?> hoveredNodeId;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperEditorContext editContext,
  ) => _BlockHandleLayer(
    controller: controller,
    theme: theme,
    onTap: onTap,
    hoveredNodeId: hoveredNodeId,
    drag: drag,
  );
}

/// Callbacks of a block-handle drag (global pointer positions).
class BlockHandleDrag {
  const BlockHandleDrag({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Returns whether the block can be dragged.
  final bool Function(String nodeId, Offset globalPosition) onStart;
  final void Function(Offset globalPosition) onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

class _BlockHandleLayer extends DocumentLayoutLayerStatefulWidget {
  const _BlockHandleLayer({
    required this.controller,
    required this.theme,
    required this.onTap,
    required this.hoveredNodeId,
    this.drag,
  });

  final WriteEditorController controller;
  final EditorTheme theme;
  final void Function(String nodeId, Rect globalRect) onTap;
  final ValueNotifier<String?> hoveredNodeId;
  final BlockHandleDrag? drag;

  @override
  DocumentLayoutLayerState<_BlockHandleLayer, (String, Rect)?> createState() =>
      _BlockHandleLayerState();
}

class _BlockHandleLayerState
    extends DocumentLayoutLayerState<_BlockHandleLayer, (String, Rect)?> {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    widget.hoveredNodeId.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.hoveredNodeId.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  (String, Rect)? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final nodeId = widget.hoveredNodeId.value;
    if (nodeId == null) return null;
    final node = widget.controller.document.getNodeById(nodeId);
    if (node == null) return null;
    final rect = documentLayout.getRectForPosition(
      DocumentPosition(nodeId: nodeId, nodePosition: node.beginningPosition),
    );
    if (rect == null) return null;
    return (nodeId, rect);
  }

  @override
  Widget doBuild(BuildContext context, (String, Rect)? layoutData) {
    if (layoutData == null) return const SizedBox();
    final (nodeId, rect) = layoutData;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: rect.left - 28,
          top: rect.top + (rect.height - 24) / 2,
          child: Builder(
            builder: (handleContext) => MouseRegion(
              cursor: _dragging
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              child: GestureDetector(
                key: ValueKey('write.editor.blockHandle.$nodeId'),
                onPanStart: widget.drag == null
                    ? null
                    : (details) {
                        _dragging = widget.drag!.onStart(
                          nodeId,
                          details.globalPosition,
                        );
                        if (_dragging) setState(() {});
                      },
                onPanUpdate: widget.drag == null
                    ? null
                    : (details) {
                        if (_dragging) {
                          widget.drag!.onUpdate(details.globalPosition);
                        }
                      },
                onPanEnd: widget.drag == null
                    ? null
                    : (_) {
                        if (_dragging) widget.drag!.onEnd();
                        setState(() => _dragging = false);
                      },
                onPanCancel: widget.drag == null
                    ? null
                    : () {
                        if (_dragging) widget.drag!.onCancel();
                        setState(() => _dragging = false);
                      },
                onTap: () {
                  final box = handleContext.findRenderObject() as RenderBox?;
                  widget.onTap(
                    nodeId,
                    box == null
                        ? Rect.zero
                        : box.localToGlobal(Offset.zero) & box.size,
                  );
                },
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Icon(
                    Icons.drag_indicator,
                    size: 16,
                    color: widget.theme.mutedColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Finds the block under a document-space y coordinate (block handle hover).
String? nodeIdAtDocumentOffset(
  DocumentLayout layout,
  DocumentMirror mirror,
  Offset offset,
) {
  final position = layout.getDocumentPositionNearestToOffset(offset);
  return position?.nodeId;
}
