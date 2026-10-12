part of 'chart_layout_engine.dart';

/// Row order of a table chart after sorting (08 §3.7 `sortColumn`).
List<int> tableRowOrder(ChartTableData t, TableOptions o) {
  final order = List<int>.generate(t.rowCount, (i) => i);
  final col = o.sortColumn;
  if (col == null || col < 0 || col >= t.columnCount) return order;
  final vals = t.values[col];
  final texts = t.texts[col];
  int cmp(int a, int b) {
    final va = vals[a], vb = vals[b];
    int r;
    if (!va.isNaN && !vb.isNaN) {
      r = va.compareTo(vb);
    } else if (va.isNaN != vb.isNaN) {
      return va.isNaN ? 1 : -1; // numbers before text/empty, regardless of direction
    } else {
      final ta = texts[a], tb = texts[b];
      if (ta.isEmpty != tb.isEmpty) return ta.isEmpty ? 1 : -1;
      r = ta.toLowerCase().compareTo(tb.toLowerCase());
    }
    if (!o.sortAscending) r = -r;
    return r != 0 ? r : a.compareTo(b);
  }

  order.sort(cmp);
  return order;
}

void _layoutTable(_Ctx c, ChartRect r) {
  final t = c.data.table!;
  final o = c.spec.tableOptions;
  c.plotArea = r;
  final style = c.font(ChartFont.inherit, size: 12, color: c.theme.text);
  final headerStyle = style.copyWith(bold: true);
  final lineH = c.measure('Ag', style).height;
  final rowH = (lineH * 1.6).roundToDouble();
  final order = tableRowOrder(t, o);
  var rows = order;
  var footer = '';
  if (o.pageSize > 0 && order.length > o.pageSize) {
    final pages = (order.length / o.pageSize).ceil();
    final page = c.options.tablePage.clamp(0, pages - 1);
    rows = order.sublist(page * o.pageSize, math.min(order.length, (page + 1) * o.pageSize));
    footer = 'Page ${page + 1} of $pages';
  }
  final footerH = footer.isEmpty ? 0.0 : rowH;
  final fit = math.max(0, ((r.height - rowH - footerH) / rowH).floor());
  if (rows.length > fit) {
    if (footer.isEmpty) footer = '$fit of ${rows.length} rows';
    rows = rows.sublist(0, fit);
  }
  // Columns: optional row numbers, then data columns.
  final cols = <(String header, List<String> texts, bool numeric, int? source)>[];
  if (o.showRowNumbers) {
    cols.add(('', [for (final i in rows) '${i + 1}'], true, null));
  }
  for (var k = 0; k < t.columnCount; k++) {
    var numeric = true;
    var any = false;
    for (final i in rows) {
      if (t.texts[k][i].isEmpty) continue;
      any = true;
      if (t.values[k][i].isNaN) {
        numeric = false;
        break;
      }
    }
    cols.add((t.headers[k], [for (final i in rows) t.texts[k][i]], numeric && any, k));
  }
  const padX = 8.0;
  final widths = <double>[];
  for (final (h, texts, _, _) in cols) {
    var w = c.measure(h, headerStyle).width;
    for (var k = 0; k < texts.length && k < 100; k++) {
      w = math.max(w, c.measure(texts[k], style).width);
    }
    widths.add(w + 2 * padX);
  }
  final total = widths.fold<double>(0, (s, w) => s + w);
  if (total > r.width && total > 0) {
    final f = r.width / total;
    for (var k = 0; k < widths.length; k++) {
      widths[k] = math.max(24, widths[k] * f);
    }
  } else if (total < r.width && widths.isNotEmpty) {
    final extra = (r.width - total) / widths.length;
    for (var k = 0; k < widths.length; k++) {
      widths[k] += extra;
    }
  }
  final headerFill = Argb.lerp(c.background, c.theme.gridline, 0.8);
  final altFill = Argb.lerp(c.background, c.theme.gridline, 0.35);
  c.out.add(SRect(ChartRect(r.left, r.top, r.width, rowH), fill: headerFill, tag: const SceneTag(SceneRole.tableHeader)));
  if (o.alternatingColors) {
    for (var k = 1; k < rows.length; k += 2) {
      c.out.add(SRect(ChartRect(r.left, r.top + rowH * (k + 1), r.width, rowH), fill: altFill));
    }
  }
  final sep = PathBuilder();
  for (var k = 0; k <= rows.length; k++) {
    final y = r.top + rowH * (k + 1);
    sep
      ..moveTo(r.left, y)
      ..lineTo(r.left + math.min(r.width, widths.fold<double>(0, (s, w) => s + w)), y);
  }
  c.out.add(SPath(sep.commands, stroke: SStroke(c.theme.gridline), tag: const SceneTag(SceneRole.gridline, detail: 'table')));
  var x = r.left;
  for (var k = 0; k < cols.length; k++) {
    final (h, texts, numeric, source) = cols[k];
    final w = widths[k];
    final inner = w - 2 * padX;
    final tx = numeric ? x + w - padX : x + padX;
    final anchor = numeric ? TextAnchor.middleRight : TextAnchor.middleLeft;
    if (h.isNotEmpty) {
      final sorted = source != null && o.sortColumn == source;
      final label = sorted ? '$h ${o.sortAscending ? '▲' : '▼'}' : h;
      c.out.add(
        c.text(c.measurer.ellipsize(label, headerStyle, inner), tx, r.top + rowH / 2, headerStyle, anchor: anchor, tag: SceneTag(SceneRole.tableHeader, detail: '${source ?? -1}')),
      );
    }
    final cellStyle = source == null ? style.copyWith(color: c.theme.mutedText) : style;
    for (var i = 0; i < texts.length; i++) {
      if (texts[i].isEmpty) continue;
      c.out.add(
        c.text(
          c.measurer.ellipsize(texts[i], cellStyle, inner),
          tx,
          r.top + rowH * (i + 1.5),
          cellStyle,
          anchor: anchor,
          tag: SceneTag(SceneRole.tableCell, pointIndex: rows[i], detail: '${source ?? -1}'),
        ),
      );
    }
    x += w;
  }
  if (footer.isNotEmpty) {
    final fs = style.copyWith(color: c.theme.mutedText, size: 11);
    c.out.add(c.text(footer, r.right - padX, r.top + rowH * (rows.length + 1) + rowH / 2, fs, anchor: TextAnchor.middleRight, tag: const SceneTag(SceneRole.legend, detail: 'paging')));
  }
}
