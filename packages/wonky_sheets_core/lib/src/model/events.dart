import 'schema.dart';

/// Kinds of range-based rules indexed per sheet.
enum RuleKind {
  merge,
  conditionalFormat,
  dataValidation,
  protection,
  basicFilter,
  filterView,
  banding,
  object,
  pivot,
  group,
}

/// A cell key by ids.
typedef CellKey = ({String rowId, String colId});

/// One change notification of the [WorkbookModel] (02 §6, 13 §4.2).
sealed class WorkbookChangeEvent {
  const WorkbookChangeEvent();
}

/// Cell rows changed. [contentKeys] had their `content` changed; [formatKeys]
/// their format attributes; [noteKeys] their notes.
final class CellsChanged extends WorkbookChangeEvent {
  /// Creates the event.
  CellsChanged(
    this.sheetId, {
    Set<CellKey>? contentKeys,
    Set<CellKey>? formatKeys,
    Set<CellKey>? noteKeys,
  }) : contentKeys = contentKeys ?? {},
       formatKeys = formatKeys ?? {},
       noteKeys = noteKeys ?? {};

  final String sheetId;
  final Set<CellKey> contentKeys;
  final Set<CellKey> formatKeys;
  final Set<CellKey> noteKeys;

  /// All keys.
  Set<CellKey> get allKeys => {...contentKeys, ...formatKeys, ...noteKeys};

  @override
  String toString() =>
      'CellsChanged($sheetId, content: ${contentKeys.length}, format: ${formatKeys.length}, notes: ${noteKeys.length})';
}

/// Rows or columns were inserted, deleted, moved, resized or (un)hidden, or
/// their default format changed.
final class StructureChanged extends WorkbookChangeEvent {
  /// Creates the event.
  StructureChanged(
    this.sheetId,
    this.dimension, {
    this.order = false,
    this.sizes = false,
    this.formats = false,
  });

  final String sheetId;
  final Dimension dimension;

  /// Insert/delete/move (index mapping changed).
  bool order;

  /// Sizes or hidden flags changed.
  bool sizes;

  /// Row/column default formats changed.
  bool formats;

  @override
  String toString() =>
      'StructureChanged($sheetId, ${dimension.name}, order: $order, sizes: $sizes, formats: $formats)';
}

/// Sheets were added, removed, renamed, reordered or their properties changed.
final class SheetsChanged extends WorkbookChangeEvent {
  /// Creates the event.
  SheetsChanged(this.sheetIds, {this.orderOrNames = false});

  /// Affected sheets.
  final Set<String> sheetIds;

  /// Whether the sheet list order or names changed (formula `SheetNamesDep`).
  bool orderOrNames;

  @override
  String toString() => 'SheetsChanged($sheetIds, orderOrNames: $orderOrNames)';
}

/// Range rules of [kind] on [sheetId] changed.
final class RulesChanged extends WorkbookChangeEvent {
  /// Creates the event.
  RulesChanged(this.sheetId, this.kind, this.ruleIds);

  final String sheetId;
  final RuleKind kind;
  final Set<String> ruleIds;

  @override
  String toString() => 'RulesChanged($sheetId, ${kind.name}, $ruleIds)';
}

/// Named ranges / named functions changed (by name, lower case).
final class NamesChanged extends WorkbookChangeEvent {
  /// Creates the event.
  NamesChanged(this.names);

  final Set<String> names;

  @override
  String toString() => 'NamesChanged($names)';
}

/// The `Spreadsheet` row changed (title, locale, theme, calc settings…).
final class SpreadsheetChanged extends WorkbookChangeEvent {
  /// Creates the event.
  SpreadsheetChanged(this.columns);

  /// Changed column names.
  final Set<String> columns;

  @override
  String toString() => 'SpreadsheetChanged($columns)';
}

/// Rows of a table the model stores generically (scripts, …) changed.
final class OtherRowsChanged extends WorkbookChangeEvent {
  /// Creates the event.
  OtherRowsChanged(this.table, this.ids);

  final String table;
  final Set<String> ids;

  @override
  String toString() => 'OtherRowsChanged($table, $ids)';
}

/// The events of one ingestion batch (one plan, one remote merge, one load).
final class WorkbookChangeBatch {
  /// Creates a batch.
  const WorkbookChangeBatch(this.events);

  final List<WorkbookChangeEvent> events;

  /// Whether nothing changed.
  bool get isEmpty => events.isEmpty;

  /// Events of type [T].
  Iterable<T> whereType<T extends WorkbookChangeEvent>() =>
      events.whereType<T>();

  @override
  String toString() => 'WorkbookChangeBatch($events)';
}
