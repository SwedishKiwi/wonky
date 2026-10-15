import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show showShadDialog;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_charts/wonky_charts.dart' show ChartData;
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart'
    show ChartDataTableDialog, ChartDataTableStrings, chartDataJson;

/// *View data as table* (Slides 08 §17) as an MCP-describable dialog
/// (04 AC-9; SL-42): the shared `ChartDataTableDialog` of
/// `wonky_charts_flutter` can't implement `McpDescribableDialog`, so it is
/// shown inside an [McpDialogScope] that describes the table (headers and
/// rows, at most 500) with a `close` button.
Future<void> showDescribableChartDataDialog(
  BuildContext context, {
  required ChartData data,
  required ChartDataTableStrings strings,
  String locale = 'en_US',
  Key dialogKey = const ValueKey<String>('dialog.slides.chartData'),
}) => showShadDialog<void>(
  context: context,
  builder: (context) => McpDialogScope(
    dialog: _ChartDataDialog(
      title: strings.title,
      closeLabel: strings.close,
      table: chartDataJson(data, locale: locale),
      close: () => Navigator.of(context).pop(),
    ),
    child: ChartDataTableDialog(
      data: data,
      strings: strings,
      locale: locale,
      dialogKey: dialogKey,
    ),
  ),
);

class _ChartDataDialog implements McpDescribableDialog {
  _ChartDataDialog({
    required this.title,
    required this.closeLabel,
    required this.table,
    required this.close,
  });

  final String title;
  final String closeLabel;
  final Map<String, Object?> table;
  final VoidCallback close;

  @override
  Map<String, Object?> describe() => {
    'title': title,
    'kind': 'chartData',
    'table': table,
    'fields': const <Object?>[],
    'buttons': [
      {'id': 'close', 'label': closeLabel},
    ],
  };

  @override
  bool setField(String id, Object? value) => false;

  @override
  bool press(String buttonId) {
    if (buttonId != 'close' && buttonId != 'cancel') return false;
    close();
    return true;
  }
}
