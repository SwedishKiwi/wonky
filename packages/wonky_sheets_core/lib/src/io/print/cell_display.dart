import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../content/rich_text.dart';
import '../../engine_bridge/value_bridge.dart';
import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../format/format_resolver.dart';
import '../../format/number_format/number_formatter.dart';
import '../../formula/model/workbook_view.dart';
import '../../model/events.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';

/// Result of conditional formatting for one cell (06 §15): the format
/// overlay (bold/italic/underline/strikethrough/textColor/fillColor) and an
/// optional data bar.
final class ConditionalOverlay {
  /// Creates an overlay.
  const ConditionalOverlay({
    this.format,
    this.dataBarFraction,
    this.dataBarColor,
    this.dataBarStart = 0,
  });

  /// Format attributes that win over everything (06 §1.2).
  final CellFormat? format;

  /// Data bar length as a fraction of the cell width (0..1), if any.
  final double? dataBarFraction;

  /// Data bar color (`#RRGGBB` / `theme:*`).
  final String? dataBarColor;

  /// Fraction where the bar starts (negative values / axis position).
  final double dataBarStart;
}

/// Supplies conditional formatting results (the CF evaluator adapts to this).
typedef ConditionalOverlayProvider =
    ConditionalOverlay? Function(String sheetId, int row, int col);

/// The four resolved edges of a cell (shared-edge conflicts already applied,
/// 06 §8.4); null = no border.
typedef CellEdges = ({
  BorderSpec? top,
  BorderSpec? right,
  BorderSpec? bottom,
  BorderSpec? left,
});

/// In-cell widget of a cell (03 §14.1–14.2).
enum CellWidgetKind { none, checkbox, dropdownChip, dropdownArrow }

/// Data validation information relevant for rendering.
final class CellWidgetInfo {
  /// Creates widget info.
  const CellWidgetInfo(
    this.kind, {
    this.checked = false,
    this.chipFill,
    this.chipText,
  });

  /// No widget.
  static const none = CellWidgetInfo(CellWidgetKind.none);

  final CellWidgetKind kind;

  /// Checkbox state.
  final bool checked;

  /// Chip background / text color of the selected option (`#RRGGBB`), if any.
  final String? chipFill;
  final String? chipText;
}

/// Everything needed to display one cell outside the grid (clipboard HTML,
/// HTML export, print/PDF): value, formatted text, effective format (incl.
/// banding and CF), resolved colors and alignment, rich runs, link, widget.
final class CellDisplay {
  /// Creates a display record.
  const CellDisplay({
    required this.row,
    required this.col,
    required this.record,
    required this.content,
    required this.value,
    required this.formatted,
    required this.format,
    required this.numberFormat,
    required this.hAlign,
    required this.textColor,
    required this.fillColor,
    required this.underline,
    required this.widget,
    this.conditional,
    this.rich,
    this.linkUrl,
  });

  final int row;
  final int col;
  final CellRecord? record;
  final CellContent? content;

  /// Computed value (literal or formula result or overlay).
  final CellValue value;

  /// Number-formatted value.
  final FormattedValue formatted;

  /// Effective format (CF overlay, explicit chain, banding, theme defaults).
  final ResolvedFormat format;

  /// The number format used (explicit, else the formula's format hint, else
  /// Automatic).
  final String numberFormat;

  /// Resolved alignment (general alignment applied, 06 §9.1).
  final HorizontalAlign hAlign;

  /// Final text color `#RRGGBB` (CF ▸ number-format color ▸ explicit ▸ link
  /// color); null = automatic.
  final String? textColor;

  /// Final fill `#RRGGBB` (CF ▸ explicit ▸ banding); null = none.
  final String? fillColor;

  /// Whether the text is underlined (explicit, or link default).
  final bool underline;
  final CellWidgetInfo widget;
  final ConditionalOverlay? conditional;

  /// Rich runs (text cells only).
  final RichText? rich;

  /// Whole-cell link.
  final String? linkUrl;

  /// Display text (repeat segments dropped, spacers as spaces).
  String get text => formatted.plainText;

  /// Whether nothing is shown (no text and no widget).
  bool get isBlank => text.isEmpty && widget.kind == CellWidgetKind.none;

  /// Whether the value is a number/date that renders `####` when too wide.
  bool get numberLike => formatted.overflowHashes || value is NumberValue;

  /// Whether the cell holds a formula.
  bool get isFormula => content is FormulaContent;
}

/// Builds [CellDisplay]s for a workbook and a computed-value source.
final class CellDisplayResolver {
  /// Creates a resolver. [locale] defaults to the spreadsheet locale.
  CellDisplayResolver(
    this.model,
    this.source, {
    String? locale,
    this.conditional,
    NumberFormatter? formatter,
    this.includeBanding = true,
  }) : locale = locale ?? model.spreadsheet.locale,
       formatter = formatter ?? NumberFormatter.instance,
       formats = EffectiveFormatResolver(model);

  final WorkbookModel model;
  final CellSource source;
  final String locale;
  final ConditionalOverlayProvider? conditional;
  final NumberFormatter formatter;
  final EffectiveFormatResolver formats;
  final bool includeBanding;

  final Map<String, _DvInfo?> _dvCache = {};

  /// Display data of the cell at indices.
  CellDisplay display(String sheetId, int row, int col) {
    final sheet = model.sheet(sheetId);
    final record = sheet?.cellAt(row, col);
    final content = record?.decoded;
    final value = source.valueAt(sheetId, row, col).toCellValue();
    final cf = conditional?.call(sheetId, row, col);
    final rf = formats.resolve(
      sheetId,
      row,
      col,
      conditional: cf?.format,
      includeBanding: includeBanding,
    );
    final pattern = rf.numberFormatExplicit
        ? rf.numberFormat
        : (source.numberFormatAt(sheetId, row, col) ?? kAutomaticNumberFormat);
    final formatted = formatter.format(value, pattern, locale: locale);
    final widget = sheet == null
        ? CellWidgetInfo.none
        : _widget(sheet, row, col, value, formatted);
    final theme = model.theme;

    final explicit = formats.explicit(sheetId, row, col);
    final rich = content is RichTextContent ? content.rich : null;
    final link = rf.linkUrl;
    final cfText = cf?.format?[FormatAttr.textColor] as String?;
    String? textColor;
    if (cfText != null) {
      textColor = theme.resolveColor(cfText);
    } else if (formatted.colorArgb != null) {
      textColor = _hex(formatted.colorArgb!);
    } else if (rf.textColor != null) {
      textColor = theme.resolveColor(rf.textColor);
    } else if (link != null) {
      textColor = theme.resolveColor('theme:link');
    }
    final underline =
        rf.underline ||
        (link != null &&
            !explicit.has(FormatAttr.underline) &&
            cf?.format?[FormatAttr.underline] == null);
    final align = rf.hAlign ?? _generalAlign(value, widget.kind);
    return CellDisplay(
      row: row,
      col: col,
      record: record,
      content: content,
      value: value,
      formatted: formatted,
      format: rf,
      numberFormat: pattern,
      hAlign: align,
      textColor: textColor,
      fillColor: theme.resolveColor(rf.fillColor),
      underline: underline,
      widget: widget,
      conditional: cf,
      rich: rich,
      linkUrl: link,
    );
  }

  /// Whether the cell shows anything or holds content (overflow neighbours
  /// must be empty: no content, no overlay value, no widget, 03 §2.6).
  bool hasContent(String sheetId, int row, int col) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return false;
    final rec = sheet.cellAt(row, col);
    if (rec?.content != null) return true;
    if (!source.valueAt(sheetId, row, col).toCellValue().isBlank()) return true;
    final dv = _dvAt(sheet, row, col);
    return dv != null && dv.kind != CellWidgetKind.none;
  }

  /// The resolved edges of the cell at (row, col) — or of the merged area
  /// whose bottom-right cell is ([bottomRow], [rightCol]) — with shared-edge
  /// conflicts resolved against the neighbours (06 §8.4–8.5).
  CellEdges edges(
    String sheetId,
    int row,
    int col, {
    int? bottomRow,
    int? rightCol,
  }) {
    final b = bottomRow ?? row;
    final r = rightCol ?? col;
    BorderSpec? vis(BorderSpec? s) => s == null || s.isNone ? null : s;
    return (
      top: vis(
        row > 0
            ? formats.edgeBelow(sheetId, row - 1, col)
            : formats.outerEdge(sheetId, row, col, FormatAttr.borderTop),
      ),
      left: vis(
        col > 0
            ? formats.edgeRight(sheetId, row, col - 1)
            : formats.outerEdge(sheetId, row, col, FormatAttr.borderLeft),
      ),
      bottom: vis(formats.edgeBelow(sheetId, b, col)),
      right: vis(formats.edgeRight(sheetId, row, r)),
    );
  }

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static HorizontalAlign _generalAlign(CellValue v, CellWidgetKind w) {
    if (w == CellWidgetKind.checkbox) return HorizontalAlign.center;
    if (w == CellWidgetKind.dropdownChip) return HorizontalAlign.left;
    return switch (v) {
      NumberValue() => HorizontalAlign.right,
      BoolValue() || ErrorValue() => HorizontalAlign.center,
      _ => HorizontalAlign.left,
    };
  }

  CellWidgetInfo _widget(
    SheetModel s,
    int row,
    int col,
    CellValue v,
    FormattedValue f,
  ) {
    final dv = _dvAt(s, row, col);
    if (dv == null) return CellWidgetInfo.none;
    switch (dv.kind) {
      case CellWidgetKind.checkbox:
        return CellWidgetInfo(
          CellWidgetKind.checkbox,
          checked: dv.isChecked(v),
        );
      case CellWidgetKind.dropdownChip:
      case CellWidgetKind.dropdownArrow:
        final text = f.plainText;
        final colors = dv.colors[text];
        return CellWidgetInfo(
          dv.kind,
          chipFill: colors?.$1,
          chipText: colors?.$2,
        );
      case CellWidgetKind.none:
        return CellWidgetInfo.none;
    }
  }

  _DvInfo? _dvAt(SheetModel s, int row, int col) {
    final ids = s.rulesAt(RuleKind.dataValidation, row, col);
    if (ids.isEmpty) return null;
    DvRuleRecord? best;
    for (final id in ids) {
      final r = s.dvRules[id];
      if (r == null) continue;
      if (best == null ||
          r.createdAt.isAfter(best.createdAt) ||
          (r.createdAt == best.createdAt && r.id.compareTo(best.id) > 0)) {
        best = r;
      }
    }
    if (best == null) return null;
    final rule = best;
    return _dvCache.putIfAbsent(
      '${rule.id}|${rule.criteriaJson}|${rule.displayStyle}',
      () {
        return _DvInfo.parse(rule);
      },
    );
  }
}

final class _DvInfo {
  _DvInfo(this.kind, {this.checked, this.colors = const {}});

  final CellWidgetKind kind;
  final String? checked;
  final Map<String, (String?, String?)> colors;

  bool isChecked(CellValue v) {
    if (checked == null) return v is BoolValue && v.value;
    return switch (v) {
      TextValue(:final text) => text == checked,
      NumberValue(:final number) => CellContent.formatNumber(number) == checked,
      BoolValue(:final value) =>
        (value ? 'TRUE' : 'FALSE') == checked!.toUpperCase(),
      _ => false,
    };
  }

  static _DvInfo? parse(DvRuleRecord r) {
    Object? m;
    try {
      m = jsonDecode(r.criteriaJson);
    } on FormatException {
      return null;
    }
    if (m is! Map) return null;
    final type = m['type'];
    if (type == 'checkbox') {
      final c = m['checked'];
      return _DvInfo(CellWidgetKind.checkbox, checked: c is String ? c : null);
    }
    if (type == 'oneOfList' || type == 'oneOfRange') {
      final style = r.displayStyle ?? (r.showDropdown ? 'chip' : 'plainText');
      final kind = switch (style) {
        'arrow' => CellWidgetKind.dropdownArrow,
        'plainText' => CellWidgetKind.none,
        _ => CellWidgetKind.dropdownChip,
      };
      final colors = <String, (String?, String?)>{};
      final options = m['options'];
      if (options is List) {
        for (final o in options) {
          if (o is Map && o['value'] != null) {
            colors[o['value'].toString()] = (
              o['bg'] as String?,
              o['fg'] as String?,
            );
          }
        }
      }
      final cm = m['colors'];
      if (cm is Map) {
        cm.forEach((k, v) {
          if (v is Map) {
            colors[k.toString()] = (v['bg'] as String?, v['fg'] as String?);
          }
        });
      }
      return _DvInfo(kind, colors: colors);
    }
    return null;
  }
}

/// Helpers to locate embedded objects (08 §1.2) in sheet coordinates.
final class PrintObjectPlacement {
  /// Creates a placement.
  const PrintObjectPlacement({
    required this.row,
    required this.col,
    required this.dx,
    required this.dy,
    required this.width,
    required this.height,
    this.ownSheet = false,
    this.lockAspect = false,
  });

  /// Anchor cell indices.
  final int row;
  final int col;

  /// Offset inside the anchor cell and size, px at 100 %.
  final double dx;
  final double dy;
  final double width;
  final double height;

  /// Object on a chart sheet.
  final bool ownSheet;
  final bool lockAspect;

  /// Resolves the anchor of [obj] on [sheet]; null when it doesn't resolve.
  static PrintObjectPlacement? of(SheetModel sheet, EmbeddedObjectRecord obj) {
    Object? m;
    try {
      m = jsonDecode(obj.anchorJson);
    } on FormatException {
      return null;
    }
    if (m is! Map) return null;
    double d(String k, double def) =>
        m is Map && m[k] is num ? (m[k] as num).toDouble() : def;
    if (m['ownSheet'] == true) {
      return PrintObjectPlacement(
        row: 0,
        col: 0,
        dx: 0,
        dy: 0,
        width: d('width', 600),
        height: d('height', 371),
        ownSheet: true,
        lockAspect: m['lockAspect'] == true,
      );
    }
    final rowId = m['rowId'];
    final colId = m['colId'];
    if (rowId is! String || colId is! String) return null;
    final r = sheet.rows.indexOf(_decodeId(rowId));
    final c = sheet.columns.indexOf(_decodeId(colId));
    if (r < 0 || c < 0) return null;
    return PrintObjectPlacement(
      row: r,
      col: c,
      dx: d('dx', 0).clamp(0, double.infinity),
      dy: d('dy', 0).clamp(0, double.infinity),
      width: d('width', 600).clamp(1, 100000),
      height: d('height', 371).clamp(1, 100000),
      lockAspect: m['lockAspect'] == true,
    );
  }

  static String _decodeId(String id) {
    if (id.length == Base62Uuid.length &&
        !id.contains('-') &&
        Base62Uuid.isValid(id)) {
      return Base62Uuid.decode(id);
    }
    return id;
  }

  /// The cell rectangle covered by the object given the sheet's natural
  /// sizes (hidden rows/columns count as zero).
  GridRect coveredCells(SheetModel sheet) {
    var r = row;
    final bottom = (sheet.rows.isHidden(row) ? 0.0 : dy) + height;
    var acc = 0.0;
    while (r < sheet.rows.length - 1) {
      final h = sheet.rows.isHidden(r) ? 0.0 : sheet.rows.naturalSizeAt(r);
      if (acc + h >= bottom) break;
      acc += h;
      r++;
    }
    var c = col;
    final right = (sheet.columns.isHidden(col) ? 0.0 : dx) + width;
    acc = 0;
    while (c < sheet.columns.length - 1) {
      final w = sheet.columns.isHidden(c)
          ? 0.0
          : sheet.columns.naturalSizeAt(c);
      if (acc + w >= right) break;
      acc += w;
      c++;
    }
    return GridRect(row, col, r, c);
  }
}
