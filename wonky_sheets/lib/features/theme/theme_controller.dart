import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/model.dart';

import '../sheet_editor/sheet_editor_controller.dart';

/// The spreadsheet theme (06 §13): the theme panel previews a draft through
/// `WorkbookModel.previewTheme` until *Done* commits `sheets.theme.set`.
class ThemeController extends ChangeNotifier {
  ThemeController(this.editor, {this.onPreviewChanged});

  final SheetEditorController editor;

  /// Called after the previewed theme changes (CF colors are re-resolved).
  final VoidCallback? onPreviewChanged;

  SpreadsheetTheme? get draft => editor.model.previewTheme;

  /// The stored theme.
  SpreadsheetTheme get stored =>
      SpreadsheetTheme.parse(editor.model.spreadsheet.themeJson);

  /// The theme cells render with (draft or stored).
  SpreadsheetTheme get current => editor.model.theme;

  /// Previews [t] (null ends the preview).
  void preview(SpreadsheetTheme? t) {
    final model = editor.model;
    if (t == model.previewTheme) return;
    model.previewTheme = t;
    onPreviewChanged?.call();
    editor.cells.invalidate();
    editor.contentSignal.fire();
    notifyListeners();
  }

  @override
  void dispose() {
    if (editor.model.previewTheme != null) editor.model.previewTheme = null;
    super.dispose();
  }
}
