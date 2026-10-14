import '../content/cell_content.dart';
import '../engine_bridge/formula_hooks.dart';
import '../mutations/operations.dart';
import 'clipboard_payload.dart';
import 'clipboard_table.dart';
import 'html_table_codec.dart';
import 'r1c1_relative.dart';
import 'tsv_codec.dart';

/// Which clipboard representation a paste used (03 §12.3 resolution order).
enum ClipboardPasteKind {
  /// The in-memory payload whose clip id matches the HTML (`ClipboardService.last`).
  internal,

  /// A payload decoded from the HTML `<!--wonky:…-->` comment (another window
  /// or app instance).
  embedded,

  /// An HTML table (Google Sheets, Excel, LibreOffice, web pages).
  html,

  /// Plain text parsed as TSV.
  text,
}

/// A decoded clipboard, ready to become a [PasteClipboard] operation:
/// `PasteClipboard(target, input.source, mode: …)`.
final class ClipboardPasteInput {
  /// Creates a decoded clipboard.
  const ClipboardPasteInput({
    required this.kind,
    required this.source,
    this.payload,
    this.table,
    this.truncatedCells = 0,
    this.splitSuggestion,
  });

  final ClipboardPasteKind kind;

  /// The paste source for the planner.
  final PasteSource source;

  /// The Wonky payload ([ClipboardPasteKind.internal] / `embedded`).
  final SheetsClipboardPayload? payload;

  /// The parsed HTML table ([ClipboardPasteKind.html]).
  final ClipboardTable? table;

  /// Cells truncated to [kMaxPastedCellChars] (warning toast, 03 §12.5).
  final int truncatedCells;

  /// "Split text to columns" chip suggestion for single-column text.
  final SplitSuggestion? splitSuggestion;

  /// Whether paste-special modes that need the internal payload
  /// (conditional formatting, data validation, column widths) are enabled
  /// (03 §12.4).
  bool get supportsInternalModes => source.internal;
}

/// Turns clipboard contents into a [PasteSource] (03 §12.3, §12.5).
///
/// Formulas are prepared so that the planner translates them correctly for
/// every tile of a tiled paste: with [FormulaHooks] they become stored
/// formulas anchored at a virtual source position, without hooks they are A1
/// text relative to the target top-left.
abstract final class ClipboardDecoder {
  static final RegExp _clipAttr = RegExp(
    r'''data-wonky-clip\s*=\s*["']([^"']*)["']''',
  );

  /// Decodes the clipboard for a paste whose target top-left is
  /// ([targetRow], [targetCol]) on [targetSheetId].
  ///
  /// Resolution order: (a) [html] carrying `data-wonky-clip` equal to
  /// [last]'s clip id → [last]; (b) a `<!--wonky:…-->` payload; (c) an HTML
  /// table; (d) [text] equal to [lastText] (the TSV of [last]; platforms
  /// that keep only plain text) → [last]; (e) [text] as TSV. Returns null
  /// when there is nothing to paste.
  static ClipboardPasteInput? decode({
    String? html,
    String? text,
    SheetsClipboardPayload? last,
    String? lastText,
    required String targetSpreadsheetId,
    required String targetSheetId,
    required int targetRow,
    required int targetCol,
    String locale = 'en_US',
    DateTime? today,
    FormulaHooks? hooks,
  }) {
    if (html != null && html.isNotEmpty) {
      final m = _clipAttr.firstMatch(html);
      if (last != null && m != null && m.group(1) == last.clipId) {
        return ClipboardPasteInput(
          kind: ClipboardPasteKind.internal,
          payload: last,
          source: fromPayload(
            last,
            targetSpreadsheetId: targetSpreadsheetId,
            targetSheetId: targetSheetId,
            targetRow: targetRow,
            targetCol: targetCol,
            hooks: hooks,
          ),
        );
      }
      final table = HtmlTableCodec.parse(html);
      if (table != null) {
        final embedded = table.wonkyPayload;
        if (embedded != null) {
          return ClipboardPasteInput(
            kind: ClipboardPasteKind.embedded,
            payload: embedded,
            source: fromPayload(
              embedded,
              targetSpreadsheetId: targetSpreadsheetId,
              targetSheetId: targetSheetId,
              targetRow: targetRow,
              targetCol: targetCol,
              hooks: hooks,
            ),
          );
        }
        return ClipboardPasteInput(
          kind: ClipboardPasteKind.html,
          table: table,
          truncatedCells: table.truncatedCells,
          source: fromTable(
            table,
            targetSpreadsheetId: targetSpreadsheetId,
            targetSheetId: targetSheetId,
            targetRow: targetRow,
            targetCol: targetCol,
            locale: locale,
            today: today,
            hooks: hooks,
          ),
        );
      }
    }
    if (last != null && lastText != null && text == lastText) {
      return ClipboardPasteInput(
        kind: ClipboardPasteKind.internal,
        payload: last,
        source: fromPayload(
          last,
          targetSpreadsheetId: targetSpreadsheetId,
          targetSheetId: targetSheetId,
          targetRow: targetRow,
          targetCol: targetCol,
          hooks: hooks,
        ),
      );
    }
    if (text != null && text.isNotEmpty) {
      final parsed = TsvCodec.parseWithReport(text);
      if (parsed.rows.isEmpty) return null;
      return ClipboardPasteInput(
        kind: ClipboardPasteKind.text,
        source: fromRows(parsed.rows),
        truncatedCells: parsed.truncatedCells,
        splitSuggestion: parsed.suggestSplit,
      );
    }
    return null;
  }

  /// A Wonky payload as a paste source. Within the source spreadsheet the
  /// stored formulas are used (translated by the planner; cells whose source
  /// rows/columns were not contiguous because of hidden rows are first
  /// re-anchored with [hooks]). From another spreadsheet the A1 formulas are
  /// re-based to the target, and a cut becomes a copy.
  static PasteSource fromPayload(
    SheetsClipboardPayload p, {
    required String targetSpreadsheetId,
    required String targetSheetId,
    required int targetRow,
    required int targetCol,
    FormulaHooks? hooks,
  }) {
    final same = p.spreadsheetId == targetSpreadsheetId;
    final r0 = p.sourceRect.top;
    final c0 = p.sourceRect.left;
    var anchoredAtTarget = false;
    final cells = <List<PasteCell?>>[];
    for (var i = 0; i < p.rowCount; i++) {
      final row = <PasteCell?>[];
      for (var j = 0; j < p.colCount; j++) {
        final c = p.cellAt(i, j);
        if (c == null) {
          row.add(null);
          continue;
        }
        String? stored;
        String? a1;
        CellContent? content;
        if (c.isFormula) {
          if (same) {
            stored = c.content;
            final vr = r0 + i;
            final vc = c0 + j;
            if (hooks != null && (c.sourceRow != vr || c.sourceCol != vc)) {
              stored = hooks.translate(
                stored!,
                fromSheetId: p.sheetId,
                fromRow: c.sourceRow,
                fromCol: c.sourceCol,
                toSheetId: p.sheetId,
                toRow: vr,
                toCol: vc,
              );
            }
            a1 = c.formulaA1;
          } else if (c.formulaA1 != null) {
            final tr = targetRow + i;
            final tc = targetCol + j;
            final rebased = R1C1Relative.toA1(
              R1C1Relative.fromA1(c.formulaA1!, c.sourceRow, c.sourceCol),
              tr,
              tc,
            );
            if (hooks != null) {
              stored = hooks.toStored(
                rebased,
                sheetId: targetSheetId,
                row: tr,
                col: tc,
              );
              anchoredAtTarget = true;
            } else {
              a1 = rebased;
            }
          }
        } else if (c.content != null) {
          content = CellContent.decode(c.content!);
        }
        row.add(
          PasteCell(
            storedFormula: stored,
            formulaA1: a1,
            content: content,
            value: c.value,
            format: c.format,
            note: c.note,
          ),
        );
      }
      cells.add(row);
    }
    final dv = <PasteDvRule>[];
    final cf = <PasteCfRule>[];
    final dvAnchors = <(int, int)?>[];
    final cfAnchors = <(int, int)?>[];
    for (final r in p.rules) {
      final cols = r.columns;
      switch (r.kind) {
        case ClipRuleKind.dataValidation:
          final criteria = cols['criteriaJson'];
          if (criteria is! String) continue;
          dv.add((
            criteriaJson: criteria,
            strict: cols['strict'] == true,
            displayStyle: cols['displayStyle'] as String?,
            helpText: cols['helpText'] as String?,
            rects: r.rects,
          ));
          dvAnchors.add((r.anchorRow, r.anchorCol));
        case ClipRuleKind.conditionalFormat:
          final rule = cols['ruleJson'];
          if (rule is! String) continue;
          cf.add((ruleJson: rule, rects: r.rects));
          cfAnchors.add((r.anchorRow, r.anchorCol));
      }
    }
    return PasteSource(
      cells: cells,
      spreadsheetId: same || anchoredAtTarget
          ? targetSpreadsheetId
          : p.spreadsheetId,
      sheetId: same ? p.sheetId : (anchoredAtTarget ? targetSheetId : null),
      sourceRow: same ? r0 : (anchoredAtTarget ? targetRow : 0),
      sourceCol: same ? c0 : (anchoredAtTarget ? targetCol : 0),
      merges: p.merges,
      dvRules: dv,
      cfRules: cf,
      columnWidths: p.columnWidths,
      rowHeights: p.rowHeights,
      isCut: same && p.isCut,
      internal: true,
      sourceRowIndices: same ? p.rowIndices : null,
      sourceColIndices: same ? p.colIndices : null,
      dvAnchors: same ? dvAnchors : const [],
      cfAnchors: same ? cfAnchors : const [],
    );
  }

  /// A parsed HTML table as a paste source. `data-sheets-formula` formulas
  /// are resolved relative to the target cells; untyped text is parsed like
  /// typed input in [locale].
  static PasteSource fromTable(
    ClipboardTable t, {
    required String targetSpreadsheetId,
    required String targetSheetId,
    required int targetRow,
    required int targetCol,
    String locale = 'en_US',
    DateTime? today,
    FormulaHooks? hooks,
  }) {
    var anchored = false;
    final cells = <List<PasteCell?>>[];
    for (var i = 0; i < t.rowCount; i++) {
      final row = <PasteCell?>[];
      for (var j = 0; j < t.colCount; j++) {
        final cell = t.cellAt(i, j);
        if (cell == null) {
          row.add(null);
          continue;
        }
        final tr = targetRow + i;
        final tc = targetCol + j;
        final v = cell.resolve(
          targetRow: tr,
          targetCol: tc,
          locale: locale,
          today: today,
        );
        String? stored;
        String? a1 = v.formulaA1;
        if (a1 != null && hooks != null) {
          stored = hooks.toStored(
            a1,
            sheetId: targetSheetId,
            row: tr,
            col: tc,
            locale: cell.formulaR1C1 != null ? 'en_US' : locale,
          );
          a1 = null;
          anchored = true;
        }
        row.add(
          PasteCell(
            storedFormula: stored,
            formulaA1: a1,
            content: v.content,
            value: cell.typedValue,
            format: v.format,
            note: v.note,
          ),
        );
      }
      cells.add(row);
    }
    return PasteSource(
      cells: cells,
      spreadsheetId: anchored ? targetSpreadsheetId : null,
      sheetId: anchored ? targetSheetId : null,
      sourceRow: anchored ? targetRow : 0,
      sourceCol: anchored ? targetCol : 0,
      merges: t.merges,
      columnWidths: t.columnWidths,
      rowHeights: t.rowHeights,
    );
  }

  /// Plain-text rows (TSV) as a paste source: every field is parsed like
  /// typing by the planner; empty fields clear their cell.
  static PasteSource fromRows(List<List<String>> rows) => PasteSource(
    cells: [
      for (final r in rows)
        [for (final f in r) f.isEmpty ? null : PasteCell(text: f)],
    ],
  );
}
