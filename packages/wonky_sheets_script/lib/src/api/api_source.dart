/// The Wonky Script API: the source of `package:wonky/wonky.dart`.
///
/// Scripts import this library. It is written in the dart_eval language
/// subset and compiled together with every script (09 §6). Every API object is
/// a small interpreted wrapper that forwards to the host through two bridge
/// functions (`wonkyHostCall`, `wonkyHostError` in `package:wonky/src/host.dart`,
/// registered by `WonkyScriptPlugin`). The host validates every call
/// (handles, roles, scopes, quotas), so nothing in this file is trusted.
///
/// Conventions (09 §6): row/column numbers are 1-based; 2-D data is
/// `List<List<Object?>>`; cell values are `null`, `num`, `String`, `bool`,
/// `DateTime` or [CellError].
///
/// dart_eval notes: no enums (constant classes instead, `.name` works), no
/// static setters, no `late`.
library;

/// Version of the script API; stored in `ScriptBuild.apiVersion` (09 §9.4).
const int wonkyApiVersion = 1;

/// Library URI of the API.
const String wonkyApiLibrary = 'package:wonky/wonky.dart';

/// Library URI of the host bridge functions.
const String wonkyHostLibrary = 'package:wonky/src/host.dart';

/// Source of `package:wonky/wonky.dart`.
const String wonkyApiSource = r'''
/// The Wonky Script API for Wonky Sheets.
library;

import 'package:wonky/src/host.dart';

export 'package:wonky/src/host.dart' show CellError;

// ---------------------------------------------------------------------------
// Host plumbing (not part of the documented API).
// ---------------------------------------------------------------------------

Object? _call(int target, String method, List<Object?> args) {
  final result = wonkyHostCall(target, method, args);
  if (result == null) {
    final error = wonkyHostError();
    if (error != null) {
      _throwHostError(error);
    }
  }
  return result;
}

void _throwHostError(List<Object?> error) {
  final code = error[0] as String;
  final message = error[1] as String;
  if (code == 'range') throw RangeException(message);
  if (code == 'permission_denied') throw PermissionDeniedException(message);
  if (code == 'scope_not_granted') throw ScopeNotGrantedException(message);
  if (code == 'ui_unavailable') throw UiUnavailableException(message);
  if (code == 'quota_exceeded') throw QuotaExceededException(message);
  if (code == 'offline') throw OfflineException(message);
  if (code == 'side_effect') throw CustomFunctionSideEffectException(message);
  if (code == 'url_fetch') {
    final status = error.length > 2 ? error[2] : null;
    throw UrlFetchException(message, status is int ? status : 0);
  }
  throw ScriptException(code, message);
}

List<List<Object?>> _grid(Object? value) => (value as List).cast<List<Object?>>();

List<List<String>> _stringGrid(Object? value) => (value as List).cast<List<String>>();

List<List<String?>> _nullableStringGrid(Object? value) => (value as List).cast<List<String?>>();

List<List<double>> _doubleGrid(Object? value) {
  final out = <List<double>>[];
  for (final row in value as List) {
    final r = <double>[];
    for (final v in row as List) {
      r.add((v as num).toDouble());
    }
    out.add(r);
  }
  return out;
}

List<Sheet> _sheets(Object? handles) {
  final out = <Sheet>[];
  for (final h in handles as List) {
    out.add(Sheet._(h as int));
  }
  return out;
}

Sheet? _sheetOrNull(Object? handle) => handle == null ? null : Sheet._(handle as int);

Range? _rangeOrNull(Object? handle) => handle == null ? null : Range._(handle as int);

User _user(Object? data) {
  final m = data as Map;
  return User._(m['id'] as String, m['email'] as String, m['name'] as String);
}

// ---------------------------------------------------------------------------
// Values and exceptions (09 §6.4, §6.13).
// ---------------------------------------------------------------------------

// `CellError` (a cell error value such as `#N/A`, with `code` and
// `message`) is a bridged class declared in package:wonky/src/host.dart and
// exported above.

/// Base class of every exception thrown by the API.
class ScriptException implements Exception {
  ScriptException(this.code, this.message);

  /// Machine-readable error code.
  final String code;

  /// Human-readable message.
  final String message;

  @override
  String toString() => 'ScriptException($code): $message';
}

/// Invalid A1 notation or out-of-bounds range.
class RangeException extends ScriptException {
  RangeException(String message) : super('range', message);
  @override
  String toString() => 'RangeException: $message';
}

/// The user's role or a protected range forbids the call.
class PermissionDeniedException extends ScriptException {
  PermissionDeniedException(String message) : super('permission_denied', message);
  @override
  String toString() => 'PermissionDeniedException: $message';
}

/// The project needs a scope the user has not authorized (09 §11).
class ScopeNotGrantedException extends ScriptException {
  ScopeNotGrantedException(String message) : super('scope_not_granted', message);
  @override
  String toString() => 'ScopeNotGrantedException: $message';
}

/// UI calls in server-side executions and custom functions.
class UiUnavailableException extends ScriptException {
  UiUnavailableException(String message) : super('ui_unavailable', message);
  @override
  String toString() => 'UiUnavailableException: $message';
}

/// A quota or limit was exceeded (09 §10).
class QuotaExceededException extends ScriptException {
  QuotaExceededException(String message) : super('quota_exceeded', message);
  @override
  String toString() => 'QuotaExceededException: $message';
}

/// A URL fetch failed or was blocked (09 §8.3).
class UrlFetchException extends ScriptException {
  UrlFetchException(String message, this.statusCode) : super('url_fetch', message);

  /// HTTP status code, or 0 when no response was received.
  final int statusCode;
  @override
  String toString() => 'UrlFetchException($statusCode): $message';
}

/// The call needs the server and the device is offline.
class OfflineException extends ScriptException {
  OfflineException(String message) : super('offline', message);
  @override
  String toString() => 'OfflineException: $message';
}

/// Custom functions may not change the spreadsheet or show UI (09 §8.6).
class CustomFunctionSideEffectException extends ScriptException {
  CustomFunctionSideEffectException(String message) : super('side_effect', message);
  @override
  String toString() => 'CustomFunctionSideEffectException: $message';
}

// ---------------------------------------------------------------------------
// SpreadsheetApp (09 §6.1).
// ---------------------------------------------------------------------------

/// Static entry point for the bound spreadsheet.
class SpreadsheetApp {
  /// The spreadsheet this script is bound to.
  static Spreadsheet get active => const Spreadsheet._();

  /// UI of the current user's window. Throws [UiUnavailableException] in
  /// server-side executions and in custom functions.
  static Ui get ui {
    _call(0, 'app.ui', const []);
    return const Ui._();
  }

  /// The active sheet of the user running the script (first visible sheet
  /// in server-side executions).
  static Sheet get activeSheet => Sheet._(_call(0, 'app.activeSheet', const []) as int);

  /// The active range (A1 of the active sheet in server-side executions).
  static Range get activeRange => Range._(_call(0, 'app.activeRange', const []) as int);

  /// All selected ranges.
  static List<Range> get activeRangeList {
    final out = <Range>[];
    for (final h in _call(0, 'app.activeRangeList', const []) as List) {
      out.add(Range._(h as int));
    }
    return out;
  }

  /// The current (cursor) cell, if any.
  static Range? get currentCell => _rangeOrNull(_call(0, 'app.currentCell', const []));

  /// Applies pending writes and recalculates formulas now.
  static void flush() {
    _call(0, 'app.flush', const []);
  }
}

// ---------------------------------------------------------------------------
// Spreadsheet (09 §6.2).
// ---------------------------------------------------------------------------

/// The bound spreadsheet.
class Spreadsheet {
  const Spreadsheet._();

  /// Spreadsheet (space) UUID.
  String get id => _call(0, 'ss.id', const []) as String;

  /// Title of the spreadsheet.
  String get name => _call(0, 'ss.name', const []) as String;
  set name(String value) {
    _call(0, 'ss.setName', [value]);
  }

  /// Link to the spreadsheet.
  String get url => _call(0, 'ss.url', const []) as String;

  /// Locale, e.g. `en_US`.
  String get locale => _call(0, 'ss.locale', const []) as String;
  set locale(String value) {
    _call(0, 'ss.setLocale', [value]);
  }

  /// IANA time zone, e.g. `Europe/Stockholm`.
  String get timeZone => _call(0, 'ss.timeZone', const []) as String;
  set timeZone(String value) {
    _call(0, 'ss.setTimeZone', [value]);
  }

  /// All sheets in tab order, including hidden ones.
  List<Sheet> get sheets => _sheets(_call(0, 'ss.sheets', const []));

  /// The sheet named [name] (case-insensitive), or null.
  Sheet? sheetByName(String name) => _sheetOrNull(_call(0, 'ss.sheetByName', [name]));

  /// The sheet with the id [id], or null.
  Sheet? sheetById(String id) => _sheetOrNull(_call(0, 'ss.sheetById', [id]));

  /// The active sheet (client only; the first visible sheet on the server).
  Sheet get activeSheet => Sheet._(_call(0, 'app.activeSheet', const []) as int);
  set activeSheet(Sheet sheet) {
    _call(0, 'ss.setActiveSheet', [sheet._h]);
  }

  /// Inserts a new sheet.
  Sheet insertSheet({String? name, int? index, Sheet? template}) =>
      Sheet._(_call(0, 'ss.insertSheet', [name, index, template == null ? null : template._h]) as int);

  /// Duplicates [sheet].
  Sheet duplicateSheet(Sheet sheet, {String? newName}) =>
      Sheet._(_call(0, 'ss.duplicateSheet', [sheet._h, newName]) as int);

  /// Deletes [sheet].
  void deleteSheet(Sheet sheet) {
    _call(0, 'ss.deleteSheet', [sheet._h]);
  }

  /// Moves [sheet] to the 1-based tab position [index].
  void moveSheet(Sheet sheet, int index) {
    _call(0, 'ss.moveSheet', [sheet._h, index]);
  }

  /// `Sheet1!A1:B10`, `A1` (active sheet) or a named range.
  Range getRange(String a1Notation) => Range._(_call(0, 'ss.getRange', [a1Notation]) as int);

  /// Several ranges at once.
  RangeList getRangeList(List<String> a1Notations) {
    final ranges = <Range>[];
    for (final a1 in a1Notations) {
      ranges.add(getRange(a1));
    }
    return RangeList._(ranges);
  }

  /// Named ranges of the spreadsheet.
  List<NamedRange> get namedRanges {
    final out = <NamedRange>[];
    for (final e in _call(0, 'ss.namedRanges', const []) as List) {
      final m = e as Map;
      out.add(NamedRange._(m['name'] as String, Range._(m['range'] as int)));
    }
    return out;
  }

  /// The range of the named range [name], or null.
  Range? getRangeByName(String name) => _rangeOrNull(_call(0, 'ss.getRangeByName', [name]));

  /// Creates or updates the named range [name].
  void setNamedRange(String name, Range range) {
    _call(0, 'ss.setNamedRange', [name, range._h]);
  }

  /// Removes the named range [name].
  void removeNamedRange(String name) {
    _call(0, 'ss.removeNamedRange', [name]);
  }

  /// Shows a toast in the windows of the running user.
  void toast(String message, {String? title, double timeoutSeconds = 5}) {
    _call(0, 'ss.toast', [message, title, timeoutSeconds]);
  }

  /// The owner of the spreadsheet.
  User get owner => _user(_call(0, 'ss.owner', const []));
}

// ---------------------------------------------------------------------------
// Sheet (09 §6.3).
// ---------------------------------------------------------------------------

/// A sheet (tab).
class Sheet {
  Sheet._(this._h);
  final int _h;

  /// Stable sheet id.
  String get id => _call(_h, 'sheet.id', const []) as String;

  /// Tab name.
  String get name => _call(_h, 'sheet.name', const []) as String;
  set name(String value) {
    _call(_h, 'sheet.setName', [value]);
  }

  /// 1-based tab position.
  int get index => _call(_h, 'sheet.index', const []) as int;

  /// Whether the sheet is hidden.
  bool get isHidden => _call(_h, 'sheet.isHidden', const []) as bool;

  /// Hides the sheet.
  void hide() {
    _call(_h, 'sheet.setHidden', [true]);
  }

  /// Shows the sheet.
  void show() {
    _call(_h, 'sheet.setHidden', [false]);
  }

  /// Tab color as `#RRGGBB`, or null.
  String? get tabColor => _call(_h, 'sheet.tabColor', const []) as String?;
  set tabColor(String? hex) {
    _call(_h, 'sheet.setTabColor', [hex]);
  }

  /// The spreadsheet.
  Spreadsheet get parent => const Spreadsheet._();

  /// A range in A1 notation: `A1:C10`, `B:B`, `3:3`.
  Range getRange(String a1Notation) => Range._(_call(_h, 'sheet.getRange', [a1Notation]) as int);

  /// A range by 1-based position.
  Range getRangeAt(int row, int column, [int numRows = 1, int numColumns = 1]) =>
      Range._(_call(_h, 'sheet.getRangeAt', [row, column, numRows, numColumns]) as int);

  /// A1 to (lastRow, lastColumn).
  Range get dataRange => Range._(_call(_h, 'sheet.dataRange', const []) as int);

  /// Last row with content (0 if empty).
  int get lastRow => _call(_h, 'sheet.lastRow', const []) as int;

  /// Last column with content (0 if empty).
  int get lastColumn => _call(_h, 'sheet.lastColumn', const []) as int;

  /// Number of rows of the grid.
  int get maxRows => _call(_h, 'sheet.maxRows', const []) as int;

  /// Number of columns of the grid.
  int get maxColumns => _call(_h, 'sheet.maxColumns', const []) as int;

  /// The selected range of this sheet (client only).
  Range? get activeRange => _rangeOrNull(_call(_h, 'sheet.activeRange', const []));

  /// Inserts [count] rows before [row].
  void insertRowsBefore(int row, int count) {
    _call(_h, 'sheet.insert', ['rows', row, count, true]);
  }

  /// Inserts [count] rows after [row].
  void insertRowsAfter(int row, int count) {
    _call(_h, 'sheet.insert', ['rows', row, count, false]);
  }

  /// Inserts [count] columns before [column].
  void insertColumnsBefore(int column, int count) {
    _call(_h, 'sheet.insert', ['columns', column, count, true]);
  }

  /// Inserts [count] columns after [column].
  void insertColumnsAfter(int column, int count) {
    _call(_h, 'sheet.insert', ['columns', column, count, false]);
  }

  /// Deletes rows.
  void deleteRows(int row, [int count = 1]) {
    _call(_h, 'sheet.delete', ['rows', row, count]);
  }

  /// Deletes columns.
  void deleteColumns(int column, [int count = 1]) {
    _call(_h, 'sheet.delete', ['columns', column, count]);
  }

  /// Hides rows.
  void hideRows(int row, [int count = 1]) {
    _call(_h, 'sheet.setDimHidden', ['rows', row, count, true]);
  }

  /// Shows rows.
  void showRows(int row, [int count = 1]) {
    _call(_h, 'sheet.setDimHidden', ['rows', row, count, false]);
  }

  /// Hides columns.
  void hideColumns(int column, [int count = 1]) {
    _call(_h, 'sheet.setDimHidden', ['columns', column, count, true]);
  }

  /// Shows columns.
  void showColumns(int column, [int count = 1]) {
    _call(_h, 'sheet.setDimHidden', ['columns', column, count, false]);
  }

  /// Sets the height of [row] in pixels.
  void setRowHeight(int row, double px) {
    _call(_h, 'sheet.resize', ['rows', row, 1, px]);
  }

  /// Sets the width of [column] in pixels.
  void setColumnWidth(int column, double px) {
    _call(_h, 'sheet.resize', ['columns', column, 1, px]);
  }

  /// Fits [count] columns starting at [startColumn] to their content.
  void autoResizeColumns(int startColumn, int count) {
    _call(_h, 'sheet.resize', ['columns', startColumn, count, null]);
  }

  /// Number of frozen rows.
  int get frozenRows => _call(_h, 'sheet.frozenRows', const []) as int;
  set frozenRows(int n) {
    _call(_h, 'sheet.setFrozen', [n, null]);
  }

  /// Number of frozen columns.
  int get frozenColumns => _call(_h, 'sheet.frozenColumns', const []) as int;
  set frozenColumns(int n) {
    _call(_h, 'sheet.setFrozen', [null, n]);
  }

  /// Appends a row after [lastRow]; grows the grid if needed.
  void appendRow(List<Object?> values) {
    _call(_h, 'sheet.appendRow', [values]);
  }

  /// Clears the sheet.
  void clear({bool contentsOnly = false, bool formatsOnly = false}) {
    _call(_h, 'sheet.clear', [contentsOnly, formatsOnly]);
  }

  /// Sorts the rows below the frozen rows by [column].
  void sort(int column, {bool ascending = true}) {
    _call(_h, 'sheet.sort', [column, ascending]);
  }
}

// ---------------------------------------------------------------------------
// Range (09 §6.4).
// ---------------------------------------------------------------------------

/// Sort key for [Range.sort].
class SortSpec {
  SortSpec({required this.column, this.ascending = true});

  /// 1-based column of the sheet.
  final int column;
  final bool ascending;
}

/// A rectangular range of cells. Ranges keep pointing at the same cells when
/// rows or columns are inserted before them.
class Range {
  Range._(this._h);
  final int _h;

  List<Object?> _geometry() => _call(_h, 'range.geometry', const []) as List<Object?>;

  /// The sheet of the range.
  Sheet get sheet => Sheet._(_call(_h, 'range.sheet', const []) as int);

  /// `B2:D10` (without the sheet name).
  String get a1Notation => _call(_h, 'range.a1', const []) as String;

  /// 1-based top row.
  int get row => _geometry()[0] as int;

  /// 1-based left column.
  int get column => _geometry()[1] as int;

  /// Number of rows.
  int get numRows => _geometry()[2] as int;

  /// Number of columns.
  int get numColumns => _geometry()[3] as int;

  /// 1-based bottom row.
  int get lastRow {
    final g = _geometry();
    return (g[0] as int) + (g[2] as int) - 1;
  }

  /// 1-based right column.
  int get lastColumn {
    final g = _geometry();
    return (g[1] as int) + (g[3] as int) - 1;
  }

  // ---- Values of the top-left cell ----

  /// Value of the top-left cell.
  Object? get value => _call(_h, 'range.value', const []);
  set value(Object? v) {
    _call(_h, 'range.setValue', [v]);
  }

  /// Formatted value of the top-left cell.
  String get displayValue => _call(_h, 'range.displayValue', const []) as String;

  /// Formula of the top-left cell in A1 notation (`""` when none).
  String get formula => _call(_h, 'range.formula', const []) as String;
  set formula(String a1Formula) {
    _call(_h, 'range.setFormula', [a1Formula]);
  }

  /// Note of the top-left cell.
  String? get note => _call(_h, 'range.note', const []) as String?;
  set note(String? text) {
    _call(_h, 'range.setNote', [text]);
  }

  // ---- 2-D data ----

  /// Values, row-major.
  List<List<Object?>> get values => _grid(_call(_h, 'range.values', const []));
  set values(List<List<Object?>> v) {
    _call(_h, 'range.setValues', [v, false]);
  }

  /// Formatted values.
  List<List<String>> get displayValues => _stringGrid(_call(_h, 'range.displayValues', const []));

  /// Formulas in A1 notation (`""` for cells without one).
  List<List<String>> get formulas => _stringGrid(_call(_h, 'range.formulas', const []));
  set formulas(List<List<String>> f) {
    _call(_h, 'range.setFormulas', [f]);
  }

  /// Notes.
  List<List<String?>> get notes => _nullableStringGrid(_call(_h, 'range.notes', const []));
  set notes(List<List<String?>> n) {
    _call(_h, 'range.setNotes', [n]);
  }

  /// Same as the [values] setter.
  void setValues(List<List<Object?>> values) {
    _call(_h, 'range.setValues', [values, false]);
  }

  /// Writes values without parsing strings as formulas or numbers.
  void setValuesRaw(List<List<Object?>> values) {
    _call(_h, 'range.setValues', [values, true]);
  }

  // ---- Formats ----

  /// Number format patterns.
  List<List<String?>> get numberFormats => _nullableStringGrid(_call(_h, 'range.formats', ['numberFormat']));
  set numberFormat(String pattern) {
    _call(_h, 'range.setFormat', ['numberFormat', pattern]);
  }

  /// Sets number formats per cell.
  void setNumberFormats(List<List<String?>> patterns) {
    _call(_h, 'range.setFormats', ['numberFormat', patterns]);
  }

  /// Background colors (`#RRGGBB` or null).
  List<List<String?>> get backgrounds => _nullableStringGrid(_call(_h, 'range.formats', ['background']));
  set background(String? color) {
    _call(_h, 'range.setFormat', ['background', color]);
  }

  /// Sets backgrounds per cell.
  void setBackgrounds(List<List<String?>> colors) {
    _call(_h, 'range.setFormats', ['background', colors]);
  }

  /// Font colors.
  List<List<String?>> get fontColors => _nullableStringGrid(_call(_h, 'range.formats', ['fontColor']));
  set fontColor(String? color) {
    _call(_h, 'range.setFormat', ['fontColor', color]);
  }

  /// Sets font colors per cell.
  void setFontColors(List<List<String?>> colors) {
    _call(_h, 'range.setFormats', ['fontColor', colors]);
  }

  /// `bold` or `normal`.
  List<List<String>> get fontWeights => _stringGrid(_call(_h, 'range.formats', ['fontWeight']));
  set fontWeight(String weight) {
    _call(_h, 'range.setFormat', ['fontWeight', weight]);
  }

  /// `italic` or `normal`.
  List<List<String>> get fontStyles => _stringGrid(_call(_h, 'range.formats', ['fontStyle']));
  set fontStyle(String style) {
    _call(_h, 'range.setFormat', ['fontStyle', style]);
  }

  /// Font families.
  List<List<String>> get fontFamilies => _stringGrid(_call(_h, 'range.formats', ['fontFamily']));
  set fontFamily(String family) {
    _call(_h, 'range.setFormat', ['fontFamily', family]);
  }

  /// Font sizes in points.
  List<List<double>> get fontSizes => _doubleGrid(_call(_h, 'range.formats', ['fontSize']));
  set fontSize(double size) {
    _call(_h, 'range.setFormat', ['fontSize', size]);
  }

  /// `left`, `center`, `right` or `general`.
  List<List<String>> get horizontalAlignments => _stringGrid(_call(_h, 'range.formats', ['horizontalAlignment']));
  set horizontalAlignment(String a) {
    _call(_h, 'range.setFormat', ['horizontalAlignment', a]);
  }

  /// `top`, `middle` or `bottom`.
  List<List<String>> get verticalAlignments => _stringGrid(_call(_h, 'range.formats', ['verticalAlignment']));
  set verticalAlignment(String a) {
    _call(_h, 'range.setFormat', ['verticalAlignment', a]);
  }

  /// `overflow`, `wrap` or `clip`.
  set wrapStrategy(String s) {
    _call(_h, 'range.setFormat', ['wrapStrategy', s]);
  }

  /// `none`, `underline` or `lineThrough`.
  set textDecoration(String d) {
    _call(_h, 'range.setFormat', ['textDecoration', d]);
  }

  /// Sets borders; `null` leaves a side unchanged, `false` removes it.
  void setBorder({bool? top, bool? left, bool? bottom, bool? right, bool? vertical,
      bool? horizontal, String? color, String style = 'thin'}) {
    _call(_h, 'range.setBorder', [top, left, bottom, right, vertical, horizontal, color, style]);
  }

  // ---- Operations ----

  /// Clears contents, formats and notes (or only some of them).
  void clear({bool contentsOnly = false, bool formatsOnly = false, bool notesOnly = false}) {
    _call(_h, 'range.clear', [contentsOnly, formatsOnly, notesOnly]);
  }

  /// Clears contents, keeps formats.
  void clearContent() {
    _call(_h, 'range.clear', [true, false, false]);
  }

  /// Clears formats, keeps contents.
  void clearFormat() {
    _call(_h, 'range.clear', [false, true, false]);
  }

  /// Merges all cells.
  void merge() {
    _call(_h, 'range.merge', ['all']);
  }

  /// Merges each row.
  void mergeAcross() {
    _call(_h, 'range.merge', ['horizontal']);
  }

  /// Merges each column.
  void mergeVertically() {
    _call(_h, 'range.merge', ['vertical']);
  }

  /// Unmerges.
  void breakApart() {
    _call(_h, 'range.breakApart', const []);
  }

  /// Whether the range is part of a merge.
  bool get isMerged => _call(_h, 'range.isMerged', const []) as bool;

  /// Whether every cell is empty.
  bool get isBlank => _call(_h, 'range.isBlank', const []) as bool;

  /// Sorts the rows of the range.
  void sort(List<SortSpec> specs) {
    final keys = <Object?>[];
    for (final s in specs) {
      keys.add([s.column, s.ascending]);
    }
    _call(_h, 'range.sort', [keys]);
  }

  /// Copies to [destination] (its top-left cell).
  void copyTo(Range destination, {bool contentsOnly = false, bool formatsOnly = false}) {
    _call(_h, 'range.copyTo', [destination._h, contentsOnly, formatsOnly]);
  }

  /// Moves to [destination] (its top-left cell).
  void moveTo(Range destination) {
    _call(_h, 'range.moveTo', [destination._h]);
  }

  /// A range offset from this one.
  Range offset(int rowOffset, int columnOffset, [int? numRows, int? numColumns]) =>
      Range._(_call(_h, 'range.offset', [rowOffset, columnOffset, numRows, numColumns]) as int);

  /// The cell at the 1-based [row]/[column] relative to this range.
  Range cell(int row, int column) => Range._(_call(_h, 'range.cell', [row, column]) as int);

  /// Selects the range in the UI (client only).
  Range activate() {
    _call(_h, 'range.activate', const []);
    return this;
  }

  /// Turns the cells into checkboxes.
  void insertCheckboxes() {
    _call(_h, 'range.checkboxes', [true]);
  }

  /// Removes checkboxes.
  void removeCheckboxes() {
    _call(_h, 'range.checkboxes', [false]);
  }

  /// Trims whitespace in the cells.
  Range trimWhitespace() {
    _call(_h, 'range.trimWhitespace', const []);
    return this;
  }

  /// Removes duplicate rows; returns the resulting range.
  Range removeDuplicates([List<int>? columnsToCompare]) =>
      Range._(_call(_h, 'range.removeDuplicates', [columnsToCompare]) as int);
}

/// Several ranges.
class RangeList {
  RangeList._(this.ranges);

  /// The ranges.
  final List<Range> ranges;

  /// Clears every range.
  void clear() {
    for (final r in ranges) {
      r.clear();
    }
  }

  /// Sets the background of every range.
  set background(String? color) {
    for (final r in ranges) {
      r.background = color;
    }
  }

  /// Sets the font weight of every range.
  set fontWeight(String weight) {
    for (final r in ranges) {
      r.fontWeight = weight;
    }
  }
}

/// A named range.
class NamedRange {
  NamedRange._(this.name, this.range);

  /// Name of the range.
  final String name;

  /// The range.
  final Range range;

  /// Removes the named range.
  void remove() {
    _call(0, 'ss.removeNamedRange', [name]);
  }
}

// ---------------------------------------------------------------------------
// Ui and menus (09 §6.5, §16).
// ---------------------------------------------------------------------------

/// Buttons of an alert or prompt.
class ButtonSet {
  const ButtonSet._(this.name);
  final String name;
  static const ButtonSet ok = ButtonSet._('ok');
  static const ButtonSet okCancel = ButtonSet._('okCancel');
  static const ButtonSet yesNo = ButtonSet._('yesNo');
  static const ButtonSet yesNoCancel = ButtonSet._('yesNoCancel');
  @override
  String toString() => 'ButtonSet.$name';
}

/// A dialog button.
class Button {
  const Button._(this.name);
  final String name;
  static const Button ok = Button._('ok');
  static const Button cancel = Button._('cancel');
  static const Button yes = Button._('yes');
  static const Button no = Button._('no');
  static const Button close = Button._('close');
  @override
  String toString() => 'Button.$name';
}

Button _button(Object? name) {
  if (name == 'ok') return Button.ok;
  if (name == 'cancel') return Button.cancel;
  if (name == 'yes') return Button.yes;
  if (name == 'no') return Button.no;
  return Button.close;
}

/// The answer to [Ui.prompt].
class PromptResponse {
  PromptResponse._(this.selectedButton, this.responseText);
  final Button selectedButton;
  final String responseText;
}

/// UI of the user's window.
class Ui {
  const Ui._();

  /// Shows a modal alert and waits until it is dismissed.
  Button alert(String message, {String? title, ButtonSet buttons = ButtonSet.ok}) =>
      _button(_call(0, 'ui.alert', [message, title, buttons.name]));

  /// Shows a prompt with a text field.
  PromptResponse prompt(String message, {String? title, ButtonSet buttons = ButtonSet.okCancel}) {
    final r = _call(0, 'ui.prompt', [message, title, buttons.name]) as List;
    return PromptResponse._(_button(r[0]), r[1] as String);
  }

  /// Starts a custom menu.
  Menu createMenu(String caption) => Menu._(caption);
}

/// A custom menu (built in `onOpen`).
class Menu {
  Menu._(this.caption);
  final String caption;
  final List<Object?> _items = <Object?>[];

  /// Adds an item that runs [functionName].
  Menu addItem(String caption, String functionName) {
    _items.add({'caption': caption, 'functionName': functionName});
    return this;
  }

  /// Adds a separator.
  Menu addSeparator() {
    _items.add({'separator': true});
    return this;
  }

  /// Adds a sub menu.
  Menu addSubMenu(Menu menu) {
    _items.add(menu._tree());
    return this;
  }

  Map<String, Object?> _tree() => {'caption': caption, 'items': _items};

  /// Adds the menu to the menubar for this window.
  void addToUi() {
    _call(0, 'ui.addMenu', [_tree()]);
  }
}

// ---------------------------------------------------------------------------
// Session and users (09 §6.6).
// ---------------------------------------------------------------------------

/// A user.
class User {
  User._(this.id, this.email, this.name);
  final String id;

  /// Requires the `user.email` scope; `""` without it.
  final String email;
  final String name;
}

/// Information about the running user and the script.
class Session {
  /// The person running (or triggering) the script.
  static User get activeUser => _user(_call(0, 'session.activeUser', const []));

  /// The run-as user (installer for installable triggers).
  static User get effectiveUser => _user(_call(0, 'session.effectiveUser', const []));

  /// Time zone of the project (defaults to the spreadsheet's).
  static String get scriptTimeZone => _call(0, 'session.scriptTimeZone', const []) as String;

  /// Locale of the active user.
  static String get activeUserLocale => _call(0, 'session.activeUserLocale', const []) as String;
}

// ---------------------------------------------------------------------------
// UrlFetchApp (09 §6.7, §8.3).
// ---------------------------------------------------------------------------

/// Options of [UrlFetchApp.fetch].
class FetchOptions {
  FetchOptions({this.method = 'get', this.headers, this.payload, this.contentType,
      this.followRedirects = true, this.muteHttpExceptions = false, this.timeoutSeconds = 30});
  final String method;
  final Map<String, String>? headers;
  final String? payload;
  final String? contentType;
  final bool followRedirects;
  final bool muteHttpExceptions;
  final int timeoutSeconds;

  Map<String, Object?> _toMap() => {
        'method': method,
        'headers': headers,
        'payload': payload,
        'contentType': contentType,
        'followRedirects': followRedirects,
        'muteHttpExceptions': muteHttpExceptions,
        'timeoutSeconds': timeoutSeconds,
      };
}

/// One request of [UrlFetchApp.fetchAll].
class FetchRequest {
  FetchRequest(this.url, [this.options]);
  final String url;
  final FetchOptions? options;
}

/// An HTTP response.
class HttpResponse {
  HttpResponse._(this.statusCode, this.headers, this.contentText, this.bytes);

  final int statusCode;
  final Map<String, String> headers;

  /// Body decoded as text (UTF-8 unless the charset says otherwise).
  final String contentText;

  /// Raw body.
  final List<int> bytes;

  /// The body decoded as JSON.
  Object? json() => Utilities.jsonDecode(contentText);
}

HttpResponse _response(Object? data) {
  final m = data as Map;
  final headers = <String, String>{};
  final h = m['headers'] as Map;
  for (final k in h.keys) {
    headers[k as String] = h[k] as String;
  }
  final bytes = <int>[];
  for (final b in m['bytes'] as List) {
    bytes.add(b as int);
  }
  return HttpResponse._(m['statusCode'] as int, headers, m['contentText'] as String, bytes);
}

/// HTTP requests through the Wonky server proxy.
class UrlFetchApp {
  /// Fetches [url]. Throws [UrlFetchException] for failed requests and HTTP
  /// errors (unless `muteHttpExceptions`).
  static HttpResponse fetch(String url, [FetchOptions? options]) =>
      _response(_call(0, 'fetch.fetch', [url, options == null ? null : options._toMap()]));

  /// Fetches up to 20 requests in parallel.
  static List<HttpResponse> fetchAll(List<FetchRequest> requests) {
    final list = <Object?>[];
    for (final r in requests) {
      list.add([r.url, r.options == null ? null : r.options!._toMap()]);
    }
    final out = <HttpResponse>[];
    for (final r in _call(0, 'fetch.fetchAll', [list]) as List) {
      out.add(_response(r));
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Utilities and Logger (09 §6.8).
// ---------------------------------------------------------------------------

/// Helpers.
class Utilities {
  /// Formats [date] with a spreadsheet number format pattern (`yyyy-mm-dd`).
  static String formatDate(DateTime date, String timeZone, String pattern) =>
      _call(0, 'util.formatDate', [date, timeZone, pattern]) as String;

  /// Parses [text] as a date in [timeZone].
  static DateTime parseDate(String text, String timeZone, String pattern) =>
      _call(0, 'util.parseDate', [text, timeZone, pattern]) as DateTime;

  /// Waits (≤ 5,000 ms per call; counts toward the time limit).
  static void sleep(int milliseconds) {
    _call(0, 'util.sleep', [milliseconds]);
  }

  /// A random UUID (v4).
  static String uuid() => _call(0, 'util.uuid', const []) as String;

  /// Base64-encodes [bytes].
  static String base64Encode(List<int> bytes) => _call(0, 'util.base64Encode', [bytes]) as String;

  /// Decodes base64 [text].
  static List<int> base64Decode(String text) {
    final out = <int>[];
    for (final b in _call(0, 'util.base64Decode', [text]) as List) {
      out.add(b as int);
    }
    return out;
  }

  /// Hex digest (`md5`, `sha1`, `sha256`, `sha512`) of the UTF-8 [value].
  static String computeDigest(String algorithm, String value) =>
      _call(0, 'util.digest', [algorithm, value]) as String;

  /// Hex HMAC (`sha256`, `sha512`).
  static String computeHmac(String algorithm, String value, String key) =>
      _call(0, 'util.hmac', [algorithm, value, key]) as String;

  /// Encodes [value] as JSON.
  static String jsonEncode(Object? value) => _call(0, 'util.jsonEncode', [value]) as String;

  /// Decodes JSON [text].
  static Object? jsonDecode(String text) => _call(0, 'util.jsonDecode', [text]);

  /// printf-like formatting: `%s`, `%d`, `%.2f`.
  static String formatString(String template, List<Object?> args) =>
      _call(0, 'util.formatString', [template, args]) as String;
}

/// Execution log (also shown in the editor console).
class Logger {
  static void log(Object? message) {
    wonkyHostCall(0, 'log', ['info', '$message']);
  }

  static void info(Object? message) {
    wonkyHostCall(0, 'log', ['info', '$message']);
  }

  static void warn(Object? message) {
    wonkyHostCall(0, 'log', ['warn', '$message']);
  }

  static void error(Object? message) {
    wonkyHostCall(0, 'log', ['error', '$message']);
  }
}

// ---------------------------------------------------------------------------
// PropertiesService (09 §6.9).
// ---------------------------------------------------------------------------

/// Script properties.
class PropertiesService {
  /// Shared by everyone with access to the spreadsheet.
  static Properties get documentProperties => const Properties._('document');

  /// Per user per spreadsheet.
  static Properties get userProperties => const Properties._('user');
}

/// A property store.
class Properties {
  const Properties._(this._scope);
  final String _scope;

  /// The value of [key], or null.
  String? getProperty(String key) => _call(0, 'props.get', [_scope, key]) as String?;

  /// Sets [key] (value ≤ 9 KB; store ≤ 500 KB).
  void setProperty(String key, String value) {
    _call(0, 'props.set', [_scope, key, value]);
  }

  /// Deletes [key].
  void deleteProperty(String key) {
    _call(0, 'props.delete', [_scope, key]);
  }

  /// All properties.
  Map<String, String> getProperties() {
    final m = _call(0, 'props.all', [_scope]) as Map;
    final out = <String, String>{};
    for (final k in m.keys) {
      out[k as String] = m[k] as String;
    }
    return out;
  }

  /// Sets several properties.
  void setProperties(Map<String, String> values, {bool deleteAllOthers = false}) {
    _call(0, 'props.setAll', [_scope, values, deleteAllOthers]);
  }

  /// All keys.
  List<String> get keys {
    final out = <String>[];
    for (final k in _call(0, 'props.keys', [_scope]) as List) {
      out.add(k as String);
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Event objects (09 §6.10). Built by the generated dispatcher.
// ---------------------------------------------------------------------------

/// Authorization mode of a simple trigger.
class AuthMode {
  const AuthMode._(this.name);
  final String name;
  static const AuthMode limited = AuthMode._('limited');
  static const AuthMode full = AuthMode._('full');
  @override
  String toString() => 'AuthMode.$name';
}

/// Event of `onOpen`.
class OpenEvent {
  OpenEvent._(this.user, this.authMode);
  Spreadsheet get source => const Spreadsheet._();
  final User user;
  final AuthMode authMode;
}

/// Event of `onEdit` (simple and installable).
class EditEvent {
  EditEvent._(this.range, this.user, this.value, this.oldValue, this.triggerUid, this.offline);
  Spreadsheet get source => const Spreadsheet._();

  /// Bounding box of the changed cells on the first changed sheet.
  final Range range;
  final User user;

  /// New value (single-cell edits only).
  final Object? value;

  /// Previous value (single-cell edits only).
  final Object? oldValue;

  /// Installable triggers only.
  final String? triggerUid;

  /// The edit was made offline and synced later.
  final bool offline;
}

/// Event of `onSelectionChange`.
class SelectionChangeEvent {
  SelectionChangeEvent._(this.range, this.user);
  Spreadsheet get source => const Spreadsheet._();
  final Range range;
  final User user;
}

/// Event of `onChange`.
class ChangeEvent {
  ChangeEvent._(this.user, this.changeType);
  Spreadsheet get source => const Spreadsheet._();
  final User user;

  /// EDIT, INSERT_ROW, INSERT_COLUMN, REMOVE_ROW, REMOVE_COLUMN, INSERT_GRID,
  /// REMOVE_GRID, FORMAT or OTHER.
  final String changeType;
}

/// Event of a time-driven trigger.
class TimeEvent {
  TimeEvent._(this.triggerUid, this.scheduledAt, this.firedAt);
  final String triggerUid;
  final DateTime scheduledAt;
  final DateTime firedAt;
}

/// Builds the event object of an invocation (used by the generated
/// dispatcher; not part of the documented API).
Object? wonkyEvent(Map<String, Object?>? e) {
  if (e == null) return null;
  final kind = e['kind'];
  final user = _user(e['user']);
  if (kind == 'open') {
    return OpenEvent._(user, e['authMode'] == 'limited' ? AuthMode.limited : AuthMode.full);
  }
  if (kind == 'edit') {
    return EditEvent._(Range._(e['range'] as int), user, e['value'], e['oldValue'],
        e['triggerUid'] as String?, e['offline'] == true);
  }
  if (kind == 'selectionChange') {
    return SelectionChangeEvent._(Range._(e['range'] as int), user);
  }
  if (kind == 'change') {
    return ChangeEvent._(user, e['changeType'] as String);
  }
  return TimeEvent._(e['triggerUid'] as String, e['scheduledAt'] as DateTime, e['firedAt'] as DateTime);
}

// ---------------------------------------------------------------------------
// Triggers (09 §6.11).
// ---------------------------------------------------------------------------

/// An installable trigger.
class Trigger {
  Trigger._(this.uid, this.functionName, this.eventType);
  final String uid;
  final String functionName;

  /// `timeDriven`, `onEdit`, `onChange` or `installableOnOpen`.
  final String eventType;
}

Trigger _trigger(Object? data) {
  final m = data as Map;
  return Trigger._(m['uid'] as String, m['functionName'] as String, m['eventType'] as String);
}

/// Installable triggers of the current user (scope `script.triggers`).
class ScriptApp {
  /// Starts building a trigger for [functionName].
  static TriggerBuilder newTrigger(String functionName) => TriggerBuilder._(functionName);

  /// The current user's triggers of this spreadsheet.
  static List<Trigger> get projectTriggers {
    final out = <Trigger>[];
    for (final t in _call(0, 'triggers.list', const []) as List) {
      out.add(_trigger(t));
    }
    return out;
  }

  /// Deletes [trigger].
  static void deleteTrigger(Trigger trigger) {
    _call(0, 'triggers.delete', [trigger.uid]);
  }
}

/// Builder of [Trigger]s.
class TriggerBuilder {
  TriggerBuilder._(this._functionName);
  final String _functionName;

  /// A time-driven trigger.
  TimeTriggerBuilder timeBased() => TimeTriggerBuilder._(_functionName);

  /// A trigger on spreadsheet events.
  SpreadsheetTriggerBuilder forSpreadsheet() => SpreadsheetTriggerBuilder._(_functionName);
}

/// Builder of time-driven triggers.
class TimeTriggerBuilder {
  TimeTriggerBuilder._(this._functionName);
  final String _functionName;
  final Map<String, Object?> _schedule = <String, Object?>{};

  TimeTriggerBuilder everyMinutes(int n) {
    _schedule['type'] = 'minutes';
    _schedule['interval'] = n;
    return this;
  }

  TimeTriggerBuilder everyHours(int n) {
    _schedule['type'] = 'hours';
    _schedule['interval'] = n;
    return this;
  }

  TimeTriggerBuilder everyDays(int n) {
    _schedule['type'] = 'days';
    _schedule['interval'] = n;
    return this;
  }

  TimeTriggerBuilder everyWeeks(int n) {
    _schedule['type'] = 'weeks';
    _schedule['interval'] = n;
    return this;
  }

  /// Hour of the day 0–23 (±15 min jitter).
  TimeTriggerBuilder atHour(int hour) {
    _schedule['atHour'] = hour;
    return this;
  }

  /// `DateTime.monday` … `DateTime.sunday`.
  TimeTriggerBuilder onWeekDay(int weekday) {
    _schedule['weekday'] = weekday;
    return this;
  }

  TimeTriggerBuilder onMonthDay(int day) {
    _schedule['type'] = 'monthly';
    _schedule['monthDay'] = day;
    return this;
  }

  /// A one-shot trigger.
  TimeTriggerBuilder at(DateTime when) {
    _schedule['type'] = 'once';
    _schedule['at'] = when;
    return this;
  }

  /// Creates the trigger.
  Trigger create() =>
      _trigger(_call(0, 'triggers.create', [_functionName, 'timeDriven', _schedule]));
}

/// Builder of spreadsheet triggers.
class SpreadsheetTriggerBuilder {
  SpreadsheetTriggerBuilder._(this._functionName);
  final String _functionName;
  String _event = 'onEdit';

  SpreadsheetTriggerBuilder onEdit() {
    _event = 'onEdit';
    return this;
  }

  SpreadsheetTriggerBuilder onChange() {
    _event = 'onChange';
    return this;
  }

  SpreadsheetTriggerBuilder onOpen() {
    _event = 'installableOnOpen';
    return this;
  }

  /// Creates the trigger.
  Trigger create() => _trigger(_call(0, 'triggers.create', [_functionName, _event, null]));
}
''';
