import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_sync_models/ids.dart' show SlidesIds;

import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/text_editing_host.dart';
import 'slides_presence_controller.dart';
import 'slides_presence_cursor.dart';

/// A question of the soft locks to the user (Slides 04 §13.11, 09 §2.1):
/// *"Anna is editing this text."* [Cancel] [Edit anyway], or after a lost
/// claim race *"Anna started editing this text first."* [Stop editing]
/// [Keep editing]. The canvas shows it next to the box, the notes pane in
/// its banner; [answer] completes it.
class SoftLockPrompt {
  SoftLockPrompt({
    required this.target,
    required this.holders,
    this.race = false,
  });

  final TextLockTarget target;

  /// The other participants editing the body.
  final List<RemoteDeckCursor> holders;

  /// A lost simultaneous-entry race (else: entering a claimed body).
  final bool race;

  final Completer<bool> _done = Completer<bool>();

  /// Completes with the answer: true = *Edit anyway* / *Keep editing*.
  Future<bool> get future => _done.future;

  bool get answered => _done.isCompleted;

  void answer(bool proceed) {
    if (!_done.isCompleted) _done.complete(proceed);
  }
}

class _LocalClaim {
  _LocalClaim(this.target, this.claim, this.activity, this.stop);

  final TextLockTarget target;
  EditingClaim claim;
  final Listenable? activity;
  final VoidCallback? stop;
  VoidCallback? listener;
  Timer? idle;

  /// Dropped from the cursor after 60 s without input or a hidden window;
  /// the next input claims again.
  bool dormant = false;

  /// The race prompt was shown for this claim.
  bool raceAsked = false;
}

/// The soft locks of one open deck (Slides 02 §4.4, 09 §2): the
/// [TextEditLocks] of text editing and the speaker notes.
///
/// - **Claims**: editing a body publishes `editing` in the presence cursor
///   ([claim]); it ends on exit, after [idleTimeout] without input, after
///   the window was hidden for [hiddenTimeout] (input claims again), or
///   when the session leaves (the presence roster drops it).
/// - **Entering a claimed body** asks with a [SoftLockPrompt] (*Edit
///   anyway* enters with a forced claim).
/// - **Simultaneous entry**: of two non-forced claims on one body the
///   earlier `since` wins (tie: the smaller session id); the loser is asked
///   *Stop editing* / *Keep editing* (keep = forced).
/// - [heldBy] names the other editors of a body, so formatting whole
///   elements skips it (03 §6.1).
class SlidesSoftLocks extends TextEditLocks
    with ChangeNotifier, WidgetsBindingObserver {
  SlidesSoftLocks(this.editor, this.presence) {
    presence.addListener(_onRemote);
    WidgetsBinding.instance.addObserver(this);
  }

  final DeckEditorController editor;
  final SlidesPresenceController presence;

  /// A claim ends after this long without input (09 §2.1).
  static Duration idleTimeout = const Duration(seconds: 60);

  /// A claim ends when the window stays hidden this long.
  static Duration hiddenTimeout = const Duration(seconds: 30);

  final Map<String, _LocalClaim> _local = {};
  final Set<String> _forceNext = {};
  Timer? _hidden;
  bool _disposed = false;

  /// The question shown to the user, or null.
  final ValueNotifier<SoftLockPrompt?> prompt = ValueNotifier(null);

  @override
  Listenable get changes => this;

  /// The claim published in the presence cursor (the newest active one).
  EditingClaim? get published {
    for (final c in _local.values.toList().reversed) {
      if (!c.dormant) return c.claim;
    }
    return null;
  }

  /// This user's claims (tests, diagnostics).
  List<EditingClaim> get localClaims => [
    for (final c in _local.values) c.claim,
  ];

  // ---------------------------------------------------------------- remote

  /// The other participants holding a claim on [target].
  List<RemoteDeckCursor> holdersOf(TextLockTarget target) => [
    for (final c in presence.cursors)
      if (c.cursor.editing?.target == target) c,
  ];

  /// The other participants editing [elementId] (its text or a cell).
  List<RemoteDeckCursor> holdersOfElement(String elementId) => [
    for (final c in presence.cursors)
      if (c.cursor.editing case final e?
          when e.elementId == elementId &&
              (e.kind == 'text' || e.kind == 'tableCell'))
        c,
  ];

  /// Names of [holders] ("Anna", "Anna, Bo").
  String namesOf(List<RemoteDeckCursor> holders) =>
      holders.map((h) => presence.labelOf(h.participant)).join(', ');

  @override
  String? heldBy(String elementId) {
    final h = holdersOfElement(elementId);
    return h.isEmpty ? null : namesOf(h);
  }

  @override
  String? heldByTarget(TextLockTarget target) {
    final h = target.kind == 'text'
        ? holdersOfElement(target.elementId!)
        : holdersOf(target);
    return h.isEmpty ? null : namesOf(h);
  }

  // -------------------------------------------------------------- requests

  @override
  FutureOr<bool> request(String elementId) =>
      requestTarget(TextLockTarget.element(elementId));

  @override
  FutureOr<bool> requestTarget(TextLockTarget target) {
    if (_forceNext.contains(target.key)) return true;
    final holders = holdersOf(target);
    if (holders.isEmpty) return true;
    return ask(SoftLockPrompt(target: target, holders: holders));
  }

  /// Shows [p] (replacing an unanswered question) and completes with the
  /// answer.
  Future<bool> ask(SoftLockPrompt p) async {
    prompt.value?.answer(false);
    prompt.value = p;
    final yes = await p.future;
    if (identical(prompt.value, p)) prompt.value = null;
    if (yes && !p.race && holdersOf(p.target).isNotEmpty) {
      _forceNext.add(p.target.key);
    }
    return yes;
  }

  /// *Edit anyway* for [target] (`slides.text.editAnyway`): answers its
  /// question, or makes the next claim of [target] a forced one.
  void editAnyway(TextLockTarget target) {
    final p = prompt.value;
    if (p != null && p.target == target && !p.race) {
      p.answer(true);
      return;
    }
    _forceNext.add(target.key);
  }

  // ---------------------------------------------------------------- claims

  @override
  void claim(String elementId) =>
      claimTarget(TextLockTarget.element(elementId));

  @override
  void release(String elementId) =>
      releaseTarget(TextLockTarget.element(elementId));

  @override
  void claimTarget(
    TextLockTarget target, {
    Listenable? activity,
    VoidCallback? stop,
  }) {
    final key = target.key;
    _drop(key);
    final forced = _forceNext.remove(key);
    final c = _LocalClaim(
      target,
      EditingClaim.of(
        target,
        slideId: target.slideId ?? editor.currentSlideId,
        cellId: target.kind == 'tableCell'
            ? SlidesIds.tableCellId(
                target.elementId!,
                target.rowId!,
                target.columnId!,
              )
            : null,
        since: clock.now().millisecondsSinceEpoch,
        forced: forced,
      ),
      activity,
      stop,
    );
    if (activity != null) {
      c.listener = () => _touch(key);
      activity.addListener(c.listener!);
    }
    _local[key] = c;
    _armIdle(c);
    _changed();
    _checkRaces();
  }

  @override
  void releaseTarget(TextLockTarget target) {
    if (!_local.containsKey(target.key)) return;
    _drop(target.key);
    final p = prompt.value;
    if (p != null && p.target == target) p.answer(false);
    _changed();
  }

  void _drop(String key) {
    final c = _local.remove(key);
    if (c == null) return;
    c.idle?.cancel();
    final l = c.listener;
    if (l != null) c.activity?.removeListener(l);
  }

  void _touch(String key) {
    final c = _local[key];
    if (c == null || _disposed) return;
    _armIdle(c);
    if (c.dormant) {
      // Input after idling claims again (a new claim start).
      c.dormant = false;
      c.raceAsked = false;
      c.claim = c.claim.copyWith(since: clock.now().millisecondsSinceEpoch);
      _changed();
      _checkRaces();
    }
  }

  void _armIdle(_LocalClaim c) {
    c.idle?.cancel();
    c.idle = Timer(idleTimeout, () {
      if (_disposed || c.dormant) return;
      c.dormant = true;
      _changed();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _hidden?.cancel();
        _hidden = null;
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _hidden ??= Timer(hiddenTimeout, () {
          _hidden = null;
          if (_disposed) return;
          for (final c in _local.values) {
            c.dormant = true;
          }
          _changed();
        });
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  // ----------------------------------------------------------------- races

  void _onRemote() {
    if (_disposed) return;
    final p = prompt.value;
    // A question about a body nobody else edits any more resolves itself.
    if (p != null && !p.race && holdersOf(p.target).isEmpty) {
      p.answer(true);
    }
    _checkRaces();
    notifyListeners();
  }

  /// Whether the remote claim [other] (of session [sessionId]) wins against
  /// [mine] (09 §2.1: earlier `since`; tie: smaller session id).
  static bool beats(
    EditingClaim other,
    String sessionId,
    EditingClaim mine,
    String? selfSessionId,
  ) {
    if (other.forced || mine.forced) return false;
    if (other.since != mine.since) return other.since < mine.since;
    return selfSessionId != null && sessionId.compareTo(selfSessionId) < 0;
  }

  void _checkRaces() {
    final self = presence.selfSessionId;
    for (final c in _local.values.toList()) {
      if (c.dormant || c.raceAsked || c.claim.forced) continue;
      final winners = [
        for (final h in holdersOf(c.target))
          if (beats(h.cursor.editing!, h.sessionId, c.claim, self)) h,
      ];
      if (winners.isEmpty) continue;
      c.raceAsked = true;
      unawaited(_race(c, winners));
    }
  }

  Future<void> _race(_LocalClaim c, List<RemoteDeckCursor> winners) async {
    final keep = await ask(
      SoftLockPrompt(target: c.target, holders: winners, race: true),
    );
    if (_disposed || !identical(_local[c.target.key], c)) return;
    if (keep) {
      c.claim = c.claim.copyWith(forced: true);
      _changed();
    } else {
      c.stop?.call();
    }
  }

  void _changed() {
    if (_disposed) return;
    presence.publish();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    presence.removeListener(_onRemote);
    _hidden?.cancel();
    for (final k in _local.keys.toList()) {
      _drop(k);
    }
    prompt.value?.answer(false);
    prompt.dispose();
    super.dispose();
  }
}
