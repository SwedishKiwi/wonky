part of 'script_host.dart';

/// Charts, filters, conditional formats, protections (09 §6.3 P1) and the
/// P2 `LockService` / `CacheService` (§6.12).
extension _ObjectsApi on ScriptHost {
  // -------------------------------------------------------------- sheet

  Object? _sheetObjects(SheetModel s, String method, List<Object?> a) {
    switch (method) {
      case 'sheet.charts':
        final charts =
            s.objects.values
                .where((o) => o.kind == EmbeddedObjectKind.chart)
                .toList()
              ..sort((x, y) => x.zIndex.compareTo(y.zIndex));
        return [for (final c in charts) _chartData(s, c)];
      case 'sheet.insertChart':
        return _insertChart(s, a[0] as String?, (a[1]! as Map).cast());
      case 'sheet.removeChart':
        final id = a[0] as String?;
        final o = id == null ? null : s.objects[id];
        if (o == null || o.kind != EmbeddedObjectKind.chart) {
          throw ScriptError('not_found', 'The chart is not on this sheet.');
        }
        _requireWrite(s.id);
        _apply(DeleteObject(o.id));
        return null;
      case 'sheet.filter':
        return s.basicFilter == null ? null : _sheetHandle(s.id);
      case 'sheet.cfRules':
        final rules = s.cfRules.values.toList()
          ..sort(
            (x, y) => FractionalIndex.compare(x.sortKey, x.id, y.sortKey, y.id),
          );
        return [for (final r in rules) _cfData(s, r)];
      case 'sheet.addCfRule':
        return _addCfRule(s, (a[0]! as Map).cast(), first: a[1] == true);
      case 'sheet.removeCfRule':
        final id = a[0] as String?;
        if (id == null || !s.cfRules.containsKey(id)) {
          throw ScriptError('not_found', 'The rule is not on this sheet.');
        }
        _requireWrite(s.id);
        _apply(DeleteCfRule(id));
        return null;
      case 'sheet.protect':
        return _addProtection(s, null);
      case 'sheet.protections':
        return [for (final p in s.protections.values) _protectionData(s, p)];
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  // ------------------------------------------------------------- charts

  Map<String, Object?> _chartData(SheetModel s, EmbeddedObjectRecord o) {
    final spec = ChartSpec.fromJson(o.specJson);
    final anchor = ObjectAnchor.tryParse(o.anchorJson);
    final ranges = <int>[];
    for (final ref in spec.data.ranges) {
      final g = GridRange.fromRef(ref);
      final sheet = _model.sheet(g.sheetId);
      final r = sheet?.resolve(g);
      if (r != null) ranges.add(_rangeHandle(r.sheetId, r.rect));
    }
    final row = anchor?.rowId == null ? -1 : s.rows.indexOf(anchor!.rowId!);
    final col = anchor?.colId == null ? -1 : s.columns.indexOf(anchor!.colId!);
    final title = o.title ?? spec.title.text;
    return {
      'id': o.id,
      'type': spec.type.id,
      'title': title.isEmpty ? null : title,
      'ranges': ranges,
      'row': row + 1,
      'column': col + 1,
      'width': anchor?.width ?? 0,
      'height': anchor?.height ?? 0,
      'options': const <String, Object?>{},
    };
  }

  Map<String, Object?> _insertChart(
    SheetModel s,
    String? existingId,
    Map<String, Object?> m,
  ) {
    _requireWrite(s.id);
    final ranges = <GridRange>[];
    for (final h in (m['ranges'] as List? ?? const []).cast<int>()) {
      final (rs, rect) = _rangeOf(h);
      ranges.add(rs.gridRange(rect));
    }
    if (ranges.isEmpty) {
      throw ScriptError.invalid('A chart needs at least one data range.');
    }
    final existing = existingId == null ? null : s.objects[existingId];
    if (existingId != null && existing == null) {
      throw ScriptError('not_found', 'The chart is not on this sheet.');
    }
    final type = '${m['type'] ?? ''}';
    var spec = existing == null
        ? _recommendedSpec(ranges, type)
        : ChartSpec.fromJson(existing.specJson);
    final patch = <String, Object?>{
      'data': {
        'ranges': [for (final g in ranges) g.toJson()],
      },
    };
    if (existing != null && type.isNotEmpty && type != spec.type.id) {
      final t = ChartType.tryParse(type);
      if (t == null || !t.isImplemented) {
        throw ScriptError.invalid('Unknown chart type "$type".');
      }
      patch['type'] = t.id;
    }
    final title = m['title'] as String?;
    patch['title'] = {'text': title ?? ''};
    final options = (m['options'] as Map?)?.cast<String, Object?>() ?? {};
    for (final e in options.entries) {
      _setPath(patch, e.key.split('.'), e.value);
    }
    try {
      spec = spec.patch(patch);
    } on Object catch (e) {
      throw ScriptError.invalid('Invalid chart options: $e');
    }
    final row = (m['row'] as int? ?? 0) - 1;
    final col = (m['column'] as int? ?? 0) - 1;
    final width = (m['width'] as num?)?.toDouble() ?? 0;
    final height = (m['height'] as num?)?.toDouble() ?? 0;
    String? anchorJson;
    if (existing == null || row >= 0 || width > 0) {
      final old = ObjectAnchor.tryParse(existing?.anchorJson);
      var r = row, c = col;
      if (r < 0 || c < 0) {
        final oldRow = old?.rowId == null ? -1 : s.rows.indexOf(old!.rowId!);
        final oldCol = old?.colId == null ? -1 : s.columns.indexOf(old!.colId!);
        if (oldRow >= 0 && oldCol >= 0) {
          r = oldRow;
          c = oldCol;
        } else {
          final first = ranges.first;
          final fr = first.sheetId == s.id ? s.resolve(first)?.rect : null;
          r = fr?.top ?? 0;
          c = fr == null ? 0 : math.min(fr.right + 2, s.columns.length - 1);
        }
      }
      anchorJson = ObjectAnchor.atCell(
        r,
        c,
        width: width > 0
            ? width
            : (old?.width ?? ObjectAnchor.defaultChartWidth),
        height: height > 0
            ? height
            : (old?.height ?? ObjectAnchor.defaultChartHeight),
        rows: s.rows,
        columns: s.columns,
      ).encode();
    }
    final id = existing?.id ?? workbook.ids.newId();
    if (existing == null) {
      _apply(
        AddObject(
          s.id,
          EmbeddedObjectKind.chart,
          anchorJson: anchorJson!,
          specJson: spec.encode(),
          title: (title == null || title.isEmpty) ? null : title,
          id: id,
        ),
      );
    } else {
      _apply(
        UpdateObject(
          id,
          anchorJson: anchorJson,
          specJson: spec.encode(),
          title: title ?? '',
        ),
      );
    }
    return _chartData(s, s.objects[id]!);
  }

  ChartSpec _recommendedSpec(List<GridRange> ranges, String type) {
    final profile = SelectionProfile.fromRanges(
      ranges,
      _model,
      workbook.engine,
    );
    final suggestions = ChartRecommender.recommend(profile);
    ChartType? wanted;
    if (type.isNotEmpty) {
      wanted = ChartType.tryParse(type);
      if (wanted == null || !wanted.isImplemented) {
        throw ScriptError.invalid('Unknown chart type "$type".');
      }
      for (final sg in suggestions) {
        if (sg.spec.type == wanted) return sg.spec;
      }
    }
    final base = suggestions.isEmpty
        ? ChartSpec(
            data: ChartDataSpec(ranges: [for (final r in ranges) r.toRef()]),
          )
        : suggestions.first.spec;
    return wanted == null ? base : base.patch({'type': wanted.id});
  }

  static void _setPath(Map<String, Object?> m, List<String> path, Object? v) {
    if (path.length == 1) {
      m[path.first] = v;
      return;
    }
    final child = m[path.first];
    final next = child is Map<String, Object?> ? child : <String, Object?>{};
    m[path.first] = next;
    _setPath(next, path.sublist(1), v);
  }

  // ------------------------------------------------------------- filter

  Object? _filterCall(int h, String method, List<Object?> a) {
    final s = _sheetOf(h);
    final f = s.basicFilter;
    if (f == null) throw ScriptError('not_found', 'The sheet has no filter.');
    final rect = s.resolve(GridRange.tryParse(f.rangeJson)!)?.rect;
    if (rect == null) throw ScriptError.range('The filter range was deleted.');
    int colId(Object? col) {
      final c = (col! as int) - 1;
      if (c < rect.left || c > rect.right) {
        throw ScriptError.range(
          'Column ${c + 1} is outside the filter range ${rect.a1}.',
        );
      }
      return c;
    }

    switch (method) {
      case 'filter.range':
        return _rangeHandle(s.id, rect);
      case 'filter.criteria':
        final c = colId(a[0]);
        final cr = FilterCriteria.parse(
          f.criteriaJson,
        ).columns[s.columns.idAt(c)];
        return cr?.toJson();
      case 'filter.setCriteria':
        _requireWrite(s.id);
        final c = colId(a[0]);
        final raw = (a[1] as Map?)?.cast<String, Object?>();
        Map<String, Object?>? criteria;
        if (raw != null) {
          criteria = {...raw};
          final cond = (raw['condition'] as Map?)?.cast<String, Object?>();
          if (cond != null) {
            criteria['condition'] = _storedCondition(
              s,
              cond,
              rect.top + 1,
              c,
              ConditionUse.filter,
            );
          }
        }
        _apply(
          SetFilterColumnCriteria(s.id, s.columns.idAt(c), criteria),
          cells: rect.cellCount,
        );
        return null;
      case 'filter.sort':
        _requireWrite(s.id, rect);
        final c = colId(a[0]);
        if (rect.rowCount < 2) return null;
        final body = GridRect(rect.top + 1, rect.left, rect.bottom, rect.right);
        _apply(
          SortRange(_resolved(s, body), [
            SortKeySpec(s.columns.idAt(c), ascending: a[1] != false),
          ]),
          cells: body.cellCount,
        );
        return null;
      case 'filter.remove':
        _requireWrite(s.id);
        _apply(RemoveBasicFilter(s.id));
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  /// A condition from the script (`{type, values: [{v}]}`) with formulas in
  /// stored form, validated for [use].
  Map<String, Object?> _storedCondition(
    SheetModel s,
    Map<String, Object?> c,
    int row,
    int col,
    ConditionUse use,
  ) {
    final type = ConditionType.byId(c['type'] as String?);
    if (type == null || !type.usableIn(use)) {
      throw ScriptError.invalid('Unknown condition type "${c['type']}".');
    }
    final raw = (c['values'] as List?) ?? const [];
    if (raw.length < type.arity) {
      throw ScriptError.invalid('${type.id} needs ${type.arity} value(s).');
    }
    final values = <Object?>[];
    for (final v in raw.take(type.arity)) {
      final x = v is Map ? v['v'] : v;
      final text = x is DateTime
          ? x.toIso8601String().substring(0, 10)
          : '${x ?? ''}';
      if (text.length > 1 && text.startsWith('=')) {
        final stored = workbook.formulas.toStored(
          text,
          sheetId: s.id,
          row: row,
          col: col,
        );
        values.add({'v': stored.startsWith('=') ? stored : '=$stored'});
      } else {
        values.add({'v': text});
      }
    }
    return {'type': type.id, if (values.isNotEmpty) 'values': values};
  }

  // ---------------------------------------------------------------- CF

  Map<String, Object?> _cfData(SheetModel s, CfRuleRecord r) {
    final ranges = <int>[];
    for (final g in GridRange.parseList(r.rangesJson)) {
      final rr = s.resolve(g);
      if (rr != null) ranges.add(_rangeHandle(s.id, rr.rect));
    }
    Object? rule;
    try {
      rule = jsonDecode(r.ruleJson);
    } on FormatException {
      rule = const <String, Object?>{};
    }
    return {
      'id': r.id,
      'ranges': ranges,
      'rule': rule is Map ? rule : const <String, Object?>{},
      'enabled': r.enabled,
    };
  }

  Map<String, Object?> _addCfRule(
    SheetModel s,
    Map<String, Object?> data, {
    required bool first,
  }) {
    final rects = <GridRect>[];
    for (final h in (data['ranges'] as List? ?? const []).cast<int>()) {
      final (rs, rect) = _rangeOf(h);
      if (rs.id != s.id) {
        throw ScriptError.range('The rule ranges must be on this sheet.');
      }
      rects.add(rect);
    }
    if (rects.isEmpty) {
      throw ScriptError.invalid('A conditional format rule needs ranges.');
    }
    _requireWrite(s.id);
    final rule = {...(data['rule']! as Map).cast<String, Object?>()};
    rule['v'] = 1;
    if (rule['type'] == 'boolean') {
      final cond = (rule['condition'] as Map?)?.cast<String, Object?>();
      if (cond == null) {
        throw ScriptError.invalid('A boolean rule needs a condition.');
      }
      rule['condition'] = _storedCondition(
        s,
        cond,
        rects.first.top,
        rects.first.left,
        ConditionUse.conditionalFormat,
      );
      final f = (rule['format'] as Map?)?.cast<String, Object?>() ?? {};
      rule['format'] = {
        for (final e in f.entries)
          e.key: e.value is String && e.key.endsWith('Color')
              ? _cfColor(e.value)
              : e.value,
      };
      rule['stopIfTrue'] = true;
    }
    final parsed = CfRule.parse(rule);
    if (parsed is CfUnknownRule) {
      throw ScriptError.invalid('Invalid conditional format rule.');
    }
    String? before;
    if (first) {
      final ordered = s.cfRules.values.toList()
        ..sort(
          (x, y) => FractionalIndex.compare(x.sortKey, x.id, y.sortKey, y.id),
        );
      before = ordered.firstOrNull?.id;
    }
    final id = workbook.ids.newId();
    _apply(
      AddCfRule(
        s.id,
        rects,
        jsonEncode(rule),
        beforeRuleId: before,
        ruleId: id,
      ),
      cells: rects.fold(0, (n, r) => n + r.cellCount),
    );
    return _cfData(s, s.cfRules[id]!);
  }

  String _cfColor(Object? v) {
    final c = '$v'.trim().toUpperCase();
    if (!RegExp(r'^#[0-9A-F]{6}$').hasMatch(c)) {
      throw ScriptError.invalid('Colors are "#RRGGBB" (got "$v").');
    }
    return c;
  }

  // -------------------------------------------------------- protections

  Map<String, Object?> _addProtection(SheetModel s, GridRect? rect) {
    if (context.role < Role.editor) {
      throw ScriptError.permission(
        'Only editors can protect ranges of this spreadsheet.',
      );
    }
    final id = workbook.ids.newId();
    _apply(
      AddProtection(
        s.id,
        range: rect,
        editors: [context.effectiveUser.id],
        id: id,
      ),
    );
    return _protectionData(s, s.protections[id]!);
  }

  Map<String, Object?> _protectionData(SheetModel s, ProtectedRangeRecord p) {
    final g = p.rangeJson == null ? null : GridRange.tryParse(p.rangeJson);
    final r = g == null ? null : s.resolve(g);
    return {'id': p.id, 'range': r == null ? null : _rangeHandle(s.id, r.rect)};
  }

  (SheetModel, ProtectedRangeRecord) _protection(Object? id) {
    for (final s in _model.sheets) {
      final p = s.protections['$id'];
      if (p != null) return (s, p);
    }
    throw ScriptError('not_found', 'The protection was removed.');
  }

  /// Owner, the protection's creator or its editors may change it.
  void _requireProtectionEditor(ProtectedRangeRecord p) {
    if (context.role == Role.owner) return;
    if (context.role < Role.editor) {
      throw ScriptError.permission('Only editors can change protections.');
    }
    final me = context.effectiveUser.id;
    if (p.createdBy == me) return;
    if (ScriptHost._stringList(p.editorsJson).contains(me)) return;
    throw ScriptError.permission(
      'Only the owner and the editors of a protection can change it.',
    );
  }

  Object? _protectionCall(String method, List<Object?> a) {
    final (s, p) = _protection(a[0]);
    switch (method) {
      case 'protection.get':
        return {
          'description': p.description ?? '',
          'warningOnly': p.warningOnly,
          'editors': ScriptHost._stringList(p.editorsJson),
        };
      case 'protection.update':
        _requireProtectionEditor(p);
        final m = (a[1]! as Map).cast<String, Object?>();
        List<GridRect>? except;
        if (m['exceptRanges'] is List) {
          except = [
            for (final h in (m['exceptRanges'] as List).cast<int>())
              _rangeOf(h).$2,
          ];
        }
        _apply(
          UpdateProtection(
            p.id,
            description: m['description'] as String?,
            warningOnly: m['warningOnly'] as bool?,
            editors: (m['editors'] as List?)?.cast<String>(),
            exceptRanges: except,
          ),
        );
        return null;
      case 'protection.remove':
        _requireProtectionEditor(p);
        _apply(DeleteProtection(p.id));
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method (${s.id})');
  }

  // ------------------------------------------------------ lock / cache

  String _scopeKey(Object? scope) {
    final ss = _model.spreadsheet.id;
    return scope == 'user' ? 'user:$ss:${context.effectiveUser.id}' : 'doc:$ss';
  }

  Object? _lockCall(String method, List<Object?> a) {
    final key = _scopeKey(a[0]);
    switch (method) {
      case 'lock.acquire':
        final ms = (a[1] as int? ?? 0).clamp(0, limits.timeout.inMilliseconds);
        final r = locks.acquire(key, this, Duration(milliseconds: ms));
        if (r is bool) {
          if (r) _heldLocks.add(key);
          return r;
        }
        if (!asyncCallsAllowed) {
          // The inline runner cannot wait.
          return false;
        }
        return r.then((ok) {
          if (ok) _heldLocks.add(key);
          return ok;
        });
      case 'lock.has':
        return locks.holds(key, this);
      case 'lock.release':
        locks.release(key, this);
        _heldLocks.remove(key);
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }

  Object? _cacheCall(String method, List<Object?> a) {
    final prefix = '${_scopeKey(a[0])}:';
    switch (method) {
      case 'cache.get':
        return cache.get('$prefix${a[1]}');
      case 'cache.getAll':
        return {
          for (final k in (a[1]! as List))
            if (cache.get('$prefix$k') case final String v) '$k': v,
        };
      case 'cache.put':
        final ttl = Duration(seconds: (a[2] as int? ?? 600).clamp(1, 21600));
        final values = (a[1]! as Map);
        for (final e in values.entries) {
          final v = '${e.value}';
          if (v.length > MemoryScriptCache.maxValueLength) {
            throw ScriptError.invalid(
              'Cache values are limited to 100 KB ("${e.key}").',
            );
          }
          cache.put('$prefix${e.key}', v, ttl);
        }
        return null;
      case 'cache.remove':
        for (final k in (a[1]! as List)) {
          cache.remove('$prefix$k');
        }
        return null;
    }
    throw ScriptError('not_found', 'Unknown host method $method');
  }
}
