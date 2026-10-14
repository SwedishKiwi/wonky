import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;
import 'package:wonky_sheets_core/model.dart';

import '../features/protection/protection_controller.dart';
import '../features/protection/protection_panel_state.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _data(SheetsLocalizations l) => l.categoryData;

const _targetArgs = {
  'range': JsonSchema.string(
    description: 'A1 range to protect (may name a sheet: Sheet1!F2:F40).',
  ),
  'sheetId': JsonSchema.string(description: 'Protect this whole sheet.'),
  'sheet': JsonSchema.string(description: 'Protect the sheet with this name.'),
  'wholeSheet': JsonSchema.boolean(
    description: 'Protect the whole sheet of the range/active sheet.',
  ),
  'exceptRanges': JsonSchema.array(
    JsonSchema.string(),
    description: 'Sheet protection: A1 ranges that stay editable.',
  ),
  'description': JsonSchema.string(),
  'warningOnly': JsonSchema.boolean(
    description: 'Only warn before edits instead of restricting editors.',
  ),
  'editors': JsonSchema.array(
    JsonSchema.string(),
    description:
        'User UUIDs who may edit besides the owner and the protection '
        'creator.',
  ),
};

/// Protected sheets and ranges (07 §10.4, 03 §16): panel, add/update/
/// delete (one undo step each) and the stripes view option.
List<Command<CommandArgs>> protectionCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.protect.openPanel',
    label: (l) => l.cmdProtectOpenPanel,
    icon: LucideIcons.lock,
    categoryName: _data,
    argsSchema: const JsonSchema.object(
      properties: {
        'range': JsonSchema.string(description: 'Prefill a new range.'),
        'sheetId': JsonSchema.string(description: 'Prefill a sheet.'),
        'mode': JsonSchema.string(enumValues: ['range', 'sheet']),
        'id': JsonSchema.string(description: 'Edit this protection.'),
        'list': JsonSchema.boolean(description: 'Show the list.'),
      },
    ),
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      final panel = ProtectionPanelState.of(ed);
      final protection = ProtectionController.of(ed);
      final id = a.string('id');
      final sheetId = a.string('sheetId');
      final range = a.string('range');
      final sheetMode = a.string('mode') == 'sheet';
      if (id != null) {
        final e = protection.byId(id);
        if (e == null) return const CommandResult.failed('Unknown protection');
        panel.edit(e);
      } else if (a.boolean('list') ?? false) {
        panel.close();
      } else if (sheetId != null || sheetMode) {
        panel.startNew(sheetId: sheetId ?? ed.activeSheetId, sheet: true);
      } else if (range != null ||
          ctx.source == InvocationSource.contextMenu ||
          protection.entries.isEmpty) {
        panel.startNew(rangeText: range ?? _selectionA1(ed));
      } else {
        panel.close();
      }
      s.panels.open(protectionPanelId);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.protect.add',
    label: (l) => l.cmdProtectAdd,
    icon: LucideIcons.lock,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(properties: _targetArgs),
    run: (ctx, ed, a) {
      final t = _target(ed, a);
      final plan = ed.apply(
        ctx,
        AddProtection(
          t.sheetId,
          range: t.range,
          exceptRanges: t.except,
          description: _blankToNull(a.string('description')),
          warningOnly: a.boolean('warningOnly') ?? false,
          editors: _editors(a),
        ),
      );
      return ok({'id': plan.result['protectionId']});
    },
  ),
  SheetsCommand(
    'sheets.protect.update',
    label: (l) => l.cmdProtectUpdate,
    icon: LucideIcons.lock,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'id': JsonSchema.string(), ..._targetArgs},
      required: ['id'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('id');
      final protection = ProtectionController.of(ed);
      final e = protection.byId(id);
      if (e == null) return const CommandResult.failed('Unknown protection');
      if (!protection.canManage(e.record)) {
        return CommandResult.failed(ed.l10n.reasonCantManageProtection);
      }
      final hasTarget =
          a.string('range') != null ||
          a.string('sheetId') != null ||
          a.string('sheet') != null ||
          a.boolean('wholeSheet') == true;
      final t = hasTarget ? _target(ed, a, fallbackSheet: e.sheet.id) : null;
      if (t != null && t.sheetId != e.sheet.id) {
        return const CommandResult.failed(
          'A protection stays on its sheet; remove it and add a new one.',
        );
      }
      final hasExcept = a.values.containsKey('exceptRanges');
      ed.apply(
        ctx,
        UpdateProtection(
          id,
          range: t?.range,
          wholeSheet: t != null && t.range == null,
          exceptRanges: hasExcept
              ? _exceptRects(ed, a, e.sheet.id)
              : (t != null && t.range != null ? const [] : null),
          description: a.values.containsKey('description')
              ? (a.string('description') ?? '')
              : null,
          warningOnly: a.boolean('warningOnly'),
          editors: a.values.containsKey('editors') ? _editors(a) : null,
        ),
      );
      return ok({'id': id});
    },
  ),
  SheetsCommand(
    'sheets.protect.delete',
    label: (l) => l.cmdProtectDelete,
    icon: LucideIcons.lockOpen,
    categoryName: _data,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'id': JsonSchema.string()},
      required: ['id'],
    ),
    run: (ctx, ed, a) {
      final id = a.requireString('id');
      final protection = ProtectionController.of(ed);
      final e = protection.byId(id);
      if (e == null) return const CommandResult.failed('Unknown protection');
      if (!protection.canManage(e.record)) {
        return CommandResult.failed(ed.l10n.reasonCantManageProtection);
      }
      ed.apply(ctx, DeleteProtection(id));
      final panel = ProtectionPanelState.of(ed);
      if (panel.draft?.id == id) panel.close();
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.view.toggleProtectedRanges',
    label: (l) => l.cmdViewToggleProtectedRanges,
    categoryName: (l) => l.categoryView,
    checked: (ed, a) => ProtectionController.of(ed).showStripes,
    run: (ctx, ed, a) {
      final p = ProtectionController.of(ed);
      p.showStripes = !p.showStripes;
      return ok({'shown': p.showStripes});
    },
  ),
];

String _selectionA1(SheetEditorController ed) {
  final rect = ed.activeRange.rect;
  final s = ed.activeSheet;
  final grid = s?.gridRect;
  final clipped = grid == null ? rect : (rect.intersection(grid) ?? rect);
  return clipped.a1;
}

String? _blankToNull(String? s) =>
    s == null || s.trim().isEmpty ? null : s.trim();

List<String> _editors(JsonArgs a) => [
  for (final e in a.strings('editors'))
    if (e.trim().isNotEmpty) e.trim().toLowerCase(),
];

({String sheetId, GridRect? range, List<GridRect> except}) _target(
  SheetEditorController ed,
  JsonArgs a, {
  String? fallbackSheet,
}) {
  final byId = a.string('sheetId');
  final byName = a.string('sheet');
  final rangeText = a.string('range');
  String sheetId;
  GridRect? range;
  if (byId != null || byName != null) {
    final sh = byId != null
        ? ed.model.sheet(byId)
        : ed.model.sheetByName(byName!);
    if (sh == null) throw const InvalidRangeException('Unknown sheet');
    sheetId = sh.id;
  } else if (rangeText != null && rangeText.trim().isNotEmpty) {
    final r = ed.model.parseA1(
      rangeText.trim(),
      contextSheetId: fallbackSheet ?? ed.activeSheetId,
    );
    sheetId = r.sheetId;
    range = r.rect;
    if (a.boolean('wholeSheet') ?? false) range = null;
  } else if (a.boolean('wholeSheet') ?? false) {
    sheetId = fallbackSheet ?? ed.activeSheetId;
  } else {
    final r = ed.activeRange;
    sheetId = r.sheetId;
    range = ed.model.sheet(sheetId)?.gridRect == null
        ? r.rect
        : (r.rect.intersection(ed.model.sheet(sheetId)!.gridRect!) ?? r.rect);
  }
  final sheetWide = range == null;
  return (
    sheetId: sheetId,
    range: range,
    except: sheetWide ? _exceptRects(ed, a, sheetId) : const [],
  );
}

List<GridRect> _exceptRects(
  SheetEditorController ed,
  JsonArgs a,
  String sheetId,
) => [
  for (final t in a.strings('exceptRanges'))
    for (final part in t.split(','))
      if (part.trim().isNotEmpty)
        ed.model.parseA1(part.trim(), contextSheetId: sheetId).rect,
];
