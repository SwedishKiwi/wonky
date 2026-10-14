import 'package:wonky_core/wonky_core.dart' show Role;

import '../host/services.dart';

/// One case of the API conformance corpus (09 §21.1).
///
/// [code] is the body of `Object? <name>()`; [decls] are extra top-level
/// declarations. The default fixture is:
///
/// - `Sheet1` (20 rows × 8 columns): `A1:C3` = `[[1, 2, 3], [4, 5, 6],
///   ['a', 'b', 'c']]`;
/// - `Sheet2` (10 × 5), empty.
final class ConformanceCase {
  /// Creates a case.
  const ConformanceCase(
    this.name,
    this.code, {
    this.expect,
    this.cells = const {},
    this.error,
    this.decls = '',
    this.role = Role.editor,
    this.kind = ExecutionKind.editor,
    this.scopes = const {},
    this.isServer = false,
    this.logs = const [],
    this.checkResult = true,
  });

  /// Description.
  final String name;

  /// Function body.
  final String code;

  /// Expected return value (plain values; `DateTime` compared by value).
  final Object? expect;

  /// Expected computed cell values after the run (`'A1'`, `'Sheet2!B2'`).
  final Map<String, Object?> cells;

  /// Expected exception type of a failed execution.
  final String? error;

  /// Extra top-level declarations.
  final String decls;

  /// Role of the runner.
  final Role role;

  /// Kind of execution.
  final ExecutionKind kind;

  /// Granted scopes.
  final Set<String> scopes;

  /// Server-side execution.
  final bool isServer;

  /// Expected log messages (in order, subset).
  final List<String> logs;

  /// Whether [expect] is checked.
  final bool checkResult;
}

/// The corpus.
const conformanceCorpus = <ConformanceCase>[
  // ---------------------------------------------------------------- values
  ConformanceCase(
    'reads a number',
    "return SpreadsheetApp.active.getRange('A1').value;",
    expect: 1,
  ),
  ConformanceCase(
    'reads with a sheet-qualified A1',
    "return SpreadsheetApp.active.getRange('Sheet1!B2').value;",
    expect: 5,
  ),
  ConformanceCase(
    'reads 2-D values',
    "return SpreadsheetApp.active.getRange('A1:C2').values;",
    expect: [
      [1, 2, 3],
      [4, 5, 6],
    ],
  ),
  ConformanceCase(
    'reads text',
    "return SpreadsheetApp.activeSheet.getRange('C3').value;",
    expect: 'c',
  ),
  ConformanceCase(
    'reads an empty cell as null',
    "return SpreadsheetApp.active.getRange('E5').value;",
    expect: null,
  ),
  ConformanceCase(
    'reads empty cells in a block as null',
    "return SpreadsheetApp.active.getRange('C3:D3').values;",
    expect: [
      ['c', null],
    ],
  ),
  ConformanceCase(
    'writes a value',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        'r.value = 42;\n'
        'return r.value;',
    expect: 42,
    cells: {'E1': 42},
  ),
  ConformanceCase(
    'writes 2-D values',
    "SpreadsheetApp.active.getRange('E1:F2').values = [[1, 'x'], [true, null]];\n"
        "return SpreadsheetApp.active.getRange('E1:F2').values;",
    expect: [
      [1, 'x'],
      [true, null],
    ],
    cells: {'E1': 1, 'F1': 'x', 'E2': true, 'F2': null},
  ),
  ConformanceCase(
    'setValues is the same as the setter',
    "SpreadsheetApp.active.getRange('A1:B1').setValues([[10, 20]]);\n"
        "return SpreadsheetApp.active.getRange('A1:B1').values;",
    expect: [
      [10, 20],
    ],
  ),
  ConformanceCase(
    'writes a string starting with = as a formula',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        "r.values = [['=A1+B1']];\n"
        'return r.value;',
    expect: 3,
  ),
  ConformanceCase(
    'setValuesRaw keeps text',
    "final r = SpreadsheetApp.active.getRange('E1:F1');\n"
        "r.setValuesRaw([['=A1', '123']]);\n"
        'return r.values;',
    expect: [
      ['=A1', '123'],
    ],
  ),
  ConformanceCase(
    'values parses strings like typing',
    "final r = SpreadsheetApp.active.getRange('E1:F1');\n"
        "r.values = [['123', 'TRUE']];\n"
        'return r.values;',
    expect: [
      [123, true],
    ],
  ),
  ConformanceCase(
    'writes doubles',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        'r.value = 2.5;\n'
        'return r.value;',
    expect: 2.5,
  ),
  ConformanceCase(
    'writes negative numbers and large integers',
    "final r = SpreadsheetApp.active.getRange('E1:F1');\n"
        'r.values = [[-7, 1000000000000]];\n'
        'return r.values;',
    expect: [
      [-7, 1000000000000],
    ],
  ),
  ConformanceCase(
    'clears with null',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        'r.value = null;\n'
        'return r.value;',
    expect: null,
    cells: {'A1': null},
  ),
  ConformanceCase(
    'reads its own writes before flushing',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        'r.value = 7;\n'
        "return (SpreadsheetApp.active.getRange('A1').value as int) + 1;",
    expect: 8,
  ),
  ConformanceCase(
    'recalculates formulas after writes',
    "SpreadsheetApp.active.getRange('E1').formula = '=SUM(A1:C1)';\n"
        "SpreadsheetApp.active.getRange('A1').value = 100;\n"
        "return SpreadsheetApp.active.getRange('E1').value;",
    expect: 105,
  ),
  ConformanceCase(
    'flush succeeds',
    "SpreadsheetApp.active.getRange('A1').value = 9;\n"
        'SpreadsheetApp.flush();\n'
        "return SpreadsheetApp.active.getRange('A1').value;",
    expect: 9,
  ),
  ConformanceCase(
    'many buffered writes are applied in order',
    'final s = SpreadsheetApp.activeSheet;\n'
        'for (var i = 1; i <= 30; i++) {\n'
        "  s.getRangeAt(i % 10 + 1, 5).value = i;\n"
        '}\n'
        "return s.getRange('E1:E10').values.map((r) => r[0]).toList();",
    expect: [30, 21, 22, 23, 24, 25, 26, 27, 28, 29],
  ),
  // --------------------------------------------------------------- formulas
  ConformanceCase(
    'sets and reads a formula',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        "r.formula = '=SUM(A1:C1)';\n"
        'return [r.formula, r.value];',
    expect: ['=SUM(A1:C1)', 6],
  ),
  ConformanceCase(
    'formula without = gets one',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        "r.formula = 'A2*2';\n"
        'return [r.formula, r.value];',
    expect: ['=A2*2', 8],
  ),
  ConformanceCase(
    'formulas of cells without formulas are empty',
    "final r = SpreadsheetApp.active.getRange('E1:F1');\n"
        "r.formulas = [['=A1', '']];\n"
        'return r.formulas;',
    expect: [
      ['=A1', ''],
    ],
  ),
  ConformanceCase(
    'formula references follow inserted rows',
    'final s = SpreadsheetApp.activeSheet;\n'
        "s.getRange('E1').formula = '=A2';\n"
        's.insertRowsBefore(2, 1);\n'
        "return s.getRange('E1').formula;",
    expect: '=A3',
  ),
  ConformanceCase(
    'reads a formula error as CellError',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        "r.formula = '=1/0';\n"
        'final v = r.value;\n'
        'return v is CellError ? v.code : v;',
    expect: '#DIV/0!',
  ),
  ConformanceCase(
    'writes a CellError',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        "r.value = CellError('#N/A');\n"
        'return r.displayValue;',
    expect: '#N/A',
  ),
  ConformanceCase(
    'CellError equality',
    "return CellError('#N/A') == CellError('#N/A');",
    expect: true,
  ),
  // ---------------------------------------------------------- display/notes
  ConformanceCase(
    'displayValue follows the number format',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.numberFormat = '0.00';\n"
        'return r.displayValue;',
    expect: '1.00',
  ),
  ConformanceCase(
    'displayValues',
    "return SpreadsheetApp.active.getRange('A3:C3').displayValues;",
    expect: [
      ['a', 'b', 'c'],
    ],
  ),
  ConformanceCase(
    'notes',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.note = 'Hello';\n"
        "return [r.note, SpreadsheetApp.active.getRange('A1:B1').notes];",
    expect: [
      'Hello',
      [
        ['Hello', null],
      ],
    ],
  ),
  ConformanceCase(
    'setNotes',
    "final r = SpreadsheetApp.active.getRange('A1:B1');\n"
        "r.notes = [['x', 'y']];\n"
        'return r.notes;',
    expect: [
      ['x', 'y'],
    ],
  ),
  // ------------------------------------------------------------- dates
  ConformanceCase(
    'writes and reads a date',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        'r.value = DateTime.utc(2024, 3, 15);\n'
        'final v = r.value;\n'
        'return v is DateTime ? [v.toUtc().year, v.toUtc().month, v.toUtc().day] : v;',
    expect: [2024, 3, 15],
  ),
  ConformanceCase(
    'a written date gets a date format',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        'r.value = DateTime.utc(2024, 3, 15);\n'
        'return r.numberFormats;',
    expect: [
      ['preset:date'],
    ],
  ),
  ConformanceCase(
    'a written date-time gets a date-time format',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        'r.value = DateTime.utc(2024, 3, 15, 10, 30);\n'
        'final v = r.value as DateTime;\n'
        'return [r.numberFormats[0][0], v.toUtc().hour, v.toUtc().minute];',
    expect: ['preset:dateTime', 10, 30],
  ),
  ConformanceCase(
    'formula dates come back as DateTime',
    "final r = SpreadsheetApp.active.getRange('E1');\n"
        "r.formula = '=DATE(2020, 2, 29)';\n"
        "r.numberFormat = 'yyyy-mm-dd';\n"
        'final v = r.value;\n'
        'return v is DateTime ? v.toUtc().day : v;',
    expect: 29,
  ),
  // ------------------------------------------------------------ geometry
  ConformanceCase(
    'range geometry',
    "final r = SpreadsheetApp.active.getRange('B2:D5');\n"
        'return [r.row, r.column, r.numRows, r.numColumns, r.lastRow, r.lastColumn, r.a1Notation];',
    expect: [2, 2, 4, 3, 5, 4, 'B2:D5'],
  ),
  ConformanceCase(
    'single cell A1 notation',
    "return SpreadsheetApp.active.getRange('C3').a1Notation;",
    expect: 'C3',
  ),
  ConformanceCase(
    'offset',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        'return [r.offset(1, 1).a1Notation, r.offset(1, 1, 2, 2).a1Notation];',
    expect: ['B2', 'B2:C3'],
  ),
  ConformanceCase(
    'cell relative to a range',
    "return SpreadsheetApp.active.getRange('A1:C3').cell(2, 2).value;",
    expect: 5,
  ),
  ConformanceCase(
    'cell outside the range throws',
    "SpreadsheetApp.active.getRange('A1:B2').cell(3, 1);\nreturn 'no';",
    error: 'RangeException',
  ),
  ConformanceCase(
    'isBlank',
    'final ss = SpreadsheetApp.active;\n'
        "return [ss.getRange('E1:F2').isBlank, ss.getRange('A1:B2').isBlank];",
    expect: [true, false],
  ),
  ConformanceCase(
    'range.sheet',
    "return SpreadsheetApp.active.getRange('Sheet2!A1').sheet.name;",
    expect: 'Sheet2',
  ),
  ConformanceCase(
    'whole column range',
    "final r = SpreadsheetApp.activeSheet.getRange('B:B');\n"
        'return [r.numRows, r.numColumns, r.column];',
    expect: [20, 1, 2],
  ),
  ConformanceCase(
    'whole row range',
    "final r = SpreadsheetApp.activeSheet.getRange('2:2');\n"
        'return [r.numRows, r.numColumns, r.row];',
    expect: [1, 8, 2],
  ),
  // ---------------------------------------------------------- range errors
  ConformanceCase(
    'invalid A1 throws RangeException',
    "SpreadsheetApp.active.getRange('not a range!!');\nreturn 'no';",
    error: 'RangeException',
  ),
  ConformanceCase(
    'RangeException can be caught',
    'try {\n'
        "  SpreadsheetApp.active.getRange('Nope!A1');\n"
        "  return 'no';\n"
        '} on RangeException catch (e) {\n'
        "  return 'caught';\n"
        '}',
    expect: 'caught',
  ),
  ConformanceCase(
    'API exceptions are ScriptExceptions',
    'try {\n'
        "  SpreadsheetApp.active.getRange('A1:B2').values = [[1]];\n"
        "  return 'no';\n"
        '} on ScriptException catch (e) {\n'
        '  return e.code;\n'
        '}',
    expect: 'range',
  ),
  ConformanceCase(
    'dimension mismatch on write throws',
    "SpreadsheetApp.active.getRange('A1:B2').values = [[1, 2]];\nreturn 'no';",
    error: 'RangeException',
  ),
  ConformanceCase(
    'getRangeAt out of the sheet throws',
    "SpreadsheetApp.activeSheet.getRangeAt(100, 1);\nreturn 'no';",
    error: 'RangeException',
  ),
  ConformanceCase(
    'rows start at 1',
    "SpreadsheetApp.activeSheet.getRangeAt(0, 1);\nreturn 'no';",
    error: 'RangeException',
  ),
  // ----------------------------------------------------------------- sheets
  ConformanceCase(
    'lists sheets',
    'return SpreadsheetApp.active.sheets.map((s) => s.name).toList();',
    expect: ['Sheet1', 'Sheet2'],
  ),
  ConformanceCase(
    'sheetByName is case-insensitive',
    "return SpreadsheetApp.active.sheetByName('sheet2')!.name;",
    expect: 'Sheet2',
  ),
  ConformanceCase(
    'sheetByName returns null for unknown sheets',
    "return SpreadsheetApp.active.sheetByName('Nope') == null;",
    expect: true,
  ),
  ConformanceCase(
    'sheetById',
    'final id = SpreadsheetApp.active.sheets[1].id;\n'
        'return SpreadsheetApp.active.sheetById(id)!.name;',
    expect: 'Sheet2',
  ),
  ConformanceCase(
    'inserts a sheet at the end',
    "final s = SpreadsheetApp.active.insertSheet(name: 'New');\n"
        'return [s.name, s.index, SpreadsheetApp.active.sheets.length];',
    expect: ['New', 3, 3],
  ),
  ConformanceCase(
    'inserts a sheet at a position',
    "final s = SpreadsheetApp.active.insertSheet(name: 'First', index: 1);\n"
        'return SpreadsheetApp.active.sheets.map((x) => x.name).toList();',
    expect: ['First', 'Sheet1', 'Sheet2'],
  ),
  ConformanceCase(
    'renames a sheet',
    "final s = SpreadsheetApp.active.sheetByName('Sheet2')!;\n"
        "s.name = 'Data';\n"
        "return SpreadsheetApp.active.sheetByName('Data')!.index;",
    expect: 2,
  ),
  ConformanceCase(
    'deletes a sheet',
    "final ss = SpreadsheetApp.active;\nss.deleteSheet(ss.sheetByName('Sheet2')!);\n"
        'return ss.sheets.length;',
    expect: 1,
  ),
  ConformanceCase(
    'duplicates a sheet',
    "final ss = SpreadsheetApp.active;\nfinal d = ss.duplicateSheet(ss.sheetByName('Sheet1')!, newName: 'Dup');\n"
        "return [d.name, d.getRange('B2').value];",
    expect: ['Dup', 5],
  ),
  ConformanceCase(
    'inserts a sheet from a template',
    "final ss = SpreadsheetApp.active;\nfinal d = ss.insertSheet(name: 'T', template: ss.sheetByName('Sheet1'));\n"
        "return d.getRange('A1').value;",
    expect: 1,
  ),
  ConformanceCase(
    'moves a sheet',
    "final ss = SpreadsheetApp.active;\nss.moveSheet(ss.sheetByName('Sheet2')!, 1);\n"
        'return ss.sheets.map((s) => s.name).toList();',
    expect: ['Sheet2', 'Sheet1'],
  ),
  ConformanceCase(
    'sheet handles survive renames',
    "final s = SpreadsheetApp.active.sheetByName('Sheet2')!;\n"
        "s.name = 'Renamed';\n"
        'return s.name;',
    expect: 'Renamed',
  ),
  ConformanceCase(
    'last row and column',
    'final s = SpreadsheetApp.activeSheet;\nreturn [s.lastRow, s.lastColumn];',
    expect: [3, 3],
  ),
  ConformanceCase(
    'empty sheet has last row 0',
    "final s = SpreadsheetApp.active.sheetByName('Sheet2')!;\nreturn [s.lastRow, s.lastColumn];",
    expect: [0, 0],
  ),
  ConformanceCase(
    'max rows and columns',
    'final s = SpreadsheetApp.activeSheet;\nreturn [s.maxRows, s.maxColumns];',
    expect: [20, 8],
  ),
  ConformanceCase(
    'data range',
    'return SpreadsheetApp.activeSheet.dataRange.a1Notation;',
    expect: 'A1:C3',
  ),
  ConformanceCase(
    'getRangeAt',
    'return SpreadsheetApp.activeSheet.getRangeAt(2, 1, 1, 3).values;',
    expect: [
      [4, 5, 6],
    ],
  ),
  ConformanceCase(
    'appends a row',
    'final s = SpreadsheetApp.activeSheet;\n'
        "s.appendRow([7, 8, 'nine']);\n"
        "return [s.lastRow, s.getRange('C4').value];",
    expect: [4, 'nine'],
    cells: {'A4': 7, 'B4': 8},
  ),
  ConformanceCase(
    'appendRow grows the grid',
    "final s = SpreadsheetApp.active.sheetByName('Sheet2')!;\n"
        'for (var i = 0; i < 12; i++) {\n'
        '  s.appendRow([i]);\n'
        '}\n'
        'return [s.lastRow, s.maxRows];',
    expect: [12, 12],
  ),
  ConformanceCase(
    'inserts rows; ranges keep pointing at their cells',
    'final s = SpreadsheetApp.activeSheet;\n'
        "final r = s.getRange('A1');\n"
        's.insertRowsBefore(1, 2);\n'
        "return [r.a1Notation, r.value, s.getRange('A3').value];",
    expect: ['A3', 1, 1],
  ),
  ConformanceCase(
    'inserts rows after',
    'final s = SpreadsheetApp.activeSheet;\ns.insertRowsAfter(1, 1);\n'
        "return [s.getRange('A2').value, s.getRange('A3').value, s.maxRows];",
    expect: [null, 4, 21],
  ),
  ConformanceCase(
    'deletes rows',
    'final s = SpreadsheetApp.activeSheet;\ns.deleteRows(1);\n'
        "return [s.getRange('A1').value, s.maxRows];",
    expect: [4, 19],
  ),
  ConformanceCase(
    'inserts and deletes columns',
    'final s = SpreadsheetApp.activeSheet;\n'
        's.insertColumnsAfter(1, 1);\n'
        "final afterInsert = [s.getRange('B1').value, s.getRange('C1').value];\n"
        's.deleteColumns(2, 2);\n'
        "return [afterInsert, s.getRange('B1').value];",
    expect: [
      [null, 2],
      3,
    ],
  ),
  ConformanceCase(
    'insertColumnsBefore',
    "final s = SpreadsheetApp.activeSheet;\ns.insertColumnsBefore(1, 1);\nreturn s.getRange('B1').value;",
    expect: 1,
  ),
  ConformanceCase(
    'a deleted range throws',
    'final s = SpreadsheetApp.activeSheet;\n'
        "final r = s.getRange('A1');\n"
        's.deleteRows(1);\n'
        'return r.value;',
    error: 'RangeException',
  ),
  ConformanceCase(
    'deleting outside the sheet throws',
    'SpreadsheetApp.activeSheet.deleteRows(19, 5);\nreturn 1;',
    error: 'RangeException',
  ),
  ConformanceCase(
    'frozen rows and columns',
    'final s = SpreadsheetApp.activeSheet;\n'
        's.frozenRows = 1;\n'
        's.frozenColumns = 2;\n'
        'return [s.frozenRows, s.frozenColumns];',
    expect: [1, 2],
  ),
  ConformanceCase(
    'hides and shows a sheet',
    "final s = SpreadsheetApp.active.sheetByName('Sheet2')!;\n"
        's.hide();\n'
        'final hidden = s.isHidden;\n'
        's.show();\n'
        'return [hidden, s.isHidden];',
    expect: [true, false],
  ),
  ConformanceCase(
    'tab color',
    'final s = SpreadsheetApp.activeSheet;\n'
        "s.tabColor = '#FF0000';\n"
        'final c = s.tabColor;\n'
        's.tabColor = null;\n'
        'return [c, s.tabColor];',
    expect: ['#FF0000', null],
  ),
  ConformanceCase(
    'hides, shows and resizes rows and columns',
    'final s = SpreadsheetApp.activeSheet;\n'
        's.hideRows(2, 2);\n'
        's.showRows(2);\n'
        's.hideColumns(1);\n'
        's.showColumns(1);\n'
        's.setRowHeight(1, 40);\n'
        's.setColumnWidth(1, 200);\n'
        's.autoResizeColumns(1, 2);\n'
        "return 'ok';",
    expect: 'ok',
  ),
  ConformanceCase(
    'clears a sheet',
    'final s = SpreadsheetApp.activeSheet;\ns.clear();\nreturn s.lastRow;',
    expect: 0,
    cells: {'A1': null},
  ),
  ConformanceCase(
    'clears only contents of a sheet',
    'final s = SpreadsheetApp.activeSheet;\n'
        "s.getRange('A1').background = '#FF0000';\n"
        's.clear(contentsOnly: true);\n'
        "return s.getRange('A1').backgrounds;",
    expect: [
      ['#FF0000'],
    ],
    cells: {'A1': null},
  ),
  // ---------------------------------------------------------------- formats
  ConformanceCase(
    'background',
    "final r = SpreadsheetApp.active.getRange('A1:B1');\n"
        "r.background = '#ff0000';\n"
        'return r.backgrounds;',
    expect: [
      ['#FF0000', '#FF0000'],
    ],
  ),
  ConformanceCase(
    'background null removes the fill',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.background = '#ff0000';\n"
        'r.background = null;\n'
        'return r.backgrounds;',
    expect: [
      [null],
    ],
  ),
  ConformanceCase(
    'setBackgrounds per cell',
    "final r = SpreadsheetApp.active.getRange('A1:B1');\n"
        "r.setBackgrounds([['#00FF00', null]]);\n"
        'return r.backgrounds;',
    expect: [
      ['#00FF00', null],
    ],
  ),
  ConformanceCase(
    'short hex colors',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.fontColor = '#0f0';\n"
        'return r.fontColors;',
    expect: [
      ['#00FF00'],
    ],
  ),
  ConformanceCase(
    'invalid colors are rejected',
    'try {\n'
        "  SpreadsheetApp.active.getRange('A1').background = 'red';\n"
        '  SpreadsheetApp.flush();\n'
        "  return 'no';\n"
        '} on ScriptException catch (e) {\n'
        '  return e.code;\n'
        '}',
    expect: 'invalid_argument',
  ),
  ConformanceCase(
    'font weight and style',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.fontWeight = 'bold';\n"
        "r.fontStyle = 'italic';\n"
        'return [r.fontWeights, r.fontStyles];',
    expect: [
      [
        ['bold'],
      ],
      [
        ['italic'],
      ],
    ],
  ),
  ConformanceCase(
    'font family and size',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.fontFamily = 'Roboto';\n"
        'r.fontSize = 14;\n'
        'return [r.fontFamilies[0][0], r.fontSizes[0][0]];',
    expect: ['Roboto', 14.0],
  ),
  ConformanceCase(
    'alignments',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.horizontalAlignment = 'center';\n"
        "r.verticalAlignment = 'top';\n"
        'return [r.horizontalAlignments[0][0], r.verticalAlignments[0][0]];',
    expect: ['center', 'top'],
  ),
  ConformanceCase(
    'default horizontal alignment is general',
    "return SpreadsheetApp.active.getRange('A1').horizontalAlignments;",
    expect: [
      ['general'],
    ],
  ),
  ConformanceCase(
    'number formats',
    "final r = SpreadsheetApp.active.getRange('A1:B1');\n"
        "r.setNumberFormats([['0.00%', '#,##0']]);\n"
        'return [r.numberFormats, r.displayValues];',
    expect: [
      [
        ['0.00%', '#,##0'],
      ],
      [
        ['100.00%', '2'],
      ],
    ],
  ),
  ConformanceCase(
    'wrap, decoration and borders',
    "final r = SpreadsheetApp.active.getRange('A1:B2');\n"
        "r.wrapStrategy = 'wrap';\n"
        "r.textDecoration = 'underline';\n"
        "r.setBorder(top: true, bottom: true, color: '#000000', style: 'medium');\n"
        'r.setBorder(top: false);\n'
        "return 'ok';",
    expect: 'ok',
  ),
  ConformanceCase(
    'clearFormat keeps values',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.background = '#123456';\n"
        'r.clearFormat();\n'
        'return [r.value, r.backgrounds[0][0]];',
    expect: [1, null],
  ),
  ConformanceCase(
    'clearContent keeps formats',
    "final r = SpreadsheetApp.active.getRange('A1');\n"
        "r.background = '#123456';\n"
        'r.clearContent();\n'
        'return [r.value, r.backgrounds[0][0]];',
    expect: [null, '#123456'],
  ),
  ConformanceCase(
    'clear removes everything',
    "final r = SpreadsheetApp.active.getRange('A1:C1');\n"
        "r.background = '#123456';\n"
        'r.clear();\n'
        'return [r.values, r.backgrounds];',
    expect: [
      [
        [null, null, null],
      ],
      [
        [null, null, null],
      ],
    ],
  ),
  ConformanceCase(
    'merge and break apart',
    "final r = SpreadsheetApp.active.getRange('E1:F2');\n"
        'r.merge();\n'
        'final merged = r.isMerged;\n'
        'r.breakApart();\n'
        'return [merged, r.isMerged];',
    expect: [true, false],
  ),
  ConformanceCase(
    'merge across',
    "final r = SpreadsheetApp.active.getRange('E1:F2');\nr.mergeAcross();\nreturn SpreadsheetApp.active.getRange('E2').isMerged;",
    expect: true,
  ),
  ConformanceCase(
    'checkboxes',
    "final r = SpreadsheetApp.active.getRange('E1:E2');\n"
        'r.insertCheckboxes();\n'
        'r.removeCheckboxes();\n'
        "return 'ok';",
    expect: 'ok',
  ),
  // -------------------------------------------------------------- copy/move
  ConformanceCase(
    'copyTo copies values and formats',
    'final ss = SpreadsheetApp.active;\n'
        "ss.getRange('A1').background = '#AA0000';\n"
        "ss.getRange('A1:B1').copyTo(ss.getRange('E5'));\n"
        "return [ss.getRange('E5:F5').values, ss.getRange('E5').backgrounds[0][0]];",
    expect: [
      [
        [1, 2],
      ],
      '#AA0000',
    ],
  ),
  ConformanceCase(
    'copyTo translates relative formulas',
    'final ss = SpreadsheetApp.active;\n'
        "ss.getRange('D1').formula = '=A1*2';\n"
        "ss.getRange('D1').copyTo(ss.getRange('D2'));\n"
        "return [ss.getRange('D2').formula, ss.getRange('D2').value];",
    expect: ['=A2*2', 8],
  ),
  ConformanceCase(
    'copyTo contents only',
    'final ss = SpreadsheetApp.active;\n'
        "ss.getRange('A1').background = '#AA0000';\n"
        "ss.getRange('A1').copyTo(ss.getRange('E1'), contentsOnly: true);\n"
        "return [ss.getRange('E1').value, ss.getRange('E1').backgrounds[0][0]];",
    expect: [1, null],
  ),
  ConformanceCase(
    'copyTo formats only',
    'final ss = SpreadsheetApp.active;\n'
        "ss.getRange('A1').background = '#AA0000';\n"
        "ss.getRange('A1').copyTo(ss.getRange('E1'), formatsOnly: true);\n"
        "return [ss.getRange('E1').value, ss.getRange('E1').backgrounds[0][0]];",
    expect: [null, '#AA0000'],
  ),
  ConformanceCase(
    'moveTo moves the block',
    'final ss = SpreadsheetApp.active;\n'
        "ss.getRange('A1:B1').moveTo(ss.getRange('Sheet2!B2'));\n"
        "return [ss.getRange('A1').value, ss.getRange('Sheet2!B2:C2').values];",
    expect: [
      null,
      [
        [1, 2],
      ],
    ],
  ),
  // ------------------------------------------------------------ named ranges
  ConformanceCase(
    'named ranges',
    'final ss = SpreadsheetApp.active;\n'
        "ss.setNamedRange('Data', ss.getRange('A1:C3'));\n"
        "final byName = ss.getRangeByName('Data')!.a1Notation;\n"
        "final viaA1 = ss.getRange('Data').numRows;\n"
        'final names = ss.namedRanges.map((n) => n.name).toList();\n'
        "ss.removeNamedRange('Data');\n"
        "return [byName, viaA1, names, ss.getRangeByName('Data') == null];",
    expect: [
      'A1:C3',
      3,
      ['Data'],
      true,
    ],
  ),
  ConformanceCase(
    'setNamedRange updates an existing name',
    'final ss = SpreadsheetApp.active;\n'
        "ss.setNamedRange('Data', ss.getRange('A1'));\n"
        "ss.setNamedRange('Data', ss.getRange('B2:C3'));\n"
        "return ss.getRangeByName('Data')!.a1Notation;",
    expect: 'B2:C3',
  ),
  ConformanceCase(
    'NamedRange.remove',
    'final ss = SpreadsheetApp.active;\n'
        "ss.setNamedRange('X', ss.getRange('A1'));\n"
        'ss.namedRanges.first.remove();\n'
        'return ss.namedRanges.length;',
    expect: 0,
  ),
  // -------------------------------------------------------------- spreadsheet
  ConformanceCase(
    'spreadsheet name',
    'final ss = SpreadsheetApp.active;\n'
        "ss.name = 'Budget';\n"
        'return ss.name;',
    expect: 'Budget',
  ),
  ConformanceCase(
    'spreadsheet id and url',
    'final ss = SpreadsheetApp.active;\n'
        "return [ss.id.isNotEmpty, ss.url.contains('/sheets/s/')];",
    expect: [true, true],
  ),
  ConformanceCase(
    'locale and time zone',
    'final ss = SpreadsheetApp.active;\n'
        "ss.timeZone = 'Europe/Stockholm';\n"
        "ss.locale = 'en_GB';\n"
        'return [ss.locale, ss.timeZone];',
    expect: ['en_GB', 'Europe/Stockholm'],
  ),
  ConformanceCase(
    'getRangeList',
    'final ss = SpreadsheetApp.active;\n'
        "final list = ss.getRangeList(['A1', 'B2']);\n"
        "list.background = '#00FF00';\n"
        "return [list.ranges.length, ss.getRange('B2').backgrounds[0][0]];",
    expect: [2, '#00FF00'],
  ),
  ConformanceCase(
    'owner',
    'return SpreadsheetApp.active.owner.name;',
    expect: 'Anna',
  ),
  ConformanceCase(
    'toast on the server is logged',
    "SpreadsheetApp.active.toast('Done', title: 'Job');\nreturn 'ok';",
    expect: 'ok',
    isServer: true,
    logs: ['Toast: Job — Done'],
  ),
  // ------------------------------------------------------------- selection
  ConformanceCase(
    'active range defaults to A1',
    'return SpreadsheetApp.activeRange.a1Notation;',
    expect: 'A1',
  ),
  ConformanceCase(
    'active sheet defaults to the first sheet',
    'return SpreadsheetApp.activeSheet.name;',
    expect: 'Sheet1',
  ),
  ConformanceCase(
    'active range list and current cell',
    'return [SpreadsheetApp.activeRangeList.length, SpreadsheetApp.currentCell!.a1Notation];',
    expect: [1, 'A1'],
  ),
  // ---------------------------------------------------------------- session
  ConformanceCase(
    'active user without the email scope',
    'final u = Session.activeUser;\nreturn [u.name, u.email];',
    expect: ['Anna', ''],
  ),
  ConformanceCase(
    'active user with the email scope',
    'return Session.activeUser.email;',
    expect: 'anna@example.com',
    scopes: {'user.email'},
  ),
  ConformanceCase(
    'effective user and locale',
    'return [Session.effectiveUser.name, Session.activeUserLocale];',
    expect: ['Anna', 'en_US'],
  ),
  ConformanceCase(
    'script time zone defaults to the spreadsheet',
    "SpreadsheetApp.active.timeZone = 'America/New_York';\nreturn Session.scriptTimeZone;",
    expect: 'America/New_York',
  ),
  // -------------------------------------------------------------- utilities
  ConformanceCase(
    'uuid',
    'final id = Utilities.uuid();\nreturn [id.length, id == Utilities.uuid()];',
    expect: [36, false],
  ),
  ConformanceCase(
    'base64',
    "final e = Utilities.base64Encode([104, 105]);\nreturn [e, Utilities.base64Decode(e)];",
    expect: [
      'aGk=',
      [104, 105],
    ],
  ),
  ConformanceCase(
    'digests',
    "return [Utilities.computeDigest('sha256', 'abc'), Utilities.computeDigest('md5', 'abc')];",
    expect: [
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      '900150983cd24fb0d6963f7d28e17f72',
    ],
  ),
  ConformanceCase(
    'hmac',
    "return Utilities.computeHmac('sha256', 'data', 'key');",
    expect: '5031fe3d989c6d1537a013fa6e739da23463fdaec3b70137d828e36ace221bd0',
  ),
  ConformanceCase(
    'json',
    "final s = Utilities.jsonEncode({'a': [1, true, null], 'b': 'x'});\n"
        'final m = Utilities.jsonDecode(s) as Map;\n'
        "return [s, m['b'], (m['a'] as List).length];",
    expect: ['{"a":[1,true,null],"b":"x"}', 'x', 3],
  ),
  ConformanceCase(
    'formatString',
    "return Utilities.formatString('%s is %d and %.2f (100%%)', ['x', 3, 2.5]);",
    expect: 'x is 3 and 2.50 (100%)',
  ),
  ConformanceCase(
    'formatDate',
    "return Utilities.formatDate(DateTime.utc(2024, 1, 2, 23, 30), 'UTC', 'yyyy-mm-dd hh:mm');",
    expect: '2024-01-02 23:30',
  ),
  ConformanceCase(
    'parseDate',
    "final d = Utilities.parseDate('2024-05-06', 'UTC', 'yyyy-mm-dd');\n"
        'return [d.toUtc().year, d.toUtc().month, d.toUtc().day];',
    expect: [2024, 5, 6],
  ),
  ConformanceCase('sleep', "Utilities.sleep(1);\nreturn 'ok';", expect: 'ok'),
  ConformanceCase(
    'sleep longer than 5 s is rejected',
    'Utilities.sleep(6000);\nreturn 1;',
    error: 'ScriptException',
  ),
  // ---------------------------------------------------------------- logging
  ConformanceCase(
    'Logger and print',
    "Logger.log('one');\nLogger.warn('two');\nLogger.error(3);\nprint('four');\nreturn null;",
    expect: null,
    logs: ['one', 'two', '3', 'four'],
  ),
  ConformanceCase(
    'logs null values',
    'Object? x;\nLogger.log(x);\nLogger.log(\'v=\$x\');\nreturn 1;',
    expect: 1,
    logs: ['null', 'v=null'],
  ),
  // ------------------------------------------------------------- properties
  ConformanceCase(
    'document properties',
    'final p = PropertiesService.documentProperties;\n'
        "p.setProperty('runs', '1');\n"
        "p.setProperty('runs', '2');\n"
        "p.setProperty('other', 'x');\n"
        "final v = p.getProperty('runs');\n"
        "p.deleteProperty('other');\n"
        "return [v, p.getProperties(), p.keys, p.getProperty('other')];",
    expect: [
      '2',
      {'runs': '2'},
      ['runs'],
      null,
    ],
  ),
  ConformanceCase(
    'setProperties with deleteAllOthers',
    'final p = PropertiesService.documentProperties;\n'
        "p.setProperty('a', '1');\n"
        "p.setProperties({'b': '2'}, deleteAllOthers: true);\n"
        'return p.getProperties();',
    expect: {'b': '2'},
  ),
  ConformanceCase(
    'user properties are separate',
    "PropertiesService.userProperties.setProperty('k', 'u');\n"
        "PropertiesService.documentProperties.setProperty('k', 'd');\n"
        "return [PropertiesService.userProperties.getProperty('k'), PropertiesService.documentProperties.getProperty('k')];",
    expect: ['u', 'd'],
  ),
  ConformanceCase(
    'property values are limited to 9 KB',
    "final big = List<String>.filled(10000, 'x').join();\n"
        "PropertiesService.documentProperties.setProperty('big', big);\n"
        'return 1;',
    error: 'QuotaExceededException',
  ),
  // --------------------------------------------------------- script language
  ConformanceCase(
    'script classes and closures',
    'final items = [Item(3), Item(1), Item(2)];\n'
        'items.sort((a, b) => a.n.compareTo(b.n));\n'
        "return items.map((i) => '\$i').join(',');",
    decls: '''
class Item {
  Item(this.n);
  final int n;
  @override
  String toString() => 'Item(\$n)';
}
''',
    expect: 'Item(1),Item(2),Item(3)',
  ),
  ConformanceCase(
    'collections over range values',
    "final values = SpreadsheetApp.active.getRange('A1:C2').values;\n"
        'var sum = 0;\n'
        'for (final row in values) {\n'
        '  for (final v in row) {\n'
        '    if (v is int) sum += v;\n'
        '  }\n'
        '}\n'
        'return sum;',
    expect: 21,
  ),
  ConformanceCase(
    'maps and string helpers',
    "final m = <String, int>{'a': 1, 'b': 2};\n"
        "return [m.keys.join('+'), 'Hello'.toUpperCase(), ' x '.trim()];",
    expect: ['a+b', 'HELLO', 'x'],
  ),
  ConformanceCase(
    'try/finally',
    'var log = <String>[];\n'
        'try {\n'
        "  log.add('try');\n"
        "  throw StateError('x');\n"
        '} catch (e) {\n'
        "  log.add('catch');\n"
        '} finally {\n'
        "  log.add('finally');\n"
        '}\n'
        'return log;',
    expect: ['try', 'catch', 'finally'],
  ),
  ConformanceCase(
    'helper functions in the same file',
    'return twice(21);',
    decls: 'int twice(int x) => x * 2;',
    expect: 42,
  ),
  ConformanceCase(
    'uncaught exceptions fail the execution',
    "throw Exception('boom');",
    error: 'Exception',
  ),
  ConformanceCase(
    'uncaught script exception classes',
    "throw MyError('bad input');",
    decls: '''
class MyError implements Exception {
  MyError(this.message);
  final String message;
  @override
  String toString() => 'MyError: \$message';
}
''',
    error: 'MyError',
  ),
  // ------------------------------------------------------------ permissions
  ConformanceCase(
    'viewers can read',
    "return SpreadsheetApp.active.getRange('A1').value;",
    expect: 1,
    role: Role.viewer,
  ),
  ConformanceCase(
    'viewers cannot write',
    "SpreadsheetApp.active.getRange('A1').value = 2;\nreturn 1;",
    error: 'PermissionDeniedException',
    role: Role.viewer,
    cells: {'A1': 1},
  ),
  ConformanceCase(
    'viewers cannot change document properties',
    "PropertiesService.documentProperties.setProperty('a', 'b');\nreturn 1;",
    error: 'PermissionDeniedException',
    role: Role.commenter,
  ),
  ConformanceCase(
    'viewers can change their user properties',
    "PropertiesService.userProperties.setProperty('a', 'b');\nreturn PropertiesService.userProperties.getProperty('a');",
    expect: 'b',
    role: Role.viewer,
  ),
  ConformanceCase(
    'custom functions cannot read the spreadsheet',
    "return SpreadsheetApp.active.getRange('A1').value;",
    error: 'CustomFunctionSideEffectException',
    kind: ExecutionKind.customFunction,
  ),
  ConformanceCase(
    'custom functions cannot show UI',
    "SpreadsheetApp.ui.alert('x');\nreturn 1;",
    error: 'CustomFunctionSideEffectException',
    kind: ExecutionKind.customFunction,
  ),
  ConformanceCase(
    'custom functions may use Utilities',
    "return Utilities.computeDigest('md5', 'abc').length;",
    expect: 32,
    kind: ExecutionKind.customFunction,
  ),
  ConformanceCase(
    'server executions have no UI',
    "SpreadsheetApp.ui.alert('x');\nreturn 1;",
    error: 'UiUnavailableException',
    isServer: true,
  ),
  ConformanceCase(
    'triggers need the triggers scope',
    "ScriptApp.newTrigger('dailyJob').timeBased().everyHours(1).create();\nreturn 1;",
    decls: 'void dailyJob() {}',
    error: 'ScopeNotGrantedException',
  ),
  ConformanceCase(
    'creates, lists and deletes triggers',
    "final t = ScriptApp.newTrigger('dailyJob').timeBased().everyDays(1).atHour(7).create();\n"
        "final e = ScriptApp.newTrigger('dailyJob').forSpreadsheet().onEdit().create();\n"
        'final listed = ScriptApp.projectTriggers.map((x) => x.eventType).toList();\n'
        'ScriptApp.deleteTrigger(t);\n'
        'return [t.functionName, e.eventType, listed, ScriptApp.projectTriggers.length];',
    decls: 'void dailyJob() {}',
    expect: [
      'dailyJob',
      'onEdit',
      ['timeDriven', 'onEdit'],
      1,
    ],
    scopes: {'script.triggers'},
  ),
  ConformanceCase(
    'triggers must target an existing function',
    "ScriptApp.newTrigger('nope').timeBased().everyHours(1).create();\nreturn 1;",
    error: 'ScriptException',
    scopes: {'script.triggers'},
  ),
  ConformanceCase(
    'UrlFetchApp needs the external_request scope',
    "UrlFetchApp.fetch('https://example.com');\nreturn 1;",
    error: 'ScopeNotGrantedException',
    isServer: true,
  ),
];

/// Name of the function of case [index] in [conformanceProgramSource].
String conformanceFunctionName(int index) => 'case$index';

/// One script with every case of [conformanceCorpus] as `case<i>()`.
Map<String, String> conformanceProgramSource() {
  final b = StringBuffer("import 'package:wonky/wonky.dart';\n\n");
  final decls = <String>{};
  for (final c in conformanceCorpus) {
    if (c.decls.isNotEmpty) decls.add(c.decls);
  }
  for (final d in decls) {
    b
      ..writeln(d)
      ..writeln();
  }
  for (var i = 0; i < conformanceCorpus.length; i++) {
    b
      ..writeln('/// ${conformanceCorpus[i].name}')
      ..writeln('Object? ${conformanceFunctionName(i)}() {')
      ..writeln(conformanceCorpus[i].code)
      ..writeln('}')
      ..writeln();
  }
  return {'main.dart': b.toString()};
}

/// Compares a conformance result; returns the mismatches (empty = pass).
List<String> checkConformance(
  ConformanceCase c, {
  required String status,
  required Object? result,
  required String? errorType,
  required String? errorMessage,
  required List<String> logs,
  required Object? Function(String a1) valueOf,
}) {
  final problems = <String>[];
  if (c.error != null) {
    if (status != 'failed' && status != 'quotaExceeded') {
      problems.add('expected ${c.error} but status was $status ($result)');
    } else if (errorType != c.error) {
      problems.add('expected ${c.error} but got $errorType: $errorMessage');
    }
  } else {
    if (status != 'completed') {
      problems.add('failed: $errorType: $errorMessage');
    } else if (c.checkResult && !deepEquals(result, c.expect)) {
      problems.add('expected ${c.expect} but got $result');
    }
  }
  for (final e in c.cells.entries) {
    final v = valueOf(e.key);
    if (!deepEquals(v, e.value)) {
      problems.add('cell ${e.key}: expected ${e.value} but got $v');
    }
  }
  var from = 0;
  for (final l in c.logs) {
    final i = logs.indexOf(l, from);
    if (i < 0) {
      problems.add('log "$l" missing in $logs');
    } else {
      from = i + 1;
    }
  }
  return problems;
}

/// Deep equality of plain values (numbers compare by value).
bool deepEquals(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !deepEquals(a[k], b[k])) return false;
    }
    return true;
  }
  return a == b;
}
