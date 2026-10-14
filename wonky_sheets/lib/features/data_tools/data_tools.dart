import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import '../../theme/sheets_tokens.dart';
import '../filters/filter_controller.dart';
import '../filters/filter_layers.dart';
import '../find/find_controller.dart';
import '../find/find_layer.dart';
import '../groups/group_controller.dart';
import '../groups/group_gutter.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// The floating separator chip after *Split text to columns* (04 §11.13).
@immutable
class SplitChipState {
  const SplitChipState(
    this.sheetId,
    this.range,
    this.separator, {
    this.detected,
    this.failed = false,
  });

  final String sheetId;

  /// The split source column range.
  final GridRect range;

  /// The separator chosen in the chip (`null` = detect automatically).
  final String? separator;

  /// The separator the split used.
  final String? detected;

  /// Detection found no separator ("Couldn't detect a separator").
  final bool failed;
}

/// Per-editor state of the data tools (07): filters and filter views, outline
/// groups, find, and transient UI (separator chip, column stats column).
/// Installs the grid layers and hit handlers once per editor.
class DataTools {
  DataTools._(this.ed)
    : filters = FilterController(ed),
      groups = GroupController(ed),
      find = FindController(ed);

  static const _key = #sheetsDataTools;

  /// The data tools of [ed] (installed on first use).
  static DataTools of(SheetEditorController ed) =>
      ed.extension(_key, () => DataTools._(ed).._install());

  final SheetEditorController ed;
  final FilterController filters;
  final GroupController groups;
  final FindController find;

  /// The separator chip (null = hidden).
  final ValueNotifier<SplitChipState?> splitChip = ValueNotifier(null);

  /// Column shown by the column stats panel (null = active column).
  final ValueNotifier<String?> statsColumn = ValueNotifier(null);

  /// Cleanup suggestions dismissed on this device (07 §12.3: local),
  /// by `sheetId/suggestion id`.
  final Set<String> dismissedCleanup = {};

  void _install() {
    filters.start();
    groups.start();
    find.start();
    ed.layers
      ..add(FilterButtonLayer(filters))
      ..add(FilterRangeLayer(filters))
      ..add(StickyRowLayer(filters))
      ..add(FindLayer(find))
      ..add(GroupGutterLayer(groups));
    final hooks = ed.gridHooks;
    hooks.hitHandlers
      ..add(GroupGutterHitHandler(groups, _invoke))
      ..add(
        FilterButtonHitHandler(ed, filters, (colId, anchor) {
          filters.popover.value = FilterPopoverRequest(
            ed.activeSheetId,
            colId,
            anchor,
          );
        }),
      );
    hooks.gutters = groups.gutters;
    hooks.rowNumberColor = _rowNumberColor;
    hooks.headerColors = (sheetId, tokens) =>
        filters.activeViewId(sheetId) == null
        ? null
        : FilterColors.viewHeaders(tokens);
    ed.selection.addListener(_onSelection);
    ed.onDispose(_dispose);
  }

  Color? _rowNumberColor(String sheetId, int row, GridPaintTokens tokens) {
    final f = filters.effective(sheetId);
    if (f == null || f.criteria.isEmpty) return null;
    if (row < f.dataTop || row > f.range.bottom) return null;
    return FilterColors.rowNumber(tokens);
  }

  void _invoke(String id, Map<String, Object?> args) =>
      unawaited(ed.invokeCommand(id, args));

  void _onSelection() {
    final chip = splitChip.value;
    if (chip == null) return;
    final sel = ed.selection.resolved;
    if (sel.sheetId != chip.sheetId || sel.activeRange.rect != chip.range) {
      splitChip.value = null;
    }
  }

  void _dispose() {
    ed.selection.removeListener(_onSelection);
    filters.dispose();
    groups.dispose();
    find.dispose();
    splitChip.dispose();
    statsColumn.dispose();
  }
}
