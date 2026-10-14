import 'dart:convert';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import '../features/formatting/formatting_features.dart';
import '../features/theme/theme_import.dart';
import 'sheets_command.dart';

String _fmt(SheetsLocalizations l) => l.categoryFormatting;

/// Spreadsheet theme commands (06 §13, §16).
List<Command<CommandArgs>> themeCommands(ShellServices s) => [
  SheetsCommand(
    'sheets.theme.openPanel',
    label: (l) => l.cmdThemeOpenPanel,
    icon: LucideIcons.palette,
    categoryName: _fmt,
    enabled: (ed, a) => ed.canEdit,
    run: (ctx, ed, a) {
      FormattingFeatures.of(ed);
      s.panels.open(FormattingPanels.theme);
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.theme.set',
    label: (l) => l.cmdThemeSet,
    icon: LucideIcons.palette,
    categoryName: _fmt,
    mutates: true,
    showInPalette: false,
    argsSchema: const JsonSchema.object(
      properties: {
        'presetName': JsonSchema.string(
          description:
              'Standard, Simple, Streamline, Paperback, Marina, '
              'Coral, Forest, Mono, Retro or Ocean.',
        ),
        'themeJson': JsonSchema.anyOf([
          JsonSchema.object(additionalProperties: true),
          JsonSchema.string(),
        ]),
      },
    ),
    run: (ctx, ed, a) {
      final SpreadsheetTheme theme;
      final preset = a.string('presetName');
      final raw = a.values['themeJson'];
      if (preset != null) {
        final p = SpreadsheetTheme.preset(preset);
        if (p == null) return const CommandResult.failed('Unknown theme');
        theme = p;
      } else if (raw != null) {
        theme = SpreadsheetTheme.parse(raw is String ? raw : jsonEncode(raw));
      } else {
        return const CommandResult.failed('presetName or themeJson required');
      }
      FormattingFeatures.maybeOf(ed)?.theme.preview(null);
      ed.apply(ctx, SetSpreadsheetProperties(themeJson: theme.toJson()));
      return ok();
    },
  ),
  SheetsCommand(
    'sheets.theme.import',
    label: (l) => l.themeImport,
    icon: LucideIcons.import,
    categoryName: _fmt,
    mutates: true,
    argsSchema: const JsonSchema.object(
      properties: {
        'sourceItemUuid': JsonSchema.string(
          description: 'Drive item of the spreadsheet whose theme to copy.',
        ),
      },
    ),
    undoLabelOf: (l, a) => l.themeImport,
    run: (ctx, ed, a) async {
      final src = a.string('sourceItemUuid');
      SpreadsheetTheme? theme;
      if (src == null) {
        final dc = ctx.dialogContext;
        if (dc == null || !dc.mounted) return const CommandResult.cancelled();
        theme = await ThemeImport.pick(dc, ed);
      } else {
        try {
          theme = await ThemeImport.load(ed, UuidValue.fromString(src));
        } catch (_) {
          return CommandResult.failed(ed.l10n.pickSpreadsheetOffline);
        }
      }
      if (theme == null) return const CommandResult.cancelled();
      FormattingFeatures.maybeOf(ed)?.theme.preview(null);
      ed.apply(ctx, SetSpreadsheetProperties(themeJson: theme.toJson()));
      return ok({'theme': theme.name});
    },
  ),
];
