import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Style key of a laid-out cell text.
@immutable
class GridTextStyle {
  const GridTextStyle({
    required this.fontFamily,
    required this.fontSize,
    required this.color,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.align = TextAlign.left,
  });

  final String fontFamily;

  /// Size in logical px (already multiplied by zoom).
  final double fontSize;
  final Color color;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final TextAlign align;

  @override
  bool operator ==(Object other) =>
      other is GridTextStyle &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize &&
      other.color == color &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.strikethrough == strikethrough &&
      other.align == align;

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontSize,
    color,
    bold,
    italic,
    underline,
    strikethrough,
    align,
  );
}

/// LRU cache of laid-out cell paragraphs (03 §2.6 `TextLayoutCache`), keyed
/// by text, style and wrap width. Unwrapped text is laid out once with an
/// infinite width; its `maxIntrinsicWidth` drives overflow.
class TextLayoutCache {
  TextLayoutCache({this.capacity = 20000});

  final int capacity;
  final LinkedHashMap<(String, GridTextStyle, double?), ui.Paragraph> _map =
      LinkedHashMap();
  int hits = 0;
  int misses = 0;

  int get length => _map.length;

  /// The laid-out paragraph of [text]. [wrapWidth] wraps (null = single
  /// line per `\n`, unbounded width).
  ui.Paragraph layout(String text, GridTextStyle style, {double? wrapWidth}) {
    final key = (text, style, wrapWidth);
    final hit = _map.remove(key);
    if (hit != null) {
      hits++;
      _map[key] = hit;
      return hit;
    }
    misses++;
    final p = _build(text, style, wrapWidth);
    _map[key] = p;
    if (_map.length > capacity) {
      final first = _map.keys.first;
      _map.remove(first)?.dispose();
    }
    return p;
  }

  static ui.Paragraph _build(
    String text,
    GridTextStyle style,
    double? wrapWidth,
  ) {
    final decorations = <TextDecoration>[
      if (style.underline) TextDecoration.underline,
      if (style.strikethrough) TextDecoration.lineThrough,
    ];
    final b =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: style.align,
              fontFamily: style.fontFamily,
              fontSize: style.fontSize,
              height: 1.2,
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: style.color,
              fontFamily: style.fontFamily,
              fontFamilyFallback: const ['Inter', 'Geist', 'Roboto'],
              fontSize: style.fontSize,
              fontWeight: style.bold ? FontWeight.w700 : FontWeight.w400,
              fontStyle: style.italic ? FontStyle.italic : FontStyle.normal,
              decoration: decorations.isEmpty
                  ? null
                  : TextDecoration.combine(decorations),
              decorationColor: style.color,
              height: 1.2,
            ),
          )
          ..addText(text);
    final p = b.build();
    p.layout(ui.ParagraphConstraints(width: wrapWidth ?? double.infinity));
    if (wrapWidth == null) {
      // Re-layout to the intrinsic width so alignment inside the paragraph
      // is relative to the text block.
      p.layout(ui.ParagraphConstraints(width: p.maxIntrinsicWidth + 0.5));
    }
    return p;
  }

  void clear() {
    for (final p in _map.values) {
      p.dispose();
    }
    _map.clear();
  }
}
