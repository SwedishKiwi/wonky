import '../addressing/grid_geometry.dart';
import '../content/cell_content.dart';
import '../format/attributes.dart';
import '../format/borders.dart';
import '../model/grid_range.dart';
import '../model/schema.dart';

/// A user operation the [SheetsMutationPlanner] turns into a [MutationPlan]
/// (13 §4.1). Commands (UI), MCP tools and scripts construct these; ranges are
/// already resolved (`WorkbookModel.parseA1` for A1 input).
sealed class SheetsOperation {
  const SheetsOperation();
}

// =============================================================================
// Values

/// One input value of [SetCellInputs].
sealed class CellInput {
  const CellInput();

  /// User-entered text, parsed like typing (`=formulas`, numbers, dates, `'text`).
  const factory CellInput.user(String text) = UserCellInput;

  /// A raw value: strings stay text, numbers stay numbers, null clears (MCP `raw`).
  const factory CellInput.raw(Object? value) = RawCellInput;

  /// Exact content (already encoded semantics).
  const factory CellInput.content(CellContent? content) = ContentCellInput;
}

/// User-entered text.
final class UserCellInput extends CellInput {
  /// Creates the input.
  const UserCellInput(this.text);

  /// The text.
  final String text;
}

/// A raw value.
final class RawCellInput extends CellInput {
  /// Creates the input.
  const RawCellInput(this.value);

  /// `num`, `String`, `bool`, `null` or a [CellValue].
  final Object? value;
}

/// Exact content.
final class ContentCellInput extends CellInput {
  /// Creates the input.
  const ContentCellInput(this.content);

  /// Content; null clears the value.
  final CellContent? content;
}

/// Writes values into a block whose top-left is ([row], [col]) (typing,
/// `sheets.cell.setInput`, MCP `set_values`). Formats are kept; Automatic cells
/// get auto-detected number formats (06 §5.9).
final class SetCellInputs extends SheetsOperation {
  /// Creates the operation.
  const SetCellInputs({
    required this.sheetId,
    required this.row,
    required this.col,
    required this.inputs,
    this.parseLocale,
    this.growGrid = false,
    this.label,
  });

  final String sheetId;
  final int row;
  final int col;

  /// Rows of inputs (ragged rows allowed).
  final List<List<CellInput>> inputs;

  /// Locale for parsing user input (default: spreadsheet locale).
  final String? parseLocale;

  /// Whether rows/columns are appended when the block exceeds the grid.
  final bool growGrid;

  /// Undo label override.
  final String? label;
}

/// What [ClearRanges] clears.
enum ClearWhat { contents, formats, all, notes, validation, links }

/// Clears contents/formats/notes/validation of ranges (Delete key, Edit ›
/// Delete values, clear formatting via [ClearWhat.formats], MCP `clear_range`).
final class ClearRanges extends SheetsOperation {
  /// Creates the operation.
  const ClearRanges(this.ranges, {this.what = ClearWhat.contents});

  final List<ResolvedRange> ranges;
  final ClearWhat what;
}

/// Sets or removes the note of one cell.
final class SetNote extends SheetsOperation {
  /// Creates the operation.
  const SetNote(this.sheetId, this.row, this.col, this.note);

  final String sheetId;
  final int row;
  final int col;

  /// New note; null removes it.
  final String? note;
}

/// Sets (or removes with null) the whole-cell link of ranges; with [text], the
/// single target cell also gets that text (Insert link).
final class SetLink extends SheetsOperation {
  /// Creates the operation.
  const SetLink(this.ranges, this.url, {this.text});

  final List<ResolvedRange> ranges;
  final String? url;
  final String? text;
}

/// Restores a cell value from history (`sheets.history.restoreCellValue`).
final class RestoreCellValue extends SheetsOperation {
  /// Creates the operation.
  const RestoreCellValue(this.sheetId, this.rowId, this.colId, this.content);

  final String sheetId;
  final String rowId;
  final String colId;
  final String? content;
}

// =============================================================================
// Formatting

/// Sets format attributes on ranges with the row/column/sheet strategies of
/// 06 §1.3 (null values reset to inherit).
final class SetFormat extends SheetsOperation {
  /// Creates the operation.
  const SetFormat(this.ranges, this.values, {this.label});

  final List<ResolvedRange> ranges;
  final Map<FormatAttr, Object?> values;
  final String? label;
}

/// Toggles a boolean attribute (bold, italic, underline, strikethrough) with
/// the all-true rule of 06 §1.4.
final class ToggleFormat extends SheetsOperation {
  /// Creates the operation.
  const ToggleFormat(this.ranges, this.attr);

  final List<ResolvedRange> ranges;
  final FormatAttr attr;
}

/// Applies a border preset (06 §8.3).
final class SetBorders extends SheetsOperation {
  /// Creates the operation.
  const SetBorders(
    this.ranges,
    this.preset, {
    this.style = BorderStyle.thin,
    this.color = 'auto',
  });

  final List<ResolvedRange> ranges;
  final BorderPreset preset;
  final BorderStyle style;
  final String color;
}

/// Clear formatting (06 §3): all attributes except links, rich runs reduced to
/// link runs.
final class ClearFormatting extends SheetsOperation {
  /// Creates the operation.
  const ClearFormatting(this.ranges);

  final List<ResolvedRange> ranges;
}

/// Increase/decrease decimals (06 §5.10).
final class AdjustDecimals extends SheetsOperation {
  /// Creates the operation.
  const AdjustDecimals(this.ranges, this.delta, {this.active});

  final List<ResolvedRange> ranges;

  /// +1 increase, −1 decrease.
  final int delta;

  /// The active cell; Automatic cells derive their decimals from its value
  /// (06 §5.10). Null: the first number among the Automatic cells.
  final (String sheetId, int row, int col)? active;
}

/// Increase/decrease font size per cell (06 §6.2).
final class StepFontSize extends SheetsOperation {
  /// Creates the operation.
  const StepFontSize(this.ranges, {required this.increase});

  final List<ResolvedRange> ranges;
  final bool increase;
}

/// Merge modes (06 §10).
enum MergeMode { all, horizontal, vertical }

/// Merges ranges. Without [force], content in cells other than the kept ones
/// throws `PlanException('merge_data_loss')` so the UI can confirm.
final class MergeCells extends SheetsOperation {
  /// Creates the operation.
  const MergeCells(
    this.ranges, {
    this.mode = MergeMode.all,
    this.force = false,
  });

  final List<ResolvedRange> ranges;
  final MergeMode mode;
  final bool force;
}

/// Removes merges intersecting the ranges.
final class UnmergeCells extends SheetsOperation {
  /// Creates the operation.
  const UnmergeCells(this.ranges);

  final List<ResolvedRange> ranges;
}

// =============================================================================
// Structure

/// Which neighbour new rows/columns inherit formats from.
enum InheritFrom { before, after, none }

/// Inserts [count] rows/columns before index [at] (03 §13.1).
final class InsertDimension extends SheetsOperation {
  /// Creates the operation.
  const InsertDimension(
    this.sheetId,
    this.dimension,
    this.at,
    this.count, {
    this.inheritFrom = InheritFrom.before,
  });

  final String sheetId;
  final Dimension dimension;

  /// Index before which to insert (= length appends).
  final int at;
  final int count;
  final InheritFrom inheritFrom;
}

/// Deletes rows/columns with boundary repair (03 §13.2).
final class DeleteDimension extends SheetsOperation {
  /// Creates the operation.
  const DeleteDimension(this.sheetId, this.dimension, this.ids);

  final String sheetId;
  final Dimension dimension;
  final List<String> ids;
}

/// Moves rows/columns before [beforeId] (null = to the end) (03 §13.4).
final class MoveDimension extends SheetsOperation {
  /// Creates the operation.
  const MoveDimension(this.sheetId, this.dimension, this.ids, this.beforeId);

  final String sheetId;
  final Dimension dimension;
  final List<String> ids;
  final String? beforeId;
}

/// Hides/unhides rows/columns (03 §13.5).
final class SetDimensionHidden extends SheetsOperation {
  /// Creates the operation.
  const SetDimensionHidden(
    this.sheetId,
    this.dimension,
    this.ids, {
    required this.hidden,
  });

  final String sheetId;
  final Dimension dimension;
  final List<String> ids;
  final bool hidden;
}

/// Resizes rows/columns; null size = automatic/default (03 §13.6).
final class ResizeDimension extends SheetsOperation {
  /// Creates the operation.
  const ResizeDimension(this.sheetId, this.dimension, this.ids, this.size);

  final String sheetId;
  final Dimension dimension;
  final List<String> ids;
  final double? size;
}

/// Sets frozen rows/columns (null = unchanged).
final class SetFrozen extends SheetsOperation {
  /// Creates the operation.
  const SetFrozen(this.sheetId, {this.rows, this.columns});

  final String sheetId;
  final int? rows;
  final int? columns;
}

/// Insert cells and shift existing content right/down, or delete cells and
/// shift left/up (03 §13.3).
enum ShiftDirection { right, down, left, up }

/// Insert/delete cells with shift.
final class ShiftCells extends SheetsOperation {
  /// Creates the operation.
  const ShiftCells(this.range, this.direction);

  final ResolvedRange range;
  final ShiftDirection direction;
}

/// Group/ungroup and outline operations (07 §16).
enum GroupAction {
  group,
  ungroup,
  collapse,
  expand,
  toggle,
  collapseToLevel,
  expandAll,
  collapseAll,
  removeAll,
}

/// An outline group operation over the span [start]..[end] (indices) or a
/// group id / level.
final class GroupOperation extends SheetsOperation {
  /// Creates the operation.
  const GroupOperation(
    this.sheetId,
    this.dimension,
    this.action, {
    this.start,
    this.end,
    this.groupId,
    this.level,
  });

  final String sheetId;
  final Dimension dimension;
  final GroupAction action;
  final int? start;
  final int? end;
  final String? groupId;
  final int? level;
}

// =============================================================================
// Sheets & spreadsheet

/// Creates the spreadsheet row and its first sheet (new spreadsheet).
final class CreateSpreadsheet extends SheetsOperation {
  /// Creates the operation.
  const CreateSpreadsheet({
    required this.spreadsheetId,
    this.title = 'Untitled spreadsheet',
    this.locale = 'en_US',
    this.timeZone = 'UTC',
    this.firstSheetName = 'Sheet1',
    this.rows = 1000,
    this.columns = 26,
    this.fontFamily,
    this.fontSize,
  });

  final String spreadsheetId;
  final String title;
  final String locale;
  final String timeZone;
  final String firstSheetName;
  final int rows;
  final int columns;

  /// Text font of the theme (the user's default, Settings › Sheets); null
  /// keeps the standard theme's.
  final String? fontFamily;

  /// `defaultFontSize`; null = 10.
  final double? fontSize;
}

/// Adds a sheet at [index] (null = end) with [rows] × [columns].
final class AddSheet extends SheetsOperation {
  /// Creates the operation.
  const AddSheet({
    this.name,
    this.index,
    this.rows = 1000,
    this.columns = 26,
    this.kind = SheetKind.grid,
    this.sheetId,
  });

  /// Name; null = next free "SheetN".
  final String? name;
  final int? index;
  final int rows;
  final int columns;
  final SheetKind kind;

  /// Use this id instead of a generated one.
  final String? sheetId;
}

/// Deletes a sheet (children cascade; undo revives everything).
final class DeleteSheet extends SheetsOperation {
  /// Creates the operation.
  const DeleteSheet(this.sheetId);

  final String sheetId;
}

/// Renames a sheet (`duplicate_name` when taken).
final class RenameSheet extends SheetsOperation {
  /// Creates the operation.
  const RenameSheet(this.sheetId, this.name);

  final String sheetId;
  final String name;
}

/// Duplicates a sheet with all content, formats and rules.
final class DuplicateSheet extends SheetsOperation {
  /// Creates the operation.
  const DuplicateSheet(this.sheetId, {this.name, this.index});

  final String sheetId;
  final String? name;
  final int? index;
}

/// Moves a sheet to [index] in the tab order.
final class MoveSheet extends SheetsOperation {
  /// Creates the operation.
  const MoveSheet(this.sheetId, this.index);

  final String sheetId;
  final int index;
}

/// Sheet properties (null = unchanged; [clearTabColor] removes the color).
final class SetSheetProperties extends SheetsOperation {
  /// Creates the operation.
  const SetSheetProperties(
    this.sheetId, {
    this.tabColor,
    this.clearTabColor = false,
    this.hidden,
    this.showGridlines,
    this.rightToLeft,
    this.defaultRowHeight,
    this.defaultColumnWidth,
  });

  final String sheetId;
  final String? tabColor;
  final bool clearTabColor;
  final bool? hidden;
  final bool? showGridlines;
  final bool? rightToLeft;
  final double? defaultRowHeight;
  final double? defaultColumnWidth;
}

/// Spreadsheet settings (null = unchanged).
final class SetSpreadsheetProperties extends SheetsOperation {
  /// Creates the operation.
  const SetSpreadsheetProperties({
    this.title,
    this.locale,
    this.timeZone,
    this.recalcMode,
    this.iterativeCalc,
    this.maxIterations,
    this.convergenceThreshold,
    this.themeJson,
    this.displayLanguage,
  });

  final String? title;
  final String? locale;
  final String? timeZone;
  final String? recalcMode;
  final bool? iterativeCalc;
  final int? maxIterations;
  final double? convergenceThreshold;

  /// Writes `themeJson` and `defaultFontFamily` (06 §13.1).
  final String? themeJson;
  final String? displayLanguage;
}

/// Updates the print settings of sheets with a JSON merge patch (11 §7.2).
final class SetPrintSettings extends SheetsOperation {
  /// Creates the operation.
  const SetPrintSettings(this.sheetIds, this.patch, {this.replace = false});

  final List<String> sheetIds;

  /// Merge patch (or the full JSON with [replace]); null resets to defaults.
  final Map<String, Object?>? patch;
  final bool replace;
}

// =============================================================================
// Rules, names, protections, banding, objects, pivots

/// Adds a conditional format rule before [beforeRuleId] (null = last).
final class AddCfRule extends SheetsOperation {
  /// Creates the operation.
  const AddCfRule(
    this.sheetId,
    this.ranges,
    this.ruleJson, {
    this.beforeRuleId,
    this.ruleId,
  });

  final String sheetId;
  final List<GridRect> ranges;

  /// `ruleJson` with formulas already in stored form.
  final String ruleJson;
  final String? beforeRuleId;
  final String? ruleId;
}

/// Updates a CF rule's ranges and/or JSON.
final class UpdateCfRule extends SheetsOperation {
  /// Creates the operation.
  const UpdateCfRule(this.ruleId, {this.ranges, this.ruleJson});

  final String ruleId;
  final List<GridRect>? ranges;
  final String? ruleJson;
}

/// Deletes a CF rule.
final class DeleteCfRule extends SheetsOperation {
  /// Creates the operation.
  const DeleteCfRule(this.ruleId);

  final String ruleId;
}

/// Moves a CF rule before [beforeRuleId] (null = last).
final class ReorderCfRule extends SheetsOperation {
  /// Creates the operation.
  const ReorderCfRule(this.ruleId, this.beforeRuleId);

  final String ruleId;
  final String? beforeRuleId;
}

/// Enables/disables a CF rule.
final class SetCfEnabled extends SheetsOperation {
  /// Creates the operation.
  const SetCfEnabled(this.ruleId, {required this.enabled});

  final String ruleId;
  final bool enabled;
}

/// Sets (or with null [criteriaJson] removes) data validation on ranges,
/// subtracting the ranges from other rules (07 §6.4).
final class SetDataValidation extends SheetsOperation {
  /// Creates the operation.
  const SetDataValidation(
    this.sheetId,
    this.ranges,
    this.criteriaJson, {
    this.strict = false,
    this.displayStyle,
    this.helpText,
    this.ruleId,
  });

  final String sheetId;
  final List<GridRect> ranges;

  /// Criteria (07 §6.1) or null to remove validation from the ranges.
  final String? criteriaJson;
  final bool strict;

  /// chip | arrow | plainText.
  final String? displayStyle;
  final String? helpText;

  /// Existing rule to update (its ranges are replaced).
  final String? ruleId;
}

/// Deletes a DV rule.
final class DeleteDvRule extends SheetsOperation {
  /// Creates the operation.
  const DeleteDvRule(this.ruleId);

  final String ruleId;
}

/// Insert › Checkbox: a checkbox rule plus `b:0` in empty cells (07 §6.7).
final class InsertCheckboxes extends SheetsOperation {
  /// Creates the operation.
  const InsertCheckboxes(
    this.sheetId,
    this.ranges, {
    this.checked,
    this.unchecked,
  });

  final String sheetId;
  final List<GridRect> ranges;
  final String? checked;
  final String? unchecked;
}

/// Creates/replaces the basic filter (id = `SheetsIds.basicFilterId`).
final class SetBasicFilter extends SheetsOperation {
  /// Creates the operation.
  const SetBasicFilter(
    this.sheetId,
    this.range, {
    this.criteriaJson,
    this.sortJson,
    this.openEnded = false,
  });

  final String sheetId;
  final GridRect range;
  final String? criteriaJson;
  final String? sortJson;

  /// Stores the range without its last row so rows appended below are
  /// included (07 §3.6: the data region reaches the last used row).
  final bool openEnded;
}

/// Sets (null removes) one column's criteria of the basic filter.
final class SetFilterColumnCriteria extends SheetsOperation {
  /// Creates the operation.
  const SetFilterColumnCriteria(
    this.sheetId,
    this.colId,
    this.criteria, {
    this.viewId,
  });

  final String sheetId;
  final String colId;

  /// Column criteria JSON map (07 §3.2) or null.
  final Map<String, Object?>? criteria;

  /// Filter view to change instead of the basic filter.
  final String? viewId;
}

/// Removes the basic filter.
final class RemoveBasicFilter extends SheetsOperation {
  /// Creates the operation.
  const RemoveBasicFilter(this.sheetId);

  final String sheetId;
}

/// Creates a saved filter view.
final class CreateFilterView extends SheetsOperation {
  /// Creates the operation.
  const CreateFilterView(
    this.sheetId,
    this.range, {
    this.name,
    this.criteriaJson,
    this.sortJson,
    this.viewId,
  });

  final String sheetId;
  final GridRect range;
  final String? name;
  final String? criteriaJson;
  final String? sortJson;
  final String? viewId;
}

/// Updates a filter view.
final class UpdateFilterView extends SheetsOperation {
  /// Creates the operation.
  const UpdateFilterView(
    this.viewId, {
    this.name,
    this.range,
    this.criteriaJson,
    this.sortJson,
  });

  final String viewId;
  final String? name;
  final GridRect? range;
  final String? criteriaJson;
  final String? sortJson;
}

/// Deletes a filter view.
final class DeleteFilterView extends SheetsOperation {
  /// Creates the operation.
  const DeleteFilterView(this.viewId);

  final String viewId;
}

/// Adds a named range ([range]) or named function/formula ([formula], stored form).
final class AddNamedRange extends SheetsOperation {
  /// Creates the operation.
  const AddNamedRange(
    this.name, {
    this.range,
    this.formula,
    this.comment,
    this.metaJson,
    this.id,
  });

  final String name;
  final ResolvedRange? range;
  final String? formula;
  final String? comment;
  final String? metaJson;
  final String? id;
}

/// Updates a named range; renames rewrite formulas using it (07 §8.3).
final class UpdateNamedRange extends SheetsOperation {
  /// Creates the operation.
  const UpdateNamedRange(
    this.id, {
    this.name,
    this.range,
    this.formula,
    this.comment,
    this.metaJson,
  });

  final String id;
  final String? name;
  final ResolvedRange? range;
  final String? formula;
  final String? comment;
  final String? metaJson;
}

/// Deletes a named range (formulas keep the text → `#NAME?`).
final class DeleteNamedRange extends SheetsOperation {
  /// Creates the operation.
  const DeleteNamedRange(this.id);

  final String id;
}

/// Adds a protection of [range] (null = whole sheet).
final class AddProtection extends SheetsOperation {
  /// Creates the operation.
  const AddProtection(
    this.sheetId, {
    this.range,
    this.exceptRanges = const [],
    this.description,
    this.warningOnly = false,
    this.editors = const [],
    this.id,
  });

  final String sheetId;
  final GridRect? range;
  final List<GridRect> exceptRanges;
  final String? description;
  final bool warningOnly;

  /// User UUIDs allowed to edit.
  final List<String> editors;
  final String? id;
}

/// Updates a protection.
final class UpdateProtection extends SheetsOperation {
  /// Creates the operation.
  const UpdateProtection(
    this.id, {
    this.range,
    this.wholeSheet = false,
    this.exceptRanges,
    this.description,
    this.warningOnly,
    this.editors,
  });

  final String id;
  final GridRect? range;
  final bool wholeSheet;
  final List<GridRect>? exceptRanges;
  final String? description;
  final bool? warningOnly;
  final List<String>? editors;
}

/// Deletes a protection.
final class DeleteProtection extends SheetsOperation {
  /// Creates the operation.
  const DeleteProtection(this.id);

  final String id;
}

/// Adds alternating colors to [range] (replacing overlapping bandings).
final class AddBanding extends SheetsOperation {
  /// Creates the operation.
  const AddBanding(this.sheetId, this.range, this.styleJson, {this.id});

  final String sheetId;
  final GridRect range;
  final String styleJson;
  final String? id;
}

/// Updates a banding.
final class UpdateBanding extends SheetsOperation {
  /// Creates the operation.
  const UpdateBanding(this.id, {this.range, this.styleJson});

  final String id;
  final GridRect? range;
  final String? styleJson;
}

/// Removes a banding.
final class RemoveBanding extends SheetsOperation {
  /// Creates the operation.
  const RemoveBanding(this.id);

  final String id;
}

/// Adds an embedded object (chart, image, slicer).
final class AddObject extends SheetsOperation {
  /// Creates the operation.
  const AddObject(
    this.sheetId,
    this.kind, {
    required this.anchorJson,
    required this.specJson,
    this.title,
    this.altText,
    this.zIndex,
    this.id,
  });

  final String sheetId;
  final EmbeddedObjectKind kind;
  final String anchorJson;
  final String specJson;
  final String? title;
  final String? altText;

  /// Null = on top.
  final int? zIndex;
  final String? id;
}

/// Updates an object (null = unchanged).
final class UpdateObject extends SheetsOperation {
  /// Creates the operation.
  const UpdateObject(
    this.id, {
    this.sheetId,
    this.anchorJson,
    this.specJson,
    this.zIndex,
    this.title,
    this.altText,
  });

  final String id;
  final String? sheetId;
  final String? anchorJson;
  final String? specJson;
  final int? zIndex;
  final String? title;
  final String? altText;
}

/// Deletes an object.
final class DeleteObject extends SheetsOperation {
  /// Creates the operation.
  const DeleteObject(this.id);

  final String id;
}

/// Adds a pivot table anchored at ([anchorRow], [anchorCol]) of [sheetId].
final class AddPivotTable extends SheetsOperation {
  /// Creates the operation.
  const AddPivotTable(
    this.sheetId,
    this.anchorRow,
    this.anchorCol,
    this.source,
    this.specJson, {
    this.id,
  });

  final String sheetId;
  final int anchorRow;
  final int anchorCol;
  final ResolvedRange source;
  final String specJson;
  final String? id;
}

/// Updates a pivot table.
final class UpdatePivotTable extends SheetsOperation {
  /// Creates the operation.
  const UpdatePivotTable(
    this.id, {
    this.specJson,
    this.source,
    this.anchorRow,
    this.anchorCol,
  });

  final String id;
  final String? specJson;
  final ResolvedRange? source;
  final int? anchorRow;
  final int? anchorCol;
}

/// Deletes a pivot table.
final class DeletePivotTable extends SheetsOperation {
  /// Creates the operation.
  const DeletePivotTable(this.id);

  final String id;
}

/// Inserts, updates or deletes rows of tables the planner treats generically
/// (scripts: `script_project`, `script_file`, `macro`, `script_property`,
/// `script_trigger`).
final class GenericRowWrite extends SheetsOperation {
  /// Creates the operation.
  const GenericRowWrite(
    this.table,
    this.id,
    this.columns, {
    this.delete = false,
    this.label,
  });

  final String table;
  final String id;

  /// Columns to insert/update (ignored for [delete]).
  final Map<String, Object?> columns;
  final bool delete;
  final String? label;
}

// =============================================================================
// Data tools, fill, clipboard

/// One sort key (07 §2.1).
final class SortKeySpec {
  /// Creates a key.
  const SortKeySpec(
    this.colId, {
    this.ascending = true,
    this.fillColor,
    this.textColor,
  });

  final String colId;
  final bool ascending;

  /// Sort-by-color (P2): rows with this fill/text color first.
  final String? fillColor;
  final String? textColor;
}

/// Sorts a range (strategy chosen automatically, 07 §2.2).
final class SortRange extends SheetsOperation {
  /// Creates the operation.
  const SortRange(this.range, this.specs, {this.hasHeader = false, this.label});

  final ResolvedRange range;
  final List<SortKeySpec> specs;
  final bool hasHeader;
  final String? label;
}

/// Randomizes the rows of a range (07 §14).
final class RandomizeRange extends SheetsOperation {
  /// Creates the operation.
  const RandomizeRange(this.range);

  final ResolvedRange range;
}

/// Removes duplicate rows within a range (07 §12.1).
final class RemoveDuplicates extends SheetsOperation {
  /// Creates the operation.
  const RemoveDuplicates(this.range, {this.hasHeader = false, this.colIds});

  final ResolvedRange range;
  final bool hasHeader;

  /// Compared columns (null = all).
  final List<String>? colIds;
}

/// Trims whitespace in text cells (07 §12.2).
final class TrimWhitespace extends SheetsOperation {
  /// Creates the operation.
  const TrimWhitespace(this.ranges);

  final List<ResolvedRange> ranges;
}

/// Splits a single column of text into columns (07 §13).
final class SplitTextToColumns extends SheetsOperation {
  /// Creates the operation.
  const SplitTextToColumns(this.range, {this.separator, this.force = false});

  final ResolvedRange range;

  /// null = detect automatically.
  final String? separator;

  /// Overwrite non-empty cells to the right without asking.
  final bool force;
}

/// Find & replace (07 §11).
final class FindReplace extends SheetsOperation {
  /// Creates the operation.
  const FindReplace({
    required this.find,
    required this.replacement,
    this.sheetIds,
    this.range,
    this.matchCase = false,
    this.matchEntireCell = false,
    this.useRegex = false,
    this.searchFormulas = false,
    this.searchLinks = false,
    this.onlyCell,
  });

  final String find;
  final String replacement;

  /// Sheets to search (null = all, in order).
  final List<String>? sheetIds;

  /// Specific range (overrides [sheetIds]).
  final ResolvedRange? range;
  final bool matchCase;
  final bool matchEntireCell;
  final bool useRegex;
  final bool searchFormulas;
  final bool searchLinks;

  /// Replace only in this cell (single *Replace*).
  final (String sheetId, int row, int col)? onlyCell;
}

/// Fill handle / Mod+D / Mod+R / Mod+Enter (03 §10).
enum FillMode { auto, copy }

/// Fills [target] from [source] (target includes or extends the source).
final class FillSeries extends SheetsOperation {
  /// Creates the operation.
  const FillSeries(
    this.sheetId,
    this.source,
    this.target, {
    this.mode = FillMode.auto,
    this.label,
  });

  final String sheetId;
  final GridRect source;
  final GridRect target;
  final FillMode mode;

  /// Undo label (default "Fill series", or "Fill" in copy mode).
  final String? label;
}

/// Moves (cut/paste, drag-move) or copies a block (03 §11, §12.6).
final class MoveRange extends SheetsOperation {
  /// Creates the operation.
  const MoveRange(
    this.source,
    this.destSheetId,
    this.destRow,
    this.destCol, {
    this.copy = false,
  });

  final ResolvedRange source;
  final String destSheetId;
  final int destRow;
  final int destCol;

  /// Copy instead of move.
  final bool copy;
}

/// Paste special modes (03 §12.4); [all] = normal paste.
enum PasteMode {
  all,
  valuesOnly,
  format,
  formulas,
  conditionalFormatting,
  dataValidation,
  columnWidths,
  transposed,
  allExceptBorders,
}

/// One source cell of a paste.
final class PasteCell {
  /// Creates a paste cell.
  const PasteCell({
    this.storedFormula,
    this.formulaA1,
    this.text,
    this.content,
    this.value,
    this.format,
    this.note,
  });

  /// Stored-form formula (same spreadsheet; translated from the source position).
  final String? storedFormula;

  /// A1 formula relative to the cell (other spreadsheets, HTML `data-sheets-formula`).
  final String? formulaA1;

  /// Plain text parsed like typing (TSV / HTML without typed values).
  final String? text;

  /// Literal content (typed values).
  final CellContent? content;

  /// The source's computed value (used by *Paste values only* for formulas).
  final CellValue? value;

  /// Format attributes (null = none).
  final CellFormat? format;
  final String? note;
}

/// DV rule carried by a paste source (rects relative to the source top-left).
typedef PasteDvRule = ({
  String criteriaJson,
  bool strict,
  String? displayStyle,
  String? helpText,
  List<GridRect> rects,
});

/// CF rule carried by a paste source (rects relative to the source top-left).
typedef PasteCfRule = ({String ruleJson, List<GridRect> rects});

/// Data to paste (internal payload, HTML table or TSV, already decoded).
final class PasteSource {
  /// Creates a source.
  const PasteSource({
    required this.cells,
    this.spreadsheetId,
    this.sheetId,
    this.sourceRow = 0,
    this.sourceCol = 0,
    this.merges = const [],
    this.dvRules = const [],
    this.cfRules = const [],
    this.columnWidths = const [],
    this.rowHeights = const [],
    this.isCut = false,
    this.internal = false,
    this.sourceRowIndices,
    this.sourceColIndices,
    this.dvAnchors = const [],
    this.cfAnchors = const [],
  });

  /// Rows × columns (null = empty cell).
  final List<List<PasteCell?>> cells;

  /// Source spreadsheet (same spreadsheet enables stored formulas and cut-move).
  final String? spreadsheetId;
  final String? sheetId;

  /// Source top-left (for formula translation and cut-move).
  final int sourceRow;
  final int sourceCol;

  /// Merges relative to the top-left.
  final List<GridRect> merges;
  final List<PasteDvRule> dvRules;
  final List<PasteCfRule> cfRules;
  final List<double?> columnWidths;
  final List<double?> rowHeights;

  /// Paste after cut (= move within the same spreadsheet).
  final bool isCut;

  /// Whether this came from a Wonky payload (enables CF/DV/widths modes).
  final bool internal;

  /// Source sheet indices of the copied rows / columns when the copy skipped
  /// hidden ones (source row `i` = `sourceRowIndices[i]`); null = contiguous
  /// from [sourceRow] / [sourceCol]. A cut of a non-contiguous copy moves only
  /// the copied (visible) cells (03 §12.6). [PasteCell.storedFormula]s stay
  /// relative to the contiguous position `sourceRow + i` / `sourceCol + j`.
  final List<int>? sourceRowIndices;
  final List<int>? sourceColIndices;

  /// Formula anchors (source sheet indices: top-left of the rule's first
  /// range, 06 §15.3) of [dvRules] / [cfRules], by position; missing entries
  /// default to the top-left of the rule's first copied rectangle. Used to
  /// re-anchor relative references of pasted rule formulas.
  final List<(int row, int col)?> dvAnchors;
  final List<(int row, int col)?> cfAnchors;

  /// The source sheet row of payload row [i].
  int sourceRowOf(int i) {
    final idx = sourceRowIndices;
    return idx != null && i < idx.length ? idx[i] : sourceRow + i;
  }

  /// The source sheet column of payload column [j].
  int sourceColOf(int j) {
    final idx = sourceColIndices;
    return idx != null && j < idx.length ? idx[j] : sourceCol + j;
  }

  /// Height.
  int get rowCount => cells.length;

  /// Width.
  int get colCount => cells.fold(0, (m, r) => r.length > m ? r.length : m);
}

/// Paste into [target] (selection; tiling when an exact multiple, 03 §12.3).
final class PasteClipboard extends SheetsOperation {
  /// Creates the operation.
  const PasteClipboard(this.target, this.source, {this.mode = PasteMode.all});

  final ResolvedRange target;
  final PasteSource source;
  final PasteMode mode;
}
