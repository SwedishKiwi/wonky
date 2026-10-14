import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart'
    show CellPos, FArray, FError, FValue, FormatHint, FormulaEngine;
import 'package:wonky_sheets_core/model.dart';

/// What the live preview chip shows (03 §8.7).
@immutable
class FormulaPreview {
  const FormulaPreview(this.text, {this.isError = false, this.detail});

  /// `= 1,234.50`, `#REF!`.
  final String text;
  final bool isError;

  /// The error message, or "(3×4 array)".
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is FormulaPreview &&
      other.text == text &&
      other.isError == isError &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(text, isError, detail);
}

/// Live result preview while a formula is typed (03 §8.7
/// `FormulaPreviewController`): 150 ms after the last keystroke the formula
/// is evaluated detached at the edited cell (`evaluateDetached`, 50 ms
/// budget; nothing is shown when the budget is exceeded) and formatted with
/// the cell's number format.
class FormulaPreviewController extends ValueNotifier<FormulaPreview?> {
  FormulaPreviewController({
    required this.engine,
    required this.model,
    this.delay = const Duration(milliseconds: 150),
  }) : super(null);

  final FormulaEngine Function() engine;
  final WorkbookModel Function() model;
  final Duration delay;
  Timer? _timer;

  /// Schedules a preview of [text] at ([row], [col]) of [sheetId]; non
  /// formulas clear it.
  void schedule(String text, {String? sheetId, int? row, int? col}) {
    _timer?.cancel();
    if (!text.startsWith('=') ||
        text.trim().length < 2 ||
        sheetId == null ||
        row == null ||
        col == null) {
      value = null;
      return;
    }
    _timer = Timer(delay, () => value = compute(text, sheetId, row, col));
  }

  /// Evaluates [text] now (tests, [schedule]).
  FormulaPreview? compute(String text, String sheetId, int row, int col) {
    final m = model();
    final ComputedValueLike? computed;
    try {
      final v = engine().evaluateDetached(
        text,
        sheetId: sheetId,
        at: CellPos(row, col),
      );
      computed = v == null ? null : (v.value, v.hint);
    } catch (_) {
      return null;
    }
    if (computed == null) return null;
    var (v, hint) = computed;
    String? detail;
    if (v is FArray) {
      detail = '(${v.rows}×${v.cols} array)';
      v = v.rows == 0 || v.cols == 0 ? v : v.at(0, 0);
    }
    if (v is FError) {
      return FormulaPreview(
        v.kind.literal,
        isError: true,
        detail: v.message ?? detail,
      );
    }
    final locale = m.spreadsheet.locale;
    final format =
        m.explicitFormatChain(sheetId, row, col)[FormatAttr.numberFormat]
            as String?;
    final text0 = CellTextFormatter.formatValue(
      v,
      explicitFormat: format,
      hint: hint,
      locale: locale,
    ).plainText;
    return FormulaPreview('= $text0', detail: detail);
  }

  /// Hides the chip (commit, cancel).
  void clear() {
    _timer?.cancel();
    value = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// A computed value with its format hint.
typedef ComputedValueLike = (FValue, FormatHint);
