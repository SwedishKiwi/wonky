import 'dart:convert';

import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_sync_models/ids.dart';

import '../copy/id_remapper.dart';
import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../model/index/deck_indexes.dart';
import '../model/text/slides_text.dart';
import '../ops/plan_context.dart';
import '../schema/slides_schema.dart';
import '../text/slides_delta.dart';
import '../theme/layout/placeholder_type.dart';
import '../theme/model/common.dart';
import 'slides_html.dart';

/// The Wonky Slides clipboard payload `application/x-wonky-slides` v1
/// (03 §12.2): built from a deck selection on copy, parsed and sanitized on
/// paste (the payload may come from another tab, deck or user), plus the
/// `text/plain` and Markdown representations (03 §12.1) and the file
/// re-homing of cross-deck pastes (03 §12.3).
///
/// The planner's `PasteSlides` / `PasteElements` consume [decode]d
/// payloads and remap every id (fresh and deterministic ids); match keys
/// are kept. Payload rows are column maps of the synced tables with
/// JSON-safe values (UUIDs as strings, times as ISO 8601).
abstract final class SlidesClipboardCodec {
  /// `format` of the payload.
  static const format = 'wonky-slides-clipboard';

  /// Payload version.
  static const version = 1;

  /// MIME type of the lossless representation.
  static const mimeType = 'application/x-wonky-slides';

  /// Kinds of payload.
  static const kindElements = 'elements';
  static const kindSlides = 'slides';
  static const kindGroups = 'groups';
  static const kindText = 'text';
  static const kinds = {kindElements, kindSlides, kindGroups, kindText};

  /// Max rows of one payload (all lists together).
  static const maxRows = 200000;

  // -------------------------------------------------------------- building

  /// The payload of elements [elementIds] of one owner (slide, layout or
  /// master; ids of other owners are ignored) with their descendants,
  /// table axes and cells, code states, chart links and builds. Placeholder
  /// instances get their effective frame, so they paste in place in any
  /// deck.
  static Map<String, Object?> copyElements(
    DeckModel deck,
    List<String> elementIds, {
    String? sourceItemUuid,
  }) {
    final selected = [for (final id in elementIds) ?deck.element(id)];
    if (selected.isEmpty) return _empty(deck, kindElements, sourceItemUuid);
    final owner = selected.first.ownerId;
    final all = owner == null
        ? <SlideElementRec>[]
        : deck.allElementsOf(owner).toList();
    final byParent = <String?, List<SlideElementRec>>{};
    for (final e in all) {
      byParent.putIfAbsent(e.parentId, () => []).add(e);
    }
    final chosen = {
      for (final e in selected)
        if (e.ownerId == owner) e.id,
    };
    // Drop selected elements whose ancestor is selected too.
    bool hasSelectedAncestor(SlideElementRec e) {
      var p = e.parentId;
      final seen = <String>{};
      while (p != null && seen.add(p)) {
        if (chosen.contains(p)) return true;
        p = deck.element(p)?.parentId;
      }
      return false;
    }

    final roots = [
      for (final e in selected)
        if (e.ownerId == owner && !hasSelectedAncestor(e)) e,
    ];
    final elements = <SlideElementRec>[];
    final seen = <String>{};
    void collect(SlideElementRec e) {
      if (!seen.add(e.id)) return;
      elements.add(e);
      for (final c in byParent[e.id] ?? const <SlideElementRec>[]) {
        collect(c);
      }
    }

    for (final r in roots) {
      collect(r);
    }
    // The owner: a slide, or a layout/master in master mode (SL-28).
    final slideId = selected.first.slideId ?? selected.first.ownerId;
    final ids = {for (final e in elements) e.id};
    final payload = _empty(deck, kindElements, sourceItemUuid)
      ..['sourceSlideId'] = slideId
      ..['elements'] = [for (final e in elements) _elementRow(deck, e)]
      ..addAll(_dependents(deck, ids, slideIds: {?slideId}));
    payload['files'] = _files(payload, sourceItemUuid ?? deck.deckId);
    return payload;
  }

  /// The payload of slides [slideIds] and slide groups [groupIds] (with
  /// all their slides), in presentation order, with the themes their
  /// layouts use (for *Keep source formatting*). Kind `groups` when any
  /// group is copied, else `slides`.
  static Map<String, Object?> copySlides(
    DeckModel deck, {
    List<String> slideIds = const [],
    List<String> groupIds = const [],
    String? sourceItemUuid,
  }) {
    final groups = [
      for (final g in deck.groups)
        if (groupIds.contains(g.id)) g,
    ];
    final inGroups = {
      for (final g in groups)
        for (final s in deck.slidesInGroup(g.id)) s.id,
    };
    final wanted = {...slideIds, ...inGroups};
    final slides = [
      for (final s in deck.slides)
        if (wanted.contains(s.id)) s,
    ];
    final payload = _empty(
      deck,
      groups.isEmpty ? kindSlides : kindGroups,
      sourceItemUuid,
    );
    final elements = [for (final s in slides) ...deck.allElementsOf(s.id)];
    final ids = {for (final e in elements) e.id};
    // Themes used by the copied slides (all their masters and layouts).
    final themeIds = <String>{};
    for (final s in slides) {
      final layout = s.layoutId == null ? null : deck.layout(s.layoutId!);
      final master = layout?.masterId == null
          ? null
          : deck.master(layout!.masterId!);
      if (master?.themeId != null) themeIds.add(master!.themeId!);
    }
    payload
      ..['themes'] = [
        for (final t in deck.themes)
          if (themeIds.contains(t.id)) themeEntry(deck, t),
      ]
      ..['groups'] = [
        for (final g in groups)
          {
            'id': g.id,
            'title': g.columns[SlidesCols.title],
            'color': g.columns[SlideGroupCols.color],
            'skipped': g.columns[SlidesCols.skipped] == true,
            'slides': [
              for (final s in slides)
                if (s.groupId == g.id) s.id,
            ],
          },
      ]
      ..['slides'] = [for (final s in slides) _json(s.columns)]
      ..['elements'] = [for (final e in elements) _json(e.columns)]
      ..addAll(
        _dependents(deck, ids, slideIds: {for (final s in slides) s.id}),
      );
    payload['files'] = _files(payload, sourceItemUuid ?? deck.deckId);
    return payload;
  }

  /// The payload of a text selection (paste into text editing; on the
  /// canvas a text box).
  static Map<String, Object?> copyText(
    Delta text, {
    String? sourceDeckId,
    String? sourceItemUuid,
    bool notes = false,
  }) => {
    'format': format,
    'v': version,
    'sourceDeckId': ?sourceDeckId,
    'sourceItemUuid': ?(sourceItemUuid ?? sourceDeckId),
    'kind': kindText,
    'text': {
      'delta': SlidesDeltaNormalizer(
        notes: notes,
      ).normalize(text).delta.toJson(),
    },
  };

  static Map<String, Object?> _empty(
    DeckModel deck,
    String kind,
    String? sourceItemUuid,
  ) => {
    'format': format,
    'v': version,
    'sourceDeckId': deck.deckId,
    'sourceItemUuid': sourceItemUuid ?? deck.deckId,
    'kind': kind,
    'themes': <Object?>[],
    'groups': <Object?>[],
    'slides': <Object?>[],
    'elements': <Object?>[],
    'tableAxes': <Object?>[],
    'tableCells': <Object?>[],
    'builds': <Object?>[],
    'codeStates': <Object?>[],
    'chartLinks': <Object?>[],
    'files': <Object?>[],
  };

  static Map<String, Object?> _elementRow(DeckModel deck, SlideElementRec e) {
    final row = _json(e.columns);
    if (e.frame == null && e.placeholderType != null && e.slideId != null) {
      final d = deck.deck;
      final eff = deck.indexes.placeholders.effective(
        e,
        bounds: SuRect(0, 0, d?.width ?? 1920, d?.height ?? 1080),
      );
      row
        ..[ElementCols.x] = eff.frame.x
        ..[ElementCols.y] = eff.frame.y
        ..[ElementCols.width] = eff.frame.width
        ..[ElementCols.height] = eff.frame.height
        ..[ElementCols.rotation] ??= eff.rotation == 0 ? null : eff.rotation;
    }
    return row;
  }

  static Map<String, Object?> _dependents(
    DeckModel deck,
    Set<String> elementIds, {
    required Set<String> slideIds,
  }) => {
    'tableAxes': [
      for (final id in elementIds)
        for (final d in TableAxisDimension.values)
          for (final a in deck.axesOf(id, d)) _json(a.columns),
    ],
    'tableCells': [
      for (final id in elementIds)
        for (final c in deck.cellsOf(id)) _json(c.columns),
    ],
    'builds': [
      for (final s in slideIds)
        for (final b in deck.buildsOf(s))
          if (elementIds.contains(b.columns[SlidesCols.elementId]))
            _json(b.columns),
    ],
    'codeStates': [
      for (final id in elementIds)
        for (final c in deck.codeStatesOf(id)) _json(c.columns),
    ],
    'chartLinks': [
      for (final id in elementIds) ?_jsonOrNull(deck.chartLinkOf(id)?.columns),
    ],
  };

  /// The rows of theme [t] of [deck]: its `deck_theme` columns plus
  /// `masters`, `layouts` and `elements` (of masters and layouts) — the
  /// `themes` entries of a payload, and `ImportTheme.themeEntry` (SL-17:
  /// theme import and duplicate). JSON-safe (dates as ISO strings).
  static Map<String, Object?> themeEntry(DeckModel deck, DeckThemeRec t) {
    final masters = deck.mastersOf(t.id);
    return {
      ..._json(t.columns),
      'masters': [for (final m in masters) _json(m.columns)],
      'layouts': [
        for (final m in masters)
          for (final l in deck.layoutsOf(m.id)) _json(l.columns),
      ],
      'elements': [
        for (final m in masters) ...[
          for (final e in deck.allElementsOf(m.id)) _json(e.columns),
          for (final l in deck.layoutsOf(m.id))
            for (final e in deck.allElementsOf(l.id)) _json(e.columns),
        ],
      ],
    };
  }

  /// The uploaded files a payload references (03 §12.2 `files`).
  static List<Map<String, Object?>> _files(
    Map<String, Object?> payload,
    String itemUuid,
  ) {
    final out = <String, Map<String, Object?>>{};
    for (final (_, row) in _allRows(payload)) {
      for (final e in row.entries) {
        if (!e.key.endsWith('Json') || e.value is! String) continue;
        for (final f in SlidesIdRemapper.fileRefs(e.value as String)) {
          out.putIfAbsent(f, () {
            String? mime;
            if (e.key == ElementCols.dataJson) {
              try {
                final d = jsonDecode(e.value as String);
                if (d is Map && d['mimeType'] is String) {
                  mime = d['mimeType'] as String;
                }
              } on FormatException {
                // No metadata.
              }
            }
            return {'fileUuid': f, 'itemUuid': itemUuid, 'mimeType': ?mime};
          });
        }
      }
    }
    return out.values.toList();
  }

  static Map<String, Object?>? _jsonOrNull(Map<String, Object?>? c) =>
      c == null ? null : _json(c);

  /// [columns] with JSON-safe values.
  static Map<String, Object?> _json(Map<String, Object?> columns) => {
    for (final e in columns.entries)
      e.key: switch (e.value) {
        final DateTime d => d.toUtc().toIso8601String(),
        final Enum v => v.name,
        final v => v,
      },
  };

  // ------------------------------------------------------------- encoding

  /// The payload as JSON text.
  static String encode(Map<String, Object?> payload) => jsonEncode(payload);

  /// Parses and sanitizes a payload (null when [text] is not a Slides
  /// payload of a supported version, or is malformed).
  static Map<String, Object?>? decode(String text) {
    if (!text.startsWith('{') || !text.contains(format)) return null;
    try {
      final v = jsonDecode(text);
      if (v is! Map) return null;
      return sanitize(v.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  /// A clean payload from untrusted JSON: the format and version checked,
  /// rows reduced to the known columns of their table with valid UUID
  /// ids, text bodies normalized to the schema, dependent rows of missing
  /// elements dropped, group slide lists limited to copied slides. Throws
  /// [FormatException] when [raw] is not a v1 payload or is too large.
  static Map<String, Object?> sanitize(Map<String, Object?> raw) {
    if (raw['format'] != format) {
      throw const FormatException('Not a Wonky Slides clipboard payload.');
    }
    if (raw['v'] != version) {
      throw FormatException('Unsupported clipboard version ${raw['v']}.');
    }
    final kind = raw['kind'];
    if (kind is! String || !kinds.contains(kind)) {
      throw FormatException('Unknown clipboard kind $kind.');
    }
    var count = 0;
    List<Map<String, Object?>> rows(Object? list, String table) {
      final out = <Map<String, Object?>>[];
      if (list is! List) return out;
      final known = SlidesTables.columns[table]!;
      for (final r in list) {
        if (r is! Map) continue;
        final id = r[SlidesCols.id];
        if (id is! String || !SlidesIdRemapper.isUuid(id)) continue;
        if (++count > maxRows) {
          throw const FormatException('The clipboard payload is too large.');
        }
        final row = <String, Object?>{
          for (final c in known)
            if (r.containsKey(c)) c: _uuidColumn(c, r[c]),
        };
        row[SlidesCols.id] = id.toLowerCase();
        out.add(row);
      }
      return out;
    }

    String? uuid(Object? v) =>
        v is String && SlidesIdRemapper.isUuid(v) ? v.toLowerCase() : null;

    final out = <String, Object?>{
      'format': format,
      'v': version,
      'sourceDeckId': ?uuid(raw['sourceDeckId']),
      'sourceItemUuid': ?uuid(raw['sourceItemUuid']),
      'sourceSlideId': ?uuid(raw['sourceSlideId']),
      'kind': kind,
    };
    if (kind == kindText) {
      final t = raw['text'];
      final delta = t is Map ? t['delta'] : null;
      out['text'] = {
        'delta': SlidesDeltaNormalizer().normalizeValue(delta).delta.toJson(),
      };
      return out;
    }
    final body = SlidesDeltaNormalizer();
    final notes = SlidesDeltaNormalizer(notes: true);
    String? text(Object? v, SlidesDeltaNormalizer n) {
      if (v is! String) return null;
      try {
        return n.normalizeJson(v);
      } on FormatException {
        return null;
      }
    }

    final slides = rows(raw['slides'], SlidesTables.slide);
    for (final s in slides) {
      if (s[SlidesCols.skipped] is! bool) s[SlidesCols.skipped] = false;
      if (s.containsKey(SlideCols.notes)) {
        s[SlideCols.notes] = text(s[SlideCols.notes], notes);
      }
    }
    final slideIds = {for (final s in slides) s[SlidesCols.id]};
    var elements = rows(raw['elements'], SlidesTables.slideElement);
    if (kind != kindElements) {
      elements = [
        for (final e in elements)
          if (slideIds.contains(e[SlidesCols.slideId])) e,
      ];
    }
    for (final e in elements) {
      // Non-null columns an older or foreign payload may omit.
      for (final c in const [
        ElementCols.flipH,
        ElementCols.flipV,
        ElementCols.locked,
        SlidesCols.hidden,
        ElementCols.decorative,
      ]) {
        if (e[c] is! bool) e[c] = false;
      }
      if (e.containsKey(SlidesCols.text)) {
        e[SlidesCols.text] = text(e[SlidesCols.text], body);
      }
      if (ElementKind.fromName(e[SlidesCols.kind]) == null) {
        e[SlidesCols.kind] = ElementKind.shape.name;
      }
    }
    final elementIds = {for (final e in elements) e[SlidesCols.id]};
    bool ofElement(Map<String, Object?> r) =>
        elementIds.contains(r[SlidesCols.elementId]);
    final cells = [
      for (final c in rows(raw['tableCells'], SlidesTables.slideTableCell))
        if (ofElement(c)) c,
    ];
    for (final c in cells) {
      if (c.containsKey(SlidesCols.text)) {
        c[SlidesCols.text] = text(c[SlidesCols.text], body);
      }
    }
    out
      ..['themes'] = [
        if (raw['themes'] case final List<Object?> themes)
          for (final t in themes)
            if (t is Map)
              if (rows([t], SlidesTables.deckTheme) case [final theme])
                {
                  ...theme,
                  'masters': rows(t['masters'], SlidesTables.slideMaster),
                  'layouts': rows(t['layouts'], SlidesTables.slideLayout),
                  'elements': rows(t['elements'], SlidesTables.slideElement),
                },
      ]
      ..['groups'] = [
        if (raw['groups'] case final List<Object?> groups)
          for (final g in groups)
            if (g is Map && uuid(g['id']) != null)
              {
                'id': uuid(g['id']),
                'title': g['title'] is String
                    ? (g['title']! as String).trim()
                    : null,
                'color': g['color'] is String ? g['color'] : null,
                'skipped': g['skipped'] == true,
                'slides': [
                  if (g['slides'] case final List<Object?> ids)
                    for (final s in ids)
                      if (slideIds.contains(uuid(s))) uuid(s),
                ],
              },
      ]
      ..['slides'] = slides
      ..['elements'] = elements
      ..['tableAxes'] = [
        for (final a in rows(raw['tableAxes'], SlidesTables.slideTableAxis))
          if (ofElement(a)) a,
      ]
      ..['tableCells'] = cells
      ..['builds'] = [
        for (final b in rows(raw['builds'], SlidesTables.slideBuild))
          if (ofElement(b)) b,
      ]
      ..['codeStates'] = [
        for (final c in rows(raw['codeStates'], SlidesTables.codeState))
          if (ofElement(c)) c,
      ]
      ..['chartLinks'] = [
        for (final c in rows(raw['chartLinks'], SlidesTables.chartLink))
          if (ofElement(c)) c,
      ]
      ..['files'] = [
        if (raw['files'] case final List<Object?> files)
          for (final f in files)
            if (f is Map && uuid(f['fileUuid']) != null)
              {
                'fileUuid': uuid(f['fileUuid']),
                'itemUuid': ?uuid(f['itemUuid']),
                'mimeType': ?(f['mimeType'] is String ? f['mimeType'] : null),
                'size': ?(f['size'] is int ? f['size'] : null),
              },
      ];
    return out;
  }

  static Object? _uuidColumn(String column, Object? v) {
    if (v is String &&
        (column == SlidesCols.id ||
            column.endsWith('Id') ||
            column == ElementCols.placeholderOf) &&
        SlidesIdRemapper.isUuid(v)) {
      return v.toLowerCase();
    }
    return v;
  }

  static Iterable<(String, Map<String, Object?>)> _allRows(
    Map<String, Object?> p,
  ) sync* {
    Iterable<Map<String, Object?>> list(Object? v) sync* {
      if (v is! List) return;
      for (final r in v) {
        if (r is Map<String, Object?>) yield r;
      }
    }

    for (final t in list(p['themes'])) {
      yield (SlidesTables.deckTheme, t);
      for (final m in list(t['masters'])) {
        yield (SlidesTables.slideMaster, m);
      }
      for (final l in list(t['layouts'])) {
        yield (SlidesTables.slideLayout, l);
      }
      for (final e in list(t['elements'])) {
        yield (SlidesTables.slideElement, e);
      }
    }
    for (final (key, table) in _lists) {
      for (final r in list(p[key])) {
        yield (table, r);
      }
    }
  }

  static const _lists = [
    ('slides', SlidesTables.slide),
    ('elements', SlidesTables.slideElement),
    ('tableAxes', SlidesTables.slideTableAxis),
    ('tableCells', SlidesTables.slideTableCell),
    ('builds', SlidesTables.slideBuild),
    ('codeStates', SlidesTables.codeState),
    ('chartLinks', SlidesTables.chartLink),
  ];

  // ------------------------------------------------------- re-homing files

  /// The uploaded files of [payload] (03 §12.2 `files`, else scanned).
  static Set<String> fileUuids(Map<String, Object?> payload) {
    final out = <String>{};
    for (final (_, row) in _allRows(payload)) {
      for (final e in row.entries) {
        if (e.key.endsWith('Json') && e.value is String) {
          out.addAll(SlidesIdRemapper.fileRefs(e.value as String));
        }
      }
    }
    return out;
  }

  /// A cross-deck paste's re-homing (03 §12.3): every referenced file gets
  /// a new uuid written into the payload's rows (`wonky-file://` and
  /// `fileUuid`), and the list of copies the client queues
  /// (`FileEndpoint.copyToItem`). Same-deck pastes don't re-home.
  static (Map<String, Object?>, List<FileRehome>) rehomeFiles(
    Map<String, Object?> payload, {
    IdGenerator ids = const UuidV7IdGenerator(),
  }) {
    final files = {for (final f in fileUuids(payload)) f: ids.newId()};
    if (files.isEmpty) return (payload, const []);
    final remap = SlidesIdRemapper(const {}, files: files);
    Object? rows(Object? list) => [
      if (list is List)
        for (final r in list)
          if (r is Map<String, Object?>)
            {
              for (final e in r.entries)
                e.key: e.key.endsWith('Json') && e.value is String
                    ? remap.json(e.value as String)
                    : e.value,
            },
    ];
    final out = <String, Object?>{...payload};
    for (final (key, _) in _lists) {
      if (payload.containsKey(key)) out[key] = rows(payload[key]);
    }
    if (payload['themes'] is List) {
      out['themes'] = [
        for (final t in payload['themes']! as List)
          if (t is Map<String, Object?>)
            {
              ...(rows([t])! as List).single as Map<String, Object?>,
              'masters': rows(t['masters']),
              'layouts': rows(t['layouts']),
              'elements': rows(t['elements']),
            },
      ];
    }
    out['files'] = [
      if (payload['files'] is List)
        for (final f in payload['files']! as List)
          if (f is Map && files.containsKey(f['fileUuid']))
            {...f.cast<String, Object?>(), 'fileUuid': files[f['fileUuid']]},
    ];
    return (out, [for (final e in files.entries) FileRehome(e.key, e.value)]);
  }

  // ------------------------------------------------------ representations

  /// `text/plain` of a payload (03 §12.1): elements' text in reading order
  /// (tables as tab-separated rows, code as its first state); slides as an
  /// outline (title, then body lines indented by two spaces).
  static String plainText(Map<String, Object?> payload) {
    if (payload['kind'] == kindText) {
      return _plainOfDelta(payload['text']);
    }
    final ctx = _PayloadView(payload);
    if (payload['kind'] == kindElements) {
      return ctx.textOf(ctx.topElements(null)).join('\n');
    }
    final out = <String>[];
    for (final s in ctx.slides) {
      final (title, body) = ctx.outline(s);
      out.add(title.isEmpty ? '(untitled)' : title);
      for (final line in body) {
        out.add('  $line');
      }
    }
    return out.join('\n');
  }

  /// Markdown of slides (03 §12.1, for Write): `# Title` per slide and its
  /// body text as bullets. Elements and text become paragraphs.
  static String markdown(Map<String, Object?> payload) {
    if (payload['kind'] == kindText || payload['kind'] == kindElements) {
      return plainText(payload);
    }
    final ctx = _PayloadView(payload);
    final out = <String>[];
    for (final s in ctx.slides) {
      final (title, body) = ctx.outline(s);
      if (out.isNotEmpty) out.add('');
      out.add('# ${title.isEmpty ? 'Untitled slide' : title}');
      if (body.isNotEmpty) out.add('');
      for (final line in body) {
        out.add('- $line');
      }
    }
    return out.join('\n');
  }

  /// Readable `text/html` content of a payload (03 §12.1; the embedded
  /// payload is added by `SlidesHtml.ofPayload`): text bodies with their
  /// formatting, tables as `<table>`, code as `<pre>`; slides as their
  /// title (`<h2>`) followed by their text.
  static String htmlBody(Map<String, Object?> payload) {
    if (payload['kind'] == kindText) {
      final t = payload['text'];
      return SlidesHtml.ofDelta(t is Map ? t['delta'] : null);
    }
    final ctx = _PayloadView(payload);
    if (payload['kind'] == kindElements) {
      return ctx.htmlOf(ctx.topElements(null));
    }
    final out = StringBuffer();
    for (final s in ctx.slides) {
      final (title, _) = ctx.outline(s);
      final rest = [
        for (final e in ctx.topElements('${s[SlidesCols.id]}'))
          if (e[ElementCols.placeholderType] != SlidePlaceholderType.title.name)
            e,
      ];
      out.write(
        '<h2>${SlidesHtml.escape(title.isEmpty ? 'Untitled slide' : title)}'
        '</h2>',
      );
      out.write(ctx.htmlOf(rest));
    }
    return out.toString();
  }

  static String _plainOfDelta(Object? text) {
    final d = text is Map ? text['delta'] : null;
    final t = SlidesDeltaNormalizer().normalizeValue(d).delta;
    final s = StringBuffer();
    for (final op in t.operations) {
      if (op.data is String) s.write(op.data);
    }
    final r = s.toString();
    return r.endsWith('\n') ? r.substring(0, r.length - 1) : r;
  }

  /// Whether [limits] allow pasting [payload] (slides count); null = ok,
  /// else the message.
  static String? checkLimits(
    Map<String, Object?> payload, {
    SlidesLimits limits = SlidesLimits.defaults,
  }) {
    final slides = (payload['slides'] as List?)?.length ?? 0;
    if (slides > limits.maxSlidesPerDeck) {
      return 'A presentation can have at most ${limits.maxSlidesPerDeck} slides.';
    }
    return null;
  }
}

/// Read helpers over payload rows (plain text, Markdown).
final class _PayloadView {
  _PayloadView(Map<String, Object?> p)
    : slides = _maps(p['slides']),
      elements = _maps(p['elements']),
      axes = _maps(p['tableAxes']),
      cells = _maps(p['tableCells']),
      states = _maps(p['codeStates']);

  final List<Map<String, Object?>> slides;
  final List<Map<String, Object?>> elements;
  final List<Map<String, Object?>> axes;
  final List<Map<String, Object?>> cells;
  final List<Map<String, Object?>> states;

  static List<Map<String, Object?>> _maps(Object? v) => [
    if (v is List)
      for (final r in v)
        if (r is Map<String, Object?>) r,
  ];

  static int _byOrder(String ka, Object? ia, String kb, Object? ib) =>
      FractionalIndex.compare(ka, '$ia', kb, '$ib');

  /// Top-level elements (of [slideId], or all when null) in reading
  /// order: `readingKey` when set, else `zKey`.
  List<Map<String, Object?>> topElements(String? slideId) {
    final ids = {for (final e in elements) e[SlidesCols.id]};
    final top = [
      for (final e in elements)
        if ((slideId == null || e[SlidesCols.slideId] == slideId) &&
            !ids.contains(e[SlidesCols.parentId]))
          e,
    ];
    String key(Map<String, Object?> e) =>
        '${e[ElementCols.readingKey] ?? e[ElementCols.zKey] ?? ''}';
    top.sort(
      (a, b) => _byOrder(key(a), a[SlidesCols.id], key(b), b[SlidesCols.id]),
    );
    return top;
  }

  List<Map<String, Object?>> childrenOf(String id) {
    final c = [
      for (final e in elements)
        if (e[SlidesCols.parentId] == id) e,
    ];
    c.sort(
      (a, b) => _byOrder(
        '${a[ElementCols.zKey] ?? ''}',
        a[SlidesCols.id],
        '${b[ElementCols.zKey] ?? ''}',
        b[SlidesCols.id],
      ),
    );
    return c;
  }

  static String _plain(Object? json) {
    final t = SlidesText.plainText(json is String ? json : null);
    return t.endsWith('\n') ? t.substring(0, t.length - 1) : t;
  }

  /// The text lines of [list] (groups expanded).
  List<String> textOf(List<Map<String, Object?>> list) {
    final out = <String>[];
    for (final e in list) {
      final id = '${e[SlidesCols.id]}';
      switch (ElementKind.fromName(e[SlidesCols.kind])) {
        case ElementKind.group:
          out.addAll(textOf(childrenOf(id)));
        case ElementKind.table:
          out.addAll(_table(id));
        case ElementKind.code:
          final s =
              [
                for (final c in states)
                  if (c[SlidesCols.elementId] == id) c,
              ]..sort(
                (a, b) => _byOrder(
                  '${a[SlidesCols.sortKey] ?? ''}',
                  a[SlidesCols.id],
                  '${b[SlidesCols.sortKey] ?? ''}',
                  b[SlidesCols.id],
                ),
              );
          if (s.isNotEmpty) out.add('${s.first[CodeStateCols.code] ?? ''}');
        default:
          final t = _plain(e[SlidesCols.text]);
          if (t.trim().isNotEmpty) out.add(t);
      }
    }
    return out;
  }

  /// HTML of [list] (groups expanded; images and charts skipped).
  String htmlOf(List<Map<String, Object?>> list) {
    final out = StringBuffer();
    for (final e in list) {
      final id = '${e[SlidesCols.id]}';
      switch (ElementKind.fromName(e[SlidesCols.kind])) {
        case ElementKind.group:
          out.write(htmlOf(childrenOf(id)));
        case ElementKind.table:
          out.write(_tableHtml(id));
        case ElementKind.code:
          final t = textOf([e]);
          if (t.isNotEmpty) {
            out.write('<pre><code>${SlidesHtml.escape(t.first)}</code></pre>');
          }
        default:
          final text = e[SlidesCols.text];
          if (text is String && !SlidesText.isBlank(text)) {
            out.write(SlidesHtml.ofDelta(SlidesText.parse(text)));
          }
      }
    }
    return out.toString();
  }

  List<Map<String, Object?>> _axesOf(String elementId, String dim) =>
      [
        for (final a in axes)
          if (a[SlidesCols.elementId] == elementId &&
              a[TableAxisCols.dimension] == dim)
            a,
      ]..sort(
        (a, b) => _byOrder(
          '${a[SlidesCols.sortKey] ?? ''}',
          a[SlidesCols.id],
          '${b[SlidesCols.sortKey] ?? ''}',
          b[SlidesCols.id],
        ),
      );

  String _tableHtml(String elementId) {
    final rows = _axesOf(elementId, TableAxisDimension.row.name);
    final cols = _axesOf(elementId, TableAxisDimension.column.name);
    final byPos = {
      for (final c in cells)
        if (c[SlidesCols.elementId] == elementId)
          '${c[TableCellCols.rowId]}:${c[TableCellCols.columnId]}': c,
    };
    final covered = <(int, int)>{};
    final out = StringBuffer('<table><tbody>');
    for (final (i, r) in rows.indexed) {
      out.write('<tr>');
      for (final (j, c) in cols.indexed) {
        if (covered.contains((i, j))) continue;
        final cell = byPos['${r[SlidesCols.id]}:${c[SlidesCols.id]}'];
        final rs = (cell?[TableCellCols.rowSpan] as num?)?.toInt() ?? 1;
        final cs = (cell?[TableCellCols.colSpan] as num?)?.toInt() ?? 1;
        for (var dr = 0; dr < rs; dr++) {
          for (var dc = 0; dc < cs; dc++) {
            if (dr > 0 || dc > 0) covered.add((i + dr, j + dc));
          }
        }
        final fill = cell?[TableCellCols.fill];
        out.write('<td');
        if (rs > 1) out.write(' rowspan="$rs"');
        if (cs > 1) out.write(' colspan="$cs"');
        if (fill is String && fill.startsWith('#')) {
          out.write(' style="background-color:${SlidesHtml.escape(fill)}"');
        }
        out.write('>');
        final text = cell?[SlidesCols.text];
        if (text is String && !SlidesText.isBlank(text)) {
          final html = SlidesHtml.ofDelta(SlidesText.parse(text));
          // One paragraph: no <p> wrapper (spreadsheets paste it as a value).
          final single = RegExp(r'^<p>(.*)</p>$').firstMatch(html);
          out.write(single?.group(1) ?? html);
        }
        out.write('</td>');
      }
      out.write('</tr>');
    }
    out.write('</tbody></table>');
    return out.toString();
  }

  List<String> _table(String elementId) {
    List<Map<String, Object?>> axesOf(String dim) =>
        [
          for (final a in axes)
            if (a[SlidesCols.elementId] == elementId &&
                a[TableAxisCols.dimension] == dim)
              a,
        ]..sort(
          (a, b) => _byOrder(
            '${a[SlidesCols.sortKey] ?? ''}',
            a[SlidesCols.id],
            '${b[SlidesCols.sortKey] ?? ''}',
            b[SlidesCols.id],
          ),
        );
    final rows = axesOf(TableAxisDimension.row.name);
    final cols = axesOf(TableAxisDimension.column.name);
    final byPos = {
      for (final c in cells)
        if (c[SlidesCols.elementId] == elementId)
          '${c[TableCellCols.rowId]}:${c[TableCellCols.columnId]}': c,
    };
    return [
      for (final r in rows)
        [
          for (final c in cols)
            _plain(
              byPos['${r[SlidesCols.id]}:${c[SlidesCols.id]}']?[SlidesCols
                  .text],
            ).replaceAll('\n', ' ').replaceAll('\t', ' '),
        ].join('\t'),
    ];
  }

  /// The title (title/subtitle-less: first title placeholder) and body
  /// lines of [slide].
  (String, List<String>) outline(Map<String, Object?> slide) {
    final top = topElements('${slide[SlidesCols.id]}');
    String title = '';
    final rest = <Map<String, Object?>>[];
    for (final e in top) {
      if (title.isEmpty &&
          e[ElementCols.placeholderType] == SlidePlaceholderType.title.name) {
        title = _plain(e[SlidesCols.text]).replaceAll('\n', ' ').trim();
      } else {
        rest.add(e);
      }
    }
    final body = <String>[
      for (final t in textOf(rest))
        for (final line in t.split(RegExp('[\n ]')))
          if (line.trim().isNotEmpty) line.trimRight(),
    ];
    return (title, body);
  }
}
