import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show Participant, PresenceState;
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../l10n/slides_l10n.dart';
import '../canvas/canvas_controller.dart';
import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../editor_screen/slide_labels.dart';
import 'slides_presence_cursor.dart';

/// A remote participant's Slides cursor.
@immutable
class RemoteDeckCursor {
  const RemoteDeckCursor({
    required this.participant,
    required this.cursor,
    required this.movedAt,
  });

  final Participant participant;
  final SlidesPresenceCursor cursor;

  /// When their slide or selection last changed (the name flag shows for
  /// 3 s, 09 §1.2).
  final DateTime movedAt;

  String get sessionId => participant.sessionId;
  int get colorIndex => participant.colorIndex;
  String get displayName => participant.displayName;
  bool get isAgent => participant.actorKind.name != 'user';

  /// Away and offline participants are not drawn (09 §1.2).
  bool get isAway =>
      participant.state == PresenceState.away ||
      participant.state == PresenceState.offline;

  /// The slide they are on (the presented slide while presenting).
  String? get slideId => cursor.presenting?.slideId ?? cursor.slideId;
}

/// Slides presence (Slides 09 §1): publishes the local editor state as the
/// Slides `PresenceCursor` JSON through the shell's [PresenceSession]
/// (current slide, selection, navigator selection, the soft-lock claim of
/// [claimOf], presenting, the viewport while followed); maps the other
/// participants' cursors for the canvas (selection outlines, name flags),
/// the navigator and grid dots and the avatar tooltips; jump-to, follow
/// mode and following a presenter.
class SlidesPresenceController extends ChangeNotifier {
  SlidesPresenceController(this.editor, {required this.claimOf}) {
    editor.addListener(_onLocal);
  }

  final DeckEditorController editor;

  /// The local soft-lock claim (the soft locks).
  final EditingClaim? Function() claimOf;

  /// How long a selection name flag stays after the selection changed.
  static const flagDuration = Duration(seconds: 3);

  /// Viewport updates while followed (2/s, 09 §1.5).
  static const viewportInterval = Duration(milliseconds: 500);

  PresenceSession? _presence;
  String? _sent;
  final Map<String, RemoteDeckCursor> _cursors = {};
  List<RemoteDeckCursor> _list = const [];

  /// The session followed (09 §1.5), or null.
  final ValueNotifier<String?> following = ValueNotifier(null);

  /// The session whose selection flashes after a jump, and whether it is
  /// lit (09 §1.3: twice).
  String? flashSession;
  bool flashOn = false;
  Timer? _flash;
  Timer? _flagTimer;
  Timer? _viewportTimer;
  bool _applying = false;
  bool _disposed = false;
  PresentingState? _presenting;
  bool _transform = false;
  CanvasController? _viewport;
  SlideCanvasController? _canvas;

  PresenceSession? get presence => _presence;

  String? get selfSessionId => _presence?.sessionId;

  /// The other participants with a Slides cursor, in joining order.
  List<RemoteDeckCursor> get cursors => _list;

  /// Attaches the shell's presence session (null detaches).
  void attach(PresenceSession? presence) {
    if (identical(presence, _presence)) return;
    _presence?.removeListener(_onRemote);
    if (_presence?.detailOf == _detailOf) _presence?.detailOf = null;
    _presence = presence;
    _sent = null;
    if (presence != null) {
      presence.addListener(_onRemote);
      presence.detailOf = _detailOf;
      _onRemote();
    } else {
      _cursors.clear();
      _emit();
    }
  }

  // ---------------------------------------------------------------- outgoing

  /// The local state as a cursor.
  SlidesPresenceCursor localCursor({bool withViewport = false}) {
    final presenting = _presenting;
    return SlidesPresenceCursor(
      route: presenting != null ? 'present' : 'editor',
      viewMode: editor.mode.name,
      slideId: editor.currentSlideId,
      selection: editor.selectedElementIds,
      navSlides: [...editor.selectedSlideIds],
      navGroups: [...editor.selectedGroupIds],
      editing: claimOf(),
      transform: _transform,
      viewport: withViewport ? _localViewport() : null,
      presenting: presenting,
      following: following.value,
    );
  }

  DeckViewport? _localViewport() {
    final slide = editor.currentSlideId;
    final v = _viewport;
    if (slide == null) return null;
    if (v == null || v.viewport.isEmpty) {
      return DeckViewport(slideId: slide, cx: 960, cy: 540);
    }
    final c = v.toSlide(v.viewport.center(Offset.zero));
    return DeckViewport(
      slideId: slide,
      zoom: editor.zoomFit ? null : editor.zoom,
      cx: c.dx,
      cy: c.dy,
    );
  }

  bool get _followed => (_presence?.followerCount ?? 0) > 0;

  /// Publishes the cursor when it changed (the presence session throttles
  /// to 10/s).
  void publish() {
    final p = _presence;
    if (p == null || _disposed) return;
    final json = localCursor(withViewport: _followed).encode();
    if (json == _sent) return;
    _sent = json;
    p.updateCursor(json);
  }

  /// Sets the presenting state (null: not presenting; 09 §1.6).
  set presenting(PresentingState? value) {
    if (value == _presenting) return;
    _presenting = value;
    publish();
  }

  PresentingState? get presenting => _presenting;

  /// Whether a drag is live (09 §1.1 `transform`).
  set transforming(bool value) {
    if (value == _transform) return;
    _transform = value;
    publish();
  }

  ({String? slide, List<String> selection, double zoom, bool fit, String mode})?
  _last;

  ({String? slide, List<String> selection, double zoom, bool fit, String mode})
  _snapshot() => (
    slide: editor.currentSlideId,
    selection: editor.selectedElementIds,
    zoom: editor.zoom,
    fit: editor.zoomFit,
    mode: editor.mode.name,
  );

  void _onLocal() {
    if (_disposed) return;
    _bindCanvas();
    final now = _snapshot();
    final last = _last;
    if (!_applying && following.value != null && last != null) {
      // Local navigation, selection, zoom or view mode stops following.
      if (last.slide != now.slide ||
          !listEquals(last.selection, now.selection) ||
          last.fit != now.fit ||
          (!now.fit && last.zoom != now.zoom) ||
          last.mode != now.mode) {
        unfollow();
      }
    }
    _last = now;
    publish();
  }

  /// Follows the canvas of the editor once it is attached (viewport for
  /// follow mode, live drags).
  void _bindCanvas() {
    final c = SlideCanvasController.of(editor);
    if (identical(c, _canvas)) return;
    _viewport?.removeListener(_onViewport);
    _canvas?.removeListener(_onCanvas);
    _canvas = c;
    _viewport = c?.viewport;
    _viewport?.addListener(_onViewport);
    c?.addListener(_onCanvas);
  }

  Offset? _followPan;

  void _onViewport() {
    if (_disposed) return;
    final v = _viewport;
    final f = _followPan;
    if (!_applying && following.value != null && v != null && f != null) {
      if ((v.pan - f).distance > 2) unfollow();
    }
    if (_followed && !(_viewportTimer?.isActive ?? false)) {
      _viewportTimer = Timer(viewportInterval, publish);
    }
  }

  void _onCanvas() {
    if (_disposed) return;
    final t = _canvas?.transform;
    transforming = t != null && t.changed;
  }

  // ---------------------------------------------------------------- incoming

  void _onRemote() {
    final p = _presence;
    if (p == null || _disposed) return;
    _bindCanvas();
    final self = p.sessionId;
    final now = clock.now();
    final seen = <String>{};
    for (final part in p.participants) {
      if (part.sessionId == self) continue;
      final cursor = SlidesPresenceCursor.tryParse(part.cursorJson);
      if (cursor == null) continue;
      seen.add(part.sessionId);
      final before = _cursors[part.sessionId];
      final moved =
          before == null ||
          before.cursor.slideId != cursor.slideId ||
          !listEquals(before.cursor.selection, cursor.selection);
      _cursors[part.sessionId] = RemoteDeckCursor(
        participant: part,
        cursor: cursor,
        movedAt: moved ? now : before.movedAt,
      );
      if (part.sessionId == following.value) _applyFollow(cursor);
    }
    _cursors.removeWhere((k, _) => !seen.contains(k));
    final f = following.value;
    if (f != null && !_cursors.containsKey(f)) unfollow();
    // The viewport is sent only while followed; the count may have changed.
    publish();
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    _list = _cursors.values.toList()
      ..sort(
        (a, b) => a.participant.joinedAt.compareTo(b.participant.joinedAt),
      );
    _scheduleFlagExpiry();
    notifyListeners();
  }

  void _scheduleFlagExpiry() {
    _flagTimer?.cancel();
    final now = clock.now();
    Duration? next;
    for (final c in _cursors.values) {
      final left = c.movedAt.add(flagDuration).difference(now);
      if (left > Duration.zero && (next == null || left < next)) next = left;
    }
    if (next != null) {
      _flagTimer = Timer(next + const Duration(milliseconds: 20), () {
        if (!_disposed) notifyListeners();
      });
    }
  }

  /// The cursors drawn on the canvas of [slideId]: editing that slide,
  /// not away, not presenting.
  List<RemoteDeckCursor> cursorsOn(String slideId) => [
    for (final c in _list)
      if (c.cursor.slideId == slideId &&
          c.cursor.route == 'editor' &&
          !c.isAway)
        c,
  ];

  /// Participants per slide (navigator and grid dots; presenters on their
  /// presented slide).
  Map<String, List<RemoteDeckCursor>> get bySlide {
    final out = <String, List<RemoteDeckCursor>>{};
    for (final c in _list) {
      final s = c.slideId;
      if (s == null || c.isAway) continue;
      out.putIfAbsent(s, () => []).add(c);
    }
    return out;
  }

  /// The participants presenting (09 §1.6).
  List<RemoteDeckCursor> get presenters => [
    for (final c in _list)
      if (c.cursor.presenting != null && !c.isAway) c,
  ];

  /// Whether the selection name flag of [c] shows (3 s after it changed,
  /// while flashing, while one of its elements is [hovered]).
  bool flagVisible(RemoteDeckCursor c, DateTime now, {String? hovered}) =>
      now.difference(c.movedAt) < flagDuration ||
      c.sessionId == flashSession ||
      (hovered != null && c.cursor.selection.contains(hovered));

  /// The display label of a participant: agents (MCP/AI writes) show as
  /// "Claude via MCP (Anna)" / "Assistant (Anna)".
  String labelOf(Participant p) {
    final l = slidesL10nOf(editor.services);
    return switch (p.actorKind.name) {
      'mcp' => l.actorViaMcp(p.displayName),
      'ai' => l.actorViaAi(p.displayName),
      _ => p.displayName,
    };
  }

  /// "Editing slide 4 · Intro" (avatar tooltips, 09 §1.2).
  String? _detailOf(Participant p) {
    if (p.sessionId == selfSessionId) return null;
    if (p.state == PresenceState.idle ||
        p.state == PresenceState.away ||
        p.state == PresenceState.offline) {
      return null;
    }
    final c = SlidesPresenceCursor.tryParse(p.cursorJson);
    if (c == null) return null;
    final l = slidesL10nOf(editor.services);
    String? detail;
    if (c.isPresenting) {
      detail = l.presencePresenting;
    } else if (c.viewMode == 'masters') {
      detail = l.presenceEditingLayouts;
    } else {
      final id = c.slideId;
      final entry = id == null ? null : editor.order.entry(id);
      if (entry != null) {
        final title = SlideLabels.title(editor.model, entry.id);
        final name = title.isEmpty ? l.slideUntitled : title;
        detail = p.mode == 'viewing'
            ? l.presenceViewingSlide(entry.index + 1, name)
            : l.presenceEditingSlide(entry.index + 1, name);
      }
    }
    if (c.following != null && c.following == selfSessionId) {
      return detail == null
          ? l.presenceFollowingYou
          : '$detail · ${l.presenceFollowingYou}';
    }
    return detail;
  }

  /// The detail line of [sessionId] (tests, MCP state).
  String? detailOf(String sessionId) {
    final c = _cursors[sessionId];
    return c == null ? null : _detailOf(c.participant);
  }

  // ------------------------------------------------------------ jump/follow

  RemoteDeckCursor? cursorOf(String sessionId) => _cursors[sessionId];

  /// Switches to the participant's slide and view mode, scrolls their
  /// selection into view and flashes it twice (09 §1.3). The local
  /// element selection is not changed (beyond the slide switch).
  bool jumpTo(String sessionId) {
    final c = _cursors[sessionId];
    final slide = c?.slideId;
    if (c == null || slide == null || editor.order.entry(slide) == null) {
      return false;
    }
    _apply(() {
      final mode = DeckViewMode.fromName(c.cursor.viewMode);
      if (mode == DeckViewMode.normal || mode == DeckViewMode.grid) {
        editor.setMode(mode!);
      }
      if (editor.currentSlideId != slide) editor.setCurrentSlide(slide);
      final box = _boundsOf(c.cursor.selection);
      if (box != null) _viewport?.reveal(box);
    });
    _startFlash(sessionId);
    return true;
  }

  SuRect? _boundsOf(List<String> ids) {
    final canvas = SlideCanvasController.of(editor);
    if (canvas == null) return null;
    SuRect? out;
    for (final id in ids) {
      final f = canvas.frameOf(id)?.bounds;
      if (f == null) continue;
      out = out == null
          ? f
          : () {
              final x = math.min(out!.x, f.x), y = math.min(out.y, f.y);
              return SuRect(
                x,
                y,
                math.max(out.x + out.width, f.x + f.width) - x,
                math.max(out.y + out.height, f.y + f.height) - y,
              );
            }();
    }
    return out;
  }

  void _startFlash(String sessionId) {
    _flash?.cancel();
    flashSession = sessionId;
    var ticks = 0;
    flashOn = true;
    notifyListeners();
    _flash = Timer.periodic(const Duration(milliseconds: 250), (t) {
      ticks++;
      flashOn = !flashOn;
      if (ticks >= 4) {
        t.cancel();
        flashSession = null;
        flashOn = false;
      }
      if (!_disposed) notifyListeners();
    });
  }

  /// Follows [sessionId] (09 §1.5): their slide and view mode, and their
  /// zoom and center on the same slide, until local interaction.
  bool follow(String sessionId) {
    if (sessionId == selfSessionId || !_cursors.containsKey(sessionId)) {
      return false;
    }
    following.value = sessionId;
    _presence?.follow(sessionId);
    HardwareKeyboard.instance.addHandler(_onKey);
    _applyFollow(_cursors[sessionId]!.cursor);
    publish();
    notifyListeners();
    return true;
  }

  /// Stops following.
  void unfollow() {
    if (following.value == null) return;
    following.value = null;
    _followPan = null;
    _presence?.follow(null);
    HardwareKeyboard.instance.removeHandler(_onKey);
    publish();
    if (!_disposed) notifyListeners();
  }

  /// The participant followed, or null.
  RemoteDeckCursor? get followed {
    final f = following.value;
    return f == null ? null : _cursors[f];
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      unfollow();
    }
    return false;
  }

  void _apply(void Function() f) {
    _applying = true;
    try {
      f();
    } finally {
      _applying = false;
      _last = _snapshot();
    }
  }

  void _applyFollow(SlidesPresenceCursor c) {
    _apply(() {
      final mode = DeckViewMode.fromName(c.viewMode);
      if (mode == DeckViewMode.normal || mode == DeckViewMode.grid) {
        editor.setMode(mode!);
      }
      final slide = c.presenting?.slideId ?? c.slideId;
      if (slide != null &&
          slide != editor.currentSlideId &&
          editor.order.entry(slide) != null) {
        editor.setCurrentSlide(slide);
      }
      final v = c.viewport;
      final vp = _viewport;
      if (v != null && v.slideId == editor.currentSlideId) {
        final z = v.zoom;
        if (z == null) {
          editor.setZoomFit();
        } else {
          editor.setZoom(z);
          if (vp != null && !vp.viewport.isEmpty) {
            final size = vp.slideSize;
            final want = -(Offset(v.cx, v.cy) - size.center(Offset.zero)) * z;
            vp.panBy(want - vp.pan);
          }
        }
      }
    });
    _followPan = _viewport?.pan;
  }

  @override
  void dispose() {
    _disposed = true;
    HardwareKeyboard.instance.removeHandler(_onKey);
    editor.removeListener(_onLocal);
    _viewport?.removeListener(_onViewport);
    _canvas?.removeListener(_onCanvas);
    _presence?.removeListener(_onRemote);
    if (_presence?.detailOf == _detailOf) _presence?.detailOf = null;
    _flash?.cancel();
    _flagTimer?.cancel();
    _viewportTimer?.cancel();
    following.dispose();
    super.dispose();
  }
}
