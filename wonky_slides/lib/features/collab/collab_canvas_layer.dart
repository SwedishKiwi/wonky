import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/model.dart' show ElementFrame;
import 'package:wonky_slides_core/scene.dart' show SlideScene;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';
import '../canvas/canvas_interactions.dart';
import '../canvas/slide_canvas_controller.dart';
import '../settings/slides_user_defaults.dart';
import '../text_editing/text_editing_host.dart';
import 'slides_collab.dart';
import 'slides_presence_controller.dart';
import 'soft_locks.dart';

/// The collaboration layer of the canvas (Slides 09 §1.2, §2.3, §2.4;
/// `SlidesHintOverlay`): live text hints in the stage's scene, and on top
/// of the slide the remote selection outlines with name flags, soft-lock
/// outlines with "✎ Anna is editing" flags, live drag outlines, the
/// soft-lock popover and the follow banner. Registered with
/// [CanvasInteractions] by the collaboration commands.
class CollabCanvasLayer extends CanvasInteraction {
  CollabCanvasLayer(super.c);

  SlidesCollab? get _collab => SlidesCollab.of(c.editor);

  @override
  SlideScene sceneFor(SlideScene scene) =>
      _collab?.hints.hintedScene(scene, c) ?? scene;

  @override
  List<Widget> overlays(BuildContext context) {
    final collab = _collab;
    if (collab == null) return const [];
    return [
      Positioned.fill(
        child: CollabCanvasOverlay(
          key: const ValueKey<String>('slides.collab.overlay'),
          collab: collab,
          canvas: c,
        ),
      ),
    ];
  }
}

/// One outlined element of a participant.
class _Outline {
  const _Outline(this.frame, this.color, {this.dashed = false, this.width = 2});

  final ElementFrame frame;
  final Color color;
  final bool dashed;
  final double width;
}

/// The widgets and painting of [CollabCanvasLayer] (rebuilt when presence,
/// claims or hints change).
class CollabCanvasOverlay extends StatefulWidget {
  const CollabCanvasOverlay({
    super.key,
    required this.collab,
    required this.canvas,
  });

  final SlidesCollab collab;
  final SlideCanvasController canvas;

  @override
  State<CollabCanvasOverlay> createState() => _CollabCanvasOverlayState();
}

class _CollabCanvasOverlayState extends State<CollabCanvasOverlay> {
  String? _hover;

  SlidesCollab get collab => widget.collab;
  SlideCanvasController get c => widget.canvas;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: collab.changes,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final ed = c.editor;
    final slide = ed.currentSlideId;
    if (slide == null) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final presence = collab.presence;
    final locks = collab.locks;
    final now = clock.now();
    final showRemote = ed.defaults.flag(
      SlidesUserDefaults.keyShowRemoteCursors,
    );
    final reduceMotion = WonkyThemeScope.of(context).reduceMotion;
    Color colorOf(int i) => theme.colorScheme.presence(i);

    final outlines = <_Outline>[];
    final flags = <Widget>[];
    final hoverTargets = <String, Rect>{};
    final flagOffsets = <String, int>{};

    // Soft-locked bodies (09 §2.3): dashed outlines (offset per claimer)
    // and one flag per body.
    final claimed = <String, List<RemoteDeckCursor>>{};
    for (final h in presence.cursors) {
      final e = h.cursor.editing;
      final id = e?.elementId;
      if (e == null || id == null || h.isAway) continue;
      if (e.kind != 'text' && e.kind != 'tableCell') continue;
      claimed.putIfAbsent(id, () => []).add(h);
    }
    for (final MapEntry(key: id, value: holders) in claimed.entries) {
      final f = c.frameOf(id);
      if (f == null) continue;
      for (final (i, h) in holders.indexed) {
        final grow = i * 2.0 / c.viewport.scale;
        outlines.add(
          _Outline(
            ElementFrame(
              f.x - grow,
              f.y - grow,
              f.width + 2 * grow,
              f.height + 2 * grow,
              rotation: f.rotation,
            ),
            colorOf(h.colorIndex),
            dashed: true,
            width: 1.5,
          ),
        );
      }
      final r = c.viewport.rectToViewport(f.bounds);
      hoverTargets[id] = r;
      final names = locks.namesOf(holders);
      final label = _hover == id
          ? l.presenceEditingHover(names)
          : holders.length == 1
          ? l.presenceEditingFlag(names)
          : l.presenceEditingFlagMany(names);
      flags.add(
        _flag(
          key: 'slides.collab.lockFlag.$id',
          rect: r,
          index: flagOffsets.update(id, (v) => v + 1, ifAbsent: () => 0),
          label: label,
          color: colorOf(holders.first.colorIndex),
        ),
      );
    }

    // Remote selections (09 §1.2): 2 px outlines + a name flag above the
    // first selected element.
    if (showRemote) {
      for (final h in presence.cursorsOn(slide)) {
        final ids = [
          for (final id in h.cursor.selection)
            if (!(claimed[id]?.contains(h) ?? false)) id,
        ];
        final flashing = h.sessionId == presence.flashSession;
        final color = colorOf(h.colorIndex);
        String? first;
        for (final id in ids) {
          final f = c.frameOf(id);
          if (f == null) continue;
          first ??= id;
          outlines.add(
            _Outline(f, color, width: flashing && presence.flashOn ? 4 : 2),
          );
          hoverTargets.putIfAbsent(
            id,
            () => c.viewport.rectToViewport(f.bounds),
          );
        }
        if (first == null) continue;
        final visible = presence.flagVisible(
          h,
          now,
          hovered: _hover == null || !ids.contains(_hover) ? null : _hover,
        );
        flags.add(
          _flag(
            key: 'slides.collab.selectionFlag.${h.sessionId}',
            rect: c.viewport.rectToViewport(c.frameOf(first)!.bounds),
            index: flagOffsets.update(first, (v) => v + 1, ifAbsent: () => 0),
            label: presence.labelOf(h.participant),
            color: color,
            visible: visible,
            fade: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 300),
          ),
        );
      }
    }

    // Live drags of others (09 §2.4, P1): outlines at the hinted frames.
    for (final t in collab.hints.transforms.values) {
      if (t.slideId != slide) continue;
      final color = colorOf(presence.cursorOf(t.sessionId)?.colorIndex ?? 0);
      for (final f in t.frames.values) {
        outlines.add(_Outline(f, color, dashed: true, width: 1));
      }
    }

    final prompt = locks.prompt.value;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey<String>('slides.collab.outlines'),
              painter: _OutlinePainter(outlines, c),
            ),
          ),
        ),
        for (final MapEntry(key: id, value: r) in hoverTargets.entries)
          Positioned.fromRect(
            rect: r,
            child: MouseRegion(
              opaque: false,
              hitTestBehavior: HitTestBehavior.translucent,
              onEnter: (_) => setState(() => _hover = id),
              onExit: (_) {
                if (_hover == id) setState(() => _hover = null);
              },
              child: const SizedBox.expand(),
            ),
          ),
        ...flags,
        if (prompt != null && prompt.target.kind != 'notes')
          ..._prompt(context, prompt),
        if (presence.followed case final f?)
          Positioned(
            top: 8,
            right: 8,
            child: CanvasChrome(
              child: _FollowBanner(
                name: presence.labelOf(f.participant),
                color: colorOf(f.colorIndex),
                onStop: () => ed.services.dispatcher.invoke(
                  'slides.presence.unfollow',
                  source: InvocationSource.ui,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _flag({
    required String key,
    required Rect rect,
    required int index,
    required String label,
    required Color color,
    bool visible = true,
    Duration fade = Duration.zero,
  }) {
    const h = 18.0;
    var top = rect.top - h - 2 - index * (h + 2);
    if (top < 0) top = rect.top + 2 + index * (h + 2);
    return Positioned(
      key: ValueKey<String>(key),
      left: math.max(0, rect.left),
      top: top,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: fade,
          child: CollabFlag(label: label, color: color),
        ),
      ),
    );
  }

  List<Widget> _prompt(BuildContext context, SoftLockPrompt p) {
    final id = p.target.elementId;
    final f = id == null ? null : c.frameOf(id);
    final size = c.viewport.viewport;
    const w = 300.0, h = 96.0;
    double left, top;
    if (f == null) {
      left = (size.width - w) / 2;
      top = 16;
    } else {
      final r = c.viewport.rectToViewport(f.bounds);
      left = r.left;
      top = r.bottom + 8 + h <= size.height ? r.bottom + 8 : r.top - h - 8;
    }
    left = left.clamp(8, math.max(8, size.width - w - 8)).toDouble();
    top = top.clamp(8, math.max(8, size.height - h - 8)).toDouble();
    return [
      Positioned(
        left: left,
        top: top,
        width: w,
        child: CanvasChrome(
          child: SoftLockPopover(prompt: p, collab: collab),
        ),
      ),
    ];
  }
}

/// A presence-colored name pill ("Anna", "✎ Anna is editing").
class CollabFlag extends StatelessWidget {
  const CollabFlag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 280),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: ShadColorScheme.contrastingForeground(color),
      ),
    ),
  );
}

/// The soft-lock popover (04 §13.11): *"Anna is editing this text."*
/// [Cancel] [Edit anyway]; after a lost race *"Anna started editing this
/// text first."* [Stop editing] [Keep editing]. Esc answers no.
class SoftLockPopover extends StatelessWidget {
  const SoftLockPopover({
    super.key,
    required this.prompt,
    required this.collab,
  });

  final SoftLockPrompt prompt;
  final SlidesCollab collab;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final names = collab.locks.namesOf(prompt.holders);
    final message = prompt.race
        ? l.softLockRaceMessage(names)
        : prompt.target.kind == 'notes'
        ? l.softLockNotesMessage(names)
        : l.softLockMessage(names);
    final color = theme.colorScheme.presence(
      prompt.holders.isEmpty ? 0 : prompt.holders.first.colorIndex,
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            prompt.answer(false),
      },
      child: Semantics(
        container: true,
        liveRegion: true,
        label: message,
        child: Container(
          key: const ValueKey<String>('slides.softLock.popover'),
          decoration: BoxDecoration(
            color: theme.colorScheme.popover,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  message,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.popoverForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ShadButton.outline(
                      key: const ValueKey<String>('slides.softLock.no'),
                      size: ShadButtonSize.sm,
                      onPressed: () => prompt.answer(false),
                      child: Text(
                        prompt.race ? l.softLockStop : l.softLockCancel,
                      ),
                    ),
                    ShadButton(
                      key: const ValueKey<String>('slides.softLock.yes'),
                      size: ShadButtonSize.sm,
                      autofocus: true,
                      onPressed: () => prompt.answer(true),
                      child: Text(
                        prompt.race ? l.softLockKeep : l.softLockEditAnyway,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Following Anna · Stop" (09 §1.5).
class _FollowBanner extends StatelessWidget {
  const _FollowBanner({
    required this.name,
    required this.color,
    required this.onStop,
  });

  final String name;
  final Color color;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    return Container(
      key: const ValueKey<String>('slides.collab.followBanner'),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.followBanner(name),
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.popoverForeground,
              ),
            ),
            const SizedBox(width: 4),
            ShadButton.ghost(
              key: const ValueKey<String>('slides.collab.followStop'),
              size: ShadButtonSize.sm,
              onPressed: onStop,
              child: Text(l.followStop),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.outlines, this.c);

  final List<_Outline> outlines;
  final SlideCanvasController c;

  @override
  void paint(Canvas canvas, Size size) {
    final v = c.viewport;
    for (final o in outlines) {
      final f = o.frame;
      final center = Offset(f.cx, f.cy);
      final a = f.rotation * math.pi / 180;
      Offset corner(double dx, double dy) {
        final x = dx * math.cos(a) - dy * math.sin(a);
        final y = dx * math.sin(a) + dy * math.cos(a);
        return v.toViewport(center + Offset(x, y));
      }

      final hw = f.width / 2, hh = f.height / 2;
      final pts = [
        corner(-hw, -hh),
        corner(hw, -hh),
        corner(hw, hh),
        corner(-hw, hh),
      ];
      final paint = Paint()
        ..color = o.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = o.width;
      final path = Path()..addPolygon(pts, true);
      if (!o.dashed) {
        canvas.drawPath(path, paint);
        continue;
      }
      for (final m in path.computeMetrics()) {
        var d = 0.0;
        while (d < m.length) {
          canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
          d += 8;
        }
      }
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => true;
}

/// Starts editing [target] with a forced claim (`slides.text.editAnyway`):
/// answers the open popover, or enters editing of the element.
Future<bool> editAnyway(SlidesCollab collab, TextLockTarget target) async {
  final p = collab.locks.prompt.value;
  final pending = p != null && p.target == target && !p.race;
  collab.locks.editAnyway(target);
  if (pending) return true;
  final id = target.elementId;
  if (id == null) return false;
  final host = textEditingOf(collab.editor);
  return host.begin(
    id,
    cell: target.kind == 'tableCell'
        ? (rowId: target.rowId!, columnId: target.columnId!)
        : null,
  );
}
