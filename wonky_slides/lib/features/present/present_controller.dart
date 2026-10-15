import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        PresentationCommandEvent,
        PresentationCommandUpdate,
        PresentationEvent,
        PresentationInkEvent,
        PresentationInkUpdate,
        PresentationLaserEvent,
        PresentationLaserUpdate,
        PresentationRole,
        PresentationState,
        PresentationStateEvent,
        PresentationStateUpdate,
        PresentationWelcome;
import 'package:wonky_slides_core/charts.dart' show SlideChartMotion;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart' show SlideScene;

import '../motion/player/motion_budget.dart';
import '../motion/player/slide_player.dart';

import 'present_ink.dart';
import 'present_sequence.dart';
import 'present_settings.dart';
import 'presentation_link.dart';

/// Where this present screen shows the deck (Slides 10 §1.1, §5.2).
enum PresentView {
  /// Present mode: the audience rendering in this window, full screen.
  present,

  /// The presenter view in this window (current/next, notes, timers).
  presenter,

  /// The audience view of a session on another device or browser.
  audience,

  /// A collaborator following the presentation (`?view=follow`, 09 §1.6,
  /// 10 §6.3; SL-37): joins as `follower`, can't control, may browse away
  /// and return to the presenter.
  follower;

  static PresentView fromName(String? name) => switch (name) {
    'presenter' => presenter,
    'audience' => audience,
    'follow' => follower,
    _ => present,
  };

  /// Whether this view follows a presenter of a session (audience or
  /// follower).
  bool get isMember => this == audience || this == follower;
}

/// Black or white screen (10 §4.4).
enum PresentBlank {
  none,
  black,
  white;

  static PresentBlank fromName(Object? name) => switch (name) {
    'black' => black,
    'white' => white,
    _ => none,
  };
}

/// The presenter's timer (10 §5.1): elapsed with pause/reset; it starts
/// with the first advance (or *Start*).
class PresentTimer {
  PresentTimer(this._now);

  final int Function() _now;
  int _base = 0;
  int? _since;
  bool _started = false;

  bool get running => _since != null;

  /// Whether the timer ran at all (the first advance starts it).
  bool get started => _started;

  int get elapsedMs => _base + (_since == null ? 0 : _now() - _since!);

  void start() {
    _started = true;
    _since ??= _now();
  }

  void pause() {
    final s = _since;
    if (s == null) return;
    _base += _now() - s;
    _since = null;
  }

  void reset() {
    _base = 0;
    if (_since != null) _since = _now();
  }

  /// The audience copies the presenter's timer.
  void set(int elapsedMs, {required bool running}) {
    _started = true;
    _base = elapsedMs;
    _since = running ? _now() : null;
  }
}

/// The state of one presentation (Slides 10 §1–§6) for the present
/// screen, the presenter view and the `slides.present.*` commands:
/// the position in the timeline order ([PresentSequence]), black/white,
/// the end screen, the slide picker, help and *Go to slide n* overlays,
/// the pointer tools with laser and ephemeral ink, the timer, and the
/// presentation session ([link]) — the presenter view publishes its state
/// to the audience on other devices; an audience view applies it and
/// sends its own navigation to the presenter as commands.
class PresentController extends ChangeNotifier {
  PresentController({
    required this.model,
    required this.view,
    String? startSlideId,
    int startStep = 0,
    SlideTimelineOf? timelineOf,
    int Function()? nowMs,
    this.link,
    bool showSkipped = false,
    this.notesSize = 18,
    this.burstMs = 120,
    String? inkPrefix,
    this._reducedMotion = false,
    this.scenesOf,
    this._kiosk = false,
  }) : _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _inkPrefix = inkPrefix ?? _randomPrefix() {
    timer = PresentTimer(_now);
    sequence = PresentSequence(
      model.indexes.order,
      timelineOf: timelineOf ?? _compile,
      showSkipped: showSkipped,
    );
    player = SlidePlayer(timelineOf: sequence.timelineOf, planOf: _planOf);
    if (!view.isMember) {
      final start = sequence.startAt(startSlideId);
      _position = start == null
          ? null
          : (sequence.goTo(
                  start.slideId,
                  start.slideId == startSlideId ? startStep : 0,
                ) ??
                start);
      _lastIndex = _position == null
          ? 0
          : model.indexes.order.indexOf(_position!.slideId);
      _stepStartedMs = _now();
      final p = _position;
      if (p != null) {
        // The first slide shows without a transition; its step 0 plays.
        player.enter(p.slideId, now: _stepStartedMs, toStep: p.step);
        _afterNavigation();
      }
    }
    model.addListener(_onBatch);
    final l = link;
    if (l != null) {
      _linkSub = l.events.listen(_onLinkEvent);
      l.addListener(notifyListeners);
      if (view == PresentView.presenter) {
        _heartbeat = Timer.periodic(
          const Duration(seconds: 10),
          (_) => _publish(),
        );
      }
    }
  }

  final DeckModel model;
  final PresentView view;

  /// The stage's scenes (Flutter text layout: exact part boxes and Magic
  /// Move glyph runs), or null (the core text layout is used).
  final SlideScene? Function(String slideId)? scenesOf;

  /// Plays builds and transitions (06 §6): the frames of [view].
  late final SlidePlayer player;

  /// The session (presenter view and audience views; null when presenting
  /// alone or offline without a session).
  final PresentationLink? link;
  final int Function() _now;
  final String _inkPrefix;

  /// Inputs within this many ms of the last accepted one are collapsed
  /// (10 §2.1).
  final int burstMs;

  late final PresentTimer timer;
  late final PresentSequence sequence;
  final InkModel ink = InkModel();

  StreamSubscription<PresentationEvent>? _linkSub;
  Timer? _heartbeat;
  bool _disposed = false;

  /// Called once when the presentation ends (the screen leaves the route
  /// for the editor at [position]).
  VoidCallback? onEnd;

  static String _randomPrefix() {
    final r = math.Random();
    return List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  // ------------------------------------------------------------ settings

  String? _settingsJson;
  PresentSettings _settings = PresentSettings.defaults;

  /// `Deck.presentJson` (10 §3).
  PresentSettings get settings {
    final json = model.deck?.presentJson;
    if (json != _settingsJson) {
      _settingsJson = json;
      _settings = PresentSettings.parse(json);
    }
    return _settings;
  }

  // ------------------------------------------------------------ timeline

  final Map<String, (String, SlideTimeline)> _timelines = {};

  bool _reducedMotion;

  /// Whether the system or app asks for reduced motion (06 §13); the
  /// deck's own *Reduce motion* setting ([PresentSettings.reduceMotion])
  /// applies as well. The present screen keeps it current.
  bool get reducedMotion => _reducedMotion;
  set reducedMotion(bool value) {
    if (value == _reducedMotion) return;
    _reducedMotion = value;
    _timelines.clear();
    _plans.clear();
  }

  /// Compiles [slideId] from the deck (Slides 12 §5.5, SL-24): builds,
  /// the effective transition and every element resolved, so transforms
  /// are about the elements' centers and references are validated.
  SlideTimeline _compile(String slideId) {
    final reduced = _reducedMotion || settings.reduceMotion;
    final rev = '${model.indexes.revision(slideId)}|$reduced';
    final hit = _timelines[slideId];
    if (hit != null && hit.$1 == rev) return hit.$2;
    final t = model.slide(slideId) == null
        ? SlideTimeline(slideId: slideId)
        : SlideTimelineCompiler.compile(
            SlideMotionInput.fromDeck(
              model,
              slideId,
              scene: scenesOf?.call(slideId),
              options: CompileOptions(reducedMotion: reduced),
              chartShapeOf: _chartShapes,
            ),
          );
    _timelines[slideId] = (rev, t);
    return t;
  }

  late final _chartShapes = SlideChartMotion.shapes(model);

  final Map<String, (String, TransitionPlan)> _plans = {};

  /// Compiles (or reuses) the transition of [r] (06 §9.9; plans are cached
  /// per slides' revisions, steps and direction, 06 §14 prefetch).
  TransitionPlan planOf(TransitionRequest r) => _planOf(r);

  TransitionPlan _planOf(TransitionRequest r) {
    final reduced = _reducedMotion || settings.reduceMotion;
    final rev =
        '${model.indexes.revision(r.fromSlideId)}|'
        '${model.indexes.revision(r.toSlideId)}|$reduced|'
        '${model.deck?.defaultsJson.hashCode}';
    final key = r.key;
    final hit = _plans[key];
    if (hit != null && hit.$1 == rev) return hit.$2;
    TransitionPlan plan;
    try {
      plan = TransitionCompiler.between(
        model,
        fromSlideId: r.fromSlideId,
        toSlideId: r.toSlideId,
        fromFrame: r.fromFrame,
        toFrame: r.toFrame,
        options: TransitionOptions(reducedMotion: reduced, reverse: r.reverse),
        fromScene: scenesOf?.call(r.fromSlideId),
        toScene: scenesOf?.call(r.toSlideId),
      );
    } on Object {
      plan = TransitionPlan.cut;
    }
    _plans[key] = (rev, plan);
    if (_plans.length > 32) _plans.remove(_plans.keys.first);
    return plan;
  }

  /// The timeline of [slideId].
  SlideTimeline timelineOf(String slideId) => sequence.timelineOf(slideId);

  // ------------------------------------------------------------ position

  PresentPosition? _position;
  int _lastIndex = 0;
  int _stepStartedMs = 0;

  /// The shown slide and step (null in an empty deck, or while an audience
  /// waits for the presenter).
  PresentPosition? get position => _position;

  /// What the audience sees now (06 §6): the current slide in a frame of
  /// its timeline, a transition, or the degraded crossfade; null without a
  /// slide. Blur stays within the budget of 06 §14.
  PlayerView? get playerView {
    if (_position == null) return null;
    final v = player.viewAt(_now());
    if (v is SlidePlayerView) {
      final f = MotionBudget.limitBlur(v.frame);
      if (!identical(f, v.frame)) return SlidePlayerView(v.slideId, v.step, f);
    }
    return v;
  }

  /// The current slide's frame now (the settled frame during a transition).
  SlideFrame get frame {
    final p = _position;
    if (p == null) return SlideFrame.edit;
    final v = playerView;
    if (v is SlidePlayerView && v.slideId == p.slideId) return v.frame;
    return timelineOf(p.slideId).endOfStep(p.step);
  }

  /// Whether the stage animates (a transition, build or looping emphasis
  /// runs): it ticks every frame while true.
  bool get animating => _position != null && player.needsTicks(_now());

  /// Whether the running animation was degraded to a crossfade (the
  /// presenter view shows "Reduced effects", 06 §14).
  bool get degraded => player.degraded;

  final FrameBudget _budget = FrameBudget();

  /// Called by the stage on every animation frame: counts frames that
  /// missed the budget and degrades the running animation after 10 in a
  /// row (06 §14).
  void animationFrame() {
    if (!player.isRunning(_now())) {
      _budget.reset();
      return;
    }
    if (_budget.frame(_now()) && !player.degraded) {
      player.degrade(_now());
      _budget.reset();
      debugPrint('slides.motion.degraded');
      notifyListeners();
    }
  }

  /// Milliseconds since the current step started.
  int get stepElapsedMs => math.max(0, _now() - _stepStartedMs);

  /// Whether the current step's builds are still running (a *Next*
  /// finishes them first, 10 §2.1).
  bool get stepRunning => _position != null && player.isRunning(_now());

  /// The end screen (10 §1.5).
  bool get endScreen => _endScreen;
  bool _endScreen = false;

  /// The audience waits for the presenter's slide to arrive by sync
  /// ("Catching up…", 10 §6.2).
  bool get catchingUp => _pendingRemote != null;
  PresentPosition? _pendingRemote;

  /// Whether this view only mirrors the presenter (navigation becomes
  /// commands to the presenter; a follower's navigation browses away).
  bool get mirrors =>
      view == PresentView.audience ||
      (view == PresentView.follower && !_browsing);

  // ---------------------------------------------- follower (SL-37, 09 §1.6)

  bool _browsing = false;
  (PresentationState, int?)? _latestRemote;

  /// Whether a follower browsed away from the presenter's slide (10 §6.3:
  /// *Return to presenter*).
  bool get browsing => _browsing;

  /// A follower's navigation leaves the presenter (locally only).
  void _browse() {
    if (view != PresentView.follower || _browsing) return;
    _browsing = true;
    _laser = null;
    notifyListeners();
  }

  /// Back to the presenter's current slide and step (a follower that
  /// browsed away).
  void returnToPresenter() {
    if (!_browsing) return;
    _browsing = false;
    _picker = false;
    final latest = _latestRemote;
    if (latest != null) {
      _remoteRevision = -1;
      applyState(latest.$1, sentAtMs: latest.$2);
    } else {
      notifyListeners();
    }
  }

  SlideOrderEntry? get currentEntry =>
      _position == null ? null : sequence.order.entry(_position!.slideId);

  /// "12 / 40": the slide's 1-based deck position and the deck's length.
  (int, int) get counter => (
    currentEntry == null ? 0 : currentEntry!.index + 1,
    sequence.order.length,
  );

  /// What the presenter view's *Next* shows: the next step on this slide,
  /// the next slide, or null at the end.
  PresentPosition? get upNext {
    final p = _position;
    if (p == null || _endScreen) return null;
    return sequence.next(p);
  }

  int _lastInput = -1 << 40;

  bool _accept(bool user) {
    if (!user) return true;
    // Kiosk: navigation is the timers' (10 §9).
    if (kiosk) return false;
    final now = _now();
    if (now - _lastInput < burstMs) return false;
    _lastInput = now;
    return true;
  }

  void _goto(PresentPosition p, {bool back = false}) {
    final prev = _position;
    final now = _now();
    _play(prev, p, back: back, now: now);
    _position = p;
    _lastIndex = sequence.order.indexOf(p.slideId);
    _stepStartedMs = now;
    _endScreen = false;
    _blank = PresentBlank.none;
    _laser = null;
    if (!timer.started) timer.start();
    _afterNavigation();
    _changed();
  }

  /// Plays the way from [prev] to [p] (06 §6): the next step on the same
  /// slide plays; other steps on it are jumps; another slide plays its
  /// transition (backward: the left slide's transition reversed when its
  /// `reverseOnBack`, then the target settled; forward: then step 0).
  void _play(
    PresentPosition? prev,
    PresentPosition p, {
    required bool back,
    required int now,
    int elapsed = 0,
  }) {
    _budget.reset();
    if (prev == null || player.slideId == null) {
      player.enter(p.slideId, now: now, toStep: p.step, elapsed: elapsed);
      return;
    }
    if (prev.slideId == p.slideId && !(p.step == 0 && prev.step == 0)) {
      if (!back && p.step == prev.step + 1) {
        player.playStep(p.step, now: now, elapsed: elapsed);
      } else {
        player.show(p.slideId, p.step, now: now);
      }
      return;
    }
    var reverse = false;
    if (back) {
      reverse = TransitionSpec.effective(
        model.slide(prev.slideId)?.transitionJson,
        model.deck?.defaultsJson,
      ).reverseOnBack;
    }
    player.enter(
      p.slideId,
      now: now,
      fromSlideId: prev.slideId,
      fromStep: prev.step,
      fromFrame: player.slideId == prev.slideId ? player.settledFrame : null,
      toStep: p.step,
      reverse: reverse,
      playStep0: !back,
      elapsed: elapsed,
    );
  }

  // ------------------------------------------------- kiosk, auto-advance

  final bool _kiosk;

  /// Self-running kiosk mode (`?kiosk=1` or `presentJson.mode`, 10 §9):
  /// every step and slide advances on its own, loops, and user navigation
  /// is off (exit with the Esc gesture).
  bool get kiosk => !view.isMember && (_kiosk || settings.mode == 'kiosk');

  /// Whether the deck continues with its first slide after the last.
  bool get loops => kiosk || settings.loops;

  int? _autoAt;
  Timer? _autoTimer;

  /// When the presentation advances by itself (the controller's clock),
  /// or null: kiosk timers, `advance: auto`, rehearsed timings (06 §4.4,
  /// 10 §9–§10).
  int? get autoAdvanceAt => _autoAt;

  void _afterNavigation() {
    _scheduleAuto();
    _schedulePrefetch();
  }

  /// The rehearsed step times of [slideId] (`Slide.timingsJson`), or null.
  List<int>? rehearsedSteps(String slideId) {
    final json = model.slide(slideId)?.timingsJson;
    if (json == null || json.isEmpty) return null;
    try {
      final v = jsonDecode(json);
      final steps = v is Map ? v['stepsMs'] : null;
      if (steps is! List || steps.isEmpty) return null;
      return [for (final x in steps) x is num ? x.toInt() : 0];
    } on FormatException {
      return null;
    }
  }

  void _scheduleAuto() {
    _autoAt = null;
    final p = _position;
    if (p != null &&
        !mirrors &&
        view != PresentView.follower &&
        !_ended &&
        !_endScreen) {
      final steps = timelineOf(p.slideId).stepCount;
      final last = p.step >= steps;
      final spec = TransitionSpec.effective(
        model.slide(p.slideId)?.transitionJson,
        model.deck?.defaultsJson,
      );
      final settle = player.endMs;
      final rehearsed = settings.useRehearsedTimings || kiosk
          ? rehearsedSteps(p.slideId)
          : null;
      if (rehearsed != null && p.step < rehearsed.length) {
        _autoAt = math.max(settle, _stepStartedMs + rehearsed[p.step]);
      } else if (kiosk) {
        _autoAt =
            settle +
            (last
                ? (spec.advance.auto ? spec.advance.afterMs : kioskSlideMs)
                : spec.advance.buildDelayMs);
      } else if (last && spec.advance.auto) {
        _autoAt = settle + spec.advance.afterMs;
      }
    }
    if (_autoAt == null) {
      _autoTimer?.cancel();
      _autoTimer = null;
    } else {
      _autoTimer ??= Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => autoTick(),
      );
    }
  }

  /// Kiosk: how long a slide without timing stays after its builds.
  static const int kioskSlideMs = 5000;

  /// Advances when the auto-advance time has come (a 50 ms timer calls it;
  /// tests call it after moving the clock). Waits while the screen is
  /// blanked or the picker is open.
  void autoTick() {
    final at = _autoAt;
    if (at == null || _disposed || _ended) return;
    if (_now() < at || _blank != PresentBlank.none || _picker) return;
    _autoAt = null;
    if (!next(user: false)) _scheduleAuto();
  }

  // ------------------------------------------------------------ prefetch

  Timer? _prefetchTimer;

  void _schedulePrefetch() {
    if (_disposed) return;
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer(const Duration(milliseconds: 1), prefetch);
  }

  /// The transition the next *Next* plays from the end of this slide
  /// (prefetched; the stage prepares its snapshots), or null.
  TransitionRequest? get upcomingTransition {
    final p = _position;
    if (p == null) return null;
    final n = sequence.nextSlide(p) ?? (loops ? sequence.first() : null);
    if (n == null || n.slideId == p.slideId) return null;
    final from = timelineOf(p.slideId);
    final to = timelineOf(n.slideId);
    return TransitionRequest(
      fromSlideId: p.slideId,
      fromStep: from.stepCount,
      fromFrame: from.finalFrame,
      toSlideId: n.slideId,
      toStep: -1,
      toFrame: to.initial,
      reverse: false,
    );
  }

  /// Compiles the timelines of the neighbors and the plan into the next
  /// slide ahead of time (06 §14: prefetch).
  void prefetch() {
    final p = _position;
    if (p == null || _disposed) return;
    final prev = sequence.previousSlide(p);
    if (prev != null) timelineOf(prev.slideId);
    final r = upcomingTransition;
    if (r != null) {
      _planOf(r);
      if (_has3dChart(r.toSlideId)) onPrefetch3dChart?.call();
    }
  }

  /// Starts the 3D chart GPU backend when the next slide has a 3D chart
  /// (06 §14 prefetch); set by the present stage.
  VoidCallback? onPrefetch3dChart;

  bool _has3dChart(String slideId) {
    for (final e in model.elementsOf(slideId)) {
      if (e.kind == ElementKind.chart && (_chartShapes(e)?.is3d ?? false)) {
        return true;
      }
    }
    return false;
  }

  /// Returns to the slide from a black/white screen (any navigation does
  /// so first, without advancing; 10 §4.4).
  bool _unblank() {
    if (_blank == PresentBlank.none) return false;
    _blank = PresentBlank.none;
    _changed();
    return true;
  }

  bool _command(String command, [Map<String, Object?>? args]) {
    // Followers can't control the presentation (10 §6.3).
    if (view == PresentView.follower) return false;
    link?.send(
      PresentationCommandUpdate(
        command: command,
        argsJson: args == null ? null : jsonEncode(args),
      ),
    );
    return link != null;
  }

  /// Next step, then slide (→, Space, PageDown, click; 10 §2.1).
  bool next({bool user = true}) {
    if (!_accept(user)) return false;
    _browse();
    if (mirrors) return _command('next');
    if (_unblank()) return true;
    if (_endScreen) {
      if (loops) return _restart();
      end();
      return true;
    }
    final p = _position;
    if (p == null) return false;
    if (stepRunning) {
      // A click during a build finishes it (06 §6); `skip` also starts the
      // next step at once (10 §3).
      player.finish();
      if (settings.advanceDuringBuild != 'skip') {
        _scheduleAuto();
        _changed();
        return true;
      }
    }
    final n = sequence.next(p);
    if (n != null) {
      _goto(n);
      return true;
    }
    return _atEnd();
  }

  bool _atEnd() {
    if (loops) return _restart();
    if (settings.endBehavior == 'exit') {
      end();
      return true;
    }
    _endScreen = true;
    _blank = PresentBlank.none;
    _changed();
    return true;
  }

  bool _restart() {
    final f = sequence.first();
    if (f == null) return false;
    _goto(f);
    return true;
  }

  /// The previous step's end state, or the previous slide's final frame.
  bool previous({bool user = true}) {
    if (!_accept(user)) return false;
    _browse();
    if (mirrors) return _command('previous');
    if (_unblank()) return true;
    if (_endScreen) {
      _endScreen = false;
      _changed();
      return true;
    }
    final p = _position;
    if (p == null) return false;
    final n = sequence.previous(p);
    if (n == null) return false;
    _goto(n, back: true);
    return true;
  }

  /// The next slide, skipping the remaining builds.
  bool nextSlide({bool user = true}) {
    if (!_accept(user)) return false;
    _browse();
    if (mirrors) return _command('nextSlide');
    if (_unblank()) return true;
    final p = _position;
    if (p == null) return false;
    if (_endScreen) return next(user: false);
    final n = sequence.nextSlide(p);
    if (n != null) {
      _goto(n);
      return true;
    }
    return _atEnd();
  }

  /// The previous slide at its start.
  bool previousSlide({bool user = true}) {
    if (!_accept(user)) return false;
    _browse();
    if (mirrors) return _command('previousSlide');
    if (_unblank()) return true;
    if (_endScreen) return previous(user: false);
    final p = _position;
    if (p == null) return false;
    final n = sequence.previousSlide(p);
    if (n == null) return false;
    _goto(n, back: true);
    return true;
  }

  bool first() {
    _browse();
    if (mirrors) return _command('first');
    final f = sequence.first();
    if (f == null) return false;
    _goto(f);
    return true;
  }

  bool last() {
    _browse();
    if (mirrors) return _command('last');
    final f = sequence.last();
    if (f == null) return false;
    _goto(f);
    return true;
  }

  /// Shows [slideId] at [step] — skipped slides too (picker, *Go to
  /// slide*, the strip; 10 §2.2).
  bool goTo(String slideId, [int step = 0]) {
    _browse();
    if (mirrors) return _command('goTo', {'slideId': slideId, 'step': step});
    final p = sequence.goTo(slideId, step);
    if (p == null) return false;
    _picker = false;
    _goto(p);
    return true;
  }

  /// *Go to slide n* by 1-based deck position.
  bool goToNumber(int number) {
    final p = sequence.goToNumber(number);
    if (p == null) return false;
    return goTo(p.slideId);
  }

  // ------------------------------------------------ overlays and blanking

  PresentBlank _blank = PresentBlank.none;

  /// Black/white screen over the audience rendering (10 §4.4).
  PresentBlank get blank => _blank;

  /// Sets the screen; the same color again returns to the slide.
  void setBlank(PresentBlank color, {bool toggle = true}) {
    if (mirrors) {
      _command('blank', {'color': color.name});
      return;
    }
    final next = toggle && color == _blank ? PresentBlank.none : color;
    if (next == _blank) return;
    _blank = next;
    _changed();
  }

  bool _picker = false;

  /// The slide picker (10 §4.5).
  bool get pickerOpen => _picker;

  void setPicker(bool open) {
    if (open == _picker) return;
    _picker = open;
    _changed();
  }

  bool _help = false;

  /// The shortcut help overlay (10 §4.6).
  bool get helpOpen => _help;

  void setHelp(bool open) {
    if (open == _help) return;
    _help = open;
    notifyListeners();
  }

  String? _number;

  /// The digits typed for *Go to slide n* ("Go to 12"), or null.
  String? get numberEntry => _number;

  void typeDigit(int digit) {
    final n = '${_number ?? ''}$digit';
    _number = n.length > 4 ? n.substring(n.length - 4) : n;
    notifyListeners();
  }

  /// Goes to the typed number; returns whether a number was pending.
  bool commitNumber() {
    final n = _number;
    if (n == null) return false;
    _number = null;
    final v = int.tryParse(n);
    if (v == null || !goToNumber(v)) notifyListeners();
    return true;
  }

  /// `Esc` closes the innermost transient state first (number entry,
  /// help, picker, a drawing tool); returns false when there was none
  /// (then `Esc` ends the presentation, 10 §2.1).
  bool escape() {
    if (_number != null) {
      _number = null;
      notifyListeners();
      return true;
    }
    if (_help) {
      setHelp(false);
      return true;
    }
    if (_picker) {
      setPicker(false);
      return true;
    }
    if (_tool != PresentTool.arrow) {
      setTool(PresentTool.arrow);
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------- tools

  PresentTool _tool = PresentTool.arrow;
  PresentTool get tool => _tool;

  /// The pen color and width last used (10 §4.3).
  int penColor = InkColors.all['red']!;
  double penWidth = InkColors.penWidths['medium']!;

  /// Toggles [tool] (the same tool again returns to the arrow).
  void setTool(
    PresentTool tool, {
    bool toggle = false,
    int? color,
    double? width,
  }) {
    if (color != null) penColor = color;
    if (width != null) penWidth = width;
    final next = toggle && tool == _tool ? PresentTool.arrow : tool;
    if (next == _tool && color == null && width == null) return;
    _tool = next;
    if (next != PresentTool.laser) setLaser(null);
    notifyListeners();
  }

  bool _temporaryLaser = false;

  /// Holding `Mod` while moving the mouse shows the laser (10 §2.1).
  bool get laserActive => _tool == PresentTool.laser || _temporaryLaser;

  void setTemporaryLaser(bool on) {
    if (on == _temporaryLaser) return;
    _temporaryLaser = on;
    if (!laserActive) setLaser(null);
    notifyListeners();
  }

  Offset? _laser;
  final List<(Offset, int)> _trail = [];
  int _lastLaserSent = 0;

  /// The laser position in slide units (null = hidden).
  Offset? get laser => _laser;

  /// The last 300 ms of laser positions (newest last) with their age.
  List<(Offset, int)> get laserTrail {
    final now = _now();
    _trail.removeWhere((e) => now - e.$2 > 300);
    return [for (final e in _trail) (e.$1, now - e.$2)];
  }

  /// Moves (or hides, null) the laser; mirrored to the audience (≤ 30 Hz).
  void setLaser(Offset? su) {
    if (su == _laser) return;
    _laser = su;
    final now = _now();
    if (su != null) {
      _trail.add((su, now));
      if (_trail.length > 64) _trail.removeAt(0);
    } else {
      _trail.clear();
    }
    if (_publishes && (su == null || now - _lastLaserSent >= 33)) {
      _lastLaserSent = now;
      link!.send(
        PresentationLaserUpdate(
          slideId: _position?.slideId,
          x: su?.dx,
          y: su?.dy,
        ),
      );
    }
    notifyListeners();
  }

  InkStroke? _drawing;
  OneEuroFilter? _filter;
  int _inkSeq = 0;

  /// The stroke being drawn.
  InkStroke? get drawing => _drawing;

  /// Pointer down on the slide at [su] with the current tool.
  void pointerDown(Offset su) {
    final p = _position;
    if (p == null || mirrors || view == PresentView.follower) return;
    switch (_tool) {
      case PresentTool.pen || PresentTool.highlighter:
        final hl = _tool == PresentTool.highlighter;
        _filter = OneEuroFilter();
        _drawing = InkStroke(
          id: '$_inkPrefix-${_inkSeq++}',
          tool: _tool,
          color: penColor,
          width: hl ? InkColors.highlighterWidth : penWidth,
          points: [_filter!.filter(su, _now())],
        );
        notifyListeners();
      case PresentTool.eraser:
        _erase(p.slideId, su);
      case PresentTool.laser:
        setLaser(su);
      case PresentTool.arrow:
        break;
    }
  }

  void pointerMove(Offset su) {
    final p = _position;
    if (p == null || mirrors || view == PresentView.follower) return;
    final d = _drawing;
    if (d != null) {
      _drawing = d.extend(_filter!.filter(su, _now()));
      notifyListeners();
    } else if (_tool == PresentTool.eraser) {
      _erase(p.slideId, su);
    } else if (laserActive) {
      setLaser(su);
    }
  }

  void pointerUp() {
    final d = _drawing;
    final p = _position;
    _drawing = null;
    _filter = null;
    if (d == null || p == null) return;
    ink.put(p.slideId, d);
    if (_publishes) {
      link!.send(
        PresentationInkUpdate(
          slideId: p.slideId,
          op: 'add',
          strokeId: d.id,
          strokeJson: d.encode(),
        ),
      );
    }
    notifyListeners();
  }

  void _erase(String slideId, Offset su) {
    final removed = ink.eraseAt(slideId, su, 6);
    if (removed.isEmpty) return;
    for (final id in removed) {
      if (_publishes) {
        link!.send(
          PresentationInkUpdate(slideId: slideId, op: 'remove', strokeId: id),
        );
      }
    }
    notifyListeners();
  }

  /// Clears the ink of [slideId] (default: the current slide).
  void clearInk([String? slideId]) {
    final id = slideId ?? _position?.slideId;
    if (id == null || !ink.hasInk(id)) return;
    ink.clear(id);
    if (_publishes) {
      link!.send(PresentationInkUpdate(slideId: id, op: 'clear'));
    }
    notifyListeners();
  }

  /// Removes the last stroke of [slideId] (default: the current slide).
  bool undoInk([String? slideId]) {
    final id = slideId ?? _position?.slideId;
    if (id == null) return false;
    final removed = ink.undo(id);
    if (removed == null) return false;
    if (_publishes) {
      link!.send(
        PresentationInkUpdate(slideId: id, op: 'remove', strokeId: removed),
      );
    }
    notifyListeners();
    return true;
  }

  // -------------------------------------------------------- presenter view

  /// The presenter view's *Show skipped slides* (10 §2.2).
  bool get showSkipped => sequence.showSkipped;

  void setShowSkipped(bool v) {
    if (v == sequence.showSkipped) return;
    sequence.showSkipped = v;
    notifyListeners();
  }

  /// Speaker notes size in pt (12–48, 10 §5.1).
  int notesSize;

  void setNotesSize(int size) {
    final s = size.clamp(12, 48);
    if (s == notesSize) return;
    notesSize = s;
    notifyListeners();
  }

  /// `slides.present.timer {action}`.
  void timerAction(String action) {
    if (mirrors) {
      _command('timer', {'action': action});
      return;
    }
    switch (action) {
      case 'start' || 'resume':
        timer.start();
      case 'pause':
        timer.pause();
      case 'toggle':
        timer.running ? timer.pause() : timer.start();
      case 'reset':
        timer.reset();
      default:
        return;
    }
    _changed();
  }

  // ------------------------------------------------------------- ending

  bool _ended = false;
  bool get ended => _ended;

  /// Ends the presentation (and the session); ink is discarded.
  void end() {
    if (_ended) return;
    _ended = true;
    _autoTimer?.cancel();
    _autoTimer = null;
    ink.clearAll();
    if (view == PresentView.presenter) unawaited(link?.end());
    notifyListeners();
    onEnd?.call();
  }

  // ------------------------------------------------------------ session

  int _revision = 0;
  int _remoteRevision = -1;

  bool get _publishes =>
      link != null &&
      !view.isMember &&
      link!.role == PresentationRole.presenter;

  void _changed() {
    _publish();
    notifyListeners();
  }

  /// The presenter's state message (10 §6.2).
  PresentationState snapshot() => PresentationState(
    revision: _revision,
    slideId: _position?.slideId,
    step: _position?.step ?? 0,
    stepElapsedMs: stepElapsedMs,
    blank: _blank.name,
    // With the presenter view open, only it shows the picker.
    picker: view == PresentView.present && _picker,
    endScreen: _endScreen,
    timerRunning: timer.running,
    timerElapsedMs: timer.elapsedMs,
    deckRevision: '${model.version}',
  );

  void _publish() {
    if (!_publishes || _disposed) return;
    _revision++;
    link!.send(PresentationStateUpdate(state: snapshot()));
  }

  void _onLinkEvent(PresentationEvent e) {
    if (_disposed) return;
    switch (e) {
      case PresentationWelcome():
        if (view.isMember) {
          final s = e.state;
          if (s != null) applyState(s, sentAtMs: e.stateSentAtMs);
        } else {
          // (Re)joined: the audience gets the full state.
          _publish();
          for (final entry in sequence.order.entries) {
            for (final s in ink.strokesOf(entry.id)) {
              link!.send(
                PresentationInkUpdate(
                  slideId: entry.id,
                  op: 'add',
                  strokeId: s.id,
                  strokeJson: s.encode(),
                ),
              );
            }
          }
        }
      case PresentationStateEvent():
        if (view.isMember) {
          applyState(e.state, sentAtMs: e.serverTimeMs);
        }
      case PresentationLaserEvent():
        if (!view.isMember || _browsing) return;
        final x = e.x, y = e.y;
        _laser = x == null || y == null ? null : Offset(x, y);
        if (_laser != null) {
          _trail.add((_laser!, _now()));
          if (_trail.length > 64) _trail.removeAt(0);
        } else {
          _trail.clear();
        }
        notifyListeners();
      case PresentationInkEvent():
        if (!view.isMember) return;
        switch (e.op) {
          case 'add':
            final s = InkStroke.tryParse(e.strokeJson);
            if (s != null) ink.put(e.slideId, s);
          case 'remove':
            if (e.strokeId != null) ink.remove(e.slideId, e.strokeId!);
          case 'clear':
            ink.clear(e.slideId);
        }
        notifyListeners();
      case PresentationCommandEvent():
        if (view.isMember) return;
        applyCommand(e.command, e.argsJson);
      default:
        break;
    }
  }

  /// Applies a command of an audience device or remote (the presenter is
  /// the only authority; 10 §6.2).
  void applyCommand(String command, String? argsJson) {
    Map<String, Object?> args = const {};
    if (argsJson != null) {
      try {
        final v = jsonDecode(argsJson);
        if (v is Map) args = v.cast<String, Object?>();
      } on FormatException {
        return;
      }
    }
    switch (command) {
      case 'next':
        next();
      case 'previous':
        previous();
      case 'nextSlide':
        nextSlide();
      case 'previousSlide':
        previousSlide();
      case 'first':
        first();
      case 'last':
        last();
      case 'goTo':
        final id = args['slideId'];
        final step = args['step'];
        if (id is String) goTo(id, step is int ? step : 0);
      case 'blank':
        setBlank(PresentBlank.fromName(args['color']), toggle: false);
      case 'timer':
        final a = args['action'];
        if (a is String) timerAction(a);
    }
  }

  /// The audience follows the presenter's [s] (sent at server time
  /// [sentAtMs]); a slide that hasn't synced yet waits ("Catching up…").
  void applyState(PresentationState s, {int? sentAtMs}) {
    if (s.revision <= _remoteRevision && s.revision != 0) return;
    if (view == PresentView.follower) {
      // A follower that browsed away catches up on *Return to presenter*.
      _latestRemote = (s, sentAtMs);
      if (_browsing) return;
    }
    _remoteRevision = s.revision;
    final since = sentAtMs == null || link == null
        ? 0
        : link!.clock.sinceServer(sentAtMs, _now());
    _blank = PresentBlank.fromName(s.blank);
    _picker = s.picker;
    _endScreen = s.endScreen;
    timer.set(
      s.timerElapsedMs + (s.timerRunning ? since : 0),
      running: s.timerRunning,
    );
    final id = s.slideId;
    if (id == null) {
      _position = null;
      _pendingRemote = null;
    } else {
      final target = PresentPosition(id, s.step);
      if (model.slide(id) == null) {
        _pendingRemote = target;
      } else {
        _pendingRemote = null;
        if (target != _position) {
          _laser = null;
          // Follow with the same animation, as far into it as the
          // presenter is (06 §6, 10 §6.2).
          final prev = _position;
          final back =
              prev != null &&
              (prev.slideId == id
                  ? s.step < prev.step
                  : sequence.order.indexOf(id) <
                        sequence.order.indexOf(prev.slideId));
          _play(
            prev,
            target,
            back: back,
            now: _now(),
            elapsed: s.stepElapsedMs + since,
          );
        }
        _position = target;
        _lastIndex = sequence.order.indexOf(id);
      }
    }
    _stepStartedMs = _now() - s.stepElapsedMs - since;
    notifyListeners();
  }

  // ------------------------------------------------------------- deck

  void _onBatch(DeckChangeBatch batch) {
    if (_disposed) return;
    sequence.order = model.indexes.order;
    final pending = _pendingRemote;
    if (pending != null && model.slide(pending.slideId) != null) {
      _pendingRemote = null;
      _play(_position, pending, back: false, now: _now());
      _position = pending;
    }
    final p = _position;
    if (p != null && sequence.order.entry(p.slideId) == null) {
      // The shown slide was deleted (here or by a collaborator).
      final n = sequence.nearest(_lastIndex);
      if (n == null) {
        _position = null;
      } else {
        _goto(n);
        return;
      }
    } else if (p != null) {
      final steps = timelineOf(p.slideId).stepCount;
      if (p.step > steps) {
        _position = PresentPosition(p.slideId, steps);
        player.show(p.slideId, steps, now: _now());
      }
      _lastIndex = sequence.order.indexOf(p.slideId);
    }
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    model.removeListener(_onBatch);
    _heartbeat?.cancel();
    _autoTimer?.cancel();
    _prefetchTimer?.cancel();
    unawaited(_linkSub?.cancel());
    link?.removeListener(notifyListeners);
    super.dispose();
  }
}
