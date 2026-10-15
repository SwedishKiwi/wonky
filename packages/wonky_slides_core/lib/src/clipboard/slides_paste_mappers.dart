import 'dart:convert';
import 'dart:math' as math;

import 'package:wonky_rich_text/wonky_rich_text.dart';
import 'package:wonky_sync_models/ids.dart';

import '../model/api/kinds.dart';
import '../model/text/slides_text.dart';
import '../ops/plan_context.dart';
import '../planner/order_keys.dart';
import '../planner/theme_copy.dart';
import '../schema/slides_schema.dart';
import '../text/slides_delta.dart';
import '../theme/model/common.dart';
import 'slides_clipboard_codec.dart';
import 'slides_html.dart';

/// The result of a paste mapper: a Slides clipboard payload of kind
/// `elements` (for `PasteElements`) and warning codes for the toast.
final class PasteMapResult {
  /// Creates a result.
  const PasteMapResult(this.payload, {this.warnings = const []});

  /// The payload (03 §12.2, kind `elements`; no source deck, so it pastes
  /// at the stored positions).
  final Map<String, Object?> payload;

  /// Warning codes: [truncated], [remoteImages].
  final List<String> warnings;

  /// More than 50 rows × 20 columns were pasted: only the first were kept
  /// ("Only the first 50 rows and 20 columns were pasted", 03 §12.4).
  static const truncated = 'truncated';

  /// Images with `https://` sources: the client fetches them through the
  /// image proxy and replaces `src` (03 §6.5).
  static const remoteImages = 'remote_images';

  /// Styling the Slides schema can't hold (fonts, sizes, other CSS) was
  /// dropped from pasted HTML.
  static const formattingDropped = 'formatting_dropped';

  /// The pasted top-level element rows.
  List<Map<String, Object?>> get elements =>
      (payload['elements']! as List).cast<Map<String, Object?>>();
}

/// One cell of a pasted grid (Sheets cells, TSV, HTML tables).
final class GridCell {
  /// Creates a cell; [text] is the displayed (formatted) value.
  const GridCell(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.color,
    this.fill,
    this.align,
    this.rowSpan,
    this.colSpan,
  });

  /// Displayed text.
  final String text;
  final bool bold;
  final bool italic;

  /// Text color (`#RRGGBB`).
  final String? color;

  /// Cell fill (`#RRGGBB`).
  final String? fill;

  /// `left`, `center`, `right`.
  final String? align;

  /// Merge origin spans (>1).
  final int? rowSpan;
  final int? colSpan;
}

/// Maps foreign clipboard content to Slides elements (03 §12.4–§12.5):
/// plain text → text box (lists detected), Write rich text → text box plus
/// image, table and code elements, grids (Sheets cells, TSV) → table
/// element, Sheets chart objects → linked (or static) chart, images →
/// image element. Each returns an `elements` payload that the planner's
/// `PasteElements` inserts with fresh ids; frames are laid out inside
/// [slide] (the deck's bounds, su).
abstract final class SlidesPasteMappers {
  /// Max pasted table size (02 §13).
  static int get maxRows => SlidesLimits.defaults.maxTableRows;
  static int get maxColumns => SlidesLimits.defaults.maxTableColumns;

  static Map<String, Object?> _payload(
    List<Map<String, Object?>> elements, {
    List<Map<String, Object?>> axes = const [],
    List<Map<String, Object?>> cells = const [],
    List<Map<String, Object?>> codeStates = const [],
    List<Map<String, Object?>> chartLinks = const [],
    List<Map<String, Object?>> files = const [],
  }) => {
    'format': SlidesClipboardCodec.format,
    'v': SlidesClipboardCodec.version,
    'kind': SlidesClipboardCodec.kindElements,
    'elements': elements,
    'tableAxes': axes,
    'tableCells': cells,
    'builds': const <Object?>[],
    'codeStates': codeStates,
    'chartLinks': chartLinks,
    'files': files,
  };

  static Map<String, Object?> _element(
    IdGenerator ids,
    ElementKind kind,
    SuRect frame,
    String zKey, {
    Map<String, Object?> columns = const {},
  }) => {
    ...elementDefaults(),
    SlidesCols.id: ids.newId(),
    SlidesCols.kind: kind.name,
    ElementCols.x: frame.x,
    ElementCols.y: frame.y,
    ElementCols.width: frame.width,
    ElementCols.height: frame.height,
    ElementCols.zKey: zKey,
    ElementCols.matchKey: SlidesIds.newMatchKey(ids),
    ...columns,
  };

  static const _textBoxStyle = '{"v":1,"autofit":"resize","wrap":true}';

  /// Line height used to size new text boxes (su per line at body size).
  static const _lineHeight = 56.0;

  static SuRect _box(SuRect slide, double y, double height) => SuRect(
    slide.x + slide.width * 0.1,
    y,
    slide.width * 0.8,
    math.max(_lineHeight, height),
  );

  /// A text box from plain text (03 §12.5: one paragraph per line, lines
  /// starting with `- `/`* `/`1. ` become lists). Empty text → no element.
  static PasteMapResult plainText(
    String text, {
    required SuRect slide,
    IdGenerator ids = const UuidV7IdGenerator(),
    bool lists = true,
  }) {
    final n = SlidesDeltaNormalizer();
    final body = n.normalize(n.fromPlainText(text, lists: lists));
    if (SlidesText.isBlank(body.json)) {
      return PasteMapResult(_payload(const []));
    }
    final lines = DeltaUtils.text(body.delta).split('\n').length - 1;
    final el = _element(
      ids,
      ElementKind.text,
      _box(slide, slide.y + slide.height * 0.1, lines * _lineHeight),
      FractionalIndex.first(),
      columns: {
        SlidesCols.text: body.json,
        ElementCols.textStyleJson: _textBoxStyle,
      },
    );
    return PasteMapResult(
      _payload([el]),
      warnings: [if (body.truncated) PasteMapResult.truncated],
    );
  }

  /// Splits TSV text (Sheets/Excel/Numbers copies) into rows of cells;
  /// quoted fields may hold tabs, newlines and doubled quotes.
  static List<List<String>> parseTsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    var atStart = true;
    final s = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < s.length && s[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
        continue;
      }
      if (ch == '"' && atStart) {
        quoted = true;
        atStart = false;
        continue;
      }
      if (ch == '\t') {
        row.add(cell.toString());
        cell.clear();
        atStart = true;
      } else if (ch == '\n') {
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
        atStart = true;
      } else {
        cell.write(ch);
        atStart = false;
      }
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  /// A table element from a grid (03 §12.4: Sheets cells with displayed
  /// values and basic formatting, TSV, Write tables): > 50 × 20 is cut
  /// ([PasteMapResult.truncated]). [header] marks the first row as the
  /// header row. [cellText] (optional) supplies a rich text body per cell
  /// instead of [GridCell.text] (Write's inline Markdown).
  static PasteMapResult grid(
    List<List<GridCell>> rows, {
    required SuRect slide,
    IdGenerator ids = const UuidV7IdGenerator(),
    bool header = false,
    Delta? Function(int row, int col)? cellText,
  }) {
    final height = math.min(rows.length, maxRows);
    final width = math.min(
      rows.fold<int>(0, (m, r) => math.max(m, r.length)),
      maxColumns,
    );
    if (height == 0 || width == 0) return PasteMapResult(_payload(const []));
    final truncated =
        rows.length > maxRows || rows.any((r) => r.length > maxColumns);
    const rowHeight = 64.0;
    final frameWidth = math.min(slide.width * 0.9, width * 240.0);
    final frame = SuRect(
      slide.x + (slide.width - frameWidth) / 2,
      slide.y + slide.height * 0.1,
      frameWidth,
      math.min(slide.height * 0.85, height * rowHeight),
    );
    final table = _element(
      ids,
      ElementKind.table,
      frame,
      FractionalIndex.first(),
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'style': 'theme',
          'options': {'headerRow': header, 'bandedRows': true},
        }),
      },
    );
    final tableId = table[SlidesCols.id]! as String;
    final axes = <Map<String, Object?>>[];
    List<String> addAxes(TableAxisDimension d, int n) {
      final out = <String>[];
      for (final (i, k) in OrderKeys.between(null, null, n).indexed) {
        final id = ids.newId();
        out.add(id);
        axes.add({
          SlidesCols.id: id,
          SlidesCols.elementId: tableId,
          TableAxisCols.dimension: d.name,
          SlidesCols.sortKey: k,
          TableAxisCols.size: null,
          TableAxisCols.header: header && d == TableAxisDimension.row && i == 0,
        });
      }
      return out;
    }

    final rowIds = addAxes(TableAxisDimension.row, height);
    final colIds = addAxes(TableAxisDimension.column, width);
    final normalizer = SlidesDeltaNormalizer();
    final cells = <Map<String, Object?>>[];
    for (var r = 0; r < height; r++) {
      for (var c = 0; c < width && c < rows[r].length; c++) {
        final g = rows[r][c];
        Delta d;
        final rich = cellText?.call(r, c);
        if (rich != null) {
          d = rich;
        } else {
          d = Delta();
          final inline = <String, dynamic>{
            if (g.bold) 'bold': true,
            if (g.italic) 'italic': true,
            'color': ?g.color,
          };
          if (g.text.isNotEmpty) {
            d.insert(
              g.text.replaceAll('\n', ' '),
              inline.isEmpty ? null : inline,
            );
          }
          d.insert('\n', g.align == null ? null : {'align': g.align});
        }
        final body = normalizer.normalize(d);
        final rowSpan = g.rowSpan != null && g.rowSpan! > 1
            ? math.min(g.rowSpan!, height - r)
            : null;
        final colSpan = g.colSpan != null && g.colSpan! > 1
            ? math.min(g.colSpan!, width - c)
            : null;
        if (SlidesText.isBlank(body.json) &&
            g.fill == null &&
            rowSpan == null &&
            colSpan == null) {
          continue;
        }
        cells.add({
          for (final col in SlidesTables.columns[SlidesTables.slideTableCell]!)
            col: null,
          SlidesCols.id: ids.newId(),
          SlidesCols.elementId: tableId,
          TableCellCols.rowId: rowIds[r],
          TableCellCols.columnId: colIds[c],
          SlidesCols.text: SlidesText.isBlank(body.json) ? null : body.json,
          TableCellCols.fill: g.fill,
          TableCellCols.rowSpan: rowSpan,
          TableCellCols.colSpan: colSpan,
        });
      }
    }
    return PasteMapResult(
      _payload([table], axes: axes, cells: cells),
      warnings: [if (truncated) PasteMapResult.truncated],
    );
  }

  /// A table from TSV text ([parseTsv] → [grid]).
  static PasteMapResult tsv(
    String text, {
    required SuRect slide,
    IdGenerator ids = const UuidV7IdGenerator(),
  }) => grid(
    [
      for (final r in parseTsv(text)) [for (final c in r) GridCell(c)],
    ],
    slide: slide,
    ids: ids,
  );

  /// An image element for an uploaded file or a URL (03 §6.5): fitted
  /// into 80 % of the slide, centered. `https://` sources warn
  /// [PasteMapResult.remoteImages] (the client re-hosts them through the
  /// image proxy).
  static PasteMapResult image({
    required String src,
    required SuRect slide,
    double? naturalWidth,
    double? naturalHeight,
    String? fileName,
    String? mimeType,
    String? altText,
    IdGenerator ids = const UuidV7IdGenerator(),
    String? sourceItemUuid,
    double? y,
  }) {
    final el = _image(
      ids,
      src: src,
      slide: slide,
      naturalWidth: naturalWidth,
      naturalHeight: naturalHeight,
      fileName: fileName,
      mimeType: mimeType,
      altText: altText,
      y: y,
      zKey: FractionalIndex.first(),
    );
    return PasteMapResult(
      _payload([el], files: _fileEntries([el], sourceItemUuid)),
      warnings: [if (_isRemote(src)) PasteMapResult.remoteImages],
    );
  }

  static bool _isRemote(String src) => src.startsWith('https://');

  static Map<String, Object?> _image(
    IdGenerator ids, {
    required String src,
    required SuRect slide,
    required String zKey,
    double? naturalWidth,
    double? naturalHeight,
    String? fileName,
    String? mimeType,
    String? altText,
    double? y,
  }) {
    final nw = (naturalWidth ?? 0) > 0 ? naturalWidth! : 800.0;
    final nh = (naturalHeight ?? 0) > 0 ? naturalHeight! : 600.0;
    final scale = math.min(
      1.0,
      math.min(slide.width * 0.8 / nw, slide.height * 0.8 / nh),
    );
    final w = nw * scale, h = nh * scale;
    final top = y ?? slide.y + (slide.height - h) / 2;
    return _element(
      ids,
      ElementKind.image,
      SuRect(slide.x + (slide.width - w) / 2, top, w, h),
      zKey,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'src': src,
          'naturalWidth': ?naturalWidth,
          'naturalHeight': ?naturalHeight,
          'fileName': ?fileName,
          'mimeType': ?mimeType,
        }),
        ElementCols.altText: altText,
      },
    );
  }

  static List<Map<String, Object?>> _fileEntries(
    List<Map<String, Object?>> elements,
    String? itemUuid,
  ) => [
    for (final e in elements)
      if (e[SlidesCols.kind] == ElementKind.image.name)
        if (jsonDecode(e[ElementCols.dataJson]! as String) case {
          'src': final String src,
        } when src.startsWith('wonky-file://'))
          {'fileUuid': src.substring(13), 'itemUuid': ?itemUuid},
  ];

  /// A chart from a Sheets objects payload item (`application/x-wonky-
  /// sheets-objects`, Sheets 08 §9.5: `{kind, spec, title, altText,
  /// spreadsheetItemUuid?, objectId?, sheetId?}`): **linked** when it
  /// names the spreadsheet item and object (a `ChartLink` with the
  /// spec; the snapshot is taken by the link update, 08) unless [unlinked],
  /// else a **static** chart holding the spec. Image objects
  /// (`spec.src`) become image elements.
  static PasteMapResult sheetsObject(
    Map<String, Object?> item, {
    required SuRect slide,
    required String userId,
    required DateTime now,
    IdGenerator ids = const UuidV7IdGenerator(),
    bool unlinked = false,
  }) {
    final spec = item['spec'] is Map
        ? (item['spec']! as Map).cast<String, Object?>()
        : const <String, Object?>{};
    final alt = item['altText'] is String ? item['altText']! as String : null;
    if (item['kind'] == 'image') {
      final src = spec['src'] ?? spec['url'];
      if (src is! String) return PasteMapResult(_payload(const []));
      return image(
        src: src,
        slide: slide,
        naturalWidth: (spec['naturalWidth'] as num?)?.toDouble(),
        naturalHeight: (spec['naturalHeight'] as num?)?.toDouble(),
        altText: alt,
        ids: ids,
      );
    }
    if (item['kind'] != 'chart') return PasteMapResult(_payload(const []));
    String? uuid(Object? v) =>
        v is String && _uuid.hasMatch(v) ? v.toLowerCase() : null;
    final itemUuid = uuid(item['spreadsheetItemUuid']);
    final objectId = uuid(item['objectId']);
    final linked = !unlinked && itemUuid != null && objectId != null;
    final w = slide.width * 0.6, h = slide.height * 0.6;
    final el = _element(
      ids,
      ElementKind.chart,
      SuRect(
        slide.x + (slide.width - w) / 2,
        slide.y + (slide.height - h) / 2,
        w,
        h,
      ),
      FractionalIndex.first(),
      columns: {
        SlidesCols.name: item['title'] is String ? item['title'] : null,
        ElementCols.altText: alt,
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'source': linked ? 'linked' : 'static',
          if (!linked) 'spec': spec,
          'style': {'useDeckTheme': true},
        }),
      },
    );
    final elementId = el[SlidesCols.id]! as String;
    return PasteMapResult(
      _payload(
        [el],
        chartLinks: [
          if (linked)
            {
              SlidesCols.id: SlidesIds.chartLinkId(elementId),
              SlidesCols.elementId: elementId,
              ChartLinkCols.spreadsheetItemUuid: itemUuid,
              ChartLinkCols.chartObjectId: objectId,
              ChartLinkCols.sheetId: uuid(item['sheetId']),
              ChartLinkCols.sourceSpecJson: jsonEncode(spec),
              // No snapshot yet: the link update (08) takes it.
              ChartLinkCols.dataSnapshotJson: '{"v":1}',
              ChartLinkCols.sourceVersion: '',
              ChartLinkCols.updatedAt: now.toUtc().toIso8601String(),
              ChartLinkCols.updatedBy: userId,
              ChartLinkCols.autoUpdate: false,
            },
        ],
      ),
    );
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// Wonky Write rich text (`application/x-wonky-write` Delta, Write 02)
  /// on the canvas (03 §12.4): paragraphs → one text box (H1 → `title`
  /// style, H2–H6 → `heading`, quotes → `quote`, lists with nesting and
  /// checklists, bold/italic/strike/underline/inline code/links kept),
  /// code blocks → code elements (language kept), images → image
  /// elements, tables → table elements (cells from inline Markdown), all
  /// stacked below each other.
  static PasteMapResult writeDelta(
    Delta write, {
    required SuRect slide,
    IdGenerator ids = const UuidV7IdGenerator(),
    String? sourceItemUuid,
  }) {
    final blocks = _writeBlocks(write);
    final elements = <Map<String, Object?>>[];
    final axes = <Map<String, Object?>>[];
    final cells = <Map<String, Object?>>[];
    final states = <Map<String, Object?>>[];
    final warnings = <String>{};
    final keys = OrderKeys.between(null, null, math.max(1, blocks.length));
    var y = slide.y + slide.height * 0.08;
    final normalizer = SlidesDeltaNormalizer();
    for (final (i, block) in blocks.indexed) {
      switch (block) {
        case _TextBlock(:final delta):
          final body = normalizer.normalize(delta);
          if (body.truncated) warnings.add(PasteMapResult.truncated);
          if (SlidesText.isBlank(body.json)) continue;
          final lines = DeltaUtils.text(body.delta).split('\n').length - 1;
          final frame = _box(slide, y, lines * _lineHeight);
          elements.add(
            _element(
              ids,
              ElementKind.text,
              frame,
              keys[i],
              columns: {
                SlidesCols.text: body.json,
                ElementCols.textStyleJson: _textBoxStyle,
              },
            ),
          );
          y += frame.height + 24;
        case _CodeBlock(:final language, :final code):
          final lines = '\n'.allMatches(code).length + 1;
          final frame = _box(slide, y, lines * 40 + 48);
          final el = _element(
            ids,
            ElementKind.code,
            frame,
            keys[i],
            columns: {
              ElementCols.dataJson: jsonEncode({
                'v': 1,
                'language': language.isEmpty ? 'plaintext' : language,
                'lineNumbers': false,
              }),
            },
          );
          elements.add(el);
          states.add({
            SlidesCols.id: ids.newId(),
            SlidesCols.elementId: el[SlidesCols.id],
            SlidesCols.sortKey: FractionalIndex.first(),
            SlidesCols.label: null,
            CodeStateCols.code: code,
            CodeStateCols.language: null,
            SlidesCols.title: null,
            CodeStateCols.highlight: null,
            CodeStateCols.annotationsJson: null,
            SlidesCols.transitionJson: null,
          });
          y += frame.height + 24;
        case _ImageBlock(:final src, :final alt):
          final el = _image(
            ids,
            src: src,
            slide: slide,
            altText: alt,
            y: y,
            zKey: keys[i],
          );
          if (_isRemote(src)) warnings.add(PasteMapResult.remoteImages);
          elements.add(el);
          y += (el[ElementCols.height]! as double) + 24;
        case _TableBlock(:final rows):
          final r = grid(
            [
              for (final row in rows)
                [for (final c in row) GridCell(InlineMarkdown.toPlainText(c))],
            ],
            slide: SuRect(
              slide.x,
              y - slide.height * 0.1,
              slide.width,
              slide.height,
            ),
            ids: ids,
            header: true,
            cellText: (row, col) =>
                _runsDelta(InlineMarkdown.parse(rows[row][col])),
          );
          warnings.addAll(r.warnings);
          for (final e in r.elements) {
            e[ElementCols.zKey] = keys[i];
            elements.add(e);
            y += (e[ElementCols.height]! as double) + 24;
          }
          axes.addAll((r.payload['tableAxes']! as List).cast());
          cells.addAll((r.payload['tableCells']! as List).cast());
      }
    }
    return PasteMapResult(
      _payload(
        elements,
        axes: axes,
        cells: cells,
        codeStates: states,
        files: _fileEntries(elements, sourceItemUuid),
      ),
      warnings: warnings.toList(),
    );
  }

  /// HTML from other apps (03 §12.5, P1): a single table (Sheets cells,
  /// spreadsheets) → table element with the cells' formatting and merges
  /// (02 §13 cut); anything else → [writeDelta] of `SlidesHtml.importHtml`
  /// (text box with paragraphs, headings, lists and inline formatting,
  /// images with `https://`/`wonky-file://` sources, tables, code).
  /// Warnings add [PasteMapResult.formattingDropped] when styling (fonts,
  /// sizes) was dropped.
  static PasteMapResult html(
    String html, {
    required SuRect slide,
    IdGenerator ids = const UuidV7IdGenerator(),
    String? sourceItemUuid,
  }) {
    final table = SlidesHtml.tableOf(html);
    if (table != null) return grid(table, slide: slide, ids: ids);
    final imported = SlidesHtml.importHtml(html);
    final r = writeDelta(
      imported.delta,
      slide: slide,
      ids: ids,
      sourceItemUuid: sourceItemUuid,
    );
    if (!imported.dropped) return r;
    return PasteMapResult(
      r.payload,
      warnings: [...r.warnings, PasteMapResult.formattingDropped],
    );
  }

  /// The text of Wonky Write rich text for pasting **into** a text body
  /// (03 §12.4, "Paste into text editing"): inline attributes and lists
  /// mapped, headings → `title`/`heading` styles, code blocks as plain
  /// paragraphs, table rows as tab-separated lines; embeds dropped. A
  /// Slides Delta (not normalized).
  static Delta writeText(Delta write) {
    final out = Delta();
    for (final b in _writeBlocks(write)) {
      switch (b) {
        case _TextBlock(:final delta):
          for (final op in delta.operations) {
            out.push(op);
          }
        case _CodeBlock(:final code):
          for (final line in code.split('\n')) {
            if (line.isNotEmpty) out.insert(line);
            out.insert('\n');
          }
        case _TableBlock(:final rows):
          for (final r in rows) {
            final t = [for (final c in r) InlineMarkdown.toPlainText(c)];
            if (t.join().isNotEmpty) out.insert(t.join('\t'));
            out.insert('\n');
          }
        case _ImageBlock():
          break;
      }
    }
    return out;
  }

  static Delta _runsDelta(List<InlineRun> runs) {
    final d = Delta();
    for (final r in runs) {
      d.insert(r.text, {
        if (r.bold) 'bold': true,
        if (r.italic) 'italic': true,
        if (r.strike) 'strike': true,
        if (r.code) 'code': true,
        'link': ?r.link,
      });
    }
    d.insert('\n');
    return d;
  }

  /// Write blocks in document order: runs of paragraphs, code blocks,
  /// images and tables (dividers dropped).
  static List<_Block> _writeBlocks(Delta write) {
    final out = <_Block>[];
    var text = Delta();
    var line = <(String, Map<String, dynamic>?)>[];
    String? codeLang;
    final code = StringBuffer();
    var codeLines = 0;

    void flushText() {
      if (text.isNotEmpty) out.add(_TextBlock(text));
      text = Delta();
    }

    void flushCode() {
      if (codeLang != null) out.add(_CodeBlock(codeLang!, code.toString()));
      codeLang = null;
      code.clear();
      codeLines = 0;
    }

    for (final op in write.operations) {
      if (!op.isInsert) continue;
      final data = op.data;
      if (data is Map) {
        flushCode();
        flushText();
        line = [];
        final image = data['image'];
        final table = data['table'];
        if (image is Map && image['src'] is String) {
          out.add(
            _ImageBlock(
              image['src']! as String,
              image['alt'] is String ? image['alt']! as String : null,
            ),
          );
        } else if (table is Map && table['rows'] is List) {
          out.add(
            _TableBlock([
              for (final r in table['rows']! as List)
                if (r is List) [for (final c in r) '$c'],
            ]),
          );
        }
        continue;
      }
      if (data is! String) continue;
      var rest = data;
      while (rest.isNotEmpty) {
        final nl = rest.indexOf('\n');
        if (nl < 0) {
          line.add((rest, op.attributes));
          break;
        }
        if (nl > 0) line.add((rest.substring(0, nl), op.attributes));
        rest = rest.substring(nl + 1);
        // End of a line: its block attributes are on this newline.
        final block = op.attributes ?? const <String, dynamic>{};
        final lang = block['code-block'];
        if (lang != null) {
          flushText();
          final l = '$lang';
          if (codeLang != null && codeLang != l) flushCode();
          codeLang = l;
          if (codeLines++ > 0) code.write('\n');
          for (final (t, _) in line) {
            code.write(t);
          }
        } else {
          flushCode();
          for (final (t, a) in line) {
            text.insert(t, _inline(a));
          }
          text.insert('\n', _block(block));
        }
        line = [];
      }
    }
    if (line.isNotEmpty) {
      for (final (t, a) in line) {
        text.insert(t, _inline(a));
      }
      text.insert('\n');
    }
    flushCode();
    flushText();
    return out;
  }

  static const _inlineKeys = {
    'bold',
    'italic',
    'strike',
    'underline',
    'code',
    'link',
  };

  static Map<String, dynamic>? _inline(Map<String, dynamic>? a) {
    if (a == null) return null;
    final out = {
      for (final e in a.entries)
        if (_inlineKeys.contains(e.key)) e.key: e.value,
    };
    return out.isEmpty ? null : out;
  }

  static Map<String, dynamic>? _block(Map<String, dynamic> a) {
    final out = <String, dynamic>{};
    final header = a['header'];
    if (header is int) out['style'] = header <= 1 ? 'title' : 'heading';
    if (a['blockquote'] == true) out['style'] = 'quote';
    final list = a['list'];
    if (list is String) {
      out['list'] = switch (list) {
        'checked' => 'check',
        'unchecked' => 'unchecked',
        'ordered' => 'ordered',
        _ => 'bullet',
      };
      final indent = a['indent'];
      if (indent is int && indent > 0) out['indent'] = math.min(indent, 8);
    }
    return out.isEmpty ? null : out;
  }
}

sealed class _Block {}

final class _TextBlock extends _Block {
  _TextBlock(this.delta);
  final Delta delta;
}

final class _CodeBlock extends _Block {
  _CodeBlock(this.language, this.code);
  final String language;
  final String code;
}

final class _ImageBlock extends _Block {
  _ImageBlock(this.src, this.alt);
  final String src;
  final String? alt;
}

final class _TableBlock extends _Block {
  _TableBlock(this.rows);
  final List<List<String>> rows;
}
