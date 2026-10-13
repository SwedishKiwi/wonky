import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// Focus mode (Write 04 §30): every block except the caret block (or the
/// blocks touched by the selection) is dimmed to [dimmedAlpha]. Presentation
/// only; the document is never changed.
class FocusModeStylePhase extends SingleColumnLayoutStylePhase {
  FocusModeStylePhase({this.dimmedAlpha = 0.35});

  /// Opacity of the text of unfocused blocks.
  final double dimmedAlpha;

  bool _enabled = false;

  /// Whether focus mode is on.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markDirty();
  }

  Set<String> _focused = const {};

  /// Sets the ids of the focused blocks (re-styles when they change).
  void setFocusedNodes(Set<String> nodeIds) {
    if (_focused.length == nodeIds.length && _focused.containsAll(nodeIds)) {
      return;
    }
    _focused = nodeIds;
    if (_enabled) markDirty();
  }

  /// The blocks touched by [selection] in [document].
  static Set<String> nodesOf(Document document, DocumentSelection? selection) {
    if (selection == null) return const {};
    final base = document.getNodeIndexById(selection.base.nodeId);
    final extent = document.getNodeIndexById(selection.extent.nodeId);
    if (base < 0 || extent < 0) return const {};
    final from = base < extent ? base : extent;
    final to = base < extent ? extent : base;
    return {for (var i = from; i <= to; i += 1) document.getNodeAt(i)!.id};
  }

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    if (!_enabled || _focused.isEmpty) return viewModel;
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final model in viewModel.componentViewModels)
          _focused.contains(model.nodeId) ? model : _dim(model),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _dim(
    SingleColumnLayoutComponentViewModel model,
  ) {
    final copy = model.copy();
    if (copy is TextComponentViewModel) {
      final builder = copy.textStyleBuilder;
      copy.textStyleBuilder = (attributions) {
        final style = builder(attributions);
        final color = style.color ?? const Color(0xff000000);
        return style.copyWith(
          color: color.withValues(alpha: color.a * dimmedAlpha),
        );
      };
    } else {
      copy.opacity = dimmedAlpha;
    }
    return copy;
  }
}
