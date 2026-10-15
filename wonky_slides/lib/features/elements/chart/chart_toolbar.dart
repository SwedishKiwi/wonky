import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_charts/wonky_charts.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../toolbar/command_ui.dart';
import 'chart_elements.dart';
import 'chart_section.dart' show chartPresetLabel;

/// The toolbar of a selected chart (Slides 04 §6 "Chart"): *Update* (when
/// linked), *Open source spreadsheet*, *3D view ▾* (camera presets, reset)
/// for 3D charts and *Style ▾* (Match theme / Keep source style, reset
/// overrides, data table, the Chart section).
List<ToolbarItem> chartToolbarItems(
  SlidesCommandUi ui,
  SlidesLocalizations l,
  DeckEditorController ed,
) {
  final ids = ed.selectedElementIds;
  final id = ids.length == 1 ? ids.single : null;
  final e = id == null ? null : ed.model.element(id);
  final linked = e != null && ChartElements.isLinked(ed, e);
  final is3D = id != null && ChartElements.is3D(ed, id);
  final snap = id == null ? null : ChartElements.snapshotOf(ed, id);
  final presets = snap?.spec.type == ChartType.pie
      ? Chart3DView.piePresets
      : Chart3DView.presets;
  return [
    if (linked) ...[
      ui.button('slides.chart.update', priority: 2),
      ui.button('slides.chart.openSource', priority: 3),
    ],
    if (is3D)
      ui.dropdown(
        'chart3dView',
        label: l.chartCamera,
        icon: LucideIcons.rotate3d,
        priority: 3,
        enabled: ui.state('slides.chart.setCamera', const {
          'reset': true,
        }).enabled,
        items: () => [
          for (final k in presets.keys)
            MenuSpec.command(
              'slides.chart.setCamera',
              label: chartPresetLabel(l, k),
              args: {'preset': k},
              id: 'toolbar.chart3dView.$k',
            ),
          MenuSpec.separator(),
          MenuSpec.command(
            'slides.chart.setCamera',
            label: l.chartCameraReset,
            args: const {'reset': true},
            id: 'toolbar.chart3dView.reset',
          ),
        ],
      ),
    ui.dropdown(
      'chartStyle',
      label: l.chartStyleMode,
      icon: LucideIcons.paintbrush,
      priority: 3,
      items: () => [
        MenuSpec.command(
          'slides.chart.setUseDeckTheme',
          label: l.chartMatchThemeShort,
          args: const {'useDeckTheme': true},
          id: 'toolbar.chartStyle.matchTheme',
          radio: true,
        ),
        MenuSpec.command(
          'slides.chart.setUseDeckTheme',
          label: l.chartKeepSource,
          args: const {'useDeckTheme': false},
          id: 'toolbar.chartStyle.keepSource',
          radio: true,
        ),
        MenuSpec.separator(),
        MenuSpec.command('slides.chart.resetOverrides'),
        MenuSpec.command('slides.chart.viewDataTable'),
        MenuSpec.command(
          'slides.inspector.open',
          label: l.chartCustomize,
          args: const {'tab': 'format', 'section': 'chart'},
          id: 'toolbar.chartStyle.customize',
        ),
      ],
    ),
  ];
}
