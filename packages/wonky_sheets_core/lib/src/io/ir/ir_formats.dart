import 'package:wonky_numfmt/wonky_numfmt.dart';

import '../../format/attributes.dart';
import '../../format/borders.dart';
import '../../model/schema.dart';
import 'workbook_document.dart';

/// Format inheritance of the IR (Wonky semantics, 02 §3.3): the effective
/// format of a cell is sheet default ▸ column ▸ row ▸ cell, per attribute.
///
/// Formats that are complete by themselves (an XLSX cell `xf` ignores the
/// column and row styles) are made relative with [relative]: attributes the
/// inheritance already provides are dropped, inherited attributes the format
/// does not set get an explicit default ([resetValue]).
abstract final class IrFormats {
  /// The explicit "default look" value of [a] (null when Wonky has none,
  /// e.g. general horizontal alignment).
  static Object? resetValue(FormatAttr a, WorkbookDocument doc) => switch (a) {
    FormatAttr.numberFormat => NumberFormatPresets.automatic,
    FormatAttr.fontFamily => doc.defaultFontFamily,
    FormatAttr.fontSize => doc.defaultFontSize,
    FormatAttr.bold ||
    FormatAttr.italic ||
    FormatAttr.underline ||
    FormatAttr.strikethrough => false,
    FormatAttr.textColor => 'theme:text',
    FormatAttr.fillColor => 'theme:background',
    FormatAttr.hAlign => null,
    FormatAttr.vAlign => VerticalAlign.bottom,
    FormatAttr.wrap => WrapStrategy.overflow,
    FormatAttr.rotation => 0,
    FormatAttr.borderTop ||
    FormatAttr.borderRight ||
    FormatAttr.borderBottom ||
    FormatAttr.borderLeft => BorderSpec.none.encode(),
    FormatAttr.linkUrl => null,
  };

  /// Whether [v] is the default look of [a] (a reset value or equivalent).
  static bool isDefaultValue(FormatAttr a, Object? v, WorkbookDocument doc) {
    if (v == null) return true;
    switch (a) {
      case FormatAttr.numberFormat:
        return NumberFormatPresets.isAutomatic(v as String?);
      case FormatAttr.borderTop ||
          FormatAttr.borderRight ||
          FormatAttr.borderBottom ||
          FormatAttr.borderLeft:
        return BorderSpec.tryParse(v as String?)?.isNone ?? true;
      default:
        final r = resetValue(a, doc);
        return r != null && (r is Enum ? r == v || r.name == v : r == v);
    }
  }

  /// The format an empty cell at ([row], [col]) of [s] inherits.
  static CellFormat inherited(
    WorkbookDocument doc,
    IrSheet s,
    int row,
    int col,
  ) {
    var f = doc.formats[s.defaultFormat].attrs;
    final c = s.columns[col]?.format ?? 0;
    if (c != 0) f = f.overlay(doc.formats[c].attrs);
    final r = s.rows[row]?.format ?? 0;
    if (r != 0) f = f.overlay(doc.formats[r].attrs);
    return f;
  }

  /// The effective attributes of the cell at ([row], [col]).
  static CellFormat effective(
    WorkbookDocument doc,
    IrSheet s,
    int row,
    int col, [
    IrCell? cell,
  ]) {
    final f = inherited(doc, s, row, col);
    final c = cell ?? s.cells.get(row, col);
    if (c == null || c.format == 0) return f;
    return f.overlay(doc.formats[c.format].attrs);
  }

  /// [complete] made relative to [inherited]: equal attributes are dropped
  /// and inherited ones missing from [complete] are reset (where possible).
  static CellFormat relative(
    CellFormat complete,
    CellFormat inherited,
    WorkbookDocument doc,
  ) {
    if (inherited.isEmpty) return complete;
    final values = <FormatAttr, Object?>{};
    for (final a in complete.attrs) {
      final v = complete[a];
      if (inherited[a] != v) values[a] = v;
    }
    for (final a in inherited.attrs) {
      if (complete.has(a)) continue;
      if (isDefaultValue(a, inherited[a], doc)) continue;
      final r = resetValue(a, doc);
      if (r != null) values[a] = r;
    }
    return CellFormat(values);
  }
}
