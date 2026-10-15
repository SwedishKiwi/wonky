part of '../slides_planner.dart';

// Builds (06), code states (07) and chart links (08): the row-level
// planning of M9; effect catalogs, option schemas and code/chart behavior
// are validated by SL-24/SL-26/SL-27 when they extend these ops.

/// `SlideBuild` columns an `UpdateBuilds` may write.
const _buildColumns = {
  SlidesCols.kind,
  BuildCols.effect,
  BuildCols.trigger,
  BuildCols.delayMs,
  BuildCols.durationMs,
  BuildCols.easing,
  BuildCols.optionsJson,
};

/// `CodeState` columns callers may write.
const _codeStateColumns = {
  SlidesCols.label,
  CodeStateCols.code,
  CodeStateCols.language,
  SlidesCols.title,
  CodeStateCols.highlight,
  CodeStateCols.annotationsJson,
  SlidesCols.transitionJson,
};

extension _MotionPart on _Planner {
  // ---------------------------------------------------------------------------
  // Builds.

  SlideBuildRec _buildOf(String id) => deck.build(id) ?? notFound('Build', id);

  /// Validates build columns (06 §2–§4): kind/trigger names (the reserved
  /// `onElementClick` is refused), delay 0–60,000 ms, duration 0–20,000
  /// ms, a catalog effect of the (resulting) kind, an easing of the 06 §4.3
  /// grammar and `optionsJson` per 06 §2.2 — wrong types are refused,
  /// out-of-range values are clamped (plan warnings) and the normalized
  /// JSON is written. [current] is the build being updated.
  Map<String, Object?> _buildValues(
    Map<String, Object?> cols, {
    SlideBuildRec? current,
  }) {
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in cols.entries) {
      if (!_buildColumns.contains(key)) {
        invalid('Column $key can\'t be set on a build', {'column': key});
      }
      switch (key) {
        case SlidesCols.kind:
          if (SlideBuildKind.fromName(value) == null) {
            invalid('Unknown build kind $value');
          }
        case BuildCols.trigger:
          final t = SlideBuildTrigger.fromName(value);
          if (t == null) invalid('Unknown build trigger $value');
          if (t == SlideBuildTrigger.onElementClick) {
            invalid('Triggers on click of an object are not supported yet');
          }
        case BuildCols.delayMs:
          if (value is! int || value < 0 || value > 60000) {
            invalid('$key must be 0–60,000 ms');
          }
        case BuildCols.durationMs:
          if (value is! int || value < 0 || value > 20000) {
            invalid('$key must be 0–20,000 ms');
          }
        case BuildCols.easing:
          if (value is! String || MotionEasing.tryParse(value) == null) {
            invalid('Unknown easing "$value"', {'column': key});
          }
        case BuildCols.effect:
          if (value is! String || value.isEmpty || value.length > 200) {
            invalid('$key must be a non-empty string');
          }
        case BuildCols.optionsJson:
          out[key] = jsonObject(value as String?, key);
          continue;
      }
      out[key] = value;
    }
    final touchesEffect =
        out.containsKey(SlidesCols.kind) ||
        out.containsKey(BuildCols.effect) ||
        out.containsKey(BuildCols.optionsJson);
    if (!touchesEffect) return out;
    final kind =
        SlideBuildKind.fromName(out[SlidesCols.kind] ?? current?.kind.name) ??
        SlideBuildKind.buildIn;
    final effect = (out[BuildCols.effect] ?? current?.effect ?? '') as String;
    if (EffectCatalog.byId(kind, effect) == null) {
      invalid('Unknown ${kind.name} effect "$effect"', {'effect': effect});
    }
    final options = out.containsKey(BuildCols.optionsJson)
        ? out[BuildCols.optionsJson] as String?
        : current?.optionsJson;
    final v = BuildOptions.decode(options, kind: kind, effect: effect);
    if (!v.isValid) {
      invalid('Invalid animation options: ${v.errors.first}', {
        'issues': [for (final e in v.errors) e.toJson()],
      });
    }
    for (final w in v.warnings) {
      warnings.add(w.toString());
    }
    if (out.containsKey(BuildCols.optionsJson) || v.warnings.isNotEmpty) {
      out[BuildCols.optionsJson] = v.value.encode();
    }
    return out;
  }

  String addBuilds(AddBuilds op) {
    final s = slideOf(op.slideId);
    final existing = OrderKeys.sorted([
      for (final bd in deck.buildsOf(s.id)) (bd.sortKey, bd.id),
    ]);
    if (existing.length + op.builds.length > limits.maxBuildsPerSlide) {
      limit('A slide can have at most ${limits.maxBuildsPerSlide} animations.');
    }
    final at = op.afterBuildId == null
        ? existing.length
        : OrderKeys.indexFor(existing, afterId: op.afterBuildId);
    if (at < 0) notFound('Build', op.afterBuildId!);
    final keys = OrderKeys.at(existing, at, op.builds.length);
    final ids = <String>[];
    for (final (i, spec) in op.builds.indexed) {
      final el = elementOf(spec.elementId);
      if (el.slideId != s.id) {
        invalid('${spec.elementId} is not on slide ${s.id}');
      }
      final id = newId();
      ids.add(id);
      b.insert(SlidesTables.slideBuild, {
        SlidesCols.id: id,
        SlidesCols.slideId: s.id,
        SlidesCols.elementId: el.id,
        ..._buildValues({
          SlidesCols.kind: spec.kind.name,
          BuildCols.effect: spec.effect,
          BuildCols.trigger: spec.trigger.name,
          BuildCols.delayMs: spec.delayMs,
          BuildCols.durationMs: spec.durationMs,
          BuildCols.easing: spec.easing,
          BuildCols.optionsJson: spec.optionsJson,
        }),
        SlidesCols.sortKey: keys[i],
        SlidesCols.createdAt: ctx.now,
      });
    }
    result['buildIds'] = ids;
    return plural(ids.length, 'Add animation', 'Add animations');
  }

  String updateBuilds(UpdateBuilds op) {
    for (final MapEntry(key: id, value: cols) in op.updates.entries) {
      final bd = _buildOf(id);
      b.set(bd, _buildValues(cols, current: bd));
    }
    return 'Change animation';
  }

  String moveBuilds(MoveBuilds op) {
    final ids = unique(op.buildIds).toSet();
    if (ids.isEmpty) return 'Reorder animations';
    final builds = [for (final id in ids) _buildOf(id)];
    final slideId = builds.first.slideId!;
    if (builds.any((x) => x.slideId != slideId)) {
      invalid('Builds of different slides can\'t be moved together');
    }
    final items = OrderKeys.sorted([
      for (final bd in deck.buildsOf(slideId)) (bd.sortKey, bd.id),
    ]);
    final at = OrderKeys.indexFor(
      items,
      beforeId: op.beforeId,
      afterId: op.afterId,
    );
    if (at < 0) notFound('Build', (op.afterId ?? op.beforeId)!);
    final moving = [
      for (final it in items)
        if (ids.contains(it.$2)) deck.build(it.$2)!,
    ];
    final keys = OrderKeys.at(items, at, moving.length, exclude: ids);
    final trigger = op.trigger;
    if (trigger == SlideBuildTrigger.onElementClick) {
      invalid('Triggers on click of an object are not supported yet');
    }
    for (final (i, bd) in moving.indexed) {
      b.set(bd, {
        SlidesCols.sortKey: keys[i],
        if (i == 0 && trigger != null) BuildCols.trigger: trigger.name,
      });
    }
    return 'Reorder animations';
  }

  String deleteBuilds(DeleteBuilds op) {
    final ids = unique(op.buildIds);
    for (final id in ids) {
      b.remove(_buildOf(id));
    }
    return plural(ids.length, 'Delete animation', 'Delete animations');
  }

  // ---------------------------------------------------------------------------
  // Code states.

  CodeStateRec _stateOf(String id) =>
      deck.record(SlidesTables.codeState, id) as CodeStateRec? ??
      notFound('Code state', id);

  String _code(String code) {
    if (code.length > limits.maxCodeLength) {
      limit(
        'A code state can hold at most ${_Planner._fmt(limits.maxCodeLength)} characters.',
      );
    }
    if ('\n'.allMatches(code).length + 1 > limits.maxCodeLines) {
      limit(
        'A code state can hold at most ${_Planner._fmt(limits.maxCodeLines)} lines.',
      );
    }
    return code;
  }

  Map<String, Object?> _stateValues(Map<String, Object?> cols) {
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in cols.entries) {
      if (!_codeStateColumns.contains(key)) {
        invalid('Column $key can\'t be set on a code state', {'column': key});
      }
      out[key] = switch (key) {
        CodeStateCols.code => _code((value as String?) ?? ''),
        CodeStateCols.annotationsJson ||
        SlidesCols.transitionJson => jsonObject(value as String?, key),
        _ => value,
      };
    }
    return out;
  }

  /// Inserts a code state of [elementId].
  String insertCodeState(
    String elementId,
    String key,
    Map<String, Object?> cols,
  ) {
    final id = newId();
    b.insert(SlidesTables.codeState, {
      SlidesCols.id: id,
      SlidesCols.elementId: elementId,
      SlidesCols.sortKey: key,
      CodeStateCols.code: '',
      ..._stateValues(cols),
      SlidesCols.createdAt: ctx.now,
    });
    return id;
  }

  SlideElementRec _codeElement(String id) {
    final e = elementOf(id);
    if (e.kind != ElementKind.code) invalid('$id is not a code block');
    return e;
  }

  String setCode(SetCode op) {
    b.set(_stateOf(op.stateId), {CodeStateCols.code: _code(op.code)});
    return 'Edit code';
  }

  String addCodeStates(AddCodeStates op) {
    final e = _codeElement(op.elementId);
    final items = OrderKeys.sorted([
      for (final s in deck.codeStatesOf(e.id)) (s.sortKey, s.id),
    ]);
    if (items.length + op.states.length > limits.maxCodeStates) {
      limit('A code block can have at most ${limits.maxCodeStates} states.');
    }
    final at = op.afterStateId == null
        ? items.length
        : OrderKeys.indexFor(items, afterId: op.afterStateId);
    if (at < 0) notFound('Code state', op.afterStateId!);
    final keys = OrderKeys.at(items, at, op.states.length);
    result['stateIds'] = [
      for (final (i, s) in op.states.indexed) insertCodeState(e.id, keys[i], s),
    ];
    return 'Add code state';
  }

  String updateCodeState(UpdateCodeState op) {
    b.set(_stateOf(op.stateId), _stateValues(op.columns));
    return 'Edit code state';
  }

  String moveCodeStates(MoveCodeStates op) {
    final ids = unique(op.stateIds).toSet();
    if (ids.isEmpty) return 'Reorder code states';
    final states = [for (final id in ids) _stateOf(id)];
    final el = states.first.elementId!;
    if (states.any((s) => s.elementId != el)) {
      invalid('States of different code blocks can\'t be moved together');
    }
    final items = OrderKeys.sorted([
      for (final s in deck.codeStatesOf(el)) (s.sortKey, s.id),
    ]);
    final at = OrderKeys.indexFor(
      items,
      beforeId: op.beforeId,
      afterId: op.afterId,
    );
    if (at < 0) notFound('Code state', (op.afterId ?? op.beforeId)!);
    final moving = [
      for (final it in items)
        if (ids.contains(it.$2)) _stateOf(it.$2),
    ];
    final keys = OrderKeys.at(items, at, moving.length, exclude: ids);
    for (final (i, s) in moving.indexed) {
      b.set(s, {SlidesCols.sortKey: keys[i]});
    }
    return 'Reorder code states';
  }

  String deleteCodeStates(DeleteCodeStates op) {
    final ids = unique(op.stateIds).toSet();
    final byElement = <String, int>{};
    for (final id in ids) {
      final s = _stateOf(id);
      byElement[s.elementId!] = (byElement[s.elementId!] ?? 0) + 1;
    }
    for (final MapEntry(key: el, value: n) in byElement.entries) {
      if (deck.codeStatesOf(el).length - n < 1) {
        invalid('A code block keeps at least one state');
      }
    }
    for (final id in ids) {
      b.remove(_stateOf(id));
    }
    return plural(ids.length, 'Delete code state', 'Delete code states');
  }

  // ---------------------------------------------------------------------------
  // Charts.

  SlideElementRec _chartElement(String id) {
    final e = elementOf(id);
    if (e.kind != ElementKind.chart) invalid('$id is not a chart');
    return e;
  }

  /// A snapshot column: a JSON object, or its `gz:` storage form (08 §3.3),
  /// validated by decoding.
  String _snapshotColumn(String value, String column) {
    if (!ChartSnapshotColumns.isCompressed(value)) {
      return jsonObject(value, column)!;
    }
    final json = ChartSnapshotColumns.decode(value);
    if (json == '{}') invalid('$column is not a valid gz: value');
    jsonObject(json, column);
    return value;
  }

  /// The JSON object stored in a snapshot column (`gz:` decoded).
  static JsonMap? _columnObject(String value) {
    try {
      final v = jsonDecode(ChartSnapshotColumns.decode(value));
      return v is Map<String, Object?> ? v : null;
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> _snapshot(ChartSnapshot s) => {
    ChartLinkCols.sourceSpecJson: _snapshotColumn(
      s.sourceSpecJson,
      ChartLinkCols.sourceSpecJson,
    ),
    ChartLinkCols.dataSnapshotJson: _snapshotColumn(
      s.dataSnapshotJson,
      ChartLinkCols.dataSnapshotJson,
    ),
    ChartLinkCols.sourceVersion: s.sourceVersion,
    ChartLinkCols.sheetId: s.sheetId,
    ChartLinkCols.updatedAt: ctx.now,
    ChartLinkCols.updatedBy: ctx.userId,
  };

  static const _snapshotColumns = {
    ChartLinkCols.sourceSpecJson,
    ChartLinkCols.dataSnapshotJson,
    ChartLinkCols.sourceVersion,
    ChartLinkCols.sheetId,
    ChartLinkCols.updatedAt,
    ChartLinkCols.updatedBy,
  };

  String linkChart(LinkChart op) {
    final e = _chartElement(op.elementId);
    final id = SlidesIds.chartLinkId(e.id);
    final cols = {
      ChartLinkCols.spreadsheetItemUuid: op.spreadsheetItemUuid,
      ChartLinkCols.chartObjectId: op.chartObjectId,
      ..._snapshot(op.snapshot),
      ChartLinkCols.autoUpdate: op.autoUpdate,
    };
    if (b.exists(SlidesTables.chartLink, id)) {
      b.update(SlidesTables.chartLink, id, cols, together: _snapshotColumns);
    } else {
      b.insert(SlidesTables.chartLink, {
        SlidesCols.id: id,
        SlidesCols.elementId: e.id,
        ...cols,
        SlidesCols.createdAt: ctx.now,
      });
    }
    // A relinked static chart drops its frozen snapshot (SL-32).
    final data = mergePatch(decodeMap(e.dataJson), {
      'v': 1,
      'source': 'linked',
      'snapshot': null,
      'spec': null,
      'data': null,
    });
    b.set(e, {ElementCols.dataJson: jsonEncode(data)});
    return 'Link chart';
  }

  ChartLinkRec _link(String elementId) {
    _chartElement(elementId);
    return deck.chartLinkOf(elementId) ?? notFound('Chart link of', elementId);
  }

  String updateChartLink(UpdateChartLink op) {
    b.set(
      _link(op.elementId),
      _snapshot(op.snapshot),
      together: _snapshotColumns,
    );
    return 'Update chart';
  }

  String setChartAutoUpdate(SetChartAutoUpdate op) {
    b.set(_link(op.elementId), {ChartLinkCols.autoUpdate: op.autoUpdate});
    return op.autoUpdate
        ? 'Update automatically'
        : "Don't update automatically";
  }

  String unlinkChart(UnlinkChart op) {
    final link = _link(op.elementId);
    final e = elementOf(op.elementId);
    // The snapshot moves into `dataJson.snapshot` (08 §3.2, §7).
    final data = mergePatch(decodeMap(e.dataJson), {
      'v': 1,
      'source': 'static',
      'snapshot': null,
      'spec': null,
      'data': null,
    });
    data['snapshot'] = {
      'sourceSpec': _columnObject(link.sourceSpecJson) ?? const {'v': 1},
      'dataSnapshot': _columnObject(link.dataSnapshotJson) ?? const {'v': 1},
    };
    b.set(e, {ElementCols.dataJson: jsonEncode(data)});
    b.remove(link);
    return 'Unlink chart';
  }

  String setChartStyle(SetChartStyle op) {
    final e = _chartElement(op.elementId);
    // Deck-side keys only; overrides within the allowlist (08 §8.2, §14).
    final native = decodeMap(e.dataJson)?['source'] == 'native';
    for (final k in op.patch.keys) {
      if (!native && const {'source', 'snapshot', 'spec', 'data'}.contains(k)) {
        invalid('Chart "$k" is changed by linking, updating or unlinking', {
          'key': k,
        });
      }
    }
    final overrides = op.patch['overrides'];
    if (overrides is Map && !native) {
      final rejected = ChartOverrides.rejectedPaths(
        overrides.cast<String, Object?>(),
      );
      if (rejected.isNotEmpty) {
        invalid(
          'Edit ${rejected.join(', ')} in Wonky Sheets: Slides only overrides '
          'the presentation of linked charts',
          {'paths': rejected},
        );
      }
    }
    final data = mergePatch(decodeMap(e.dataJson), op.patch);
    data['v'] ??= 1;
    b.set(e, {ElementCols.dataJson: jsonEncode(data)});
    return 'Chart style';
  }
}
