import 'package:wonky_sheets_core/formula.dart' show ColumnLetters, GridRect;
import 'package:wonky_sheets_core/model.dart';

final RegExp _plainName = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
final RegExp _cellLike = RegExp(r'^[A-Za-z]{1,3}[0-9]+$');

/// [name] as it appears before `!` in an A1 reference.
String sheetNameInA1(String name) =>
    _plainName.hasMatch(name) && !_cellLike.hasMatch(name)
    ? name
    : "'${name.replaceAll("'", "''")}'";

/// `Sheet1!A1:F50` (`Sheet1!A:F` for whole columns).
String rangeToA1(WorkbookModel model, ResolvedRange r) {
  final name = model.sheet(r.sheetId)?.name ?? '';
  final GridRect rect = r.rect;
  final body = r.wholeColumns && !r.wholeRows
      ? '${ColumnLetters.fromIndex(rect.left)}:'
            '${ColumnLetters.fromIndex(rect.right)}'
      : rect.a1;
  return '${sheetNameInA1(name)}!$body';
}

/// A free "Prefix N" sheet name ("Pivot table 1", "Details 2").
String nextSheetName(WorkbookModel model, String prefix) {
  final taken = {for (final s in model.sheets) s.name.toLowerCase()};
  for (var i = 1; ; i++) {
    final name = '$prefix $i';
    if (!taken.contains(name.toLowerCase())) return name;
  }
}
