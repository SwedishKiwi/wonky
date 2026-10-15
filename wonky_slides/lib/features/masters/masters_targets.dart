import 'dart:convert';

import 'package:wonky_core/wonky_core.dart' show JsonArgs;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart' show OrderKeys;
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/themes.dart';

import '../editor_screen/deck_editor_controller.dart';

/// What the masters, layout and theme-editor commands act on (Slides 05
/// §8; SL-28): explicit ids from the arguments, else the layout or master
/// edited in masters mode, else the current slide's layout.
abstract final class MastersTargets {
  /// The placeholder types *Insert › Placeholder* offers (`date` is P2 and
  /// not drawn on slides yet, 05 §4).
  static const insertable = [
    SlidePlaceholderType.title,
    SlidePlaceholderType.subtitle,
    SlidePlaceholderType.body,
    SlidePlaceholderType.picture,
    SlidePlaceholderType.chart,
    SlidePlaceholderType.table,
    SlidePlaceholderType.code,
    SlidePlaceholderType.caption,
    SlidePlaceholderType.bigNumber,
    SlidePlaceholderType.quote,
    SlidePlaceholderType.attribution,
    SlidePlaceholderType.slideNumber,
    SlidePlaceholderType.footer,
    SlidePlaceholderType.object,
  ];

  static SlideLayoutRec? _slideLayout(DeckEditorController ed) {
    final id = ed.currentSlideId;
    final s = id == null ? null : ed.model.slide(id);
    return s == null ? null : ed.model.indexes.themes.effectiveLayout(s);
  }

  /// The layout of [a] (`layoutId`), else the edited one (masters mode,
  /// null while a master is edited), else the current slide's.
  static SlideLayoutRec? layout(DeckEditorController ed, JsonArgs a) {
    final id = a.string('layoutId');
    if (id != null) return ed.model.layout(id);
    if (ed.editsMasters) {
      final t = ed.surfaceId;
      return t == null ? null : ed.model.layout(t);
    }
    return _slideLayout(ed);
  }

  /// The master of [a] (`masterId`), else the edited master or the edited
  /// layout's master, else the current slide layout's master.
  static SlideMasterRec? master(DeckEditorController ed, JsonArgs a) {
    final id = a.string('masterId');
    if (id != null) return ed.model.master(id);
    final t = ed.editsMasters ? ed.surfaceId : null;
    if (t != null) {
      final m = ed.model.master(t);
      if (m != null) return m;
      final l = ed.model.layout(t);
      return l == null ? null : ed.model.indexes.themes.masterOf(l);
    }
    final l = _slideLayout(ed);
    return l == null ? null : ed.model.indexes.themes.masterOf(l);
  }

  /// The theme of the edited layout/master (masters mode), else null.
  static DeckThemeRec? themeOfTarget(DeckEditorController ed) {
    if (!ed.editsMasters) return null;
    final m = master(ed, const JsonArgs());
    return m == null ? null : ed.model.indexes.themes.themeOf(m);
  }

  /// The theme of [a] (`themeId`), else the edited one, else the current
  /// slide's theme, else the deck's default theme.
  static DeckThemeRec? theme(DeckEditorController ed, JsonArgs a) {
    final id = a.string('themeId');
    if (id != null) return ed.model.theme(id);
    final t = themeOfTarget(ed);
    if (t != null) return t;
    final l = _slideLayout(ed);
    final fromSlide = l == null
        ? null
        : ed.model.indexes.themes.themeOfLayout(l);
    return fromSlide ?? ed.model.defaultTheme;
  }

  /// The first master of theme [themeId] (what *Edit theme…* shows).
  static String? firstTargetOf(DeckEditorController ed, String themeId) {
    final masters = ed.model.mastersOf(themeId);
    return masters.isEmpty ? null : masters.first.id;
  }

  /// The slides drawn with layout [layoutId].
  static List<String> slidesUsing(DeckEditorController ed, String layoutId) {
    final themes = ed.model.indexes.themes;
    return [
      for (final e in ed.order.entries)
        if (themes.effectiveLayout(e.slide)?.id == layoutId) e.id,
    ];
  }

  /// The layout of the same master a deleted [layout]'s slides move to:
  /// *Title and content*, else the best placeholder-signature match
  /// (`LayoutMatcher`, 05 §5.4) among the other visible layouts.
  static SlideLayoutRec? replacementFor(
    DeckEditorController ed,
    SlideLayoutRec layout,
  ) {
    final others = [
      for (final l in ed.model.layoutsOf(layout.masterId ?? ''))
        if (l.id != layout.id) l,
    ];
    if (others.isEmpty) return null;
    final visible = others.where((l) => !l.hidden).toList();
    final pool = visible.isEmpty ? others : visible;
    for (final l in pool) {
      if (l.key == 'titleBody') return l;
    }
    final ph = ed.model.indexes.placeholders;
    final match = LayoutMatcher.match(
      key: layout.key,
      types: [for (final p in ph.placeholdersOf(layout.id)) p.placeholderType!],
      candidates: [
        for (final l in pool)
          LayoutCandidate(
            id: l.id,
            key: l.key,
            types: [
              for (final p in ph.placeholdersOf(l.id)) p.placeholderType!,
            ],
          ),
      ],
    );
    return match == null ? pool.first : ed.model.layout(match.id);
  }

  /// The layout shown after [layout] is deleted: the next one of its
  /// master, else the previous one, else the master.
  static String? neighbor(DeckEditorController ed, SlideLayoutRec layout) {
    final siblings = OrderKeys.sorted([
      for (final x in ed.model.layoutsOf(layout.masterId ?? ''))
        (x.sortKey, x.id),
    ]);
    final i = siblings.indexWhere((x) => x.$2 == layout.id);
    if (i + 1 < siblings.length) return siblings[i + 1].$2;
    if (i > 0) return siblings[i - 1].$2;
    return layout.masterId;
  }

  /// The layout or master a placeholder goes to: `layoutId` / `masterId`
  /// of [a], else the surface edited in masters mode. Null outside masters
  /// mode without an explicit owner.
  static (String, ElementOwnerKind)? placeholderOwner(
    DeckEditorController ed,
    JsonArgs a,
  ) {
    final l = a.string('layoutId');
    if (l != null) {
      return ed.model.layout(l) == null ? null : (l, ElementOwnerKind.layout);
    }
    final m = a.string('masterId');
    if (m != null) {
      return ed.model.master(m) == null ? null : (m, ElementOwnerKind.master);
    }
    if (!ed.editsMasters) return null;
    final id = ed.surfaceId;
    return id == null ? null : (id, ed.surfaceKind);
  }

  /// Design-grid frames (1920 × 1080) of new placeholders by type (05 §4).
  static SuRect designFrameOf(SlidePlaceholderType type) => switch (type) {
    SlidePlaceholderType.title => const SuRect(120, 72, 1680, 144),
    SlidePlaceholderType.subtitle => const SuRect(120, 624, 1680, 144),
    SlidePlaceholderType.body ||
    SlidePlaceholderType.object => const SuRect(120, 264, 1680, 720),
    SlidePlaceholderType.picture ||
    SlidePlaceholderType.chart ||
    SlidePlaceholderType.table ||
    SlidePlaceholderType.code => const SuRect(480, 270, 960, 540),
    SlidePlaceholderType.caption => const SuRect(120, 920, 1680, 96),
    SlidePlaceholderType.bigNumber => const SuRect(120, 200, 1680, 440),
    SlidePlaceholderType.quote => const SuRect(240, 240, 1440, 480),
    SlidePlaceholderType.attribution => const SuRect(240, 760, 1440, 72),
    SlidePlaceholderType.slideNumber => const SuRect(1680, 992, 120, 48),
    SlidePlaceholderType.footer => const SuRect(120, 992, 1200, 48),
    SlidePlaceholderType.date => const SuRect(1320, 992, 320, 48),
  };

  /// The element kind of a new placeholder of [type].
  static ElementKind kindOf(SlidePlaceholderType type) => switch (type) {
    SlidePlaceholderType.picture => ElementKind.image,
    SlidePlaceholderType.chart => ElementKind.chart,
    SlidePlaceholderType.table => ElementKind.table,
    SlidePlaceholderType.code => ElementKind.code,
    SlidePlaceholderType.object => ElementKind.shape,
    _ => ElementKind.text,
  };

  /// A new placeholder of [type] on [ownerId]: on a layout it refines the
  /// master's placeholder of the same type (its frame, styles inherited);
  /// otherwise it gets the 05 §4 geometry for the deck size and the
  /// type's default text style. [prompt] is stored as its text (the prompt
  /// of empty instances, 05 §5.1).
  static ElementSpec placeholderSpec(
    DeckEditorController ed,
    String ownerId,
    ElementOwnerKind kind,
    SlidePlaceholderType type, {
    required String prompt,
  }) {
    final m = ed.model;
    final ph = m.indexes.placeholders;
    final layout = kind == ElementOwnerKind.layout ? m.layout(ownerId) : null;
    final parent = layout?.masterId == null
        ? null
        : ph.masterPlaceholder(layout!.masterId!, type);
    final d = m.deck;
    final w = d?.width ?? 1920, h = d?.height ?? 1080;
    final design = designFrameOf(type);
    final frame =
        parent?.frame ??
        SuRect(
          design.x * w / 1920,
          design.y * h / 1080,
          design.width * w / 1920,
          design.height * h / 1080,
        );
    final field =
        type == SlidePlaceholderType.slideNumber ||
        type == SlidePlaceholderType.footer ||
        type == SlidePlaceholderType.date;
    final style = type.defaultStyleKey;
    return ElementSpec(
      kind: kindOf(type),
      x: frame.x,
      y: frame.y,
      width: frame.width,
      height: frame.height,
      tableRows: type == SlidePlaceholderType.table ? 3 : null,
      tableColumns: type == SlidePlaceholderType.table ? 3 : null,
      columns: {
        ElementCols.placeholderType: type.name,
        ElementCols.placeholderOf: ?parent?.id,
        if (!field) SlidesCols.text: plainDelta(prompt),
        if (parent == null && type.holdsText)
          ElementCols.textStyleJson: jsonEncode({
            'v': 1,
            'anchor': switch (type) {
              SlidePlaceholderType.title => 'bottom',
              SlidePlaceholderType.slideNumber ||
              SlidePlaceholderType.footer ||
              SlidePlaceholderType.date ||
              SlidePlaceholderType.quote => 'middle',
              _ => 'top',
            },
            'insets': [0, 0, 0, 0],
            'autofit': 'shrink',
            'wrap': true,
            'defaults': {
              'style': ?style,
              if (type == SlidePlaceholderType.slideNumber) 'align': 'right',
              if (type == SlidePlaceholderType.body) 'list': 'bullet',
            },
          }),
      },
    );
  }

  /// The built-in key of a theme copied from a built-in (`builtin:<key>@v`
  /// source key), or null.
  static String? builtInKeyOf(DeckThemeRec t) {
    final src = t.sourceKey;
    if (src == null || !src.startsWith('builtin:')) return null;
    final key = src.substring('builtin:'.length).split('@').first;
    return BuiltInThemes.byKey(key) == null ? null : key;
  }
}
