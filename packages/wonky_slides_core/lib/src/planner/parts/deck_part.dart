part of '../slides_planner.dart';

extension _DeckPart on _Planner {
  /// *New presentation* (02 §9.3): deck row, theme copy (deterministic
  /// ids), first slide with its placeholder instances.
  String createDeck(CreateDeck op) {
    if (deck.deck != null) invalid('The presentation already exists');
    if (op.deckId != deck.deckId) {
      invalid('deckId must be the model\'s deck id ${deck.deckId}');
    }
    final title = _title(op.title);
    final def =
        BuiltInThemes.byKey(op.themeKey) ??
        invalid('Unknown theme ${op.themeKey}', {'themeKey': op.themeKey});
    final size = op.size ?? SlideSize.widescreen;
    final sizeError = SlideSize.validate(size.width, size.height);
    if (sizeError != null) invalid(sizeError);
    final pkg = BuiltInThemes.package(op.themeKey, size: size)!;
    final (rows, ids) = ThemeCopy.packageRows(
      pkg,
      deckId: op.deckId,
      sourceKey: SlidesIds.builtinThemeSourceKey(def.key, def.version),
      now: ctx.now,
    );
    b.insert(SlidesTables.deck, {
      SlidesCols.id: op.deckId,
      DeckCols.title: title,
      DeckCols.width: size.width,
      DeckCols.height: size.height,
      DeckCols.sizePreset: size.kind.name,
      DeckCols.themeId: ids.themeId,
      DeckCols.appearance: (op.appearance ?? pkg.defaultAppearance).name,
      DeckCols.showSlideNumbers: false,
      DeckCols.hideNumberOnTitle: true,
      DeckCols.firstSlideNumber: 1,
      DeckCols.createdBy: ctx.userId,
      SlidesCols.createdAt: ctx.now,
    });
    for (final (t, c) in rows) {
      b.insert(t, c);
    }
    final first = op.firstLayoutKey;
    if (first != null) {
      final layoutId =
          ids.layoutIds[first] ??
          ids.layoutIds['titleBody'] ??
          ids.layoutIds.values.first;
      final slideId = newId();
      insertSlide(slideId, {
        SlidesCols.sortKey: FractionalIndex.first(),
        SlideCols.groupId: null,
        SlideCols.layoutId: layoutId,
      });
      instantiate(slideId, [
        for (final (t, c) in rows)
          if (t == SlidesTables.slideElement &&
              c[ElementCols.layoutId] == layoutId)
            SlideElementRec(c),
      ]);
      result['slideIds'] = [slideId];
    }
    result['themeId'] = ids.themeId;
    return 'Create presentation';
  }

  /// `Deck.defaultsJson`: a JSON object whose `transition` (06 A-06-7) is
  /// a valid transition.
  String? _defaults(String? json) {
    final checked = jsonObject(json, DeckCols.defaultsJson);
    if (checked == null) return null;
    final raw = decodeMap(checked);
    final t = raw?['transition'];
    if (t != null) {
      if (t is! Map<String, Object?>) {
        invalid('The default transition must be an object');
      }
      final v = TransitionSpec.fromJson(t);
      if (!v.isValid) invalid('Invalid default transition: ${v.errors.first}');
    }
    // Keeps the unknown keys of other specs (07's codeFontSize, …).
    DeckMotionDefaults.decode(checked);
    return checked;
  }

  String _title(String raw) {
    final t = raw.trim();
    if (t.isEmpty) invalid('The title must not be empty');
    if (t.length > 255) invalid('The title can have at most 255 characters');
    return t;
  }

  String setDeckProps(SetDeckProps op) {
    final d = deckRow();
    if (op.firstSlideNumber != null &&
        (op.firstSlideNumber! < 0 || op.firstSlideNumber! > 100000)) {
      invalid('The first slide number must be between 0 and 100,000');
    }
    b.set(d, {
      if (op.title != null) DeckCols.title: _title(op.title!),
      if (op.appearance != null) DeckCols.appearance: op.appearance!.name,
      DeckCols.showSlideNumbers: ?op.showSlideNumbers,
      DeckCols.hideNumberOnTitle: ?op.hideNumberOnTitle,
      DeckCols.firstSlideNumber: ?op.firstSlideNumber,
      if (op.footerText != null) DeckCols.footerText: op.footerText!.value,
      if (op.language != null) DeckCols.language: op.language!.value,
      if (op.defaultsJson != null)
        DeckCols.defaultsJson: _defaults(op.defaultsJson!.value),
      if (op.guidesJson != null)
        DeckCols.guidesJson: jsonObject(
          op.guidesJson!.value,
          DeckCols.guidesJson,
        ),
      if (op.presentJson != null)
        DeckCols.presentJson: jsonObject(
          op.presentJson!.value,
          DeckCols.presentJson,
        ),
    });
    if (op.resetSlideTransitions) {
      for (final s in deck.slides) {
        if (s.transitionJson != null) {
          b.set(s, {SlidesCols.transitionJson: null});
        }
      }
    }
    final size = op.size;
    if (size != null) _resize(d, size);
    if (op.title != null) return 'Rename presentation';
    if (op.resetSlideTransitions) return 'Apply transition to all slides';
    if (size != null) return 'Change slide size';
    if (op.appearance != null) return 'Change appearance';
    return 'Presentation settings';
  }

  /// Page size change (05 §7): `width/height/sizePreset` together and, with
  /// *Scale content*, every frame, explicit font size, stroke width and
  /// inset of slides, layouts and masters; built-in layouts are re-generated
  /// for the new size.
  void _resize(DeckRec d, DeckSizeChange change) {
    final to = change.size;
    final err = SlideSize.validate(to.width, to.height);
    if (err != null) invalid(err);
    final from = SlideSize(d.sizePreset, d.width, d.height);
    b.set(
      d,
      {
        DeckCols.width: to.width,
        DeckCols.height: to.height,
        DeckCols.sizePreset: to.kind.name,
      },
      together: const {DeckCols.width, DeckCols.height, DeckCols.sizePreset},
    );
    if (change.mode == SizeScaleMode.keep) return;
    final scaling = SlideSizeScaling(from, to);
    if (scaling.isIdentity) return;
    final s = scaling.scale;

    // Built-in themes: placeholders and decorations from the package for
    // the new size (by part key), theme text styles too when unmodified.
    final regenerated = <String, ThemeElementSpec>{};
    for (final t in deck.themes) {
      final def = t.sourceKey == null
          ? null
          : BuiltInThemes.bySourceKey(t.sourceKey!);
      if (def == null) {
        _scaleThemeText(t, s);
        continue;
      }
      final oldPkg = BuiltInThemes.package(def.key, size: from)!;
      final newPkg = BuiltInThemes.package(def.key, size: to)!;
      for (final m in newPkg.masters) {
        for (final e in m.elements) {
          regenerated[SlidesIds.themePartId(t.id, e.partKey)] = e;
        }
        for (final l in m.layouts) {
          for (final e in l.elements) {
            regenerated[SlidesIds.themePartId(t.id, e.partKey)] = e;
          }
        }
      }
      final oldStyles = jsonEncode(oldPkg.theme.textStyles.toJson());
      final cur = decodeMap(t.themeColumns[DeckThemeCols.textStylesJson]);
      if (cur != null &&
          canonicalJson(cur) == canonicalJson(jsonDecode(oldStyles))) {
        b.set(t, {
          DeckThemeCols.textStylesJson: jsonEncode(
            newPkg.theme.textStyles.toJson(),
          ),
        });
      } else {
        _scaleThemeText(t, s);
      }
    }

    for (final table in const [SlidesTables.slideElement]) {
      for (final r in deck.records(table)) {
        final e = r as SlideElementRec;
        final spec = regenerated[e.id];
        final after = <String, Object?>{};
        if (e.parentId == null) {
          if (spec != null) {
            after.addAll({
              ElementCols.x: spec.frame.x,
              ElementCols.y: spec.frame.y,
              ElementCols.width: spec.frame.width,
              ElementCols.height: spec.frame.height,
            });
          } else if (e.frame != null) {
            final f = scaling.mapRect(e.frame!);
            after.addAll({
              ElementCols.x: f.x,
              ElementCols.y: f.y,
              ElementCols.width: clampSide(f.width),
              ElementCols.height: clampSide(f.height),
            });
          }
        }
        if (spec == null) {
          final box = PlaceholderIndex.decodeTextStyle(e.textStyleJson);
          if (box != null) {
            after[ElementCols.textStyleJson] = jsonEncode(
              box.scaled(s).toJson(),
            );
          }
          final stroke = decodeMap(e.strokeJson);
          if (stroke != null && stroke['width'] is num) {
            after[ElementCols.strokeJson] = jsonEncode({
              ...stroke,
              'width': normalizeJsonNumber((stroke['width']! as num) * s),
            });
          }
          if (e.text != null) after[SlidesCols.text] = _scaleDelta(e.text!, s);
        }
        b.set(
          e,
          after,
          together: {
            if (after.containsKey(ElementCols.x)) ...ElementCols.frame,
          },
        );
      }
    }
    for (final r in deck.records(SlidesTables.slideTableCell)) {
      final c = r as SlideTableCellRec;
      if (c.text != null) b.set(c, {SlidesCols.text: _scaleDelta(c.text!, s)});
    }
  }

  void _scaleThemeText(DeckThemeRec t, double s) {
    final data = SlideResolver.themeDataOf(t);
    b.set(t, {
      DeckThemeCols.textStylesJson: jsonEncode(
        data.textStyles.scaled(s).toJson(),
      ),
    });
  }

  /// [json] with every `size` attribute scaled (clamped to 6–800 su).
  String _scaleDelta(String json, double s) {
    final Delta d;
    try {
      d = SlidesText.parse(json);
    } on FormatException {
      return json;
    }
    var changed = false;
    final out = Delta();
    for (final op in d.operations) {
      final attrs = op.attributes;
      final size = attrs?['size'];
      if (size is num) {
        changed = true;
        out.insert(op.data, {
          ...attrs!,
          'size': normalizeJsonNumber(
            (size * s).clamp(limits.minFontSize, limits.maxFontSize),
          ),
        });
      } else {
        out.insert(op.data, attrs);
      }
    }
    return changed ? SlidesText.encode(out) : json;
  }

  String setDeckTheme(SetDeckTheme op) {
    final d = deckRow();
    themeOf(op.themeId);
    b.set(d, {DeckCols.themeId: op.themeId});
    return 'Set default theme';
  }
}
