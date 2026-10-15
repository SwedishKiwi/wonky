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
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';

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
  audience;

  static PresentView fromName(String? name) => switch (name) {
    'presenter' => presenter,
    'audience' || 'follow' => audience,
    _ => present,
  };
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
  }) : _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _inkPrefix = inkPrefix ?? _randomPrefix() {
    timer = PresentTimer(_now);
    sequence = PresentSequence(
      model.indexes.order,
      timelineOf: timelineOf ?? _compile,
      showSkipped: showSkipped,
    );
    if (view != PresentView.audience) {
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

  SlideTimeline _compile(String slideId) {
    final rev = model.indexes.revision(slideId);
    final hit = _timelines[slideId];
    if (hit != null && hit.$1 == rev) return hit.$2;
    final slide = model.slide(slideId);
    final t = slide == null
        ? SlideTimeline(slideId: slideId)
        : SlideTimelineCompiler.compile(
            SlideMotionInput(slide: slide, builds: model.buildsOf(slideId)),
          );
    _timelines[slideId] = (rev, t);
    return t;
  }

  /// The timeline of [slideId].
  SlideTimeline timelineOf(String slideId) => sequence.timelineOf(slideId);

  // ------------------------------------------------------------ position

  PresentPosition? _position;
  int _lastIndex = 0;
  int _stepStartedMs = 0;
  bool _stepFinished = false;

  /// The shown slide and step (null in an empty deck, or while an audience
  /// waits for the presenter).
  PresentPosition? get position => _position;

  /// The shown frame: the settled end of the current step (06 §9). Running
  /// builds are drawn by SL-29's player.
  SlideFrame get frame {
    final p = _position;
    if (p == null) return SlideFrame.edit;
    return timelineOf(p.slideId).endOfStep(p.step);
  }

  /// Milliseconds since the current step started.
  int get stepElapsedMs => math.max(0, _now() - _stepStartedMs);

  /// Whether the current step's builds are still running (a *Next*
  /// finishes them first, 10 §2.1).
  bool get stepRunning {
    final p = _position;
    if (p == null || _stepFinished) return false;
    final t = timelineOf(p.slideId);
    if (p.step >= t.steps.length) return false;
    return stepElapsedMs < t.steps[p.step].durationMs;
  }

  /// The end screen (10 §1.5).
  bool get endScreen => _endScreen;
  bool _endScreen = false;

  /// The audience waits for the presenter's slide to arrive by sync
  /// ("Catching up…", 10 §6.2).
  bool get catchingUp => _pendingRemote != null;
  PresentPosition? _pendingRemote;

  /// Whether this view only mirrors the presenter (navigation becomes
  /// commands to the presenter).
  bool get mirrors => view == PresentView.audience;

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
    final now = _now();
    if (now - _lastInput < burstMs) return false;
    _lastInput = now;
    return true;
  }

  void _goto(PresentPosition p) {
    _position = p;
    _lastIndex = sequence.order.indexOf(p.slideId);
    _stepStartedMs = _now();
    _stepFinished = false;
    _endScreen = false;
    _blank = PresentBlank.none;
    _laser = null;
    if (!timer.started) timer.start();
    _changed();
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
    if (mirrors) return _command('next');
    if (_unblank()) return true;
    if (_endScreen) {
      if (settings.loops) return _restart();
      end();
      return true;
    }
    final p = _position;
    if (p == null) return false;
    if (stepRunning) {
      _stepFinished = true;
      if (settings.advanceDuringBuild != 'skip') {
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
    if (settings.loops) return _restart();
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
    _goto(n);
    return true;
  }

  /// The next slide, skipping the remaining builds.
  bool nextSlide({bool user = true}) {
    if (!_accept(user)) return false;
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
    if (mirrors) return _command('previousSlide');
    if (_unblank()) return true;
    if (_endScreen) return previous(user: false);
    final p = _position;
    if (p == null) return false;
    final n = sequence.previousSlide(p);
    if (n == null) return false;
    _goto(n);
    return true;
  }

  bool first() {
    if (mirrors) return _command('first');
    final f = sequence.first();
    if (f == null) return false;
    _goto(f);
    return true;
  }

  bool last() {
    if (mirrors) return _command('last');
    final f = sequence.last();
    if (f == null) return false;
    _goto(f);
    return true;
  }

  /// Shows [slideId] at [step] — skipped slides too (picker, *Go to
  /// slide*, the strip; 10 §2.2).
  bool goTo(String slideId, [int step = 0]) {
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
    if (p == null || mirrors) return;
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
    if (p == null || mirrors) return;
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
      view != PresentView.audience &&
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
        if (view == PresentView.audience) {
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
        if (view == PresentView.audience) {
          applyState(e.state, sentAtMs: e.serverTimeMs);
        }
      case PresentationLaserEvent():
        if (view != PresentView.audience) return;
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
        if (view != PresentView.audience) return;
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
        if (view == PresentView.audience) return;
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
        if (target != _position) _laser = null;
        _position = target;
        _lastIndex = sequence.order.indexOf(id);
      }
    }
    _stepStartedMs = _now() - s.stepElapsedMs - since;
    _stepFinished = false;
    notifyListeners();
  }

  // ------------------------------------------------------------- deck

  void _onBatch(DeckChangeBatch batch) {
    if (_disposed) return;
    sequence.order = model.indexes.order;
    final pending = _pendingRemote;
    if (pending != null && model.slide(pending.slideId) != null) {
      _pendingRemote = null;
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
      if (p.step > steps) _position = PresentPosition(p.slideId, steps);
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
    unawaited(_linkSub?.cancel());
    link?.removeListener(notifyListeners);
    super.dispose();
  }
}
