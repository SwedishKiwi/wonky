import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/formula.dart' show CellPos, GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import '../cell_editor/cell_editor_controller.dart';
import '../conditional_format/cf_controller.dart' show RangeHighlightLayer;
import '../sheet_editor/sheet_editor_controller.dart';
import '../sheet_editor/write_gate.dart';
import 'dv_layer.dart';

/// Data validation of an open spreadsheet (07 §6, 03 §8.4): the shared core
/// [DvEvaluator] (effective rules, invalid markers, typed-input checks,
/// dropdown items, checkbox values), the invalid-marker layer and the
/// enforcement of strict rules on typed input (cell editor commit and the
/// write gate of `sheets.cell.setInput`; typed formulas are checked with
/// their detached result), the live preview of the panel's draft rule and
/// the highlight of a hovered rule's ranges.
class DataValidationController extends ChangeNotifier {
  DataValidationController._(this.editor) {
    _layer = InvalidMarkerLayer(this);
    editor.layers.add(_layer);
    _highlightLayer = RangeHighlightLayer(highlight);
    editor.layers.add(_highlightLayer);
    editor.writeGates.add(_gate);
    editor.editor.commitCheck = _commitCheck;
    editor.model.addListener(_onBatch);
    _recalc = editor.engine.changes.listen((_) => _invalidate());
    editor.onDispose(dispose);
  }

  /// The controller of [editor] (created on first use).
  static DataValidationController of(SheetEditorController editor) =>
      editor.extension(DataValidationController, () {
        return DataValidationController._(editor);
      });

  final SheetEditorController editor;
  late final InvalidMarkerLayer _layer;
  late final RangeHighlightLayer _highlightLayer;

  /// Ranges of the rule hovered (or focused) in the panel list, painted on
  /// the grid (07 §6.3).
  final ValueNotifier<List<GridRect>?> highlight = ValueNotifier(null);
  String? _hoverRule;
  String? _hoverSheet;

  DvDraftPreview? _draft;
  StreamSubscription<Object?>? _recalc;
  bool _disposed = false;

  DvEvaluator? _evaluator;
  final Map<String, Map<int, ValidationResult>> _results = {};

  /// Bumped when rules change (panel lists rebuild).
  int rulesGeneration = 0;

  WorkbookModel get model => editor.model;

  /// The evaluator over the current model (rebuilt after a locale change).
  DvEvaluator get evaluator {
    final e = _evaluator;
    if (e != null && e.conditions.locale == model.spreadsheet.locale) return e;
    return _evaluator = DvEvaluator(
      model,
      editor.engine,
      FormatterDisplayText(locale: model.spreadsheet.locale),
      hooks: editor.hooks,
    )..draft = _draft;
  }

  // ---------------------------------------------------------------------------
  // Panel: draft preview and hover highlight (07 §6.3).

  /// The draft rule previewed on the grid, or null.
  DvDraftPreview? get draft => _draft;

  /// Previews [d] on the grid (chips, checkboxes, invalid markers); null
  /// ends the preview. Never written.
  void setDraft(DvDraftPreview? d) {
    if (_disposed || identical(d, _draft)) return;
    _draft = d;
    _evaluator?.draft = d;
    _results.clear();
    editor.cells.dvDraft = d;
    editor.cells.invalidate();
    editor.contentSignal.fire();
    editor.overlaySignal.fire();
  }

  /// Whether the draft covers or hides the rule of the cell.
  bool draftAffects(SheetModel sheet, int row, int col) =>
      _draft?.affects(sheet, row, col) ?? false;

  /// Highlights the ranges of [ruleId] on [sheetId] (null clears).
  void hoverRule(String sheetId, String? ruleId) {
    _hoverRule = ruleId;
    _hoverSheet = sheetId;
    _refreshHighlight();
  }

  void _refreshHighlight() {
    final id = _hoverRule;
    final sid = _hoverSheet;
    final sheet = sid == null ? null : model.sheet(sid);
    highlight.value = id == null || sheet == null || sid != editor.activeSheetId
        ? null
        : sheet.ruleRects(RuleKind.dataValidation, id);
  }

  void _onBatch(WorkbookChangeBatch batch) {
    if (_disposed) return;
    final rules = batch.events.any(
      (e) => e is RulesChanged && e.kind == RuleKind.dataValidation,
    );
    _invalidate();
    if (rules) {
      rulesGeneration++;
      if (highlight.value != null) _refreshHighlight();
      notifyListeners();
    }
  }

  void _invalidate() {
    _evaluator?.invalidate();
    _results.clear();
  }

  static int _key(int row, int col) => row * 32768 + col;

  /// The rule effective at the cell, or null.
  DvRule? ruleAt(String sheetId, int row, int col) =>
      evaluator.ruleAt(sheetId, row, col);

  /// Validation of the cell's current value (cached until the next change
  /// or recalculation).
  ValidationResult validate(String sheetId, int row, int col) {
    final s = model.sheet(sheetId);
    if (s == null || (s.dvRules.isEmpty && _draft?.sheetId != sheetId)) {
      return ValidationResult.ok;
    }
    final map = _results.putIfAbsent(sheetId, () => {});
    if (map.length > 60000) map.clear();
    return map.putIfAbsent(_key(row, col), () {
      try {
        return evaluator.validateCell(sheetId, row, col);
      } catch (_) {
        return ValidationResult.ok;
      }
    });
  }

  /// Whether the cell's value violates its rule (warning marker).
  bool isInvalid(String sheetId, int row, int col) =>
      !validate(sheetId, row, col).valid;

  /// Checks [input] typed into the cell (07 §6.6). A formula is checked
  /// with its result evaluated detached at the cell (03 §8.4); when that
  /// takes too long it is accepted and marked after recalculation.
  DvInputCheck checkTyped(String sheetId, int row, int col, String input) {
    final s = model.sheet(sheetId);
    if (s == null || s.dvRules.isEmpty) return DvInputCheck.accepted;
    // A draft is only previewed, never enforced.
    if (draftAffects(s, row, col)) return DvInputCheck.accepted;
    if (evaluator.ruleAt(sheetId, row, col) == null) {
      return DvInputCheck.accepted;
    }
    final parsed = InputParser.instance.parse(
      input,
      locale: model.spreadsheet.locale,
      isFormula: (_) => true,
    );
    try {
      CellValue? result;
      if (parsed.isFormula) {
        final t = input.trim();
        final a1 = t.startsWith('=') ? t : '=$t';
        result = editor.engine
            .evaluateDetached(a1, sheetId: sheetId, at: CellPos(row, col))
            ?.value
            .toCellValue();
        if (result is ErrorValue && result.kind == CellErrorKind.loading) {
          result = null;
        }
      }
      return evaluator.checkInput(
        sheetId,
        row,
        col,
        parsed,
        formulaResult: result,
      );
    } catch (_) {
      return DvInputCheck.accepted;
    }
  }

  // ---------------------------------------------------------------------------
  // Enforcement.

  FutureOr<bool> _commitCheck(CellEditSession session, String input) {
    final s = model.sheet(session.sheetId);
    if (s == null || s.dvRules.isEmpty) return true;
    final row = s.rows.indexOf(session.rowId);
    final col = s.columns.indexOf(session.colId);
    if (row < 0 || col < 0) return true;
    final check = checkTyped(s.id, row, col, input);
    if (check.verdict != DvInputVerdict.reject) return true;
    final c = editor.services.navigatorContext;
    if (c == null || !c.mounted) return false;
    return showInvalidEntryDialog(
      c,
      DvEvaluator.cellA1(row, col),
      check.message,
    ).then((_) => false);
  }

  void _gate(CommandContext? ctx, SheetsOperation op) {
    if (op is! SetCellInputs) return;
    final s = model.sheet(op.sheetId);
    if (s == null || s.dvRules.isEmpty) return;
    for (var i = 0; i < op.inputs.length; i++) {
      final row = op.inputs[i];
      for (var j = 0; j < row.length; j++) {
        final input = row[j];
        if (input is! UserCellInput) continue;
        final r = op.row + i;
        final c = op.col + j;
        final check = checkTyped(s.id, r, c, input.text);
        if (check.verdict != DvInputVerdict.reject) continue;
        final a1 = DvEvaluator.cellA1(r, c);
        throw WriteRefused(
          check.dialogMessage(a1),
          code: 'validation',
          show: (context) => showInvalidEntryDialog(context, a1, check.message),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_recalc?.cancel());
    editor.model.removeListener(_onBatch);
    editor.writeGates.remove(_gate);
    editor.layers.remove(_highlightLayer);
    if (identical(editor.cells.dvDraft, _draft)) editor.cells.dvDraft = null;
    highlight.dispose();
    if (editor.editor.commitCheck == _commitCheck) {
      editor.editor.commitCheck = null;
    }
    super.dispose();
  }
}

/// "Invalid entry" (03 §8.4, 04 §11.17).
Future<void> showInvalidEntryDialog(
  BuildContext context,
  String cellA1,
  String? message,
) async {
  final l = sheetsL10n(context);
  final body = l.dvInvalidBody(cellA1);
  await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.dvInvalidTitle,
      description: message == null || message.isEmpty
          ? body
          : '$body\n\n$message',
      dialogKey: 'dialog.invalidEntry',
      cancelId: 'ok',
      buttons: [DialogButtonSpec(id: 'ok', label: l.dialogOk, primary: true)],
    ),
  );
}
