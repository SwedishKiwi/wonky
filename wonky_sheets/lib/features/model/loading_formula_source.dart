import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/formula.dart'
    show CellSource, FError, FValue, FormulaEngine, GridDimension, ResolvedArea;
import 'package:wonky_sheets_core/model.dart';

import 'row_loading.dart';

/// The grid's [CellSource] while a spreadsheet streams in (02 §6): a
/// formula that reads rows whose cells are not in memory yet shows
/// `#LOADING` (painted as a muted italic "Loading…", 05 §13.6) instead of a
/// partial result, until those rows arrive. Precedents are followed through
/// single-cell references to other formulas ([maxDepth] levels).
///
/// Once [rows] is complete it is a plain pass-through to [base].
class LoadingFormulaSource implements CellSource {
  LoadingFormulaSource(this.base, this.engine, this.model, this.rows) {
    if (!rows.complete) {
      rows.addListener(_onRows);
      model.addListener(_onBatch);
    }
  }

  /// The engine's values.
  final CellSource base;

  /// Precedents of formula cells.
  final FormulaEngine engine;
  final WorkbookModel model;
  final WorkbookRowLoading rows;

  /// Levels of formula-to-formula references followed.
  static const maxDepth = 4;

  /// Per sheet: sorted indexes of the rows still missing.
  final Map<String, List<int>> _missing = {};

  /// Per cell (`sheet|row|col`): whether its value is still loading.
  final Map<String, bool> _loading = {};

  static const _pending = FError.pending();

  void _onRows() {
    _invalidate();
    if (rows.complete) dispose();
  }

  // Model batches move rows and change formulas.
  void _onBatch(WorkbookChangeBatch _) => _invalidate();

  void _invalidate() {
    _missing.clear();
    _loading.clear();
  }

  /// Detaches from [rows] and the model.
  void dispose() {
    rows.removeListener(_onRows);
    model.removeListener(_onBatch);
  }

  @override
  FValue valueAt(String sheetId, int row, int col) {
    if (!rows.complete && isLoading(sheetId, row, col)) return _pending;
    return base.valueAt(sheetId, row, col);
  }

  /// Whether the formula at the cell reads rows that are still loading.
  bool isLoading(String sheetId, int row, int col, [int depth = 0]) {
    if (rows.complete) return false;
    final content = model.cellAt(sheetId, row, col)?.decoded;
    if (content is! FormulaContent) return false;
    final key = '$sheetId|$row|$col';
    final cached = _loading[key];
    if (cached != null) return cached;
    // Cycles resolve to "not loading".
    _loading[key] = false;
    var loading = false;
    for (final a in engine.dependencies(sheetId, row, col).precedents) {
      if (_areaMissing(a) ||
          (depth < maxDepth &&
              a.isSingleCell &&
              isLoading(a.sheetId, a.top, a.left, depth + 1))) {
        loading = true;
        break;
      }
    }
    _loading[key] = loading;
    return loading;
  }

  bool _areaMissing(ResolvedArea a) {
    if (rows.isSheetLoaded(a.sheetId)) return false;
    final missing = _missing[a.sheetId] ??= _missingIndexes(a.sheetId);
    // First missing index ≥ top.
    var lo = 0, hi = missing.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (missing[mid] < a.top) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo < missing.length && missing[lo] <= a.bottom;
  }

  List<int> _missingIndexes(String sheetId) {
    final sheet = model.sheet(sheetId);
    if (sheet == null) return const [];
    final out = <int>[];
    for (var i = 0; i < sheet.rows.length; i++) {
      if (!rows.isRowLoaded(sheetId, sheet.rows.idAt(i))) out.add(i);
    }
    return out;
  }

  @override
  String? numberFormatAt(String sheetId, int row, int col) =>
      base.numberFormatAt(sheetId, row, col);

  @override
  bool isHidden(
    String sheetId,
    GridDimension dimension,
    int index, {
    bool includeFilter = true,
  }) => base.isHidden(sheetId, dimension, index, includeFilter: includeFilter);

  @visibleForTesting
  int get cachedCells => _loading.length;
}
