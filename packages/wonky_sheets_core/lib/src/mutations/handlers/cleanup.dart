import '../../addressing/grid_geometry.dart';
import '../../content/cell_content.dart';
import '../../data_tools/cleanup/trim.dart';
import '../../data_tools/split/text_splitter.dart';
import '../../format/format_resolver.dart';
import '../../model/grid_range.dart';
import '../../model/schema.dart';
import '../operations.dart';
import '../plan_builder.dart';
import '../row_change.dart';
import 'helpers.dart';
import 'move.dart';
import 'values.dart';

/// [TrimWhitespace] (07 §12.2): trims text and rich-text cells (runs
/// re-offset); numbers, booleans, formulas and errors are untouched.
///
/// Result: `trimmed` (cells changed) and the toast `message`.
MutationPlan planTrimWhitespace(PlanBuilder b, TrimWhitespace op) {
  var trimmed = 0;
  for (final range in op.ranges) {
    final s = b.sheetOf(range.sheetId);
    b.checkRect(s, range.rect);
    b.addResolvedRange(range);
    for (final (_, _, rowId, colId, cur) in b.cellsIn(s, range.rect).toList()) {
      final content = CellContent.decode(cur[CellCols.content] as String?);
      final next = WhitespaceTrimmer.trimContent(content);
      if (next == null) continue;
      b.writeCell(s.id, rowId, colId, {CellCols.content: next.encode()});
      trimmed++;
    }
  }
  b.result['trimmed'] = trimmed;
  b.result['message'] = WhitespaceTrimmer.message(trimmed);
  return b.build('Trim whitespace', kinds: [ChangeKinds.values]);
}

/// Message of the single-column refusal (07 §13).
const String splitSingleColumnMessage =
    'Please select a single column of data to split.';

/// [SplitTextToColumns] (07 §13): splits the text cells of one column by the
/// given or detected separator; part 1 replaces the source cell, parts 2…n go
/// to the right (columns are appended when needed). Formula and non-text cells
/// are skipped. Each part is parsed like typed input unless the target cell's
/// number format is plain text; parts that look like formulas stay text.
///
/// Refusals: `invalid_range` (not a single column), `no_separator` (nothing
/// detected), `confirm_overwrite` (non-empty cells to the right, unless
/// [SplitTextToColumns.force]).
///
/// Result: `separator` (the one used), `columns` (maximum part count) and
/// `cells` (cells split).
MutationPlan planSplitTextToColumns(PlanBuilder b, SplitTextToColumns op) {
  const label = 'Split text to columns';
  final s = b.sheetOf(op.range.sheetId);
  final rect = op.range.rect;
  b.checkRect(s, rect);
  if (rect.colCount != 1) {
    throw const PlanException('invalid_range', splitSingleColumnMessage);
  }
  if (op.separator != null && op.separator!.isEmpty) {
    throw const PlanException('invalid_argument', 'Enter a separator');
  }
  final col = rect.left;
  // Source texts (text and rich text only).
  final texts = <int, String>{};
  for (final (r, _, _, _, cur) in b.cellsIn(s, rect)) {
    final content = CellContent.decode(cur[CellCols.content] as String?);
    if (content is TextContent || content is RichTextContent) {
      final t = content!.plainText!;
      if (t.isNotEmpty) texts[r] = t;
    }
  }
  final separator =
      op.separator ?? SeparatorDetector.detect(texts.values)?.char;
  if (separator == null) {
    throw const PlanException('no_separator', "Couldn't detect a separator");
  }
  b.result['separator'] = separator;
  final parts = <int, List<String>>{
    for (final e in texts.entries)
      e.key: TextSplitter.split(e.value, separator),
  };
  var width = 1;
  for (final p in parts.values) {
    if (p.length > width) width = p.length;
  }
  b.result['columns'] = width;
  // Existing data to the right.
  if (!op.force && width > 1) {
    var occupied = 0;
    for (final e in parts.entries) {
      for (var k = 1; k < e.value.length; k++) {
        final c = col + k;
        if (c >= s.columns.length) break;
        final cur = b.currentCell(s.id, s.rows.idAt(e.key), s.columns.idAt(c));
        if (cur?[CellCols.content] != null) occupied++;
      }
    }
    if (occupied > 0) {
      throw PlanException(
        'confirm_overwrite',
        'Do you want to replace existing data?',
        details: {'cells': occupied},
      );
    }
  }
  final (rowIdAt, colIdAt) = ensureGridSize(b, s, s.rows.length, col + width);
  var cells = 0;
  final rows = parts.keys.toList()..sort();
  for (final r in rows) {
    final p = parts[r]!;
    if (p.length < 2 && p.single == texts[r]) continue;
    for (var k = 0; k < p.length; k++) {
      final rowId = rowIdAt(r);
      final colId = colIdAt(col + k);
      b.writeCell(
        s.id,
        rowId,
        colId,
        _partColumns(b, s.id, rowId, colId, p[k]),
      );
    }
    cells++;
  }
  b.result['cells'] = cells;
  if (cells > 0) {
    b.addResolvedRange(
      ResolvedRange(
        s.id,
        GridRect(rect.top, col, rect.bottom, col + width - 1),
      ),
    );
  }
  return b.build(label, kinds: [ChangeKinds.values]);
}

Map<String, Object?> _partColumns(
  PlanBuilder b,
  String sheetId,
  String rowId,
  String colId,
  String part,
) {
  final s = b.model.sheet(sheetId)!;
  final fmt = effectiveNumberFormat(b, s, rowId, colId);
  final parsed = TextSplitter.parsePart(
    part,
    locale: b.locale,
    targetNumberFormat: fmt,
    today: b.ctx.now,
  );
  final content = parsed.isFormula ? TextContent(part) : parsed.content;
  return {
    CellCols.content: content?.encode(),
    if (parsed.autoNumberFormat != null &&
        (fmt == null || fmt == kAutomaticNumberFormat))
      CellCols.numberFormat: parsed.autoNumberFormat,
  };
}
