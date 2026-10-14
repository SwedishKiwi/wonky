import 'package:flutter/widgets.dart' show IconData;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/dialogs/sheets_dialogs.dart';
import '../features/formatting/rich_text_editing.dart';
import '../features/formatting/rotation_dialog.dart';
import '../features/number_format/custom_number_format_dialog.dart';
import '../features/number_format/recent_formats.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _fmt(SheetsLocalizations l) => l.categoryFormatting;

/// Number format menu items (06 §5.1), by preset id.
Map<String, NumberFormatMenuItem> get numberFormatPresets => {
  for (final m in NumberFormatPresets.menu) m.id: m,
};

/// Localized label of a number format preset.
String numberFormatLabel(SheetsLocalizations l, String id) => switch (id) {
  'automatic' => l.numberFormatAutomatic,
  'plainText' => l.numberFormatPlainText,
  'number' => l.numberFormatNumber,
  'percent' => l.numberFormatPercent,
  'scientific' => l.numberFormatScientific,
  'accounting' => l.numberFormatAccounting,
  'financial' => l.numberFormatFinancial,
  'currency' => l.numberFormatCurrency,
  'currencyRounded' => l.numberFormatCurrencyRounded,
  'date' => l.numberFormatDate,
  'time' => l.numberFormatTime,
  'dateTime' => l.numberFormatDateTime,
  'duration' => l.numberFormatDuration,
  _ => id,
};

/// Fonts offered by the font picker (06 §6.1). Families that aren't bundled
/// yet render with the default font.
const sheetsCellFonts = [
  'Inter',
  'Roboto',
  'Open Sans',
  'Lato',
  'Source Sans 3',
  'Noto Sans',
  'Nunito',
  'Montserrat',
  'Oswald',
  'Merriweather',
  'Lora',
  'Playfair Display',
  'Noto Serif',
  'Roboto Mono',
  'Source Code Pro',
  'Courier Prime',
  'Caveat',
  'Comfortaa',
  'Arimo',
  'Tinos',
  'Cousine',
  'Carlito',
  'Caladea',
  'Gelasio',
];

/// Toggle state of an attribute on the active cell (04 §4).
bool _activeFlag(SheetEditorController ed, FormatAttr a) =>
    ed.activeFormat().valueOf(a) == true;

SheetsCommand _toggle(
  String id,
  FormatAttr attr,
  SheetsText label,
  IconData icon,
  List<KeyBinding> bindings,
) => SheetsCommand(
  id,
  label: label,
  icon: icon,
  categoryName: _fmt,
  mutates: true,
  repeatable: true,
  keyScope: KeyScope.global,
  defaultBindings: bindings,
  argsSchema: Schemas.object({'value': const JsonSchema.boolean()}),
  checked: (ed, a) => _activeFlag(ed, attr),
  run: (ctx, ed, a) {
    final v = a.boolean('value');
    // A text selection in the cell editor formats that run (06 §11).
    if (RichTextEditing.applyToEditorSelection(
      ed.editor,
      toggleKey: v == null ? attr.column : null,
      values: v == null ? const {} : {attr.column: v},
      cellValue: ed.activeFormat().valueOf(attr) == true,
    )) {
      return ok();
    }
    ed.apply(
      ctx,
      v == null
          ? ToggleFormat(rangesArg(ed, a), attr)
          : SetFormat(rangesArg(ed, a), {attr: v}),
    );
    return ok();
  },
);

SheetsCommand _set(
  String id,
  SheetsText label, {
  IconData? icon,
  required String argName,
  required JsonSchema argSchema,
  required Map<FormatAttr, Object?> Function(JsonArgs a) values,
  bool? Function(SheetEditorController ed, JsonArgs a)? checked,
  List<ArgsKeyBinding> argBindings = const [],
  bool required = true,
}) => SheetsCommand(
  id,
  label: label,
  icon: icon,
  categoryName: _fmt,
  mutates: true,
  repeatable: true,
  keyScope: KeyScope.global,
  argBindings: argBindings,
  argsSchema: Schemas.object({
    argName: argSchema,
  }, required: required ? [argName] : const []),
  checked: checked,
  run: (ctx, ed, a) {
    final v = values(a);
    // Text formats apply to the selected run of the cell editor (06 §11).
    final runKeys = {
      for (final e in v.entries)
        if (_runAttrs.contains(e.key)) e.key.column: e.value,
    };
    if (runKeys.length == v.length &&
        RichTextEditing.applyToEditorSelection(ed.editor, values: runKeys)) {
      return ok();
    }
    ed.apply(ctx, SetFormat(rangesArg(ed, a), v));
    return ok();
  },
);

const _runAttrs = {
  FormatAttr.textColor,
  FormatAttr.fontFamily,
  FormatAttr.fontSize,
};

/// Formatting commands (06 §16, 04 §3.5, §4).
List<Command<CommandArgs>> formatCommands(ShellServices s) => [
  _toggle(
    'sheets.format.bold',
    FormatAttr.bold,
    (l) => l.cmdFormatBold,
    LucideIcons.bold,
    const [KeyBinding('B', mod: true)],
  ),
  _toggle(
    'sheets.format.italic',
    FormatAttr.italic,
    (l) => l.cmdFormatItalic,
    LucideIcons.italic,
    const [KeyBinding('I', mod: true)],
  ),
  _toggle(
    'sheets.format.underline',
    FormatAttr.underline,
    (l) => l.cmdFormatUnderline,
    LucideIcons.underline,
    const [KeyBinding('U', mod: true)],
  ),
  _toggle(
    'sheets.format.strikethrough',
    FormatAttr.strikethrough,
    (l) => l.cmdFormatStrikethrough,
    LucideIcons.strikethrough,
    const [
      KeyBinding('5', alt: true, shift: true, mac: false),
      KeyBinding('X', mod: true, shift: true, mac: true),
    ],
  ),
  _set(
    'sheets.format.fontFamily',
    (l) => l.cmdFormatFontFamily,
    icon: LucideIcons.type,
    argName: 'family',
    argSchema: const JsonSchema.string(),
    values: (a) => {FormatAttr.fontFamily: a.string('family')},
    checked: (ed, a) => a.string('family') == null
        ? null
        : ed.activeFormat().fontFamily == a.string('family'),
  ),
  _set(
    'sheets.format.fontSize',
    (l) => l.cmdFormatFontSize,
    argName: 'size',
    argSchema: const JsonSchema.number(minimum: 1, maximum: 400),
    values: (a) => {
      FormatAttr.fontSize: FontSizeSteps.clampTyped(
        (a.values['size'] as num?)?.toDouble() ?? 10,
      ),
    },
    checked: (ed, a) => a.values['size'] == null
        ? null
        : ed.activeFormat().fontSize == (a.values['size'] as num).toDouble(),
  ),
  for (final (id, inc, label, key) in [
    (
      'sheets.format.increaseFontSize',
      true,
      (SheetsLocalizations l) => l.cmdFormatIncreaseFontSize,
      '.',
    ),
    (
      'sheets.format.decreaseFontSize',
      false,
      (SheetsLocalizations l) => l.cmdFormatDecreaseFontSize,
      ',',
    ),
  ])
    SheetsCommand(
      id,
      label: label,
      icon: inc ? LucideIcons.aArrowUp : LucideIcons.aArrowDown,
      categoryName: _fmt,
      mutates: true,
      repeatable: true,
      keyScope: KeyScope.global,
      defaultBindings: [KeyBinding(key, mod: true, shift: true)],
      argsSchema: Schemas.ranges,
      run: (ctx, ed, a) {
        ed.apply(ctx, StepFontSize(rangesArg(ed, a), increase: inc));
        return ok();
      },
    ),
  _set(
    'sheets.format.textColor',
    (l) => l.cmdFormatTextColor,
    icon: LucideIcons.baseline,
    argName: 'color',
    argSchema: const JsonSchema.nullable(JsonSchema.string()),
    required: false,
    values: (a) => {FormatAttr.textColor: a.string('color')},
  ),
  _set(
    'sheets.format.fillColor',
    (l) => l.cmdFormatFillColor,
    icon: LucideIcons.paintBucket,
    argName: 'color',
    argSchema: const JsonSchema.nullable(JsonSchema.string()),
    required: false,
    values: (a) => {FormatAttr.fillColor: a.string('color')},
  ),
  _set(
    'sheets.format.hAlign',
    (l) => l.cmdFormatHAlign,
    icon: LucideIcons.alignLeft,
    argName: 'align',
    argSchema: const JsonSchema.string(
      enumValues: ['left', 'center', 'right', 'general'],
    ),
    values: (a) => {
      FormatAttr.hAlign: a.string('align') == 'general'
          ? null
          : a.string('align'),
    },
    checked: (ed, a) => a.string('align') == null
        ? null
        : (ed.activeFormat().hAlign?.name ?? 'general') == a.string('align'),
    argBindings: const [
      ArgsKeyBinding(KeyBinding('L', mod: true, shift: true), {
        'align': 'left',
      }, scope: KeyScope.global),
      ArgsKeyBinding(KeyBinding('E', mod: true, shift: true), {
        'align': 'center',
      }, scope: KeyScope.global),
      ArgsKeyBinding(KeyBinding('R', mod: true, shift: true), {
        'align': 'right',
      }, scope: KeyScope.global),
    ],
  ),
  _set(
    'sheets.format.vAlign',
    (l) => l.cmdFormatVAlign,
    icon: LucideIcons.alignVerticalJustifyEnd,
    argName: 'align',
    argSchema: const JsonSchema.string(enumValues: ['top', 'middle', 'bottom']),
    values: (a) => {FormatAttr.vAlign: a.string('align')},
    checked: (ed, a) => a.string('align') == null
        ? null
        : ed.activeFormat().vAlign.name == a.string('align'),
  ),
  _set(
    'sheets.format.wrap',
    (l) => l.cmdFormatWrap,
    icon: LucideIcons.wrapText,
    argName: 'strategy',
    argSchema: const JsonSchema.string(
      enumValues: ['overflow', 'wrap', 'clip'],
    ),
    values: (a) => {FormatAttr.wrap: a.string('strategy')},
    checked: (ed, a) => a.string('strategy') == null
        ? null
        : ed.activeFormat().wrap.name == a.string('strategy'),
  ),
  SheetsCommand(
    'sheets.format.rotation',
    label: (l) => l.cmdFormatRotation,
    icon: LucideIcons.rotateCcw,
    categoryName: _fmt,
    mutates: true,
    repeatable: true,
    argsSchema: Schemas.object({
      'angle': const JsonSchema.integer(minimum: -90, maximum: 255),
    }),
    checked: (ed, a) => a.integer('angle') == null
        ? null
        : ed.activeFormat().rotation == a.integer('angle'),
    run: (ctx, ed, a) async {
      var angle = a.integer('angle');
      if (angle == null) {
        final c = ctx.dialogContext;
        if (c == null) return const CommandResult.cancelled();
        angle = await showRotationAngleDialog(c, ed.activeFormat().rotation);
        if (angle == null) return const CommandResult.cancelled();
      }
      if (angle != 255) angle = angle.clamp(-90, 90);
      await ed.applyConfirmed(
        ctx,
        SetFormat(rangesArg(ed, a), {
          FormatAttr.rotation: angle == 0 ? null : angle,
        }),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.numberFormat',
    label: (l) => l.cmdFormatNumberFormat,
    icon: LucideIcons.hash,
    categoryName: _fmt,
    mutates: true,
    repeatable: true,
    keyScope: KeyScope.global,
    argsSchema: Schemas.object({
      'preset': JsonSchema.string(
        enumValues: [for (final m in NumberFormatPresets.menu) m.id],
      ),
      'pattern': const JsonSchema.string(),
    }),
    argBindings: [
      for (final (k, p) in const [
        ('1', 'number'),
        ('2', 'time'),
        ('3', 'date'),
        ('4', 'currency'),
        ('5', 'percent'),
        ('6', 'scientific'),
      ])
        ArgsKeyBinding(KeyBinding(k, mod: true, shift: true), {'preset': p}),
    ],
    checked: (ed, a) {
      final p = a.string('preset');
      if (p == null) return null;
      final stored = numberFormatPresets[p]?.stored;
      final cur = ed.activeFormat().numberFormat;
      return stored == cur;
    },
    run: (ctx, ed, a) {
      final preset = a.string('preset');
      final pattern = a.string('pattern');
      String? value;
      if (preset != null) {
        final item = numberFormatPresets[preset];
        if (item == null) return const CommandResult.failed('Unknown preset');
        value = item.stored == NumberFormatPresets.automatic
            ? null
            : item.stored;
      } else if (pattern != null) {
        value = pattern.isEmpty ? null : pattern;
        final err = value == null ? null : NumberFormatParser.validate(value);
        if (err != null) {
          return CommandResult.failed('invalid_number_format: ${err.message}');
        }
        if (value != null) RecentNumberFormats.note(ed.model, value);
      } else {
        return const CommandResult.failed('preset or pattern is required');
      }
      ed.apply(
        ctx,
        SetFormat(rangesArg(ed, a), {FormatAttr.numberFormat: value}),
      );
      return ok();
    },
  ),
  for (final (id, delta, label, icon) in [
    (
      'sheets.format.increaseDecimals',
      1,
      (SheetsLocalizations l) => l.cmdFormatIncreaseDecimals,
      LucideIcons.decimalsArrowRight,
    ),
    (
      'sheets.format.decreaseDecimals',
      -1,
      (SheetsLocalizations l) => l.cmdFormatDecreaseDecimals,
      LucideIcons.decimalsArrowLeft,
    ),
  ])
    SheetsCommand(
      id,
      label: label,
      icon: icon,
      categoryName: _fmt,
      mutates: true,
      repeatable: true,
      argsSchema: Schemas.ranges,
      run: (ctx, ed, a) {
        ed.apply(ctx, AdjustDecimals(rangesArg(ed, a), delta));
        return ok();
      },
    ),
  SheetsCommand(
    'sheets.format.openCustomNumberFormat',
    label: (l) => l.cmdFormatOpenCustomNumberFormat,
    categoryName: _fmt,
    mutates: true,
    undoLabelOf: (l, a) => l.cmdFormatNumberFormat,
    run: (ctx, ed, a) async {
      final c = ctx.dialogContext;
      if (c == null) return const CommandResult.cancelled();
      final current = ed.activeFormat().numberFormat;
      final p = await showCustomNumberFormatPatternDialog(
        c,
        initial: current.startsWith('preset:') ? '' : current,
        locale: ed.locale,
        activeValue: ed.activeDisplay()?.value,
        recent: RecentNumberFormats.of(ed.model),
      );
      if (p == null) return const CommandResult.cancelled();
      await ed.applyConfirmed(
        ctx,
        SetFormat(ed.selectedRanges, {
          FormatAttr.numberFormat: p.isEmpty ? null : p,
        }),
      );
      RecentNumberFormats.note(ed.model, p);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.borders',
    label: (l) => l.cmdFormatBorders,
    icon: LucideIcons.grid2x2,
    categoryName: _fmt,
    mutates: true,
    repeatable: true,
    argsSchema: Schemas.object(
      {
        'preset': JsonSchema.string(
          enumValues: [for (final p in BorderPreset.values) p.name],
        ),
        'style': JsonSchema.string(
          enumValues: [for (final s in BorderStyle.values) s.name],
        ),
        'color': const JsonSchema.string(),
      },
      required: ['preset'],
    ),
    argBindings: [
      for (final (k, p) in const [
        ('7', 'outer'),
        ('1', 'top'),
        ('2', 'right'),
        ('3', 'bottom'),
        ('4', 'left'),
        ('6', 'clear'),
      ])
        ArgsKeyBinding(KeyBinding(k, alt: true, shift: true), {
          'preset': p,
        }, scope: KeyScope.global),
    ],
    run: (ctx, ed, a) {
      final preset = BorderPreset.values
          .where((p) => p.name == a.string('preset'))
          .firstOrNull;
      if (preset == null) return const CommandResult.failed('Unknown preset');
      final style =
          BorderStyle.tryParse(a.string('style') ?? 'thin') ?? BorderStyle.thin;
      ed.apply(
        ctx,
        SetBorders(
          rangesArg(ed, a),
          preset,
          style: style,
          color: a.string('color') ?? 'auto',
        ),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.merge',
    label: (l) => l.cmdFormatMerge,
    icon: LucideIcons.combine,
    categoryName: _fmt,
    mutates: true,
    argsSchema: Schemas.object({
      'mode': const JsonSchema.string(
        enumValues: ['all', 'horizontal', 'vertical'],
      ),
      'force': const JsonSchema.boolean(),
    }),
    enabled: (ed, a) =>
        ed.selection.resolved.ranges.any((r) => r.rect.cellCount > 1),
    run: (ctx, ed, a) async {
      final mode = switch (a.string('mode')) {
        'horizontal' => MergeMode.horizontal,
        'vertical' => MergeMode.vertical,
        _ => MergeMode.all,
      };
      final ranges = rangesArg(ed, a);
      try {
        ed.apply(
          ctx,
          MergeCells(ranges, mode: mode, force: a.boolean('force') ?? false),
        );
      } on PlanException catch (e) {
        if (e.code != 'merge_data_loss') rethrow;
        final c = ctx.dialogContext;
        if (c == null || !c.mounted) return CommandResult.failed(e.message);
        if (!await confirmMergeDialog(c, mode)) {
          return const CommandResult.cancelled();
        }
        await ed.applyConfirmed(
          ctx,
          MergeCells(ranges, mode: mode, force: true),
        );
      }
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.unmerge',
    label: (l) => l.cmdFormatUnmerge,
    icon: LucideIcons.ungroup,
    categoryName: _fmt,
    mutates: true,
    argsSchema: Schemas.ranges,
    enabled: (ed, a) => ed.selectedRanges.any(
      (r) => ed.activeSheet!.mergesIntersecting(r.rect).isNotEmpty,
    ),
    run: (ctx, ed, a) {
      ed.apply(ctx, UnmergeCells(rangesArg(ed, a)));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.clear',
    label: (l) => l.cmdFormatClear,
    icon: LucideIcons.removeFormatting,
    categoryName: _fmt,
    mutates: true,
    repeatable: true,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding(r'\', mod: true)],
    argsSchema: Schemas.ranges,
    run: (ctx, ed, a) {
      ed.apply(ctx, ClearFormatting(rangesArg(ed, a)));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.paintFormat',
    label: (l) => l.cmdFormatPaintFormat,
    icon: LucideIcons.paintbrush,
    categoryName: _fmt,
    argsSchema: const JsonSchema.object(
      properties: {'sticky': JsonSchema.boolean()},
    ),
    checked: (ed, a) => ed.paintFormat.value != null,
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      if (ed.paintFormat.value != null) {
        ed.paintFormat.value = null;
        return ok();
      }
      final r = ed.selection.resolved;
      if (r.ranges.length != 1) {
        return CommandResult.failed(ed.l10n.toastMultipleSelections);
      }
      ed.paintFormat.value = PaintFormatState(
        ed.activeSheetId,
        r.activeRange.rect,
        sticky: a.boolean('sticky') ?? false,
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.format.applyPaintFormat',
    label: (l) => l.cmdFormatApplyPaintFormat,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'source': JsonSchema.string(),
        'target': JsonSchema.string(),
      },
      required: ['source', 'target'],
    ),
    run: (ctx, ed, a) {
      final src = rectArg(ed, a, 'source');
      final target = rangeArg(ed, a, 'target');
      final sheetId = ed.paintFormat.value?.sheetId ?? ed.activeSheetId;
      ed.apply(
        ctx,
        PasteClipboard(
          target,
          ed.clipboard.sourceOf(src, sheetId: sheetId),
          mode: PasteMode.format,
        ),
      );
      if (!(ed.paintFormat.value?.sticky ?? false)) ed.paintFormat.value = null;
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.edit.repeatLast',
    label: (l) => l.cmdEditRepeatLast,
    categoryName: _fmt,
    defaultBindings: const [KeyBinding('F4')],
    enabled: (ed, a) => ed.lastRepeatable != null && ed.canEdit,
    run: (ctx, ed, a) async {
      final last = ed.lastRepeatable;
      if (last == null) return const CommandResult.cancelled();
      final args = Map<String, Object?>.of(last.$2)..remove('ranges');
      final ok = await ed.invokeCommand(last.$1, args, ctx.source);
      return ok ? const CommandResult.ok() : const CommandResult.cancelled();
    },
  ),
];

/// A unit range covering one cell, for tests.
GridRect cellRect(int r, int c) => GridRect.cell(r, c);
