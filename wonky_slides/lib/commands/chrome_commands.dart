import 'package:flutter/widgets.dart' show IconData;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../features/dialogs/go_to_slide_dialog.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/settings/slides_user_defaults.dart';
import 'slides_command.dart';

/// The editor chrome's commands (Slides 04 §2–§8, §14; SL-11): view modes,
/// panes, the inspector (incl. the `slides.panel.animate` alias), zoom,
/// View › Show toggles, Editing/Viewing, slide navigation and the Select
/// tool. None of them changes the deck (not undoable).
List<Command<CommandArgs>> chromeCommands(ShellServices s) => [
  // ---- View modes (04 §2)
  SlidesCommand(
    'slides.view.setMode',
    label: (l) => l.cmdViewSetMode,
    icon: LucideIcons.layoutGrid,
    categoryOf: SlidesCategory.view,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'mode': JsonSchema.string(
          enumValues: [for (final m in DeckViewMode.values) m.name],
        ),
      },
      required: const ['mode'],
    ),
    // Masters mode edits layouts (05 §8): editors only.
    enabled: (ed, a) => a.string('mode') != 'masters' || ed.canEdit,
    reason: (l, ed) =>
        ed.roleCanEdit ? l.reasonViewingMode : l.reasonViewAccess,
    checked: (ed, a) => ed.mode.name == a.string('mode'),
    run: (ctx, ed, a) {
      final mode = DeckViewMode.fromName(a.string('mode'));
      if (mode == null) return const CommandResult.failed('Unknown mode');
      ed.setMode(mode);
      return ok();
    },
  ),
  _toggle(
    'slides.view.toggleNavigator',
    (l) => l.cmdViewToggleNavigator,
    LucideIcons.panelLeft,
    get: (ed) => ed.navigatorVisible,
    set: (ed, v) => ed.setNavigatorVisible(v),
  ),
  _toggle(
    'slides.view.toggleInspector',
    (l) => l.cmdViewToggleInspector,
    LucideIcons.panelRight,
    bindings: const [KeyBinding('I', mod: true, alt: true, shift: true)],
    get: (ed) => ed.inspectorVisible,
    set: (ed, v) => ed.setInspectorVisible(v),
  ),
  _toggle(
    'slides.view.toggleNotes',
    (l) => l.cmdViewToggleNotes,
    LucideIcons.panelBottom,
    bindings: const [KeyBinding('N', mod: true, alt: true, shift: true)],
    get: (ed) => ed.notesVisible,
    set: (ed, v) => ed.setNotesVisible(v),
  ),
  _toggle(
    'slides.view.toggleRulers',
    (l) => l.cmdViewToggleRulers,
    LucideIcons.ruler,
    bindings: const [KeyBinding('R', mod: true, alt: true, shift: true)],
    get: (ed) => ed.rulers,
    set: (ed, v) => ed.toggleView('rulers'),
  ),
  _toggle(
    'slides.view.toggleGuides',
    (l) => l.cmdViewToggleGuides,
    LucideIcons.grid3x3,
    get: (ed) => ed.guides,
    set: (ed, v) => ed.toggleView('guides'),
  ),
  _toggle(
    'slides.view.toggleCommentPins',
    (l) => l.cmdViewToggleCommentPins,
    LucideIcons.messageSquare,
    get: (ed) => ed.commentPins,
    set: (ed, v) => ed.toggleView('commentPins'),
  ),
  // Snapping and collaborator cursors are Slides settings (04 §13.16):
  // the View toggles change the same synced preference.
  for (final (id, label, key) in <(String, SlidesText, String)>[
    (
      'slides.view.toggleRemoteCursors',
      (l) => l.cmdViewToggleRemoteCursors,
      SlidesUserDefaults.keyShowRemoteCursors,
    ),
    (
      'slides.view.toggleSmartGuides',
      (l) => l.cmdViewToggleSmartGuides,
      SlidesUserDefaults.keySmartGuides,
    ),
    (
      'slides.view.toggleSnapObjects',
      (l) => l.cmdViewToggleSnapObjects,
      SlidesUserDefaults.keySnapObjects,
    ),
    (
      'slides.view.toggleSnapGuides',
      (l) => l.cmdViewToggleSnapGuides,
      SlidesUserDefaults.keySnapGuides,
    ),
  ])
    SlidesCommand(
      id,
      label: label,
      categoryOf: SlidesCategory.view,
      checked: (ed, a) => ed.defaults.flag(key),
      run: (ctx, ed, a) async {
        final err = await ed.defaults.set(key, !ed.defaults.flag(key));
        return err == null ? ok() : CommandResult.failed(err);
      },
    ),

  // ---- Zoom (03 §2.2)
  SlidesCommand(
    'slides.view.zoomFit',
    label: (l) => l.cmdViewZoomFit,
    icon: LucideIcons.scan,
    categoryOf: SlidesCategory.view,
    defaultBindings: const [KeyBinding('0', mod: true, alt: true)],
    checked: (ed, a) => ed.zoomFit,
    run: (ctx, ed, a) {
      ed.setZoomFit();
      return ok();
    },
  ),
  SlidesCommand(
    'slides.view.zoom',
    label: (l) => l.cmdViewZoom,
    icon: LucideIcons.zoomIn,
    categoryOf: SlidesCategory.view,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'percent': JsonSchema.integer(minimum: 10, maximum: 400)},
      required: ['percent'],
    ),
    checked: (ed, a) =>
        !ed.zoomFit && (ed.zoom * 100).round() == a.integer('percent'),
    run: (ctx, ed, a) {
      final p = a.integer('percent');
      if (p == null) return const CommandResult.failed('percent is required');
      ed.setZoom(p / 100);
      return ok();
    },
  ),
  SlidesCommand(
    'slides.view.zoomIn',
    label: (l) => l.cmdViewZoomIn,
    icon: LucideIcons.zoomIn,
    categoryOf: SlidesCategory.view,
    defaultBindings: const [KeyBinding('=', mod: true, alt: true)],
    run: (ctx, ed, a) {
      ed.stepZoom(1);
      return ok();
    },
  ),
  SlidesCommand(
    'slides.view.zoomOut',
    label: (l) => l.cmdViewZoomOut,
    icon: LucideIcons.zoomOut,
    categoryOf: SlidesCategory.view,
    defaultBindings: const [KeyBinding('-', mod: true, alt: true)],
    run: (ctx, ed, a) {
      ed.stepZoom(-1);
      return ok();
    },
  ),

  // ---- Inspector (04 §7) and the Animate alias (06 §5, Q21)
  SlidesCommand(
    'slides.inspector.open',
    label: (l) => l.cmdInspectorOpen,
    icon: LucideIcons.slidersHorizontal,
    categoryOf: SlidesCategory.view,
    argsSchema: JsonSchema.object(
      properties: {
        'tab': JsonSchema.string(
          enumValues: [for (final t in InspectorTab.values) t.name],
        ),
        'section': const JsonSchema.string(
          description: 'Section to reveal (arrange, text, fill, …).',
        ),
      },
    ),
    run: (ctx, ed, a) {
      ed.openInspector(
        InspectorTab.fromName(a.string('tab')) ?? InspectorTab.format,
        section: a.string('section'),
      );
      return ok();
    },
  ),
  SlidesCommand(
    'slides.panel.animate',
    label: (l) => l.cmdPanelAnimate,
    icon: LucideIcons.sparkles,
    categoryOf: SlidesCategory.animations,
    argsSchema: const JsonSchema.object(
      properties: {
        'tab': JsonSchema.string(enumValues: ['transition', 'build', 'order']),
      },
    ),
    run: (ctx, ed, a) {
      ed.openInspector(
        InspectorTab.animate,
        animateTab: a.string('tab') ?? ed.animateTab,
      );
      return ok();
    },
  ),

  // ---- Editing / Viewing (04 §4.3 Mode)
  SlidesCommand(
    'slides.mode.editing',
    label: (l) => l.cmdModeEditing,
    icon: LucideIcons.pencil,
    categoryOf: SlidesCategory.view,
    enabled: (ed, a) => ed.roleCanEdit,
    reason: (l, ed) => l.reasonViewAccess,
    checked: (ed, a) => !ed.viewMode,
    run: (ctx, ed, a) {
      ed.setViewMode(false);
      return ok();
    },
  ),
  SlidesCommand(
    'slides.mode.viewing',
    label: (l) => l.cmdModeViewing,
    icon: LucideIcons.eye,
    categoryOf: SlidesCategory.view,
    checked: (ed, a) => ed.viewMode,
    run: (ctx, ed, a) {
      ed.setViewMode(true);
      ed.armTool(null);
      return ok();
    },
  ),

  // ---- Slide navigation (04 §4.6, §13.10)
  SlidesCommand(
    'slides.nav.previousSlide',
    label: (l) => l.cmdNavPreviousSlide,
    icon: LucideIcons.chevronUp,
    categoryOf: SlidesCategory.slides,
    keyScope: SlidesKeyScopes.canvas,
    defaultBindings: const [KeyBinding('PageUp')],
    argBindings: const [
      ArgsKeyBinding(
        KeyBinding('PageUp'),
        {},
        scope: SlidesKeyScopes.navigator,
      ),
    ],
    enabled: (ed, a) => (ed.currentEntry?.index ?? 0) > 0,
    reason: (l, ed) => l.reasonFirstSlide,
    run: (ctx, ed, a) {
      ed.stepSlide(-1);
      return ok();
    },
  ),
  SlidesCommand(
    'slides.nav.nextSlide',
    label: (l) => l.cmdNavNextSlide,
    icon: LucideIcons.chevronDown,
    categoryOf: SlidesCategory.slides,
    keyScope: SlidesKeyScopes.canvas,
    defaultBindings: const [KeyBinding('PageDown')],
    argBindings: const [
      ArgsKeyBinding(
        KeyBinding('PageDown'),
        {},
        scope: SlidesKeyScopes.navigator,
      ),
    ],
    enabled: (ed, a) =>
        ed.currentEntry != null && ed.currentEntry!.index < ed.order.length - 1,
    reason: (l, ed) => l.reasonLastSlide,
    run: (ctx, ed, a) {
      ed.stepSlide(1);
      return ok();
    },
  ),
  SlidesCommand(
    'slides.nav.goToSlide',
    label: (l) => l.cmdNavGoToSlide,
    icon: LucideIcons.arrowRight,
    categoryOf: SlidesCategory.slides,
    argsSchema: const JsonSchema.object(
      properties: {
        'slideId': JsonSchema.string(
          description: 'The slide to show (omit to choose in a dialog).',
        ),
        'index': JsonSchema.integer(
          minimum: 1,
          description: '1-based position in presentation order.',
        ),
      },
    ),
    enabled: (ed, a) => ed.order.length > 0,
    reason: (l, ed) => l.reasonNoSlides,
    run: (ctx, ed, a) async {
      var id = a.string('slideId');
      final index = a.integer('index');
      if (id == null && index != null) {
        final entries = ed.order.entries;
        if (index < 1 || index > entries.length) {
          return const CommandResult.failed('No slide at that position');
        }
        id = entries[index - 1].id;
      }
      if (id == null) {
        final dc = ctx.dialogContext;
        if (dc == null || !dc.mounted || ctx.source.isAgent) {
          return const CommandResult.failed('slideId is required');
        }
        id = await showGoToSlideDialog(dc, ed);
        if (id == null) return const CommandResult.cancelled();
      }
      if (ed.order.entry(id) == null) {
        return const CommandResult.failed('No such slide');
      }
      ed.setCurrentSlide(id);
      return ok({'slideId': id});
    },
  ),
  SlidesCommand(
    'slides.nav.goToGroup',
    label: (l) => l.cmdNavGoToGroup,
    categoryOf: SlidesCategory.slides,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'groupId': JsonSchema.string()},
      required: ['groupId'],
    ),
    run: (ctx, ed, a) {
      final range = ed.order.range(a.requireString('groupId'));
      if (range == null) return const CommandResult.failed('No such group');
      if (range.length == 0) return ok();
      ed.setCurrentSlide(ed.order.entries[range.start].id);
      return ok();
    },
  ),

  // ---- Tools (04 §6.1)
  SlidesCommand(
    'slides.tool.select',
    label: (l) => l.cmdToolSelect,
    icon: LucideIcons.mousePointer2,
    categoryOf: SlidesCategory.canvas,
    checked: (ed, a) => ed.armedTool == null,
    run: (ctx, ed, a) {
      ed.armTool(null);
      return ok();
    },
  ),
];

/// A View toggle of the editor chrome (checked state = [get]).
SlidesCommand _toggle(
  String id,
  SlidesText label,
  IconData icon, {
  required bool Function(DeckEditorController ed) get,
  required void Function(DeckEditorController ed, bool value) set,
  List<KeyBinding> bindings = const [],
}) => SlidesCommand(
  id,
  label: label,
  icon: icon,
  categoryOf: SlidesCategory.view,
  defaultBindings: bindings,
  checked: (ed, a) => get(ed),
  run: (ctx, ed, a) {
    set(ed, !get(ed));
    return ok();
  },
);
