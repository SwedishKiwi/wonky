import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/scene.dart' show CodeScene;
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../../l10n/slides_l10n.dart';
import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../style/style_sections.dart';
import 'code_blocks.dart';
import 'code_dialogs.dart';
import 'code_frames.dart';
import 'code_scene_painter.dart';

/// Inspector › Format › **Code** (Slides 07 §7): the element options
/// (language, palette, font size with auto-fit bounds, line numbers and
/// start, wrap, ligatures, chrome and title, language badge, copy button,
/// highlight style and focus), the **state strip** (mini previews, select,
/// add, duplicate, delete, move, ▶ preview, label, *Show changes*), the
/// selected state's **arrival** (typing / morph / instant, speed, rhythm,
/// deletions, *More…*, estimated duration) and its **line steps** (the
/// 07 §4.1 syntax with inline issues, the parsed steps with callouts; a
/// click previews a step on the canvas). Every change runs a
/// `slides.code.*` command (one undo step).
Widget codeSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final els = [
    for (final e in s.targets)
      if (e.record.kind == ElementKind.code) e,
  ];
  if (els.length != 1) return const SizedBox.shrink();
  return _CodeSection(s: s, ed: ed, element: els.single);
}

/// Widget keys of the code section.
abstract final class CodeSectionKeys {
  static ValueKey<String> of(String name) =>
      ValueKey<String>('slides.code.section.$name');
  static ValueKey<String> chip(int i) =>
      ValueKey<String>('slides.code.state.$i');
  static ValueKey<String> step(int i) =>
      ValueKey<String>('slides.code.step.$i');
}

class _CodeSection extends StatelessWidget {
  const _CodeSection({
    required this.s,
    required this.ed,
    required this.element,
  });

  final StyleScope s;
  final DeckEditorController ed;
  final ResolvedElement element;

  SlidesLocalizations get l => s.l;

  void run(String id, [Map<String, Object?> args = const {}]) =>
      s.run(id, {'elementId': element.id, ...args});

  void patch(Map<String, Object?> p) => s.run('slides.code.updateOptions', {
    'elementIds': [element.id],
    'patch': p,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final view = CodeBlockView.of(ed);
    final data = CodeElementData.fromJson(element.data);
    final model = CodeElementModel.fromDeck(ed.model, element.id, element.data);
    final index = view.stateIndexOf(element.id).clamp(0, model.stateCount - 1);
    final state = model.state(index);
    final rec = view.stateOf(element.id);
    final canEdit = s.enabled('slides.code.updateOptions', {
      'elementIds': [element.id],
      'toggle': 'wrap',
    });
    final composer = _composer();
    final fitted = composer?.fit(element.frame.width, element.frame.height, [
      index,
    ]).fontSize;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    Widget toggle(String key, String label) => InspectorRow(
      label: label,
      child: ShadSwitch(
        key: CodeSectionKeys.of(key),
        value: data.toJson()[key] == true,
        enabled: canEdit,
        onChanged: (_) => s.run('slides.code.updateOptions', {
          'elementIds': [element.id],
          'toggle': key,
        }),
      ),
    );

    final languages = codeLanguageOptions(l);
    final palettes = codePaletteOptions(l);
    final sizeOptions = <String>[
      'auto',
      for (final x in const [14, 16, 18, 20, 24, 28, 32, 36, 40, 48]) '$x',
      if (data.fontSize != null &&
          !const [
            14,
            16,
            18,
            20,
            24,
            28,
            32,
            36,
            40,
            48,
          ].contains(data.fontSize!.round()))
        _n(data.fontSize!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InspectorRow(
          label: l.codeLanguageLabel,
          child: StyleSelect<String>(
            keyName: 'code.language',
            value: languages.containsKey(data.language) ? data.language : '',
            options: languages.keys.toList(),
            label: (v) => languages[v] ?? v,
            enabled: canEdit,
            onChanged: (v) => s.run('slides.code.setLanguage', {
              'elementIds': [element.id],
              'language': v,
            }),
          ),
        ),
        InspectorRow(
          label: l.codePaletteLabel,
          child: StyleSelect<String>(
            keyName: 'code.palette',
            value: palettes.containsKey(data.palette) ? data.palette : 'auto',
            options: palettes.keys.toList(),
            label: (v) => v == 'auto' && composer != null
                ? l.codePaletteAutoNamed(composer.style.palette.name)
                : palettes[v] ?? v,
            enabled: canEdit,
            onChanged: (v) => s.run('slides.code.setPalette', {
              'elementIds': [element.id],
              'palette': v,
            }),
          ),
        ),
        InspectorRow(
          label: l.codeFontSize,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StyleSelect<String>(
                keyName: 'code.fontSize',
                value: data.fontSize == null ? 'auto' : _n(data.fontSize!),
                options: sizeOptions,
                label: (v) => v == 'auto' ? l.codeFontSizeAuto : v,
                enabled: canEdit,
                onChanged: (v) =>
                    patch({'fontSize': v == 'auto' ? null : num.parse(v)}),
              ),
              if (data.fontSize == null && fitted != null) ...[
                Text(
                  '(${_n(fitted)})',
                  key: CodeSectionKeys.of('fitted'),
                  style: theme.textTheme.muted,
                ),
              ],
            ],
          ),
        ),
        if (data.fontSize == null)
          InspectorRow(
            label: l.codeFontSizeRange,
            child: Row(
              children: [
                Expanded(
                  child: CodeCommitField(
                    fieldKey: 'slides.code.section.min',
                    value: _n(data.fontSizeMin),
                    enabled: canEdit,
                    onCommit: (v) {
                      final x = num.tryParse(v);
                      if (x != null) patch({'fontSizeMin': x});
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Text('–', style: theme.textTheme.small),
                const SizedBox(width: 6),
                Expanded(
                  child: CodeCommitField(
                    fieldKey: 'slides.code.section.max',
                    value: _n(data.fontSizeMax),
                    enabled: canEdit,
                    onCommit: (v) {
                      final x = num.tryParse(v);
                      if (x != null) patch({'fontSizeMax': x});
                    },
                  ),
                ),
              ],
            ),
          ),
        toggle('lineNumbers', l.codeLineNumbers),
        if (data.lineNumbers)
          InspectorRow(
            label: l.codeStartLine,
            child: SizedBox(
              width: 80,
              child: CodeCommitField(
                fieldKey: 'slides.code.section.startLine',
                value: '${data.startLine}',
                enabled: canEdit,
                onCommit: (v) {
                  final x = int.tryParse(v);
                  if (x != null && x >= 0) patch({'startLine': x});
                },
              ),
            ),
          ),
        toggle('wrap', l.codeWrap),
        toggle('ligatures', l.codeLigatures),
        InspectorRow(
          label: l.codeChrome,
          child: StyleSelect<String>(
            keyName: 'code.chrome',
            value: data.chrome ?? '',
            options: const ['', 'none', 'tab', 'window', 'caption'],
            label: (v) => switch (v) {
              'none' => l.codeChromeNone,
              'tab' => l.codeChromeTab,
              'window' => l.codeChromeWindow,
              'caption' => l.codeChromeCaption,
              _ => l.codeChromeTheme,
            },
            enabled: canEdit,
            onChanged: (v) => patch({'chrome': v.isEmpty ? null : v}),
          ),
        ),
        InspectorRow(
          label: l.codeTitle,
          child: CodeCommitField(
            fieldKey: 'slides.code.section.title',
            value: data.title ?? '',
            placeholder: 'lib/main.dart',
            enabled: canEdit,
            onCommit: (v) => patch({'title': v.isEmpty ? null : v}),
          ),
        ),
        toggle('showLanguage', l.codeShowLanguage),
        InspectorRow(
          label: l.codeCopyButton,
          child: StyleSelect<String>(
            keyName: 'code.copyButton',
            value: data.copyButton,
            options: const ['never', 'present', 'always'],
            label: (v) => switch (v) {
              'never' => l.codeCopyNever,
              'always' => l.codeCopyAlways,
              _ => l.codeCopyPresent,
            },
            enabled: canEdit,
            onChanged: (v) => patch({'copyButton': v}),
          ),
        ),
        // ---- States (07 §7)
        header(l.codeStatesHeader),
        _StateStrip(
          ed: ed,
          element: element,
          model: model,
          composer: composer,
          selected: index,
          onSelect: (i) => run('slides.code.selectState', {'index': i}),
          onAdd: canEdit ? () => run('slides.code.addState') : null,
        ),
        const SizedBox(height: 6),
        Text(
          index == 0
              ? l.codeStateInfoFirst(index + 1, state.lineCount)
              : _diffInfo(model, index, state),
          key: CodeSectionKeys.of('stateInfo'),
          style: theme.textTheme.muted,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _iconButton('slides.code.duplicateState', LucideIcons.copy, {
              'stateId': ?rec?.id,
            }),
            _iconButton('slides.code.deleteState', LucideIcons.trash2, {
              'stateId': ?rec?.id,
            }),
            _iconButton(
              'slides.code.moveState',
              LucideIcons.arrowLeft,
              {'stateId': ?rec?.id, 'delta': -1},
              tooltip: l.codeMoveStateLeft,
              enabled: index > 0,
            ),
            _iconButton(
              'slides.code.moveState',
              LucideIcons.arrowRight,
              {'stateId': ?rec?.id, 'delta': 1},
              tooltip: l.codeMoveStateRight,
              enabled: index < model.stateCount - 1,
            ),
            _iconButton('slides.code.preview', LucideIcons.play, {
              'elementId': element.id,
              'index': index,
            }, tooltip: index == 0 ? l.codePreviewTypeIn : l.codePreviewChange),
            _iconButton('slides.code.edit', LucideIcons.squarePen, {
              'elementId': element.id,
            }),
          ],
        ),
        InspectorRow(
          label: l.codeStateLabel,
          child: CodeCommitField(
            fieldKey: 'slides.code.section.label.${rec?.id}',
            value: rec?.label ?? '',
            placeholder: l.codeStateLabelHint,
            enabled: canEdit && rec != null,
            onCommit: (v) => s.run('slides.code.setStateLabel', {
              'stateId': rec!.id,
              'label': v,
            }),
          ),
        ),
        InspectorRow(
          label: l.codeShowChanges,
          child: ShadSwitch(
            key: CodeSectionKeys.of('diffGutter'),
            value: view.diffGutter,
            onChanged: (_) => s.run('slides.code.toggleDiffGutter'),
          ),
        ),
        // ---- Arrival (07 §5, §7)
        header(index == 0 ? l.codeTypeInHeader : l.codeArrivalHeader),
        _arrival(context, model, index, rec, canEdit),
        // ---- Line steps (07 §4, §7)
        header(l.codeLineStepsHeader(index + 1)),
        _LineSteps(
          s: s,
          ed: ed,
          element: element,
          state: state,
          stateId: rec?.id,
          canEdit: canEdit,
        ),
        const SizedBox(height: 8),
        InspectorRow(
          label: l.codeHighlightStyle,
          child: StyleSelect<String>(
            keyName: 'code.highlightStyle',
            value: data.highlightStyle.style.name,
            options: [for (final k in CodeHighlightStyleKind.values) k.name],
            label: (v) => switch (v) {
              'blur' => l.codeStyleBlur,
              'dimBlur' => l.codeStyleDimBlur,
              'bar' => l.codeStyleBar,
              'box' => l.codeStyleBox,
              'none' => l.codeStyleNone,
              _ => l.codeStyleDim,
            },
            enabled: canEdit,
            onChanged: (v) => patch({
              'highlightStyle': {'style': v},
            }),
          ),
        ),
        InspectorRow(
          label: l.codeFocus,
          child: StyleSelect<String>(
            keyName: 'code.focus',
            value: data.highlightStyle.focus.name,
            options: [for (final k in CodeFocusMode.values) k.name],
            label: (v) => switch (v) {
              'zoom' => l.codeFocusZoom,
              'none' => l.codeFocusNone,
              _ => l.codeFocusScroll,
            },
            enabled: canEdit,
            onChanged: (v) => patch({
              'highlightStyle': {'focus': v},
            }),
          ),
        ),
        toggle('fitAcrossStates', l.codeFitAcrossStates),
      ],
    );
  }

  String _diffInfo(CodeElementModel model, int index, CodeStateModel state) {
    final stats = model.diffStats(index);
    return l.codeStateInfo(
      index + 1,
      state.lineCount,
      stats?.added ?? 0,
      stats?.changed ?? 0,
      stats?.removed ?? 0,
      index,
    );
  }

  Widget _arrival(
    BuildContext context,
    CodeElementModel model,
    int index,
    CodeStateRec? rec,
    bool canEdit,
  ) {
    final theme = ShadTheme.of(context);
    final st = model.state(index);
    final a = st.arrival;
    final id = rec?.id;
    void set(Map<String, Object?> t) => s.run(
      'slides.code.setStateTransition',
      {'stateId': ?id, 'transition': t},
    );
    final ms = index == 0
        ? model.typeInDurationMs()
        : model.transitionDurationMs(index - 1, index);
    final seconds = (ms / 1000).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index > 0)
          InspectorRow(
            label: l.codeArrivesBy,
            child: StyleSelect<String>(
              keyName: 'code.mode',
              value: a.mode.name,
              options: const ['type', 'morph', 'instant'],
              label: (v) => switch (v) {
                'morph' => l.codeModeMorph,
                'instant' => l.codeModeInstant,
                _ => l.codeModeType,
              },
              enabled: canEdit && id != null,
              onChanged: (v) => set({'mode': v}),
            ),
          ),
        if (index == 0 || a.mode == CodeTransitionMode.type) ...[
          InspectorRow(
            label: l.codeTypingCps,
            child: SizedBox(
              width: 80,
              child: CodeCommitField(
                fieldKey: 'slides.code.section.cps.$id',
                value: _n(a.cps),
                enabled: canEdit && id != null,
                onCommit: (v) {
                  final x = num.tryParse(v);
                  if (x != null) set({'cps': x.clamp(5, 200)});
                },
              ),
            ),
          ),
          InspectorRow(
            label: l.codeTypingRhythm,
            child: _RhythmSlider(
              key: ValueKey<String>('slides.code.section.rhythm.$id'),
              value: a.jitter,
              enabled: canEdit && id != null,
              onCommit: (x) => set({'jitter': (x * 100).round() / 100}),
            ),
          ),
          if (index > 0)
            InspectorRow(
              label: l.codeTypingDeletions,
              child: StyleSelect<String>(
                keyName: 'code.deleteMode',
                value: a.deleteMode.name,
                options: const ['auto', 'backspace', 'select'],
                label: (v) => switch (v) {
                  'backspace' => l.codeDeleteBackspace,
                  'select' => l.codeDeleteSelect,
                  _ => l.codeDeleteAuto,
                },
                enabled: canEdit && id != null,
                onChanged: (v) => set({'deleteMode': v}),
              ),
            ),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                switch (index == 0 ? CodeTransitionMode.type : a.mode) {
                  CodeTransitionMode.type => l.codeDurationTyped(seconds),
                  CodeTransitionMode.morph => l.codeDurationMorph(seconds),
                  CodeTransitionMode.instant => l.codeDurationInstant(seconds),
                },
                key: CodeSectionKeys.of('duration'),
                style: theme.textTheme.muted,
              ),
            ),
            ShadButton.ghost(
              key: CodeSectionKeys.of('more'),
              size: ShadButtonSize.sm,
              enabled: canEdit && id != null,
              onPressed: () => s.run('slides.code.setStateTransition', {
                'stateId': ?id,
                'more': true,
              }),
              child: Text(l.codeMore),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton(
    String id,
    IconData icon,
    Map<String, Object?> args, {
    String? tooltip,
    bool enabled = true,
  }) {
    final on = enabled && s.enabled(id, args);
    final label = tooltip ?? s.ui.title(id);
    return ShadTooltip(
      builder: (_) => Text(label),
      child: Semantics(
        label: label,
        button: true,
        child: ShadIconButton.outline(
          key: ValueKey<String>(
            'slides.code.section.${id.split('.').last}'
            '${args['delta'] == null ? '' : '.${args['delta']}'}',
          ),
          width: 32,
          height: 32,
          icon: Icon(icon, size: 15),
          enabled: on,
          onPressed: () => s.run(id, args),
        ),
      ),
    );
  }

  CodeSceneComposer? _composer() {
    final canvas = SlideCanvasController.of(ed);
    final slide = canvas?.slide;
    if (slide == null) return null;
    final e = canvas!.elements?[element.id] ?? element;
    return CodeFrames.composerOf(slide, e, ed.model);
  }
}

String _n(double v) =>
    v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

/// The state strip (07 §7): one chip per state with a live mini preview,
/// the arrival mode between chips, and `+`.
class _StateStrip extends StatelessWidget {
  const _StateStrip({
    required this.ed,
    required this.element,
    required this.model,
    required this.composer,
    required this.selected,
    required this.onSelect,
    required this.onAdd,
  });

  final DeckEditorController ed;
  final ResolvedElement element;
  final CodeElementModel model;
  final CodeSceneComposer? composer;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final w = element.frame.width, h = element.frame.height;
    const chipW = 64.0;
    final chipH = (chipW * h / math.max(w, 1)).clamp(24.0, 56.0);
    final children = <Widget>[];
    for (var i = 0; i < model.stateCount; i++) {
      if (i > 0) {
        final mode = model.state(i).arrival.mode;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              switch (mode) {
                CodeTransitionMode.type => LucideIcons.keyboard,
                CodeTransitionMode.morph => LucideIcons.diamond,
                CodeTransitionMode.instant => LucideIcons.arrowRight,
              },
              size: 12,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
        );
      }
      final st = model.state(i);
      final label = st.label?.isNotEmpty == true
          ? l.codeStateChipNamed(i + 1, st.label!)
          : l.codeStateChip(i + 1);
      final isSel = i == selected;
      final scene = composer?.build(i, width: w, height: h, dimming: false);
      children.add(
        Semantics(
          label: label,
          selected: isSel,
          button: true,
          child: ShadTooltip(
            builder: (_) => Text(label),
            child: GestureDetector(
              key: CodeSectionKeys.chip(i),
              onTap: () => onSelect(i),
              child: Container(
                width: chipW,
                height: chipH,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSel
                        ? theme.colorScheme.primary
                        : theme.colorScheme.border,
                    width: isSel ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (scene != null) CustomPaint(painter: _MiniCode(scene)),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.background.withValues(
                            alpha: 0.85,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.small.copyWith(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (onAdd != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ShadTooltip(
            builder: (_) => Text(l.cmdCodeAddState),
            child: ShadIconButton.outline(
              key: CodeSectionKeys.of('addState'),
              width: 32,
              height: 32,
              icon: const Icon(LucideIcons.plus, size: 15),
              onPressed: onAdd,
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      key: CodeSectionKeys.of('strip'),
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}

class _MiniCode extends CustomPainter {
  _MiniCode(this.scene);

  final CodeScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    if (scene.width <= 0 || scene.height <= 0) return;
    final k = math.min(size.width / scene.width, size.height / scene.height);
    canvas.save();
    canvas.translate(
      (size.width - scene.width * k) / 2,
      (size.height - scene.height * k) / 2,
    );
    canvas.scale(k);
    CodeScenePainter.paint(
      canvas,
      scene,
      SuRect(0, 0, scene.width, scene.height),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniCode old) => !identical(old.scene, scene);
}

/// The line steps of the edit state (07 §7): the syntax field (normalized
/// on commit, issues inline) and the parsed steps with their callouts.
class _LineSteps extends StatelessWidget {
  const _LineSteps({
    required this.s,
    required this.ed,
    required this.element,
    required this.state,
    required this.stateId,
    required this.canEdit,
  });

  final StyleScope s;
  final DeckEditorController ed;
  final ResolvedElement element;
  final CodeStateModel state;
  final String? stateId;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = s.l;
    final view = CodeBlockView.of(ed);
    final parsed = state.steps;
    final issues = [
      ...parsed.issues,
      ...HighlightSteps.validate(
        parsed.steps,
        state.lineCount,
      ).where((i) => !parsed.issues.any((p) => p.step == i.step)),
    ];
    final previewing = view.stepOf(element.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CodeCommitField(
          fieldKey: 'slides.code.section.steps.$stateId',
          value: state.highlight ?? '',
          placeholder: '1-3 | 5 | 7-9',
          enabled: canEdit && stateId != null,
          onCommit: (v) => s.run('slides.code.setHighlightSteps', {
            'stateId': ?stateId,
            'steps': v,
            'normalize': true,
          }),
        ),
        for (final i in issues)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              codeStepIssueText(l, i),
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
                fontSize: 12,
              ),
            ),
          ),
        if (parsed.steps.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l.codeStepsEmpty, style: theme.textTheme.muted),
          ),
        for (var i = 0; i < parsed.steps.length; i++)
          _stepRow(context, i, parsed.steps[i], previewing == i),
      ],
    );
  }

  Widget _stepRow(
    BuildContext context,
    int i,
    HighlightStep step,
    bool previewing,
  ) {
    final theme = ShadTheme.of(context);
    final l = s.l;
    final callout = state.annotations[i];
    final what = step.isAll ? l.codeStepAll : step.text;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              selected: previewing,
              label: l.codeStepRow(i + 1, what),
              child: GestureDetector(
                key: CodeSectionKeys.step(i),
                behavior: HitTestBehavior.opaque,
                onTap: () => s.run('slides.code.previewStep', {
                  'elementId': element.id,
                  'step': previewing ? null : i + 1,
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: previewing
                        ? theme.colorScheme.accent
                        : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          callout == null ? what : '$what  ·  ${callout.text}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(l.codeEditCallout),
            child: ShadIconButton.ghost(
              key: ValueKey<String>('slides.code.step.$i.callout'),
              width: 28,
              height: 28,
              icon: Icon(
                callout == null
                    ? LucideIcons.messageSquarePlus
                    : LucideIcons.messageSquareText,
                size: 14,
              ),
              enabled: canEdit && stateId != null,
              onPressed: () => s.run('slides.code.setCallout', {
                'stateId': ?stateId,
                'step': i + 1,
              }),
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(l.codeRemoveStep),
            child: ShadIconButton.ghost(
              key: ValueKey<String>('slides.code.step.$i.remove'),
              width: 28,
              height: 28,
              icon: const Icon(LucideIcons.x, size: 14),
              enabled: canEdit && stateId != null,
              onPressed: () {
                final parts =
                    state.steps.steps
                        .map((x) => x.isAll ? '*' : x.text)
                        .toList()
                      ..removeAt(i);
                s.run('slides.code.setHighlightSteps', {
                  'stateId': ?stateId,
                  'steps': parts.join(' | '),
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The typing rhythm (jitter 0–1), committed on release.
class _RhythmSlider extends StatefulWidget {
  const _RhythmSlider({
    super.key,
    required this.value,
    required this.onCommit,
    this.enabled = true,
  });

  final double value;
  final ValueChanged<double> onCommit;
  final bool enabled;

  @override
  State<_RhythmSlider> createState() => _RhythmSliderState();
}

class _RhythmSliderState extends State<_RhythmSlider> {
  double? _live;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final v = (_live ?? widget.value).clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ShadSlider(
            initialValue: v,
            min: 0,
            max: 1,
            enabled: widget.enabled,
            onChanged: (x) => setState(() => _live = x),
            onChangeEnd: (x) {
              setState(() => _live = null);
              widget.onCommit(x);
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            v.toStringAsFixed(2),
            style: theme.textTheme.small,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

/// A text field that commits on Enter or when it loses focus, only when
/// the text changed.
class CodeCommitField extends StatefulWidget {
  const CodeCommitField({
    super.key,
    required this.fieldKey,
    required this.value,
    required this.onCommit,
    this.enabled = true,
    this.placeholder,
  });

  final String fieldKey;
  final String value;
  final ValueChanged<String> onCommit;
  final bool enabled;
  final String? placeholder;

  @override
  State<CodeCommitField> createState() => _CodeCommitFieldState();
}

class _CodeCommitFieldState extends State<CodeCommitField> {
  late final _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(CodeCommitField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) _c.text = widget.value;
  }

  void _commit() {
    final v = _c.text.trim();
    if (v != widget.value.trim()) widget.onCommit(v);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShadInput(
    key: ValueKey<String>(widget.fieldKey),
    controller: _c,
    focusNode: _focus,
    enabled: widget.enabled,
    placeholder: widget.placeholder == null ? null : Text(widget.placeholder!),
    onSubmitted: (_) => _commit(),
  );
}

/// The `jsonDecode` of a column, or null.
Map<String, Object?>? decodeJsonColumn(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final v = jsonDecode(json);
    return v is Map ? v.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}
