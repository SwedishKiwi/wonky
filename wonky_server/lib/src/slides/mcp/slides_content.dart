import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:serverpod/serverpod.dart';
import 'package:wonky_slides_core/code.dart' show CodeElementData;
import 'package:wonky_slides_core/markdown.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../../platform/common/models.dart';
import '../../platform/files/file_service.dart';
import '../../platform/mcp/tool_support.dart';
import '../headless/headless_deck.dart';
import 'slides_input.dart';
import 'slides_mcp_support.dart';
import 'slides_writes.dart';

/// An image ready to be placed in a deck: a stored file of the deck's item
/// (copied there when it came from elsewhere) and its natural size.
class PreparedImage {
  const PreparedImage({
    required this.src,
    required this.width,
    required this.height,
    this.fileName,
    this.mimeType,
    this.copied = false,
  });

  /// `wonky-file://<uuid>`.
  final String src;
  final int width;
  final int height;
  final String? fileName;
  final String? mimeType;

  /// Whether the file was copied into the deck (bytes were added).
  final bool copied;

  /// The image element's `dataJson`.
  Map<String, Object?> data({
    Map<String, Object?>? crop,
    String? mask,
  }) => {
    'v': 1,
    'src': src,
    'naturalWidth': width,
    'naturalHeight': height,
    'fileName': ?fileName,
    'mimeType': ?mimeType,
    'crop': ?crop,
    'mask': ?mask,
  };
}

/// One slide to add (`slides.add_slides`, outline slides).
class SlideInput {
  SlideInput({required this.pointer});

  final String pointer;
  String? layout;
  Object? title;
  Object? body;
  Object? body2;
  Map<String, Object?> placeholders = const {};
  Object? notes;
  Object? background;
  bool? skipped;
  Map<String, Object?>? transition;
  String? transitionType;
  List<OutlineCode> code = const [];
  List<List<List<String>>> tables = const [];
  List<(PreparedImage, String?)> images = const [];

  /// Outline groups: the title of the group this slide starts (or `none`
  /// to leave grouping), and its color.
  String? groupTitle;
  String? groupColor;
  bool groupNone = false;
}

/// Builds slide content with the shared operations (11 §3.6, §3.3): new
/// slides with a layout, placeholder text, notes, background, transition,
/// code blocks, tables and images — every step through [DeckSteps].
abstract final class SlidesContent {
  /// Copies [fileUuid] into the deck when needed and reads its size
  /// (11 §3.8: only files the caller can read).
  static Future<PreparedImage> prepareImage(
    ToolContext ctx,
    SlidesTarget t,
    String fileUuid, {
    required String pointer,
  }) async {
    final UuidValue uuid;
    try {
      uuid = UuidValue.withValidation(fileUuid.toLowerCase());
    } on FormatException {
      throw SlidesMcp.invalid(
        '"$fileUuid" is not a file uuid.',
        pointer: pointer,
      );
    }
    var file = await FileService.byUuid(ctx.session, uuid);
    if (file == null) {
      // A Drive file item uuid names its current content.
      final item = await DriveItem.db.findFirstRow(
        ctx.session,
        where: (t) => t.uuid.equals(uuid) & t.kind.equals(DriveItemKind.file),
      );
      if (item?.contentRef != null) {
        file = await FileService.byUuid(ctx.session, item!.contentRef!);
      }
    }
    if (file == null ||
        !await FileService.canRead(ctx.session, ctx.actor, file)) {
      throw McpToolException(
        McpErrorCode.notFound,
        'Image file $fileUuid not found or not readable.',
        details: {'pointer': pointer},
      );
    }
    var copied = false;
    if (file.itemId != t.item.id) {
      final view = await FileService.copyToItem(
        ctx.session,
        ctx.actor,
        sourceFileUuid: file.fileUuid,
        newFileUuid: const Uuid().v4obj(),
        targetItemUuid: t.item.uuid,
      );
      file = (await FileService.byUuid(ctx.session, view.fileUuid))!;
      copied = true;
    }
    var w = 1000, h = 1000;
    if (file.mimeType != 'image/svg+xml') {
      try {
        final data = await FileService.readBytes(ctx.session, file);
        final bytes = Uint8List.view(
          data.buffer,
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final info = img.findDecoderForData(bytes)?.startDecode(bytes);
        if (info != null && info.width > 0 && info.height > 0) {
          w = info.width;
          h = info.height;
        }
      } on Object {
        // Unknown size: a square.
      }
    }
    return PreparedImage(
      src: 'wonky-file://${file.fileUuid.uuid}',
      width: w,
      height: h,
      fileName: file.fileName,
      mimeType: file.mimeType,
      copied: copied,
    );
  }

  /// [image] fitted into [box] (contain, centered).
  static SuRect fit(PreparedImage image, SuRect box) {
    final s = [box.width / image.width, box.height / image.height].reduce(
      (a, b) => a < b ? a : b,
    );
    final w = image.width * s, h = image.height * s;
    return SuRect(
      box.x + (box.width - w) / 2,
      box.y + (box.height - h) / 2,
      w,
      h,
    );
  }

  // ------------------------------------------------------------- targets

  /// The `SlideTarget` of an `at` argument (11 §3.6) inside [groupId]
  /// when given.
  static SlideTarget target(
    DeckModel m,
    Map<String, Object?>? at, {
    String? groupId,
  }) {
    String? before, after;
    if (at != null) {
      final pos = (at['position'] as num?)?.toInt();
      if (pos != null) {
        final slides = m.slides;
        if (pos <= slides.length) before = slides[pos - 1].id;
      } else if (at['after'] != null) {
        after = SlidesMcp.slideId(m, at['after'], pointer: '/at/after');
      } else if (at['before'] != null) {
        before = SlidesMcp.slideId(m, at['before'], pointer: '/at/before');
      }
    }
    final ref = before ?? after;
    final refGroup = ref == null ? null : m.slide(ref)?.groupId;
    if (groupId != null) {
      return refGroup == groupId
          ? InGroup(groupId, beforeId: before, afterId: after)
          : InGroup(groupId);
    }
    if (refGroup != null) {
      return InGroup(refGroup, beforeId: before, afterId: after);
    }
    return TopLevel(beforeId: before, afterId: after);
  }

  /// Right after [slideId], in its container.
  static SlideTarget after(DeckModel m, String slideId) {
    final g = m.slide(slideId)?.groupId;
    return g == null
        ? TopLevel(afterId: slideId)
        : InGroup(g, afterId: slideId);
  }

  // ------------------------------------------------------------- slides

  /// Adds [slides] at [start] (each after the previous); returns the new
  /// slide ids. Outline groups become slide groups.
  static List<String> addSlides(
    DeckSteps s,
    List<SlideInput> slides, {
    required SlideTarget start,
    required List<SlidesWarning> warnings,
  }) {
    final ids = <String>[];
    SlideTarget target = start;
    for (final input in slides) {
      final id = addSlide(s, input, target: target, warnings: warnings);
      ids.add(id);
      target = after(s.model, id);
    }
    // Outline groups (11 §3.3): a group directive starts a group that runs
    // until the next directive or `group: none`.
    final runs = <(String, String?, List<String>)>[];
    (String, String?, List<String>)? open;
    for (final (i, input) in slides.indexed) {
      if (input.groupNone) {
        open = null;
      } else if (input.groupTitle != null) {
        open = (input.groupTitle!, input.groupColor, <String>[]);
        runs.add(open);
      }
      open?.$3.add(ids[i]);
    }
    for (final (title, color, members) in runs) {
      s.run(CreateGroup(members, title: title, color: color));
    }
    return ids;
  }

  /// Adds one slide with its content at [target].
  static String addSlide(
    DeckSteps s,
    SlideInput input, {
    required SlideTarget target,
    required List<SlidesWarning> warnings,
  }) {
    final m = s.model;
    final p = input.pointer;
    SlideLayoutRec? layout;
    if (input.layout != null) {
      layout = SlidesMcp.layout(m, input.layout!);
      if (layout == null) {
        warnings.add(
          SlidesWarning(
            'layout_fallback',
            'Layout "${input.layout}" not found; used titleBody. Layouts: '
                '${SlidesMcp.layoutKeys(m).join(', ')}.',
            pointer: '$p/layout',
          ),
        );
      }
    }
    layout ??= SlidesMcp.layout(m, 'titleBody');
    final plan = s.run(AddSlides(layoutId: layout?.id, target: target));
    final slideId = (plan.result['slideIds']! as List).single as String;
    fill(s, slideId, input, warnings: warnings);
    return slideId;
  }

  /// Fills a (new) slide's placeholders and properties from [input].
  static void fill(
    DeckSteps s,
    String slideId,
    SlideInput input, {
    required List<SlidesWarning> warnings,
  }) {
    final m = s.model;
    final p = input.pointer;
    final layoutKey = m.layout(m.slide(slideId)!.layoutId ?? '')?.key;
    List<SlideElementRec> ph(SlidePlaceholderType t) =>
        SlidesMcp.placeholders(m, slideId, t);
    final used = <String>{};

    void setText(String elementId, Object? text, String pointer) {
      final delta = SlidesInput.text(
        m,
        text,
        pointer: pointer,
        warnings: warnings,
        elementId: elementId,
      );
      s.run(SetText(ElementText(elementId), delta));
      used.add(elementId);
    }

    String? first(List<SlidePlaceholderType> types) {
      for (final t in types) {
        for (final e in ph(t)) {
          if (!used.contains(e.id)) return e.id;
        }
      }
      return null;
    }

    if (input.title != null) {
      final id = first([SlidePlaceholderType.title]);
      if (id != null) {
        setText(id, input.title, '$p/title');
      } else {
        _textBox(s, slideId, input.title, '$p/title', 'title', warnings);
      }
    }
    if (input.body != null) {
      final body = input.body;
      // A big number / quote layout: the first line goes to the big number
      // or quote, the rest to the caption or attribution.
      if ((layoutKey == 'bigNumber' || layoutKey == 'quote') &&
          body is String) {
        final lines = body.trim().split('\n');
        final main = layoutKey == 'bigNumber'
            ? SlidePlaceholderType.bigNumber
            : SlidePlaceholderType.quote;
        final rest = layoutKey == 'bigNumber'
            ? SlidePlaceholderType.caption
            : SlidePlaceholderType.attribution;
        final a = first([main]);
        if (a != null) {
          setText(a, lines.first.replaceFirst(RegExp(r'^>\s?'), ''), '$p/body');
          final tail = lines.skip(1).join('\n').trim();
          final b = first([rest]);
          if (tail.isNotEmpty && b != null) {
            setText(b, tail.replaceFirst(RegExp(r'^[—–-]\s*'), ''), '$p/body');
          }
        }
      } else {
        final id = first([
          SlidePlaceholderType.body,
          SlidePlaceholderType.subtitle,
          SlidePlaceholderType.caption,
          SlidePlaceholderType.quote,
          SlidePlaceholderType.bigNumber,
        ]);
        if (id != null) {
          setText(id, body, '$p/body');
        } else {
          _textBox(s, slideId, body, '$p/body', null, warnings);
        }
      }
    }
    if (input.body2 != null) {
      final id = first([SlidePlaceholderType.body]);
      if (id != null) {
        setText(id, input.body2, '$p/body');
      } else {
        _textBox(s, slideId, input.body2, '$p/body', null, warnings);
      }
    }
    for (final MapEntry(:key, :value) in input.placeholders.entries) {
      final parts = key.split(':');
      final type = SlidePlaceholderType.fromName(parts.first);
      final n = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
      final list = type == null ? const <SlideElementRec>[] : ph(type);
      if (n < 1 || n > list.length) {
        throw McpToolException(
          McpErrorCode.notFound,
          'The layout has no "$key" placeholder.',
          details: {'pointer': '$p/placeholders/$key'},
        );
      }
      setText(list[n - 1].id, value, '$p/placeholders/$key');
    }
    final props = SetSlideProps(
      [slideId],
      skipped: input.skipped,
      notes: input.notes == null
          ? null
          : Patch(
              SlidesInput.text(
                m,
                input.notes,
                notes: true,
                pointer: '$p/notes',
                warnings: warnings,
              ),
            ),
      backgroundJson: input.background == null
          ? null
          : Patch(
              SlidesInput.background(
                input.background,
                pointer: '$p/background',
              ),
            ),
      transitionJson: input.transition != null
          ? Patch(SlidesInput.transitionJson(input.transition!))
          : input.transitionType != null
          ? Patch(TransitionSpec.of(input.transitionType!).encode())
          : null,
    );
    if (props.skipped != null ||
        props.notes != null ||
        props.backgroundJson != null ||
        props.transitionJson != null) {
      s.run(props);
    }
    for (final c in input.code) {
      final holder = first([SlidePlaceholderType.code]);
      if (holder != null && m.codeStatesOf(holder).isEmpty) {
        used.add(holder);
        s.run(
          SetElementData(
            holder,
            jsonEncode(
              CodeElementData.fromJson({
                'v': 1,
                'language': normalizeLanguage(c.language),
              }).toJson(),
            ),
          ),
        );
        s.run(
          AddCodeStates(holder, [
            {CodeStateCols.code: c.code},
          ]),
        );
        continue;
      }
      final area = _area(s, slideId, used, [SlidePlaceholderType.body]);
      s.run(
        InsertElements(slideId, [
          codeSpec(
            area,
            language: c.language,
            states: [
              {CodeStateCols.code: c.code},
            ],
          ),
        ]),
      );
    }
    for (final rows in input.tables) {
      if (rows.isEmpty) continue;
      final area = _area(s, slideId, used, [
        SlidePlaceholderType.table,
        SlidePlaceholderType.body,
      ]);
      insertTable(
        s,
        slideId,
        area,
        rows,
        pointer: '$p/table',
        warnings: warnings,
      );
    }
    for (final (image, alt) in input.images) {
      final area = _area(s, slideId, used, [
        SlidePlaceholderType.picture,
        SlidePlaceholderType.body,
      ]);
      final f = fit(image, area);
      s.run(
        InsertElements(slideId, [
          ElementSpec(
            kind: ElementKind.image,
            x: f.x,
            y: f.y,
            width: f.width,
            height: f.height,
            columns: {
              ElementCols.dataJson: jsonEncode(image.data()),
              if (alt != null && alt.trim().isNotEmpty)
                ElementCols.altText: alt.trim(),
            },
          ),
        ]),
      );
    }
  }

  /// A text box for text without a placeholder (top band for titles, the
  /// body area otherwise).
  static void _textBox(
    DeckSteps s,
    String slideId,
    Object? text,
    String pointer,
    String? style,
    List<SlidesWarning> warnings,
  ) {
    final (sw, sh) = SlidesInput.slideSize(s.model);
    final box = style == 'title'
        ? SuRect(sw * 0.0625, sh * 0.0667, sw * 0.875, sh * 0.1333)
        : SuRect(sw * 0.0625, sh * 0.2444, sw * 0.875, sh * 0.6667);
    final delta = SlidesInput.text(
      s.model,
      text,
      pointer: pointer,
      warnings: warnings,
    );
    s.run(
      InsertElements(slideId, [
        ElementSpec(
          kind: ElementKind.text,
          x: box.x,
          y: box.y,
          width: box.width,
          height: box.height,
          columns: {
            SlidesCols.text: delta,
            ElementCols.textStyleJson: jsonEncode({
              'v': 1,
              'autofit': 'shrink',
              if (style != null) 'defaults': {'style': style},
            }),
          },
        ),
      ]),
    );
  }

  /// The resolved frame of the first unused, empty placeholder of [types]
  /// on [slideId] — the placeholder is deleted (its content area is
  /// taken) — else the body area of the slide.
  static SuRect _area(
    DeckSteps s,
    String slideId,
    Set<String> used,
    List<SlidePlaceholderType> types,
  ) {
    final rs = SlideResolver(s.model).resolve(slideId);
    for (final t in types) {
      for (final e in rs?.elements ?? const <ResolvedElement>[]) {
        if (e.placeholderType != t || used.contains(e.id)) continue;
        if (!SlidesText.isBlank(e.text)) continue;
        used.add(e.id);
        final frame = e.frame;
        s.run(DeleteElements([e.id]));
        return frame;
      }
    }
    final (sw, sh) = SlidesInput.slideSize(s.model);
    return SuRect(sw * 0.0625, sh * 0.2444, sw * 0.875, sh * 0.6667);
  }

  /// A code element spec in [frame] (07 §3; the app's insert defaults).
  static ElementSpec codeSpec(
    SuRect frame, {
    required String language,
    required List<Map<String, Object?>> states,
    Map<String, Object?> options = const {},
  }) => ElementSpec(
    kind: ElementKind.code,
    x: frame.x,
    y: frame.y,
    width: frame.width,
    height: frame.height,
    columns: {
      ElementCols.dataJson: jsonEncode(
        CodeElementData.fromJson({
          'v': 1,
          ...options,
          'language': normalizeLanguage(language),
        }).toJson(),
      ),
    },
    codeStates: states,
  );

  /// A code language id (lower case, common aliases).
  static String normalizeLanguage(String language) {
    final l = language.trim().toLowerCase();
    return switch (l) {
      '' => 'plaintext',
      'js' => 'javascript',
      'ts' => 'typescript',
      'py' => 'python',
      'sh' || 'shell' || 'zsh' => 'bash',
      'yml' => 'yaml',
      'md' => 'markdown',
      'c++' => 'cpp',
      'c#' || 'cs' => 'csharp',
      'kt' => 'kotlin',
      'rb' => 'ruby',
      'rs' => 'rust',
      _ => l,
    };
  }

  /// Inserts a table of [rows] (inline-Markdown / `TextInput` cells) in
  /// [frame]; the first row is the header. Returns the element id.
  static String insertTable(
    DeckSteps s,
    String slideId,
    SuRect frame,
    List<List<Object?>> rows, {
    bool headerRow = true,
    List<num>? columnWidths,
    required String pointer,
    required List<SlidesWarning> warnings,
  }) {
    final columns = rows.fold<int>(0, (a, r) => r.length > a ? r.length : a);
    final plan = s.run(
      InsertElements(slideId, [
        ElementSpec(
          kind: ElementKind.table,
          x: frame.x,
          y: frame.y,
          width: frame.width,
          height: frame.height,
          tableRows: rows.length,
          tableColumns: columns < 1 ? 1 : columns,
          columns: {
            ElementCols.dataJson: jsonEncode({
              'v': 1,
              'style': 'theme',
              'options': {'headerRow': headerRow, 'bandedRows': true},
            }),
          },
        ),
      ]),
    );
    final id = (plan.result['elementIds']! as List).first as String;
    final m = s.model;
    final rowAxes = m.axesOf(id, TableAxisDimension.row);
    final colAxes = m.axesOf(id, TableAxisDimension.column);
    final writes = <CellWrite>[
      for (final (r, row) in rows.indexed)
        for (final (c, cell) in row.indexed)
          if (cell != null && !(cell is String && cell.isEmpty))
            CellWrite(rowAxes[r].id, colAxes[c].id, {
              SlidesCols.text: SlidesInput.text(
                m,
                cell,
                pointer: '$pointer/rows/$r/$c',
                warnings: warnings,
              ),
            }),
    ];
    if (writes.isNotEmpty) s.run(SetCells(id, writes));
    if (columnWidths != null && columnWidths.isNotEmpty) {
      s.run(
        ResizeTableAxes(id, {
          for (final (i, w) in columnWidths.indexed)
            if (i < colAxes.length) colAxes[i].id: w.toDouble(),
        }),
      );
    }
    return id;
  }

  /// The slide inputs of an outline (images prepared by the caller).
  static List<SlideInput> fromOutline(
    DeckOutline outline,
    Map<String, PreparedImage> images,
  ) => [
    for (final (i, o) in outline.slides.indexed)
      SlideInput(pointer: '/markdown/slides/$i')
        ..layout = o.inferLayout(first: i == 0)
        ..title = o.title
        ..body = o.body().isEmpty ? null : o.body()
        ..body2 = o.columns.length > 1 && o.body(1).isNotEmpty
            ? o.body(1)
            : null
        ..notes = o.notes
        ..skipped = o.skipped ? true : null
        ..transitionType = o.transition
        ..code = o.code
        ..tables = o.tables
        ..images = [
          for (final im in o.images)
            if (images[im.fileUuid] case final PreparedImage p) (p, im.alt),
        ]
        ..groupTitle = o.groupTitle
        ..groupColor = o.groupColor
        ..groupNone = o.groupNone,
  ];
}
