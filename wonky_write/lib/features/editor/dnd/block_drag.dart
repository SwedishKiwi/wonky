import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../commands/write_editor_commands.dart';
import '../controller/write_editor_controller.dart';
import '../model/document_queries.dart';
import '../styles/editor_theme.dart';
import 'drop_indicator.dart';

/// Drag to reorder blocks with the ⋮⋮ handle (Write 04 §22.5): a ghost
/// follows the pointer, a drop line snaps between blocks, the viewport
/// auto-scrolls near its edges, Esc cancels, and the drop runs
/// `write.block.move` (one undo step "Move block"). A list item moves with
/// its descendants; dragging a block of a multi-block selection moves the
/// whole selection.
class BlockDragController extends ChangeNotifier {
  BlockDragController({
    required this.controller,
    required this.commands,
    required this.indicator,
    required this.scrollController,
  });

  final WriteEditorController controller;
  final WriteEditorCommands commands;
  final DropIndicator indicator;
  final ScrollController scrollController;

  List<String>? _nodeIds;
  int? _target;
  Offset? _pointer;
  Timer? _autoScroll;
  OverlayEntry? _ghost;
  String _ghostLabel = '';

  /// Whether a block drag is in progress.
  bool get isDragging => _nodeIds != null;

  /// The ids of the blocks being dragged.
  List<String> get nodeIds => _nodeIds ?? const [];

  /// The pointer position (global) while dragging.
  Offset? get pointer => _pointer;

  /// Starts dragging the block [nodeId] (or the selected blocks containing
  /// it). Returns false when blocks can't move (Viewing, Suggesting).
  bool start(
    String nodeId,
    Offset globalPosition, {
    BuildContext? overlayContext,
    EditorTheme? theme,
  }) {
    if (!commands.canMoveBlock(up: true, nodeId: nodeId) &&
        !commands.canMoveBlock(up: false, nodeId: nodeId)) {
      return false;
    }
    final selected = commands.blocksToMove();
    final ids = selected.any((b) => b.id == nodeId) && selected.length > 1
        ? [for (final b in selected) b.id]
        : [for (final b in commands.blocksToMove(nodeId: nodeId)) b.id];
    if (ids.isEmpty) return false;
    _nodeIds = ids;
    _pointer = globalPosition;
    _ghostLabel = _labelFor(ids);
    HardwareKeyboard.instance.addHandler(_onKey);
    if (overlayContext != null && theme != null) {
      _showGhost(overlayContext, theme);
    }
    notifyListeners();
    return true;
  }

  String _labelFor(List<String> ids) {
    final first = controller.mirror.blockOf(ids.first);
    if (first == null) return '';
    final node = first.node;
    final text = node is TextNode
        ? node.text.toPlainText().replaceAll('\n', ' ').trim()
        : switch (node) {
            ImageNode() => 'Image',
            TableBlockNode() => 'Table',
            HorizontalRuleNode() => 'Divider',
            _ => 'Block',
          };
    final short = text.length > 60 ? '${text.substring(0, 60)}…' : text;
    final more = ids.length > 1 ? ' (+${ids.length - 1})' : '';
    return '${short.isEmpty ? 'Empty line' : short}$more';
  }

  /// The pointer moved to [globalPosition].
  void update(Offset globalPosition) {
    if (!isDragging) return;
    _pointer = globalPosition;
    _ghost?.markNeedsBuild();
    _computeTarget();
    _updateAutoScroll();
  }

  void _computeTarget() {
    final layout = controller.documentLayout;
    final pointer = _pointer;
    final ids = _nodeIds;
    if (layout == null || pointer == null || ids == null) return;
    final local = layout.getDocumentOffsetFromAncestorOffset(pointer);
    final index = DropGeometry.blockIndexAt(layout, controller, local);
    final first = controller.mirror.indexOfNode(ids.first);
    final last = controller.mirror.indexOfNode(ids.last);
    if (index == null || first < 0 || (index >= first && index <= last + 1)) {
      _target = null;
      indicator.clear();
      return;
    }
    _target = index;
    indicator.value = BlockDropSpot(index);
  }

  void _updateAutoScroll() {
    final pointer = _pointer;
    final position = scrollController.hasClients
        ? scrollController.position
        : null;
    final box = position?.context.storageContext.findRenderObject();
    if (pointer == null || position == null || box is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    const edge = 48.0;
    double speed = 0;
    if (pointer.dy < top + edge) speed = -(top + edge - pointer.dy) / 2;
    if (pointer.dy > bottom - edge) speed = (pointer.dy - bottom + edge) / 2;
    if (speed == 0) {
      _autoScroll?.cancel();
      _autoScroll = null;
      return;
    }
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!scrollController.hasClients || !isDragging) return;
      final p = scrollController.position;
      final pointerNow = _pointer;
      if (pointerNow == null) return;
      double step = 0;
      if (pointerNow.dy < top + edge) step = -(top + edge - pointerNow.dy) / 2;
      if (pointerNow.dy > bottom - edge) {
        step = (pointerNow.dy - bottom + edge) / 2;
      }
      final next = (p.pixels + step).clamp(0.0, p.maxScrollExtent);
      if (next != p.pixels) {
        scrollController.jumpTo(next);
        _computeTarget();
      }
    });
  }

  /// Drops at the current target. Returns whether blocks moved.
  bool end() {
    final ids = _nodeIds;
    final target = _target;
    _finish();
    if (ids == null || target == null) return false;
    return commands.moveBlocks(ids, target, label: 'Move block');
  }

  /// Cancels the drag (Esc, gesture cancel).
  void cancel() => _finish();

  void _finish() {
    if (_nodeIds != null) HardwareKeyboard.instance.removeHandler(_onKey);
    _nodeIds = null;
    _target = null;
    _pointer = null;
    _autoScroll?.cancel();
    _autoScroll = null;
    _ghost?.remove();
    _ghost = null;
    indicator.clear();
    notifyListeners();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        isDragging) {
      _finish();
      return true;
    }
    return false;
  }

  void _showGhost(BuildContext context, EditorTheme theme) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _ghost = OverlayEntry(
      builder: (context) {
        final pointer = _pointer;
        if (pointer == null) return const SizedBox();
        return Positioned(
          left: pointer.dx + 12,
          top: pointer.dy - 14,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: 0.6,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 120),
              child: Material(
                key: const ValueKey<String>('write.editor.blockDragGhost'),
                color: theme.paperColor,
                elevation: 4,
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 320,
                    maxHeight: 320,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      _ghostLabel,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.body.copyWith(fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_ghost!);
  }

  @override
  void dispose() {
    _finish();
    super.dispose();
  }
}
