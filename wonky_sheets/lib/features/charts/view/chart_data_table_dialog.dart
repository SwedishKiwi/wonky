import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../../l10n/sheets_l10n.dart';

/// Header and formatted rows of [data] (domain + series columns).
({List<String> headers, List<List<String>> rows}) chartDataRows(
  ChartData data, {
  String locale = 'en_US',
}) {
  final t = data.table;
  if (t != null) {
    return (
      headers: t.headers,
      rows: [
        for (var r = 0; r < t.rowCount; r++)
          [for (final col in t.texts) r < col.length ? col[r] : ''],
      ],
    );
  }
  final fmt = DefaultChartValueFormatter(locale: locale);
  final d = data.domain;
  final withDomain = !d.isSynthetic;
  return (
    headers: [if (withDomain) d.name, for (final s in data.series) s.name],
    rows: [
      for (var i = 0; i < d.length; i++)
        [
          if (withDomain) d.labels[i],
          for (final s in data.series)
            i < s.values.length && !s.values[i].isNaN
                ? fmt.format(s.values[i], s.numberFormat)
                : '',
        ],
    ],
  );
}

/// `sheets.chart.viewDataTable` result for MCP callers.
Map<String, Object?> chartDataJson(ChartData data) {
  final t = chartDataRows(data);
  return {'headers': t.headers, 'rows': t.rows};
}

/// "View data as table" (08 §14): a read-only table of the chart's resolved
/// data.
Future<void> showChartDataTableDialog(
  BuildContext context, {
  required String title,
  required ChartData data,
}) => showShadDialog<void>(
  context: context,
  builder: (context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    final t = chartDataRows(data);
    final rows = t.rows.take(500).toList();
    return ShadDialog(
      key: const ValueKey<String>('dialog.chartData'),
      title: Text(l.dialogChartDataTitle(title)),
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.dialogClose),
        ),
      ],
      child: t.headers.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.chartNoData, style: theme.textTheme.muted),
            )
          : SizedBox(
              height: 360,
              child: ShadTable.list(
                header: [
                  for (final h in t.headers)
                    ShadTableCell.header(
                      child: Text(
                        h,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                children: [
                  for (final r in rows)
                    [
                      for (final c in r)
                        ShadTableCell(
                          child: Text(
                            c,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                ],
              ),
            ),
    );
  },
);
