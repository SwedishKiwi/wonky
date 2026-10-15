import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart'
    show CodeLanguages, HighlightSteps, TypingSettings;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/code.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/model.dart' as core show SlidesText;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart'
    show CodeStateCols, ElementCols, SlidesCols, SlidesTables;

import '../features/canvas/canvas_interactions.dart';
import '../features/canvas/slide_canvas_controller.dart';
import '../features/clipboard/system_clipboard.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/elements/code/code_blocks.dart';
import '../features/elements/code/code_canvas_mode.dart';
import '../features/elements/code/code_dialogs.dart';
import '../features/elements/element_activation.dart';
import '../features/settings/slides_user_defaults.dart';
import '../features/text_editing/text_editing_host.dart';
import '../l10n/slides_l10n.dart';
import 'slides_command.dart';

/// The code element commands of SL-31 (Slides 07 §3, §7, §11): insert a
/// code block (language picker), edit in place, language, palette and the
/// other `dataJson` options, state text, the state strip (add, duplicate,
/// delete, move, select), each state's arrival (type / morph / instant and
/// the typing settings), highlight steps and callouts, the diff gutter,
/// the transition preview, *Copy code* and *Convert to code block*. Every
/// mutating command is one `slides.rows` undo step; selecting a state, the
/// preview and the diff gutter are view state.
List<Command<CommandArgs>> codeCommands(ShellServices s) {
  CanvasInteractions.register(CodeCanvasMode.new);
  ElementActivations.register(_codeActivation);
  return [
    SlidesCommand(
      'slides.insert.code',
      label: (l) => l.cmdInsertCode,
      icon: LucideIcons.codeXml,
      categoryOf: SlidesCategory.insert,
      mutates: true,
      descriptionText: (l) => l.cmdInsertCodeDescription,
      argsSchema: const JsonSchema.object(
        properties: {
          'language': JsonSchema.string(
            description: 'Language id (dart, python, …; "" = plain text).',
          ),
          'code': JsonSchema.string(description: 'Initial code.'),
          'pick': JsonSchema.boolean(description: 'Ask for the language.'),
          'x': JsonSchema.number(),
          'y': JsonSchema.number(),
          'width': JsonSchema.number(),
          'height': JsonSchema.number(),
        },
      ),
      enabled: (ed, a) => ed.surfaceId != null,
      reason: (l, ed) => l.reasonNoSlides,
      run: (ctx, ed, a) async {
        var language = a.string('language');
        if (language == null && a.boolean('pick') == true) {
          final dc = ctx.dialogContext;
          if (dc == null || ctx.source.isAgent) {
            return const CommandResult.failed('language is required');
          }
          language = await showCodeLanguageDialog(
            dc,
            initial: _defaultLanguage(ed),
            insert: true,
          );
          if (language == null) return const CommandResult.cancelled();
        }
        return _insert(ctx, ed, a, language ?? _defaultLanguage(ed));
      },
    ),
    SlidesCommand(
      'slides.code.edit',
      label: (l) => l.cmdCodeEdit,
      icon: LucideIcons.squarePen,
      categoryOf: SlidesCategory.format,
      argsSchema: const JsonSchema.object(
        properties: {'elementId': JsonSchema.string(), 'stateId': _idSchema},
      ),
      enabled: (ed, a) => ed.canEdit && _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final e = _target(ed, a)!;
        final view = CodeBlockView.of(ed);
        final stateId = a.string('stateId');
        if (stateId != null) {
          final i = view.statesOf(e.id).indexWhere((x) => x.id == stateId);
          if (i < 0) return const CommandResult.failed('No such state');
          view.selectState(e.id, i);
        }
        return _beginEdit(ed, e.id);
      },
    ),
    SlidesCommand(
      'slides.code.setLanguage',
      label: (l) => l.cmdCodeSetLanguage,
      icon: LucideIcons.codeXml,
      categoryOf: SlidesCategory.format,
      mutates: true,
      undoLabelOf: (l, a) => l.undoEditCodeBlock,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementIds': _idsSchema,
          'language': JsonSchema.string(
            description: 'Language id ("" = plain text).',
          ),
        },
      ),
      enabled: (ed, a) => _targets(ed, a).isNotEmpty,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) async {
        final els = _targets(ed, a);
        var language = a.string('language');
        if (language == null) {
          final dc = ctx.dialogContext;
          if (dc == null || ctx.source.isAgent) {
            return const CommandResult.failed('language is required');
          }
          language = await showCodeLanguageDialog(
            dc,
            initial: _data(els.first).language,
          );
          if (language == null) return const CommandResult.cancelled();
        }
        final lang = normalizeCodeLanguage(language);
        CodeBlockView.useLanguage(lang);
        _patch(ctx, ed, els, {'language': lang});
        return ok({'language': lang});
      },
    ),
    SlidesCommand(
      'slides.code.setPalette',
      label: (l) => l.cmdCodeSetPalette,
      icon: LucideIcons.palette,
      categoryOf: SlidesCategory.format,
      mutates: true,
      undoLabelOf: (l, a) => l.undoEditCodeBlock,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementIds': _idsSchema,
          'palette': JsonSchema.string(
            description:
                'auto | light | dark | a palette id (wonky-light, '
                'github-dark, one-dark, dracula, …).',
          ),
        },
        required: ['palette'],
      ),
      enabled: (ed, a) => _targets(ed, a).isNotEmpty,
      reason: (l, ed) => l.reasonSelectCode,
      checked: (ed, a) {
        final p = a.string('palette');
        final els = _targets(ed, a);
        if (p == null || els.isEmpty) return null;
        return els.every((e) => _data(e).palette == p);
      },
      run: (ctx, ed, a) {
        final p = a.requireString('palette');
        if (!codePaletteOptions(slidesL10nOf(ed.services)).containsKey(p)) {
          return CommandResult.failed('Unknown palette $p');
        }
        _patch(ctx, ed, _targets(ed, a), {'palette': p});
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.updateOptions',
      label: (l) => l.cmdCodeUpdateOptions,
      icon: LucideIcons.slidersHorizontal,
      categoryOf: SlidesCategory.format,
      mutates: true,
      undoLabelOf: (l, a) => l.undoEditCodeBlock,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementIds': _idsSchema,
          'patch': JsonSchema.object(
            additionalProperties: true,
            description:
                'JSON merge patch on the code dataJson (07 §3.1): '
                'lineNumbers, startLine, wrap, fontSize (null = auto), '
                'fontSizeMin, fontSizeMax, title, chrome, showLanguage, '
                'ligatures, fitAcrossStates, tabSize, padding, box, '
                'highlightStyle, copyButton, typing, callouts.',
          ),
          'toggle': JsonSchema.string(
            enumValues: _toggles,
            description: 'Flips one boolean option.',
          ),
        },
      ),
      enabled: (ed, a) => _targets(ed, a).isNotEmpty,
      reason: (l, ed) => l.reasonSelectCode,
      checked: (ed, a) {
        final t = a.string('toggle');
        final els = _targets(ed, a);
        if (t == null || els.isEmpty) return null;
        return els.every((e) => _data(e).toJson()[t] == true);
      },
      run: (ctx, ed, a) {
        final els = _targets(ed, a);
        final toggle = a.string('toggle');
        final Map<String, Object?> patch;
        if (toggle != null) {
          if (!_toggles.contains(toggle)) {
            return CommandResult.failed('Unknown option $toggle');
          }
          final on = els.every((e) => _data(e).toJson()[toggle] == true);
          patch = {toggle: !on};
        } else if (a.values['patch'] is Map) {
          patch = (a.values['patch'] as Map).cast<String, Object?>();
        } else {
          // Without arguments: *Line numbers* (the command's title).
          final on = els.every((e) => _data(e).lineNumbers);
          patch = {'lineNumbers': !on};
        }
        _patch(ctx, ed, els, patch);
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.setText',
      label: (l) => l.cmdCodeSetText,
      icon: LucideIcons.fileCode,
      categoryOf: SlidesCategory.format,
      mutates: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementId': JsonSchema.string(),
          'stateId': _idSchema,
          'code': JsonSchema.string(),
        },
        required: ['code'],
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final st = _stateArg(ed, a)!;
        CodeBlockView.of(ed).commitEdit();
        ed.apply(ctx, SetCode(st.id, a.requireString('code')));
        return ok({'stateId': st.id});
      },
    ),
    SlidesCommand(
      'slides.code.addState',
      label: (l) => l.cmdCodeAddState,
      icon: LucideIcons.copyPlus,
      categoryOf: SlidesCategory.format,
      mutates: true,
      descriptionText: (l) => l.cmdCodeAddStateDescription,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementId': JsonSchema.string(),
          'afterStateId': _idSchema,
          'code': JsonSchema.string(),
        },
      ),
      enabled: (ed, a) => _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final e = _target(ed, a)!;
        final view = CodeBlockView.of(ed)..commitEdit();
        final after = a.string('afterStateId') ?? view.stateOf(e.id)?.id;
        final src = after == null
            ? null
            : ed.model.record(SlidesTables.codeState, after) as CodeStateRec?;
        final plan = ed.apply(
          ctx,
          AddCodeStates(e.id, [
            {
              CodeStateCols.code: a.string('code') ?? src?.code ?? '',
              if (src?.language != null) CodeStateCols.language: src!.language,
              if (src?.title != null) SlidesCols.title: src!.title,
              if (a.string('code') == null && src?.highlight != null)
                CodeStateCols.highlight: src!.highlight,
            },
          ], afterStateId: after),
        );
        final id = (plan.result['stateIds'] as List).first as String;
        _selectStateId(ed, e.id, id);
        return ok({'stateId': id});
      },
    ),
    SlidesCommand(
      'slides.code.duplicateState',
      label: (l) => l.cmdCodeDuplicateState,
      icon: LucideIcons.copy,
      categoryOf: SlidesCategory.format,
      mutates: true,
      argsSchema: const JsonSchema.object(properties: {'stateId': _idSchema}),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final st = _stateArg(ed, a)!;
        CodeBlockView.of(ed).commitEdit();
        final cols = {
          for (final c in const [
            CodeStateCols.code,
            CodeStateCols.language,
            CodeStateCols.highlight,
            CodeStateCols.annotationsJson,
            SlidesCols.label,
            SlidesCols.title,
            SlidesCols.transitionJson,
          ])
            if (st.toColumns()[c] != null) c: st.toColumns()[c],
        };
        final plan = ed.apply(
          ctx,
          AddCodeStates(st.elementId!, [cols], afterStateId: st.id),
        );
        final id = (plan.result['stateIds'] as List).first as String;
        _selectStateId(ed, st.elementId!, id);
        return ok({'stateId': id});
      },
    ),
    SlidesCommand(
      'slides.code.deleteState',
      label: (l) => l.cmdCodeDeleteState,
      icon: LucideIcons.trash2,
      categoryOf: SlidesCategory.format,
      mutates: true,
      argsSchema: const JsonSchema.object(properties: {'stateId': _idSchema}),
      enabled: (ed, a) {
        final st = _stateArg(ed, a);
        return st != null && ed.model.codeStatesOf(st.elementId!).length > 1;
      },
      reason: (l, ed) => l.reasonLastCodeState,
      run: (ctx, ed, a) {
        final st = _stateArg(ed, a)!;
        final view = CodeBlockView.of(ed);
        if (view.editing?.stateId == st.id) view.endEdit();
        final el = st.elementId!;
        final index = view.statesOf(el).indexWhere((x) => x.id == st.id);
        ed.apply(ctx, DeleteCodeStates([st.id]));
        view.selectState(el, math.max(0, index - 1));
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.moveState',
      label: (l) => l.cmdCodeMoveState,
      icon: LucideIcons.arrowLeftRight,
      categoryOf: SlidesCategory.format,
      mutates: true,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'stateId': _idSchema,
          'to': JsonSchema.object(
            properties: {'index': JsonSchema.integer(minimum: 0)},
          ),
          'delta': JsonSchema.integer(description: 'Move by n positions.'),
        },
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final st = _stateArg(ed, a)!;
        final el = st.elementId!;
        final view = CodeBlockView.of(ed)..commitEdit();
        final ids = [for (final s in view.statesOf(el)) s.id];
        final from = ids.indexOf(st.id);
        final to = a.values['to'];
        var index = to is Map && to['index'] is num
            ? (to['index'] as num).round()
            : from + (a.integer('delta') ?? 0);
        index = index.clamp(0, ids.length - 1);
        if (index == from) return const CommandResult.failed('Not moved');
        final rest = [...ids]..remove(st.id);
        ed.apply(
          ctx,
          index == 0
              ? MoveCodeStates([st.id], beforeId: rest.first)
              : MoveCodeStates([st.id], afterId: rest[index - 1]),
        );
        view.selectState(el, index);
        return ok({'index': index});
      },
    ),
    SlidesCommand(
      'slides.code.selectState',
      label: (l) => l.cmdCodeSelectState,
      icon: LucideIcons.galleryHorizontal,
      categoryOf: SlidesCategory.format,
      keyScope: SlidesKeyScopes.canvas,
      argBindings: const [
        ArgsKeyBinding(KeyBinding('ArrowLeft', alt: true, shift: true), {
          'delta': -1,
        }),
        ArgsKeyBinding(KeyBinding('ArrowRight', alt: true, shift: true), {
          'delta': 1,
        }),
      ],
      argsSchema: const JsonSchema.object(
        properties: {
          'elementId': JsonSchema.string(),
          'stateId': _idSchema,
          'index': JsonSchema.integer(minimum: 0),
          'delta': JsonSchema.integer(),
        },
      ),
      enabled: (ed, a) => _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final e = _target(ed, a)!;
        final view = CodeBlockView.of(ed);
        final states = view.statesOf(e.id);
        final id = a.string('stateId');
        var index = id != null
            ? states.indexWhere((s) => s.id == id)
            : a.integer('index') ??
                  view.stateIndexOf(e.id) + (a.integer('delta') ?? 0);
        if (index < 0) return const CommandResult.failed('No such state');
        index = index.clamp(0, states.length - 1);
        view.selectState(e.id, index);
        return ok({'index': index, 'stateId': states[index].id});
      },
    ),
    SlidesCommand(
      'slides.code.setStateLabel',
      label: (l) => l.cmdCodeSetStateLabel,
      icon: LucideIcons.tag,
      categoryOf: SlidesCategory.format,
      mutates: true,
      showInPalette: false,
      undoLabelOf: (l, a) => l.undoEditCodeState,
      argsSchema: const JsonSchema.object(
        properties: {'stateId': _idSchema, 'label': JsonSchema.string()},
        required: ['label'],
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final st = _stateArg(ed, a)!;
        final label = a.requireString('label').trim();
        final value = label.isEmpty ? null : label;
        if (value == st.label) return const CommandResult.ok();
        ed.apply(ctx, UpdateCodeState(st.id, {SlidesCols.label: value}));
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.setStateTransition',
      label: (l) => l.cmdCodeSetStateTransition,
      icon: LucideIcons.keyboard,
      categoryOf: SlidesCategory.format,
      mutates: true,
      showInPalette: false,
      undoLabelOf: (l, a) => l.undoEditCodeState,
      argsSchema: const JsonSchema.object(
        properties: {
          'stateId': _idSchema,
          'transition': JsonSchema.object(
            additionalProperties: true,
            description:
                'JSON merge patch on transitionJson (07 §5.3): mode '
                '(type|morph|instant), cps, deleteMode, jitter, morphMs, …',
          ),
          'more': JsonSchema.boolean(
            description: 'Open the typing settings dialog.',
          ),
        },
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) async {
        final st = _stateArg(ed, a)!;
        var patch = a.values['transition'];
        if (patch is! Map) {
          final dc = ctx.dialogContext;
          if (a.boolean('more') != true || dc == null || ctx.source.isAgent) {
            return const CommandResult.failed('transition is required');
          }
          final model = CodeBlocks.modelOf(ed, st.elementId!);
          final i = model?.states.indexWhere((s) => s.id == st.id) ?? -1;
          patch = await showTypingSettingsDialog(
            dc,
            settings: i < 0
                ? TypingSettings.defaults
                : model!.states[i].arrival,
          );
          if (patch == null) return const CommandResult.cancelled();
        }
        final current = _decode(st.transitionJson) ?? <String, Object?>{};
        final merged = mergePatch(
          current,
          (patch as Map).cast<String, Object?>(),
        );
        ed.apply(
          ctx,
          UpdateCodeState(st.id, {
            SlidesCols.transitionJson: merged.isEmpty
                ? null
                : jsonEncode(merged),
          }),
        );
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.setHighlightSteps',
      label: (l) => l.cmdCodeSetHighlightSteps,
      icon: LucideIcons.highlighter,
      categoryOf: SlidesCategory.format,
      mutates: true,
      undoLabelOf: (l, a) => l.undoEditLineSteps,
      argsSchema: const JsonSchema.object(
        properties: {
          'stateId': _idSchema,
          'elementId': JsonSchema.string(),
          'steps': JsonSchema.string(
            description: 'Line steps, e.g. "1-3 | 5 | 7-9" ("" = none).',
          ),
          'normalize': JsonSchema.boolean(
            description: 'Store the normalized form (1-3|5|7-9).',
          ),
        },
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) async {
        final st = _stateArg(ed, a)!;
        var steps = a.string('steps');
        if (steps == null) {
          final dc = ctx.dialogContext;
          if (dc == null || ctx.source.isAgent) {
            return const CommandResult.failed('steps is required');
          }
          final data = CodeElementData.fromJson(
            _decode(ed.model.element(st.elementId!)?.dataJson),
          );
          steps = await showHighlightStepsDialog(
            dc,
            initial: st.highlight ?? '',
            lineCount: '\n'.allMatches(st.code).length + 1,
            startLine: data.startLine,
          );
          if (steps == null) return const CommandResult.cancelled();
        }
        if (a.boolean('normalize') == true) {
          steps = HighlightSteps.parse(steps).normalized;
        }
        final value = steps.trim().isEmpty ? null : steps;
        if (value == st.highlight) return const CommandResult.ok();
        ed.apply(ctx, UpdateCodeState(st.id, {CodeStateCols.highlight: value}));
        final view = CodeBlockView.of(ed);
        final n = HighlightSteps.count(value);
        final cur = view.stepOf(st.elementId!);
        if (cur != null && cur >= n) {
          view.previewStep(st.elementId!, n == 0 ? null : n - 1);
        }
        return ok({'steps': n});
      },
    ),
    SlidesCommand(
      'slides.code.setCallout',
      label: (l) => l.cmdCodeSetCallout,
      icon: LucideIcons.messageSquareQuote,
      categoryOf: SlidesCategory.format,
      mutates: true,
      showInPalette: false,
      undoLabelOf: (l, a) => l.undoEditCallout,
      argsSchema: const JsonSchema.object(
        properties: {
          'stateId': _idSchema,
          'step': JsonSchema.integer(minimum: 1, description: '1-based step.'),
          'callout': JsonSchema.nullable(
            JsonSchema.object(
              additionalProperties: true,
              description:
                  '{text (inline Markdown, ≤ 280), anchor: {line, side}, '
                  'side, style (bubble|label|pill), dx, dy}; null removes.',
            ),
          ),
        },
        required: ['step'],
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) async {
        final st = _stateArg(ed, a)!;
        final step = (a.integer('step') ?? 1) - 1;
        if (step < 0) return const CommandResult.failed('step starts at 1');
        final ann = CodeAnnotations.fromJson(_decode(st.annotationsJson));
        Object? callout = a.values['callout'];
        if (!a.values.containsKey('callout')) {
          final dc = ctx.dialogContext;
          if (dc == null || ctx.source.isAgent) {
            return const CommandResult.failed('callout is required');
          }
          final r = await showCodeCalloutDialog(
            dc,
            step: step,
            initial: ann[step],
          );
          if (r == null) return const CommandResult.cancelled();
          callout = r['text'] == null
              ? null
              : {
                  ...?ann[step]?.toJson(),
                  'text': r['text'],
                  'anchor': {'line': ?ann[step]?.anchorLine, 'side': r['side']},
                  'style': r['style'],
                };
        }
        final steps = Map.of(ann.steps);
        if (callout == null) {
          steps.remove(step);
        } else {
          if (callout is! Map) {
            return const CommandResult.failed('callout must be an object');
          }
          final m = callout.cast<String, Object?>();
          // `side` at the top level is a shorthand of `anchor.side`.
          final json = m['side'] is String && m['anchor'] == null
              ? {
                  ...m,
                  'anchor': {'side': m['side']},
                }
              : m;
          final c = CodeCallout.fromJson(json);
          if (c == null) {
            steps.remove(step);
          } else {
            steps[step] = c;
          }
        }
        final value = steps.isEmpty
            ? null
            : jsonEncode(CodeAnnotations(steps).toJson());
        if (value == st.annotationsJson) return const CommandResult.ok();
        ed.apply(
          ctx,
          UpdateCodeState(st.id, {CodeStateCols.annotationsJson: value}),
        );
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.addStepFromLines',
      label: (l) => l.cmdCodeAddStepFromLines,
      icon: LucideIcons.listPlus,
      categoryOf: SlidesCategory.format,
      mutates: true,
      showInPalette: false,
      undoLabelOf: (l, a) => l.undoEditLineSteps,
      argsSchema: const JsonSchema.object(
        properties: {
          'stateId': _idSchema,
          'lines': JsonSchema.array(JsonSchema.integer(minimum: 1)),
          'replaceStep': JsonSchema.integer(minimum: 1),
        },
        required: ['lines'],
      ),
      enabled: (ed, a) => _stateArg(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final st = _stateArg(ed, a)!;
        final raw = a.values['lines'];
        final lines = <int>{
          if (raw is List)
            for (final x in raw)
              if (x is num && x >= 1) x.round(),
        }.toList()..sort();
        if (lines.isEmpty) return const CommandResult.failed('No lines');
        final step = compactLineRanges(lines);
        final parts = (st.highlight == null || st.highlight!.trim().isEmpty)
            ? <String>[]
            : st.highlight!.split('|').map((s) => s.trim()).toList();
        final replace = a.integer('replaceStep');
        if (replace != null && replace >= 1 && replace <= parts.length) {
          parts[replace - 1] = step;
        } else {
          parts.add(step);
        }
        ed.apply(
          ctx,
          UpdateCodeState(st.id, {CodeStateCols.highlight: parts.join(' | ')}),
        );
        return ok({'steps': parts.length});
      },
    ),
    SlidesCommand(
      'slides.code.previewStep',
      label: (l) => l.cmdCodePreviewStep,
      icon: LucideIcons.eye,
      categoryOf: SlidesCategory.format,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementId': JsonSchema.string(),
          'step': JsonSchema.nullable(
            JsonSchema.integer(minimum: 1, description: '1-based; null = none'),
          ),
        },
      ),
      enabled: (ed, a) => _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final e = _target(ed, a)!;
        final step = a.integer('step');
        CodeBlockView.of(
          ed,
        ).previewStep(e.id, step == null || step < 1 ? null : step - 1);
        return ok();
      },
    ),
    SlidesCommand(
      'slides.code.preview',
      label: (l) => l.cmdCodePreview,
      icon: LucideIcons.play,
      categoryOf: SlidesCategory.format,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementId': JsonSchema.string(),
          'index': JsonSchema.integer(
            minimum: 0,
            description: 'Target state (0-based; default: the edit state).',
          ),
        },
      ),
      enabled: (ed, a) => _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) {
        final e = _target(ed, a)!;
        final view = CodeBlockView.of(ed);
        final n = view.statesOf(e.id).length;
        final to = (a.integer('index') ?? view.stateIndexOf(e.id)).clamp(
          0,
          n - 1,
        );
        view.startPreview(e.id, to);
        return ok({'from': to - 1, 'to': to});
      },
    ),
    SlidesCommand(
      'slides.code.toggleDiffGutter',
      label: (l) => l.cmdCodeToggleDiffGutter,
      icon: LucideIcons.diff,
      categoryOf: SlidesCategory.view,
      checked: (ed, a) => CodeBlockView.of(ed).diffGutter,
      run: (ctx, ed, a) {
        CodeBlockView.of(ed).toggleDiffGutter();
        return ok({'on': CodeBlockView.of(ed).diffGutter});
      },
    ),
    SlidesCommand(
      'slides.code.copy',
      label: (l) => l.cmdCodeCopy,
      icon: LucideIcons.clipboardCopy,
      categoryOf: SlidesCategory.edit,
      argsSchema: const JsonSchema.object(
        properties: {'elementId': JsonSchema.string()},
      ),
      enabled: (ed, a) => _target(ed, a) != null,
      reason: (l, ed) => l.reasonSelectCode,
      run: (ctx, ed, a) async {
        final e = _target(ed, a)!;
        final view = CodeBlockView.of(ed);
        final code = view.editing?.elementId == e.id
            ? view.editing!.text
            : view.stateOf(e.id)?.code ?? '';
        await SlidesSystemClipboard.instance.write(
          SlidesClipboardData(plainText: code),
        );
        if (!ctx.source.isAgent) {
          ed.services.toasts.show(slidesL10nOf(ed.services).toastCodeCopied);
        }
        return ok({'code': code});
      },
    ),
    SlidesCommand(
      'slides.code.convertFromText',
      label: (l) => l.cmdCodeConvertFromText,
      icon: LucideIcons.squareCode,
      categoryOf: SlidesCategory.format,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'elementId': JsonSchema.string(),
          'language': JsonSchema.string(),
        },
      ),
      enabled: (ed, a) => _textBox(ed, a) != null,
      reason: (l, ed) => l.reasonSelectTextBox,
      run: (ctx, ed, a) {
        final t = _textBox(ed, a)!;
        final text = core.SlidesText.plainText(
          t.text,
        ).replaceAll(RegExp(r'\n$'), '');
        final surface = ed.surfaceId!;
        ed.apply(ctx, DeleteElements([t.id]));
        final language = normalizeCodeLanguage(
          a.string('language') ?? _defaultLanguage(ed),
        );
        return _insertAt(
          ctx,
          ed,
          surface,
          language,
          text,
          x: t.x ?? 0,
          y: t.y ?? 0,
          width: t.width ?? 800,
          height: t.height ?? 400,
        );
      },
    ),
  ];
}

// ------------------------------------------------------------- helpers

const _idSchema = JsonSchema.string(description: 'A code state id.');
const _idsSchema = JsonSchema.array(JsonSchema.string());

/// The boolean options `slides.code.updateOptions {toggle}` flips.
const _toggles = [
  'lineNumbers',
  'wrap',
  'ligatures',
  'showLanguage',
  'fitAcrossStates',
];

/// Normalizes a language from a picker or an agent: `plaintext`/`text`/
/// `plain` → `''`, aliases → ids (07 §2.4).
String normalizeCodeLanguage(String language) {
  final l = language.trim().toLowerCase();
  if (l == 'plaintext' || l == 'text' || l == 'plain' || l == 'txt') {
    return '';
  }
  return CodeLanguages.normalize(l);
}

/// `1,2,3,5,7,8` → `1-3,5,7-8`.
String compactLineRanges(List<int> sorted) {
  final out = <String>[];
  var i = 0;
  while (i < sorted.length) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    out.add(j == i ? '${sorted[i]}' : '${sorted[i]}-${sorted[j]}');
    i = j + 1;
  }
  return out.join(',');
}

/// RFC 7386 JSON merge patch of [patch] onto [target].
Map<String, Object?> mergePatch(
  Map<String, Object?> target,
  Map<String, Object?> patch,
) {
  final out = Map<String, Object?>.of(target);
  for (final e in patch.entries) {
    final v = e.value;
    if (v == null) {
      out.remove(e.key);
    } else if (v is Map) {
      final cur = out[e.key];
      out[e.key] = mergePatch(
        cur is Map ? cur.cast<String, Object?>() : const {},
        v.cast<String, Object?>(),
      );
    } else {
      out[e.key] = v;
    }
  }
  return out;
}

Map<String, Object?>? _decode(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final v = jsonDecode(json);
    return v is Map ? v.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// Code element helpers shared by the inspector (SL-31).
abstract final class CodeBlocks {
  /// The model of code element [id] of [ed]'s deck, or null.
  static CodeElementModel? modelOf(DeckEditorController ed, String id) {
    final e = ed.model.element(id);
    if (e == null || e.kind != ElementKind.code) return null;
    return CodeElementModel.fromDeck(ed.model, id, _decode(e.dataJson));
  }
}

CodeElementData _data(SlideElementRec e) =>
    CodeElementData.fromJson(_decode(e.dataJson));

/// The code elements named by `elementIds`/`elementId`, or the selected
/// code elements (editable ones).
List<SlideElementRec> _targets(DeckEditorController ed, JsonArgs a) {
  final ids = a.strings('elementIds');
  final one = a.string('elementId');
  final source = ids.isNotEmpty
      ? ids
      : one != null
      ? [one]
      : ed.selectedElementIds;
  return [
    for (final id in source)
      if (ed.model.element(id) case final e?)
        if (e.kind == ElementKind.code && !e.locked) e,
  ];
}

/// The single code element of `elementId` or the selection, or null.
SlideElementRec? _target(DeckEditorController ed, JsonArgs a) {
  final id = a.string('elementId');
  if (id != null) {
    final e = ed.model.element(id);
    return e != null && e.kind == ElementKind.code ? e : null;
  }
  final sel = ed.selectedElementIds;
  if (sel.length != 1) {
    final editing = CodeBlockView.maybeOf(ed)?.editing;
    return editing == null ? null : ed.model.element(editing.elementId);
  }
  final e = ed.model.element(sel.single);
  return e != null && e.kind == ElementKind.code ? e : null;
}

/// The code state of `stateId`, or the edit state of the target element.
CodeStateRec? _stateArg(DeckEditorController ed, JsonArgs a) {
  final id = a.string('stateId');
  if (id != null) {
    final r = ed.model.record(SlidesTables.codeState, id);
    return r is CodeStateRec ? r : null;
  }
  final e = _target(ed, a);
  return e == null ? null : CodeBlockView.of(ed).stateOf(e.id);
}

SlideElementRec? _textBox(DeckEditorController ed, JsonArgs a) {
  final id =
      a.string('elementId') ??
      (ed.selectedElementIds.length == 1 ? ed.selectedElementIds.single : null);
  if (id == null) return null;
  final e = ed.model.element(id);
  if (e == null || e.kind != ElementKind.text || e.locked) return null;
  return core.SlidesText.isBlank(e.text) ? null : e;
}

void _selectStateId(DeckEditorController ed, String elementId, String id) {
  final view = CodeBlockView.of(ed);
  final i = view.statesOf(elementId).indexWhere((s) => s.id == id);
  if (i >= 0) view.selectState(elementId, i);
}

/// Writes [patch] (JSON merge patch) onto each element's `dataJson`.
void _patch(
  CommandContext ctx,
  DeckEditorController ed,
  List<SlideElementRec> els,
  Map<String, Object?> patch,
) {
  CodeBlockView.of(ed).commitEdit();
  for (final e in els) {
    final current = _decode(e.dataJson) ?? const {'v': 1};
    final merged = mergePatch(current, patch);
    // Normalize through the model (invalid values fall back to defaults).
    final json = jsonEncode(CodeElementData.fromJson(merged).toJson());
    if (json != e.dataJson) ed.apply(ctx, SetElementData(e.id, json));
  }
}

String _defaultLanguage(DeckEditorController ed) {
  final recent = CodeBlockView.recentLanguages;
  if (recent.isNotEmpty) return recent.first;
  return normalizeCodeLanguage(
    ed.defaults.string(SlidesUserDefaults.keyCodeLanguage),
  );
}

Future<CommandResult> _insert(
  CommandContext ctx,
  DeckEditorController ed,
  JsonArgs a,
  String language,
) async {
  final slide = ed.surfaceId;
  if (slide == null) return const CommandResult.failed('No slide');
  final d = ed.model.deck;
  final sw = d?.width ?? 1920, sh = d?.height ?? 1080;
  // The selected placeholder area, else centered 60 % × 50 % (07 §3.6).
  double? px, py, pw, ph;
  final sel = ed.selectedElementIds;
  if (sel.length == 1) {
    final e = ed.resolver
        .resolve(slide)
        ?.elements
        .where((x) => x.id == sel.single);
    final r = e == null || e.isEmpty ? null : e.first;
    if (r != null &&
        r.placeholderType != null &&
        core.SlidesText.isBlank(r.text)) {
      (px, py, pw, ph) = (r.frame.x, r.frame.y, r.frame.width, r.frame.height);
    }
  }
  num? n(String k) => a.values[k] is num ? a.values[k] as num : null;
  final w = (n('width') ?? pw ?? (sw * 0.6).roundToDouble()).toDouble();
  final h = (n('height') ?? ph ?? (sh * 0.5).roundToDouble()).toDouble();
  return _insertAt(
    ctx,
    ed,
    slide,
    normalizeCodeLanguage(language),
    a.string('code') ?? '',
    x: (n('x') ?? px ?? ((sw - w) / 2).roundToDouble()).toDouble(),
    y: (n('y') ?? py ?? ((sh - h) / 2).roundToDouble()).toDouble(),
    width: w,
    height: h,
    edit: !ctx.source.isAgent,
  );
}

CommandResult _insertAt(
  CommandContext ctx,
  DeckEditorController ed,
  String surface,
  String language,
  String code, {
  required double x,
  required double y,
  required double width,
  required double height,
  bool edit = false,
}) {
  final defaults = ed.defaults;
  final speed = defaults.string(SlidesUserDefaults.keyTypingSpeed);
  final data = <String, Object?>{
    'v': 1,
    'language': language,
    'fontSizeMax': defaults.integer(SlidesUserDefaults.keyCodeFontSize),
    if (speed != 'normal') 'typing': {'cps': speed == 'slow' ? 16 : 50},
  };
  final plan = ed.apply(
    ctx,
    InsertElements(ownerKind: ed.surfaceKind, surface, [
      ElementSpec(
        kind: ElementKind.code,
        x: x,
        y: y,
        width: width,
        height: height,
        columns: {
          ElementCols.dataJson: jsonEncode(
            CodeElementData.fromJson(data).toJson(),
          ),
        },
        codeStates: [
          {CodeStateCols.code: code.replaceAll('\r\n', '\n')},
        ],
      ),
    ]),
  );
  CodeBlockView.useLanguage(language);
  final ids = plan.result['elementIds'];
  ed.armTool(null);
  final id = ids is List && ids.isNotEmpty ? ids.first as String : null;
  if (id != null) {
    selectionOf(ed).select([id]);
    ed.canvasFocus.requestFocus();
    if (edit) _beginEdit(ed, id);
  }
  return ok({'elementId': id, 'language': language});
}

CommandResult _beginEdit(DeckEditorController ed, String id) {
  final canvas = SlideCanvasController.of(ed);
  if (canvas != null) {
    final parent = canvas.elements?.parentOf(id)?.id;
    canvas.selection.select([id], enteredGroup: parent);
  } else {
    ed.selectElements([id]);
  }
  final host = textEditingOf(ed);
  final allowed = host.locks.requestTarget(TextLockTarget.element(id));
  void start() {
    final view = CodeBlockView.of(ed)..previewStep(id, null);
    final s = view.beginEdit(
      id,
      undo: ed.services.undo,
      undoLabel: slidesL10nOf(ed.services).undoTyping,
    );
    if (s != null) {
      host.locks.claimTarget(
        TextLockTarget.element(id),
        activity: s,
        stop: () {
          if (identical(view.editing, s)) view.endEdit();
        },
      );
      void released() {
        if (identical(view.editing, s)) return;
        host.locks.releaseTarget(TextLockTarget.element(id));
        view.removeListener(released);
      }

      view.addListener(released);
    }
  }

  if (allowed is bool) {
    if (!allowed) return const CommandResult.cancelled();
    start();
    return ok({'elementId': id});
  }
  unawaited(
    allowed.then((yes) {
      if (yes) start();
    }),
  );
  return ok({'elementId': id});
}

final _codeActivation = ElementActivation(
  applies: (ed, a) {
    final ids = ed.selectedElementIds;
    if (ids.length != 1 || !ed.canEdit) return false;
    final e = ed.model.element(ids.single);
    return e != null && e.kind == ElementKind.code && !e.locked;
  },
  run: (ctx, ed, a) => _beginEdit(ed, ed.selectedElementIds.single),
);
