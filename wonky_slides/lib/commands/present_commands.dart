import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show IconData;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/ops.dart' show Patch, SetDeckProps;

import '../features/editor_screen/deck_editor_controller.dart';
import '../features/present/active_presentation.dart';
import '../features/present/platform/present_platform.dart';
import '../features/present/present_controller.dart';
import '../features/present/present_ink.dart';
import '../features/present/present_settings.dart';
import '../features/settings/slides_user_defaults.dart';
import '../l10n/slides_l10n.dart';
import 'slides_command.dart';

/// The present commands (Slides 10 §14; SL-19). Starting commands open the
/// `present` child route (full screen within the user gesture, 10 §1.3);
/// the in-presentation commands live in keymap scope `present` and act on
/// the open present screen ([activePresentation]). None changes the deck
/// except `slides.deck.setPresentSettings` (undoable).
///
/// No command opens a window: the audience view runs on another device or
/// browser joined to the presentation session (v2 review Q5/Q29).
List<Command<CommandArgs>> presentCommands(ShellServices s) {
  const scope = SlidesKeyScopes.present;
  PresentController? pc() => activePresentation.value?.controller;
  bool presenting(DeckEditorController ed, JsonArgs a) => pc() != null;
  String? notPresenting(SlidesLocalizations l, DeckEditorController ed) =>
      l.reasonNotPresenting;
  bool canStart(DeckEditorController ed, JsonArgs a) =>
      ed.isReady && ed.order.length > 0;
  String? cantStart(SlidesLocalizations l, DeckEditorController ed) =>
      ed.isReady ? l.reasonNoSlides : l.reasonDeckLoading;

  SlidesCommand inPresent(
    String id, {
    required SlidesText label,
    required void Function(PresentController c, JsonArgs a) run,
    List<KeyBinding> keys = const [],
    List<ArgsKeyBinding> argKeys = const [],
    JsonSchema argsSchema = JsonSchema.empty,
    IconData? icon,
    bool Function(PresentController c, JsonArgs a)? when,
    bool? Function(PresentController c, JsonArgs a)? checked,
  }) => SlidesCommand(
    id,
    label: label,
    icon: icon,
    categoryOf: SlidesCategory.present,
    defaultBindings: keys,
    argBindings: argKeys,
    keyScope: scope,
    argsSchema: argsSchema,
    enabled: (ed, a) {
      final c = pc();
      return c != null && (when?.call(c, a) ?? true);
    },
    checked: checked == null
        ? null
        : (ed, a) {
            final c = pc();
            return c == null ? null : checked(c, a);
          },
    reason: notPresenting,
    run: (ctx, ed, a) {
      final c = pc();
      if (c == null) return const CommandResult.failed('Not presenting');
      run(c, a);
      return ok();
    },
  );

  return [
    SlidesCommand(
      'slides.present.fromCurrent',
      label: (l) => l.cmdPresentFromCurrent,
      icon: LucideIcons.play,
      categoryOf: SlidesCategory.present,
      defaultBindings: const [KeyBinding('Enter', mod: true)],
      // Clickers send F5 / Shift+F5: while presenting they resume (no
      // browser reload, 10 §2.1). Outside present mode F5 stays unbound.
      argBindings: const [
        ArgsKeyBinding(KeyBinding('F5'), {}, scope: scope),
        ArgsKeyBinding(KeyBinding('F5', shift: true), {}, scope: scope),
      ],
      argsSchema: const JsonSchema.object(
        properties: {'kiosk': JsonSchema.boolean()},
      ),
      enabled: (ed, a) => pc() != null || canStart(ed, a),
      reason: cantStart,
      run: (ctx, ed, a) {
        final c = pc();
        if (c != null) {
          c.setBlank(PresentBlank.none, toggle: false);
          return ok();
        }
        final presenter = SlidesUserDefaults.of(
          s,
        ).presenterFlag(SlidesUserDefaults.keyStartWithPresenterView);
        return _start(
          s,
          ed,
          slideId: ed.currentSlideId,
          view: presenter ? PresentView.presenter : PresentView.present,
          kiosk: a.boolean('kiosk') ?? false,
        );
      },
    ),
    SlidesCommand(
      'slides.present.fromStart',
      label: (l) => l.cmdPresentFromStart,
      icon: LucideIcons.squarePlay,
      categoryOf: SlidesCategory.present,
      defaultBindings: const [KeyBinding('Enter', mod: true, shift: true)],
      argsSchema: const JsonSchema.object(
        properties: {'kiosk': JsonSchema.boolean()},
      ),
      enabled: (ed, a) => pc() == null && canStart(ed, a),
      reason: cantStart,
      run: (ctx, ed, a) => _start(
        s,
        ed,
        view: PresentView.present,
        kiosk: a.boolean('kiosk') ?? false,
      ),
    ),
    SlidesCommand(
      'slides.present.fromSlide',
      label: (l) => l.cmdPresentFromSlide,
      icon: LucideIcons.play,
      categoryOf: SlidesCategory.present,
      argsSchema: const JsonSchema.object(
        properties: {
          'slideId': JsonSchema.string(),
          'step': JsonSchema.integer(minimum: 0),
        },
      ),
      enabled: (ed, a) => pc() == null && canStart(ed, a),
      reason: cantStart,
      run: (ctx, ed, a) {
        var id = a.string('slideId');
        if (id == null && ed.selectedGroupIds.isNotEmpty) {
          // "Present from this group" (navigator group header).
          final r = ed.order.range(ed.selectedGroupIds.first);
          if (r != null && r.length > 0) id = ed.order.entries[r.start].id;
        }
        id ??= ed.currentSlideId;
        if (id == null || ed.order.entry(id) == null) {
          return CommandResult.failed(slidesL10nOf(s).presentUnknownSlide);
        }
        return _start(
          s,
          ed,
          slideId: id,
          step: a.integer('step'),
          view: PresentView.present,
        );
      },
    ),
    SlidesCommand(
      'slides.present.presenterView',
      label: (l) => l.cmdPresentPresenterView,
      icon: LucideIcons.presentation,
      categoryOf: SlidesCategory.present,
      defaultBindings: const [KeyBinding('Enter', mod: true, alt: true)],
      argsSchema: const JsonSchema.object(
        properties: {
          'from': JsonSchema.string(enumValues: ['current', 'start']),
        },
      ),
      enabled: (ed, a) => pc() == null && canStart(ed, a),
      reason: cantStart,
      run: (ctx, ed, a) => _start(
        s,
        ed,
        slideId: a.string('from') == 'start' ? null : ed.currentSlideId,
        view: PresentView.presenter,
      ),
    ),
    SlidesCommand(
      'slides.present.openOnAnotherDevice',
      label: (l) => l.cmdPresentOpenOnAnotherDevice,
      icon: LucideIcons.monitorSmartphone,
      categoryOf: SlidesCategory.present,
      enabled: (ed, a) {
        final h = activePresentation.value;
        if (h != null) return h.view == PresentView.presenter;
        return canStart(ed, a) && s.connectivity.online;
      },
      reason: (l, ed) => activePresentation.value != null
          ? l.reasonPresenterViewOnly
          : !s.connectivity.online
          ? l.presentOfflineNoDevices
          : cantStart(l, ed),
      run: (ctx, ed, a) async {
        final h = activePresentation.value;
        if (h != null) {
          await h.openOnAnotherDevice();
          return ok();
        }
        // From the editor: the presenter view creates the session and
        // shows the link once it is ready.
        return _start(
          s,
          ed,
          slideId: ed.currentSlideId,
          view: PresentView.presenter,
          share: true,
        );
      },
    ),
    SlidesCommand(
      'slides.present.joinAsAudience',
      label: (l) => l.cmdPresentJoinAsAudience,
      icon: LucideIcons.monitor,
      categoryOf: SlidesCategory.present,
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'sessionId': JsonSchema.string(pattern: r'^[0-9A-Za-z]{16,32}$'),
        },
        required: ['sessionId'],
      ),
      enabled: (ed, a) => pc() == null && ed.isReady,
      reason: (l, ed) => l.reasonDeckLoading,
      run: (ctx, ed, a) {
        final id = a.requireString('sessionId');
        unawaited(PresentPlatform.instance.requestFullscreen());
        s.router.go(
          '${s.config.itemPath(ed.session.itemUuid.uuid)}/present'
          '?view=audience&session=$id',
        );
        return ok();
      },
    ),
    inPresent(
      'slides.present.end',
      label: (l) => l.cmdPresentEnd,
      icon: LucideIcons.x,
      keys: const [KeyBinding('Escape')],
      run: (c, a) => c.end(),
    ),
    inPresent(
      'slides.present.next',
      label: (l) => l.cmdPresentNext,
      icon: LucideIcons.chevronRight,
      keys: const [
        KeyBinding('ArrowRight'),
        KeyBinding('ArrowDown'),
        KeyBinding('Space'),
        KeyBinding('Enter'),
        KeyBinding('PageDown'),
        KeyBinding('N'),
      ],
      run: (c, a) => c.next(),
    ),
    inPresent(
      'slides.present.previous',
      label: (l) => l.cmdPresentPrevious,
      icon: LucideIcons.chevronLeft,
      keys: const [
        KeyBinding('ArrowLeft'),
        KeyBinding('ArrowUp'),
        KeyBinding('Backspace'),
        KeyBinding('PageUp'),
        KeyBinding('P'),
        KeyBinding('Space', shift: true),
      ],
      run: (c, a) => c.previous(),
    ),
    inPresent(
      'slides.present.nextSlide',
      label: (l) => l.cmdPresentNextSlide,
      icon: LucideIcons.chevronsRight,
      keys: const [KeyBinding('ArrowRight', shift: true), KeyBinding(']')],
      run: (c, a) => c.nextSlide(),
    ),
    inPresent(
      'slides.present.previousSlide',
      label: (l) => l.cmdPresentPreviousSlide,
      icon: LucideIcons.chevronsLeft,
      keys: const [KeyBinding('ArrowLeft', shift: true), KeyBinding('[')],
      run: (c, a) => c.previousSlide(),
    ),
    inPresent(
      'slides.present.first',
      label: (l) => l.cmdPresentFirst,
      icon: LucideIcons.chevronFirst,
      keys: const [KeyBinding('Home')],
      run: (c, a) => c.first(),
    ),
    inPresent(
      'slides.present.last',
      label: (l) => l.cmdPresentLast,
      icon: LucideIcons.chevronLast,
      keys: const [KeyBinding('End')],
      run: (c, a) => c.last(),
    ),
    SlidesCommand(
      'slides.present.goTo',
      label: (l) => l.cmdPresentGoTo,
      icon: LucideIcons.listOrdered,
      categoryOf: SlidesCategory.present,
      keyScope: scope,
      argsSchema: const JsonSchema.object(
        properties: {
          'slideId': JsonSchema.string(),
          'position': JsonSchema.integer(
            minimum: 1,
            description: '1-based position in the deck (skipped included)',
          ),
          'step': JsonSchema.integer(minimum: 0),
        },
      ),
      enabled: presenting,
      reason: notPresenting,
      run: (ctx, ed, a) {
        final c = pc();
        if (c == null) return const CommandResult.failed('Not presenting');
        final id = a.string('slideId');
        final pos = a.integer('position');
        final done = id != null
            ? c.goTo(id, a.integer('step') ?? 0)
            : pos != null && c.goToNumber(pos);
        return done
            ? ok()
            : CommandResult.failed(slidesL10nOf(s).presentUnknownSlide);
      },
    ),
    inPresent(
      'slides.present.blank',
      label: (l) => l.cmdPresentBlank,
      icon: LucideIcons.square,
      argsSchema: const JsonSchema.object(
        properties: {
          'color': JsonSchema.string(enumValues: ['black', 'white', 'none']),
        },
        required: ['color'],
      ),
      argKeys: const [
        ArgsKeyBinding(KeyBinding('B'), {'color': 'black'}),
        ArgsKeyBinding(KeyBinding('.'), {'color': 'black'}),
        ArgsKeyBinding(KeyBinding('W'), {'color': 'white'}),
        ArgsKeyBinding(KeyBinding(','), {'color': 'white'}),
      ],
      checked: (c, a) => c.blank.name == a.string('color'),
      run: (c, a) => c.setBlank(PresentBlank.fromName(a.string('color'))),
    ),
    inPresent(
      'slides.present.picker',
      label: (l) => l.cmdPresentPicker,
      icon: LucideIcons.layoutGrid,
      argsSchema: const JsonSchema.object(
        properties: {'open': JsonSchema.boolean()},
      ),
      keys: const [KeyBinding('G'), KeyBinding('-')],
      checked: (c, a) => c.pickerOpen,
      run: (c, a) => c.setPicker(a.boolean('open') ?? !c.pickerOpen),
    ),
    inPresent(
      'slides.present.tool',
      label: (l) => l.cmdPresentTool,
      icon: LucideIcons.pencil,
      argsSchema: JsonSchema.object(
        properties: {
          'tool': JsonSchema.string(
            enumValues: [for (final t in PresentTool.values) t.name],
          ),
          'color': JsonSchema.string(enumValues: InkColors.all.keys.toList()),
          'width': JsonSchema.string(
            enumValues: InkColors.penWidths.keys.toList(),
          ),
          'toggle': const JsonSchema.boolean(),
        },
        required: const ['tool'],
      ),
      argKeys: const [
        ArgsKeyBinding(KeyBinding('L'), {'tool': 'laser', 'toggle': true}),
        ArgsKeyBinding(KeyBinding('D'), {'tool': 'pen', 'toggle': true}),
        ArgsKeyBinding(KeyBinding('H'), {
          'tool': 'highlighter',
          'toggle': true,
        }),
        ArgsKeyBinding(KeyBinding('E'), {'tool': 'eraser', 'toggle': true}),
      ],
      when: (c, a) => !c.mirrors,
      checked: (c, a) => c.tool.name == a.string('tool'),
      run: (c, a) => c.setTool(
        PresentTool.fromName(a.string('tool')) ?? PresentTool.arrow,
        toggle: a.boolean('toggle') ?? false,
        color: InkColors.all[a.string('color')],
        width: InkColors.penWidths[a.string('width')],
      ),
    ),
    inPresent(
      'slides.present.clearInk',
      label: (l) => l.cmdPresentClearInk,
      icon: LucideIcons.brushCleaning,
      argsSchema: const JsonSchema.object(
        properties: {'slideId': JsonSchema.string()},
      ),
      keys: const [KeyBinding('C')],
      when: (c, a) => !c.mirrors,
      run: (c, a) => c.clearInk(a.string('slideId')),
    ),
    inPresent(
      'slides.present.undoInk',
      label: (l) => l.cmdPresentUndoInk,
      icon: LucideIcons.undo2,
      argsSchema: const JsonSchema.object(
        properties: {'slideId': JsonSchema.string()},
      ),
      keys: const [KeyBinding('Z', mod: true)],
      when: (c, a) => !c.mirrors,
      run: (c, a) => c.undoInk(a.string('slideId')),
    ),
    inPresent(
      'slides.present.timer',
      label: (l) => l.cmdPresentTimer,
      icon: LucideIcons.timer,
      argsSchema: const JsonSchema.object(
        properties: {
          'action': JsonSchema.string(
            enumValues: ['start', 'pause', 'resume', 'reset', 'toggle'],
          ),
        },
        required: ['action'],
      ),
      argKeys: const [
        ArgsKeyBinding(KeyBinding('T'), {'action': 'toggle'}),
        ArgsKeyBinding(KeyBinding('R'), {'action': 'reset'}),
      ],
      run: (c, a) => c.timerAction(a.string('action') ?? 'toggle'),
    ),
    inPresent(
      'slides.present.toggleFullscreen',
      label: (l) => l.cmdPresentToggleFullscreen,
      icon: LucideIcons.maximize,
      keys: const [KeyBinding('F')],
      run: (c, a) => unawaited(activePresentation.value?.toggleFullscreen()),
    ),
    inPresent(
      'slides.present.toggleSkipped',
      label: (l) => l.cmdPresentToggleSkipped,
      icon: LucideIcons.eyeOff,
      when: (c, a) => c.view == PresentView.presenter,
      checked: (c, a) => c.showSkipped,
      run: (c, a) => c.setShowSkipped(!c.showSkipped),
    ),
    inPresent(
      'slides.present.notesSize',
      label: (l) => l.cmdPresentNotesSize,
      icon: LucideIcons.aLargeSmall,
      argsSchema: const JsonSchema.object(
        properties: {
          'delta': JsonSchema.integer(minimum: -36, maximum: 36),
          'size': JsonSchema.integer(minimum: 12, maximum: 48),
        },
      ),
      argKeys: const [
        ArgsKeyBinding(KeyBinding('=', mod: true), {'delta': 2}),
        ArgsKeyBinding(KeyBinding('-', mod: true), {'delta': -2}),
      ],
      when: (c, a) => c.view == PresentView.presenter,
      run: (c, a) {
        final size =
            a.integer('size') ?? c.notesSize + (a.integer('delta') ?? 0);
        c.setNotesSize(size);
        unawaited(
          SlidesUserDefaults.of(
            s,
          ).setPresenter(SlidesUserDefaults.keyNotesSize, c.notesSize),
        );
      },
    ),
    inPresent(
      'slides.present.help',
      label: (l) => l.cmdPresentHelp,
      icon: LucideIcons.keyboard,
      // `?` (Shift+/) is handled by the present screen (no chord name).
      keys: const [KeyBinding('/')],
      checked: (c, a) => c.helpOpen,
      run: (c, a) => c.setHelp(!c.helpOpen),
    ),
    SlidesCommand(
      'slides.deck.setPresentSettings',
      label: (l) => l.cmdDeckSetPresentSettings,
      icon: LucideIcons.settings2,
      categoryOf: SlidesCategory.present,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'patch': JsonSchema.object(
            additionalProperties: true,
            description: 'Keys of Deck.presentJson (Slides 10 §3)',
          ),
        },
        required: ['patch'],
      ),
      run: (ctx, ed, a) {
        final raw = a.values['patch'];
        if (raw is! Map) return const CommandResult.failed('patch required');
        final PresentSettings next;
        try {
          next = PresentSettings.parse(
            ed.model.deck?.presentJson,
          ).patched(raw.cast<String, Object?>());
        } on FormatException catch (e) {
          return CommandResult.failed(e.message);
        }
        ed.apply(
          ctx,
          SetDeckProps(presentJson: Patch(jsonEncode(next.toJson()))),
        );
        return ok(next.toJson());
      },
    ),
  ];
}

/// Opens the present route; present mode asks for full screen within the
/// user gesture (10 §1.3).
CommandResult _start(
  ShellServices s,
  DeckEditorController ed, {
  String? slideId,
  int? step,
  required PresentView view,
  bool kiosk = false,
  bool share = false,
}) {
  final defaults = SlidesUserDefaults.of(s);
  if (view == PresentView.present &&
      defaults.presenterFlag(SlidesUserDefaults.keyStartFullscreen)) {
    unawaited(PresentPlatform.instance.requestFullscreen());
  }
  final q = <String, String>{
    if (view == PresentView.presenter) 'view': 'presenter',
    'slide': ?slideId,
    if (step != null && step > 0) 'step': '$step',
    if (kiosk) 'kiosk': '1',
    if (share) 'share': '1',
  };
  final path = '${s.config.itemPath(ed.session.itemUuid.uuid)}/present';
  s.router.go(
    Uri(path: path, queryParameters: q.isEmpty ? null : q).toString(),
  );
  return ok();
}
