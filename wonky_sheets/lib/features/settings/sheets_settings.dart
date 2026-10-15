import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../../l10n/sheets_l10n.dart';
import '../formatting/sheets_user_defaults.dart';
import 'sheets_settings_section.dart';

/// Sheets settings (suite 04 §4, Sheets 04 §11.24): the app settings of
/// Wonky Sheets at `/settings/app/defaults` (`/settings/sheets` redirects).
List<SettingsSectionSpec> sheetsSettingsSections(ShellServices services) => [
  SettingsSectionSpec(
    id: 'defaults',
    title: (c) => sheetsL10n(c).sheetsSettingsDefaults,
    icon: LucideIcons.slidersHorizontal,
    builder: (_) => SheetsSettingsSection(services: services),
  ),
];

/// The value checks of the `sheetsDefaults` keys `sheets.prefs.set`
/// accepts (Sheets 04 §11.24).
final Map<String, bool Function(Object? v)> sheetsSettingKeys = {
  SheetsUserDefaults.keyLocale: (v) => v is String,
  SheetsUserDefaults.keyTimeZone: (v) => v is String,
  SheetsUserDefaults.keyFontFamily: (v) => v is String,
  SheetsUserDefaults.keyFontSize: (v) => v is num && v >= 6 && v <= 400,
  SheetsUserDefaults.keyEnterStartsEditing: (v) => v is bool,
  SheetsUserDefaults.keyFormulaAutocomplete: (v) => v is bool,
  SheetsUserDefaults.keyFormulaHelp: (v) => v is bool,
  SheetsUserDefaults.keyColumnAutocomplete: (v) => v is bool,
  SheetsUserDefaults.keyShowEditorMode: (v) => v is bool,
  SheetsUserDefaults.keyReduceAnimations: (v) => v is bool,
  SheetsUserDefaults.keyScriptsEnabled: (v) => v is bool,
  SheetsUserDefaults.keyChartSeriesByPattern: (v) => v is bool,
  SheetsUserDefaults.keyCustomFillLists: (v) =>
      v is List && v.every((l) => l is List && l.every((x) => x is String)),
};

/// `sheets.prefs.set {key, value}`: changes one Sheets setting (every
/// control of Settings › Sheets goes through it, so MCP can change them
/// too; suite 04 §4.2). Settings are not undoable; works without an open
/// spreadsheet.
List<Command<CommandArgs>> sheetsSettingsCommands(ShellServices s) => [
  CallbackCommand(
    id: 'sheets.prefs.set',
    title: (c) => sheetsL10n(c).cmdSheetsPrefsSet,
    icon: LucideIcons.slidersHorizontal,
    showInPalette: false,
    argsSchema: JsonSchema.object(
      properties: {
        'key': JsonSchema.string(enumValues: sheetsSettingKeys.keys.toList()),
        'value': const JsonSchema.any(),
      },
      required: const ['key', 'value'],
    ),
    run: (ctx, a) async {
      final key = a.requireString('key');
      final value = a.values['value'];
      final valid = sheetsSettingKeys[key];
      if (valid == null) return CommandResult.failed('Unknown setting "$key"');
      if (!valid(value)) {
        return CommandResult.failed('Invalid value for "$key"');
      }
      await SheetsUserDefaults.of(s).set(key, value);
      return const CommandResult.ok();
    },
  ),
];
