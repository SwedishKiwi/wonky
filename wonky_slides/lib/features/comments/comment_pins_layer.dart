import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show CommentThreadView;
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/model.dart' show ElementFrame;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';
import '../canvas/canvas_interactions.dart';
import '../canvas/slide_canvas_controller.dart';
import '../editor_screen/deck_editor_controller.dart';
import 'slides_comment_anchor.dart';
import 'slides_comments.dart';

/// The comments layer of the canvas (Slides 09 §3.3–§3.4): speech-bubble
/// pins at the anchors of the current slide's open threads (count badge
/// when several share an element), the active thread's element outlined
/// in `commentHighlightActive`, hover cards (300 ms), the thread card
/// docked next to the active pin and the inline composer of a new comment
/// while the comments panel is closed. Remembers right-click points for
/// the next comment's pin. Registered with [CanvasInteractions] by the
/// comment commands.
class CommentPinsLayer extends CanvasInteraction {
  CommentPinsLayer(super.c);

  SlidesComments? get _comments => SlidesComments.of(c.editor);

  /// A right-click: the next comment pins at this point (09 §3.1).
  @override
  String? contextMenuAt(Offset su) {
    _comments?.noteContextClick(su);
    return null;
  }

  @override
  List<Widget> overlays(BuildContext context) {
    final comments = _comments;
    if (comments == null || c.editor.mode != DeckViewMode.normal) {
      return const [];
    }
    return [
      Positioned.fill(
        child: CommentPinsOverlay(
          key: const ValueKey<String>('slides.comments.overlay'),
          comments: comments,
          canvas: c,
        ),
      ),
    ];
  }
}

/// One pin: the threads at one anchor point (an element's, or one slide
/// thread), in viewport px.
class _Pin {
  _Pin(this.threads, this.point, this.elementId);

  final List<PlacedDeckThread> threads;
  final Offset point;
  final String? elementId;

  PlacedDeckThread get first => threads.first;
}

/// The widgets of [CommentPinsLayer].
class CommentPinsOverlay extends StatefulWidget {
  const CommentPinsOverlay({
    super.key,
    required this.comments,
    required this.canvas,
  });

  final SlidesComments comments;
  final SlideCanvasController canvas;

  /// Size of a pin (active pins are larger).
  static const pinSize = 28.0;
  static const activePinSize = 34.0;

  /// Hover delay of pins (09 §3.3).
  static const hoverDelay = Duration(milliseconds: 300);

  @override
  State<CommentPinsOverlay> createState() => _CommentPinsOverlayState();
}

class _CommentPinsOverlayState extends State<CommentPinsOverlay> {
  SlidesComments get comments => widget.comments;
  SlideCanvasController get c => widget.canvas;
  DeckEditorController get ed => c.editor;

  Timer? _hoverTimer;
  String? _hoverPin;
  String? _shownHover;
  bool _overCard = false;

  /// Focus of the docked card: it takes the focus when a thread docks, so
  /// Esc closes it and Tab reaches its reply box (keyboard, 09 §3.4).
  final _dockFocus = FocusNode(debugLabel: 'slides.comments.docked');
  String? _focusedDock;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _dockFocus.dispose();
    super.dispose();
  }

  void _enterPin(String key) {
    _hoverPin = key;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(CommentPinsOverlay.hoverDelay, () {
      if (mounted && _hoverPin == key) setState(() => _shownHover = key);
    });
  }

  void _exitPin(String key) {
    if (_hoverPin == key) _hoverPin = null;
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && !_overCard && _hoverPin == null) {
        setState(() => _shownHover = null);
      }
    });
  }

  Future<void> _run(String id, Map<String, Object?> args) => ed
      .services
      .dispatcher
      .invoke(id, args: args, source: InvocationSource.ui, context: context);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      comments,
      c,
      ed,
      comments.dockDismissed,
      ed.services.panels,
    ]),
    builder: (context, _) =>
        LayoutBuilder(builder: (context, box) => _build(context, box.biggest)),
  );

  /// The pins of the current slide.
  List<_Pin> _pins() {
    final slide = ed.currentSlideId;
    if (slide == null) return const [];
    final out = <_Pin>[];
    final byElement = <String, List<PlacedDeckThread>>{};
    var slidePins = 0;
    final size = c.viewport.slideSize;
    for (final p in comments.threadsOn(slide)) {
      final el = p.elementId;
      if (el != null) {
        byElement.putIfAbsent(el, () => []).add(p);
        continue;
      }
      final point = p.anchor.point;
      final px = point != null
          ? c.viewport.toViewport(point)
          : c.viewport.toViewport(Offset(size.width, 0)) +
                Offset(-CommentPinsOverlay.pinSize - 8, 8.0 + slidePins++ * 32);
      out.add(_Pin([p], px, null));
    }
    for (final MapEntry(key: id, value: list) in byElement.entries) {
      final f = c.frameOf(id);
      if (f == null) continue;
      final pt =
          list.first.anchor.point ?? SlidesCommentAnchor.elementDefaultPoint;
      final su = SlideCanvasController.localToSlide(
        f,
        pt.dx * f.width,
        pt.dy * f.height,
      );
      out.add(_Pin(list, c.viewport.toViewport(su), id));
    }
    return out;
  }

  String _keyOf(_Pin p) => p.elementId ?? p.first.uuid;

  Widget _build(BuildContext context, Size area) {
    final controller = comments.controller;
    if (controller == null || !comments.visible) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final active = controller.activeThreadUuid;
    final pins = comments.pinsOn ? _pins() : const <_Pin>[];
    final activePlaced = active == null ? null : comments.placed(active);
    final onSlide =
        activePlaced != null && activePlaced.slideId == ed.currentSlideId;
    final outline = onSlide && activePlaced.elementId != null
        ? c.frameOf(activePlaced.elementId!)
        : null;
    final panelOpen = ed.services.panels.isOpen(ShellPanels.comments);
    final children = <Widget>[
      if (outline != null)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey<String>('slides.comments.activeOutline'),
              painter: _OutlinePainter(
                outline,
                c,
                theme.colorScheme.commentHighlightActive,
              ),
            ),
          ),
        ),
      for (final p in pins) _pin(context, p, active, area),
    ];
    final draft = controller.draftAnchor;
    if (draft != null && !panelOpen) {
      children.addAll(_composer(context, controller, draft, area));
    } else if (onSlide && !panelOpen && !comments.dockDismissed.value) {
      children.addAll(_docked(context, controller, activePlaced, area));
    } else if (_shownHover != null) {
      final p = pins.where((p) => _keyOf(p) == _shownHover).firstOrNull;
      if (p != null) children.add(_hover(context, p, area));
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  // ------------------------------------------------------------------ pins

  Widget _pin(BuildContext context, _Pin p, String? active, Size area) {
    final l = slidesL10n(context);
    final isActive = p.threads.any((t) => t.uuid == active);
    final size = isActive
        ? CommentPinsOverlay.activePinSize
        : CommentPinsOverlay.pinSize;
    final key = _keyOf(p);
    final author = p.first.thread.comments.firstOrNull?.author;
    final left = (p.point.dx - 4)
        .clamp(0.0, math.max(0.0, area.width - size))
        .toDouble();
    final top = (p.point.dy - size)
        .clamp(0.0, math.max(0.0, area.height - size))
        .toDouble();
    return Positioned(
      key: ValueKey<String>('slides.comments.pin.$key'),
      left: left,
      top: top,
      width: size + 8,
      height: size + 8,
      child: CanvasChrome(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _enterPin(key),
          onExit: (_) => _exitPin(key),
          child: Semantics(
            button: true,
            label: l.commentPinLabel(
              p.threads.length,
              author?.displayName ?? '',
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _shownHover = null);
                unawaited(
                  _run('slides.comments.show', {'threadUuid': p.first.uuid}),
                );
              },
              child: Align(
                alignment: Alignment.topLeft,
                child: CommentPin(
                  size: size,
                  name: author?.displayName ?? '',
                  colorIndex: author?.colorIndex ?? 0,
                  imageUrl: author?.avatarUrl,
                  count: p.threads.length,
                  active: isActive,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Positions a card of [width] next to [anchor] (right of it, or left
  /// when there is no room), clamped into [area]; narrow canvases get a
  /// card as wide as they allow.
  Positioned _place(
    Rect anchor,
    Size area, {
    required double width,
    required Widget child,
    double maxHeight = 360,
  }) {
    final w = math.max(160.0, math.min(width, area.width - 16));
    var left = anchor.right + 6;
    if (left + w > area.width - 8) left = anchor.left - w - 6;
    left = left.clamp(8.0, math.max(8.0, area.width - w - 8)).toDouble();
    final top = anchor.top
        .clamp(8.0, math.max(8.0, area.height - 120))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      width: w,
      child: CanvasChrome(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(
              120,
              math.min(maxHeight, area.height - top - 8),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Rect _pinRect(Offset point) => Rect.fromLTWH(
    point.dx - 4,
    point.dy - CommentPinsOverlay.pinSize,
    CommentPinsOverlay.pinSize,
    CommentPinsOverlay.pinSize,
  );

  /// The anchor point of a draft or a placed thread, in viewport px.
  Offset? _pointOf(SlidesCommentAnchor a, int slideIndex) {
    final size = c.viewport.slideSize;
    final el = a.elementId;
    if (el != null) {
      final f = c.frameOf(el);
      if (f == null) return null;
      final pt = a.point ?? SlidesCommentAnchor.elementDefaultPoint;
      return c.viewport.toViewport(
        SlideCanvasController.localToSlide(
          f,
          pt.dx * f.width,
          pt.dy * f.height,
        ),
      );
    }
    final pt = a.point;
    return pt != null
        ? c.viewport.toViewport(pt)
        : c.viewport.toViewport(Offset(size.width, 0)) +
              Offset(-CommentPinsOverlay.pinSize - 8, 8.0 + slideIndex * 32);
  }

  // ------------------------------------------------------------- composer

  List<Widget> _composer(
    BuildContext context,
    CommentsController controller,
    NewCommentAnchor draft,
    Size area,
  ) {
    final a = SlidesCommentAnchor.parse(draft.kind, draft.anchorJson);
    if (a == null || comments.slideOf(a) != ed.currentSlideId) return const [];
    final slidePins = a.elementId == null
        ? comments
              .threadsOn(ed.currentSlideId!)
              .where((p) => p.elementId == null && p.anchor.point == null)
              .length
        : 0;
    final point = _pointOf(a, slidePins);
    if (point == null) return const [];
    return [
      _place(
        _pinRect(point),
        area,
        width: 320,
        child: Focus(
          onKeyEvent: (node, e) {
            if (e is KeyDownEvent &&
                e.logicalKey == LogicalKeyboardKey.escape) {
              controller.cancelDraft();
              ed.canvasFocus.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
            child: NewCommentCard(
              key: const ValueKey<String>('slides.comments.composer'),
              services: ed.services,
              controller: controller,
            ),
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------- docked card

  List<Widget> _docked(
    BuildContext context,
    CommentsController controller,
    PlacedDeckThread p,
    Size area,
  ) {
    final slideIndex = p.elementId == null && p.anchor.point == null
        ? comments
              .threadsOn(p.slideId)
              .where((t) => t.elementId == null && t.anchor.point == null)
              .toList()
              .indexWhere((t) => t.uuid == p.uuid)
        : 0;
    final point = _pointOf(p.anchor, math.max(0, slideIndex));
    if (point == null) return const [];
    _shownHover = null;
    if (_focusedDock != p.uuid) {
      _focusedDock = p.uuid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _dockFocus.context != null) _dockFocus.requestFocus();
      });
    }
    void close() {
      _focusedDock = null;
      comments.dockDismissed.value = true;
      ed.canvasFocus.requestFocus();
    }

    return [
      _place(
        _pinRect(point),
        area,
        width: 300,
        maxHeight: 420,
        child: Focus(
          focusNode: _dockFocus,
          onKeyEvent: (node, e) {
            if (e is KeyDownEvent &&
                e.logicalKey == LogicalKeyboardKey.escape) {
              close();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: _DockedThread(
            key: ValueKey<String>('slides.comments.docked.${p.uuid}'),
            services: ed.services,
            controller: controller,
            thread: p.thread,
            onClose: close,
          ),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ hover card

  Widget _hover(BuildContext context, _Pin p, Size area) => _place(
    _pinRect(p.point),
    area,
    width: 280,
    maxHeight: 240,
    child: MouseRegion(
      onEnter: (_) => _overCard = true,
      onExit: (_) {
        _overCard = false;
        if (_hoverPin == null) setState(() => _shownHover = null);
      },
      child: CommentHoverCard(
        key: const ValueKey<String>('slides.comments.hoverCard'),
        threads: [for (final t in p.threads) t.thread],
        onOpen: () {
          setState(() => _shownHover = null);
          unawaited(_run('slides.comments.show', {'threadUuid': p.first.uuid}));
        },
      ),
    ),
  );
}

/// A 28 px speech-bubble pin with the thread author's avatar (09 §3.3);
/// a count badge when several threads share the anchor.
class CommentPin extends StatelessWidget {
  const CommentPin({
    super.key,
    required this.size,
    required this.name,
    required this.colorIndex,
    this.imageUrl,
    this.count = 1,
    this.active = false,
  });

  final double size;
  final String name;
  final int colorIndex;
  final String? imageUrl;
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    final ring = active ? cs.commentHighlightActive : cs.border;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: cs.popover,
            border: Border.all(color: ring, width: active ? 2 : 1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size / 2),
              topRight: Radius.circular(size / 2),
              bottomRight: Radius.circular(size / 2),
              bottomLeft: const Radius.circular(3),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: WonkyAvatar(
            name: name,
            color: cs.presence(colorIndex),
            imageUrl: imageUrl,
            size: size - 8,
          ),
        ),
        if (count > 1)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: cs.primaryForeground,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The hover card of a pin: the first comment and the reply count of each
/// thread (09 §3.3); a click opens the thread.
class CommentHoverCard extends StatelessWidget {
  const CommentHoverCard({
    super.key,
    required this.threads,
    required this.onOpen,
  });

  final List<CommentThreadView> threads;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.popover,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, t) in threads.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              GestureDetector(
                onTap: onOpen,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          WonkyAvatar(
                            name:
                                t.comments.firstOrNull?.author?.displayName ??
                                '',
                            color: cs.presence(
                              t.comments.firstOrNull?.author?.colorIndex ?? 0,
                            ),
                            imageUrl: t.comments.firstOrNull?.author?.avatarUrl,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              t.comments.firstOrNull?.author?.displayName ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.popoverForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.comments.firstOrNull?.body ?? '',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: cs.popoverForeground,
                        ),
                      ),
                      if (t.comments.length > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          l.commentReplies(t.comments.length - 1),
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The thread card docked next to the active pin (09 §3.3).
class _DockedThread extends StatelessWidget {
  const _DockedThread({
    super.key,
    required this.services,
    required this.controller,
    required this.thread,
    required this.onClose,
  });

  final ShellServices services;
  final CommentsController controller;
  final CommentThreadView thread;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final cs = ShadTheme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.popover,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: CommentThreadCard(
              services: services,
              controller: controller,
              thread: thread,
              onTap: () {},
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('slides.comments.docked.close'),
              width: 24,
              height: 24,
              iconSize: 14,
              semanticLabel: l.commentsDockedClose,
              icon: const Icon(LucideIcons.x),
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlines the active thread's element (rotated frame) in
/// `commentHighlightActive`.
class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.frame, this.c, this.color);

  final ElementFrame frame;
  final SlideCanvasController c;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final corners = [
      for (final (x, y) in [
        (0.0, 0.0),
        (f.width, 0.0),
        (f.width, f.height),
        (0.0, f.height),
      ])
        c.viewport.toViewport(SlideCanvasController.localToSlide(f, x, y)),
    ];
    final path = Path()..addPolygon(corners, true);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => true;
}
