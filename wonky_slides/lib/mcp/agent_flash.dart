import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show ShadColorScheme, ShadTheme;
import 'package:wonky_slides_core/model.dart' show ElementFrame;

import '../features/canvas/canvas_interactions.dart';
import '../features/canvas/slide_canvas_controller.dart';
import '../features/editor_screen/deck_editor_controller.dart';

/// One agent highlight: elements of a slide (or the whole slide) outlined
/// in violet with the agent's tag (Slides 11 §1.3, §5).
@immutable
class AgentFlashEntry {
  const AgentFlashEntry({
    required this.id,
    required this.label,
    required this.until,
    this.slideId,
    this.elementIds = const [],
  });

  final int id;

  /// The agent tag ("Claude Code (MCP)").
  final String label;

  /// The slide (or layout/master) the elements are on; with no
  /// [elementIds] the slide itself is outlined.
  final String? slideId;
  final List<String> elementIds;
  final DateTime until;
}

/// The agent highlights of one open deck (Slides 11 §5 *Agent presence
/// highlight*): every `ui.slides.*` call that targets elements or slides
/// and every headless `slides.*` write that touches them
/// (`SlidesAgentWrites`) flashes them for 2–5 s with a violet outline and
/// the agent tag, like Sheets' `AgentHighlightLayer`. The canvas draws them
/// with [AgentFlashLayer]. Nothing is written to the deck.
class SlidesAgentFlash extends ChangeNotifier {
  SlidesAgentFlash._(this.editor);

  static final Expando<SlidesAgentFlash> _of = Expando('slidesAgentFlash');

  /// The highlights of [editor] (created on first use).
  static SlidesAgentFlash of(DeckEditorController editor) =>
      _of[editor] ??= SlidesAgentFlash._(editor);

  /// The highlights of [editor] when any were created.
  static SlidesAgentFlash? maybeOf(DeckEditorController editor) => _of[editor];

  /// The agent violet (light theme; Sheets' agent color).
  static const color = Color(0xff8b5cf6);

  /// The agent violet on a dark app theme.
  static const darkColor = Color(0xffa78bfa);

  /// The violet for [brightness].
  static Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : color;

  /// Default duration (11 §5: 2–5 s).
  static const defaultDuration = Duration(seconds: 3);

  /// At most this many highlights at once (oldest dropped).
  static const maxActive = 20;

  final DeckEditorController editor;
  final List<AgentFlashEntry> _active = [];
  final Map<int, Timer> _timers = {};
  int _seq = 0;
  bool _disposed = false;

  /// The highlights showing now, oldest first.
  List<AgentFlashEntry> get active => List.unmodifiable(_active);

  /// Flashes [elementIds] (on [slideId], else their own slide) — or, with
  /// no elements, [slideId] itself — with the tag [label] for [duration].
  /// Unknown elements are skipped; returns the entry (null when nothing is
  /// left to show).
  AgentFlashEntry? flash({
    required String label,
    String? slideId,
    Iterable<String> elementIds = const [],
    Duration duration = defaultDuration,
  }) {
    if (_disposed) return null;
    final model = editor.model;
    final ids = [
      for (final id in elementIds)
        if (model.element(id) != null) id,
    ];
    final owner =
        slideId ?? (ids.isEmpty ? null : model.element(ids.first)?.ownerId);
    if (ids.isEmpty && owner == null) return null;
    final e = AgentFlashEntry(
      id: ++_seq,
      label: label,
      slideId: owner,
      elementIds: ids,
      until: clock.now().add(duration),
    );
    _active.add(e);
    while (_active.length > maxActive) {
      _timers.remove(_active.removeAt(0).id)?.cancel();
    }
    _timers[e.id] = Timer(duration, () => _expire(e.id));
    notifyListeners();
    return e;
  }

  void _expire(int id) {
    _timers.remove(id);
    final before = _active.length;
    _active.removeWhere((e) => e.id == id);
    if (_active.length != before && !_disposed) notifyListeners();
  }

  /// Removes every highlight.
  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    if (_active.isEmpty) return;
    _active.clear();
    notifyListeners();
  }

  /// The highlights on surface [surfaceId] (a slide, layout or master).
  List<AgentFlashEntry> on(String? surfaceId) => [
    for (final e in _active)
      if (surfaceId != null && e.slideId == surfaceId) e,
  ];

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _active.clear();
    if (_of[editor] == this) _of[editor] = null;
    super.dispose();
  }
}

/// Draws the [SlidesAgentFlash] highlights of the shown surface on the
/// canvas: a 2 px violet outline per element (rotated with it), the slide
/// outlined when no element is given, and the agent tag above the first
/// element. Registered with [CanvasInteractions] by `SlidesUiBridge`.
class AgentFlashLayer extends CanvasInteraction {
  AgentFlashLayer(super.c);

  @override
  List<Widget> overlays(BuildContext context) {
    final flash = SlidesAgentFlash.maybeOf(c.editor);
    if (flash == null) return const [];
    return [
      Positioned.fill(
        child: IgnorePointer(
          child: AgentFlashOverlay(
            key: const ValueKey<String>('slides.agentFlash.overlay'),
            flash: flash,
            canvas: c,
          ),
        ),
      ),
    ];
  }
}

/// The widgets of [AgentFlashLayer] (rebuilt when the highlights change).
class AgentFlashOverlay extends StatelessWidget {
  const AgentFlashOverlay({
    super.key,
    required this.flash,
    required this.canvas,
  });

  final SlidesAgentFlash flash;
  final SlideCanvasController canvas;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: flash,
    builder: (context, _) {
      final c = canvas;
      final entries = flash.on(c.editor.surfaceId);
      if (entries.isEmpty) return const SizedBox.shrink();
      final color = SlidesAgentFlash.colorFor(ShadTheme.of(context).brightness);
      final outlines = <ElementFrame>[];
      final tags = <Widget>[];
      var slideOutline = false;
      for (final e in entries) {
        Rect? anchor;
        for (final id in e.elementIds) {
          final f = c.frameOf(id);
          if (f == null) continue;
          outlines.add(f);
          anchor ??= c.viewport.rectToViewport(f.bounds);
        }
        if (e.elementIds.isEmpty) {
          slideOutline = true;
          final s = c.scene;
          if (s != null) {
            anchor = Rect.fromPoints(
              c.viewport.toViewport(Offset.zero),
              c.viewport.toViewport(Offset(s.width, s.height)),
            );
          }
        }
        if (anchor == null) continue;
        tags.add(
          _tag(
            key: 'slides.agentFlash.tag.${e.id}',
            rect: anchor,
            label: e.label,
            color: color,
            index: tags.length,
          ),
        );
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              key: const ValueKey<String>('slides.agentFlash.outlines'),
              painter: _FlashPainter(
                outlines,
                c,
                color,
                slide: switch (c.scene) {
                  final s? when slideOutline => Size(s.width, s.height),
                  _ => null,
                },
              ),
            ),
          ),
          ...tags,
        ],
      );
    },
  );

  Widget _tag({
    required String key,
    required Rect rect,
    required String label,
    required Color color,
    required int index,
  }) {
    const h = 18.0;
    var top = rect.top - h - 2 - index * (h + 2);
    if (top < 0) top = rect.top + 2 + index * (h + 2);
    return Positioned(
      key: ValueKey<String>(key),
      left: math.max(0, rect.left),
      top: top,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '✦ $label',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: ShadColorScheme.contrastingForeground(color),
          ),
        ),
      ),
    );
  }
}

class _FlashPainter extends CustomPainter {
  _FlashPainter(this.frames, this.c, this.color, {this.slide});

  final List<ElementFrame> frames;
  final SlideCanvasController c;
  final Color color;

  /// The slide size (su) when the slide itself is outlined.
  final Size? slide;

  @override
  void paint(Canvas canvas, Size size) {
    final v = c.viewport;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final f in frames) {
      final center = Offset(f.cx, f.cy);
      final a = f.rotation * math.pi / 180;
      Offset corner(double dx, double dy) => v.toViewport(
        center +
            Offset(
              dx * math.cos(a) - dy * math.sin(a),
              dx * math.sin(a) + dy * math.cos(a),
            ),
      );
      final hw = f.width / 2 + 3 / v.scale, hh = f.height / 2 + 3 / v.scale;
      canvas.drawPath(
        Path()..addPolygon([
          corner(-hw, -hh),
          corner(hw, -hh),
          corner(hw, hh),
          corner(-hw, hh),
        ], true),
        paint,
      );
    }
    final s = slide;
    if (s != null) {
      canvas.drawRect(
        Rect.fromPoints(
          v.toViewport(Offset.zero),
          v.toViewport(Offset(s.width, s.height)),
        ).deflate(1),
        paint..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_FlashPainter old) => true;
}
