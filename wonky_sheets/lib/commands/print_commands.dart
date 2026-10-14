import 'package:flutter/foundation.dart' show Uint8List;
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/formula.dart' show ColumnLetters;
import 'package:wonky_sheets_core/model.dart';

import '../features/export/sheets_downloads.dart';
import '../features/import_export/progress_dialog.dart';
import '../features/import_export/sheets_io.dart';
import '../features/print/pdf_print.dart';
import '../features/print/print_controller.dart';
import '../features/print/print_fonts.dart';
import '../features/sheet_editor/sheet_editor_controller.dart';
import 'sheets_command.dart';

String _file(SheetsLocalizations l) => l.categoryFile;

/// Sheets a print settings command targets: `sheetIds`, `sheetId`, or the
/// active sheet.
List<String> _sheetIds(SheetEditorController ed, JsonArgs a) {
  final ids = a.strings('sheetIds');
  if (ids.isNotEmpty) return ids;
  final one = a.string('sheetId');
  return [one ?? ed.activeSheetId];
}

/// Row/column ids of break arguments: ids, or 1-based row numbers / column
/// letters (MCP).
List<String> _breakIds(
  AxisIndex axis,
  List<Object?> raw, {
  required bool rows,
}) {
  final out = <String>[];
  for (final v in raw) {
    int? index;
    if (v is int) {
      index = rows ? v - 1 : v;
    } else if (v is String) {
      if (axis.contains(v)) {
        out.add(v);
        continue;
      }
      final t = v.trim();
      index = rows
          ? (int.tryParse(t) ?? 0) - 1
          : (RegExp(r'^[A-Za-z]{1,3}$').hasMatch(t)
                ? ColumnLetters.toIndex(t.toUpperCase())
                : null);
    }
    if (index == null || index <= 0 || index >= axis.length) continue;
    out.add(axis.idAt(index));
  }
  return out;
}

List<Object?> _list(JsonArgs a, String key) {
  final v = a.values[key];
  return v is List ? v : const [];
}

/// A PDF of the open print route, or of the current sheet with its stored
/// settings when the route isn't open (MCP).
Future<(Uint8List, String)?> _pdf(
  CommandContext ctx,
  SheetEditorController ed, {
  bool darkTheme = false,
}) async {
  final l = ed.l10n;
  final c = ctx.dialogContext;
  var pc = PrintController.current;
  final temp = pc == null || !identical(pc.ed, ed);
  if (temp) {
    pc = PrintController(ed, fonts: await SheetsPdfFonts.load());
  }
  final controller = pc;
  try {
    final bytes = c == null || !c.mounted
        ? await controller.buildPdf(darkTheme: darkTheme)
        : await runWithProgress(
            c,
            title: l.printPhaseRendering(controller.pages.length),
            work: (p) => controller.buildPdf(progress: p, darkTheme: darkTheme),
          );
    if (bytes == null) return null;
    return (bytes, controller.pdfFileName);
  } finally {
    if (temp) controller.dispose();
  }
}

/// Print route, print settings and PDF commands (11 §9).
List<Command<CommandArgs>> printCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.print.open',
    label: (l) => l.cmdPrintOpen,
    icon: LucideIcons.printer,
    categoryName: _file,
    keyScope: KeyScope.global,
    defaultBindings: const [KeyBinding('P', mod: true)],
    argsSchema: const JsonSchema.object(
      properties: {
        'scope': JsonSchema.string(
          enumValues: ['currentSheet', 'workbook', 'selection'],
        ),
        'export': JsonSchema.boolean(),
      },
    ),
    enabled: (ed, a) => canDownload(ed),
    run: (ctx, ed, a) {
      final q = <String, String>{
        'scope': ?a.string('scope'),
        if (a.boolean('export') == true) 'export': '1',
      };
      final path = '/s/${ed.session.itemUuid.uuid}/print';
      s.router.go(
        q.isEmpty ? path : Uri(path: path, queryParameters: q).toString(),
      );
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.print.updateSettings',
    label: (l) => l.cmdPrintUpdateSettings,
    icon: LucideIcons.settings2,
    categoryName: _file,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'sheetId': JsonSchema.string(),
        'sheetIds': JsonSchema.array(JsonSchema.string()),
        'patch': JsonSchema.object(
          description: 'JSON merge patch of PrintSettings (11 §7.2).',
          additionalProperties: true,
        ),
        'applyToAll': JsonSchema.boolean(),
      },
      required: ['patch'],
    ),
    run: (ctx, ed, a) {
      final raw = a.values['patch'];
      if (raw is! Map) return const CommandResult.failed('patch is required');
      final ids = a.boolean('applyToAll') == true
          ? [for (final sh in ed.model.visibleSheets) sh.id]
          : _sheetIds(ed, a);
      ed.apply(ctx, SetPrintSettings(ids, raw.cast<String, Object?>()));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.print.resetSettings',
    label: (l) => l.cmdPrintResetSettings,
    icon: LucideIcons.rotateCcw,
    categoryName: _file,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'sheetId': JsonSchema.string(),
        'sheetIds': JsonSchema.array(JsonSchema.string()),
      },
    ),
    run: (ctx, ed, a) {
      ed.apply(ctx, SetPrintSettings(_sheetIds(ed, a), null));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.print.setPageBreaks',
    label: (l) => l.cmdPrintSetPageBreaks,
    icon: LucideIcons.separatorHorizontal,
    categoryName: _file,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'sheetId': JsonSchema.string(),
        'rows': JsonSchema.array(
          JsonSchema.any(),
          description: 'Break before these rows (ids or 1-based numbers).',
        ),
        'cols': JsonSchema.array(
          JsonSchema.any(),
          description: 'Break before these columns (ids or letters).',
        ),
      },
    ),
    run: (ctx, ed, a) {
      final id = a.string('sheetId') ?? ed.activeSheetId;
      final sheet = ed.model.sheet(id);
      if (sheet == null) return const CommandResult.failed('Unknown sheet');
      final rows = _breakIds(sheet.rows, _list(a, 'rows'), rows: true);
      final cols = _breakIds(sheet.columns, _list(a, 'cols'), rows: false);
      ed.apply(
        ctx,
        SetPrintSettings(
          [id],
          {
            'pageBreaks': {'rows': rows, 'cols': cols},
          },
        ),
      );
      return ok({'rows': rows, 'cols': cols});
    },
  ),
  SheetsCommand(
    'sheets.print.enterBreakMode',
    label: (l) => l.cmdPrintEnterBreakMode,
    icon: LucideIcons.separatorHorizontal,
    categoryName: _file,
    showInPalette: false,
    enabled: (ed, a) => PrintController.current != null && ed.canEdit,
    run: (ctx, ed, a) {
      PrintController.current?.breakMode = true;
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.print.exitBreakMode',
    label: (l) => l.cmdPrintExitBreakMode,
    categoryName: _file,
    showInPalette: false,
    enabled: (ed, a) => PrintController.current?.breakMode ?? false,
    run: (ctx, ed, a) {
      PrintController.current?.breakMode = false;
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.print.print',
    label: (l) => l.cmdPrintPrint,
    icon: LucideIcons.printer,
    categoryName: _file,
    enabled: (ed, a) => canDownload(ed),
    run: (ctx, ed, a) async {
      final l = ed.l10n;
      final r = await _pdf(ctx, ed);
      if (r == null) return const CommandResult.cancelled();
      final (bytes, name) = r;
      final printed = await printPdf(bytes, title: name);
      if (!printed) {
        s.toasts.show(
          l.printUnavailableTitle,
          description: l.printUnavailableBody,
          actionLabel: l.printExportPdf,
          onAction: () => saveBytes(
            bytes,
            fileName: name,
            mimeType: 'application/pdf',
            dialogTitle: l.exportSaveDialogTitle(name),
          ),
        );
      }
      return ok({'printed': printed, 'fileName': name});
    },
  ),
  SheetsCommand(
    'sheets.print.exportPdf',
    label: (l) => l.cmdPrintExportPdf,
    icon: LucideIcons.fileDown,
    categoryName: _file,
    argsSchema: const JsonSchema.object(
      properties: {
        'darkTheme': JsonSchema.boolean(
          description: 'Dark pages (default: the print route option).',
        ),
      },
    ),
    enabled: (ed, a) => canDownload(ed),
    run: (ctx, ed, a) async {
      final l = ed.l10n;
      final r = await _pdf(
        ctx,
        ed,
        darkTheme:
            a.boolean('darkTheme') ??
            PrintController.current?.darkTheme ??
            false,
      );
      if (r == null) return const CommandResult.cancelled();
      final (bytes, name) = r;
      final saved = await saveBytes(
        bytes,
        fileName: name,
        mimeType: 'application/pdf',
        dialogTitle: l.exportSaveDialogTitle(name),
      );
      return saved
          ? ok({'fileName': name, 'sizeBytes': bytes.length})
          : const CommandResult.cancelled();
    },
  ),
];
