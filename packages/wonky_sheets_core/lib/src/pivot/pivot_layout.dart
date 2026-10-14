import '../content/cell_content.dart';
import 'pivot_engine.dart';
import 'pivot_spec.dart';

/// What a cell of the pivot output is (drives the computed default formats,
/// 07 §7.5).
enum PivotCellRole {
  /// Header area: value names, field names, column items and column totals.
  header,

  /// Row item labels.
  rowLabel,

  /// Value of an item row.
  value,

  /// Any cell of a subtotal row ("East Total").
  subtotal,

  /// Any cell of the grand total row.
  grandTotal,
}

/// The theme-adaptive fill token of a pivot cell (`pivotHeaderFill`,
/// `pivotTotalFill`, 07 §7.5).
enum PivotFill {
  /// No computed fill.
  none,

  /// `pivotHeaderFill`.
  header,

  /// `pivotTotalFill`.
  total,
}

/// Identifies the aggregate behind a value cell (GETPIVOTDATA, drill-down).
final class PivotCellRef {
  /// Creates a reference.
  const PivotCellRef(this.row, this.column, this.valueIndex);

  /// Row node (the root for the grand total row).
  final PivotAxisNode row;

  /// Column node (the root for grand total columns).
  final PivotAxisNode column;

  /// Index into [PivotResult.valueFields].
  final int valueIndex;
}

/// One cell of the pivot output.
final class PivotCell {
  /// Creates a cell.
  const PivotCell(
    this.value, {
    required this.role,
    this.numberFormat,
    this.ref,
  });

  /// The computed value (labels are text or the source values).
  final CellValue value;

  /// Number format (pattern or `preset:*`; null = Automatic).
  final String? numberFormat;

  /// The role.
  final PivotCellRole role;

  /// The aggregate behind a value cell, or null for labels and headers.
  final PivotCellRef? ref;

  /// Header and total rows are bold (07 §7.5).
  bool get bold =>
      role == PivotCellRole.header ||
      role == PivotCellRole.subtotal ||
      role == PivotCellRole.grandTotal;

  /// The computed fill token.
  PivotFill get fill => switch (role) {
    PivotCellRole.header => PivotFill.header,
    PivotCellRole.subtotal || PivotCellRole.grandTotal => PivotFill.total,
    _ => PivotFill.none,
  };

  /// Whether the cell shows an aggregate (drill-down target).
  bool get isValue => ref != null;

  @override
  String toString() => 'PivotCell($value, ${role.name})';
}

/// The laid-out pivot output (07 §7.5), anchored at its top-left cell: the
/// computed overlay the grid renders. [message] (empty spec) and [error]
/// (too large) replace the grid.
final class PivotGrid {
  PivotGrid._(
    this.rowCount,
    this.columnCount,
    this._cells, {
    this.headerRows = 0,
    this.labelColumns = 0,
    this.message,
    this.error,
  });

  /// The muted message shown for an empty spec.
  static const String emptyMessage =
      'Add rows, columns, or values in the pivot table editor';

  /// The `#REF!` message of an output above the cell limit.
  static const String tooLargeMessage = 'Pivot table is too large';

  /// Number of output rows.
  final int rowCount;

  /// Number of output columns.
  final int columnCount;

  /// Rows of the header block.
  final int headerRows;

  /// Label columns at the left.
  final int labelColumns;

  /// Muted overlay text (empty spec), shown at the anchor.
  final String? message;

  /// Error shown at the anchor instead of the output (`#REF!` with message).
  final ErrorValue? error;

  final List<PivotCell?> _cells;

  /// Whether the grid has no cells (message or error state).
  bool get isEmpty => rowCount == 0 || columnCount == 0;

  /// The cell at ([row], [col]) relative to the anchor, or null (empty).
  PivotCell? cellAt(int row, int col) {
    if (row < 0 || col < 0 || row >= rowCount || col >= columnCount) {
      return null;
    }
    return _cells[row * columnCount + col];
  }

  /// The value at ([row], [col]); empty outside the output.
  CellValue valueAt(int row, int col) =>
      cellAt(row, col)?.value ?? CellValue.empty;

  /// The values as rows (tests, exports, drill-down previews).
  List<List<CellValue>> toValues() => [
    for (var r = 0; r < rowCount; r++)
      [for (var c = 0; c < columnCount; c++) valueAt(r, c)],
  ];
}

enum _PosKind { item, subtotal, grandTotal }

final class _Pos {
  _Pos(this.node, this.kind, this.labels);
  final PivotAxisNode node;
  final _PosKind kind;

  /// Item labels to show at this position, by level (null = blank).
  final List<PivotAxisNode?> labels;
}

/// Lays out a [PivotResult] in Google Sheets' tabular form (07 §7.5).
///
/// - One label column per row group (plus a "Values" column when several
///   values are laid out as rows).
/// - Header block: when there are column groups, a field row (the value name
///   in the corner when there is one value, the column field names above
///   the data columns), then one row per column group with the items, then a
///   row of value names when ≥ 2 values are laid out as columns. Without
///   column groups a single header row holds the value names. Row field names
///   are in the last header row.
/// - Subtotal rows ("East Total") after each non-innermost row item whose
///   group shows totals, subtotal columns likewise; the grand total row and
///   column(s) when the outermost group shows totals.
abstract final class PivotLayout {
  /// Builds the output grid. [labelText] renders a label value with its
  /// number format for "‹label› Total" headers (default: plain text).
  static PivotGrid build(
    PivotResult result, {
    String Function(CellValue value, String? numberFormat)? labelText,
  }) {
    if (result.isEmpty) {
      return PivotGrid._(0, 0, const [], message: PivotGrid.emptyMessage);
    }
    final rowFields = result.rowFields;
    final colFields = result.columnFields;
    final values = result.valueFields;
    final r = rowFields.length;
    final c = colFields.length;
    final v = values.length;
    final valuesAsRows =
        v >= 2 && result.spec.valueLayout == PivotValueLayout.rows;
    final valuesAsCols = v >= 1 && !valuesAsRows;
    final vRows = valuesAsRows ? v : 1;
    final vCols = valuesAsCols ? v : 1;

    final rowPos = _positions(result.rowRoot, rowFields);
    // Without values and column groups there are no data columns.
    final colPos = v == 0 && c == 0
        ? const <_Pos>[]
        : _positions(result.columnRoot, colFields);

    var labelCols = r + (valuesAsRows ? 1 : 0);
    if (labelCols == 0 && c > 0) labelCols = 1;
    final fieldRow = c > 0 ? 1 : 0;
    final valueNamesRow = valuesAsCols && (v >= 2 || c == 0) ? 1 : 0;
    var headerRows = fieldRow + c + valueNamesRow;
    if (headerRows == 0 && labelCols > 0) headerRows = 1;

    final width = labelCols + colPos.length * vCols;
    final height = headerRows + rowPos.length * vRows;
    if (width * height > result.maxOutputCells) {
      return PivotGrid._(
        0,
        0,
        const [],
        error: const ErrorValue(CellErrorKind.ref, PivotGrid.tooLargeMessage),
      );
    }

    final cells = List<PivotCell?>.filled(width * height, null);
    void put(int row, int col, PivotCell cell) =>
        cells[row * width + col] = cell;
    String totalLabel(PivotAxisNode node, PivotFieldInfo field) {
      final f = labelText;
      final label = f == null
          ? node.key!.labelText
          : f(node.key!.label, _labelFormat(node, field));
      return '$label Total';
    }

    // Header block: every cell carries the header role (fill).
    for (var y = 0; y < headerRows; y++) {
      for (var x = 0; x < width; x++) {
        put(y, x, const PivotCell(CellValue.empty, role: PivotCellRole.header));
      }
    }
    PivotCell header(CellValue value, [String? format]) =>
        PivotCell(value, role: PivotCellRole.header, numberFormat: format);

    if (c > 0) {
      if (v == 1 && valuesAsCols) put(0, 0, header(TextValue(values[0].name)));
      for (var k = 0; k < c; k++) {
        if (labelCols + k < width) {
          put(0, labelCols + k, header(TextValue(colFields[k].label)));
        }
      }
    }
    final fieldNamesRow = headerRows - 1;
    for (var k = 0; k < r; k++) {
      put(fieldNamesRow, k, header(TextValue(rowFields[k].label)));
    }
    if (valuesAsRows) put(fieldNamesRow, r, header(const TextValue('Values')));

    for (var p = 0; p < colPos.length; p++) {
      final pos = colPos[p];
      final x0 = labelCols + p * vCols;
      switch (pos.kind) {
        case _PosKind.item:
          for (var k = 0; k < c; k++) {
            final node = pos.labels[k];
            if (node == null) continue;
            final f = colFields[k];
            put(
              fieldRow + k,
              x0,
              header(node.key!.label, _labelFormat(node, f)),
            );
          }
        case _PosKind.subtotal:
          put(
            fieldRow + pos.node.depth - 1,
            x0,
            header(
              TextValue(totalLabel(pos.node, colFields[pos.node.depth - 1])),
            ),
          );
        case _PosKind.grandTotal:
          put(fieldRow, x0, header(const TextValue('Grand Total')));
      }
      if (valueNamesRow == 1) {
        for (var j = 0; j < vCols; j++) {
          put(fieldRow + c, x0 + j, header(TextValue(values[j].name)));
        }
      }
    }

    // Body.
    for (var p = 0; p < rowPos.length; p++) {
      final pos = rowPos[p];
      final role = switch (pos.kind) {
        _PosKind.item => PivotCellRole.value,
        _PosKind.subtotal => PivotCellRole.subtotal,
        _PosKind.grandTotal => PivotCellRole.grandTotal,
      };
      for (var vr = 0; vr < vRows; vr++) {
        final y = headerRows + p * vRows + vr;
        final rowRole = role == PivotCellRole.value
            ? PivotCellRole.rowLabel
            : role;
        // Labels.
        for (var x = 0; x < labelCols; x++) {
          put(y, x, PivotCell(CellValue.empty, role: rowRole));
        }
        if (vr == 0) {
          switch (pos.kind) {
            case _PosKind.item:
              for (var k = 0; k < r; k++) {
                final node = pos.labels[k];
                if (node == null) continue;
                put(
                  y,
                  k,
                  PivotCell(
                    node.key!.label,
                    role: rowRole,
                    numberFormat: _labelFormat(node, rowFields[k]),
                  ),
                );
              }
            case _PosKind.subtotal:
              final d = pos.node.depth - 1;
              put(
                y,
                d,
                PivotCell(
                  TextValue(totalLabel(pos.node, rowFields[d])),
                  role: rowRole,
                ),
              );
            case _PosKind.grandTotal:
              put(
                y,
                0,
                PivotCell(const TextValue('Grand Total'), role: rowRole),
              );
          }
        }
        if (valuesAsRows) {
          put(y, r, PivotCell(TextValue(values[vr].name), role: rowRole));
        }
        // Values.
        for (var q = 0; q < colPos.length; q++) {
          for (var vc = 0; vc < vCols; vc++) {
            final x = labelCols + q * vCols + vc;
            final j = valuesAsRows ? vr : (valuesAsCols ? vc : -1);
            if (j < 0) {
              put(y, x, PivotCell(CellValue.empty, role: role));
              continue;
            }
            final col = colPos[q].node;
            put(
              y,
              x,
              PivotCell(
                result.value(pos.node, col, j),
                role: role,
                numberFormat: values[j].numberFormat,
                ref: PivotCellRef(pos.node, col, j),
              ),
            );
          }
        }
      }
    }
    return PivotGrid._(
      height,
      width,
      cells,
      headerRows: headerRows,
      labelColumns: labelCols,
    );
  }

  static String? _labelFormat(PivotAxisNode node, PivotFieldInfo field) =>
      node.key!.inheritsFormat ? field.numberFormat : null;

  /// Output positions along one axis in order (items, subtotals, grand
  /// total), with the item labels each position shows.
  static List<_Pos> _positions(
    PivotAxisNode root,
    List<PivotFieldInfo> fields,
  ) {
    final n = fields.length;
    final out = <_Pos>[];
    if (n == 0) {
      out.add(_Pos(root, _PosKind.item, const []));
      return out;
    }
    final pending = List<PivotAxisNode?>.filled(n, null);
    void visit(PivotAxisNode node) {
      pending[node.depth - 1] = node;
      if (node.depth == n) {
        final labels = List<PivotAxisNode?>.filled(n, null);
        for (var k = 0; k < n; k++) {
          final p = pending[k];
          if (p != null) {
            labels[k] = p;
            pending[k] = null;
          } else if (fields[k].spec.repeatLabels) {
            labels[k] = _ancestorAt(node, k + 1);
          }
        }
        out.add(_Pos(node, _PosKind.item, labels));
        return;
      }
      for (final child in node.children) {
        visit(child);
      }
      if (fields[node.depth - 1].spec.showTotals) {
        out.add(_Pos(node, _PosKind.subtotal, const []));
      }
    }

    for (final child in root.children) {
      visit(child);
    }
    if (fields.first.spec.showTotals) {
      out.add(_Pos(root, _PosKind.grandTotal, const []));
    }
    return out;
  }

  static PivotAxisNode _ancestorAt(PivotAxisNode node, int depth) {
    var n = node;
    while (n.depth > depth) {
      n = n.parent!;
    }
    return n;
  }
}
