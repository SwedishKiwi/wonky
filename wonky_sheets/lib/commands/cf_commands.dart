import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/conditional_format/cf_rule_text.dart';
import '../features/formatting/formatting_features.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _fmt(SheetsLocalizations l) => l.categoryFormatting;

const _ruleSchema = JsonSchema.anyOf([
  JsonSchema.object(additionalProperties: true),
  JsonSchema.string(),
], description: 'ruleJson (06 §15.1) with A1 formulas.');

/// The sheet holding CF rule [ruleId], or null.
SheetModel? cfRuleSheet(SheetEditorController ed, String ruleId) {
  for (final s in ed.model.sheets) {
    if (s.cfRules.containsKey(ruleId)) return s;
  }
  return null;
}

/// The rule argument as a JSON map (object or JSON string).
Map<String, Object?> _ruleArg(JsonArgs a) {
  final v = a.values['rule'];
  if (v is Map) return v.cast<String, Object?>();
  if (v is String) {
    final m = jsonDecode(v);
    if (m is Map) return m.cast<String, Object?>();
  }
  throw const PlanException('invalid_argument', 'rule must be a JSON object');
}

/// Validates a rule (A1 form) before writing; returns an error message.
String? _validate(Map<String, Object?> json) {
  final rule = CfRule.parse(json);
  switch (rule) {
    case CfUnknownRule():
      return 'Unsupported rule';
    case CfBooleanRule(:final condition):
      return condition.validate();
    default:
      return null;
  }
}

/// Conditional formatting commands (06 §15, §16).
List<Command<CommandArgs>> cfCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.cf.openPanel',
    label: (l) => l.cmdCfOpenPanel,
    icon: LucideIcons.paintRoller,
    categoryName: _fmt,
    argsSchema: const JsonSchema.object(
      properties: {'range': JsonSchema.string()},
    ),
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      final range = a.string('range');
      if (range != null && !ed.goTo(range)) {
        return CommandResult.failed(ed.l10n.rangeInputInvalid);
      }
      FormattingFeatures.of(ed);
      s.panels.open(FormattingPanels.conditionalFormatting);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.cf.addRule',
    label: (l) => l.cmdCfAddRule,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: Schemas.object(
      {'rule': _ruleSchema, 'beforeRuleId': const JsonSchema.string()},
      required: ['rule'],
    ),
    run: (ctx, ed, a) {
      final ranges = rangesArg(ed, a);
      if (ranges.isEmpty) return const CommandResult.failed('No range');
      final sheetId = ranges.first.sheetId;
      final rule = _ruleArg(a);
      final err = _validate(rule);
      if (err != null) return CommandResult.failed(err);
      final rects = [
        for (final r in ranges)
          if (r.sheetId == sheetId) _bounded(ed, r),
      ];
      final anchor = rects.first;
      final stored = cfRuleToStored(
        rule,
        hooks: ed.hooks,
        sheetId: sheetId,
        anchorRow: anchor.top,
        anchorCol: anchor.left,
        locale: ed.locale,
      );
      final plan = ed.apply(
        ctx,
        AddCfRule(
          sheetId,
          rects,
          stored,
          beforeRuleId: a.string('beforeRuleId'),
        ),
      );
      return ok({'ruleId': plan.result['ruleId']});
    },
  ),
  SheetsCommand(
    'sheets.cf.updateRule',
    label: (l) => l.cmdCfUpdateRule,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'ruleId': const JsonSchema.string(),
        'ranges': const JsonSchema.array(JsonSchema.string()),
        'rule': _ruleSchema,
      },
      required: ['ruleId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('ruleId');
      final sheet = cfRuleSheet(ed, id);
      if (sheet == null) return const CommandResult.failed('Unknown rule');
      List<GridRect>? rects;
      if (a.strings('ranges').isNotEmpty) {
        rects = [
          for (final r in rangesArg(ed, a))
            if (r.sheetId == sheet.id) _bounded(ed, r),
        ];
        if (rects.isEmpty) return const CommandResult.failed('No range');
      }
      String? stored;
      if (a.values['rule'] != null) {
        final rule = _ruleArg(a);
        final err = _validate(rule);
        if (err != null) return CommandResult.failed(err);
        final anchor =
            (rects ?? sheet.ruleRects(RuleKind.conditionalFormat, id))
                .firstOrNull;
        stored = cfRuleToStored(
          rule,
          hooks: ed.hooks,
          sheetId: sheet.id,
          anchorRow: anchor?.top ?? 0,
          anchorCol: anchor?.left ?? 0,
          locale: ed.locale,
        );
      }
      ed.apply(ctx, UpdateCfRule(id, ranges: rects, ruleJson: stored));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.cf.deleteRule',
    label: (l) => l.cmdCfDeleteRule,
    icon: LucideIcons.trash2,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'ruleId': JsonSchema.string()},
      required: ['ruleId'],
    ),
    run: (ctx, ed, a) {
      ed.apply(ctx, DeleteCfRule(a.requireString('ruleId')));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.cf.reorder',
    label: (l) => l.cmdCfReorder,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'ruleId': JsonSchema.string(),
        'beforeRuleId': JsonSchema.string(),
      },
      required: ['ruleId'],
    ),
    run: (ctx, ed, a) {
      ed.apply(
        ctx,
        ReorderCfRule(a.requireString('ruleId'), a.string('beforeRuleId')),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.cf.setEnabled',
    label: (l) => l.cmdCfSetEnabled,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'ruleId': JsonSchema.string(),
        'enabled': JsonSchema.boolean(),
      },
      required: ['ruleId', 'enabled'],
    ),
    undoLabelOf: (l, a) =>
        a.boolean('enabled') ?? true ? l.cfUndoEnable : l.cfUndoDisable,
    run: (ctx, ed, a) {
      ed.apply(
        ctx,
        SetCfEnabled(
          a.requireString('ruleId'),
          enabled: a.boolean('enabled') ?? true,
        ),
      );
      return ok();
    },
  ),
];

/// Whole rows/columns are bounded to the sheet's grid.
GridRect _bounded(SheetEditorController ed, ResolvedRange r) {
  final sheet = ed.model.sheet(r.sheetId);
  if (sheet == null) return r.rect;
  final grid = GridRect(0, 0, sheet.rows.length - 1, sheet.columns.length - 1);
  return r.rect.intersection(grid) ?? r.rect;
}
