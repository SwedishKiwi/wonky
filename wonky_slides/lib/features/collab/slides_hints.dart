import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart' show PresenceSession;
import 'package:wonky_client/wonky_client.dart' show PresenceHints;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesCols;
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/text_editing_host.dart';
import 'slides_presence_controller.dart';

/// A collaborator's text being typed (09 §2.4 `text` hint).
@immutable
class TextHint {
  const TextHint({
    required this.sessionId,
    required this.elementId,
    required this.json,
    required this.hlcMillis,
    required this.at,
  });

  final String sessionId;
  final String elementId;

  /// The body (Delta JSON) shown in place of the stored text.
  final String json;
  final int hlcMillis;
  final DateTime at;
}

/// A collaborator's live drag (09 §2.4 `transform` hint, P1).
@immutable
class TransformHint {
  const TransformHint({
    required this.sessionId,
    required this.slideId,
    required this.frames,
    required this.at,
  });

  final String sessionId;
  final String slideId;
  final Map<String, ElementFrame> frames;
  final DateTime at;
}

/// Ephemeral hints on the presence stream (Slides 09 §2.4, A-09-2): never
/// persisted, never echoed to the sender; the synced rows stay the truth.
///
/// Sender: while this user types in a text body, the body is sent as a
/// `text` hint (≤ 4/s, ≤ 16 KB — larger bodies send no hint); while
/// dragging, the live frames as `transform` hints (≤ 10/s).
///
/// Receiver (`SlidesHintOverlay`): a text hint is drawn in place of the
/// stored body (same styles, [hintedScene]) until the synced text equals
/// it, the sender's claim ended + [textLinger], or this user edits the
/// body; transform hints outline the moving elements in the mover's color
/// until the synced write of one of them or [transformLifetime].
class SlidesHints extends ChangeNotifier {
  SlidesHints(this.editor, this.presence) {
    _host = textEditingOf(editor)..addListener(_onHost);
    editor.session.model.addListener(_onBatch);
  }

  final DeckEditorController editor;
  final SlidesPresenceController presence;
  late final SlideTextEditing _host;

  /// Text hints are sent at most this often (4/s).
  static const textInterval = Duration(milliseconds: 250);

  /// Transform hints are sent at most this often (10/s).
  static const transformInterval = Duration(milliseconds: 100);

  /// Largest text hint sent (09 §2.4).
  static const maxTextBytes = 16 * 1024;

  /// A text hint stays this long after the sender's claim ended.
  static const textLinger = Duration(seconds: 5);

  /// A text hint without updates and without a claim is dropped after this.
  static const textLifetime = Duration(seconds: 30);

  /// A transform hint without updates is dropped after this.
  static const transformLifetime = Duration(seconds: 2);

  /// The navigator shimmer of a structure hint (09 §2.4).
  static const structureShimmer = Duration(seconds: 1);

  /// Hinted slides and groups not synced yet shimmer when their rows
  /// arrive within this time.
  static const structureWait = Duration(seconds: 10);

  /// Ids sent per structure hint.
  static const maxStructureIds = 200;

  PresenceSession? _session;
  StreamSubscription<PresenceHints>? _sub;
  bool _disposed = false;

  /// Text hints by element id.
  final Map<String, TextHint> text = {};

  /// Transform hints by session id.
  final Map<String, TransformHint> transforms = {};

  /// When a structure hint (or the arrival of its hinted rows) started the
  /// shimmer of a slide or group, by id.
  final Map<String, DateTime> structure = {};

  /// Hinted ids whose rows haven't arrived yet, with the hint time.
  final Map<String, DateTime> _structurePending = {};

  /// When a sender's claim on an element was last seen (linger).
  final Map<String, DateTime> _claimSeen = {};

  /// Changes of the hinted texts (scene memo key).
  int _textVersion = 0;
  Timer? _expiry;

  /// Sent hint messages (tests, diagnostics).
  int sent = 0;

  /// Attaches the shell's presence session (null detaches).
  void attach(PresenceSession? session) {
    if (identical(session, _session)) return;
    unawaited(_sub?.cancel());
    _session = session;
    _sub = session?.hints.listen(_onHints);
    _canvas = null;
    _bindCanvas();
  }

  // ------------------------------------------------------------------ send

  Timer? _textTimer;
  String? _textSent;

  /// Typing outside the canvas text editor (the outline view, 04 §10):
  /// the element, its slide and the body's Delta JSON, sent with the next
  /// text hint.
  ({String elementId, String? slideId, String json})? _typed;

  void _onHost() {
    if (_disposed) return;
    final c = _host.active;
    if (c != null && text.remove(c.elementId) != null) _textChanged();
    // Only typing is hinted (not the start of editing, caret moves or the
    // state after the idle write).
    if (_session == null ||
        !editor.roleCanEdit ||
        c == null ||
        c.isCell ||
        !c.hasPendingEdits) {
      return;
    }
    _typed = null;
    _scheduleText();
  }

  /// Hints typing into [elementId]'s body outside the canvas text editor
  /// (the outline view): [json] is the whole body as it would be written.
  void typing(String elementId, String? slideId, String json) {
    if (_disposed || _session == null || !editor.roleCanEdit) return;
    if (text.remove(elementId) != null) {
      _textChanged();
      notifyListeners();
    }
    _typed = (elementId: elementId, slideId: slideId, json: json);
    _scheduleText();
  }

  void _scheduleText() {
    if (_textTimer?.isActive ?? false) return;
    _sendText();
    _textTimer = Timer(textInterval, _sendText);
  }

  void _sendText() {
    final p = _session;
    if (_disposed || p == null) return;
    final c = _host.active;
    final typed = _typed;
    final String elementId;
    final String? slideId;
    final String json;
    if (typed != null) {
      (:elementId, :slideId, :json) = typed;
    } else if (c != null && !c.isCell) {
      elementId = c.elementId;
      slideId = c.slideId;
      json = c.json;
    } else {
      return;
    }
    final key = '$elementId|$json';
    if (key == _textSent) return;
    _textSent = key;
    Object? delta;
    try {
      delta = jsonDecode(json);
    } on FormatException {
      return;
    }
    final hint = jsonEncode({
      't': 'text',
      'target': {'kind': 'text', 'elementId': elementId, 'slideId': slideId},
      'delta': delta,
      'diff': null,
      'hlcMillis': clock.now().millisecondsSinceEpoch,
    });
    if (utf8.encode(hint).length > maxTextBytes) return;
    sent++;
    p.sendHints([hint]);
  }

  SlideCanvasController? _canvas;
  Timer? _transformTimer;
  String? _transformSent;

  void _bindCanvas() {
    final c = SlideCanvasController.of(editor);
    if (identical(c, _canvas)) return;
    _canvas?.removeListener(_onCanvas);
    _canvas = c;
    c?.addListener(_onCanvas);
  }

  void _onCanvas() {
    if (_disposed || _session == null || !editor.roleCanEdit) return;
    final t = _canvas?.transform;
    if (t == null || !t.changed) {
      _transformSent = null;
      return;
    }
    if (_transformTimer?.isActive ?? false) return;
    _sendTransform();
    _transformTimer = Timer(transformInterval, _sendTransform);
  }

  void _sendTransform() {
    final p = _session;
    final t = _canvas?.transform;
    final slide = editor.surfaceId;
    if (_disposed || p == null || t == null || !t.changed || slide == null) {
      return;
    }
    double r(double v) => (v * 10).roundToDouble() / 10;
    final hint = jsonEncode({
      't': 'transform',
      'slideId': slide,
      'frames': {
        for (final MapEntry(:key, :value) in t.liveFrames.entries)
          key: [
            r(value.x),
            r(value.y),
            r(value.width),
            r(value.height),
            r(value.rotation),
          ],
      },
    });
    if (hint == _transformSent) return;
    _transformSent = hint;
    sent++;
    p.sendHints([hint]);
  }

  // --------------------------------------------------------------- receive

  void _onHints(PresenceHints e) {
    if (_disposed || e.sessionId == presence.selfSessionId) return;
    var changed = false;
    for (final raw in e.hints) {
      Object? h;
      try {
        h = jsonDecode(raw);
      } on FormatException {
        continue;
      }
      if (h is! Map) continue;
      switch (h['t']) {
        case 'text':
          changed = _receiveText(e.sessionId, h) || changed;
        case 'transform':
          changed = _receiveTransform(e.sessionId, h) || changed;
        case 'structure':
          changed = _receiveStructure(h) || changed;
      }
    }
    if (changed) {
      _scheduleExpiry();
      notifyListeners();
    }
  }

  bool _receiveText(String sessionId, Map<Object?, Object?> h) {
    final target = h['target'];
    if (target is! Map || target['kind'] != 'text') return false;
    final id = target['elementId'];
    final delta = h['delta'];
    if (id is! String || delta == null) return false;
    final element = editor.model.element(id);
    // Unknown ids wait for their rows; the local edit wins (09 §2.4).
    if (element == null || _host.elementId == id) return false;
    final json = jsonEncode(delta);
    if (_sameText(element.text, json)) {
      return text.remove(id) != null && _textChanged();
    }
    final hlc = h['hlcMillis'];
    text[id] = TextHint(
      sessionId: sessionId,
      elementId: id,
      json: json,
      hlcMillis: hlc is num ? hlc.toInt() : 0,
      at: clock.now(),
    );
    _claimSeen['$sessionId|$id'] = clock.now();
    return _textChanged();
  }

  bool _receiveTransform(String sessionId, Map<Object?, Object?> h) {
    final slide = h['slideId'];
    final frames = h['frames'];
    if (slide is! String || frames is! Map) return false;
    final out = <String, ElementFrame>{};
    for (final MapEntry(:key, :value) in frames.entries) {
      if (key is! String || value is! List || value.length < 4) continue;
      final v = [for (final x in value) x is num ? x.toDouble() : 0.0];
      out[key] = ElementFrame(
        v[0],
        v[1],
        v[2],
        v[3],
        rotation: v.length > 4 ? v[4] : 0,
      );
    }
    if (out.isEmpty) return transforms.remove(sessionId) != null;
    transforms[sessionId] = TransformHint(
      sessionId: sessionId,
      slideId: slide,
      frames: out,
      at: clock.now(),
    );
    return true;
  }

  bool _receiveStructure(Map<Object?, Object?> h) {
    final now = clock.now();
    var changed = false;
    for (final key in const ['slideIds', 'groupIds']) {
      final ids = h[key];
      if (ids is! List) continue;
      for (final id in ids.take(maxStructureIds)) {
        if (id is! String) continue;
        final known = key == 'slideIds'
            ? editor.model.slide(id) != null
            : editor.model.group(id) != null;
        if (known) {
          structure[id] = now;
          changed = true;
        } else {
          _structurePending[id] = now;
          _scheduleExpiry();
        }
      }
    }
    return changed;
  }

  /// When the shimmer of slide or group [id] started (null: none running).
  DateTime? shimmerOf(String id) {
    final at = structure[id];
    if (at == null || clock.now().difference(at) >= structureShimmer) {
      return null;
    }
    return at;
  }

  void _sendStructure(OrderChanged ev) {
    final p = _session;
    if (p == null || !editor.roleCanEdit) return;
    final slides = ev.slideIds.take(maxStructureIds).toList();
    final groups = ev.groupIds.take(maxStructureIds).toList();
    if (slides.isEmpty && groups.isEmpty) return;
    sent++;
    p.sendHints([
      jsonEncode({
        't': 'structure',
        'slideIds': slides,
        'groupIds': groups,
        'hlcMillis': clock.now().millisecondsSinceEpoch,
      }),
    ]);
  }

  bool _textChanged() {
    _textVersion++;
    SlideCanvasController.of(editor)?.refresh();
    return true;
  }

  /// Whether two bodies are the same text (Delta JSON, compared parsed).
  static bool _sameText(String? stored, String hinted) {
    if (stored == null) return false;
    if (stored == hinted) return true;
    try {
      return _deepEq(jsonDecode(stored), jsonDecode(hinted));
    } on FormatException {
      return false;
    }
  }

  static bool _deepEq(Object? a, Object? b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_deepEq(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEq(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is num && b is num) return a == b;
    return a == b;
  }

  void _onBatch(DeckChangeBatch batch) {
    if (_disposed) return;
    final order = batch.event<OrderChanged>();
    var changed = false;
    if (order != null) {
      if (batch.origin == DeckChangeOrigin.local) _sendStructure(order);
      if (batch.isRemote && _structurePending.isNotEmpty) {
        // Hinted rows arrived: their shimmer starts now.
        final now = clock.now();
        for (final id in [
          ...order.slideIds,
          ...order.groupIds,
          ...?batch.event<SlidesChanged>()?.added,
        ]) {
          if (_structurePending.remove(id) != null) {
            structure[id] = now;
            changed = true;
          }
        }
        if (changed) _scheduleExpiry();
      }
    }
    final ev = batch.event<ElementsChanged>();
    if (ev == null) {
      if (changed) notifyListeners();
      return;
    }
    for (final id in ev.elementIds) {
      final h = text[id];
      if (h == null) continue;
      final e = editor.model.element(id);
      // The synced text caught up (no flicker), the element is gone, or
      // this user changed it.
      if (e == null || !batch.isRemote || _sameText(e.text, h.json)) {
        text.remove(id);
        changed = _textChanged();
      }
    }
    if (batch.isRemote) {
      transforms.removeWhere((_, t) {
        final hit = t.frames.keys.any(ev.elementIds.contains);
        if (hit) changed = true;
        return hit;
      });
    }
    if (changed) notifyListeners();
  }

  void _scheduleExpiry() {
    if (_expiry != null) return;
    _expiry = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => expire(),
    );
  }

  /// Drops hints past their lifetime (called periodically; tests call it).
  void expire() {
    if (_disposed) return;
    final now = clock.now();
    var changed = false;
    final claims = <String>{
      for (final c in presence.cursors)
        if (c.cursor.editing case final e? when e.kind == 'text')
          '${c.sessionId}|${e.elementId}',
    };
    for (final key in claims) {
      _claimSeen[key] = now;
    }
    text.removeWhere((id, h) {
      final key = '${h.sessionId}|$id';
      final seen = _claimSeen[key] ?? h.at;
      final gone =
          (!claims.contains(key) && now.difference(seen) > textLinger) ||
          now.difference(h.at) > textLifetime;
      if (gone) {
        _claimSeen.remove(key);
        changed = _textChanged();
      }
      return gone;
    });
    transforms.removeWhere((_, t) {
      final gone = now.difference(t.at) > transformLifetime;
      if (gone) changed = true;
      return gone;
    });
    structure.removeWhere((_, at) {
      final gone = now.difference(at) >= structureShimmer;
      if (gone) changed = true;
      return gone;
    });
    _structurePending.removeWhere(
      (_, at) => now.difference(at) > structureWait,
    );
    if (text.isEmpty &&
        transforms.isEmpty &&
        structure.isEmpty &&
        _structurePending.isEmpty) {
      _expiry?.cancel();
      _expiry = null;
    }
    if (changed) notifyListeners();
  }

  /// The session whose text hint [elementId] shows, or null.
  TextHint? textOf(String elementId) => text[elementId];

  // ----------------------------------------------------------------- scene

  ({String key, Map<String, SceneNode> nodes, Map<String, SuRect> frames})?
  _memo;

  /// [scene] with the hinted texts of its elements (09 §2.4: same styles,
  /// laid out like the stored body would be). Bodies this user edits are
  /// left alone.
  SlideScene hintedScene(SlideScene scene, SlideCanvasController c) {
    if (text.isEmpty) return scene;
    final slide = c.slide;
    if (slide == null || slide.slide.id != scene.slideId) return scene;
    final editing = _host.elementId;
    final hints = <String, String>{
      for (final e in slide.painted)
        if (text[e.id] case final h? when e.id != editing) e.id: h.json,
    };
    if (hints.isEmpty) return scene;
    final r = c.renderer;
    final key =
        '${scene.slideId}|${r.revision(scene.slideId)}|$_textVersion|'
        '${editor.viewMode}|$editing';
    var memo = _memo;
    if (memo == null || memo.key != key) {
      final built = r.builder.build(
        _withTexts(slide, hints),
        SceneContext(
          theme: slide.theme,
          textLayout: r.textLayout,
          editing: !editor.viewMode,
          deck: r.model,
          icons: r.icons,
          charts: r.charts,
          code: r.code,
          generation: r.fonts.generation.value,
        ),
      );
      final nodes = <String, SceneNode>{};
      void collect(SceneNode n) {
        final id = n.elementId;
        if (id != null && hints.containsKey(id) && !nodes.containsKey(id)) {
          nodes[id] = n;
          return;
        }
        if (n is GroupNode) n.children.forEach(collect);
      }

      built.nodes.forEach(collect);
      memo = _memo = (
        key: key,
        nodes: nodes,
        frames: {for (final id in hints.keys) id: ?built.frames[id]},
      );
    }
    final nodes = memo.nodes;
    if (nodes.isEmpty) return scene;
    SceneNode swap(SceneNode n) {
      final id = n.elementId;
      if (id != null && nodes.containsKey(id)) return nodes[id]!;
      if (n is GroupNode) {
        return GroupNode(
          elementId: n.elementId,
          transform: n.transform,
          opacity: n.opacity,
          clip: n.clip,
          effects: n.effects,
          children: [for (final ch in n.children) swap(ch)],
        );
      }
      return n;
    }

    return SlideScene(
      slideId: scene.slideId,
      width: scene.width,
      height: scene.height,
      background: scene.background,
      nodes: [for (final n in scene.nodes) swap(n)],
      frames: {...scene.frames, ...memo.frames},
      routes: scene.routes,
    );
  }

  static ResolvedSlide _withTexts(ResolvedSlide s, Map<String, String> texts) {
    ResolvedElement el(ResolvedElement e) {
      final t = texts[e.id];
      var kids = e.children;
      if (kids.isNotEmpty) {
        final next = [for (final c in kids) el(c)];
        var same = true;
        for (var i = 0; i < next.length; i++) {
          if (!identical(next[i], kids[i])) same = false;
        }
        if (!same) kids = next;
      }
      if (t == null && identical(kids, e.children)) return e;
      return ResolvedElement(
        record: t == null
            ? e.record
            : SlideElementRec({...e.record.columns, SlidesCols.text: t}),
        frame: e.frame,
        rotation: e.rotation,
        flipH: e.flipH,
        flipV: e.flipV,
        opacity: e.opacity,
        inherited: e.inherited,
        children: kids,
        placeholderType: e.placeholderType,
        dangling: e.dangling,
        fill: e.fill,
        stroke: e.stroke,
        effects: e.effects,
        data: e.data,
        textStyle: e.textStyle,
        styleKey: e.styleKey,
        textStyles: e.textStyles,
        prompt: e.prompt,
        fieldText: e.fieldText,
        parentId: e.parentId,
      );
    }

    return ResolvedSlide(
      slide: s.slide,
      bounds: s.bounds,
      theme: s.theme,
      background: s.background,
      masterElements: s.masterElements,
      layoutElements: s.layoutElements,
      elements: [for (final e in s.elements) el(e)],
      hideMasterElements: s.hideMasterElements,
      skipped: s.skipped,
      layout: s.layout,
      master: s.master,
      themeRecord: s.themeRecord,
      number: s.number,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _host.removeListener(_onHost);
    editor.session.model.removeListener(_onBatch);
    _canvas?.removeListener(_onCanvas);
    unawaited(_sub?.cancel());
    _textTimer?.cancel();
    _transformTimer?.cancel();
    _expiry?.cancel();
    super.dispose();
  }
}
