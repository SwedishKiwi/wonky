import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../theme/sheets_tokens.dart';
import '../grid/paint/text_layout_cache.dart';
import 'cell_fonts.dart';

/// Lays out cell text with rich runs (06 §11, 03 §8.8): the cell's [base]
/// style for text outside runs, run attributes inside them. Conditional
/// formatting attributes win over runs (precedence CF > run > cell), so keys
/// set by the CF overlay are ignored in runs.
class RichTextLayoutCache {
  RichTextLayoutCache({this.capacity = 2000});

  final int capacity;
  final LinkedHashMap<Object, ui.Paragraph> _map = LinkedHashMap();

  /// The paragraph of [rich]. [pxPerPoint] converts run font sizes (pt) to
  /// px at the current zoom; [linkColor] colors link runs without a color.
  ui.Paragraph layout(
    RichText rich,
    GridTextStyle base, {
    required double pxPerPoint,
    required Color linkColor,
    required String? Function(String? color) resolveColor,
    CellFormat? conditional,
    double? wrapWidth,
  }) {
    final key = (rich, base, pxPerPoint, linkColor, conditional, wrapWidth);
    final hit = _map.remove(key);
    if (hit != null) {
      _map[key] = hit;
      return hit;
    }
    final p = _build(
      rich,
      base,
      pxPerPoint,
      linkColor,
      resolveColor,
      conditional,
      wrapWidth,
    );
    _map[key] = p;
    if (_map.length > capacity) _map.remove(_map.keys.first)?.dispose();
    return p;
  }

  static ui.TextStyle _style(
    GridTextStyle base, {
    Map<String, Object?> run = const {},
    required double pxPerPoint,
    required Color linkColor,
    required String? Function(String? color) resolveColor,
    CellFormat? conditional,
  }) {
    bool cf(FormatAttr a) => conditional?.has(a) ?? false;
    final link = run[RichRunKeys.link] is String;
    final bold = !cf(FormatAttr.bold) && run[RichRunKeys.bold] is bool
        ? run[RichRunKeys.bold]! as bool
        : base.bold;
    final italic = !cf(FormatAttr.italic) && run[RichRunKeys.italic] is bool
        ? run[RichRunKeys.italic]! as bool
        : base.italic;
    var underline =
        !cf(FormatAttr.underline) && run[RichRunKeys.underline] is bool
        ? run[RichRunKeys.underline]! as bool
        : base.underline;
    if (link && run[RichRunKeys.underline] == null) underline = true;
    final strike =
        !cf(FormatAttr.strikethrough) && run[RichRunKeys.strikethrough] is bool
        ? run[RichRunKeys.strikethrough]! as bool
        : base.strikethrough;
    var color = base.color;
    if (!cf(FormatAttr.textColor)) {
      final c = hexToColor(resolveColor(run[RichRunKeys.textColor] as String?));
      if (c != null) {
        color = c;
      } else if (link) {
        color = linkColor;
      }
    }
    final family = run[RichRunKeys.fontFamily] is String
        ? CellFonts.screenFamily(run[RichRunKeys.fontFamily]! as String)
        : base.fontFamily;
    final size = run[RichRunKeys.fontSize] is num
        ? (run[RichRunKeys.fontSize]! as num).toDouble() * pxPerPoint
        : base.fontSize;
    final decorations = <TextDecoration>[
      if (underline) TextDecoration.underline,
      if (strike) TextDecoration.lineThrough,
    ];
    return ui.TextStyle(
      color: color,
      fontFamily: family,
      fontFamilyFallback: CellFonts.fallback,
      fontSize: size,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      decoration: decorations.isEmpty
          ? null
          : TextDecoration.combine(decorations),
      decorationColor: color,
      height: 1.2,
    );
  }

  static ui.Paragraph _build(
    RichText rich,
    GridTextStyle base,
    double pxPerPoint,
    Color linkColor,
    String? Function(String?) resolveColor,
    CellFormat? conditional,
    double? wrapWidth,
  ) {
    final b = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: base.align,
        fontFamily: base.fontFamily,
        fontSize: base.fontSize,
        height: 1.2,
      ),
    );
    ui.TextStyle style([Map<String, Object?> run = const {}]) => _style(
      base,
      run: run,
      pxPerPoint: pxPerPoint,
      linkColor: linkColor,
      resolveColor: resolveColor,
      conditional: conditional,
    );
    final text = rich.text;
    final runs = [...rich.runs]..sort((a, b) => a.start.compareTo(b.start));
    var pos = 0;
    for (final r in runs) {
      final s = r.start.clamp(pos, text.length);
      final e = r.end.clamp(s, text.length);
      if (s > pos) {
        b
          ..pushStyle(style())
          ..addText(text.substring(pos, s))
          ..pop();
      }
      if (e > s) {
        b
          ..pushStyle(style(r.format))
          ..addText(text.substring(s, e))
          ..pop();
      }
      pos = e;
    }
    if (pos < text.length) {
      b
        ..pushStyle(style())
        ..addText(text.substring(pos))
        ..pop();
    }
    final p = b.build();
    p.layout(ui.ParagraphConstraints(width: wrapWidth ?? double.infinity));
    if (wrapWidth == null) {
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

/// The shared rich-text layout cache of the grid painters.
final RichTextLayoutCache richTextLayouts = RichTextLayoutCache();
