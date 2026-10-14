import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/in_cell/in_cell_controller.dart';
import '../features/in_cell/smart_chips.dart';
import 'sheets_command.dart';

String _cat(SheetsLocalizations l) => l.categoryInsert;

/// Smart chips (03 §14.3, P2): `sheets.insert.smartChip` opens the chip
/// menu at the active cell (also opened by typing `@` into an empty cell),
/// or inserts a chip directly (`kind`, for agents and the menu).
List<Command<CommandArgs>> chipCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.insert.smartChip',
    label: (l) => l.cmdInsertSmartChip,
    icon: LucideIcons.atSign,
    categoryName: _cat,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'kind': JsonSchema.string(
          enumValues: ['person', 'file', 'date', 'dropdown'],
          description: 'Omit to open the chip menu at the active cell.',
        ),
        'email': JsonSchema.string(description: 'Person chip: e-mail.'),
        'name': JsonSchema.string(description: 'Person chip: display name.'),
        'userId': JsonSchema.string(description: 'Person chip: user UUID.'),
        'uuid': JsonSchema.string(
          description:
              'File chip: drive item UUID (document, spreadsheet, '
              'folder).',
        ),
        'itemKind': JsonSchema.string(
          enumValues: ['document', 'spreadsheet', 'folder'],
          description: 'File chip: item kind (default: looked up).',
        ),
        'date': JsonSchema.string(
          description: 'Date chip: ISO date (default: opens the picker).',
        ),
        'cell': JsonSchema.string(description: 'A1 cell (default: active).'),
      },
    ),
    run: (ctx, ed, a) async {
      final cell = a.string('cell');
      final target = cell == null
          ? ed.activeRange
          : ed.model.parseA1(cell, contextSheetId: ed.activeSheetId);
      final sid = target.sheetId;
      final r = cell == null
          ? ed.selection.resolved.activeRow
          : target.rect.top;
      final c = cell == null
          ? ed.selection.resolved.activeCol
          : target.rect.left;
      final kind = a.string('kind');
      final inCell = InCellController.of(ed);
      switch (kind) {
        case null:
          if (ctx.source.isAgent) {
            return const CommandResult.failed('kind is required');
          }
          inCell.openSmartChipMenu(sid, r, c);
          return ok();
        case 'person':
          final email = a.string('email')?.trim() ?? '';
          if (!email.contains('@')) {
            return const CommandResult.failed('email is required');
          }
          final name = a.string('name')?.trim();
          final chip = PersonChip(
            email: email,
            name: name == null || name.isEmpty ? email : name,
            userId: a.string('userId'),
          );
          await ed.applyConfirmed(
            ctx,
            SetCellInputs(
              sheetId: sid,
              row: r,
              col: c,
              inputs: [
                [CellInput.content(chip.content)],
              ],
              label: ed.l10n.cmdInsertSmartChip,
            ),
          );
          return ok({'chip': 'person', 'email': email});
        case 'file':
          final uuid = UuidValue.withValidation(a.string('uuid') ?? '');
          var name = a.string('name')?.trim();
          var itemKind = a.string('itemKind');
          if (name == null || name.isEmpty || itemKind == null) {
            final item = await ed.services.drive.get(uuid);
            name = item.name;
            itemKind = item.kind.name;
          }
          final chip = FileChip(
            uuid: uuid.uuid,
            name: name,
            itemKind: itemKind,
          );
          await ed.applyConfirmed(
            ctx,
            SetCellInputs(
              sheetId: sid,
              row: r,
              col: c,
              inputs: [
                [CellInput.content(chip.content)],
              ],
              label: ed.l10n.cmdInsertSmartChip,
            ),
          );
          return ok({'chip': 'file', 'uuid': uuid.uuid});
        case 'date':
          final iso = a.string('date');
          if (iso == null) {
            if (ctx.source.isAgent) {
              return const CommandResult.failed('date is required');
            }
            inCell.openDatePicker(sid, r, c);
            return ok();
          }
          final d = DateTime.tryParse(iso);
          if (d == null) return const CommandResult.failed('Invalid date');
          await ed.applyConfirmed(
            ctx,
            SetCellInputs(
              sheetId: sid,
              row: r,
              col: c,
              inputs: [
                [CellInput.user(isoDate(d))],
              ],
              parseLocale: 'en_US',
              label: ed.l10n.cmdInsertSmartChip,
            ),
          );
          return ok({'chip': 'date'});
        case 'dropdown':
          return ed.services.dispatcher.invoke(
            'sheets.insert.dropdown',
            source: ctx.source,
            context: ctx.buildContext,
          );
        default:
          return CommandResult.failed('Unknown chip kind "$kind"');
      }
    },
  ),
  SheetsCommand(
    'sheets.chip.openFile',
    label: (l) => l.cmdChipOpenFile,
    icon: LucideIcons.externalLink,
    categoryName: _cat,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {'uuid': JsonSchema.string()},
      required: ['uuid'],
    ),
    // A file chip's item opens in this window (suite 03 §1: single window).
    run: (ctx, ed, a) async {
      final uuid = UuidValue.withValidation(a.requireString('uuid'));
      final item = await ed.services.drive.get(uuid);
      await ed.services.openItem(item);
      return ok({'kind': item.kind.name});
    },
  ),
];
