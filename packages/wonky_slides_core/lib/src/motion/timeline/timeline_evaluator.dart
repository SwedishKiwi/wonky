part of 'slide_timeline.dart';

// Frame evaluation (06 §9.3): `initial` applies the initial visibility,
// `endOfStep(i)` settles every effect of steps 0…i on top of it, and
// `frameAt` evaluates the running effects of a step on top of the end of
// the previous one. Persistent results (visibility, motion, persistent
// emphasis, dimming) accumulate per element in `_Acc`; running effects
// write a `_Live` overlay that is merged into the frame.

/// The persistent geometry of an element: center, size and rotation (su,
/// degrees). Motion paths, `moveTo`, `spin` and `grow` change it.
final class _Geom {
  const _Geom(this.cx, this.cy, this.w, this.h, this.rot);

  factory _Geom.of(MotionElement? el) {
    if (el == null) return const _Geom(0, 0, 0, 0, 0);
    final f = el.frame;
    return _Geom(
      f.x + f.width / 2,
      f.y + f.height / 2,
      f.width,
      f.height,
      el.rotation,
    );
  }

  final double cx, cy, w, h, rot;

  /// The point at fraction ([ax], [ay]) of the (rotated) box.
  (double, double) anchor(double ax, double ay) {
    final r = rot * math.pi / 180;
    final lx = (ax - 0.5) * w, ly = (ay - 0.5) * h;
    return (
      cx + lx * math.cos(r) - ly * math.sin(r),
      cy + lx * math.sin(r) + ly * math.cos(r),
    );
  }

  _Geom rotateAbout(double angle, double ax, double ay) {
    final (px, py) = anchor(ax, ay);
    final r = angle * math.pi / 180;
    final dx = cx - px, dy = cy - py;
    return _Geom(
      px + dx * math.cos(r) - dy * math.sin(r),
      py + dx * math.sin(r) + dy * math.cos(r),
      w,
      h,
      rot + angle,
    );
  }

  _Geom scaleAbout(double s, double ax, double ay) {
    final (px, py) = anchor(ax, ay);
    return _Geom(px + s * (cx - px), py + s * (cy - py), w * s, h * s, rot);
  }

  _Geom translate(double dx, double dy) => _Geom(cx + dx, cy + dy, w, h, rot);

  _Geom lerp(_Geom to, double t) => _Geom(
    cx + (to.cx - cx) * t,
    cy + (to.cy - cy) * t,
    w + (to.w - w) * t,
    h + (to.h - h) * t,
    rot + (to.rot - rot) * t,
  );

  bool same(_Geom o) =>
      cx == o.cx && cy == o.cy && w == o.w && h == o.h && rot == o.rot;

  /// The slide-space matrix mapping the box of [g0] onto this box.
  Matrix4 from(_Geom g0) {
    final m = Matrix4.identity()..translateByDouble(cx, cy, 0, 1);
    if (rot != 0) m.rotateZ(rot * math.pi / 180);
    final sx = g0.w == 0 ? 1.0 : w / g0.w, sy = g0.h == 0 ? 1.0 : h / g0.h;
    if (sx != 1 || sy != 1) m.scaleByDouble(sx, sy, 1, 1);
    if (g0.rot != 0) m.rotateZ(-g0.rot * math.pi / 180);
    m.translateByDouble(-g0.cx, -g0.cy, 0, 1);
    return m;
  }
}

/// Persistent state of one text part.
final class _PartAcc {
  _PartAcc(this.start, this.end, {this.visible = true});
  final int start, end;
  bool visible;
  double dim = 1;
  int? dimColor;

  _PartAcc clone() => _PartAcc(start, end, visible: visible)
    ..dim = dim
    ..dimColor = dimColor;
}

/// Persistent state of one chart part.
final class _ChartPartAcc {
  _ChartPartAcc({this.visible = true});
  bool visible;
  double dim = 1;
  _ChartPartAcc clone() => _ChartPartAcc(visible: visible)..dim = dim;
}

/// Persistent state of one element.
final class _Acc {
  _Acc(this.el, this.geom0) : geom = geom0;

  final MotionElement? el;
  final _Geom geom0;
  bool visible = true;
  double opacity = 1;
  _Geom geom;
  final Map<String, ColorOverride> colors = {};
  final List<TextHighlightState> highlights = [];
  final Map<String, _PartAcc> textParts = {};
  bool textBackground = true;
  bool chartBackground = true;
  final Map<ChartPartKey, _ChartPartAcc> chartParts = {};
  Map<String, Object?>? chartHighlight;
  double azimuth = 0, elevation = 0;
  Map<String, Object?>? camera;
  CodeViewState? code;
  String? prepared;

  _Acc clone() {
    final c = _Acc(el, geom0)
      ..visible = visible
      ..opacity = opacity
      ..geom = geom
      ..textBackground = textBackground
      ..chartBackground = chartBackground
      ..chartHighlight = chartHighlight
      ..azimuth = azimuth
      ..elevation = elevation
      ..camera = camera
      ..code = code
      ..prepared = prepared;
    c.colors.addAll(colors);
    c.highlights.addAll(highlights);
    for (final e in textParts.entries) {
      c.textParts[e.key] = e.value.clone();
    }
    for (final e in chartParts.entries) {
      c.chartParts[e.key] = e.value.clone();
    }
    return c;
  }

  /// Hides the parts of a part-based build about to start (06 §9.3):
  /// the element is drawn, its built parts are not.
  void prepare(_Eff e) {
    if (prepared == e.build.id) return;
    prepared = e.build.id;
    visible = true;
    for (final p in e.partsOfBuild) {
      switch (p) {
        case _TextPartRef(:final start, :final end):
          textParts[p.key] = _PartAcc(start, end, visible: false);
        case _ChartPartRef(:final key):
          chartParts[key] = _ChartPartAcc(visible: false);
      }
    }
    if (e.backgroundWithParts) {
      if (e.part is _TextPartRef) textBackground = false;
      if (e.part is _ChartPartRef) chartBackground = false;
    }
    if (e.spec?.id == 'codeType') {
      code = const CodeViewState(
        stateIndex: 0,
        fromStateIndex: -1,
        mix: 0,
        mode: 'type',
        typing: 0,
      );
    }
  }

  void resetParts() {
    textParts.clear();
    chartParts.clear();
    textBackground = true;
    chartBackground = true;
    prepared = null;
  }
}

/// Live part overlay.
final class _PartLive {
  bool visible = true;
  double opacity = 1;
  Matrix4? matrix;
  ClipSpec? clip;
  double blur = 0;
  int? revealEnd;
  bool caret = false;
  double? dim;
}

/// Live element overlay of the running effects.
final class _Live {
  bool forceVisible = false;
  double opacity = 1;
  double? opacityAbs;
  double dx = 0, dy = 0;
  Matrix4? chan;
  _Geom? geom;
  ClipSpec? clip;
  double blur = 0;
  DissolveState? dissolve;
  double? draw;
  bool drawReverse = false;
  double? fill;
  final Map<String, ColorOverride> colors = {};
  final List<TextHighlightState> highlights = [];
  final Map<String, _PartLive> parts = {};
  double? textBackground;
  final Map<ChartPartKey, (double, double)> chartParts = {};
  double? chartBackground;
  Map<String, Object?>? chartHighlight;
  double? chartHighlightMix;
  double azimuth = 0, elevation = 0;
  Map<String, Object?>? camera;
  Map<String, Object?>? fromCamera;
  double? cameraMix;
  CodeViewState? code;

  _PartLive part(_TextPartRef r) => parts[r.key] ??= _PartLive();
}

/// The evaluator of a compiled timeline.
final class _Program {
  _Program({
    required this.input,
    required this.steps,
    required this.firstVisibility,
    required this.initialPrep,
    required this.codeElements,
  });

  final SlideMotionInput input;

  /// Effects per step with their start (sorted).
  final List<List<(int, _Eff)>> steps;
  final Map<String, SlideBuildKind> firstVisibility;
  final Map<String, _Eff> initialPrep;
  final Set<String> codeElements;

  late final Map<String, _Acc> _initial = _makeInitial();
  final Map<int, Map<String, _Acc>> _after = {};
  final Map<int, SlideFrame> _frames = {};
  late final SlideFrame initialFrame = _frame(_initial, const {});

  Map<String, _Acc> _makeInitial() {
    final accs = <String, _Acc>{};
    _Acc acc(String id) {
      final el = input.elements?[id];
      return accs[id] ??= _Acc(el, _Geom.of(el));
    }

    for (final s in steps) {
      for (final (_, e) in s) {
        acc(e.elementId);
      }
    }
    for (final e in firstVisibility.entries) {
      if (e.value == SlideBuildKind.buildIn && accs.containsKey(e.key)) {
        accs[e.key]!.visible = false;
      }
    }
    for (final e in initialPrep.entries) {
      accs[e.key]?.prepare(e.value);
    }
    for (final id in codeElements) {
      final a = accs[id];
      if (a != null && a.code == null) {
        a.code = const CodeViewState(stateIndex: 0);
      }
    }
    return accs;
  }

  static Map<String, _Acc> _clone(Map<String, _Acc> m) => {
    for (final e in m.entries) e.key: e.value.clone(),
  };

  /// Accumulators after every effect of steps 0…[step] settled.
  Map<String, _Acc> accAfter(int step) {
    if (step < 0) return _initial;
    final hit = _after[step];
    if (hit != null) return hit;
    final accs = _clone(accAfter(step - 1));
    for (final (_, e) in steps[step]) {
      final a = accs[e.elementId];
      if (a != null) _settle(e, a);
    }
    return _after[step] = accs;
  }

  /// The settled frame after [step].
  SlideFrame endOfStep(int step) {
    if (step < 0) return initialFrame;
    final s = math.min(step, steps.length - 1);
    return _frames[s] ??= _frame(accAfter(s), const {});
  }

  /// The frame at [ms] into [step].
  SlideFrame frameAt(int step, int ms) {
    if (step < 0) return initialFrame;
    if (step >= steps.length) return endOfStep(steps.length - 1);
    final effects = steps[step];
    final settledAll = effects.every(
      (x) => !x.$2.loops && ms >= x.$1 + x.$2.totalMs,
    );
    if (settledAll) return endOfStep(step);
    final accs = _clone(accAfter(step - 1));
    final live = <String, _Live>{};
    for (final (start, e) in effects) {
      final a = accs[e.elementId];
      if (a == null) continue;
      final local = ms - start;
      if (local < 0) continue;
      if (!e.loops && local >= e.totalMs) {
        _settle(e, a);
      } else {
        _run(e, a, live[e.elementId] ??= _Live(), local);
      }
    }
    return _frame(accs, live);
  }

  /// The print frame (06 §9.6): code elements at their last state without
  /// highlight; everything else authored (charts and text complete).
  late final SlideFrame printFrame = SlideFrame({
    for (final id in codeElements)
      if ((input.elements?[id]?.codeStates.length ?? 0) > 0)
        id: ElementVisualState(
          code: CodeViewState(
            stateIndex: input.elements![id]!.codeStates.length - 1,
          ),
        ),
  });

  // ---------------------------------------------------------------------
  // Settling

  _Ctx _ctx(_Eff e, SuRect box) => _Ctx(
    e.params,
    box,
    e.el?.frame ?? const SuRect(0, 0, 0, 0),
    input.slideWidth,
    input.slideHeight,
  );

  int? _color(Object? ref) {
    if (ref is! String) return null;
    final r = input.resolveColor?.call(ref);
    if (r != null) return r;
    if (ref.startsWith('#')) {
      final hex = ref.substring(1);
      final v = int.tryParse(hex, radix: 16);
      if (v == null) return null;
      if (hex.length == 6) return 0xFF000000 | v;
      if (hex.length == 8) return ((v & 0xFF) << 24) | (v >> 8);
    }
    return null;
  }

  void _settle(_Eff e, _Acc a) {
    if (e.role == EffectRole.dim) {
      final mode = e.options.afterBuild.mode;
      final dimColor = _color(e.options.afterBuild.dimColor);
      for (final t in e.dimTargets) {
        switch (t) {
          case _TextPartRef():
            final p = a.textParts[t.key] ??= _PartAcc(t.start, t.end);
            if (mode == AfterBuildMode.hide) {
              p.visible = false;
            } else {
              p.dim = e.options.afterBuild.dimOpacity;
              p.dimColor = dimColor;
            }
          case _ChartPartRef(:final key):
            final p = a.chartParts[key] ??= _ChartPartAcc();
            if (mode == AfterBuildMode.hide) {
              p.visible = false;
            } else {
              p.dim = e.options.afterBuild.dimOpacity;
            }
        }
      }
      return;
    }
    final id = e.spec?.id ?? e.effectId;
    switch (e.kind) {
      case SlideBuildKind.buildIn:
        if (e.partBased) {
          a.prepare(e);
          _showPart(a, e.part!, true);
          if (e.firstPart) {
            a.textBackground = true;
            a.chartBackground = true;
          }
          if (e.lastPart) _dropDefaultParts(a);
        } else {
          a.visible = true;
          if (id == 'codeType') a.code = const CodeViewState(stateIndex: 0);
        }
      case SlideBuildKind.buildOut:
        if (e.partBased) {
          _showPart(a, e.part!, false);
          if (e.lastPart) {
            a.visible = false;
            a.resetParts();
          }
        } else {
          a.visible = false;
          a.resetParts();
        }
      case SlideBuildKind.emphasis || SlideBuildKind.motion:
        if (!e.persistent) {
          return;
        }
        _applyPersistent(e, a, 1, a);
    }
  }

  void _showPart(_Acc a, _PartRef p, bool visible) {
    switch (p) {
      case _TextPartRef():
        (a.textParts[p.key] ??= _PartAcc(p.start, p.end)).visible = visible;
      case _ChartPartRef(:final key):
        (a.chartParts[key] ??= _ChartPartAcc()).visible = visible;
    }
  }

  /// Drops part states that are back to the default (fully built, not
  /// dimmed).
  void _dropDefaultParts(_Acc a) {
    a.textParts.removeWhere(
      (_, p) => p.visible && p.dim == 1 && p.dimColor == null,
    );
    a.chartParts.removeWhere((_, p) => p.visible && p.dim == 1);
    a.prepared = null;
  }

  /// The geometry/state of persistent effect [e] at eased progress [t],
  /// written into [out] (the accumulator when settling; a live overlay
  /// adapter when running).
  void _applyPersistent(_Eff e, _Acc a, double t, Object out) {
    final p = e.params;
    final id = e.spec?.id ?? e.effectId;
    final live = out is _Live ? out : null;
    void setGeom(_Geom g) {
      if (live != null) {
        live.geom = g;
      } else {
        a.geom = g;
      }
    }

    switch (id) {
      case 'spin':
        final (ax, ay) = _anchor(p['origin']);
        setGeom(a.geom.rotateAbout(_num(p, 'angle', 360) * t, ax, ay));
      case 'grow':
        final (ax, ay) = _anchor(p['origin']);
        setGeom(a.geom.scaleAbout(1 + (_num(p, 'scale', 1.2) - 1) * t, ax, ay));
      case 'moveTo':
        final target = _moveTarget(a.geom, p);
        setGeom(a.geom.lerp(target, t));
        final to = p['to'];
        if (to is Map && to['opacity'] is num) {
          final el = a.el;
          final authored = el == null || el.opacity <= 0 ? 1.0 : el.opacity;
          final goal = _clamp01((to['opacity'] as num).toDouble()) / authored;
          final v = a.opacity + (goal - a.opacity) * t;
          if (live != null) {
            live.opacityAbs = v;
          } else {
            a.opacity = v;
          }
        }
      case 'path':
        final path = e.path!;
        // Path data is relative to the element's center at the start of
        // the build (06 §3.4).
        final (_, _, ang0) = path.at(0);
        final (x, y, ang) = path.at(t);
        var g = a.geom.translate(x, y);
        if (p['orientToPath'] == true) {
          g = _Geom(g.cx, g.cy, g.w, g.h, g.rot + (ang - ang0));
        }
        setGeom(g);
      case 'opacityTo':
        final el = a.el;
        final authored = el == null || el.opacity <= 0 ? 1.0 : el.opacity;
        final goal = _clamp01(_num(p, 'opacity', 0.4)) / authored;
        final v = a.opacity + (goal - a.opacity) * t;
        if (live != null) {
          live.opacityAbs = v;
        } else {
          a.opacity = v;
        }
      case 'colorChange':
        final prop = p['property'] as String? ?? 'fill';
        final to = _color(p['to']);
        if (to == null) return;
        if (live != null) {
          live.colors[prop] = ColorOverride(
            from: a.colors[prop]?.to,
            to: to,
            mix: t,
          );
        } else {
          a.colors[prop] = ColorOverride(to: to);
        }
      case 'highlight':
        final color = _color(p['color']) ?? 0x66FFD54F;
        final style = p['style'] as String? ?? 'marker';
        final ranges = e.part is _TextPartRef
            ? [e.part! as _TextPartRef]
            : [_TextPartRef(0, _Compiler._trimEnd(a.el?.text?.plain ?? ''))];
        for (final r in ranges) {
          final h = TextHighlightState(
            start: r.start,
            end: r.end,
            color: color,
            style: style,
            progress: t,
          );
          if (live != null) {
            live.highlights.add(h);
          } else {
            a.highlights.add(h);
          }
        }
      case 'chartHighlight':
        final target = {
          'target': p['target'],
          'dimOthers': _num(p, 'dimOthers', 0.3),
        };
        if (live != null) {
          live.chartHighlight = target;
          live.chartHighlightMix = t;
        } else {
          a.chartHighlight = target;
        }
      case 'chartHighlightClear':
        if (live != null) {
          live.chartHighlight = a.chartHighlight;
          live.chartHighlightMix = 1 - t;
        } else {
          a.chartHighlight = null;
        }
      case 'chartOrbit':
        final az = _num(p, 'azimuth', 360) * t;
        final el = _num(p, 'elevation', 0) * t;
        if (live != null) {
          live.azimuth = az;
          live.elevation = el;
        } else {
          a.azimuth += az;
          a.elevation += el;
        }
      case 'chartCamera':
        final cam = <String, Object?>{
          'azimuth': p['azimuth'],
          'elevation': p['elevation'],
          'perspective': p['perspective'],
          'preset': ?p['preset'],
        };
        if (live != null) {
          live.camera = cam;
          live.fromCamera = a.camera;
          live.cameraMix = t;
        } else {
          a.camera = cam;
        }
      case 'codeHighlight':
        final cur = a.code ?? const CodeViewState(stateIndex: 0);
        final step = (e.codeTarget ?? -1) < 0 ? null : e.codeTarget;
        final v = CodeViewState(
          stateIndex: cur.stateIndex,
          highlightStep: step,
          fromHighlightStep: live == null ? null : cur.highlightStep,
          highlightMix: live == null ? 1 : t,
        );
        if (live != null) {
          live.code = v;
        } else {
          a.code = v;
        }
      case 'codeState':
        final cur = a.code ?? const CodeViewState(stateIndex: 0);
        final target = e.codeTarget ?? cur.stateIndex;
        if (live != null) {
          live.code = CodeViewState(
            stateIndex: target,
            fromStateIndex: cur.stateIndex,
            mix: t,
            mode: e.codeMode ?? 'type',
            typing: e.codeMode == 'type' ? t : null,
          );
        } else {
          a.code = CodeViewState(stateIndex: target);
        }
    }
  }

  /// The `moveTo` target geometry (06 §3.4): absolute frame values;
  /// omitted ones keep the current value (the origin anchor stays put when
  /// only the size changes).
  _Geom _moveTarget(_Geom cur, Map<String, Object?> p) {
    final to = p['to'];
    if (to is! Map) return cur;
    double? n(String k) => to[k] is num ? (to[k] as num).toDouble() : null;
    final w = math.max(0.0, n('w') ?? cur.w);
    final h = math.max(0.0, n('h') ?? cur.h);
    final rot = n('rotation') ?? cur.rot;
    final (ax, ay) = _anchor(p['origin']);
    final (px, py) = cur.anchor(ax, ay);
    final r = rot * math.pi / 180;
    final lx = (0.5 - ax) * w, ly = (0.5 - ay) * h;
    var cx = px + lx * math.cos(r) - ly * math.sin(r);
    var cy = py + lx * math.sin(r) + ly * math.cos(r);
    final x = n('x'), y = n('y');
    if (x != null) cx = x + w / 2;
    if (y != null) cy = y + h / 2;
    return _Geom(cx, cy, w, h, rot);
  }

  // ---------------------------------------------------------------------
  // Running

  void _run(_Eff e, _Acc a, _Live live, int local) {
    final cycle = e.cycleMs;
    var u = local.toDouble();
    var reversed = false;
    if (cycle > 0) {
      var k = (local / cycle).floor();
      if (!e.loops && k >= e.repeat) k = e.repeat - 1;
      u = (local - k * cycle).toDouble();
      reversed = e.autoReverse && k.isOdd;
    }
    var t = e.easing.at(u);
    if (reversed) t = e.easing.at(cycle - u);

    if (e.role == EffectRole.dim) {
      final ab = e.options.afterBuild;
      for (final target in e.dimTargets) {
        switch (target) {
          case _TextPartRef():
            final pl = live.part(target);
            if (ab.mode == AfterBuildMode.hide) {
              pl.opacity *= 1 - t;
            } else {
              pl.dim = 1 - (1 - ab.dimOpacity) * t;
            }
          case _ChartPartRef(:final key):
            final cur = live.chartParts[key] ?? (1.0, 1.0);
            final o = ab.mode == AfterBuildMode.hide
                ? 1 - t
                : 1 - (1 - ab.dimOpacity) * t;
            live.chartParts[key] = (cur.$1, cur.$2 * o);
        }
      }
      return;
    }

    final id = e.spec?.id ?? e.effectId;
    final el = a.el;
    final frameBox = el?.frame ?? const SuRect(0, 0, 0, 0);
    switch (e.kind) {
      case SlideBuildKind.buildIn || SlideBuildKind.buildOut:
        final isIn = e.kind == SlideBuildKind.buildIn;
        if (isIn && e.partBased) a.prepare(e);
        if (isIn && id == 'codeType') {
          a.prepare(e);
          live.code = CodeViewState(
            stateIndex: 0,
            fromStateIndex: -1,
            mix: t,
            mode: 'type',
            typing: t,
          );
          return;
        }
        final chan = _Chan();
        final box = _partBox(e, el, frameBox);
        final ctx = _ctx(e, box);
        if (isIn) {
          _evalIn(id, t, ctx, chan);
        } else {
          _evalOut(id, e.spec?.mirrorOf, t, ctx, chan);
        }
        if (e.partBased) {
          _applyPart(e, a, live, chan, box);
          final carriesBg =
              e.backgroundWithParts && (isIn ? e.firstPart : e.lastPart);
          if (carriesBg) {
            if (e.part is _TextPartRef) {
              live.textBackground = chan.opacity;
            } else {
              live.chartBackground = chan.opacity;
            }
          }
        } else {
          live.forceVisible = true;
          _applyChan(e, live, chan, frameBox);
        }
      case SlideBuildKind.emphasis || SlideBuildKind.motion:
        if (e.persistent) {
          if (e.reduced == ReducedMotionRule.fadeOutIn) {
            // Fades out at the start and in at the end position.
            if (u < 200) {
              live.opacity *= 1 - u / 200;
            } else {
              _applyPersistent(e, a, 1, live);
              live.opacity *= _clamp01((u - 200) / 200);
            }
            return;
          }
          _applyPersistent(e, a, t, live);
          return;
        }
        final chan = _Chan();
        final box = _partBox(e, el, frameBox);
        if (id == 'chartOrbit') {
          live.azimuth = _num(e.params, 'azimuth', 360) * t;
          live.elevation =
              _num(e.params, 'elevation', 0) * math.sin(math.pi * t);
          return;
        }
        _evalEmphasis(id, t, _ctx(e, box), chan);
        if (e.partBased && e.part is _TextPartRef) {
          _applyPart(e, a, live, chan, box);
        } else {
          _applyChan(e, live, chan, frameBox);
        }
    }
  }

  /// The box channels of [e] apply to: the part's box (element-local)
  /// for text parts, the element frame otherwise.
  SuRect _partBox(_Eff e, MotionElement? el, SuRect frame) {
    final p = e.part;
    if (p is _TextPartRef && el != null) {
      return el.partBoxes?.call(p.start, p.end) ??
          SuRect(0, 0, frame.width, frame.height);
    }
    return frame;
  }

  void _applyChan(_Eff e, _Live live, _Chan c, SuRect box) {
    live.opacity *= _clamp01(c.opacity);
    live.dx += c.dx;
    live.dy += c.dy;
    if (c.hasMatrix) {
      final m = c.matrix(box);
      live.chan = live.chan == null ? m : (live.chan!..multiply(m));
    }
    if (c.clip != null) live.clip = c.clip;
    if (c.blur > live.blur) live.blur = c.blur;
    if (c.dissolve != null) {
      live.dissolve = DissolveState(
        c.dissolve!,
        e.seed,
        _num(e.params, 'cell', 6),
      );
    }
    if (c.draw != null) {
      live.draw = c.draw;
      live.drawReverse = c.drawReverse;
      live.fill = c.fill;
    }
  }

  void _applyPart(_Eff e, _Acc a, _Live live, _Chan c, SuRect box) {
    switch (e.part!) {
      case final _TextPartRef r:
        final pl = live.part(r);
        pl.visible = true;
        pl.opacity *= _clamp01(c.opacity);
        if (c.hasMatrix || c.dx != 0 || c.dy != 0) {
          final m = Matrix4.identity()..translateByDouble(c.dx, c.dy, 0, 1);
          if (c.hasMatrix) m.multiply(c.matrix(box));
          pl.matrix = pl.matrix == null ? m : (pl.matrix!..multiply(m));
        }
        if (c.clip != null) pl.clip = c.clip;
        if (c.blur > pl.blur) pl.blur = c.blur;
        if (c.reveal != null && e.reveal != null) {
          final rv = e.reveal!;
          pl.revealEnd = rv.at(c.reveal! * rv.totalMs);
          pl.caret = e.params['caret'] != false;
        }
      case _ChartPartRef(:final key):
        final cur = live.chartParts[key] ?? (1.0, 1.0);
        live.chartParts[key] = (c.grow ?? cur.$1, cur.$2 * _clamp01(c.opacity));
    }
  }

  // ---------------------------------------------------------------------
  // Frames

  SlideFrame _frame(Map<String, _Acc> accs, Map<String, _Live> lives) {
    final out = <String, ElementVisualState>{};
    final ids = accs.keys.toList()..sort();
    for (final id in ids) {
      final s = _state(accs[id]!, lives[id]);
      if (!s.isEdit) out[id] = s;
    }
    return SlideFrame(Map.unmodifiable(out));
  }

  ElementVisualState _state(_Acc a, _Live? l) {
    final visible = a.visible || (l?.forceVisible ?? false);
    if (!visible) return ElementVisualState(visible: false);
    final geom = l?.geom ?? a.geom;
    Matrix4? m;
    if (!geom.same(a.geom0)) m = geom.from(a.geom0);
    if (l != null && (l.dx != 0 || l.dy != 0)) {
      final t = Matrix4.identity()..translateByDouble(l.dx, l.dy, 0, 1);
      m = m == null ? t : (t..multiply(m));
    }
    if (l?.chan != null) {
      m = m == null ? l!.chan!.clone() : (m.clone()..multiply(l!.chan!));
    }
    final opacity = (l?.opacityAbs ?? a.opacity) * (l?.opacity ?? 1);
    final colors = {...a.colors, ...?l?.colors};
    final highlights = [...a.highlights, ...?l?.highlights];

    // Text parts.
    TextPartStates? parts;
    final keys = {...a.textParts.keys, ...?l?.parts.keys}.toList();
    if (keys.isNotEmpty || !a.textBackground || l?.textBackground != null) {
      final states = <TextPartState>[];
      for (final k in keys) {
        final pa = a.textParts[k];
        final pl = l?.parts[k];
        final i = k.indexOf(':');
        final start = int.parse(k.substring(0, i));
        final end = int.parse(k.substring(i + 1));
        final vis = (pa?.visible ?? true) || (pl?.visible ?? false);
        final st = TextPartState(
          start: start,
          end: end,
          visible: vis,
          opacity: pl?.opacity ?? 1,
          transform: pl?.matrix,
          clip: pl?.clip,
          blurSigma: pl?.blur ?? 0,
          revealEnd: pl?.revealEnd,
          caret: pl?.caret ?? false,
          dim: pl?.dim ?? pa?.dim ?? 1,
          dimColor: pa?.dimColor,
        );
        if (st.toJson().length > 1) states.add(st);
      }
      states.sort((x, y) => x.start.compareTo(y.start));
      final bg = l?.textBackground ?? (a.textBackground ? 1.0 : 0.0);
      if (states.isNotEmpty || bg != 1) {
        parts = TextPartStates(parts: states, backgroundOpacity: bg);
      }
    }

    // Chart.
    ChartRevealState? chart;
    final chartKeys = {...a.chartParts.keys, ...?l?.chartParts.keys};
    final hasChart =
        chartKeys.isNotEmpty ||
        !a.chartBackground ||
        l?.chartBackground != null ||
        a.chartHighlight != null ||
        l?.chartHighlight != null ||
        a.azimuth != 0 ||
        a.elevation != 0 ||
        (l != null && (l.azimuth != 0 || l.elevation != 0)) ||
        a.camera != null ||
        l?.camera != null;
    if (hasChart) {
      final cps = <ChartPartState>[];
      for (final k in chartKeys) {
        final pa = a.chartParts[k];
        final pl = l?.chartParts[k];
        final visible = pa?.visible ?? true;
        final grow = pl?.$1 ?? (visible ? 1.0 : 0.0);
        final op = pl != null
            ? pl.$2 * (pa?.dim ?? 1)
            : (visible ? (pa?.dim ?? 1) : 0.0);
        final st = ChartPartState(k, grow: grow, opacity: op);
        if (st.toJson().length > 1) cps.add(st);
      }
      final highlight = l?.chartHighlight ?? a.chartHighlight;
      chart = ChartRevealState(
        backgroundOpacity:
            l?.chartBackground ?? (a.chartBackground ? 1.0 : 0.0),
        parts: cps,
        highlight: highlight,
        highlightMix: highlight == null
            ? 0
            : (l?.chartHighlightMix ?? (a.chartHighlight != null ? 1 : 0)),
        azimuthDelta: a.azimuth + (l?.azimuth ?? 0),
        elevationDelta: a.elevation + (l?.elevation ?? 0),
        camera: l?.camera ?? a.camera,
        fromCamera: l?.fromCamera,
        cameraMix: l?.cameraMix ?? (a.camera != null ? 1 : 0),
      );
      if (chart.toJson().isEmpty) chart = null;
    }

    return ElementVisualState(
      opacity: opacity,
      transform: m,
      blurSigma: l?.blur ?? 0,
      drawProgress: l?.draw ?? 1,
      drawReverse: l?.drawReverse ?? false,
      fillOpacity: l?.fill ?? 1,
      clip: l?.clip,
      dissolve: l?.dissolve,
      colors: colors,
      highlights: highlights,
      parts: parts,
      chart: chart,
      code: l?.code ?? a.code,
    );
  }
}

/// A timeline with programs.
final class _CompiledTimeline extends SlideTimeline {
  _CompiledTimeline({
    required super.slideId,
    required super.steps,
    required super.warnings,
    required _Program program,
  }) : _program = program; // ignore: prefer_initializing_formals

  final _Program _program;

  @override
  SlideFrame get initial => _program.initialFrame;

  @override
  SlideFrame endOfStep(int step) => _program.endOfStep(step);

  @override
  SlideFrame frameAt(TimelinePosition p) => _program.frameAt(p.step, p.ms);

  @override
  SlideFrame get printFrame => _program.printFrame;

  @override
  Map<String, Object?> describe() => {
    ...super.describe(),
    'steps': [for (final s in steps) s.toJson()],
    if (warnings.isNotEmpty) 'warnings': [for (final w in warnings) w.toJson()],
  };
}
