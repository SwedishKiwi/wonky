import 'dart:math' as math;

import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';
import 'system_clipboard.dart';

/// Thrown when a copy/paste is not possible (message for a toast).
class ClipboardActionException implements Exception {
  const ClipboardActionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Copy, cut and paste of the grid (03 §12): the internal rich payload,
/// TSV and HTML through the core codecs, and the system clipboard.
class ClipboardService {
  ClipboardService(this.host, {SystemClipboard? system})
    : system = system ?? SystemClipboard.platform();

  final SheetEditorController host;
  final SystemClipboard system;

  /// The last copied payload (`ClipboardService.last`).
  SheetsClipboardPayload? last;
  String? _lastTsv;
  int _clipCounter = 0;

  /// Copies (or cuts) the active range. Throws [ClipboardActionException].
  Future<void> copy({bool cut = false}) async {
    final r = host.selection.resolved;
    // Rows selected on screen in a sorted filter view are copied in display
    // order (07 §4.4): one range on screen, several model ranges.
    final shown = r.ranges.length > 1 && r.isSingleGroup
        ? r.activeRange.displayRect
        : null;
    if (r.ranges.length != 1 && shown == null) {
      throw ClipboardActionException(host.l10n.toastMultipleSelections);
    }
    if (shown != null && cut) {
      throw ClipboardActionException(host.l10n.viewSortCutUnavailable);
    }
    final range = shown == null
        ? host.activeRange
        : ResolvedRange(
            r.sheetId,
            GridRect(
              r.ranges.map((x) => x.rect.top).reduce(math.min),
              shown.left,
              r.ranges.map((x) => x.rect.bottom).reduce(math.max),
              shown.right,
            ),
          );
    final clipId = '${host.services.ids.nextString()}-${_clipCounter++}';
    final ClipboardContent content;
    try {
      content = ClipboardEncoder.copy(
        host.model,
        range,
        host.engine,
        clipId: clipId,
        hooks: host.hooks,
        isCut: cut,
        conditional: host.cells.conditional,
        rowOrder: shown == null
            ? null
            : [
                for (final x in r.ranges)
                  for (var row = x.rect.top; row <= x.rect.bottom; row++) row,
              ],
      );
    } on ClipboardCopyException catch (e) {
      throw ClipboardActionException(e.message);
    }
    last = content.payload;
    _lastTsv = content.tsv;
    host.clipMark.value = ClipMark(
      range.sheetId,
      range.rect,
      cut: cut,
      displayRect: shown,
    );
    await system.write(
      SystemClipboardData(plainText: content.tsv, html: content.html),
    );
  }

  /// Reads the clipboard as a paste source for a paste anchored at
  /// ([targetRow], [targetCol]) on the active sheet, through the core
  /// `ClipboardDecoder` (03 §12.3 resolution order). [plainText] ignores
  /// HTML. Returns null when the clipboard is empty.
  Future<PasteSource?> readSource({
    required int targetRow,
    required int targetCol,
    bool plainText = false,
  }) async {
    final data = await system.read();
    final input = ClipboardDecoder.decode(
      html: plainText ? null : data?.html,
      text: data?.plainText,
      last: last,
      lastText: _lastTsv,
      targetSpreadsheetId: host.model.spreadsheetId,
      targetSheetId: host.activeSheetId,
      targetRow: targetRow,
      targetCol: targetCol,
      locale: host.locale,
      hooks: host.hooks,
    );
    if (input != null) return input.source;
    // Nothing readable (permission denied): fall back to our own copy.
    final internal = last;
    if (data == null && internal != null) {
      return ClipboardDecoder.fromPayload(
        internal,
        targetSpreadsheetId: host.model.spreadsheetId,
        targetSheetId: host.activeSheetId,
        targetRow: targetRow,
        targetCol: targetCol,
        hooks: host.hooks,
      );
    }
    return null;
  }

  /// A paste source copying [rect] of the active sheet (fill down/right,
  /// paint format): same-spreadsheet stored formulas, formats, notes.
  PasteSource sourceOf(GridRect rect, {String? sheetId}) {
    final sid = sheetId ?? host.activeSheetId;
    final s = host.model.sheet(sid)!;
    return PasteSource(
      cells: [
        for (var r = rect.top; r <= rect.bottom; r++)
          [
            for (var c = rect.left; c <= rect.right; c++)
              () {
                final rec = s.cellAt(r, c);
                final chain = host.model.explicitFormatChain(sid, r, c);
                final content = rec?.decoded;
                return PasteCell(
                  storedFormula: content is FormulaContent
                      ? content.text
                      : null,
                  content: content is FormulaContent ? null : content,
                  value: host.engine.valueAt(sid, r, c).toCellValue(),
                  format: chain.isEmpty ? CellFormat.empty : chain,
                  note: rec?.note,
                );
              }(),
          ],
      ],
      spreadsheetId: host.model.spreadsheetId,
      sheetId: sid,
      sourceRow: rect.top,
      sourceCol: rect.left,
      merges: [
        for (final (_, m) in s.mergesIntersecting(rect))
          if (rect.containsRect(m)) m.shift(-rect.top, -rect.left),
      ],
      internal: true,
    );
  }

  /// After a cut has been pasted, the clipboard holds a normal copy.
  void consumeCut() {
    final p = last;
    if (p != null && p.isCut) last = p.withCut(false);
    host.clipMark.value = null;
  }
}
