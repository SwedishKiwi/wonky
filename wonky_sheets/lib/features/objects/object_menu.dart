import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../sheet_editor/sheet_editor_controller.dart';
import '../toolbar/command_ui.dart';

/// Z-order operations of `sheets.object.order` (08 §9.4).
const objectOrderOps = ['front', 'forward', 'backward', 'back'];

/// Chart download formats of `sheets.chart.download` (08 §13).
const chartDownloadFormats = ['png', 'svg', 'pdf'];

/// The ⋮ / context menu of an embedded object (08 §9.6), built from
/// command ids.
List<WonkyMenuEntry> objectMenu(
  CommandUi ui,
  SheetEditorController ed,
  EmbeddedObjectRecord o, {
  InvocationSource source = InvocationSource.contextMenu,
}) {
  final l = ui.l;
  final id = {'objectId': o.id};
  final chart = o.kind == EmbeddedObjectKind.chart;
  final image = o.kind == EmbeddedObjectKind.image;
  final onChartSheet =
      ed.model.sheet(o.sheetId)?.record?.kind == SheetKind.chart;
  final gridSheets = [
    for (final s in ed.model.sheets)
      if (s.record?.kind != SheetKind.chart && !(s.record?.hidden ?? false)) s,
  ];
  return [
    if (chart) ui.item('sheets.chart.edit', args: id, source: source),
    if (image) ...[
      ui.item('sheets.image.replace', args: id, source: source),
      ui.item('sheets.image.placeInCell', args: id, source: source),
      ui.item('sheets.image.resetSize', args: id, source: source),
    ],
    ui.item('sheets.object.editAltText', args: id, source: source),
    if (chart) ui.item('sheets.chart.viewDataTable', args: id, source: source),
    const WonkyMenuSeparator(),
    ui.item(
      'sheets.object.copy',
      args: id,
      label: chart ? l.objectMenuCopyChart : null,
      source: source,
    ),
    if (chart)
      WonkyMenuSubmenu(
        label: l.objectMenuDownload,
        children: [
          for (final f in chartDownloadFormats)
            ui.item(
              'sheets.chart.download',
              args: {...id, 'format': f},
              label: switch (f) {
                'png' => l.chartDownloadPng,
                'svg' => l.chartDownloadSvg,
                _ => l.chartDownloadPdf,
              },
              keyName: 'object.download.$f',
              source: source,
            ),
        ],
      )
    else if (image)
      ui.item(
        'sheets.chart.download',
        args: id,
        label: l.objectMenuDownload,
        keyName: 'object.download',
        source: source,
      ),
    if (chart && !onChartSheet)
      ui.item('sheets.chart.moveToOwnSheet', args: id, source: source),
    if (chart && onChartSheet)
      WonkyMenuSubmenu(
        label: l.objectMenuMoveToSheet,
        children: [
          for (final s in gridSheets)
            ui.item(
              'sheets.chart.moveToSheet',
              args: {...id, 'sheetId': s.id},
              label: s.name,
              keyName: 'object.moveToSheet.${s.id}',
              source: source,
            ),
        ],
      ),
    if (!onChartSheet)
      WonkyMenuSubmenu(
        label: l.objectMenuOrder,
        children: [
          for (final op in objectOrderOps)
            ui.item(
              'sheets.object.order',
              args: {...id, 'op': op},
              label: switch (op) {
                'front' => l.objectOrderFront,
                'forward' => l.objectOrderForward,
                'backward' => l.objectOrderBackward,
                _ => l.objectOrderBack,
              },
              keyName: 'object.order.$op',
              source: source,
            ),
        ],
      ),
    const WonkyMenuSeparator(),
    ui.item(
      'sheets.object.delete',
      args: {
        'objectIds': [o.id],
      },
      source: source,
    ),
  ];
}
