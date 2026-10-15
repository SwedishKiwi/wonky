import 'dart:convert';

import 'package:flutter/widgets.dart' show BuildContext;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart' show OrderKeys;
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/themes.dart';

import '../features/canvas/canvas_interactions.dart';
import '../features/editor_screen/deck_editor_controller.dart';
import '../features/masters/masters_canvas_layer.dart';
import '../features/masters/masters_targets.dart';
import '../l10n/slides_l10n.dart' show slidesL10n, slidesL10nOf;
import 'slides_command.dart';

/// Masters mode, layouts, masters and the theme editor (Slides 05 §8;
/// SL-28). Every mutating command is one undo step.
///
/// Layouts (`layoutId` defaults to the layout edited in masters mode, else
/// the current slide's layout):
/// - `slides.layout.add {masterId?, basedOn?, name?}`,
///   `duplicate {layoutId?}`, `rename {layoutId?, name?}` (dialog without
///   a name), `move {layoutId?, to? | direction?: up|down}`,
///   `delete {layoutId?, replaceWith?}` (a used layout asks to apply
///   another layout of the master to its slides first),
///   `setBackground {layoutId?, color? | fill? | reset?}`,
///   `setHideMasterElements {layoutId?, value?}`, `toggleHidden {layoutId?}`,
///   `insertPlaceholder {layoutId? | masterId?, type}`.
///
/// Masters (`masterId` defaults to the edited master, else the edited or
/// current layout's master): `slides.master.add {themeId?}`,
/// `duplicate {masterId?}`, `rename {masterId?, name?}`,
/// `delete {masterId?}` (not the last, not while used),
/// `setBackground {masterId?, color? | fill? | reset?}`.
///
/// Theme editor (`themeId` defaults to the edited master's theme, else the
/// default theme): `slides.theme.edit {themeId?}` opens masters mode on it
/// with the Theme tab; `slides.theme.update {themeId?, name?, columns}`
/// writes whole JSON columns (05 §8.4: one column per committed control);
/// `slides.theme.deriveDarkColors {themeId?}`;
/// `slides.theme.resetToBuiltIn {themeId?}`.
///
/// `slides.masters.exit` (Esc on the canvas with nothing selected) returns
/// to Normal view.
List<Command<CommandArgs>> masterCommands(ShellServices s) {
  CanvasInteractions.register(MastersCanvasLayer.new);
  return [
    // ---- Masters mode
    SlidesCommand(
      'slides.masters.exit',
      label: (l) => l.cmdMastersExit,
      icon: LucideIcons.check,
      categoryOf: SlidesCategory.view,
      defaultBindings: [KeyBinding('Escape')],
      keyScope: SlidesKeyScopes.canvas,
      showInPalette: false,
      enabled: (ed, a) =>
          ed.editsMasters && ed.selectedElementIds.isEmpty && !ed.textEditing,
      run: (ctx, ed, a) {
        ed.setMode(DeckViewMode.normal);
        ed.canvasFocus.requestFocus();
        return ok();
      },
    ),
    // ---- Layouts (05 §8.2)
    SlidesCommand(
      'slides.layout.add',
      label: (l) => l.cmdLayoutAdd,
      icon: LucideIcons.squarePlus,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'masterId': JsonSchema.string(),
          'basedOn': JsonSchema.string(
            description: 'A layout to copy (else blank with a title)',
          ),
          'name': JsonSchema.string(),
        },
      ),
      enabled: (ed, a) => MastersTargets.master(ed, a) != null,
      reason: (l, ed) => l.reasonNoMaster,
      run: (ctx, ed, a) {
        final m = MastersTargets.master(ed, a)!;
        final basedOn = a.string('basedOn');
        if (basedOn != null && ed.model.layout(basedOn) == null) {
          return const CommandResult.failed('Layout not found');
        }
        final l = slidesL10nOf(s);
        final plan = ed.apply(
          ctx,
          AddLayout(
            m.id,
            layoutName:
                a.string('name') ??
                (basedOn == null
                    ? l.layoutDefaultName(ed.model.layoutsOf(m.id).length + 1)
                    : null),
            duplicateOf: basedOn,
          ),
        );
        final id = plan.result['layoutId']! as String;
        _show(ed, id);
        return ok({'layoutId': id});
      },
    ),
    SlidesCommand(
      'slides.layout.duplicate',
      label: (l) => l.cmdLayoutDuplicate,
      icon: LucideIcons.copy,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {'layoutId': JsonSchema.string()},
      ),
      enabled: (ed, a) => MastersTargets.layout(ed, a) != null,
      reason: (l, ed) => l.reasonNoLayout,
      run: (ctx, ed, a) {
        final layout = MastersTargets.layout(ed, a)!;
        final l = slidesL10nOf(s);
        final plan = ed.apply(
          ctx,
          AddLayout(
            layout.masterId!,
            layoutName: _clip(l.themeCopyName(layout.name)),
            duplicateOf: layout.id,
          ),
        );
        final id = plan.result['layoutId']! as String;
        _show(ed, id);
        return ok({'layoutId': id});
      },
    ),
    SlidesCommand(
      'slides.layout.rename',
      label: (l) => l.cmdLayoutRename,
      icon: LucideIcons.pencil,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'layoutId': JsonSchema.string(),
          'name': JsonSchema.string(),
        },
      ),
      enabled: (ed, a) => MastersTargets.layout(ed, a) != null,
      reason: (l, ed) => l.reasonNoLayout,
      run: (ctx, ed, a) async {
        final layout = MastersTargets.layout(ed, a)!;
        final l = slidesL10nOf(s);
        if (a.string('name') == null && ctx.source.isAgent) {
          return const CommandResult.failed('name is required');
        }
        final name =
            a.string('name') ??
            await _askName(ctx, l.layoutRenameTitle, layout.name);
        if (name == null) return const CommandResult.cancelled();
        if (name.trim() == layout.name) return ok();
        ed.apply(ctx, UpdateMasterOrLayout(layout.id, {SlidesCols.name: name}));
        return ok();
      },
    ),
    SlidesCommand(
      'slides.layout.move',
      label: (l) => l.cmdLayoutMove,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'layoutId': JsonSchema.string(),
          'to': JsonSchema.integer(
            description: 'The new 0-based position among the master layouts',
          ),
          'direction': JsonSchema.string(enumValues: ['up', 'down']),
        },
      ),
      enabled: (ed, a) => _moveTarget(ed, a) != null,
      reason: (l, ed) => l.reasonNoLayout,
      undoLabelOf: (l, a) => l.cmdLayoutMove,
      run: (ctx, ed, a) {
        final (layout, to) = _moveTarget(ed, a)!;
        final siblings = OrderKeys.sorted([
          for (final x in ed.model.layoutsOf(layout.masterId!))
            (x.sortKey, x.id),
        ]);
        final from = siblings.indexWhere((x) => x.$2 == layout.id);
        if (from == to) return ok();
        // Index among the siblings without the moved layout.
        final key = OrderKeys.at(
          siblings,
          to > from ? to + 1 : to,
          1,
          exclude: {layout.id},
        ).single;
        ed.apply(
          ctx,
          UpdateMasterOrLayout(layout.id, {SlidesCols.sortKey: key}),
        );
        return ok();
      },
    ),
    SlidesCommand(
      'slides.layout.delete',
      label: (l) => l.cmdLayoutDelete,
      icon: LucideIcons.trash2,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'layoutId': JsonSchema.string(),
          'replaceWith': JsonSchema.string(
            description:
                'A layout of the same master applied to the slides using '
                'this one before it is deleted (05 §8.2, P1)',
          ),
        },
      ),
      enabled: (ed, a) {
        final layout = MastersTargets.layout(ed, a);
        return layout != null &&
            ed.model.layoutsOf(layout.masterId ?? '').length > 1;
      },
      reason: (l, ed) {
        final layout = MastersTargets.layout(ed, const JsonArgs());
        return layout == null ? l.reasonNoLayout : l.reasonLastLayout;
      },
      run: (ctx, ed, a) async {
        final layout = MastersTargets.layout(ed, a)!;
        final l = slidesL10nOf(s);
        final users = MastersTargets.slidesUsing(ed, layout.id);
        var replacement = a.string('replaceWith');
        if (users.isNotEmpty && replacement == null) {
          final proposed = MastersTargets.replacementFor(ed, layout);
          final dc = ctx.dialogContext;
          if (proposed == null) {
            return CommandResult.failed(l.reasonLayoutUsed(users.length));
          }
          if (dc == null || !dc.mounted || ctx.source.isAgent) {
            return CommandResult.failed(l.reasonLayoutUsed(users.length));
          }
          final r = await showWonkyFormDialog(
            dc,
            WonkyDialogSpec(
              title: l.layoutDeleteTitle,
              description: l.layoutDeleteUsedBody(
                users.length,
                layout.name,
                proposed.name,
              ),
              dialogKey: 'dialog.slides.deleteLayout',
              buttons: [
                DialogButtonSpec(id: 'cancel', label: l.dialogCancel),
                DialogButtonSpec(
                  id: 'delete',
                  label: l.layoutDeleteApplyAndDelete,
                  primary: true,
                  destructive: true,
                ),
              ],
            ),
          );
          if (r?.buttonId != 'delete') return const CommandResult.cancelled();
          replacement = proposed.id;
        }
        if (users.isNotEmpty) {
          final target = ed.model.layout(replacement!);
          if (target == null ||
              target.id == layout.id ||
              target.masterId != layout.masterId) {
            return const CommandResult.failed(
              'replaceWith must be another layout of the same master',
            );
          }
          ed.apply(ctx, SetSlideProps(users, layoutId: target.id));
        }
        final next = MastersTargets.neighbor(ed, layout);
        ed.apply(ctx, DeleteMastersOrLayouts([layout.id]));
        if (ed.editsMasters && next != null) ed.setMasterTarget(next);
        return ok();
      },
    ),
    SlidesCommand(
      'slides.layout.setBackground',
      label: (l) => l.cmdLayoutSetBackground,
      icon: LucideIcons.wallpaper,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: _backgroundSchema(
        'layoutId',
        'Inherit the master background',
      ),
      enabled: (ed, a) => MastersTargets.layout(ed, a) != null,
      reason: (l, ed) => l.reasonNoLayout,
      run: (ctx, ed, a) {
        final layout = MastersTargets.layout(ed, a)!;
        return _setBackground(ctx, ed, a, layout.id);
      },
    ),
    SlidesCommand(
      'slides.layout.setHideMasterElements',
      label: (l) => l.cmdLayoutSetHideMasterElements,
      icon: LucideIcons.eyeOff,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'layoutId': JsonSchema.string(),
          'value': JsonSchema.boolean(description: 'Omitted = toggle'),
        },
      ),
      enabled: (ed, a) => MastersTargets.layout(ed, a) != null,
      reason: (l, ed) => l.reasonNoLayout,
      checked: (ed, a) => MastersTargets.layout(ed, a)?.hideMasterElements,
      run: (ctx, ed, a) {
        final layout = MastersTargets.layout(ed, a)!;
        final v = a.boolean('value') ?? !layout.hideMasterElements;
        if (v == layout.hideMasterElements) return ok();
        ed.apply(
          ctx,
          UpdateMasterOrLayout(layout.id, {SlidesCols.hideMasterElements: v}),
        );
        return ok();
      },
    ),
    SlidesCommand(
      'slides.layout.toggleHidden',
      label: (l) => l.cmdLayoutToggleHidden,
      icon: LucideIcons.eyeOff,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'layoutId': JsonSchema.string(),
          'value': JsonSchema.boolean(description: 'Omitted = toggle'),
        },
      ),
      enabled: (ed, a) => MastersTargets.layout(ed, a) != null,
      reason: (l, ed) => l.reasonNoLayout,
      checked: (ed, a) => MastersTargets.layout(ed, a)?.hidden,
      run: (ctx, ed, a) {
        final layout = MastersTargets.layout(ed, a)!;
        final v = a.boolean('value') ?? !layout.hidden;
        if (v == layout.hidden) return ok();
        ed.apply(ctx, UpdateMasterOrLayout(layout.id, {SlidesCols.hidden: v}));
        return ok();
      },
    ),
    SlidesCommand(
      'slides.layout.insertPlaceholder',
      label: (l) => l.cmdLayoutInsertPlaceholder,
      icon: LucideIcons.squareDashed,
      categoryOf: SlidesCategory.insert,
      mutates: true,
      argsSchema: JsonSchema.object(
        properties: {
          'type': JsonSchema.string(
            enumValues: [for (final t in MastersTargets.insertable) t.name],
          ),
          'layoutId': const JsonSchema.string(),
          'masterId': const JsonSchema.string(),
        },
        required: const ['type'],
      ),
      enabled: (ed, a) => MastersTargets.placeholderOwner(ed, a) != null,
      reason: (l, ed) => l.reasonMastersOnly,
      run: (ctx, ed, a) {
        final type = SlidePlaceholderType.fromName(a.string('type'));
        if (type == null || !MastersTargets.insertable.contains(type)) {
          return const CommandResult.failed('Unknown placeholder type');
        }
        final (ownerId, kind) = MastersTargets.placeholderOwner(ed, a)!;
        final spec = MastersTargets.placeholderSpec(
          ed,
          ownerId,
          kind,
          type,
          prompt: slidesL10nOf(s).placeholderPrompt(type.name),
        );
        final plan = ed.apply(
          ctx,
          InsertElements(ownerId, [spec], ownerKind: kind),
        );
        final ids = (plan.result['elementIds'] as List? ?? const [])
            .whereType<String>()
            .toList();
        if (ed.surfaceId == ownerId) ed.selectElements(ids);
        return ok({'elementId': ids.isEmpty ? null : ids.first});
      },
    ),
    // ---- Masters (05 §8.2)
    SlidesCommand(
      'slides.master.add',
      label: (l) => l.cmdMasterAdd,
      icon: LucideIcons.squarePlus,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'themeId': JsonSchema.string(),
          'name': JsonSchema.string(),
        },
      ),
      enabled: (ed, a) => MastersTargets.theme(ed, a) != null,
      run: (ctx, ed, a) {
        final t = MastersTargets.theme(ed, a)!;
        final l = slidesL10nOf(s);
        final plan = ed.apply(
          ctx,
          AddMaster(
            t.id,
            masterName:
                a.string('name') ??
                l.masterDefaultName(ed.model.mastersOf(t.id).length + 1),
          ),
        );
        final id = plan.result['masterId']! as String;
        _show(ed, id);
        return ok({'masterId': id});
      },
    ),
    SlidesCommand(
      'slides.master.duplicate',
      label: (l) => l.cmdMasterDuplicate,
      icon: LucideIcons.copy,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {'masterId': JsonSchema.string()},
      ),
      enabled: (ed, a) => MastersTargets.master(ed, a) != null,
      reason: (l, ed) => l.reasonNoMaster,
      run: (ctx, ed, a) {
        final m = MastersTargets.master(ed, a)!;
        final l = slidesL10nOf(s);
        final plan = ed.apply(
          ctx,
          AddMaster(
            m.themeId!,
            masterName: _clip(l.themeCopyName(m.name)),
            duplicateOf: m.id,
          ),
        );
        final id = plan.result['masterId']! as String;
        _show(ed, id);
        return ok({'masterId': id});
      },
    ),
    SlidesCommand(
      'slides.master.rename',
      label: (l) => l.cmdMasterRename,
      icon: LucideIcons.pencil,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {
          'masterId': JsonSchema.string(),
          'name': JsonSchema.string(),
        },
      ),
      enabled: (ed, a) => MastersTargets.master(ed, a) != null,
      reason: (l, ed) => l.reasonNoMaster,
      run: (ctx, ed, a) async {
        final m = MastersTargets.master(ed, a)!;
        final l = slidesL10nOf(s);
        if (a.string('name') == null && ctx.source.isAgent) {
          return const CommandResult.failed('name is required');
        }
        final name =
            a.string('name') ??
            await _askName(ctx, l.masterRenameTitle, m.name);
        if (name == null) return const CommandResult.cancelled();
        if (name.trim() == m.name) return ok();
        ed.apply(ctx, UpdateMasterOrLayout(m.id, {SlidesCols.name: name}));
        return ok();
      },
    ),
    SlidesCommand(
      'slides.master.delete',
      label: (l) => l.cmdMasterDelete,
      icon: LucideIcons.trash2,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {'masterId': JsonSchema.string()},
      ),
      enabled: (ed, a) {
        final m = MastersTargets.master(ed, a);
        return m != null &&
            ed.model.mastersOf(m.themeId ?? '').length > 1 &&
            ed.model.indexes.themes.slidesUsingMaster(m.id) == 0;
      },
      reason: (l, ed) {
        final m = MastersTargets.master(ed, const JsonArgs());
        if (m == null) return l.reasonNoMaster;
        final used = ed.model.indexes.themes.slidesUsingMaster(m.id);
        return used > 0 ? l.reasonMasterUsed(used) : l.reasonLastMaster;
      },
      run: (ctx, ed, a) {
        final m = MastersTargets.master(ed, a)!;
        final others = [
          for (final x in ed.model.mastersOf(m.themeId!))
            if (x.id != m.id) x,
        ];
        ed.apply(ctx, DeleteMastersOrLayouts([m.id]));
        if (ed.editsMasters && others.isNotEmpty) {
          ed.setMasterTarget(others.first.id);
        }
        return ok();
      },
    ),
    SlidesCommand(
      'slides.master.setBackground',
      label: (l) => l.cmdMasterSetBackground,
      icon: LucideIcons.wallpaper,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: _backgroundSchema('masterId', 'Use the theme background'),
      enabled: (ed, a) => MastersTargets.master(ed, a) != null,
      reason: (l, ed) => l.reasonNoMaster,
      run: (ctx, ed, a) {
        final m = MastersTargets.master(ed, a)!;
        return _setBackground(ctx, ed, a, m.id);
      },
    ),
    // ---- Theme editor (05 §8.4)
    SlidesCommand(
      'slides.theme.edit',
      label: (l) => l.cmdThemeEdit,
      icon: LucideIcons.palette,
      categoryOf: SlidesCategory.slides,
      argsSchema: const JsonSchema.object(
        properties: {'themeId': JsonSchema.string()},
      ),
      enabled: (ed, a) => ed.canEdit && MastersTargets.theme(ed, a) != null,
      reason: (l, ed) =>
          ed.roleCanEdit ? l.reasonViewingMode : l.reasonViewAccess,
      run: (ctx, ed, a) {
        final t = MastersTargets.theme(ed, a)!;
        // Keep the edited layout/master when it is of this theme; else
        // show the theme's (first) master.
        final current = MastersTargets.themeOfTarget(ed);
        ed.setMode(
          DeckViewMode.masters,
          masterTarget: current?.id == t.id
              ? null
              : MastersTargets.firstTargetOf(ed, t.id),
        );
        ed.openInspector(InspectorTab.theme);
        return ok({'themeId': t.id});
      },
    ),
    SlidesCommand(
      'slides.theme.update',
      label: (l) => l.cmdThemeUpdate,
      icon: LucideIcons.palette,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      showInPalette: false,
      argsSchema: JsonSchema.object(
        properties: {
          'themeId': const JsonSchema.string(),
          'name': const JsonSchema.string(),
          'columns': JsonSchema.object(
            description:
                'Theme JSON columns to replace (05 §2): '
                '${DeckThemeColumn.values.map((c) => c.name).join(', ')}; '
                'each a JSON object (or its string)',
            additionalProperties: true,
          ),
        },
      ),
      enabled: (ed, a) => MastersTargets.theme(ed, a) != null,
      run: (ctx, ed, a) {
        final t = MastersTargets.theme(ed, a)!;
        final raw = a.values['columns'];
        final columns = <String, String?>{};
        if (raw is Map) {
          for (final MapEntry(:key, :value) in raw.entries) {
            columns['$key'] = value == null
                ? null
                : value is String
                ? value
                : jsonEncode(value);
          }
        }
        final name = a.string('name');
        if (columns.isEmpty && name == null) return ok();
        ed.apply(ctx, UpdateTheme(t.id, themeName: name, columns: columns));
        return ok();
      },
    ),
    SlidesCommand(
      'slides.theme.deriveDarkColors',
      label: (l) => l.cmdThemeDeriveDarkColors,
      icon: LucideIcons.moon,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {'themeId': JsonSchema.string()},
      ),
      enabled: (ed, a) => MastersTargets.theme(ed, a) != null,
      run: (ctx, ed, a) {
        final t = MastersTargets.theme(ed, a)!;
        final data = SlideResolver.themeDataOf(t);
        final derived = const ThemeDarkDeriver().deriveColors(data.colors);
        ed.apply(
          ctx,
          UpdateTheme(
            t.id,
            columns: {
              DeckThemeColumn.colorsJson.name: jsonEncode(derived.toJson()),
            },
          ),
        );
        return ok();
      },
    ),
    SlidesCommand(
      'slides.theme.resetToBuiltIn',
      label: (l) => l.cmdThemeResetToBuiltIn,
      icon: LucideIcons.rotateCcw,
      categoryOf: SlidesCategory.slides,
      mutates: true,
      argsSchema: const JsonSchema.object(
        properties: {'themeId': JsonSchema.string()},
      ),
      enabled: (ed, a) {
        final t = MastersTargets.theme(ed, a);
        return t != null && MastersTargets.builtInKeyOf(t) != null;
      },
      reason: (l, ed) => l.reasonNotBuiltInTheme,
      run: (ctx, ed, a) {
        final t = MastersTargets.theme(ed, a)!;
        final key = MastersTargets.builtInKeyOf(t)!;
        final d = ed.model.deck;
        final size = SlideSize.custom(d?.width ?? 1920, d?.height ?? 1080);
        final pkg = BuiltInThemes.package(key, size: size);
        if (pkg == null) return const CommandResult.failed('Unknown theme');
        final cols = pkg.theme.toColumns();
        ed.apply(
          ctx,
          UpdateTheme(
            t.id,
            columns: {
              for (final c in DeckThemeColumn.values)
                if (cols[c.name] case final String v) c.name: v,
            },
          ),
        );
        return ok();
      },
    ),
  ];
}

/// Clips a generated name to the 100-character limit.
String _clip(String name) => name.length > 100 ? name.substring(0, 100) : name;

/// Shows layout or master [id] when masters mode is on.
void _show(DeckEditorController ed, String id) {
  if (ed.editsMasters) ed.setMasterTarget(id);
}

JsonSchema _backgroundSchema(String idKey, String reset) => JsonSchema.object(
  properties: {
    idKey: const JsonSchema.string(),
    'color': const JsonSchema.string(
      description: 'A solid color: `theme:bg2`, `#RRGGBB`',
    ),
    'fill': const JsonSchema.object(
      description: 'A Fill (02 §5.2)',
      additionalProperties: true,
    ),
    'reset': JsonSchema.boolean(description: reset),
  },
);

CommandResult _setBackground(
  CommandContext ctx,
  DeckEditorController ed,
  JsonArgs a,
  String ownerId,
) {
  final color = a.string('color');
  final fill = a.values['fill'];
  final String? json;
  if (a.boolean('reset') ?? false) {
    json = null;
  } else if (color != null || fill is Map) {
    final f = fill is Map
        ? fill.cast<String, Object?>()
        : {'v': 1, 'type': 'solid', 'color': color};
    json = jsonEncode({
      'v': 1,
      'fill': {'v': 1, ...f},
    });
    final sink = IssueSink();
    if (SlideBackground.fromJson(jsonDecode(json), sink) == null ||
        sink.errors.isNotEmpty) {
      return const CommandResult.failed('Invalid background');
    }
  } else {
    ed.openInspector(InspectorTab.slide, section: 'background');
    return ok();
  }
  ed.apply(
    ctx,
    UpdateMasterOrLayout(ownerId, {SlidesCols.backgroundJson: json}),
  );
  return ok();
}

/// The layout to move and its target index among its siblings.
(SlideLayoutRec, int)? _moveTarget(DeckEditorController ed, JsonArgs a) {
  final layout = MastersTargets.layout(ed, a);
  if (layout == null) return null;
  final siblings = OrderKeys.sorted([
    for (final x in ed.model.layoutsOf(layout.masterId ?? ''))
      (x.sortKey, x.id),
  ]);
  final from = siblings.indexWhere((x) => x.$2 == layout.id);
  final to =
      a.integer('to') ??
      switch (a.string('direction')) {
        'up' => from - 1,
        'down' => from + 1,
        _ => null,
      };
  if (to == null || to < 0 || to >= siblings.length || to == from) return null;
  return (layout, to);
}

Future<String?> _askName(
  CommandContext ctx,
  String title,
  String initial,
) async {
  final dc = ctx.dialogContext;
  if (dc == null || !dc.mounted || ctx.source.isAgent) return null;
  return askMastersName(dc, title: title, initial: initial);
}

/// The rename dialog of layouts and masters (MCP-describable).
Future<String?> askMastersName(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final l = slidesL10n(context);
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: title,
      dialogKey: 'dialog.slides.renameMastersPart',
      fields: [
        TextFieldSpec(
          id: 'name',
          label: l.themeNameLabel,
          initial: initial,
          maxLength: 100,
          validator: (v) => v.trim().isEmpty ? l.themeNameEmpty : null,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: l.dialogCancel),
        DialogButtonSpec(
          id: 'rename',
          label: l.themeRenameButton,
          primary: true,
        ),
      ],
    ),
  );
  if (r?.buttonId != 'rename') return null;
  return r!.text('name');
}
