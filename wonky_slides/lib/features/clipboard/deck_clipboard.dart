import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/clipboard.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/scene.dart' show SlideImageRef;
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/text.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;
import 'package:wonky_sync_models/ids.dart';

import '../../config/slides_features.dart';
import '../../l10n/slides_l10n.dart';
import '../canvas/slide_canvas_controller.dart' show selectionOf;
import '../editor_screen/deck_editor_controller.dart';
import '../elements/image/image_canvas.dart' show ImageDrops;
import '../elements/image/image_rules.dart' show PickedImage;
import '../elements/table/table_cells.dart';
import '../navigator/navigator_clipboard.dart';
import '../text_editing/slide_text_editor.dart';
import '../text_editing/text_editing_host.dart';
import '../uploads/slides_image_service.dart';
import 'paste_options.dart';
import 'rehome_queue.dart';
import 'system_clipboard.dart';

/// Where a copy or paste of an open deck goes (03 §12.3).
enum ClipboardTarget {
  /// The body being edited (rich text at the caret).
  text,

  /// The selected table cells.
  cells,

  /// The navigator or grid view (slides and groups).
  navigator,

  /// The current slide (elements).
  canvas,
}

/// Copy, cut and paste of Wonky Slides (03 §12, 04 §5.8, §13.12; SL-18):
///
/// - **Copy** writes the lossless payload (in-app store + `text/html` with
///   the payload embedded, `text/plain`) for elements, text selections and
///   (through the navigator) slides and groups; table cell ranges as TSV
///   and an HTML table.
/// - **Paste** resolves the clipboard in this order: a Slides payload
///   (embedded in HTML, or the in-app store when the system clipboard
///   holds its plain text or can't be read), a Sheets objects copy
///   (marker + the shared local store), Wonky Write's Delta, an image,
///   HTML (tables, rich text), TSV, a URL, plain text — and maps it for
///   the target: rich text at the caret, cells, slides after the current
///   slide, or elements on the canvas.
/// - **Cross-deck and cross-app** pastes re-home uploaded files into this
///   deck (`file.copyToItem` through [SlidesRehomeQueue]; quota
///   pre-checked) and offer the paste options chip.
abstract final class DeckClipboard {
  /// Key of the Sheets objects copy in the user's local store (shared by
  /// the apps of one origin): `{id, items}` (Sheets 08 §9.5, A-03-5).
  static const sheetsObjectsKey = 'clipboard.sheetsObjects';

  /// Plain-text marker Wonky Sheets writes with an objects copy.
  static const sheetsMarker = 'wonky-sheets-objects:';

  static final _url = RegExp(r'^(https://|mailto:)\S+$');

  /// Where a clipboard action of [ed] goes now.
  static ClipboardTarget targetOf(DeckEditorController ed) {
    if (textEditingOf(ed).active != null) return ClipboardTarget.text;
    if (ed.mode == DeckViewMode.grid || ed.navigatorFocus.hasFocus) {
      return ClipboardTarget.navigator;
    }
    if (ed.mode == DeckViewMode.normal &&
        TableCellSelection.of(ed).range != null) {
      return ClipboardTarget.cells;
    }
    if (ed.mode == DeckViewMode.normal &&
        ed.selectedElementIds.isEmpty &&
        !ed.notesFocus.hasFocus) {
      // Nothing on the canvas: slides (04 §5.8) — paste still goes to the
      // canvas unless the clipboard holds slides.
      return ClipboardTarget.navigator;
    }
    return ClipboardTarget.canvas;
  }

  /// Whether this user may copy from [ed] (03 §12.3: viewers only when the
  /// owner allows copying/exporting).
  static bool copyAllowed(DeckEditorController ed) =>
      ed.roleCanEdit ||
      (ed.services.currentItem.value?.nonEditorsCanExport ?? true);

  /// Whether Copy has something to copy.
  static bool canCopy(DeckEditorController ed) {
    if (!copyAllowed(ed) || !ed.isReady) return false;
    return switch (targetOf(ed)) {
      ClipboardTarget.text => _textRange(ed) != null,
      ClipboardTarget.cells => true,
      ClipboardTarget.navigator =>
        ed.services.dispatcher.stateOf('slides.navigator.copy').enabled,
      ClipboardTarget.canvas => ed.selectedElementIds.isNotEmpty,
    };
  }

  /// Whether Cut has something to cut (edit access).
  static bool canCut(DeckEditorController ed) {
    if (!ed.canEdit) return false;
    if (targetOf(ed) == ClipboardTarget.navigator) {
      return ed.services.dispatcher.stateOf('slides.navigator.cut').enabled;
    }
    return canCopy(ed);
  }

  static (SlideTextEditController, int, int)? _textRange(
    DeckEditorController ed,
  ) {
    final c = textEditingOf(ed).active;
    final r = c?.selectionRange;
    if (c == null || r == null || r.$1 == r.$2) return null;
    return (c, r.$1, r.$2);
  }

  // ------------------------------------------------------------------ copy

  /// Copies (or cuts) the current selection of [ed] (03 §12.1).
  static Future<CommandResult> copy(
    CommandContext ctx,
    DeckEditorController ed, {
    bool cut = false,
  }) async {
    final l = slidesL10nOf(ed.services);
    if (!copyAllowed(ed)) return CommandResult.failed(l.reasonCopyNotAllowed);
    final store = ed.services.userStore;
    switch (targetOf(ed)) {
      case ClipboardTarget.text:
        final t = _textRange(ed);
        if (t == null) return CommandResult.failed(l.reasonSelectText);
        final (c, start, end) = t;
        c.commit();
        final body = SlidesText.parse(c.json);
        final slice = body.slice(start, end)..insert('\n');
        await SlidesSlideClipboard.put(
          store,
          SlidesClipboardCodec.copyText(
            slice,
            sourceDeckId: ed.session.deckId,
            sourceItemUuid: ed.session.itemUuid.uuid,
          ),
        );
        if (cut) {
          final next = body.compose(
            Delta()
              ..retain(start)
              ..delete(end - start),
          );
          ed.apply(ctx, SetText(c.target, SlidesText.encode(next)));
          c.selectRange(start);
        }
        return CommandResult.ok({'kind': 'text', 'length': end - start});
      case ClipboardTarget.cells:
        return _copyCells(ctx, ed, cut: cut);
      case ClipboardTarget.navigator:
        return ed.invokeCommand(
          cut ? 'slides.navigator.cut' : 'slides.navigator.copy',
          const {},
          ctx.source,
        );
      case ClipboardTarget.canvas:
        final ids = ed.selectedElementIds;
        if (ids.isEmpty) return CommandResult.failed(l.reasonSelectObject);
        final payload = SlidesClipboardCodec.copyElements(
          ed.model,
          ids,
          sourceItemUuid: ed.session.itemUuid.uuid,
        );
        _addSizes(ed, payload);
        await SlidesSlideClipboard.put(store, payload);
        _cascade[ed] = null;
        if (cut) {
          final r = await ed.invokeCommand(
            'slides.edit.delete',
            const {},
            ctx.source,
          );
          if (!r.isOk) return r;
        }
        return CommandResult.ok({
          'kind': 'elements',
          'count': (payload['elements']! as List).length,
        });
    }
  }

  /// Adds the byte sizes the device knows to the payload's `files` (the
  /// quota pre-check of a cross-deck paste, 03 §12.2).
  static void _addSizes(DeckEditorController ed, Map<String, Object?> p) {
    final files = p['files'];
    if (files is! List) return;
    final images = SlidesImageService.of(ed);
    for (final f in files) {
      if (f is! Map<String, Object?> || f['size'] != null) continue;
      final b = images.cachedBytes(
        SlideImageRef('wonky-file://${f['fileUuid']}'),
      );
      if (b != null) f['size'] = b.length;
    }
  }

  static Future<CommandResult> _copyCells(
    CommandContext ctx,
    DeckEditorController ed, {
    required bool cut,
  }) async {
    final sel = TableCellSelection.of(ed);
    final range = sel.range;
    if (range == null) return const CommandResult.failed('No cells');
    final ix = ed.model.indexes.table(range.tableId);
    final texts = <List<String?>>[];
    for (var r = range.r0; r <= range.r1; r++) {
      final row = <String?>[];
      for (var c = range.c0; c <= range.c1; c++) {
        final cell = ed.model.record(
          SlidesTables.slideTableCell,
          SlidesIds.tableCellId(range.tableId, ix.rows[r].id, ix.columns[c].id),
        );
        row.add(cell?.columns[SlidesCols.text] as String?);
      }
      texts.add(row);
    }
    String plain(String? json) => json == null
        ? ''
        : DeckClipboard._plainOf(
            json,
          ).replaceAll('\n', ' ').replaceAll('\t', ' ');
    final tsv = [for (final r in texts) r.map(plain).join('\t')].join('\n');
    final html = StringBuffer('<table><tbody>');
    for (final r in texts) {
      html.write('<tr>');
      for (final t in r) {
        final h = t == null ? '' : SlidesHtml.ofDelta(SlidesText.parse(t));
        final single = RegExp(r'^<p>(.*)</p>$').firstMatch(h);
        html.write('<td>${single?.group(1) ?? h}</td>');
      }
      html.write('</tr>');
    }
    html.write('</tbody></table>');
    await SlidesSystemClipboard.instance.write(
      SlidesClipboardData(plainText: tsv, html: html.toString()),
    );
    if (cut) {
      for (final c in range.cells(ix)) {
        ed.apply(
          ctx,
          SetText(CellText(range.tableId, c.rowId, c.columnId), null),
        );
      }
    }
    return CommandResult.ok({
      'kind': 'cells',
      'rows': range.rows,
      'columns': range.columns,
    });
  }

  static String _plainOf(String json) {
    final t = SlidesText.plainText(json);
    return t.endsWith('\n') ? t.substring(0, t.length - 1) : t;
  }

  // ------------------------------------------------------------- reading

  /// Reads the system clipboard; [blocked] when the browser refused.
  static Future<(SlidesClipboardData?, bool)> read() async {
    final cb = SlidesSystemClipboard.instance;
    try {
      final d = await cb.read();
      return (d, cb.readBlocked);
    } catch (_) {
      return (null, true);
    }
  }

  /// The Slides payload the clipboard holds: embedded in HTML, or the
  /// in-app one when the system clipboard holds its plain text (no HTML:
  /// desktop) or can't be read.
  static Future<Map<String, Object?>?> slidesPayloadOf(
    DeckEditorController ed,
    SlidesClipboardData? data,
  ) async {
    final html = data?.html;
    if (html != null) {
      final p = SlidesHtml.payloadOf(html);
      if (p != null) return p;
    }
    if (data == null || data.isEmpty) {
      return SlidesSlideClipboard.read(ed.services.userStore);
    }
    final plain = data.plainText;
    if (html == null &&
        data.image == null &&
        plain != null &&
        plain == SlidesSlideClipboard.currentPlainText) {
      return SlidesSlideClipboard.current;
    }
    return null;
  }

  static Future<List<Map<String, Object?>>?> _sheetsObjects(
    DeckEditorController ed,
    String? plain,
  ) async {
    if (plain == null || !plain.startsWith(sheetsMarker)) return null;
    final id = plain.substring(sheetsMarker.length).trim();
    try {
      final raw = await ed.services.userStore.read(sheetsObjectsKey);
      if (raw is! Map || raw['id'] != id || raw['items'] is! List) return null;
      return [
        for (final i in raw['items']! as List)
          if (i is Map) i.cast<String, Object?>(),
      ];
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- paste

  /// Pastes into [ed] (03 §12.3–§12.5): [plain] = *Paste without
  /// formatting*; [mode] = a `PasteModes` value (*Paste special*); [data]
  /// replaces the system clipboard (agents, tests).
  static Future<CommandResult> paste(
    CommandContext ctx,
    DeckEditorController ed, {
    bool plain = false,
    String? mode,
    SlidesClipboardData? data,
  }) async {
    final l = slidesL10nOf(ed.services);
    var content = data;
    if (content == null) {
      final (d, _) = await read();
      content = d;
    }
    final target = targetOf(ed);
    final payload = await slidesPayloadOf(ed, content);
    if (payload != null && !plain) {
      final kind = payload['kind'];
      if (kind == SlidesClipboardCodec.kindSlides ||
          kind == SlidesClipboardCodec.kindGroups) {
        switch (target) {
          case ClipboardTarget.text:
            return _pasteText(
              ctx,
              ed,
              SlidesDeltaNormalizer().fromPlainText(
                SlidesClipboardCodec.plainText(payload),
                lists: false,
              ),
            );
          case ClipboardTarget.cells:
            return CommandResult.failed(l.reasonPasteSlidesNotInCells);
          case ClipboardTarget.navigator || ClipboardTarget.canvas:
            return pasteSlides(ctx, ed, payload, mode: mode);
        }
      }
      if (kind == SlidesClipboardCodec.kindText) {
        final t = payload['text'];
        final delta = SlidesDeltaNormalizer()
            .normalizeValue(t is Map ? t['delta'] : null)
            .delta;
        return switch (target) {
          ClipboardTarget.text => _pasteText(ctx, ed, delta),
          ClipboardTarget.cells => _pasteGrid(ctx, ed, [
            [SlidesText.encode(delta)],
          ]),
          _ => _pasteMapped(ctx, ed, _textBox(ed, delta), origin: 'slides'),
        };
      }
      // Elements.
      switch (target) {
        case ClipboardTarget.text:
          return _pasteText(ctx, ed, _textOfElements(payload));
        case ClipboardTarget.cells:
          final grid = _gridOfPayload(payload);
          if (grid != null) return _pasteGrid(ctx, ed, grid);
          return _pasteGrid(ctx, ed, [
            [SlidesText.encode(_textOfElements(payload))],
          ]);
        case ClipboardTarget.navigator:
          if (ed.navigatorFocus.hasFocus || ed.mode == DeckViewMode.grid) {
            return CommandResult.failed(l.reasonPasteObjectsOnSlide);
          }
          return _pasteElements(ctx, ed, payload);
        case ClipboardTarget.canvas:
          return _pasteElements(ctx, ed, payload);
      }
    }
    if (content == null || content.isEmpty) {
      return CommandResult.failed(l.toastClipboardEmpty);
    }
    final text = content.plainText ?? '';
    final html = plain ? null : content.html;
    switch (target) {
      case ClipboardTarget.text:
        return _pasteText(ctx, ed, _foreignText(content, plain: plain));
      case ClipboardTarget.cells:
        final g = html == null ? null : SlidesHtml.tableOf(html);
        if (g != null) {
          return _pasteGrid(ctx, ed, _gridJson(g, ed));
        }
        return _pasteGrid(ctx, ed, [
          for (final r in SlidesPasteMappers.parseTsv(text))
            [
              for (final c in r)
                c.isEmpty
                    ? null
                    : SlidesText.encode(
                        SlidesDeltaNormalizer().fromPlainText(c, lists: false),
                      ),
            ],
        ]);
      case ClipboardTarget.navigator:
        if (ed.navigatorFocus.hasFocus || ed.mode == DeckViewMode.grid) {
          return CommandResult.failed(l.reasonClipboardNoSlides);
        }
      case ClipboardTarget.canvas:
        break;
    }
    final slide = ed.resolver.bounds;
    final ids = ed.session.planContext().ids;
    if (plain) {
      return _pasteMapped(
        ctx,
        ed,
        SlidesPasteMappers.plainText(
          text,
          slide: slide,
          ids: ids,
          lists: false,
        ),
        origin: 'text',
      );
    }
    var objects = await _sheetsObjects(ed, content.plainText);
    if (objects != null &&
        objects.isNotEmpty &&
        !SlidesFeatures.isOn(SlidesFeature.charts)) {
      // Charts in Slides are SL-32's (hidden, SL-23): Sheets images still
      // paste; charts alone are refused instead of becoming placeholders.
      objects = [
        for (final o in objects)
          if (o['kind'] != 'chart') o,
      ];
      if (objects.isEmpty) {
        return CommandResult.failed(
          slidesL10nOf(ed.services).toastPasteChartsUnavailable,
        );
      }
    }
    if (objects != null && objects.isNotEmpty) {
      return pasteSheetsObjects(
        ctx,
        ed,
        objects,
        unlinked: mode == PasteModes.unlinked,
      );
    }
    if (html != null) {
      final write = SlidesHtml.writeDeltaOf(html);
      if (write != null) {
        return _pasteMapped(
          ctx,
          ed,
          SlidesPasteMappers.writeDelta(write, slide: slide, ids: ids),
          origin: 'write',
        );
      }
    }
    final image = content.image;
    if (image != null && (html == null || !_hasText(html))) {
      final type = content.imageType ?? 'image/png';
      ImageDrops.put(ed, [
        PickedImage(
          name: 'Pasted image.${type.split('/').last}',
          bytes: image,
          mimeType: type,
        ),
      ]);
      return ed.invokeCommand('slides.insert.image', {
        'source': 'drop',
      }, ctx.source);
    }
    if (html != null && html.trim().isNotEmpty) {
      final r = SlidesPasteMappers.html(html, slide: slide, ids: ids);
      if (r.elements.isNotEmpty) {
        return _pasteMapped(ctx, ed, r, origin: 'html');
      }
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return CommandResult.failed(l.toastClipboardEmpty);
    if (text.contains('\t')) {
      final rows = SlidesPasteMappers.parseTsv(text);
      if (rows.isNotEmpty && rows.any((r) => r.length > 1)) {
        return _pasteMapped(
          ctx,
          ed,
          SlidesPasteMappers.tsv(text, slide: slide, ids: ids),
          origin: 'tsv',
        );
      }
    }
    if (_url.hasMatch(trimmed)) {
      return _pasteMapped(
        ctx,
        ed,
        _textBox(
          ed,
          Delta()
            ..insert(trimmed, {'link': trimmed})
            ..insert('\n'),
        ),
        origin: 'url',
      );
    }
    return _pasteMapped(
      ctx,
      ed,
      SlidesPasteMappers.plainText(text, slide: slide, ids: ids),
      origin: 'text',
    );
  }

  static bool _hasText(String html) {
    final stripped = html
        .replaceAll(RegExp(r'<(style|script)[^>]*>[\s\S]*?</\1>'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    return stripped.isNotEmpty || html.contains('<table');
  }

  /// The Slides Delta of foreign content for a text body.
  static Delta _foreignText(SlidesClipboardData d, {required bool plain}) {
    final n = SlidesDeltaNormalizer();
    final html = d.html;
    if (!plain && html != null) {
      final write = SlidesHtml.writeDeltaOf(html);
      if (write != null) return SlidesPasteMappers.writeText(write);
      if (_hasText(html)) {
        return SlidesPasteMappers.writeText(SlidesHtml.importHtml(html).delta);
      }
    }
    return n.fromPlainText(d.plainText ?? '', lists: false);
  }

  /// A text box element payload holding [delta].
  static PasteMapResult _textBox(DeckEditorController ed, Delta delta) {
    final body = SlidesDeltaNormalizer().normalize(delta);
    final plain = DeckClipboard._plainOf(body.json);
    final r = SlidesPasteMappers.plainText(
      plain.isEmpty ? ' ' : plain,
      slide: ed.resolver.bounds,
      ids: ed.session.planContext().ids,
      lists: false,
    );
    for (final e in r.elements) {
      e[SlidesCols.text] = body.json;
    }
    return r;
  }

  /// The text of an elements payload's top-level bodies in reading order.
  static Delta _textOfElements(Map<String, Object?> payload) {
    final out = Delta();
    final els = [
      for (final e in (payload['elements'] as List? ?? const []))
        if (e is Map<String, Object?>) e,
    ];
    final ids = {for (final e in els) e[SlidesCols.id]};
    final top = [
      for (final e in els)
        if (!ids.contains(e[SlidesCols.parentId])) e,
    ];
    String key(Map<String, Object?> e) =>
        '${e[ElementCols.readingKey] ?? e[ElementCols.zKey] ?? ''}';
    top.sort(
      (a, b) => FractionalIndex.compare(
        key(a),
        '${a[SlidesCols.id]}',
        key(b),
        '${b[SlidesCols.id]}',
      ),
    );
    void add(Map<String, Object?> e) {
      final t = e[SlidesCols.text];
      if (t is String && !SlidesText.isBlank(t)) {
        for (final op in SlidesText.parse(t).operations) {
          out.push(op);
        }
      }
      for (final c in els) {
        if (c[SlidesCols.parentId] == e[SlidesCols.id]) add(c);
      }
    }

    for (final e in top) {
      add(e);
    }
    if (out.isEmpty) {
      return SlidesDeltaNormalizer().fromPlainText(
        SlidesClipboardCodec.plainText(payload),
        lists: false,
      );
    }
    return out;
  }

  /// The cell bodies of an elements payload holding one table, row-major.
  static List<List<String?>>? _gridOfPayload(Map<String, Object?> payload) {
    final els = [
      for (final e in (payload['elements'] as List? ?? const []))
        if (e is Map<String, Object?>) e,
    ];
    if (els.length != 1 || els.single[SlidesCols.kind] != 'table') return null;
    return _cellsOf(payload, '${els.single[SlidesCols.id]}');
  }

  static List<List<String?>> _cellsOf(
    Map<String, Object?> payload,
    String tableId,
  ) {
    List<String> axes(String dim) {
      final list = [
        for (final a in (payload['tableAxes'] as List? ?? const []))
          if (a is Map &&
              a[SlidesCols.elementId] == tableId &&
              a[TableAxisCols.dimension] == dim)
            a,
      ];
      list.sort(
        (a, b) => FractionalIndex.compare(
          '${a[SlidesCols.sortKey] ?? ''}',
          '${a[SlidesCols.id]}',
          '${b[SlidesCols.sortKey] ?? ''}',
          '${b[SlidesCols.id]}',
        ),
      );
      return [for (final a in list) '${a[SlidesCols.id]}'];
    }

    final rows = axes(TableAxisDimension.row.name);
    final cols = axes(TableAxisDimension.column.name);
    final byPos = <String, String?>{
      for (final c in (payload['tableCells'] as List? ?? const []))
        if (c is Map && c[SlidesCols.elementId] == tableId)
          '${c[TableCellCols.rowId]}:${c[TableCellCols.columnId]}':
              c[SlidesCols.text] as String?,
    };
    return [
      for (final r in rows) [for (final c in cols) byPos['$r:$c']],
    ];
  }

  /// Cell bodies of an HTML grid (formatting kept) through the grid mapper.
  static List<List<String?>> _gridJson(
    List<List<GridCell>> g,
    DeckEditorController ed,
  ) {
    final r = SlidesPasteMappers.grid(
      g,
      slide: ed.resolver.bounds,
      ids: ed.session.planContext().ids,
    );
    if (r.elements.isEmpty) return const [];
    return _cellsOf(r.payload, '${r.elements.single[SlidesCols.id]}');
  }

  // ------------------------------------------------------- paste targets

  /// Rich text at the caret of the body being edited (replacing the
  /// selection) — one undo step.
  static CommandResult _pasteText(
    CommandContext ctx,
    DeckEditorController ed,
    Delta pasted,
  ) {
    final c = textEditingOf(ed).active;
    if (c == null) return const CommandResult.failed('No text is edited');
    c.commit();
    final range = c.selectionRange ?? (0, 0);
    var insert = SlidesText.normalize(pasted);
    // The last paragraph merges into the caret's paragraph.
    final ops = insert.toList();
    final last = ops.isEmpty ? null : ops.last;
    if (last != null &&
        last.data is String &&
        (last.data! as String).endsWith('\n')) {
      final t = last.data! as String;
      final trimmed = Delta();
      for (final op in ops.take(ops.length - 1)) {
        trimmed.push(op);
      }
      if (t.length > 1) {
        trimmed.insert(t.substring(0, t.length - 1), last.attributes);
      }
      insert = trimmed;
    }
    final length = insert.toList().fold<int>(
      0,
      (n, op) => n + (op.data is String ? (op.data! as String).length : 0),
    );
    final change = Delta()..retain(range.$1);
    if (range.$2 > range.$1) change.delete(range.$2 - range.$1);
    for (final op in insert.toList()) {
      change.push(op);
    }
    final body = SlidesText.parse(c.json).compose(change);
    final cell = c.target is CellText;
    ed.apply(
      ctx,
      SetText(
        c.target,
        SlidesText.encode(SlidesText.normalize(body, notes: false)),
      ),
    );
    c.selectRange(range.$1 + length);
    return CommandResult.ok({'kind': 'text', 'length': length, 'cell': cell});
  }

  /// Fills the selected cells from their top-left cell with [grid] (cell
  /// bodies; a single value fills the whole range), clipped to the table —
  /// one undo step (03 §12.3 "Table cell range").
  static CommandResult _pasteGrid(
    CommandContext ctx,
    DeckEditorController ed,
    List<List<String?>> grid,
  ) {
    final l = slidesL10nOf(ed.services);
    final sel = TableCellSelection.of(ed);
    final range = sel.range;
    if (range == null || grid.isEmpty || grid.first.isEmpty) {
      return CommandResult.failed(l.toastClipboardEmpty);
    }
    final ix = ed.model.indexes.table(range.tableId);
    final single = grid.length == 1 && grid.first.length == 1;
    final rows = single ? range.rows : grid.length;
    final cols = single
        ? range.columns
        : grid.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    var clipped = false;
    var written = 0;
    var r1 = range.r0, c1 = range.c0;
    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < cols; j++) {
        final r = range.r0 + i, c = range.c0 + j;
        if (r >= ix.rows.length || c >= ix.columns.length) {
          clipped = true;
          continue;
        }
        final m = ix.mergeAt(r, c);
        if (m != null && (m.row != r || m.column != c)) continue;
        final json = single
            ? grid.first.first
            : (j < grid[i].length ? grid[i][j] : null);
        ed.apply(
          ctx,
          SetText(
            CellText(range.tableId, ix.rows[r].id, ix.columns[c].id),
            json,
          ),
        );
        written++;
        if (r > r1) r1 = r;
        if (c > c1) c1 = c;
      }
    }
    sel.select(
      range.tableId,
      (rowId: ix.rows[range.r0].id, columnId: ix.columns[range.c0].id),
      (rowId: ix.rows[r1].id, columnId: ix.columns[c1].id),
    );
    if (clipped && !ctx.source.isAgent) {
      ed.services.toasts.show(l.toastPasteClipped);
    }
    return CommandResult.ok({
      'kind': 'cells',
      'cells': written,
      'clipped': clipped,
    });
  }

  static final Expando<(int, String, int)> _cascade = Expando(
    'slidesPasteCascade',
  );

  /// Elements of a Slides payload on the current slide (03 §12.3): same
  /// positions on another slide, +32 su cascading on the source slide;
  /// files re-homed when the payload comes from another deck.
  static Future<CommandResult> _pasteElements(
    CommandContext ctx,
    DeckEditorController ed,
    Map<String, Object?> payload,
  ) async {
    final l = slidesL10nOf(ed.services);
    final slideId = ed.currentSlideId;
    if (slideId == null) return CommandResult.failed(l.reasonNoSlides);
    final source =
        (payload['sourceItemUuid'] ?? payload['sourceDeckId']) as String?;
    final cross =
        source != ed.session.itemUuid.uuid && source != ed.session.deckId;
    var p = SlidesSlideClipboard.copyOf(payload);
    if (cross) {
      final prepared = await prepareFiles(ctx, ed, p);
      if (prepared == null) return const CommandResult.cancelled();
      p = prepared;
    }
    // Repeated pastes onto the source slide cascade (+32 su each).
    double? atX, atY;
    final sameSlide = !cross && payload['sourceSlideId'] == slideId;
    if (sameSlide) {
      // Repeated pastes onto the source slide cascade (+32 su each); after
      // a cut (the copied objects are gone) the first one lands in place.
      final prev = _cascade[ed];
      final hash = SlidesClipboardCodec.encode(payload).hashCode;
      final n = prev != null && prev.$1 == hash && prev.$2 == slideId
          ? prev.$3 + 1
          : 1;
      _cascade[ed] = (hash, slideId, n);
      final cutAway = !(payload['elements'] as List? ?? const []).any(
        (e) => e is Map && ed.model.element('${e[SlidesCols.id]}') != null,
      );
      final box = _boundsOf(payload);
      if (box != null) {
        final off = 32.0 * (cutAway ? n - 1 : n);
        atX = box.x + off;
        atY = box.y + off;
      }
    }
    final plan = ed.apply(ctx, PasteElements(p, slideId, atX: atX, atY: atY));
    final created = (plan.result['elementIds'] as List? ?? const [])
        .whereType<String>()
        .toList();
    selectionOf(ed).select(created);
    return CommandResult.ok({
      'kind': 'elements',
      'elementIds': created,
      'crossDeck': cross,
    });
  }

  static SuRect? _boundsOf(Map<String, Object?> payload) {
    final els = [
      for (final e in (payload['elements'] as List? ?? const []))
        if (e is Map<String, Object?>) e,
    ];
    final ids = {for (final e in els) e[SlidesCols.id]};
    return unionRects([
      for (final e in els)
        if (!ids.contains(e[SlidesCols.parentId]))
          if ((
                e[ElementCols.x],
                e[ElementCols.y],
                e[ElementCols.width],
                e[ElementCols.height],
              )
              case (final num x, final num y, final num w, final num h))
            SuRect(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
    ]);
  }

  /// Mapped foreign content (Write, Sheets, HTML, text) on the current
  /// slide: uploaded files of other items are re-homed (cross-app).
  static Future<CommandResult> _pasteMapped(
    CommandContext ctx,
    DeckEditorController ed,
    PasteMapResult r, {
    required String origin,
  }) async {
    final l = slidesL10nOf(ed.services);
    final slideId = ed.currentSlideId;
    if (slideId == null) return CommandResult.failed(l.reasonNoSlides);
    if (r.elements.isEmpty) return CommandResult.failed(l.toastClipboardEmpty);
    final p = await prepareFiles(ctx, ed, r.payload);
    if (p == null) return const CommandResult.cancelled();
    final plan = ed.apply(ctx, PasteElements(p, slideId));
    final created = (plan.result['elementIds'] as List? ?? const [])
        .whereType<String>()
        .toList();
    selectionOf(ed).select(created);
    if (r.warnings.contains(PasteMapResult.truncated) && !ctx.source.isAgent) {
      ed.services.toasts.show(l.toastPasteTruncated);
    }
    return CommandResult.ok({
      'kind': 'elements',
      'origin': origin,
      'elementIds': created,
      'warnings': r.warnings,
    });
  }

  /// Slides and groups (04 §5.8) through the navigator's paste (its
  /// insertion point and selection rules); re-homing and the chip happen
  /// there ([afterSlidesPaste]).
  static Future<CommandResult> pasteSlides(
    CommandContext ctx,
    DeckEditorController ed,
    Map<String, Object?> payload, {
    String? mode,
  }) {
    SlidesSlideClipboard.adopt(payload);
    return ed.invokeCommand('slides.navigator.paste', {
      'themeMode': mode == PasteModes.keepSource
          ? PasteModes.keepSource
          : PasteModes.useDestination,
    }, ctx.source);
  }

  /// Whether a slides payload comes from another deck.
  static bool isCrossDeck(DeckEditorController ed, Map<String, Object?> p) {
    final source = (p['sourceItemUuid'] ?? p['sourceDeckId']) as String?;
    return source != ed.session.itemUuid.uuid && source != ed.session.deckId;
  }

  /// After a slides paste: the paste options chip for cross-deck pastes
  /// (*Use destination theme* / *Keep source formatting*).
  static void afterSlidesPaste(
    CommandContext ctx,
    DeckEditorController ed,
    Map<String, Object?> original,
    String mode,
  ) {
    if (!isCrossDeck(ed, original) || ctx.source.isAgent) return;
    if ((original['themes'] as List? ?? const []).isEmpty) return;
    PasteOptions.of(ed).show(
      PasteOptionsState(
        kind: 'slides',
        modes: const [PasteModes.useDestination, PasteModes.keepSource],
        current: mode,
        source: original,
      ),
    );
  }

  /// Sheets objects (charts → linked charts unless [unlinked], images) on
  /// the current slide, stacked; the chip offers *Paste unlinked*.
  static Future<CommandResult> pasteSheetsObjects(
    CommandContext ctx,
    DeckEditorController ed,
    List<Map<String, Object?>> items, {
    bool unlinked = false,
  }) async {
    final l = slidesL10nOf(ed.services);
    final slideId = ed.currentSlideId;
    if (slideId == null) return CommandResult.failed(l.reasonNoSlides);
    final ids = ed.session.planContext().ids;
    final created = <String>[];
    var charts = 0;
    SuRect? bounds;
    for (final (i, item) in items.indexed) {
      final r = SlidesPasteMappers.sheetsObject(
        item,
        slide: ed.resolver.bounds,
        userId: ed.session.userId,
        now: clock.now().toUtc(),
        ids: ids,
        unlinked: unlinked,
      );
      if (r.elements.isEmpty) continue;
      if (item['kind'] == 'chart') charts++;
      final p = await prepareFiles(ctx, ed, r.payload);
      if (p == null) return const CommandResult.cancelled();
      final box = _boundsOf(p);
      final plan = ed.apply(
        ctx,
        PasteElements(
          p,
          slideId,
          atX: box == null ? null : box.x + 32.0 * i,
          atY: box == null ? null : box.y + 32.0 * i,
        ),
      );
      created.addAll(
        (plan.result['elementIds'] as List? ?? const []).whereType<String>(),
      );
      if (box != null) {
        bounds = SuRect(
          box.x + 32.0 * i,
          box.y + 32.0 * i,
          box.width,
          box.height,
        );
      }
    }
    if (created.isEmpty) return CommandResult.failed(l.toastClipboardEmpty);
    selectionOf(ed).select(created);
    final linkable = items.any(
      (i) =>
          i['kind'] == 'chart' &&
          i['spreadsheetItemUuid'] is String &&
          i['objectId'] is String,
    );
    if (charts > 0 && linkable && !ctx.source.isAgent) {
      PasteOptions.of(ed).show(
        PasteOptionsState(
          kind: 'sheetsChart',
          modes: const [PasteModes.linked, PasteModes.unlinked],
          current: unlinked ? PasteModes.unlinked : PasteModes.linked,
          source: items,
          bounds: bounds,
        ),
      );
    }
    return CommandResult.ok({
      'kind': 'elements',
      'origin': 'sheets',
      'elementIds': created,
      'linked': !unlinked && linkable,
    });
  }

  // ------------------------------------------------------------ files

  /// Re-homes the uploaded files [payload] references into this deck (03
  /// §12.3, A-03-3): new file uuids (deterministic per deck and source
  /// file, so a re-run of the same paste reuses the copies) are written
  /// into the rows and the copies are queued ([SlidesRehomeQueue]). The
  /// bytes the device knows are pre-checked against the deck owner's
  /// quota; null = refused (the dialog was shown).
  static Future<Map<String, Object?>?> prepareFiles(
    CommandContext ctx,
    DeckEditorController ed,
    Map<String, Object?> payload,
  ) async {
    final files = SlidesClipboardCodec.fileUuids(payload).toList();
    if (files.isEmpty) return payload;
    final target = ed.session.itemUuid.uuid;
    final s = ed.services;
    // Bytes known on this device (payload sizes, cached images).
    final sizes = <String, int>{};
    for (final f in (payload['files'] as List? ?? const [])) {
      if (f is Map && f['fileUuid'] is String && f['size'] is num) {
        sizes[f['fileUuid'] as String] = (f['size'] as num).toInt();
      }
    }
    final images = SlidesImageService.of(ed);
    var bytes = 0;
    for (final f in files) {
      bytes +=
          sizes[f] ??
          images.cachedBytes(SlideImageRef('wonky-file://$f'))?.length ??
          0;
    }
    if (bytes > 0 &&
        !ctx.source.isAgent &&
        !await s.storageChecks.ensureRoom(
          bytes,
          reason: QuotaReasons.image,
          item: s.currentItem.value,
        )) {
      return null;
    }
    final newIds = [
      for (final f in files) SlidesIds.themePartId(target, 'file:$f'),
    ];
    final (out, copies) = SlidesClipboardCodec.rehomeFiles(
      payload,
      ids: _ListIds(newIds),
    );
    final queue = SlidesRehomeQueue.of(s);
    if (queue != null) {
      unawaited(queue.add(copies, target));
    } else {
      // No queue (signed out, tests without one): copy directly.
      final copier = SlidesRehomeQueue.serverCopier(s);
      for (final c in copies) {
        unawaited(
          copier(
            RehomeJob(
              sourceFileUuid: c.sourceFileUuid,
              newFileUuid: c.newFileUuid,
              targetItemUuid: target,
            ),
          ).catchError((Object _) {}),
        );
      }
    }
    return out;
  }

  /// `slides.edit.pasteSpecial`: re-runs the last paste (when its undo
  /// step is still the newest) in [mode], replacing that step; otherwise
  /// pastes the clipboard in [mode].
  static Future<CommandResult> pasteSpecial(
    CommandContext ctx,
    DeckEditorController ed,
    String mode,
  ) async {
    final chip = PasteOptions.of(ed);
    final replace = chip.state != null && chip.isTopStep;
    final state = chip.take();
    if (replace && state != null) {
      await ed.services.undo.undo();
      if (state.kind == 'sheetsChart') {
        return pasteSheetsObjects(
          ctx,
          ed,
          (state.source as List).cast<Map<String, Object?>>(),
          unlinked: mode == PasteModes.unlinked,
        );
      }
      return pasteSlides(
        ctx,
        ed,
        (state.source as Map).cast<String, Object?>(),
        mode: mode,
      );
    }
    return paste(ctx, ed, mode: mode);
  }

  /// Decodes `slides.edit.paste` content args (agents): `html`, `text`.
  static SlidesClipboardData? dataOf(JsonArgs a) {
    final html = a.string('html'), text = a.string('text');
    final image = a.string('imageBase64');
    if (html == null && text == null && image == null) return null;
    return SlidesClipboardData(
      plainText: text,
      html: html,
      image: image == null ? null : base64Decode(image),
      imageType: image == null ? null : (a.string('imageType') ?? 'image/png'),
    );
  }
}

/// Hands out given ids in order (the deterministic re-homing uuids).
class _ListIds implements IdGenerator {
  _ListIds(this.ids);

  final List<String> ids;
  int _n = 0;

  @override
  String newId() => ids[_n++];
}
