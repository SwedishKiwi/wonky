import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../fill/series_detector.dart';
import '../../model/grid_range.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'move.dart';
import 'values.dart';

/// [FillSeries] (03 §10): fills the part of [FillSeries.target] outside
/// [FillSeries.source] per column (vertical) or per row (horizontal) with
/// [SeriesDetector] (series or copy, backwards when filling up/left).
/// Formulas are translated from their source cell; cell formats (all
/// attributes and links, not notes) are copied cyclically from the sources.
///
/// A target that grows in both directions (Mod+Enter from the active cell)
/// is filled vertically first, then horizontally from the filled columns.
/// A target inside the source does nothing.
///
/// Result: `cells` (target cells written).
MutationPlan planFillSeries(PlanBuilder b, FillSeries op) {
  final label = op.label ?? (op.mode == FillMode.copy ? 'Fill' : 'Fill series');
  final s = b.sheetOf(op.sheetId);
  final src = op.source;
  b.checkRect(s, src);
  b.checkRect(s, op.target);
  final t = GridRect(
    op.target.top < src.top ? op.target.top : src.top,
    op.target.left < src.left ? op.target.left : src.left,
    op.target.bottom > src.bottom ? op.target.bottom : src.bottom,
    op.target.right > src.right ? op.target.right : src.right,
  );
  var cells = 0;
  // Vertical: the source columns over the union rows.
  for (var c = src.left; c <= src.right; c++) {
    cells += _fillLine(b, s, op.mode, c, src.top, src.bottom, t, true);
  }
  // Horizontal: every row of the union, from the (filled) source columns.
  if (t.left < src.left || t.right > src.right) {
    for (var r = t.top; r <= t.bottom; r++) {
      cells += _fillLine(b, s, op.mode, r, src.left, src.right, t, false);
    }
  }
  b.result['cells'] = cells;
  if (cells > 0) b.addResolvedRange(ResolvedRange(s.id, t));
  return b.build(label, kinds: [ChangeKinds.values, ChangeKinds.format]);
}

/// Fills one line (column [line] when [vertical], else row [line]) whose
/// sources span [from]..[to] along the axis, up to the bounds of [t].
int _fillLine(
  PlanBuilder b,
  SheetModel s,
  FillMode mode,
  int line,
  int from,
  int to,
  GridRect t,
  bool vertical,
) {
  final lo = vertical ? t.top : t.left;
  final hi = vertical ? t.bottom : t.right;
  if (lo >= from && hi <= to) return 0;
  (String, String) ids(int pos) => vertical
      ? (s.rows.idAt(pos), s.columns.idAt(line))
      : (s.rows.idAt(line), s.columns.idAt(pos));
  (int, int) at(int pos) => vertical ? (pos, line) : (line, pos);
  final data = <Map<String, Object?>>[];
  final sources = <FillSource>[];
  for (var p = from; p <= to; p++) {
    final (rowId, colId) = ids(p);
    final cur = b.currentCell(s.id, rowId, colId);
    data.add(cellData(cur));
    sources.add(
      FillSource(
        CellContent.decode(cur?[CellCols.content] as String?),
        numberFormat: effectiveNumberFormat(b, s, rowId, colId),
      ),
    );
  }
  var written = 0;
  void fill(int count, FillDirection direction) {
    if (count <= 0) return;
    final items = SeriesDetector.instance.fill(
      sources,
      count,
      direction: direction,
      mode: mode,
      locale: b.locale,
      customLists: b.ctx.customLists,
    );
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final pos = direction == FillDirection.forward
          ? to + 1 + i
          : from - 1 - i;
      final (rowId, colId) = ids(pos);
      final out = Map<String, Object?>.of(data[item.sourceIndex])
        ..remove(CellCols.note);
      final content = item.content;
      if (item.isFormula && content is FormulaContent) {
        final (fr, fc) = at(from + item.sourceIndex);
        final (tr, tc) = at(pos);
        out[CellCols.content] = b.formulas.translate(
          content.text,
          fromSheetId: s.id,
          fromRow: fr,
          fromCol: fc,
          toSheetId: s.id,
          toRow: tr,
          toCol: tc,
        );
      } else {
        out[CellCols.content] = content?.encode();
      }
      b.writeCell(s.id, rowId, colId, out);
      written++;
    }
  }

  fill(hi - to, FillDirection.forward);
  fill(from - lo, FillDirection.backward);
  return written;
}
