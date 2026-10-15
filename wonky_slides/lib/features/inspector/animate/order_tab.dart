import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/model.dart' as core show SlidesText;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../commands/animate_commands.dart' show animatePaneScope;
import '../../../l10n/slides_l10n.dart';
import '../../../theme/slides_tokens.dart';
import '../../builds/animate_view.dart';
import '../../builds/build_labels.dart';
import '../../builds/build_order.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../toolbar/command_ui.dart';

/// Widget keys of the Order list.
abstract final class OrderTabKeys {
  static const list = ValueKey<String>('slides.animate.orderList');
  static const empty = ValueKey<String>('slides.animate.orderEmpty');
  static const options = ValueKey<String>('slides.animate.orderOptions');

  static ValueKey<String> row(String buildId) =>
      ValueKey<String>('slides.animate.row.$buildId');
  static ValueKey<String> step(int index) =>
      ValueKey<String>('slides.animate.step.$index');
  static ValueKey<String> drag(String buildId) =>
      ValueKey<String>('slides.animate.drag.$buildId');
}

/// Inspector › Animate › **Order** (Slides 06 §5.4): every build of the
/// slide grouped by step ("Automatic", "Click 1", …) with kind colors,
/// trigger glyphs, element names, effect summaries, timing bars and
/// warnings; parts expand; drag and drop reorders (a step header drop is
/// a "New click"), `Mod+Alt+↑/↓` too (scope `slidesAnimatePane`), Delete
/// removes; Shift/Mod-click multi-selects; a row's context menu previews
/// from it, sets its trigger, moves, copies or removes it. Footer:
/// *Preview*, *Play from selected*, ⚙ options.
class OrderTab extends StatefulWidget {
  const OrderTab({super.key, required this.services, required this.editor});

  final ShellServices services;
  final DeckEditorController editor;

  @override
  State<OrderTab> createState() => _OrderTabState();
}

class _OrderTabState extends State<OrderTab> {
  final _focus = FocusNode(debugLabel: 'slides.animate.order');
  final Set<String> _expanded = {};

  /// Drop target: (build id or `step:<k>`, before).
  (String, bool)? _drop;

  DeckEditorController get ed => widget.editor;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final ui = SlidesCommandUi(context, widget.services);
    final slideId = ed.currentSlideId;
    if (slideId == null || ed.editsMasters) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Text(
          l.animateNoSlide,
          textAlign: TextAlign.center,
          style: theme.textTheme.muted,
        ),
      );
    }
    final view = AnimateView.of(ed);
    final order = view.orderOf(slideId);
    final selected = view.selectedBuildIds.toSet();
    final canEdit = ed.canEdit;

    final list = order.rows.isEmpty
        ? Padding(
            key: OrderTabKeys.empty,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              l.animateOrderNone,
              textAlign: TextAlign.center,
              style: theme.textTheme.muted,
            ),
          )
        : Focus(
            focusNode: _focus,
            onKeyEvent: (node, e) => _key(e, order, view),
            child: Semantics(
              container: true,
              label: l.animateOrderListLabel,
              child: Column(
                key: OrderTabKeys.list,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in order.steps) ...[
                    _header(context, s, order, canEdit),
                    for (final r in s.rows)
                      _row(context, ui, view, order, s, r, selected, canEdit),
                  ],
                ],
              ),
            ),
          );

    final sel = view.selectedBuildIds;
    return Column(
      key: const ValueKey<String>('slides.animate.orderTab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                order.rows.isEmpty
                    ? ''
                    : l.animateOrderSummary(
                        order.timeline.stepCount,
                        BuildLabels.seconds(order.timeline.durationMs),
                      ),
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ),
            WonkyDropdownMenu(
              anchor: const ShadAnchor(
                childAlignment: AlignmentDirectional.bottomEnd,
                overlayAlignment: AlignmentDirectional.topEnd,
                offset: Offset(0, 4),
              ),
              entries: () => MenuResolver(widget.services).entries(context, [
                for (final o in const [
                  AnimateView.optionAutoPreview,
                  AnimateView.optionIncludeTransition,
                  AnimateView.optionFullMotion,
                ])
                  MenuSpec.command(
                    'slides.animate.togglePreviewOption',
                    args: {'option': o},
                    label: l.animatePreviewOption(o),
                    id: 'animate.options.$o',
                  ),
                MenuSpec.command(
                  'slides.animate.toggleOrderOverlay',
                  id: 'animate.options.overlay',
                ),
              ]),
              builder: (context, c) => ShadIconButton.ghost(
                key: OrderTabKeys.options,
                width: 28,
                height: 28,
                iconSize: 16,
                semanticLabel: l.animatePreviewOptions,
                icon: const Icon(LucideIcons.settings2),
                onPressed: c.toggle,
              ),
            ),
          ],
        ),
        list,
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _button(
              ui,
              'slides.animate.preview',
              const {},
              LucideIcons.play,
              l.animatePreview,
            ),
            _button(
              ui,
              'slides.animate.preview',
              {'fromBuildId': ?(sel.isEmpty ? null : sel.first)},
              LucideIcons.skipForward,
              l.animatePlayFromSelected,
              enabled: sel.isNotEmpty,
            ),
          ],
        ),
      ],
    );
  }

  Widget _button(
    SlidesCommandUi ui,
    String id,
    Map<String, Object?> args,
    IconData icon,
    String label, {
    bool enabled = true,
  }) {
    final st = ui.state(id, args);
    return ShadButton.outline(
      key: ValueKey<String>('slides.animate.order.$label'),
      size: ShadButtonSize.sm,
      enabled: enabled && st.enabled,
      leading: Icon(icon, size: 14),
      onPressed: () => ui.run(id, args, InvocationSource.ui),
      child: Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  // ------------------------------------------------------------ keyboard

  KeyEventResult _key(KeyEvent e, BuildOrder order, AnimateView view) {
    if (e is KeyDownEvent || e is KeyRepeatEvent) {
      final k = e.logicalKey;
      final hw = HardwareKeyboard.instance;
      final mod = hw.isMetaPressed || hw.isControlPressed;
      if (!mod &&
          !hw.isAltPressed &&
          (k == LogicalKeyboardKey.arrowUp ||
              k == LogicalKeyboardKey.arrowDown)) {
        final ids = [for (final r in order.rows) r.id];
        if (ids.isEmpty) return KeyEventResult.handled;
        final sel = view.selectedBuildIds;
        final cur = sel.isEmpty
            ? -1
            : ids.indexOf(
                k == LogicalKeyboardKey.arrowUp ? sel.first : sel.last,
              );
        final next =
            (cur < 0 ? 0 : cur + (k == LogicalKeyboardKey.arrowUp ? -1 : 1))
                .clamp(0, ids.length - 1);
        if (hw.isShiftPressed && view.anchor != null) {
          _range(view, ids, view.anchor!, ids[next]);
        } else {
          view.selectBuilds([ids[next]]);
        }
        return KeyEventResult.handled;
      }
      if (k == LogicalKeyboardKey.enter && view.selectedBuildIds.isNotEmpty) {
        ed.invokeCommand('slides.panel.animate', {'tab': 'build'});
        return KeyEventResult.handled;
      }
    }
    return widget.services.keymap.handle(e, animatePaneScope, context: context);
  }

  void _range(AnimateView view, List<String> ids, String from, String to) {
    final a = ids.indexOf(from), b = ids.indexOf(to);
    if (a < 0 || b < 0) return;
    view.selectBuilds(
      ids.sublist(math.min(a, b), math.max(a, b) + 1),
      anchor: from,
    );
  }

  void _tap(AnimateView view, BuildOrder order, String id) {
    _focus.requestFocus();
    final hw = HardwareKeyboard.instance;
    final ids = [for (final r in order.rows) r.id];
    if (hw.isShiftPressed && view.anchor != null) {
      _range(view, ids, view.anchor!, id);
    } else if (hw.isMetaPressed || hw.isControlPressed) {
      final sel = view.selectedBuildIds.toSet();
      if (!sel.remove(id)) sel.add(id);
      view.selectBuilds(sel, anchor: id);
    } else {
      view.selectBuilds([id]);
    }
  }

  // ----------------------------------------------------------- drag/drop

  List<String> _moving(AnimateView view, String id) {
    final sel = view.selectedBuildIds;
    return sel.contains(id) ? sel : [id];
  }

  void _dropOn(String target, bool before, List<String> moving, BuildOrder o) {
    setState(() => _drop = null);
    if (target.startsWith('step:')) {
      final k = int.parse(target.substring(5));
      final step = o.steps.firstWhere((s) => s.index == k);
      final first = step.rows.first.id;
      if (moving.length == 1 && moving.single == first) return;
      ed.invokeCommand('slides.animate.moveBuilds', {
        'buildIds': moving,
        'to': {'beforeBuildId': first},
        'trigger': k == 0 ? 'withPrevious' : 'onClick',
      });
      return;
    }
    if (moving.contains(target)) return;
    ed.invokeCommand('slides.animate.moveBuilds', {
      'buildIds': moving,
      'to': {before ? 'beforeBuildId' : 'afterBuildId': target},
    });
  }

  // ---------------------------------------------------------------- rows

  Widget _header(
    BuildContext context,
    BuildOrderStep s,
    BuildOrder order,
    bool canEdit,
  ) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final target = 'step:${s.index}';
    final hot = _drop?.$1 == target;
    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (_) => canEdit,
      onMove: (_) {
        if (!hot) setState(() => _drop = (target, true));
      },
      onLeave: (_) {
        if (hot) setState(() => _drop = null);
      },
      onAcceptWithDetails: (d) => _dropOn(target, true, d.data, order),
      builder: (context, _, _) => Container(
        key: OrderTabKeys.step(s.index),
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
        decoration: BoxDecoration(
          border: hot
              ? Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              s.index == 0 ? LucideIcons.zap : LucideIcons.mousePointerClick,
              size: 12,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  s.index == 0
                      ? l.animateStepAutomatic
                      : l.animateStepClick(s.index),
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (hot)
              Text(
                l.animateNewClick,
                style: theme.textTheme.small.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                ),
              )
            else if (s.durationMs > 0)
              Text(
                '${BuildLabels.seconds(s.durationMs)} s',
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    SlidesCommandUi ui,
    AnimateView view,
    BuildOrder order,
    BuildOrderStep step,
    BuildOrderRow r,
    Set<String> selected,
    bool canEdit,
  ) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final tokens = SlidesTokens.of(context);
    final b = r.build;
    final el = b.elementId == null ? null : ed.model.element(b.elementId!);
    final isSel = selected.contains(r.id);
    final color = tokens.buildKind(b.kind.name);
    final name = BuildLabels.element(l, el);
    final summary = BuildLabels.summary(l, b, parts: r.parts);
    final hot = _drop?.$1 == r.id ? _drop!.$2 : null;
    final expanded = _expanded.contains(r.id);
    final unsupported = EffectCatalog.byId(b.kind, b.effect) == null;

    final content = Container(
      key: OrderTabKeys.row(r.id),
      decoration: BoxDecoration(
        color: isSel ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          top: hot == true
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
          bottom: hot == false
              ? BorderSide(color: theme.colorScheme.primary, width: 2)
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 30,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(BuildLabels.trigger(l, b.trigger)),
            child: Icon(
              BuildLabels.triggerIcon(b.trigger),
              size: 13,
              color: theme.colorScheme.mutedForeground,
              semanticLabel: BuildLabels.trigger(l, b.trigger),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (el != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          BuildLabels.elementIcon(el.kind),
                          size: 12,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.muted.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (r.warning != null || unsupported)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ShadTooltip(
                builder: (_) => Text(
                  unsupported
                      ? l.animateEffectUnsupported
                      : l.animateWarning(r.warning!.code),
                ),
                child: Icon(
                  LucideIcons.triangleAlert,
                  size: 13,
                  color: tokens.buildEmphasis,
                ),
              ),
            ),
          const SizedBox(width: 4),
          _TimingBar(
            startMs: r.startMs,
            durationMs: r.durationMs,
            totalMs: math.max(step.durationMs, 1),
            color: color,
          ),
          if (r.parts > 1)
            ShadIconButton.ghost(
              width: 22,
              height: 22,
              iconSize: 12,
              semanticLabel: l.animateShowParts,
              icon: Icon(
                expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              ),
              onPressed: () => setState(() {
                if (!_expanded.remove(r.id)) _expanded.add(r.id);
              }),
            ),
        ],
      ),
    );

    final tappable = Semantics(
      selected: isSel,
      button: true,
      label: '$name, $summary, ${BuildLabels.trigger(l, b.trigger)}',
      excludeSemantics: true,
      onTap: () => _tap(view, order, r.id),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(view, order, r.id),
        child: content,
      ),
    );

    final draggable = !canEdit
        ? tappable
        : Draggable<List<String>>(
            key: OrderTabKeys.drag(r.id),
            data: _moving(view, r.id),
            // Vertical slop first, so a click still selects the row.
            affinity: Axis.vertical,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: () {
              if (!isSel) view.selectBuilds([r.id]);
            },
            onDragEnd: (_) => setState(() => _drop = null),
            feedback: _DragGhost(
              label: _moving(view, r.id).length > 1
                  ? l.animateBuildsSelected(_moving(view, r.id).length)
                  : '$name · ${BuildLabels.effect(l, b.effect)}',
              color: color,
            ),
            childWhenDragging: Opacity(opacity: 0.4, child: tappable),
            child: tappable,
          );

    final target = DragTarget<List<String>>(
      onWillAcceptWithDetails: (d) => canEdit && !d.data.contains(r.id),
      onMove: (d) {
        // Above or below the row's center.
        var before = true;
        final rows = _rowBoxes[r.id];
        if (rows != null && rows.attached) {
          final local = rows.globalToLocal(d.offset);
          before = local.dy < rows.size.height / 2;
        }
        if (_drop != (r.id, before)) setState(() => _drop = (r.id, before));
      },
      onLeave: (_) {
        if (_drop?.$1 == r.id) setState(() => _drop = null);
      },
      onAcceptWithDetails: (d) =>
          _dropOn(r.id, _drop?.$2 ?? true, d.data, order),
      builder: (context, _, _) =>
          _BoxReporter(onBox: (box) => _rowBoxes[r.id] = box, child: draggable),
    );

    final menu = WonkyContextMenuRegion(
      onOpen: () {
        if (!isSel) view.selectBuilds([r.id]);
      },
      entries: () => MenuResolver(widget.services).entries(context, [
        MenuSpec.command(
          'slides.animate.preview',
          args: {'fromBuildId': r.id},
          label: l.animatePreviewFromHere,
          id: 'animate.row.previewFrom',
        ),
        MenuSpec.submenu('animate.row.trigger', l.animateSetTrigger, [
          for (final t in const ['onClick', 'withPrevious', 'afterPrevious'])
            MenuSpec.command(
              'slides.animate.setTrigger',
              args: {'trigger': t},
              label: l.animateTriggerName(t),
              id: 'animate.row.trigger.$t',
            ),
        ]),
        MenuSpec.command(
          'slides.animate.moveBuilds',
          args: const {'by': -1},
          label: l.animateMoveUp,
          id: 'animate.row.up',
        ),
        MenuSpec.command(
          'slides.animate.moveBuilds',
          args: const {'by': 1},
          label: l.animateMoveDown,
          id: 'animate.row.down',
        ),
        MenuSpec.separator(),
        MenuSpec.command(
          'slides.animate.copyBuilds',
          args: {'elementId': ?b.elementId},
          id: 'animate.row.copy',
        ),
        MenuSpec.command(
          'slides.animate.deleteBuilds',
          id: 'animate.row.remove',
        ),
        MenuSpec.separator(),
        MenuSpec.command(
          'slides.animate.selectBuilds',
          args: {
            'buildIds': [r.id],
          },
          label: l.animateSelectObjectItem,
          id: 'animate.row.selectElement',
        ),
      ]),
      child: target,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [menu, if (expanded) ..._parts(context, b, el)],
    );
  }

  final Map<String, RenderBox> _rowBoxes = {};

  List<Widget> _parts(
    BuildContext context,
    SlideBuildRec b,
    SlideElementRec? e,
  ) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final by = BuildOptions.decode(b.optionsJson).value.delivery.by;
    if (e == null || !by.isText) return const [];
    final plain = core.SlidesText.plainText(e.text);
    final parts = TextParts.of(MotionText(plain), by);
    return [
      for (final (i, p) in parts.take(50).indexed)
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 1, 4, 1),
          child: Text(
            l.animatePartLabel(
              i + 1,
              plain.substring(p.start, p.end).trim().replaceAll('\n', ' '),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.muted.copyWith(fontSize: 11),
          ),
        ),
    ];
  }
}

/// Reports its render box (drop position inside a row).
class _BoxReporter extends SingleChildRenderObjectWidget {
  const _BoxReporter({required this.onBox, super.child});

  final ValueChanged<RenderBox> onBox;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBoxReporter(onBox);

  @override
  void updateRenderObject(BuildContext context, _RenderBoxReporter r) {
    r.onBox = onBox;
  }
}

class _RenderBoxReporter extends RenderProxyBox {
  _RenderBoxReporter(this.onBox);

  ValueChanged<RenderBox> onBox;

  @override
  void performLayout() {
    super.performLayout();
    onBox(this);
  }
}

/// The start/duration of a build on its step's time scale (06 §5.4).
class _TimingBar extends StatelessWidget {
  const _TimingBar({
    required this.startMs,
    required this.durationMs,
    required this.totalMs,
    required this.color,
  });

  final int startMs, durationMs, totalMs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    const w = 44.0;
    final x = (startMs / totalMs).clamp(0.0, 1.0) * w;
    final dw = math.max(2.0, (durationMs / totalMs).clamp(0.0, 1.0) * w);
    return ExcludeSemantics(
      child: Container(
        width: w,
        height: 8,
        decoration: BoxDecoration(
          color: theme.colorScheme.muted,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            Positioned(
              left: math.min(x, w - dw),
              top: 0,
              bottom: 0,
              width: dw,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.popover,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
      ),
      child: Text(
        label,
        style: theme.textTheme.small.copyWith(
          decoration: TextDecoration.none,
          fontSize: 12,
        ),
      ),
    );
  }
}
