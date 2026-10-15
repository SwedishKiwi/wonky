import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';

import '../../../l10n/drive_l10n.dart';
import '../file_preview_controller.dart';
import 'text_file_viewer.dart';

/// CSV/TSV viewer (Drive 02 §6.4, P1): a virtualized table of the first
/// 1,000 rows (cells as text, no conversion) or the source text, switched
/// with the viewer bar's *Table* / *Text* toggle.
class CsvTableViewer extends StatefulWidget {
  const CsvTableViewer({super.key, required this.controller});

  final FilePreviewController controller;

  static const tableKey = ValueKey<String>('drive.preview.csv.table');

  @override
  State<CsvTableViewer> createState() => _CsvTableViewerState();
}

class _CsvTableViewerState extends State<CsvTableViewer> {
  final _h = ScrollController();
  final _v = ScrollController();

  static const _rowHeight = 30.0;
  static const _indexWidth = 52.0;
  static const _minCol = 72.0;
  static const _maxCol = 280.0;

  @override
  void dispose() {
    _h.dispose();
    _v.dispose();
    super.dispose();
  }

  /// Column widths from the first 100 rows (character count × 7.5 px).
  List<double> _widths(List<List<String>> rows, int columns) {
    final w = List<double>.filled(columns, _minCol);
    for (final r in rows.take(100)) {
      for (var i = 0; i < r.length; i++) {
        final firstLine = r[i].split('\n').first;
        w[i] = math.max(w[i], math.min(_maxCol, firstLine.length * 7.5 + 20));
      }
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (!c.csvAsTable) return TextFileViewer(controller: c);
    final table = c.csv!;
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final widths = _widths(table.rows, table.columnCount);
    final totalW = _indexWidth + widths.fold<double>(0, (a, b) => a + b);
    final cellStyle = theme.textTheme.small.copyWith(
      fontWeight: FontWeight.w400,
    );
    final headStyle = theme.textTheme.small.copyWith(
      fontWeight: FontWeight.w600,
    );
    Widget row(int index) {
      final r = table.rows[index];
      final header = index == 0;
      return Container(
        height: _rowHeight,
        decoration: BoxDecoration(
          color: header ? cs.muted : cs.background,
          border: Border(bottom: BorderSide(color: cs.border)),
        ),
        child: Row(
          children: [
            Container(
              width: _indexWidth,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: cs.muted,
                border: Border(right: BorderSide(color: cs.border)),
              ),
              child: Text('${index + 1}', style: theme.textTheme.muted),
            ),
            for (var i = 0; i < widths.length; i++)
              Container(
                width: widths[i],
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: cs.border)),
                ),
                child: Text(
                  i < r.length ? r[i].replaceAll('\n', ' ⏎ ') : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: header ? headStyle : cellStyle,
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PreviewNotices(controller: c),
        if (table.truncated)
          Container(
            key: const ValueKey<String>('drive.preview.csv.truncated'),
            color: cs.muted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l.previewCsvTruncated(table.rows.length),
              style: theme.textTheme.small,
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: cs.background,
            child: LayoutBuilder(
              builder: (context, box) => RawScrollbar(
                controller: _h,
                notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _h,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: math.max(totalW, box.maxWidth),
                    height: box.maxHeight,
                    child: RawScrollbar(
                      controller: _v,
                      child: ListView.builder(
                        key: CsvTableViewer.tableKey,
                        controller: _v,
                        itemExtent: _rowHeight,
                        itemCount: table.rows.length,
                        itemBuilder: (context, i) => row(i),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
