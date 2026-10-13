import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../controller/write_editor_controller.dart';
import '../model/document_queries.dart';
import '../styles/editor_theme.dart';

/// Where a drag would drop (Write 04 §22.5, §24).
@immutable
sealed class DropTargetSpot {
  const DropTargetSpot();
}

/// Between characters: Delta [offset] (text drops). Drawn as a caret.
final class CaretDropSpot extends DropTargetSpot {
  const CaretDropSpot(this.offset);

  final int offset;

  @override
  bool operator ==(Object other) =>
      other is CaretDropSpot && other.offset == offset;

  @override
  int get hashCode => offset.hashCode;
}

/// Between blocks: before the block at [index] (`nodeCount` = after the last
/// block). Drawn as a horizontal line across the content width.
final class BlockDropSpot extends DropTargetSpot {
  const BlockDropSpot(this.index);

  final int index;

  @override
  bool operator ==(Object other) =>
      other is BlockDropSpot && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// The current drop indicator of the editor (one at a time: text drag, block
/// drag or an external drop).
class DropIndicator extends ValueNotifier<DropTargetSpot?> {
  DropIndicator() : super(null);

  void clear() => value = null;
}

/// Geometry for drops over a laid-out document.
abstract final class DropGeometry {
  /// The component rectangle of [nodeId] in document layout coordinates.
  static Rect? blockRect(DocumentLayout layout, DocumentNode node) {
    final component = layout.getComponentByNodeId(node.id);
    final box = component?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return layout.getRectForSelection(
        DocumentPosition(nodeId: node.id, nodePosition: node.beginningPosition),
        DocumentPosition(nodeId: node.id, nodePosition: node.endPosition),
      );
    }
    final topLeft = layout.getDocumentOffsetFromAncestorOffset(
      box.localToGlobal(Offset.zero),
    );
    return topLeft & box.size;
  }

  /// The block boundary nearest to [layoutOffset] (`y` decides: above or
  /// below the middle of the block under the pointer).
  static int? blockIndexAt(
    DocumentLayout layout,
    WriteEditorController controller,
    Offset layoutOffset,
  ) {
    final mirror = controller.mirror;
    if (mirror.nodeCount == 0) return null;
    final position = layout.getDocumentPositionNearestToOffset(layoutOffset);
    if (position == null) return null;
    final index = mirror.indexOfNode(position.nodeId);
    if (index < 0) return null;
    final node = mirror.blockAt(index).node;
    final rect = blockRect(layout, node);
    if (rect == null) return index;
    return layoutOffset.dy < rect.center.dy ? index : index + 1;
  }

  /// The Delta offset nearest to [layoutOffset].
  static int? caretOffsetAt(
    DocumentLayout layout,
    WriteEditorController controller,
    Offset layoutOffset,
  ) {
    final position = layout.getDocumentPositionNearestToOffset(layoutOffset);
    return position == null ? null : controller.mirror.offsetOf(position);
  }
}

/// Paints the [DropIndicator] (overlay layer): a 2 px caret for text drops, a
/// 2 px line between blocks for block and file drops, in the accent color.
class DropIndicatorLayerBuilder implements SuperEditorLayerBuilder {
  const DropIndicatorLayerBuilder({
    required this.controller,
    required this.indicator,
    required this.theme,
  });

  final WriteEditorController controller;
  final DropIndicator indicator;
  final EditorTheme theme;

  @override
  ContentLayerWidget build(
    BuildContext context,
    SuperEditorContext editContext,
  ) => _DropIndicatorLayer(
    controller: controller,
    indicator: indicator,
    theme: theme,
  );
}

class _DropIndicatorLayer extends DocumentLayoutLayerStatefulWidget {
  const _DropIndicatorLayer({
    required this.controller,
    required this.indicator,
    required this.theme,
  });

  final WriteEditorController controller;
  final DropIndicator indicator;
  final EditorTheme theme;

  @override
  DocumentLayoutLayerState<_DropIndicatorLayer, Rect?> createState() =>
      _DropIndicatorLayerState();
}

class _DropIndicatorLayerState
    extends DocumentLayoutLayerState<_DropIndicatorLayer, Rect?> {
  @override
  void initState() {
    super.initState();
    widget.indicator.addListener(_onChange);
  }

  @override
  void didUpdateWidget(_DropIndicatorLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.indicator != widget.indicator) {
      oldWidget.indicator.removeListener(_onChange);
      widget.indicator.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.indicator.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Rect? computeLayoutDataWithDocumentLayout(
    BuildContext contentLayersContext,
    BuildContext documentContext,
    DocumentLayout documentLayout,
  ) {
    final spot = widget.indicator.value;
    final mirror = widget.controller.mirror;
    switch (spot) {
      case null:
        return null;
      case CaretDropSpot(:final offset):
        final position = mirror.positionAt(offset);
        if (position == null) return null;
        final rect = documentLayout.getRectForPosition(position);
        if (rect == null) return null;
        return Rect.fromLTWH(rect.left - 1, rect.top, 2, rect.height);
      case BlockDropSpot(:final index):
        if (mirror.nodeCount == 0) return null;
        final below = index < mirror.nodeCount;
        final node = mirror.blockAt(below ? index : mirror.nodeCount - 1).node;
        final rect = DropGeometry.blockRect(documentLayout, node);
        if (rect == null) return null;
        final y = below ? rect.top : rect.bottom;
        return Rect.fromLTWH(rect.left, y - 1, rect.width, 2);
    }
  }

  @override
  Widget doBuild(BuildContext context, Rect? layoutData) {
    if (layoutData == null) return const SizedBox();
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fromRect(
            key: const ValueKey<String>('write.editor.dropIndicator'),
            rect: layoutData,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.theme.ringColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
