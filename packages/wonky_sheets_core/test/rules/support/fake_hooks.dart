import 'core.dart';

/// A tiny [FormulaHooks] fake for rule tests. Formulas are kept in A1 form
/// ("stored" = A1 text) and `evaluateRelative` understands
/// `=<operand> [op <operand>]` where an operand is a number, a quoted string,
/// `TRUE`/`FALSE` or a cell reference (`$C2`, `B$3`, `A1`) shifted relative
/// to the anchor. Supported ops: `> < >= <= = <> + - * /`.
final class FakeHooks implements FormulaHooks {
  FakeHooks(this.values, {this.sheetIdOf});

  final CellSource values;
  final String Function(String name)? sheetIdOf;

  /// Number of evaluations performed.
  int evaluations = 0;

  static final RegExp _ref = RegExp(r'^(\$?)([A-Za-z]{1,3})(\$?)(\d+)$');
  static final RegExp _expr = RegExp(r'^(.+?)\s*(>=|<=|<>|>|<|=|\+|-|\*|/)\s*(.+)$');

  FValue _operand(String t, String sheetId, int dr, int dc) {
    t = t.trim();
    if (t.startsWith('"') && t.endsWith('"') && t.length >= 2) return FText(t.substring(1, t.length - 1));
    if (t.toUpperCase() == 'TRUE') return FBool.t;
    if (t.toUpperCase() == 'FALSE') return FBool.f;
    final n = double.tryParse(t);
    if (n != null) return FNumber(n);
    final m = _ref.firstMatch(t);
    if (m != null) {
      var col = ColumnLetters.toIndex(m.group(2)!);
      var row = int.parse(m.group(4)!) - 1;
      if (m.group(1)!.isEmpty) col += dc;
      if (m.group(3)!.isEmpty) row += dr;
      return values.valueAt(sheetId, row, col);
    }
    return FError(ErrorKind.name);
  }

  double? _num(FValue v) => switch (v) {
    FNumber(:final v) => v,
    FBool(:final v) => v ? 1 : 0,
    FEmpty() => 0,
    _ => null,
  };

  @override
  FValue evaluateRelative(
    String stored, {
    required String sheetId,
    required int anchorRow,
    required int anchorCol,
    required int row,
    required int col,
  }) {
    evaluations++;
    final body = stored.substring(1).trim();
    final dr = row - anchorRow;
    final dc = col - anchorCol;
    final m = _expr.firstMatch(body);
    if (m == null || m.group(1)!.startsWith('"')) return _operand(body, sheetId, dr, dc);
    final a = _operand(m.group(1)!, sheetId, dr, dc);
    final b = _operand(m.group(3)!, sheetId, dr, dc);
    if (a is FError) return a;
    if (b is FError) return b;
    final op = m.group(2)!;
    if ('+-*/'.contains(op)) {
      final x = _num(a), y = _num(b);
      if (x == null || y == null) return FError(ErrorKind.value);
      return FNumber(switch (op) {
        '+' => x + y,
        '-' => x - y,
        '*' => x * y,
        _ => x / y,
      });
    }
    final c = Compare.compare(a, b);
    return FBool(switch (op) {
      '>' => c > 0,
      '<' => c < 0,
      '>=' => c >= 0,
      '<=' => c <= 0,
      '=' => c == 0,
      _ => c != 0,
    });
  }

  @override
  String toA1(String stored, {required String sheetId, required int row, required int col, String locale = 'en_US'}) =>
      stored;

  @override
  String toStored(String a1Formula, {required String sheetId, required int row, required int col, String locale = 'en_US'}) =>
      a1Formula;

  @override
  String translate(
    String stored, {
    required String fromSheetId,
    required int fromRow,
    required int fromCol,
    required String toSheetId,
    required int toRow,
    required int toCol,
  }) => stored;

  @override
  String? repairBoundaries(String stored, {required Set<String> deletedRowIds, required Set<String> deletedColIds}) =>
      null;

  @override
  String? remap(
    String stored, {
    required String hostSheetId,
    required String sourceSheetId,
    required GridRect source,
    required String destSheetId,
    required GridRect dest,
  }) => null;

  @override
  String? repinRows(
    String stored, {
    required String hostSheetId,
    required String sheetId,
    required int blockTop,
    required int blockBottom,
    required String Function(int position) newRowIdAt,
    required int Function(String rowId) oldIndexOf,
  }) => null;

  @override
  String renameName(String stored, String oldName, String newName) => stored;

  @override
  bool references(String stored, {required String hostSheetId, required String sheetId, required GridRect rect}) =>
      false;
}
