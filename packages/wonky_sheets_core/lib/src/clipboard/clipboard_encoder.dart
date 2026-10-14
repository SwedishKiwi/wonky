import '../addressing/grid_geometry.dart';
import '../engine_bridge/formula_hooks.dart';
import '../format/number_format/number_formatter.dart';
import '../formula/model/workbook_view.dart';
import '../model/events.dart';
import '../model/grid_range.dart';
import '../model/sheet_model.dart';
import '../model/workbook_model.dart';
import '../io/html/cell_css.dart';
import '../io/html/html_escape.dart';
import '../io/print/cell_display.dart';
import 'clipboard_payload.dart';
import 'r1c1_relative.dart';
import 'sheets_html_attrs.dart';
import 'tsv_codec.dart';

/// The three clipboard representations of a copy (03 §12.2).
final class ClipboardContent {
  /// Creates the content.
  const ClipboardContent({
    required this.tsv,
    required this.html,
    required this.payload,
    required this.payloadEmbedded,
  });

  /// `text/plain`: TSV of displayed values.
  final String tsv;

  /// `text/html`: a styled `<table>` with Google-compatible attributes.
  final String html;

  /// The in-memory payload (`ClipboardService.last`).
  final SheetsClipboardPayload payload;

  /// Whether [html] carries the payload in a `<!--wonky:…-->` comment.
  final bool payloadEmbedded;
}

/// Thrown when a copy is not possible.
final class ClipboardCopyException implements Exception {
  /// Creates the exception.
  const ClipboardCopyException(this.message);

  /// Reason.
  final String message;

  @override
  String toString() => 'ClipboardCopyException: $message';
}

/// Builds clipboard content for a single rectangular range (03 §12.2).
abstract final class ClipboardEncoder {
  /// Largest base64 payload embedded in the HTML comment (5 MB).
  static const int maxEmbeddedPayloadChars = 5 * 1024 * 1024;

  /// Copies [range]: only visible rows/columns are included; displayed values
  /// come from [source] formatted with the number formatter in [locale]
  /// (default: the spreadsheet locale). [hooks] converts formulas to A1 for
  /// `data-sheets-formula` and [ClipCell.formulaA1] (omitted without hooks).
  ///
  /// [rowOrder] lists the rows to copy in their order (a display order,
  /// e.g. a sorted filter view, 07 §4.4); rows outside [range] are ignored;
  /// DV/CF rules are not copied then.
  static ClipboardContent copy(
    WorkbookModel model,
    ResolvedRange range,
    CellSource source, {
    required String clipId,
    String? locale,
    FormulaHooks? hooks,
    bool isCut = false,
    ConditionalOverlayProvider? conditional,
    NumberFormatter? formatter,
    List<int>? rowOrder,
  }) {
    final sheet = model.sheet(range.sheetId);
    if (sheet == null) throw const ClipboardCopyException('Unknown sheet');
    final grid = sheet.gridRect;
    if (grid == null) throw const ClipboardCopyException('Empty sheet');
    var rect = range.rect.intersection(grid);
    if (rect == null) {
      throw const ClipboardCopyException('Range outside the grid');
    }
    if (range.wholeRows || range.wholeColumns) {
      final used = sheet.usedRect(includeFormatOnly: true);
      final bottom = range.wholeColumns
          ? (used?.bottom ?? rect.top)
          : rect.bottom;
      final right = range.wholeRows ? (used?.right ?? rect.left) : rect.right;
      rect = GridRect(
        rect.top,
        rect.left,
        bottom.clamp(rect.top, rect.bottom),
        right.clamp(rect.left, rect.right),
      );
    }
    final loc = locale ?? model.spreadsheet.locale;
    final resolver = CellDisplayResolver(
      model,
      source,
      locale: loc,
      conditional: conditional,
      formatter: formatter,
    );
    final sheetId = sheet.id;

    // [rowOrder]: the rows in display order (a sorted filter view, 07 §4.4).
    final rowIdx = [
      for (final r
          in rowOrder ?? [for (var r = rect.top; r <= rect.bottom; r++) r])
        if (r >= rect.top &&
            r <= rect.bottom &&
            !_hidden(sheet, source, GridDimension.rows, r))
          r,
    ];
    final colIdx = [
      for (var c = rect.left; c <= rect.right; c++)
        if (!_hidden(sheet, source, GridDimension.columns, c)) c,
    ];
    final rowPos = {for (var i = 0; i < rowIdx.length; i++) rowIdx[i]: i};
    final colPos = {for (var i = 0; i < colIdx.length; i++) colIdx[i]: i};

    GridRect? compact(GridRect r) {
      final i = r.intersection(rect!);
      if (i == null) return null;
      int? first(List<int> idx, int a, int b) {
        for (final x in idx) {
          if (x >= a && x <= b) return x;
        }
        return null;
      }

      int? last(List<int> idx, int a, int b) {
        for (var k = idx.length - 1; k >= 0; k--) {
          if (idx[k] >= a && idx[k] <= b) return idx[k];
        }
        return null;
      }

      final t = first(rowIdx, i.top, i.bottom);
      final b = last(rowIdx, i.top, i.bottom);
      final l = first(colIdx, i.left, i.right);
      final rr = last(colIdx, i.left, i.right);
      if (t == null || b == null || l == null || rr == null) return null;
      return GridRect(rowPos[t]!, colPos[l]!, rowPos[b]!, colPos[rr]!);
    }

    // Merges.
    final merges = <GridRect>[];
    final mergeByAnchor = <(int, int), (GridRect compact, GridRect source)>{};
    final covered = <(int, int)>{};
    for (final (_, m) in sheet.mergesIntersecting(rect)) {
      final cm = compact(m);
      if (cm == null || cm.isSingleCell) continue;
      merges.add(cm);
      mergeByAnchor[(cm.top, cm.left)] = (cm, m.intersection(rect)!);
      for (var r = cm.top; r <= cm.bottom; r++) {
        for (var c = cm.left; c <= cm.right; c++) {
          if (r != cm.top || c != cm.left) covered.add((r, c));
        }
      }
    }

    // Cells.
    final cells = List.generate(
      rowIdx.length,
      (_) => List<ClipCell?>.filled(colIdx.length, null),
    );
    final displays = List.generate(
      rowIdx.length,
      (_) => List<CellDisplay?>.filled(colIdx.length, null),
    );
    final tsvRows = <List<String>>[];
    for (var i = 0; i < rowIdx.length; i++) {
      final tsvRow = <String>[];
      for (var j = 0; j < colIdx.length; j++) {
        final r = rowIdx[i];
        final c = colIdx[j];
        final d = resolver.display(sheetId, r, c);
        displays[i][j] = d;
        tsvRow.add(covered.contains((i, j)) ? '' : d.text);
        final rec = d.record;
        final fmt = model.explicitFormatChain(sheetId, r, c);
        if (rec?.content == null &&
            rec?.note == null &&
            fmt.isEmpty &&
            d.value.isBlank()) {
          continue;
        }
        String? a1;
        final content = rec?.content;
        if (hooks != null && content != null && content.startsWith('=')) {
          a1 = hooks.toA1(
            content,
            sheetId: sheetId,
            row: r,
            col: c,
            locale: 'en_US',
          );
        }
        cells[i][j] = ClipCell(
          sourceRow: r,
          sourceCol: c,
          content: content,
          value: d.value,
          formulaA1: a1,
          format: fmt,
          note: rec?.note,
        );
      }
      tsvRows.add(tsvRow);
    }

    // Rules.
    final rules = <ClipRule>[];
    void addRules(RuleKind kind) {
      for (final id in sheet.rulesIntersecting(kind, rect!)) {
        final ranges = sheet.ruleRects(kind, id);
        final rects = [
          for (final rr in ranges)
            if (compact(rr) case final GridRect g) g,
        ];
        if (rects.isEmpty) continue;
        final anchor = ranges.first;
        final cols = kind == RuleKind.dataValidation
            ? sheet.dvRules[id]?.toColumns()
            : sheet.cfRules[id]?.toColumns();
        if (cols == null) continue;
        final keep = Map<String, Object?>.of(cols)
          ..remove('id')
          ..remove('sheetId')
          ..remove('rangesJson')
          ..remove('createdAt');
        rules.add(
          ClipRule(
            kind: kind == RuleKind.dataValidation
                ? ClipRuleKind.dataValidation
                : ClipRuleKind.conditionalFormat,
            columns: keep,
            rects: rects,
            anchorRow: anchor.top,
            anchorCol: anchor.left,
            sourceRuleId: id,
          ),
        );
      }
    }

    // Rule rectangles can't follow a row order: rules stay behind then.
    if (rowOrder == null) {
      addRules(RuleKind.dataValidation);
      addRules(RuleKind.conditionalFormat);
    }

    final payload = SheetsClipboardPayload(
      clipId: clipId,
      spreadsheetId: model.spreadsheetId,
      sheetId: sheetId,
      sheetName: sheet.name,
      locale: loc,
      sourceRect: rect,
      sourceRange: sheet.gridRange(rect),
      rowIndices: rowIdx,
      colIndices: colIdx,
      cells: cells,
      merges: merges,
      rules: rules,
      columnWidths: [for (final c in colIdx) sheet.columns.explicitSizeAt(c)],
      rowHeights: [for (final r in rowIdx) sheet.rows.explicitSizeAt(r)],
      isCut: isCut,
    );
    final b64 = payload.encodeBase64();
    final embed = b64.length <= maxEmbeddedPayloadChars;

    final html = _html(
      model: model,
      sheet: sheet,
      resolver: resolver,
      rowIdx: rowIdx,
      colIdx: colIdx,
      displays: displays,
      cells: cells,
      mergeByAnchor: mergeByAnchor,
      covered: covered,
      clipId: clipId,
      payloadB64: embed ? b64 : null,
    );
    return ClipboardContent(
      tsv: TsvCodec.encode(tsvRows),
      html: html,
      payload: payload,
      payloadEmbedded: embed,
    );
  }

  static bool _hidden(SheetModel s, CellSource source, GridDimension d, int i) {
    final axis = d == GridDimension.rows ? s.rows : s.columns;
    return axis.isHidden(i) || source.isHidden(s.id, d, i);
  }

  static String _html({
    required WorkbookModel model,
    required SheetModel sheet,
    required CellDisplayResolver resolver,
    required List<int> rowIdx,
    required List<int> colIdx,
    required List<List<CellDisplay?>> displays,
    required List<List<ClipCell?>> cells,
    required Map<(int, int), (GridRect, GridRect)> mergeByAnchor,
    required Set<(int, int)> covered,
    required String clipId,
    String? payloadB64,
  }) {
    final theme = model.theme;
    final ss = model.spreadsheet;
    final defaultFont = theme.textFont.isNotEmpty
        ? theme.textFont
        : ss.defaultFontFamily;
    final defaultSize = ss.defaultFontSize;
    final b = StringBuffer()
      ..write('<meta charset="utf-8">')
      ..write(
        '<style type="text/css"><!--br {mso-data-placement:same-cell;}--></style>',
      )
      ..write(
        '<table data-wonky-clip="${HtmlText.attr(clipId)}" cellspacing="0" ',
      )
      ..write(
        'cellpadding="0" dir="${sheet.record?.rightToLeft == true ? 'rtl' : 'ltr'}" ',
      )
      ..write(
        'border="1" style="table-layout:fixed;font-size:${HtmlText.num(defaultSize)}pt;',
      )
      ..write('font-family:${HtmlText.cssFontFamily(defaultFont)};width:0px;')
      ..write('border-collapse:collapse;border:none">');
    if (payloadB64 != null) b.write('<!--wonky:$payloadB64-->');
    b.write('<colgroup>');
    for (final c in colIdx) {
      b.write('<col width="${HtmlText.num(sheet.columns.naturalSizeAt(c))}"/>');
    }
    b.write('</colgroup><tbody>');
    for (var i = 0; i < rowIdx.length; i++) {
      b.write(
        '<tr style="height:${HtmlText.num(sheet.rows.naturalSizeAt(rowIdx[i]))}px;">',
      );
      for (var j = 0; j < colIdx.length; j++) {
        if (covered.contains((i, j))) continue;
        final merge = mergeByAnchor[(i, j)];
        final srcRow = merge?.$2.top ?? rowIdx[i];
        final srcCol = merge?.$2.left ?? colIdx[j];
        final d = merge == null
            ? displays[i][j]!
            : resolver.display(sheet.id, srcRow, srcCol);
        final edges = resolver.edges(
          sheet.id,
          srcRow,
          srcCol,
          bottomRow: merge?.$2.bottom,
          rightCol: merge?.$2.right,
        );
        b.write('<td');
        if (merge != null) {
          final (cm, _) = merge;
          if (cm.colCount > 1) b.write(' colspan="${cm.colCount}"');
          if (cm.rowCount > 1) b.write(' rowspan="${cm.rowCount}"');
        }
        final style = CellCss.style(
          d,
          theme: theme,
          defaultFont: defaultFont,
          defaultSize: defaultSize,
          edges: edges,
        );
        b.write(' style="${HtmlText.attr(style)}"');
        final sv = SheetsHtmlAttrs.encodeValue(d.value);
        if (sv != null) b.write(' data-sheets-value="${HtmlText.attr(sv)}"');
        final cell = cells[i][j];
        final a1 = cell?.formulaA1;
        if (cell != null && a1 != null) {
          final r1c1 = R1C1Relative.fromA1(a1, cell.sourceRow, cell.sourceCol);
          b.write(' data-sheets-formula="${HtmlText.attr(r1c1)}"');
        }
        final nf = d.format.numberFormatExplicit
            ? SheetsHtmlAttrs.interchangePattern(d.format.numberFormat)
            : null;
        if (nf != null) {
          b.write(
            ' data-sheets-numberformat="${HtmlText.attr(SheetsHtmlAttrs.encodeNumberFormat(nf))}"',
          );
        }
        final note = d.record?.note;
        if (note != null && note.isNotEmpty) {
          b.write(' data-sheets-note="${HtmlText.attr(note)}"');
        }
        final link = HtmlText.safeUrl(d.linkUrl);
        if (link != null) {
          b.write(' data-sheets-hyperlink="${HtmlText.attr(link)}"');
        }
        b.write('>');
        b.write(CellCss.body(d, model.theme));
        b.write('</td>');
      }
      b.write('</tr>');
    }
    b.write('</tbody></table>');
    return b.toString();
  }
}
