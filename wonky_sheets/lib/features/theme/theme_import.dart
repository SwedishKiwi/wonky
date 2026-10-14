import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets_core/model.dart';

import '../data_tools/spreadsheet_picker_dialog.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// *Import theme* (06 §13, P2): the theme of another spreadsheet the user
/// can open, fetched online (`sheets.spreadsheetTheme`).
abstract final class ThemeImport {
  /// Loads the theme of [item]; throws when offline.
  static Future<SpreadsheetTheme> load(
    SheetEditorController ed,
    UuidValue item,
  ) async {
    final client = ed.services.client;
    if (client == null) throw StateError('offline');
    return SpreadsheetTheme.parse(await client.sheets.spreadsheetTheme(item));
  }

  /// Picks a spreadsheet and returns its theme (null when cancelled; a toast
  /// explains failures).
  static Future<SpreadsheetTheme?> pick(
    BuildContext context,
    SheetEditorController ed,
  ) async {
    final item = await showSpreadsheetPickerDialog(
      context,
      services: ed.services,
      title: ed.l10n.themeImportTitle,
      exclude: ed.session.itemUuid,
    );
    if (item == null) return null;
    try {
      return await load(ed, item.uuid);
    } catch (_) {
      ed.services.toasts.error(ed.l10n.pickSpreadsheetOffline);
      return null;
    }
  }
}
