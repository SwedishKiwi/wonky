part of 'slide_timeline.dart';

// Step compilation (06 §4.2, normative), part expansion (§2.3), validity
// (§2.4), fallbacks (§2.1) and reduced motion (§13).

/// What a part-based effect applies to.
sealed class _PartRef {
  const _PartRef();
}

final class _TextPartRef extends _PartRef {
  const _TextPartRef(this.start, this.end);
  final int start, end;
  String get key => '$start:$end';
}

final class _ChartPartRef extends _PartRef {
  const _ChartPartRef(this.key);
  final ChartPartKey key;
}

/// Typewriter reveal table: after `times[k]` ms (of one play), `offsets[k]`
/// UTF-16 units of the part are shown.
final class _Reveal {
  const _Reveal(this.start, this.offsets, this.times, this.totalMs);
  final int start;
  final List<int> offsets;
  final List<double> times;
  final double totalMs;

  /// Offset revealed at [ms].
  int at(double ms) {
    if (ms >= totalMs) return offsets.isEmpty ? start : offsets.last;
    var lo = 0, hi = times.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo == 0 ? start : offsets[lo - 1];
  }
}

/// A flattened motion path with arc-length parameterization.
final class _PathTable {
  _PathTable(this.xy, this.len);

  factory _PathTable.parse(String d) {
    final polys = PathOps.flatten(SvgPathParser.parse(d), curveSteps: 24);
    final xy = <double>[];
    for (final (pts, _) in polys) {
      xy.addAll(pts);
    }
    if (xy.length < 4) return _PathTable(const [0, 0, 0, 0], const [0, 0]);
    final len = <double>[0];
    for (var i = 2; i < xy.length; i += 2) {
      final dx = xy[i] - xy[i - 2], dy = xy[i + 1] - xy[i - 1];
      len.add(len.last + math.sqrt(dx * dx + dy * dy));
    }
    return _PathTable(xy, len);
  }

  final List<double> xy;
  final List<double> len;

  double get total => len.last;

  /// Point and tangent angle (degrees) at fraction [f] of the length.
  (double, double, double) at(double f) {
    final n = len.length;
    if (total <= 0) return (xy[0], xy[1], 0);
    final target = _clamp01(f) * total;
    var i = 1;
    while (i < n - 1 && len[i] < target) {
      i++;
    }
    final seg = len[i] - len[i - 1];
    final u = seg <= 0 ? 0.0 : (target - len[i - 1]) / seg;
    final x0 = xy[2 * i - 2], y0 = xy[2 * i - 1];
    final x1 = xy[2 * i], y1 = xy[2 * i + 1];
    return (
      x0 + (x1 - x0) * u,
      y0 + (y1 - y0) * u,
      math.atan2(y1 - y0, x1 - x0) * 180 / math.pi,
    );
  }
}

/// One compiled effect (the private side of [ScheduledEffect]).
final class _Eff {
  _Eff({
    required this.build,
    required this.elementId,
    required this.kind,
    required this.spec,
    required this.effectId,
    required this.params,
    required this.options,
    required this.el,
    required this.cycleMs,
    required this.easing,
    required this.seq,
    this.partNumber = 0,
    this.part,
    this.partsOfBuild = const [],
    this.repeat = 1,
    this.autoReverse = false,
    this.loops = false,
    this.role = EffectRole.build,
    this.dimTargets = const [],
    this.reduced,
    this.firstPart = true,
    this.lastPart = true,
    this.reveal,
    this.path,
    this.codeTarget,
    this.codeMode,
    this.seed = 0,
    this.backgroundWithParts = true,
  });

  final SlideBuildRec build;
  final String elementId;
  final SlideBuildKind kind;

  /// The effect played (null = unknown effect id kept for display).
  final EffectSpec? spec;
  final String effectId;
  final Map<String, Object?> params;
  final BuildOptions options;
  final MotionElement? el;
  final int cycleMs;
  final BoundEasing easing;
  final int seq;
  final int partNumber;
  final _PartRef? part;

  /// Every part of the build (preparing a part-based build hides them).
  final List<_PartRef> partsOfBuild;
  final int repeat;
  final bool autoReverse;
  final bool loops;
  final EffectRole role;
  final List<_PartRef> dimTargets;
  final ReducedMotionRule? reduced;
  final bool firstPart, lastPart;
  final _Reveal? reveal;
  final _PathTable? path;

  /// Code: 0-based target state / highlight step (−1 = clear).
  final int? codeTarget;
  final String? codeMode;
  final int seed;

  /// Part-based in builds: the box/background arrives with the first part.
  final bool backgroundWithParts;

  int get totalMs => loops ? cycleMs : cycleMs * repeat;

  bool get persistent =>
      kind == SlideBuildKind.buildIn ||
      kind == SlideBuildKind.buildOut ||
      _isPersistentEmphasis;

  bool get _isPersistentEmphasis {
    if (kind == SlideBuildKind.motion) return true;
    if (kind != SlideBuildKind.emphasis) return false;
    final override = options.persist;
    if (override != null) return override;
    if (spec?.id == 'chartOrbit') return params['persist'] == true;
    return spec?.persistence == EffectPersistence.persistent;
  }

  /// Whether the effect works on parts of the element.
  bool get partBased => part != null;
}

/// Logical visibility of an element during validation.
enum _Vis { visible, hidden }

final class _Compiler {
  _Compiler(this.input);

  final SlideMotionInput input;
  final List<TimelineWarning> warnings = [];
  int _seq = 0;
  bool _fullRange = true;

  CompileOptions get options => input.options;

  void _warn(String code, String message, SlideBuildRec b) =>
      warnings.add(TimelineWarning(code, message, buildId: b.id));

  SlideTimeline compile() {
    final builds = [...input.builds]
      ..sort((a, b) {
        final c = a.sortKey.compareTo(b.sortKey);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final elements = input.elements;

    // 1. Validity (06 §2.4): references, triggers, effects, visibility.
    final firstVis = <String, SlideBuildKind>{};
    final candidates = <SlideBuildRec>[];
    for (final b in builds) {
      final elId = b.elementId;
      if (elId == null) continue;
      if (elements != null && !elements.containsKey(elId)) {
        _warn('elementMissing', 'The animated object no longer exists', b);
        continue;
      }
      if (elements?[elId]?.hidden ?? false) {
        _warn('hiddenTarget', 'The object is hidden', b);
        continue;
      }
      if (b.trigger == SlideBuildTrigger.onElementClick) {
        _warn(
          'unsupportedTrigger',
          'Triggers on click of an object are not supported yet',
          b,
        );
        continue;
      }
      candidates.add(b);
      if (b.kind == SlideBuildKind.buildIn ||
          b.kind == SlideBuildKind.buildOut) {
        firstVis.putIfAbsent(elId, () => b.kind);
      }
    }
    final vis = <String, _Vis>{
      for (final e in firstVis.entries)
        e.key: e.value == SlideBuildKind.buildIn ? _Vis.hidden : _Vis.visible,
    };
    final valid = <SlideBuildRec>[];
    for (final b in candidates) {
      final id = b.elementId!;
      final v = vis[id] ?? _Vis.visible;
      switch (b.kind) {
        case SlideBuildKind.buildIn:
          if (v == _Vis.visible) {
            _warn('alreadyVisible', 'Element is already visible', b);
            continue;
          }
          vis[id] = _Vis.visible;
        case SlideBuildKind.buildOut:
          if (v == _Vis.hidden) {
            _warn('alreadyHidden', 'Element is already hidden', b);
            continue;
          }
          vis[id] = _Vis.hidden;
        case SlideBuildKind.emphasis || SlideBuildKind.motion:
          if (v == _Vis.hidden) {
            _warn('hiddenTarget', 'Element is hidden at this point', b);
            continue;
          }
      }
      valid.add(b);
    }

    // 2. Steps (06 §4.2).
    final autoBuilds =
        input.transition.advance.auto &&
        input.transition.advance.autoBuilds &&
        !options.ignoreAutoBuilds;
    final buildDelay = input.transition.advance.buildDelayMs;
    final steps = <List<(int, _Eff)>>[[]];
    int prevStart = 0, prevEnd = 0;
    var first = true;
    final codeCursor = <String, (int, int?)>{}; // element → (state, step)
    final initialPrep = <String, _Eff>{};
    final firstVisBuild = <String, String>{};
    for (final b in valid) {
      if (b.kind == SlideBuildKind.buildIn ||
          b.kind == SlideBuildKind.buildOut) {
        firstVisBuild.putIfAbsent(b.elementId!, () => b.id);
      }
    }

    for (final b in valid) {
      final effs = _expand(b, codeCursor);
      if (effs.isEmpty) continue;
      var trigger = b.trigger;
      var delay = b.delayMs;
      if (autoBuilds && trigger == SlideBuildTrigger.onClick) {
        trigger = SlideBuildTrigger.afterPrevious;
        delay += buildDelay;
      }
      int start;
      if (trigger == SlideBuildTrigger.onClick) {
        steps.add([]);
        start = delay;
      } else if (first || steps.last.isEmpty) {
        start = delay;
      } else if (trigger == SlideBuildTrigger.withPrevious) {
        start = prevStart + delay;
      } else {
        start = prevEnd + delay;
      }
      first = false;

      // Parts: the first follows the build's trigger; the rest per
      // partTrigger (onClick parts open new steps).
      final kind = b.kind;
      var partTrigger = effs.first.options.delivery.effectivePartTrigger(kind);
      var stagger = effs.first.options.delivery.effectiveStaggerMs(
        kind,
        effs.first.cycleMs,
      );
      if (autoBuilds && partTrigger == SlideBuildTrigger.onClick) {
        partTrigger = SlideBuildTrigger.afterPrevious;
        stagger = buildDelay;
      }
      var partStart = start;
      var partEnd = start;
      var lastStepStart = start;
      var buildEnd = start;
      final builds = effs.where((e) => e.role == EffectRole.build).toList();
      for (final (k, e) in builds.indexed) {
        if (k > 0) {
          if (partTrigger == SlideBuildTrigger.onClick) {
            steps.add([]);
            partStart = 0;
            lastStepStart = 0;
            buildEnd = 0;
          } else if (partTrigger == SlideBuildTrigger.withPrevious) {
            partStart = partStart + stagger;
          } else {
            partStart = partEnd + stagger;
          }
        }
        steps.last.add((partStart, e));
        partEnd = partStart + e.totalMs;
        buildEnd = math.max(buildEnd, partEnd);
        // After-build dimming of the earlier parts (06 §2.3): part of the
        // next part's step, 300 ms from its start.
        if (k > 0 && e.options.afterBuild.mode != AfterBuildMode.none) {
          final d = _dimEffect(e, [for (final p in builds.take(k)) p.part!]);
          steps.last.add((partStart, d));
          buildEnd = math.max(buildEnd, partStart + d.totalMs);
        }
      }
      if (b.id == firstVisBuild[b.elementId] &&
          b.kind == SlideBuildKind.buildIn &&
          (builds.first.partBased || builds.first.spec?.id == 'codeType')) {
        initialPrep[b.elementId!] = builds.first;
      }
      // The next build's "previous": this build's start and end in the
      // step it ends in.
      prevStart = lastStepStart;
      prevEnd = buildEnd;
    }

    // 3. Scheduled effects and step durations.
    final timelineSteps = <TimelineStep>[];
    final scheduled = <List<(int, _Eff)>>[];
    for (final (i, s) in steps.indexed) {
      final sorted = [...s]
        ..sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.seq.compareTo(b.$2.seq);
        });
      scheduled.add(sorted);
      var dur = 0;
      for (final (st, e) in sorted) {
        dur = math.max(dur, st + e.totalMs);
      }
      timelineSteps.add(
        TimelineStep(
          index: i,
          durationMs: dur,
          effects: [for (final (st, e) in sorted) ScheduledEffect._(e, st)],
        ),
      );
    }

    final program = _Program(
      input: input,
      steps: scheduled,
      firstVisibility: firstVis,
      initialPrep: initialPrep,
      codeElements: {
        for (final b in valid)
          if (input.elements?[b.elementId]?.kind == ElementKind.code)
            b.elementId!,
      },
    );
    return _CompiledTimeline(
      slideId: input.slide.id,
      steps: timelineSteps,
      warnings: List.unmodifiable(warnings),
      program: program,
    );
  }

  _Eff _dimEffect(_Eff part, List<_PartRef> targets) => _Eff(
    build: part.build,
    elementId: part.elementId,
    kind: part.kind,
    spec: part.spec,
    effectId: 'dim',
    params: const {},
    options: part.options,
    el: part.el,
    cycleMs: options.reducedMotion ? 0 : 300,
    easing: MotionEasing.parse(
      'easeInOut',
    ).bind(options.reducedMotion ? 0 : 300),
    seq: _seq++,
    partNumber: part.partNumber,
    role: EffectRole.dim,
    dimTargets: targets,
  );

  /// The effects of build [b]: one per part (or one for the whole
  /// element). Empty when the build is skipped.
  List<_Eff> _expand(SlideBuildRec b, Map<String, (int, int?)> codeCursor) {
    final el = input.elements?[b.elementId];
    var kind = b.kind;

    // Options.
    var spec = EffectCatalog.byId(kind, b.effect);
    final decoded = BuildOptions.decode(
      b.optionsJson,
      kind: kind,
      effect: spec == null ? null : b.effect,
    );
    if (!decoded.isValid) {
      _warn(
        'invalidOptions',
        'Invalid animation options: ${decoded.errors.first}',
        b,
      );
    }
    var opts = decoded.value;

    // Effect fallbacks (06 §2.1, §5.2).
    var effectId = b.effect;
    if (spec == null || !spec.available) {
      final fb = EffectCatalog.fallback(kind);
      if (fb == null) {
        _warn('unsupportedEffect', 'Effect not supported by this version', b);
        return const [];
      }
      _warn('unsupportedEffect', 'Effect not supported by this version', b);
      spec = fb;
      effectId = fb.id;
    }
    if (el != null && !spec.target.accepts(el.kind)) {
      final fb = EffectCatalog.fallback(kind);
      if (fb == null) {
        _warn(
          'wrongElementKind',
          '${spec.name} doesn\'t work on this object',
          b,
        );
        return const [];
      }
      _warn('wrongElementKind', '${spec.name} doesn\'t work on this object', b);
      spec = fb;
      effectId = fb.id;
    }

    // Easing and duration.
    var easingExpr = MotionEasing.tryParse(b.easing);
    if (easingExpr == null) {
      if (b.easing.isNotEmpty) {
        _warn('invalidEasing', 'Unknown easing "${b.easing}"', b);
      }
      easingExpr =
          MotionEasing.tryParse(spec.defaultEasing) ?? MotionEasing.linear;
    }
    var durationMs = b.durationMs.clamp(0, 20000);
    var params = <String, Object?>{...spec.defaults, ...opts.params};
    ReducedMotionRule? reduced;

    // Reduced motion (06 §13).
    if (options.reducedMotion) {
      final rule = spec.reducedMotion;
      if (opts.delivery.by == DeliveryBy.word ||
          opts.delivery.by == DeliveryBy.character) {
        opts = _withDelivery(opts, opts.delivery.withBy(DeliveryBy.paragraph));
      }
      switch (rule) {
        case ReducedMotionRule.same:
          break;
        case ReducedMotionRule.fade:
          if (kind == SlideBuildKind.buildIn ||
              kind == SlideBuildKind.buildOut) {
            spec = EffectCatalog.fallback(kind)!;
            effectId = spec.id;
            params = {};
            durationMs = math.min(durationMs, 300);
            easingExpr = MotionEasing.parse('easeOut');
            reduced = rule;
          }
        case ReducedMotionRule.partsFade:
          reduced = rule;
          if (spec.id == 'codeState') {
            durationMs = 300;
            easingExpr = MotionEasing.linear;
          } else {
            final fb = EffectCatalog.fallback(kind)!;
            spec = fb;
            effectId = fb.id;
            params = {};
            durationMs = 200;
            easingExpr = MotionEasing.linear;
            if (el?.kind.hasText ?? false) {
              final d = opts.delivery;
              opts = _withDelivery(
                opts,
                BuildDelivery(
                  by: d.by.isText ? d.by : DeliveryBy.paragraph,
                  order: d.order,
                  from: d.from,
                  to: d.to,
                  partTrigger: d.by.isText
                      ? d.partTrigger
                      : SlideBuildTrigger.afterPrevious,
                  staggerMs: d.by.isText ? d.staggerMs : 0,
                ),
              );
            }
          }
        case ReducedMotionRule.skip:
          return const [];
        case ReducedMotionRule.instant:
          reduced = rule;
          durationMs = 200;
          easingExpr = MotionEasing.jump;
        case ReducedMotionRule.fadeOutIn:
          reduced = rule;
          durationMs = 400;
          easingExpr = MotionEasing.linear;
      }
    }

    var bound = easingExpr.bind(durationMs);
    if (spec.id == 'appear' || spec.id == 'disappear') {
      bound = BoundEasing(MotionEasing.linear, 0);
    }

    // Blink: at most 3 flashes per second (06 §17).
    if (spec.id == 'blink') {
      final maxCount = math.max(1, (3 * bound.durationMs / 1000).floor());
      final count = (params['count'] as num? ?? 2).round();
      if (count > maxCount) {
        params['count'] = maxCount;
        _warn('flashLimit', 'Blink limited to 3 flashes per second', b);
      }
    }

    // Repeat (transient emphasis).
    final transient =
        kind == SlideBuildKind.emphasis &&
        !(opts.persist ?? (spec.persistence == EffectPersistence.persistent));
    final repeat = transient ? opts.repeat : BuildRepeat.once;

    // Code effects.
    int? codeTarget;
    String? codeMode;
    if (el != null && el.kind == ElementKind.code) {
      final cur = codeCursor[el.id] ?? (0, null);
      switch (spec.id) {
        case 'codeType':
          codeCursor[el.id] = (0, null);
          final len = el.codeStates.isEmpty ? 0 : el.codeStates.first.length;
          if (reduced == null) {
            bound = BoundEasing(
              MotionEasing.linear,
              el.codeTimings?.typeInMs() ?? _typeMs(len),
            );
          }
        case 'codeHighlight':
          final step = (params['step'] as num? ?? 1).round();
          final states = el.codeStates;
          final steps = cur.$1 < states.length
              ? states[cur.$1].highlightSteps
              : 0;
          if (step > steps) {
            _warn(
              'codeStepMissing',
              'Step $step doesn\'t exist in state ${cur.$1 + 1}',
              b,
            );
            return const [];
          }
          codeTarget = step - 1;
          codeCursor[el.id] = (cur.$1, step == 0 ? null : step - 1);
        case 'codeState':
          final states = el.codeStates;
          final target = params['state'] is num
              ? (params['state'] as num).round() - 1
              : cur.$1 + 1;
          if (target < 0 || target >= states.length) {
            _warn('codeStateMissing', 'State ${target + 1} doesn\'t exist', b);
            return const [];
          }
          codeTarget = target;
          final mode = params['mode'] as String?;
          codeMode =
              mode ??
              (target < cur.$1 ? 'instant' : (states[target].mode ?? 'type'));
          if (reduced != null) codeMode = 'crossfade';
          codeCursor[el.id] = (target, null);
          if (reduced == null) {
            // Derived from the element's typing script / morph settings
            // (07 §5.3, §5.6; SL-31); estimates without a model.
            final derived = el.codeTimings?.transitionMs(
              cur.$1,
              target,
              codeMode,
            );
            final delta = (states[target].length - states[cur.$1].length).abs();
            bound = switch (codeMode) {
              'type' => BoundEasing(
                MotionEasing.linear,
                derived ?? _typeMs(delta + 10),
              ),
              'instant' => BoundEasing(MotionEasing.linear, derived ?? 0),
              _ => easingExpr.bind(
                derived ?? (durationMs > 0 ? durationMs : 800),
              ),
            };
          }
      }
    }

    // Motion path.
    _PathTable? path;
    if (spec.id == 'path') {
      path = _PathTable.parse(params['path'] as String? ?? 'M0 0');
    }

    // Parts (06 §2.3).
    final parts = _parts(b, opts, spec, el, kind);
    final fullRange = _fullRange;
    final seed = partSeed(b.id, 0);
    final base = _Eff(
      build: b,
      elementId: b.elementId!,
      kind: kind,
      spec: spec,
      effectId: effectId,
      params: params,
      options: opts,
      el: el,
      cycleMs: bound.durationMs,
      easing: bound,
      seq: 0,
      reduced: reduced,
      path: path,
      codeTarget: codeTarget,
      codeMode: codeMode,
      seed: seed,
    );
    if (parts == null) {
      return [_copy(base, seq: _seq++, repeat: repeat)];
    }
    final out = <_Eff>[];
    for (final (k, (number, ref)) in parts.indexed) {
      var cycle = bound.durationMs;
      _Reveal? reveal;
      if (spec.id == 'typewriter' || spec.id == 'eraseText') {
        reveal = _reveal(
          el!,
          ref as _TextPartRef,
          params,
          partSeed(b.id, number),
        );
        cycle = (reveal.totalMs - 1e-6).ceil();
      }
      out.add(
        _copy(
          base,
          seq: _seq++,
          repeat: repeat,
          partNumber: number,
          part: ref,
          partsOfBuild: [for (final (_, r) in parts) r],
          firstPart: k == 0,
          lastPart: k == parts.length - 1,
          cycleMs: cycle,
          reveal: reveal,
          seed: partSeed(b.id, number),
          easing: reveal != null
              ? BoundEasing(MotionEasing.linear, cycle)
              : bound,
          backgroundWithParts:
              fullRange &&
              (ref is _TextPartRef || opts.delivery.includeBackground),
        ),
      );
    }
    return out;
  }

  static int _typeMs(int chars) =>
      (chars / 28 * 1000).round().clamp(300, 20000);

  BuildOptions _withDelivery(BuildOptions o, BuildDelivery d) => BuildOptions(
    params: o.params,
    delivery: d,
    afterBuild: o.afterBuild,
    repeat: o.repeat,
    persist: o.persist,
    extra: o.extra,
  );

  _Eff _copy(
    _Eff e, {
    required int seq,
    BuildRepeat repeat = BuildRepeat.once,
    int partNumber = 0,
    _PartRef? part,
    List<_PartRef> partsOfBuild = const [],
    bool firstPart = true,
    bool lastPart = true,
    int? cycleMs,
    _Reveal? reveal,
    int? seed,
    BoundEasing? easing,
    bool backgroundWithParts = true,
  }) => _Eff(
    build: e.build,
    elementId: e.elementId,
    kind: e.kind,
    spec: e.spec,
    effectId: e.effectId,
    params: e.params,
    options: e.options,
    el: e.el,
    cycleMs: cycleMs ?? e.cycleMs,
    easing: easing ?? e.easing,
    seq: seq,
    partNumber: partNumber,
    part: part,
    partsOfBuild: partsOfBuild,
    repeat: repeat.untilNextClick ? 1 : repeat.count,
    autoReverse: repeat.autoReverse,
    loops: repeat.untilNextClick,
    reduced: e.reduced,
    firstPart: firstPart,
    lastPart: lastPart,
    reveal: reveal,
    path: e.path,
    codeTarget: e.codeTarget,
    codeMode: e.codeMode,
    seed: seed ?? e.seed,
    backgroundWithParts: backgroundWithParts,
  );

  /// The parts of [b] in build order as (1-based natural number, ref), or
  /// null when the build animates the whole element.
  List<(int, _PartRef)>? _parts(
    SlideBuildRec b,
    BuildOptions opts,
    EffectSpec spec,
    MotionElement? el,
    SlideBuildKind kind,
  ) {
    final d = opts.delivery;
    final typewriter = spec.id == 'typewriter' || spec.id == 'eraseText';
    final chartWhole = spec.id == 'chartGrow' || spec.id == 'chartShrink';
    if (el == null) return null;
    List<_PartRef>? all;
    if (d.by.isText || typewriter) {
      final text = el.text;
      if (text == null) {
        if (d.by != DeliveryBy.all) {
          _warn(
            'deliveryFallback',
            'This object has no text to build in parts',
            b,
          );
        }
        return null;
      }
      var by = d.by;
      if (by == DeliveryBy.character &&
          TextParts.characters(text.plain).length > 2000) {
        _warn(
          'deliveryFallback',
          'More than 2,000 characters: built by word',
          b,
        );
        by = DeliveryBy.word;
      }
      if (kind == SlideBuildKind.emphasis &&
          spec.id != 'highlight' &&
          spec.persistence == EffectPersistence.persistent) {
        return null;
      }
      if (kind == SlideBuildKind.motion) return null;
      final ranges = by == DeliveryBy.all
          ? [TextPartRange(0, _trimEnd(text.plain), 0)]
          : TextParts.of(text, by);
      if (ranges.isEmpty) return null;
      all = [for (final r in ranges) _TextPartRef(r.start, r.end)];
    } else if (d.by.isChart || (chartWhole && el.kind == ElementKind.chart)) {
      if (el.kind != ElementKind.chart) {
        _warn('deliveryFallback', 'Chart delivery on a non-chart object', b);
        return null;
      }
      if (kind == SlideBuildKind.emphasis || kind == SlideBuildKind.motion) {
        return null;
      }
      var by = d.by;
      final shape = el.chart;
      List<ChartPartKey>? keys;
      if (by.isChart) {
        if (shape == null) {
          _warn(
            'deliveryFallback',
            'Chart data unavailable: built as a whole',
            b,
          );
        } else {
          if (by == DeliveryBy.point &&
              shape.seriesKeys.length * shape.categoryCount > 500) {
            _warn(
              'deliveryFallback',
              'More than 500 points: built by series',
              b,
            );
            by = DeliveryBy.series;
          }
          keys = shape.partsOf(by);
        }
      }
      keys ??= const [ChartPartKey('all')];
      if (keys.isEmpty) keys = const [ChartPartKey('all')];
      all = [for (final k in keys) _ChartPartRef(k)];
    } else if (d.by != DeliveryBy.all) {
      _warn('deliveryFallback', 'This object can\'t be built in parts', b);
      return null;
    }
    if (all == null) return null;
    // Range (1-based inclusive) and order.
    final from = (d.from - 1).clamp(0, all.length);
    final to = (d.to ?? all.length).clamp(from, all.length);
    final selected = [for (var i = from; i < to; i++) (i + 1, all[i])];
    _fullRange = selected.length == all.length;
    if (selected.isEmpty) return null;
    final order = PartOrdering.order(
      selected.length,
      d.order,
      partSeed(b.id, 0, 'order'),
    );
    return [for (final i in order) selected[i]];
  }

  static int _trimEnd(String s) {
    var e = s.length;
    while (e > 0 &&
        (s.codeUnitAt(e - 1) == 0x0A || s.codeUnitAt(e - 1) == 0x20)) {
      e--;
    }
    return e;
  }

  /// The typewriter reveal of [r]: one visible character every `1000/cps`
  /// ms, jittered by `jitter` with a generator seeded per part.
  _Reveal _reveal(
    MotionElement el,
    _TextPartRef r,
    Map<String, Object?> params,
    int seed,
  ) {
    final text = el.text!.plain;
    final cps = _num(params, 'cps', 30).clamp(1, 200);
    final jitter = _num(params, 'jitter', 0).clamp(0, 1);
    final base = 1000 / cps;
    final rnd = SeededRandom(seed);
    final offsets = <int>[];
    final times = <double>[];
    var t = 0.0;
    for (final c in TextParts.characters(text.substring(r.start, r.end))) {
      final u = jitter == 0 ? 0.5 : rnd.nextDouble();
      t += math.max(15, base * (1 + jitter * (2 * u - 1)));
      times.add(t);
      offsets.add(r.start + c.end);
    }
    return _Reveal(r.start, offsets, times, t);
  }
}
