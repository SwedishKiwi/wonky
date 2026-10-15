part of '../slides_planner.dart';

extension _SlidePart on _Planner {
  String addSlides(AddSlides op) {
    if (op.count < 1) invalid('count must be at least 1');
    checkSlideLimit(op.count);
    final target =
        op.target ??
        (op.afterSlideId != null
            ? afterSlide(op.afterSlideId!)
            : const TopLevel());
    String? layoutId = op.layoutId;
    if (layoutId != null) {
      final l = layoutOf(layoutId);
      if (ix.themes.themeOfLayout(l) == null) notFound('Layout', layoutId);
    } else {
      layoutId = _defaultLayoutFor(op.afterSlideId);
    }
    final layout = deck.layout(layoutId);
    final placeholders = layout == null
        ? const <SlideElementRec>[]
        : ix.placeholders.placeholdersOf(layout.id);
    final (groupId, keys) = keysAt(target, op.count);
    final ids = <String>[];
    for (final k in keys) {
      final id = newId();
      insertSlide(id, {
        SlidesCols.sortKey: k,
        SlideCols.groupId: groupId,
        SlideCols.layoutId: layoutId,
        // null = the deck default (06 §7.1): changing the default later
        // changes every slide without an own transition.
        SlidesCols.transitionJson: null,
      });
      instantiate(id, placeholders);
      ids.add(id);
    }
    result['slideIds'] = ids;
    return op.count == 1 ? 'New slide' : 'New ${op.count} slides';
  }

  /// A validated `transitionJson` (06 §7.1): wrong types are refused,
  /// clamped values become plan warnings, unknown keys are kept.
  String? transitionValue(String? json, String column) {
    final checked = jsonObject(json, column);
    if (checked == null) return null;
    final v = TransitionSpec.decode(checked);
    if (!v.isValid) {
      invalid('Invalid transition: ${v.errors.first}', {'column': column});
    }
    for (final w in v.warnings) {
      warnings.add(w.toString());
    }
    return v.value.encode();
  }

  /// The layout of a new slide: the layout of [afterSlideId], else the
  /// default theme's `titleBody`, else its first layout.
  String _defaultLayoutFor(String? afterSlideId) {
    if (afterSlideId != null) {
      final s = deck.slide(afterSlideId);
      final l = s == null ? null : ix.themes.effectiveLayout(s);
      if (l != null && l.key != 'title') return l.id;
      if (l != null) {
        final theme = ix.themes.themeOfLayout(l);
        final tb = theme == null
            ? null
            : ix.themes.layoutByKey(theme.id, 'titleBody');
        return (tb ?? l).id;
      }
    }
    final theme =
        ix.themes.defaultTheme ??
        (throw const PlanException(
          PlanException.notFound,
          'The presentation has no theme',
        ));
    final layouts = ix.themes.layoutsOfTheme(theme.id);
    if (layouts.isEmpty) {
      throw const PlanException(
        PlanException.notFound,
        'The theme has no layouts',
      );
    }
    return (ix.themes.layoutByKey(theme.id, 'titleBody') ?? layouts.first).id;
  }

  String duplicateSlides(DuplicateSlides op) {
    final ids = unique(op.slideIds);
    final ordered = [
      for (final e in ix.order.entries)
        if (ids.contains(e.id)) e.slide,
    ];
    for (final id in ids) {
      slideOf(id);
    }
    checkSlideLimit(ordered.length);
    final out = <String>[];
    // Each copy goes right after its source (02 §12.1).
    for (final s in ordered) {
      final (groupId, keys) = keysAt(afterSlide(s.id), 1);
      out.add(
        cloneSlide(
          s,
          groupId: groupId,
          sortKey: keys.single,
          keepMatchKeys: true,
        ),
      );
    }
    result['slideIds'] = out;
    return out.length == 1
        ? 'Duplicate slide'
        : 'Duplicate ${out.length} slides';
  }

  String deleteSlides(DeleteSlides op) {
    final ids = unique(op.slideIds);
    for (final id in ids) {
      deleteSlide(slideOf(id));
    }
    return ids.length == 1 ? 'Delete slide' : 'Delete ${ids.length} slides';
  }

  String moveSlides(MoveSlides op) {
    final ids = unique(op.slideIds).toSet();
    for (final id in ids) {
      slideOf(id);
    }
    final ordered = [
      for (final e in ix.order.entries)
        if (ids.contains(e.id)) e.slide,
    ];
    final (groupId, keys) = keysAt(op.target, ordered.length, exclude: ids);
    for (final (i, s) in ordered.indexed) {
      // groupId and sortKey together (02 P4).
      b.set(
        s,
        {SlideCols.groupId: groupId, SlidesCols.sortKey: keys[i]},
        together: const {SlideCols.groupId, SlidesCols.sortKey},
      );
    }
    return ordered.length == 1 ? 'Move slide' : 'Move ${ordered.length} slides';
  }

  String setSlideProps(SetSlideProps op) {
    final ids = unique(op.slideIds);
    String? notes;
    if (op.notes != null) {
      notes = _notes(op.notes!.value);
    }
    for (final id in ids) {
      final s = slideOf(id);
      b.set(s, {
        SlidesCols.skipped: ?op.skipped,
        if (op.notes != null) SlideCols.notes: notes,
        if (op.backgroundJson != null)
          SlidesCols.backgroundJson: _background(op.backgroundJson!.value),
        if (op.transitionJson != null)
          SlidesCols.transitionJson: transitionValue(
            op.transitionJson!.value,
            SlidesCols.transitionJson,
          ),
        if (op.hideMasterElements != null)
          SlidesCols.hideMasterElements: op.hideMasterElements!.value,
        if (op.timingsJson != null)
          SlideCols.timingsJson: jsonObject(
            op.timingsJson!.value,
            SlideCols.timingsJson,
          ),
      });
      if (op.layoutId != null) applyLayout(s, op.layoutId!);
    }
    if (op.layoutId != null) return 'Apply layout';
    if (op.skipped != null) {
      return op.skipped!
          ? plural(ids.length, 'Skip slide', 'Skip slides')
          : plural(ids.length, "Don't skip slide", "Don't skip slides");
    }
    if (op.notes != null) return 'Edit notes';
    if (op.backgroundJson != null) return 'Change background';
    if (op.transitionJson != null) return 'Change transition';
    return 'Slide settings';
  }

  /// Validated speaker notes (02 §4.3, §13), or null.
  String? _notes(String? delta) {
    if (delta == null) return null;
    final String n;
    try {
      n = SlidesText.normalizeJson(delta, notes: true)!;
    } on FormatException catch (e) {
      invalid('Invalid notes: ${e.message}');
    }
    final max = limits.maxNotesLength;
    if (SlidesText.lengthOf(n) > max) {
      limit('Speaker notes can have at most ${_Planner._fmt(max)} characters.');
    }
    return n;
  }

  /// A validated background JSON (05 §2.6), or null.
  String? _background(String? json) {
    if (json == null) return null;
    final m = decodeMap(jsonObject(json, SlidesCols.backgroundJson));
    final sink = IssueSink();
    final bg = SlideBackground.fromJson(
      m,
      sink,
      path: SlidesCols.backgroundJson,
    );
    if (bg == null || sink.hasErrors) {
      invalid(
        'Invalid background: '
        '${sink.errors.map((e) => '${e.path}: ${e.message}').join('; ')}',
      );
    }
    return jsonEncode(bg.toJson());
  }

  /// Applies [layoutId] to [s] with the placeholder remap of 05 §5.4.
  void applyLayout(SlideRec s, String layoutId) {
    final layout = layoutOf(layoutId);
    if (ix.themes.themeOfLayout(layout) == null) notFound('Layout', layoutId);
    final current = b.rec(SlidesTables.slide, s.id)! as SlideRec;
    final oldLayout = ix.themes.effectiveLayout(current);
    final oldOrder = <String, int>{
      if (oldLayout != null)
        for (final (i, p)
            in ix.placeholders.placeholdersOf(oldLayout.id).indexed)
          p.id: i,
    };
    final instances = [
      for (final e in deck.elementsOf(s.id))
        if (e.placeholderType != null &&
            b.exists(SlidesTables.slideElement, e.id))
          b.rec(SlidesTables.slideElement, e.id)! as SlideElementRec,
    ];
    instances.sort((a, c) {
      final ia = oldOrder[a.placeholderOf] ?? 1 << 20;
      final ic = oldOrder[c.placeholderOf] ?? 1 << 20;
      if (ia != ic) return ia.compareTo(ic);
      return FractionalIndex.compare(
        a.readingKey ?? a.zKey,
        a.id,
        c.readingKey ?? c.zKey,
        c.id,
      );
    });
    final targets = ix.placeholders.placeholdersOf(layoutId);
    final remap = LayoutRemapper.remap(
      [
        for (final i in instances)
          RemapInstance(
            id: i.id,
            type: i.placeholderType!,
            isEmpty: _isEmpty(i),
          ),
      ],
      [
        for (final t in targets)
          RemapTarget(id: t.id, type: t.placeholderType!),
      ],
    );
    for (final MapEntry(key: id, value: target) in remap.repoint.entries) {
      b.update(SlidesTables.slideElement, id, {
        ElementCols.placeholderOf: target,
      });
    }
    for (final id in remap.materialize) {
      materialize(deck.element(id)!, clearPlaceholder: true);
    }
    for (final id in remap.delete) {
      deleteElementTree(deck.element(id)!);
    }
    final z = zItems(s.id, null);
    final byId = {for (final t in targets) t.id: t};
    instantiate(s.id, [
      for (final id in remap.create) byId[id]!,
    ], afterZ: z.isEmpty ? null : z.last.$1);
    b.set(current, {SlideCols.layoutId: layoutId});
  }

  /// Whether a placeholder instance holds no content (05 §5.4).
  bool _isEmpty(SlideElementRec e) {
    if (!SlidesText.isBlank(e.text)) return false;
    return switch (e.kind) {
      ElementKind.code => deck.codeStatesOf(e.id).isEmpty,
      ElementKind.table => deck.axesOf(e.id, TableAxisDimension.row).isEmpty,
      ElementKind.chart => deck.chartLinkOf(e.id) == null && e.dataJson == null,
      ElementKind.image || ElementKind.icon => e.dataJson == null,
      ElementKind.group => false,
      _ => true,
    };
  }

  /// Writes [e]'s effective frame and style into its columns (02 §10,
  /// 05 §5.4): the element no longer inherits. With [clearPlaceholder] it
  /// becomes a regular element (`placeholderType`/`placeholderOf` null);
  /// otherwise [placeholderOf] is written.
  void materialize(
    SlideElementRec e, {
    bool clearPlaceholder = false,
    String? placeholderOf,
  }) {
    final eff = ix.placeholders.effective(e, bounds: bounds);
    String? enc(JsonMap? m) => m == null ? null : jsonEncode(m);
    final text = eff.textStyle;
    b.set(
      e,
      {
        ElementCols.x: e.x ?? eff.frame.x,
        ElementCols.y: e.y ?? eff.frame.y,
        ElementCols.width: e.width ?? eff.frame.width,
        ElementCols.height: e.height ?? eff.frame.height,
        if (e.rotation == null && eff.rotation != 0)
          ElementCols.rotation: eff.rotation,
        ElementCols.textStyleJson:
            text == BoxTextStyle.empty && e.textStyleJson == null
            ? null
            : jsonEncode(
                text
                    .merge(BoxTextStyle(defaults: {'style': eff.styleKey}))
                    .toJson(),
              ),
        ElementCols.fillJson: e.fillJson ?? enc(eff.fill),
        ElementCols.strokeJson: e.strokeJson ?? enc(eff.stroke),
        ElementCols.effectsJson: e.effectsJson ?? enc(eff.effects),
        if (clearPlaceholder) ...{
          ElementCols.placeholderType: null,
          ElementCols.placeholderOf: null,
        } else
          ElementCols.placeholderOf: placeholderOf,
      },
      together: const {
        ElementCols.x,
        ElementCols.y,
        ElementCols.width,
        ElementCols.height,
      },
    );
  }

  String resetSlideToLayout(ResetSlideToLayout op) {
    final ids = unique(op.slideIds);
    for (final id in ids) {
      final s = slideOf(id);
      for (final e in ix.placeholders.instancesOf(id)) {
        b.set(
          e,
          {
            ElementCols.x: null,
            ElementCols.y: null,
            ElementCols.width: null,
            ElementCols.height: null,
            ElementCols.rotation: null,
            ElementCols.textStyleJson: null,
            ElementCols.fillJson: null,
            ElementCols.strokeJson: null,
            ElementCols.effectsJson: null,
            ElementCols.opacity: null,
          },
          together: const {
            ElementCols.x,
            ElementCols.y,
            ElementCols.width,
            ElementCols.height,
          },
        );
      }
      final layout = ix.themes.effectiveLayout(s);
      if (layout == null) continue;
      final pointed = {
        for (final e in ix.placeholders.instancesOf(id)) e.placeholderOf,
      };
      final z = zItems(id, null);
      instantiate(id, [
        for (final p in ix.placeholders.placeholdersOf(layout.id))
          if (!pointed.contains(p.id)) p,
      ], afterZ: z.isEmpty ? null : z.last.$1);
    }
    return plural(ids.length, 'Reset slide', 'Reset slides');
  }
}
