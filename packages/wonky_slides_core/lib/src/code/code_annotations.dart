/// Per-step callouts: `CodeState.annotationsJson` (Slides 07 §4.4).
library;

import '../theme/json/json_util.dart';
import 'code_element_data.dart';

/// One callout of a highlight step.
final class CodeCallout {
  const CodeCallout({
    required this.text,
    this.anchorLine,
    this.side = 'auto',
    this.style,
    this.dx = 0,
    this.dy = 0,
  });

  /// Inline Markdown (bold, italic, code), at most [maxLength] characters.
  final String text;

  /// 1-based anchor line; null = the step's last highlighted line.
  final int? anchorLine;

  /// `auto`, `right`, `left`, `above`, `below`.
  final String side;

  /// `bubble`, `label`, `pill`; null = the element default.
  final String? style;

  /// Nudge (su) set by dragging.
  final double dx;
  final double dy;

  /// Maximum text length.
  static const maxLength = 280;

  /// Sides.
  static const sides = {'auto', 'right', 'left', 'above', 'below'};

  JsonMap toJson() => {
    'text': text,
    if (anchorLine != null || side != 'auto')
      'anchor': {'line': ?anchorLine, 'side': side},
    'style': ?style,
    if (dx != 0) 'dx': dx,
    if (dy != 0) 'dy': dy,
  };

  /// Parses one callout; null when it has no text.
  static CodeCallout? fromJson(Object? json) {
    if (json is! Map || json['text'] is! String) return null;
    var text = json['text'] as String;
    if (text.trim().isEmpty) return null;
    if (text.length > maxLength) text = text.substring(0, maxLength);
    final anchor = json['anchor'];
    int? line;
    var side = 'auto';
    if (anchor is Map) {
      final l = anchor['line'];
      if (l is num && l.isFinite && l >= 1) line = l.round();
      if (sides.contains(anchor['side'])) side = anchor['side'] as String;
    }
    final style = json['style'];
    double nudge(Object? v) => v is num && v.isFinite ? v.toDouble() : 0;
    return CodeCallout(
      text: text,
      anchorLine: line,
      side: side,
      style: calloutStyles.contains(style) ? style as String : null,
      dx: nudge(json['dx']),
      dy: nudge(json['dy']),
    );
  }
}

/// The callouts of one code state by 0-based step index.
final class CodeAnnotations {
  const CodeAnnotations([this.steps = const {}]);

  static const empty = CodeAnnotations();

  /// 0-based step → callout.
  final Map<int, CodeCallout> steps;

  /// The callout of [step] (0-based), or null.
  CodeCallout? operator [](int step) => steps[step];

  /// The JSON column (`steps` keys are 1-based strings, 07 §4.4).
  JsonMap toJson() => {
    'v': 1,
    'steps': {
      for (final e
          in (steps.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        '${e.key + 1}': e.value.toJson(),
    },
  };

  /// Parses `annotationsJson` (a decoded map, or null); invalid entries are
  /// skipped.
  static CodeAnnotations fromJson(Object? json) {
    if (json is! Map || json['steps'] is! Map) return empty;
    final out = <int, CodeCallout>{};
    (json['steps'] as Map).forEach((k, v) {
      final n = int.tryParse('$k');
      final c = CodeCallout.fromJson(v);
      if (n != null && n >= 1 && c != null) out[n - 1] = c;
    });
    return CodeAnnotations(out);
  }
}
