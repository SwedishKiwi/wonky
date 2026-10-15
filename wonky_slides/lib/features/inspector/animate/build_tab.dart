import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/charts.dart' show SlideChartMotion;
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/slides_l10n.dart';
import '../../../theme/slides_tokens.dart';
import '../../builds/animate_preview.dart';
import '../../builds/animate_view.dart';
import '../../builds/build_labels.dart';
import '../../builds/build_recipes.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../elements/style/element_style.dart';
import '../../elements/style/style_sections.dart';
import '../../settings/slides_user_defaults.dart';
import '../../toolbar/command_ui.dart';
import 'animate_controls.dart';
import 'effect_tiles.dart';
import 'transition_tab.dart' show easingSelect;

/// Inspector › Animate › **Build** (Slides 06 §5.2, §5.3): the builds of
/// the selected object(s) by kind (*In* / *Action* / *Out* with counts),
/// the effect grid (search, hover previews on the canvas, Alt-click =
/// *With previous*), and for the edited build its effect parameters,
/// delivery (parts, order, after-build dim/hide), timing (start, delay,
/// duration, easing), repeat and persistence, *Add another build*,
/// *Remove* and — for code blocks and charts — *Build all steps*.
class BuildTab extends StatefulWidget {
  const BuildTab({super.key, required this.services, required this.editor});

  final ShellServices services;
  final DeckEditorController editor;

  @override
  State<BuildTab> createState() => _BuildTabState();
}

class _BuildTabState extends State<BuildTab> {
  final _search = TextEditingController();
  String _query = '';

  DeckEditorController get ed => widget.editor;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SlideElementRec> _elements() {
    final slideId = ed.currentSlideId;
    if (slideId == null || ed.editsMasters) return const [];
    return [
      for (final id in ed.selectedElementIds)
        if (ed.model.element(id) case final e?
            when e.slideId == slideId && e.parentId == null)
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final ui = SlidesCommandUi(context, widget.services);
    final view = AnimateView.of(ed);
    final els = _elements();
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
    if (els.isEmpty) return _empty(context, view, slideId);

    final tab = view.kindTab;
    final ids = {for (final e in els) e.id};
    final builds = ed.model.buildsOf(slideId);
    int count(BuildKindTab t) => builds
        .where((b) => ids.contains(b.elementId) && t.contains(b.kind))
        .length;
    final edited = view.editedBuilds();
    final enabled = ui.state('slides.animate.addBuild', {
      'elementIds': [for (final e in els) e.id],
      'kind': 'in',
      'effect': 'fade',
    }).enabled;
    final tokens = SlidesTokens.of(context);

    // Builds of this kind on a single selected element (chips 1 · 2 · +).
    final mine = els.length == 1
        ? [
            for (final b in builds)
              if (b.elementId == els.single.id && tab.contains(b.kind)) b,
          ]
        : const <SlideBuildRec>[];

    return Column(
      key: const ValueKey<String>('slides.animate.buildTab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          els.length == 1
              ? BuildLabels.element(l, els.single)
              : l.animateObjectsSelected(els.length),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final t in BuildKindTab.values)
              Expanded(
                child: Semantics(
                  selected: t == tab,
                  button: true,
                  child: ShadButton.ghost(
                    key: ValueKey<String>('slides.animate.kind.${t.name}'),
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: t == tab ? theme.colorScheme.muted : null,
                    onPressed: () => setState(() => view.kindTab = t),
                    child: Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: tokens.buildKind(t.kinds.first.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${l.animateKindTab(t.name)} · ${count(t)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                fontWeight: t == tab
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (mine.length > 1) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (i, b) in mine.indexed)
                Semantics(
                  selected: edited.any((e) => e.id == b.id),
                  child: ShadButton.outline(
                    key: ValueKey<String>('slides.animate.buildChip.${b.id}'),
                    size: ShadButtonSize.sm,
                    backgroundColor: edited.any((e) => e.id == b.id)
                        ? theme.colorScheme.muted
                        : null,
                    onPressed: () => setState(() => view.selectBuilds([b.id])),
                    child: Text(
                      '${i + 1} · ${BuildLabels.effect(l, b.effect)}',
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        ShadInput(
          key: const ValueKey<String>('slides.animate.search'),
          controller: _search,
          placeholder: Text(l.animateSearchEffects),
          leading: const Icon(LucideIcons.search, size: 14),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        EffectTileGrid(
          keyPrefix: 'slides.animate.tile',
          sections: _sections(l, tokens, tab, els, edited, enabled),
          onSelected: (id, {required alt}) =>
              _choose(ui, view, tab, els, edited, id, alt),
          onPreview: (id) => _hover(view, slideId, tab, els, id),
        ),
        if (edited.isNotEmpty)
          _BuildDetails(
            services: widget.services,
            editor: ed,
            builds: edited,
            elements: els,
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (edited.isNotEmpty)
              _cmd(
                ui,
                'slides.animate.addBuild',
                args: {
                  'elementIds': [for (final e in els) e.id],
                  'kind': tab.kinds.first.name,
                  'effect': edited.first.effect,
                  'trigger': 'afterPrevious',
                },
                icon: LucideIcons.plus,
                label: l.animateAddAnother,
              ),
            if (els.length == 1 &&
                BuildRecipes.allSteps(ed.model, els.single.id) != null)
              _cmd(
                ui,
                'slides.animate.buildAllSteps',
                args: {'elementId': els.single.id},
                icon: LucideIcons.listOrdered,
              ),
            if (els.length == 1)
              _cmd(
                ui,
                'slides.animate.copyBuilds',
                args: {'elementId': els.single.id},
                icon: LucideIcons.paintbrush,
              ),
            _cmd(
              ui,
              'slides.animate.pasteBuilds',
              args: {
                'elementIds': [for (final e in els) e.id],
              },
              icon: LucideIcons.clipboardPaste,
            ),
          ],
        ),
      ],
    );
  }

  Widget _empty(BuildContext context, AnimateView view, String slideId) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final animated = <String>{};
    final rows = <SlideElementRec>[];
    for (final b in ed.model.buildsOf(slideId)) {
      final e = b.elementId == null ? null : ed.model.element(b.elementId!);
      if (e != null && animated.add(e.id)) rows.add(e);
    }
    return Column(
      key: const ValueKey<String>('slides.animate.buildEmpty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Icon(
          LucideIcons.mousePointerClick,
          size: 28,
          color: theme.colorScheme.mutedForeground,
        ),
        const SizedBox(height: 8),
        Text(
          l.animateSelectObject,
          textAlign: TextAlign.center,
          style: theme.textTheme.muted,
        ),
        if (rows.isNotEmpty) ...[
          AnimateHeading(l.animateAnimatedObjects),
          for (final e in rows)
            ShadButton.ghost(
              key: ValueKey<String>('slides.animate.animated.${e.id}'),
              size: ShadButtonSize.sm,
              mainAxisAlignment: MainAxisAlignment.start,
              leading: Icon(BuildLabels.elementIcon(e.kind), size: 14),
              onPressed: () => ed.invokeCommand('slides.animate.selectBuilds', {
                'buildIds': [
                  for (final b in ed.model.buildsOf(slideId))
                    if (b.elementId == e.id) b.id,
                ].take(1).toList(),
              }, InvocationSource.ui),
              child: Flexible(
                child: Text(
                  BuildLabels.element(l, e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ],
    );
  }

  List<EffectTileSection> _sections(
    SlidesLocalizations l,
    SlidesTokens tokens,
    BuildKindTab tab,
    List<SlideElementRec> els,
    List<SlideBuildRec> edited,
    bool enabled,
  ) {
    final kinds = {for (final e in els) e.kind};
    final current = edited.isEmpty ? null : edited.first.effect;
    final same = edited.every((b) => b.effect == current);
    final groups = <String, List<EffectTileData>>{};
    for (final k in tab.kinds) {
      for (final e in EffectCatalog.all) {
        if (e.kind != k || !e.available) continue;
        // Chart and code effects only when such an object is selected.
        if ((e.target == EffectTarget.chart ||
                e.target == EffectTarget.chart3d) &&
            !kinds.contains(ElementKind.chart)) {
          continue;
        }
        if (e.target == EffectTarget.code &&
            !kinds.contains(ElementKind.code)) {
          continue;
        }
        final name = BuildLabels.effect(l, e.id);
        if (_query.isNotEmpty && !name.toLowerCase().contains(_query)) {
          continue;
        }
        final fits = kinds.every(e.target.accepts);
        (groups[e.group] ??= []).add(
          EffectTileData(
            id: e.id,
            label: name,
            description: '$name: ${BuildLabels.effectDescription(l, e.id)}',
            icon: BuildLabels.effectIcon(e.id),
            enabled: enabled && fits,
            disabledReason: fits ? null : BuildLabels.targetReason(l, e),
            selected: same && e.id == current,
            color: tokens.buildKind(k.name),
          ),
        );
      }
    }
    const order = [
      'basic',
      'exciting',
      'emphasis',
      'text',
      'shape',
      'motion',
      'chart',
      'code',
    ];
    return [
      for (final g in order)
        if (groups[g] case final tiles?)
          EffectTileSection(BuildLabels.group(l, g), tiles),
    ];
  }

  SlideBuildKind _kindOf(BuildKindTab tab, String effect) {
    for (final k in tab.kinds) {
      if (EffectCatalog.byId(k, effect) != null) return k;
    }
    return tab.kinds.first;
  }

  void _choose(
    SlidesCommandUi ui,
    AnimateView view,
    BuildKindTab tab,
    List<SlideElementRec> els,
    List<SlideBuildRec> edited,
    String effect,
    bool alt,
  ) {
    view.preview.stop();
    final kind = _kindOf(tab, effect);
    if (edited.isNotEmpty) {
      ui.run('slides.animate.updateBuild', {
        'buildIds': [for (final b in edited) b.id],
        'patch': {'effect': effect, 'kind': kind.name},
      }, InvocationSource.ui);
    } else {
      ui.run('slides.animate.addBuild', {
        'elementIds': [for (final e in els) e.id],
        'kind': kind.name,
        'effect': effect,
        if (alt) 'alt': true,
      }, InvocationSource.ui);
    }
  }

  void _hover(
    AnimateView view,
    String slideId,
    BuildKindTab tab,
    List<SlideElementRec> els,
    String? effect,
  ) {
    if (effect == null) {
      if (view.preview.kind == PreviewKind.effect) view.preview.stop();
      return;
    }
    final on = SlidesUserDefaults.of(
      widget.services,
    ).flag(SlidesUserDefaults.keyPreviewOnHover);
    if (!on) return;
    final kind = _kindOf(tab, effect);
    final spec = EffectCatalog.byId(kind, effect);
    if (spec == null || !els.every((e) => spec.target.accepts(e.kind))) return;
    view.preview.playEffect(
      slideId,
      [for (final e in els) e.id],
      kind: kind,
      effect: effect,
      key: effect,
    );
  }
}

Widget _cmd(
  SlidesCommandUi ui,
  String id, {
  Map<String, Object?> args = const {},
  IconData? icon,
  String? label,
}) {
  final st = ui.state(id, args);
  final b = ShadButton.outline(
    key: ValueKey<String>('slides.animate.cmd.$id'),
    size: ShadButtonSize.sm,
    enabled: st.enabled,
    leading: icon == null ? null : Icon(icon, size: 14),
    onPressed: () => ui.run(id, args, InvocationSource.ui),
    child: Flexible(
      child: Text(
        label ?? ui.title(id),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  final reason = st.disabledReason;
  if (st.enabled || reason == null) return b;
  return ShadTooltip(builder: (_) => Text(reason), child: b);
}

/// The edited build(s): parameters, delivery, timing, repeat.
class _BuildDetails extends StatelessWidget {
  const _BuildDetails({
    required this.services,
    required this.editor,
    required this.builds,
    required this.elements,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final List<SlideBuildRec> builds;
  final List<SlideElementRec> elements;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final ui = SlidesCommandUi(context, services);
    final view = AnimateView.of(editor);
    final first = builds.first;
    final spec = EffectCatalog.byId(first.kind, first.effect);
    final ids = [for (final b in builds) b.id];
    final enabled = ui.state('slides.animate.updateBuild', {
      'buildIds': ids,
      'patch': const <String, Object?>{},
    }).enabled;
    final opts = BuildOptions.decode(first.optionsJson).value;
    final order = view.orderOf(first.slideId!);
    final row = order.rowOf(first.id);

    void update(Map<String, Object?> patch, {String? coalesce}) => ui.run(
      'slides.animate.updateBuild',
      {'buildIds': ids, 'patch': patch, 'coalesceKey': ?coalesce},
      InvocationSource.ui,
    );
    void options(Map<String, Object?> patch, String coalesce) =>
        update({'options': patch}, coalesce: coalesce);

    T? common<T>(T Function(SlideBuildRec b) f) {
      final v = f(first);
      return builds.every((b) => f(b) == v) ? v : null;
    }

    final children = <Widget>[];

    // ---- header: effect, ▶, remove
    children.add(
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                builds.length > 1
                    ? l.animateBuildsSelected(builds.length)
                    : spec == null
                    ? l.animateEffectUnsupported
                    : BuildLabels.effect(l, first.effect),
                key: const ValueKey<String>('slides.animate.editedEffect'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ShadTooltip(
              builder: (_) => Text(l.animatePreview),
              child: ShadIconButton.ghost(
                key: const ValueKey<String>('slides.animate.previewBuild'),
                width: 28,
                height: 28,
                iconSize: 14,
                semanticLabel: l.animatePreview,
                icon: const Icon(LucideIcons.play),
                onPressed: () => ui.run('slides.animate.preview', {
                  'buildIds': ids,
                }, InvocationSource.ui),
              ),
            ),
            ShadTooltip(
              builder: (_) => Text(ui.title('slides.animate.deleteBuilds')),
              child: ShadIconButton.ghost(
                key: const ValueKey<String>('slides.animate.removeBuild'),
                width: 28,
                height: 28,
                iconSize: 14,
                enabled: enabled,
                semanticLabel: ui.title('slides.animate.deleteBuilds'),
                icon: const Icon(LucideIcons.trash2),
                onPressed: () => ui.run('slides.animate.deleteBuilds', {
                  'buildIds': ids,
                }, InvocationSource.ui),
              ),
            ),
          ],
        ),
      ),
    );
    final warning = row?.warning;
    if (warning != null || spec == null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                size: 14,
                color: SlidesTokens.of(context).buildEmphasis,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  spec == null
                      ? l.animateEffectUnsupported
                      : l.animateWarning(warning!.code),
                  key: const ValueKey<String>('slides.animate.buildWarning'),
                  style: theme.textTheme.small,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ---- effect parameters
    if (spec != null && builds.every((b) => b.effect == first.effect)) {
      final themeRec = ElementStyle.themeOf(editor);
      for (final p in spec.params) {
        if (p.key == 'path' || p.key == 'preset' || p.key == 'to') continue;
        if (p.key == 'target' && spec.id == 'chartHighlight') {
          children.add(_chartTarget(context, opts, spec, update));
          continue;
        }
        final control = paramControl(
          context,
          spec: p,
          value: opts.params[p.key],
          keyPrefix: 'param',
          theme: themeRec,
          enabled: enabled,
          onChanged: (v) => options({
            'params': {p.key: v},
          }, 'param.${p.key}'),
        );
        if (control != null) {
          children.add(
            InspectorRow(label: BuildLabels.param(l, p.key), child: control),
          );
        }
      }
      if (spec.id == 'path') children.add(_motionPath(context, ui, opts, spec));
      if (spec.id == 'moveTo') children.add(_transform(context, ui, opts));
    }

    // ---- delivery
    final deliveries = _deliveries(first, spec);
    if (deliveries.length > 1) {
      final d = opts.delivery;
      children.add(AnimateHeading(l.animateDelivery));
      children.add(
        InspectorRow(
          label: l.animateDeliveryLabel,
          child: StyleSelect<DeliveryBy>(
            keyName: 'animate.delivery',
            value: d.by,
            options: deliveries,
            enabled: enabled,
            label: (b) => BuildLabels.delivery(l, b),
            onChanged: (b) => options({
              'delivery': {'by': b.name},
            }, 'delivery'),
          ),
        ),
      );
      if (d.by != DeliveryBy.all) {
        children.addAll([
          InspectorRow(
            label: l.animatePartOrder,
            child: StyleSelect<PartOrder>(
              keyName: 'animate.partOrder',
              value: d.order,
              options: PartOrder.values,
              enabled: enabled,
              label: (o) => l.animateOrderName(o.name),
              onChanged: (o) => options({
                'delivery': {'order': o.name},
              }, 'delivery.order'),
            ),
          ),
          InspectorRow(
            label: l.animatePartsFrom,
            child: WonkyNumberStepper(
              key: const ValueKey<String>('slides.animate.partsFrom'),
              value: d.from,
              min: 1,
              max: 2000,
              enabled: enabled,
              semanticLabel: l.animatePartsFrom,
              onChanged: (v) => options({
                'delivery': {
                  'parts': {'from': v.round(), 'to': d.to},
                },
              }, 'delivery.parts'),
            ),
          ),
          InspectorRow(
            label: l.animatePartsTo,
            child: WonkyNumberStepper(
              key: const ValueKey<String>('slides.animate.partsTo'),
              value: d.to,
              min: 1,
              max: 2000,
              enabled: enabled,
              semanticLabel: l.animatePartsTo,
              onChanged: (v) => options({
                'delivery': {
                  'parts': {'from': d.from, 'to': v.round()},
                },
              }, 'delivery.parts'),
            ),
          ),
          InspectorRow(
            label: l.animatePartStart,
            child: StyleSelect<SlideBuildTrigger>(
              keyName: 'animate.partTrigger',
              value: d.effectivePartTrigger(first.kind),
              options: const [
                SlideBuildTrigger.onClick,
                SlideBuildTrigger.withPrevious,
                SlideBuildTrigger.afterPrevious,
              ],
              enabled: enabled,
              label: (t) => BuildLabels.trigger(l, t),
              onChanged: (t) => options({
                'delivery': {'partTrigger': t.name},
              }, 'delivery.partTrigger'),
            ),
          ),
          if (d.effectivePartTrigger(first.kind) != SlideBuildTrigger.onClick)
            InspectorRow(
              label: l.animateStaggerParts,
              child: SecondsField(
                key: const ValueKey<String>('slides.animate.stagger'),
                ms: d.effectiveStaggerMs(first.kind, first.durationMs),
                maxMs: 10000,
                step: 0.05,
                enabled: enabled,
                semanticLabel: l.animateStaggerParts,
                onChanged: (ms) => options({
                  'delivery': {'staggerMs': ms},
                }, 'delivery.stagger'),
              ),
            ),
          if (first.kind == SlideBuildKind.buildIn && d.by.isText) ...[
            InspectorRow(
              label: l.animateAfterBuild,
              child: StyleSelect<AfterBuildMode>(
                keyName: 'animate.afterBuild',
                value: opts.afterBuild.mode,
                options: AfterBuildMode.values,
                enabled: enabled,
                label: (m) => l.animateAfterBuildName(m.name),
                onChanged: (m) => options({
                  'afterBuild': {'mode': m.name},
                }, 'afterBuild'),
              ),
            ),
            if (opts.afterBuild.mode == AfterBuildMode.dim)
              InspectorRow(
                label: l.animateDimTo,
                child: CommitSlider(
                  key: const ValueKey<String>('slides.animate.dimOpacity'),
                  value: opts.afterBuild.dimOpacity,
                  enabled: enabled,
                  onCommit: (v) => options({
                    'afterBuild': {'dimOpacity': v},
                  }, 'afterBuild.dim'),
                ),
              ),
          ],
        ]);
      }
    }

    // ---- timing
    final trigger = common((b) => b.trigger);
    final derived = spec?.derivedDuration ?? false;
    final easing = common((b) => b.easing);
    final duration = common((b) => b.durationMs);
    final curve = easing == null ? null : MotionEasing.tryParse(easing);
    children.addAll([
      AnimateHeading(l.animateTiming),
      InspectorRow(
        label: l.animateStart,
        child: StyleSelect<SlideBuildTrigger>(
          keyName: 'animate.trigger',
          value: trigger,
          options: const [
            SlideBuildTrigger.onClick,
            SlideBuildTrigger.withPrevious,
            SlideBuildTrigger.afterPrevious,
          ],
          placeholder: '—',
          enabled: enabled,
          label: (t) => BuildLabels.trigger(l, t),
          onChanged: (t) => ui.run('slides.animate.setTrigger', {
            'buildIds': ids,
            'trigger': t.name,
          }, InvocationSource.ui),
        ),
      ),
      InspectorRow(
        label: l.animateDelay,
        child: SecondsField(
          key: const ValueKey<String>('slides.animate.delay'),
          ms: common((b) => b.delayMs),
          maxMs: 60000,
          enabled: enabled,
          semanticLabel: l.animateDelay,
          onChanged: (ms) => update({'delayMs': ms}, coalesce: 'delay'),
        ),
      ),
      InspectorRow(
        label: l.animateDuration,
        child: derived
            ? Text(
                l.animateDurationAutomatic,
                key: const ValueKey<String>('slides.animate.durationAuto'),
                style: theme.textTheme.muted,
              )
            : SecondsField(
                key: const ValueKey<String>('slides.animate.duration'),
                ms: duration,
                enabled: enabled,
                semanticLabel: l.animateDuration,
                onChanged: (ms) =>
                    update({'durationMs': ms}, coalesce: 'duration'),
              ),
      ),
      if (!derived)
        InspectorRow(
          label: l.animateEasing,
          child: easingSelect(
            keyName: 'animate.easing',
            expression: easing,
            durationMs: duration ?? first.durationMs,
            enabled: enabled,
            onChanged: (e) => update({'easing': e}),
          ),
        ),
      if (curve is SpringEasing)
        Padding(
          padding: const EdgeInsets.only(left: 92, bottom: 8),
          child: Text(
            l.animateSettles(
              BuildLabels.seconds((curve.settleSeconds * 1000).round()),
            ),
            key: const ValueKey<String>('slides.animate.settle'),
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
        ),
    ]);

    // ---- repeat (transient emphasis) and persistence
    if (spec?.persistence == EffectPersistence.transient) {
      final r = opts.repeat;
      children.addAll([
        AnimateHeading(l.animateRepeat),
        InspectorRow(
          label: l.animateRepeatCount,
          child: WonkyNumberStepper(
            key: const ValueKey<String>('slides.animate.repeatCount'),
            value: r.count,
            min: 1,
            max: 20,
            enabled: enabled && !r.untilNextClick,
            semanticLabel: l.animateRepeatCount,
            onChanged: (v) => options({
              'repeat': {'count': v.round()},
            }, 'repeat.count'),
          ),
        ),
        AnimateSwitch(
          keyName: 'repeatUntilClick',
          label: l.animateUntilNextClick,
          value: r.untilNextClick,
          enabled: enabled,
          onChanged: (v) => options({
            'repeat': {'untilNextClick': v},
          }, 'repeat.until'),
        ),
        AnimateSwitch(
          keyName: 'repeatAutoReverse',
          label: l.animateAutoReverse,
          value: r.autoReverse,
          enabled: enabled,
          onChanged: (v) => options({
            'repeat': {'autoReverse': v},
          }, 'repeat.reverse'),
        ),
      ]);
    } else if (spec?.persistence == EffectPersistence.persistent &&
        first.kind == SlideBuildKind.emphasis &&
        spec!.target != EffectTarget.code) {
      children.add(
        AnimateSwitch(
          keyName: 'persist',
          label: l.animateReturnToStart,
          value: opts.persist == false,
          enabled: enabled,
          onChanged: (v) => options({'persist': v ? false : null}, 'persist'),
        ),
      );
    }

    return Column(
      key: const ValueKey<String>('slides.animate.buildDetails'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// The deliveries the build can use (06 §2.3): text deliveries for text
  /// in/out builds and the part-based emphasis, chart deliveries for chart
  /// builds; code builds don't use delivery.
  List<DeliveryBy> _deliveries(SlideBuildRec b, EffectSpec? spec) {
    final e = editor.model.element(b.elementId ?? '');
    if (e == null || spec == null) return const [];
    final partEmphasis = const {
      'highlight',
      'pulse',
      'bounce',
      'shake',
      'blink',
    }.contains(spec.id);
    if (b.kind == SlideBuildKind.motion) return const [];
    if (b.kind == SlideBuildKind.emphasis && !partEmphasis) return const [];
    if (e.kind == ElementKind.chart) {
      if (spec.target != EffectTarget.chart &&
          b.kind == SlideBuildKind.emphasis) {
        return const [];
      }
      return const [
        DeliveryBy.all,
        DeliveryBy.series,
        DeliveryBy.category,
        DeliveryBy.point,
        DeliveryBy.chartElement,
      ];
    }
    if (e.kind.hasText) {
      return const [
        DeliveryBy.all,
        DeliveryBy.paragraph,
        DeliveryBy.paragraphGroup,
        DeliveryBy.word,
        DeliveryBy.character,
      ];
    }
    return const [];
  }

  Widget _chartTarget(
    BuildContext context,
    BuildOptions opts,
    EffectSpec spec,
    void Function(Map<String, Object?> patch, {String? coalesce}) update,
  ) {
    final l = slidesL10n(context);
    final e = editor.model.element(builds.first.elementId ?? '');
    final shape = e == null ? null : SlideChartMotion.shapeOf(e, editor.model);
    final keys = shape?.seriesKeys ?? const <String>[];
    final target = opts.params['target'];
    final current = target is Map ? target['series'] as String? : null;
    return InspectorRow(
      label: l.animateParamName('target'),
      child: StyleSelect<String>(
        keyName: 'animate.chartTarget',
        value: current,
        options: keys,
        placeholder: '—',
        label: (k) => k,
        onChanged: (k) => update({
          'options': {
            'params': {
              'target': {'series': k},
            },
          },
        }),
      ),
    );
  }

  Widget _motionPath(
    BuildContext context,
    SlidesCommandUi ui,
    BuildOptions opts,
    EffectSpec spec,
  ) {
    final l = slidesL10n(context);
    final preset = opts.params['preset'] as String?;
    final id = builds.first.id;
    return InspectorRow(
      label: l.animatePathPreset,
      child: StyleSelect<String>(
        keyName: 'animate.pathPreset',
        value: preset ?? 'custom',
        options: [...MotionPaths.presets, 'custom'],
        label: l.animateChoiceName,
        onChanged: (p) {
          if (p == 'custom') return;
          ui.run('slides.animate.setMotionPath', {
            'buildId': id,
            'preset': p,
          }, InvocationSource.ui);
        },
      ),
    );
  }

  Widget _transform(
    BuildContext context,
    SlidesCommandUi ui,
    BuildOptions opts,
  ) {
    final l = slidesL10n(context);
    final b = builds.first;
    final e = editor.model.element(b.elementId ?? '');
    final to = opts.params['to'] is Map
        ? {
            for (final x in (opts.params['to'] as Map).entries)
              '${x.key}': x.value,
          }
        : <String, Object?>{};
    final f = e?.frame;
    Widget field(String key, String label, num? authored, {num step = 10}) =>
        InspectorRow(
          label: label,
          child: WonkyNumberStepper(
            key: ValueKey<String>('slides.animate.to.$key'),
            value: (to[key] as num?) ?? authored,
            min: key == 'opacity' ? 0 : -100000,
            max: key == 'opacity' ? 1 : 100000,
            step: step,
            fractionDigits: key == 'opacity' ? 2 : 0,
            semanticLabel: label,
            onChanged: (v) => ui.run('slides.animate.setTransformTarget', {
              'buildId': b.id,
              'to': {...to, key: v},
            }, InvocationSource.ui),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimateHeading(l.animateEndState),
        field('x', 'X', f?.x),
        field('y', 'Y', f?.y),
        field('w', l.animateWidth, f?.width),
        field('h', l.animateHeight, f?.height),
        field(
          'rotation',
          l.animateParamName('rotation'),
          e?.rotation ?? 0,
          step: 5,
        ),
        field(
          'opacity',
          l.animateParamName('opacity'),
          e?.opacity ?? 1,
          step: 0.05,
        ),
      ],
    );
  }
}
