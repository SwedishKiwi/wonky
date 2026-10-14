import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/formatting/formatting_features.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _fmt(SheetsLocalizations l) => l.categoryFormatting;

const _styleSchema = JsonSchema.anyOf([
  JsonSchema.object(additionalProperties: true),
  JsonSchema.string(),
], description: 'Banding styleJson (06 §14.1).');

/// The style argument as `styleJson`.
String _styleArg(JsonArgs a) {
  final v = a.values['style'];
  final Object? m = v is String ? jsonDecode(v) : v;
  if (m is! Map) {
    throw const PlanException('invalid_argument', 'style must be an object');
  }
  return BandingStyle.parse(jsonEncode(m)).toJson();
}

/// The sheet holding banding [id], or null.
SheetModel? bandingSheet(SheetEditorController ed, String id) {
  for (final s in ed.model.sheets) {
    if (s.bandings.containsKey(id)) return s;
  }
  return null;
}

GridRect _bounded(SheetEditorController ed, ResolvedRange r) {
  final sheet = ed.model.sheet(r.sheetId);
  if (sheet == null) return r.rect;
  final grid = GridRect(0, 0, sheet.rows.length - 1, sheet.columns.length - 1);
  return r.rect.intersection(grid) ?? r.rect;
}

/// Alternating colors commands (06 §14.2, §16).
List<Command<CommandArgs>> bandingCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.banding.openPanel',
    label: (l) => l.cmdBandingOpenPanel,
    icon: LucideIcons.rows3,
    categoryName: _fmt,
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      FormattingFeatures.of(ed);
      s.panels.open(FormattingPanels.alternatingColors);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.banding.add',
    label: (l) => l.cmdBandingAdd,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {'range': const JsonSchema.string(), 'style': _styleSchema},
      required: ['style'],
    ),
    run: (ctx, ed, a) {
      final range = rangeArg(ed, a);
      final plan = ed.apply(
        ctx,
        AddBanding(range.sheetId, _bounded(ed, range), _styleArg(a)),
      );
      return ok({'bandingId': plan.result['bandingId']});
    },
  ),
  SheetsCommand(
    'sheets.banding.update',
    label: (l) => l.cmdBandingUpdate,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'bandingId': const JsonSchema.string(),
        'range': const JsonSchema.string(),
        'style': _styleSchema,
      },
      required: ['bandingId'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('bandingId');
      final sheet = bandingSheet(ed, id);
      if (sheet == null) return const CommandResult.failed('Unknown banding');
      GridRect? rect;
      if (a.string('range') != null) {
        final r = ed.model.parseA1(
          a.string('range')!.trim(),
          contextSheetId: sheet.id,
        );
        if (r.sheetId != sheet.id) {
          return const CommandResult.failed('The range is on another sheet');
        }
        rect = _bounded(ed, r);
      }
      ed.apply(
        ctx,
        UpdateBanding(
          id,
          range: rect,
          styleJson: a.values['style'] == null ? null : _styleArg(a),
        ),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.banding.remove',
    label: (l) => l.cmdBandingRemove,
    icon: LucideIcons.trash2,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'bandingId': JsonSchema.string()},
      required: ['bandingId'],
    ),
    run: (ctx, ed, a) {
      ed.apply(ctx, RemoveBanding(a.requireString('bandingId')));
      return ok();
    },
  ),
];
