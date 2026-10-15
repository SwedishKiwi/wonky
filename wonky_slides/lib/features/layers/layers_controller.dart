import 'package:flutter/foundation.dart';

import '../editor_screen/deck_editor_controller.dart';

/// The tabs of the Layers panel (03 §8.1).
enum LayersTab {
  layers,

  /// The reading order list (03 §17.2).
  readingOrder;

  static LayersTab? fromName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

/// The Layers panel state of [editor] (one per open deck).
LayersController layersOf(DeckEditorController editor) =>
    LayersController._of[editor] ??= LayersController._();

/// View state of the Layers panel (not undoable, not synced): the tab, the
/// collapsed element groups, the *From layout* section and the row being
/// renamed.
class LayersController extends ChangeNotifier {
  LayersController._();

  static final Expando<LayersController> _of = Expando('layers');

  LayersTab _tab = LayersTab.layers;
  final Set<String> _collapsed = {};
  bool _layoutOpen = false;
  String? _renaming;

  LayersTab get tab => _tab;

  set tab(LayersTab t) {
    if (t == _tab) return;
    _tab = t;
    notifyListeners();
  }

  /// Whether element group [id] is collapsed in the tree.
  bool isCollapsed(String id) => _collapsed.contains(id);

  void toggleCollapsed(String id) {
    if (!_collapsed.remove(id)) _collapsed.add(id);
    notifyListeners();
  }

  /// Whether the *From layout* section is open.
  bool get layoutOpen => _layoutOpen;

  set layoutOpen(bool v) {
    if (v == _layoutOpen) return;
    _layoutOpen = v;
    notifyListeners();
  }

  /// The element whose name is being edited inline, or null.
  String? get renaming => _renaming;

  set renaming(String? id) {
    if (id == _renaming) return;
    _renaming = id;
    notifyListeners();
  }
}
