import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;
import 'package:wonky_slides_core/motion.dart';

import '../../../l10n/slides_l10n.dart';
import '../../builds/animate_preview.dart';
import '../../builds/animate_view.dart';
import '../../builds/build_labels.dart';
import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../elements/style/element_style.dart';
import '../../elements/style/style_sections.dart';
import '../../motion/motion_stage.dart';
import '../../motion/player/slide_player.dart';
import '../../toolbar/command_ui.dart';
import 'animate_controls.dart';
import 'effect_tiles.dart';

/// Inspector › Animate › **Transition** (Slides 06 §5.1, §7, §8.6): the
/// transition into the current slide (or every selected slide): effect
/// grid with live previews of the actual previous → current slide, the
/// transition's options (direction pad, duration, easing, the Magic Move
/// options with the match count), how the slide advances, *Preview*,
/// *Apply to all slides*.
class TransitionTab extends StatelessWidget {
  const TransitionTab({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final DeckEditorController editor;

  DeckEditorController get ed => editor;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final ui = SlidesCommandUi(context, services);
    final slideId = ed.currentSlideId;
    final slide = slideId == null ? null : ed.model.slide(slideId);
    if (slide == null || ed.editsMasters) {
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
    final ids = _slides();
    final spec = TransitionSpec.effective(
      slide.transitionJson,
      ed.model.deck?.defaultsJson,
    );
    final mixed = ids.any(
      (id) =>
          TransitionSpec.effective(
            ed.model.slide(id)?.transitionJson,
            ed.model.deck?.defaultsJson,
          ).type !=
          spec.type,
    );
    final inherited = slide.transitionJson == null;
    final enabled = ui.state('slides.transition.set', {
      'slideIds': ids,
      'transition': const <String, Object?>{},
    }).enabled;

    void set(Map<String, Object?> patch) => ui.run('slides.transition.set', {
      'slideIds': ids,
      'transition': patch,
    }, InvocationSource.ui);

    final info = TransitionInfo.of(spec.type);
    final typeSpec = spec.typeSpec;
    final prev = view.previousSlideOf(slideId!);

    final tiles = [
      for (final g in TransitionGroup.values)
        EffectTileSection(BuildLabels.group(l, g.name), [
          for (final t in TransitionInfo.inGroup(g))
            EffectTileData(
              id: t.id,
              label: BuildLabels.transition(l, t.id),
              description: BuildLabels.transitionDescription(l, t.id),
              icon: BuildLabels.transitionIcon(t.id),
              enabled: enabled,
              selected: !mixed && t.id == spec.type,
            ),
        ]),
    ];

    return Column(
      key: const ValueKey<String>('slides.animate.transitionTab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ids.length > 1
              ? l.animateTransitionForSlides(ids.length)
              : l.animateTransitionForSlide(
                  (ed.order.entry(slideId)?.index ?? 0) + 1,
                ),
          style: theme.textTheme.small,
        ),
        if (inherited && !spec.isNone)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.animateTransitionInherited,
              key: const ValueKey<String>('slides.animate.transitionInherited'),
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ),
        EffectTileGrid(
          keyPrefix: 'slides.animate.transition.tile',
          sections: tiles,
          onSelected: (id, {required alt}) => set({'type': id}),
          previewBuilder: SlideCanvasController.of(ed) == null
              ? null
              : (id) => TransitionTilePreview(
                  key: ValueKey<String>('slides.animate.transition.live.$id'),
                  view: view,
                  slideId: slideId,
                  fromSlideId: prev ?? slideId,
                  spec: TransitionSpec.of(id),
                ),
        ),
        if (!spec.isNone && !mixed) ...[
          AnimateHeading(BuildLabels.transition(l, spec.type)),
          if (info != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                BuildLabels.transitionDescription(l, spec.type),
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ),
          InspectorRow(
            label: l.animateDuration,
            child: SecondsField(
              key: const ValueKey<String>('slides.animate.transition.duration'),
              ms: spec.durationMs,
              minMs: 100,
              maxMs: 10000,
              enabled: enabled,
              semanticLabel: l.animateDuration,
              onChanged: (ms) => set({'durationMs': ms}),
            ),
          ),
          InspectorRow(
            label: l.animateEasing,
            child: _EasingSelect(
              keyName: 'transition.easing',
              expression: spec.easing,
              durationMs: spec.durationMs,
              enabled: enabled,
              onChanged: (e) => set({'easing': e}),
            ),
          ),
          for (final p in typeSpec?.params ?? const <ParamSpec>[])
            if (paramControl(
                  context,
                  spec: p,
                  value: spec.params[p.key],
                  keyPrefix: 'transition',
                  theme: ElementStyle.themeOf(ed),
                  enabled: enabled,
                  onChanged: (v) => set({
                    'params': {p.key: v},
                  }),
                )
                case final control?)
              InspectorRow(label: BuildLabels.param(l, p.key), child: control),
          if (spec.type == 'magicMove')
            _MagicMoveOptions(
              services: services,
              editor: ed,
              spec: spec,
              previousSlideId: prev,
              enabled: enabled,
              set: set,
            ),
          AnimateSwitch(
            keyName: 'transition.reverseOnBack',
            label: l.animateReverseOnBack,
            value: spec.reverseOnBack,
            enabled: enabled,
            onChanged: (v) => set({'reverseOnBack': v}),
          ),
        ],
        AnimateHeading(l.animateAdvance),
        SegmentedChoice<bool>(
          keyName: 'transition.advance',
          value: spec.advance.auto,
          options: const [false, true],
          enabled: enabled,
          label: (auto) => auto ? l.animateAdvanceAuto : l.animateAdvanceClick,
          onChanged: (auto) => ui.run('slides.transition.setAdvance', {
            'slideIds': ids,
            'advance': {'mode': auto ? 'auto' : 'onClick'},
          }, InvocationSource.ui),
        ),
        if (spec.advance.auto) ...[
          const SizedBox(height: 8),
          InspectorRow(
            label: l.animateAdvanceAfter,
            child: SecondsField(
              key: const ValueKey<String>('slides.animate.transition.afterMs'),
              ms: spec.advance.afterMs,
              maxMs: 600000,
              step: 0.5,
              enabled: enabled,
              onChanged: (ms) => ui.run('slides.transition.setAdvance', {
                'slideIds': ids,
                'advance': {'afterMs': ms},
              }, InvocationSource.ui),
            ),
          ),
          AnimateSwitch(
            keyName: 'transition.autoBuilds',
            label: l.animateAutoBuilds,
            value: spec.advance.autoBuilds,
            enabled: enabled,
            onChanged: (v) => ui.run('slides.transition.setAdvance', {
              'slideIds': ids,
              'advance': {'autoBuilds': v},
            }, InvocationSource.ui),
          ),
          if (spec.advance.autoBuilds)
            InspectorRow(
              label: l.animateBuildDelay,
              child: SecondsField(
                key: const ValueKey<String>(
                  'slides.animate.transition.buildDelay',
                ),
                ms: spec.advance.buildDelayMs,
                maxMs: 60000,
                step: 0.5,
                enabled: enabled,
                onChanged: (ms) => ui.run('slides.transition.setAdvance', {
                  'slideIds': ids,
                  'advance': {'buildDelayMs': ms},
                }, InvocationSource.ui),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _button(
              ui,
              'slides.transition.preview',
              icon: LucideIcons.play,
              label: l.animatePreview,
            ),
            _button(ui, 'slides.transition.applyToAll'),
            if (!spec.isNone)
              _button(
                ui,
                'slides.transition.remove',
                args: {'slideIds': ids},
                label: l.animateRemoveTransition,
              ),
          ],
        ),
      ],
    );
  }

  List<String> _slides() {
    final cur = ed.currentSlideId;
    if (cur == null) return const [];
    final sel = ed.selectedSlideIds;
    if (sel.length > 1 && sel.contains(cur)) {
      return [
        for (final e in ed.order.entries)
          if (sel.contains(e.id)) e.id,
      ];
    }
    return [cur];
  }
}

Widget _button(
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

/// The easing preset select (06 §4.3): Smooth, Snappy, Bouncy, Gentle,
/// Linear, Ease in, Ease out (+ *Custom* for other expressions).
class _EasingSelect extends StatelessWidget {
  const _EasingSelect({
    required this.keyName,
    required this.expression,
    required this.durationMs,
    required this.onChanged,
    this.enabled = true,
  });

  final String keyName;
  final String? expression;
  final int durationMs;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final current = expression == null
        ? null
        : EasingPresets.presetOf(expression!);
    return StyleSelect<String>(
      keyName: keyName,
      value: current,
      options: [
        ...EasingPresets.presets.keys,
        if (current == 'custom') 'custom',
      ],
      enabled: enabled,
      placeholder: '—',
      label: l.animateEasingName,
      onChanged: (p) {
        if (p == 'custom') return;
        onChanged(EasingPresets.expressionOf(p, durationMs));
      },
    );
  }
}

/// The easing select of builds (shared with the Build tab).
Widget easingSelect({
  required String keyName,
  required String? expression,
  required int durationMs,
  required ValueChanged<String> onChanged,
  bool enabled = true,
}) => _EasingSelect(
  keyName: keyName,
  expression: expression,
  durationMs: durationMs,
  onChanged: onChanged,
  enabled: enabled,
);

/// The Magic Move options of 06 §8.6 and the match count of 06 §8.3.
class _MagicMoveOptions extends StatelessWidget {
  const _MagicMoveOptions({
    required this.services,
    required this.editor,
    required this.spec,
    required this.previousSlideId,
    required this.enabled,
    required this.set,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final TransitionSpec spec;
  final String? previousSlideId;
  final bool enabled;
  final void Function(Map<String, Object?> patch) set;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    final ui = SlidesCommandUi(context, services);
    final mm = spec.magicMove ?? const MagicMoveOptions();
    final count = _matchCount();
    void patch(String key, Object v) => set({
      'magicMove': {key: v},
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                count == 0 ? LucideIcons.triangleAlert : LucideIcons.link,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  previousSlideId == null
                      ? l.animateMagicMoveFirstSlide
                      : count == 0
                      ? l.animateMagicMoveNoMatches
                      : l.animateMagicMoveMatches(count ?? 0),
                  key: const ValueKey<String>('slides.animate.magicMove.count'),
                  style: theme.textTheme.small,
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('slides.animate.magicMove.showMatches'),
            size: ShadButtonSize.sm,
            leading: Icon(
              ui.state('slides.magicMove.toggleMatches').checked == true
                  ? LucideIcons.eyeOff
                  : LucideIcons.eye,
              size: 14,
            ),
            onPressed: () => ui.run(
              'slides.magicMove.toggleMatches',
              const {},
              InvocationSource.ui,
            ),
            child: Text(
              ui.state('slides.magicMove.toggleMatches').checked == true
                  ? l.animateHideMatches
                  : l.animateShowMatches,
            ),
          ),
        ),
        const SizedBox(height: 8),
        InspectorRow(
          label: l.animateMatchTextBy,
          child: StyleSelect<String>(
            keyName: 'magicMove.textMatching',
            value: mm.textMatching,
            options: const ['object', 'word', 'character'],
            enabled: enabled,
            label: l.animateChoiceName,
            onChanged: (v) => patch('textMatching', v),
          ),
        ),
        AnimateSwitch(
          keyName: 'magicMove.matchByContent',
          label: l.animateMatchByContent,
          value: mm.matchByContent,
          enabled: enabled,
          onChanged: (v) => patch('matchByContent', v),
        ),
        InspectorRow(
          label: l.animateUnmatched,
          child: StyleSelect<String>(
            keyName: 'magicMove.fadeUnmatched',
            value: mm.fadeUnmatched,
            options: const ['together', 'before', 'after'],
            enabled: enabled,
            label: l.animateUnmatchedName,
            onChanged: (v) => patch('fadeUnmatched', v),
          ),
        ),
        InspectorRow(
          label: l.animateRotation,
          child: SegmentedChoice<String>(
            keyName: 'magicMove.rotation',
            value: mm.rotation,
            options: const ['shortest', 'literal'],
            enabled: enabled,
            label: l.animateChoiceName,
            onChanged: (v) => patch('rotation', v),
          ),
        ),
        InspectorRow(
          label: l.animateStagger,
          child: SecondsField(
            key: const ValueKey<String>('slides.animate.magicMove.stagger'),
            ms: mm.stagger,
            maxMs: 2000,
            step: 0.05,
            enabled: enabled,
            onChanged: (ms) => patch('stagger', ms),
          ),
        ),
      ],
    );
  }

  /// Matched pairs with the previous slide (null without one).
  int? _matchCount() {
    final prev = previousSlideId;
    final cur = editor.currentSlideId;
    if (prev == null || cur == null) return null;
    final view = AnimateView.of(editor);
    final renderer = SlideCanvasController.of(editor)?.renderer;
    try {
      final a = MagicMoveSlide.fromDeck(
        editor.model,
        prev,
        frame: view.timelineOf(prev, reduced: false).finalFrame,
        scene: renderer?.scene(prev),
      );
      final b = MagicMoveSlide.fromDeck(
        editor.model,
        cur,
        frame: view.timelineOf(cur, reduced: false).initial,
        scene: renderer?.scene(cur),
      );
      return MagicMoveMatcher.match(
        a.elements,
        b.elements,
        options: spec.magicMove ?? const MagicMoveOptions(),
      ).allPairs.length;
    } on Object {
      return null;
    }
  }
}

/// A transition tile's live preview (06 §5.1): the actual previous slide
/// → this slide with [spec], looping while the tile is hovered/focused.
class TransitionTilePreview extends StatefulWidget {
  const TransitionTilePreview({
    super.key,
    required this.view,
    required this.slideId,
    required this.fromSlideId,
    required this.spec,
  });

  final AnimateView view;
  final String slideId;
  final String fromSlideId;
  final TransitionSpec spec;

  @override
  State<TransitionTilePreview> createState() => _TransitionTilePreviewState();
}

class _TransitionTilePreviewState extends State<TransitionTilePreview> {
  late final int _origin = clock.now().millisecondsSinceEpoch;
  late final SlidePlayer _player;
  late final SlidePlayback _playback;
  Timer? _timer;

  int _now() => clock.now().millisecondsSinceEpoch - _origin;

  @override
  void initState() {
    super.initState();
    _player = SlidePlayer(
      // Edit frames: the tile shows the slides as authored.
      timelineOf: (id) => SlideTimeline(slideId: id),
      planOf: (r) => AnimatePreview.planWith(
        widget.view,
        widget.spec,
        fromSlideId: r.fromSlideId,
        toSlideId: r.toSlideId,
      ),
    );
    _playback = SlidePlayback(player: _player, now: _now);
    _play();
  }

  void _play() {
    _player.enter(
      widget.slideId,
      now: _now(),
      fromSlideId: widget.fromSlideId,
      playStep0: false,
    );
    _playback.changed();
    final left = _player.endMs - _now();
    _timer = Timer(Duration(milliseconds: (left < 0 ? 0 : left) + 600), () {
      if (!mounted) return;
      _play();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderer = SlideCanvasController.of(widget.view.editor)?.renderer;
    if (renderer == null) return const SizedBox.shrink();
    return SlidePlaybackStage(
      playback: _playback,
      renderer: renderer,
      letterbox: ShadTheme.of(context).colorScheme.muted,
      reducedMotion: widget.view.previewReduced,
    );
  }
}
