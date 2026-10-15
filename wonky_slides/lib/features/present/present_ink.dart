import 'dart:ui';

import 'package:wonky_ui/wonky_ui.dart' show InkStroke, InkTool;

export 'package:wonky_ui/wonky_ui.dart'
    show InkStroke, InkStrokePainter, InkTool, OneEuroFilter;

/// A present tool (Slides 10 §2.1, §4): the arrow (navigation clicks), the
/// laser pointer, pen, highlighter and eraser.
enum PresentTool {
  arrow,
  laser,
  pen,
  highlighter,
  eraser;

  static PresentTool? fromName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }

  bool get draws => this == pen || this == highlighter;

  /// The ink tool of a drawing tool ([draws]).
  InkTool? get inkTool => switch (this) {
    pen => InkTool.pen,
    highlighter => InkTool.highlighter,
    _ => null,
  };
}

/// The ink colors (§4.3: red, blue, green, amber, white, black).
abstract final class InkColors {
  static const Map<String, int> all = {
    'red': 0xffef4444,
    'blue': 0xff3b82f6,
    'green': 0xff22c55e,
    'amber': 0xfff59e0b,
    'white': 0xffffffff,
    'black': 0xff111111,
  };

  /// Pen widths in slide units (§4.3: thin, medium, thick).
  static const Map<String, double> penWidths = {
    'thin': 4,
    'medium': 8,
    'thick': 14,
  };

  /// The highlighter's width (su) and opacity (§4.3).
  static const highlighterWidth = 28.0;
  static const highlighterOpacity = 0.4;
}

/// The ink of a presentation (§4.3): strokes per slide, in memory only —
/// kept while navigating, discarded when presenting ends. [undo] removes
/// the last stroke of a slide (a local stack, not the document undo).
class InkModel {
  final Map<String, List<InkStroke>> _bySlide = {};

  List<InkStroke> strokesOf(String slideId) =>
      List.unmodifiable(_bySlide[slideId] ?? const <InkStroke>[]);

  bool hasInk(String slideId) => _bySlide[slideId]?.isNotEmpty ?? false;

  /// Adds or replaces (same id) a stroke.
  void put(String slideId, InkStroke stroke) {
    final list = _bySlide.putIfAbsent(slideId, () => []);
    final i = list.indexWhere((s) => s.id == stroke.id);
    if (i >= 0) {
      list[i] = stroke;
    } else {
      list.add(stroke);
    }
  }

  bool remove(String slideId, String strokeId) {
    final list = _bySlide[slideId];
    if (list == null) return false;
    final before = list.length;
    list.removeWhere((s) => s.id == strokeId);
    return list.length != before;
  }

  /// Removes every stroke [p] touches; returns their ids.
  List<String> eraseAt(String slideId, Offset p, double radius) {
    final list = _bySlide[slideId];
    if (list == null) return const [];
    final hit = [
      for (final s in list)
        if (s.touches(p, radius)) s.id,
    ];
    list.removeWhere((s) => hit.contains(s.id));
    return hit;
  }

  /// Removes the last stroke of [slideId]; returns its id.
  String? undo(String slideId) {
    final list = _bySlide[slideId];
    if (list == null || list.isEmpty) return null;
    return list.removeLast().id;
  }

  void clear(String slideId) => _bySlide.remove(slideId);

  void clearAll() => _bySlide.clear();
}
