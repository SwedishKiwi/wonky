import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/scene.dart' show SlideScene;
import 'package:wonky_slides_core/schema.dart' show BuildCols, SlidesCols;

import '../canvas/slide_canvas_controller.dart';
import '../motion/motion_stage.dart';
import '../motion/player/slide_player.dart';
import 'animate_view.dart';

/// What a canvas preview plays (06 §5.4, §5.5).
enum PreviewKind {
  /// The whole slide from step 0 (with its transition when asked).
  slide,

  /// From the start of a build's step (*Play from selected*).
  fromBuild,

  /// Only some builds (*Preview* of the edited build, auto-preview).
  builds,

  /// The slide's transition from the previous slide (Transition tab).
  transition,

  /// A hovered effect tile on the selected elements (looping).
  effect,
}

/// The editor's animation preview (06 §5.5, §6): plays on the canvas with
/// SL-29's [SlidePlayer] (drawn by `SlidePlaybackStage`), every step after
/// the other with a short pause standing in for the clicks, then returns
/// to the edit frame. Any press, Esc or a change of the slide's builds
/// stops it.
class AnimatePreview extends ChangeNotifier {
  AnimatePreview(this.view);

  final AnimateView view;

  /// Pause between steps (the "click").
  static const stepGap = Duration(milliseconds: 450);

  /// How long the end state stays before the edit frame returns.
  static const holdEnd = Duration(milliseconds: 700);

  DeckModel get _model => view.model;

  SlidePlayback? _playback;
  SlidePlayer? _player;
  String? _slideId;
  PreviewKind? _kind;
  String? _key;
  SlideTimeline? _timeline;
  TransitionSpec? _spec;
  int _step = 0, _lastStep = 0;
  bool _loop = false;
  String _revision = '';
  Timer? _timer;
  final int _origin = clock.now().millisecondsSinceEpoch;

  /// The playback the canvas draws, or null when nothing plays.
  SlidePlayback? get playback => _playback;

  /// Whether a preview runs.
  bool get active => _playback != null;

  /// The previewed slide.
  String? get slideId => _slideId;

  /// What plays.
  PreviewKind? get kind => _kind;

  /// The key of a hovered tile's preview ([playEffect]).
  String? get key => _key;

  /// The step that plays (or played last).
  int get step => _step;

  /// The timeline being played.
  SlideTimeline? get timeline => _timeline;

  int _now() => clock.now().millisecondsSinceEpoch - _origin;

  /// Plays [slideId] from [fromStep] (0 = the whole slide); with
  /// [includeTransition] step 0 is entered from the previous slide.
  void playSlide(
    String slideId, {
    int fromStep = 0,
    bool includeTransition = false,
  }) {
    final t = view.timelineOf(slideId);
    _start(
      slideId,
      fromStep == 0 ? PreviewKind.slide : PreviewKind.fromBuild,
      t,
      fromStep: fromStep.clamp(0, t.stepCount),
      transition: includeTransition && fromStep == 0,
    );
  }

  /// Plays only [buildIds] of [slideId] (each in its own step when it
  /// starts on a click).
  void playBuilds(String slideId, List<String> buildIds) {
    final ids = buildIds.toSet();
    final builds = [
      for (final b in _model.buildsOf(slideId))
        if (ids.contains(b.id)) b,
    ];
    if (builds.isEmpty) return;
    final t = view.compile(
      slideId,
      reduced: view.previewReduced,
      builds: builds,
    );
    _start(slideId, PreviewKind.builds, t);
  }

  /// Plays [effect] of [kind] on [elementIds] of [slideId] in a loop (a
  /// hovered effect tile, 06 §5.3), keyed by [key].
  void playEffect(
    String slideId,
    List<String> elementIds, {
    required SlideBuildKind kind,
    required String effect,
    required String key,
    Map<String, Object?>? params,
  }) {
    if (elementIds.isEmpty) return;
    final builds = <SlideBuildRec>[];
    for (final (i, id) in elementIds.indexed) {
      final spec = BuildEdits.spec(
        elementId: id,
        kind: kind,
        effect: effect,
        params: params,
        // Step 0: plays right away, all elements together.
        trigger: SlideBuildTrigger.withPrevious,
      );
      builds.add(
        SlideBuildRec({
          SlidesCols.id: 'preview:$i',
          SlidesCols.slideId: slideId,
          SlidesCols.elementId: id,
          SlidesCols.kind: spec.kind.name,
          BuildCols.effect: spec.effect,
          SlidesCols.sortKey: 'a$i',
          BuildCols.trigger: spec.trigger.name,
          BuildCols.delayMs: 0,
          BuildCols.durationMs: spec.durationMs,
          BuildCols.easing: spec.easing,
          BuildCols.optionsJson: spec.optionsJson,
        }),
      );
    }
    final t = view.compile(
      slideId,
      reduced: view.previewReduced,
      builds: builds,
    );
    _start(slideId, PreviewKind.effect, t, loop: true, key: key);
  }

  /// Plays the transition into [slideId] from the slide before it ([spec]
  /// instead of the slide's own), then its step 0.
  void playTransition(String slideId, {TransitionSpec? spec}) {
    _spec = spec;
    _start(
      slideId,
      PreviewKind.transition,
      view.timelineOf(slideId),
      transition: true,
      lastStep: 0,
    );
  }

  /// Stops the preview (the edit frame returns).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _listenKeys(false);
    if (_playback == null) return;
    _playback = null;
    _player = null;
    _slideId = null;
    _kind = null;
    _key = null;
    _timeline = null;
    _spec = null;
    notifyListeners();
  }

  /// Stops a preview of [slideId] whose builds changed (06 §11: "The
  /// animations changed"); true when one was stopped.
  bool stopIfChanged() {
    final id = _slideId;
    if (id == null || _kind == PreviewKind.effect) return false;
    if (_model.indexes.revision(id) == _revision) return false;
    stop();
    return true;
  }

  void _start(
    String slideId,
    PreviewKind kind,
    SlideTimeline timeline, {
    int fromStep = 0,
    bool transition = false,
    int? lastStep,
    bool loop = false,
    String? key,
  }) {
    _timer?.cancel();
    if (kind != PreviewKind.transition) _spec = null;
    _slideId = slideId;
    _kind = kind;
    _key = key;
    _loop = loop;
    _timeline = timeline;
    _revision = _model.indexes.revision(slideId);
    _lastStep = lastStep ?? timeline.stepCount;
    final player = SlidePlayer(
      timelineOf: (id) => id == slideId ? timeline : view.timelineOf(id),
      planOf: _planOf,
    );
    _player = player;
    final pb = SlidePlayback(player: player, now: _now);
    _playback = pb;
    // Hover previews end when the pointer leaves the tile instead.
    _listenKeys(kind != PreviewKind.effect);
    _begin(fromStep: fromStep, transition: transition);
  }

  void _begin({int fromStep = 0, bool transition = false}) {
    final player = _player, pb = _playback, slideId = _slideId;
    if (player == null || pb == null || slideId == null) return;
    final now = pb.now();
    final prev = transition ? view.previousSlideOf(slideId) : null;
    _step = fromStep;
    if (fromStep > 0) {
      player
        ..show(slideId, fromStep - 1, now: now)
        ..playStep(fromStep, now: now);
    } else if (prev != null) {
      player.enter(
        slideId,
        now: now,
        fromSlideId: prev,
        fromStep: view.timelineOf(prev).stepCount,
      );
    } else if (transition && _kind == PreviewKind.transition) {
      // The first slide: its transition from a blank slide is not played;
      // show the slide entering from itself.
      player.enter(slideId, now: now, fromSlideId: slideId, fromStep: 0);
    } else {
      player.enter(slideId, now: now);
    }
    pb.changed();
    notifyListeners();
    _schedule();
  }

  void _schedule() {
    final player = _player, pb = _playback;
    if (player == null || pb == null) return;
    final left = player.endMs - pb.now();
    final wait = Duration(milliseconds: left < 0 ? 0 : left);
    _timer = Timer(wait + (_step < _lastStep ? stepGap : holdEnd), _next);
  }

  void _next() {
    final player = _player, pb = _playback;
    if (player == null || pb == null) return;
    // Another slide is shown: the preview ends.
    if (view.editor.currentSlideId != _slideId) {
      stop();
      return;
    }
    if (_step < _lastStep) {
      _step++;
      player.playStep(_step, now: pb.now());
      pb.changed();
      notifyListeners();
      _schedule();
    } else if (_loop) {
      _begin();
    } else {
      stop();
    }
  }

  bool _listening = false;

  static final _modifiers = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  /// While a preview plays any key press stops it (06 §5.5); Esc is
  /// consumed, other keys go on.
  void _listenKeys(bool on) {
    if (on == _listening) return;
    _listening = on;
    if (on) {
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !active) return false;
    final k = e.logicalKey;
    // Modifiers alone (a shortcut being typed) don't stop it.
    if (HardwareKeyboard.instance.logicalKeysPressed.length > 1 ||
        _modifiers.contains(k)) {
      return false;
    }
    stop();
    return k == LogicalKeyboardKey.escape;
  }

  TransitionPlan _planOf(TransitionRequest r) {
    final spec = _spec;
    try {
      if (spec == null) {
        return TransitionCompiler.between(
          _model,
          fromSlideId: r.fromSlideId,
          toSlideId: r.toSlideId,
          fromFrame: r.fromFrame,
          toFrame: r.toFrame,
          options: TransitionOptions(
            reducedMotion: view.previewReduced,
            reverse: r.reverse,
          ),
          fromScene: _sceneOf(r.fromSlideId),
          toScene: _sceneOf(r.toSlideId),
        );
      }
      return planWith(
        view,
        spec,
        fromSlideId: r.fromSlideId,
        toSlideId: r.toSlideId,
        fromFrame: r.fromFrame,
        toFrame: r.toFrame,
      );
    } on Object {
      return TransitionPlan.cut;
    }
  }

  SlideScene? _sceneOf(String slideId) =>
      SlideCanvasController.of(view.editor)?.renderer.scene(slideId);

  /// The plan of [spec] between two slides of the deck (a transition the
  /// slide doesn't have yet: tile previews).
  static TransitionPlan planWith(
    AnimateView view,
    TransitionSpec spec, {
    required String fromSlideId,
    required String toSlideId,
    SlideFrame fromFrame = SlideFrame.edit,
    SlideFrame toFrame = SlideFrame.edit,
  }) {
    final model = view.model;
    final renderer = SlideCanvasController.of(view.editor)?.renderer;
    final magic = spec.type == 'magicMove' && !view.previewReduced;
    return TransitionCompiler.compile(
      from: fromFrame,
      to: toFrame,
      spec: spec,
      options: TransitionOptions(
        slideWidth: model.deck?.width ?? 1920,
        slideHeight: model.deck?.height ?? 1080,
        reducedMotion: view.previewReduced,
        seedKey: toSlideId,
      ),
      fromSlide: magic
          ? MagicMoveSlide.fromDeck(
              model,
              fromSlideId,
              frame: fromFrame,
              scene: renderer?.scene(fromSlideId),
            )
          : null,
      toSlide: magic
          ? MagicMoveSlide.fromDeck(
              model,
              toSlideId,
              frame: toFrame,
              scene: renderer?.scene(toSlideId),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _listenKeys(false);
    super.dispose();
  }
}
