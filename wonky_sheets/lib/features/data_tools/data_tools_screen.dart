import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart' show EmbeddedObjectKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/cleanup_commands.dart'
    show cleanupSuggestionsPanelId, columnStatsPanelId;
import '../../commands/filter_commands.dart' show filterViewsPanelId;
import '../../commands/named_commands.dart'
    show namedFunctionsPanelId, namedRangesPanelId;
import '../../l10n/sheets_l10n.dart';
import '../filters/filter_views_panel.dart';
import '../named_ranges/named_functions_panel.dart';
import '../named_ranges/named_ranges_panel.dart';
import '../objects/objects_layer.dart' show objectViewBuilders;
import '../sheet_editor/sheet_editor_controller.dart';
import '../slicers/slicer_controller.dart';
import '../slicers/slicer_panel.dart';
import '../slicers/slicer_view.dart';
import '../toolbar/command_ui.dart';
import 'cleanup_suggestions_panel.dart';
import 'column_stats_panel.dart';
import 'data_tools.dart';

export '../filters/filter_view_bar.dart' show FilterViewBar;
export 'data_tools_overlay.dart' show DataToolsGridOverlay;

/// Dynamic menu slot of Data › Change view (04 §3.6).
const filterViewsMenuSlot = 'data.changeView.list';

/// Installs the data tools on a new editor (filter/group masks, layers) and
/// activates the `?fv=` filter view of the route (07 §4.1).
void attachDataTools(SheetEditorController editor, {String? filterView}) {
  final tools = DataTools.of(editor);
  // Slicers filter for everyone: compute their rows when the editor opens.
  objectViewBuilders[EmbeddedObjectKind.slicer] = (context, ed, o, zoom) =>
      SlicerView(editor: ed, record: o, zoom: zoom);
  SlicerController.of(editor);
  tools.filters.onViewDeleted = () =>
      editor.services.toasts.show(editor.l10n.filterViewDeletedToast);
  if (filterView != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in editor.model.sheets) {
        if (s.filterViews.containsKey(filterView)) {
          editor.activateSheet(s.id);
          tools.filters.activate(s.id, filterView);
          return;
        }
      }
      editor.services.toasts.show(editor.l10n.filterViewDeletedToast);
    });
  }
}

/// The data tool panels (04 §10): named ranges, named functions, filter
/// views, column stats.
List<SidePanelSpec> dataToolsPanelSpecs(
  BuildContext context,
  SheetEditorController editor,
) {
  final l = sheetsL10n(context);
  return [
    SidePanelSpec(
      id: namedRangesPanelId,
      title: l.cmdNamedRangesOpenPanel,
      icon: LucideIcons.bookmark,
      showAsTab: false,
      builder: (_) => NamedRangesPanel(editor: editor),
    ),
    SidePanelSpec(
      id: namedFunctionsPanelId,
      title: l.cmdNamedFunctionsOpenPanel,
      icon: LucideIcons.squareFunction,
      showAsTab: false,
      builder: (_) => NamedFunctionsPanel(editor: editor),
    ),
    SidePanelSpec(
      id: filterViewsPanelId,
      title: l.filterViewsTitle,
      icon: LucideIcons.listFilter,
      showAsTab: false,
      builder: (_) => FilterViewsPanel(editor: editor),
    ),
    SidePanelSpec(
      id: columnStatsPanelId,
      title: l.cmdDataColumnStats,
      icon: LucideIcons.chartNoAxesColumn,
      showAsTab: false,
      builder: (_) => ColumnStatsPanel(editor: editor),
    ),
    SidePanelSpec(
      id: cleanupSuggestionsPanelId,
      title: l.cmdCleanupOpenSuggestions,
      icon: LucideIcons.sparkles,
      showAsTab: false,
      builder: (_) => CleanupSuggestionsPanel(editor: editor),
    ),
    SidePanelSpec(
      id: slicerPanelId,
      title: l.slicerPanelTitle,
      icon: LucideIcons.slidersHorizontal,
      showAsTab: false,
      builder: (_) => SlicerPanel(editor: editor),
    ),
  ];
}

/// Dynamic menu entries of the data tools (Data › Change view list).
Map<String, List<WonkyMenuEntry> Function(BuildContext context)>
dataToolsMenuEntries(ShellServices s, SheetEditorController editor) => {
  filterViewsMenuSlot: (context) {
    final ui = CommandUi(context, s);
    final filters = DataTools.of(editor).filters;
    final sid = editor.activeSheetId;
    return [
      ui.item(
        'sheets.filterView.activate',
        args: {'viewId': null},
        label: ui.l.filterViewNoneItem,
        radio: true,
        keyName: 'data.changeView.none',
      ),
      for (final v in filters.savedViews(sid))
        ui.item(
          'sheets.filterView.activate',
          args: {'viewId': v.id},
          label: v.name ?? v.id,
          radio: true,
          keyName: 'data.changeView.${v.id}',
        ),
      for (final t in filters.temporaryViews)
        if (t.sheetId == sid)
          ui.item(
            'sheets.filterView.activate',
            args: {'viewId': t.id},
            label: t.name,
            radio: true,
            keyName: 'data.changeView.${t.id}',
          ),
      const WonkyMenuSeparator(),
      ui.item('sheets.filterView.openPanel', keyName: 'data.changeView.manage'),
    ];
  },
};
