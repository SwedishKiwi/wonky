import 'package:flutter/widgets.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart' as shared;
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';

export 'package:wonky_charts_flutter/wonky_charts_flutter.dart'
    show chartDataRows, chartDataJson;

/// "View data as table" (08 §14): a read-only table of the chart's resolved
/// data (the shared `ChartDataTableDialog` of `wonky_charts_flutter`).
Future<void> showChartDataTableDialog(
  BuildContext context, {
  required String title,
  required ChartData data,
}) {
  final l = sheetsL10n(context);
  return shared.showChartDataTableDialog(
    context,
    data: data,
    strings: shared.ChartDataTableStrings(
      title: l.dialogChartDataTitle(title),
      close: l.dialogClose,
      noData: l.chartNoData,
    ),
  );
}
