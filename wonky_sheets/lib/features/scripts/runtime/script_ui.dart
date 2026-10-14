import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../../l10n/sheets_l10n.dart';
import '../../grid/selection/grid_selection.dart' show SelectionKind;
import '../../sheet_editor/sheet_editor_controller.dart';
import 'script_panels.dart';

/// The UI side of client executions (09 §16): alerts and prompts as
/// `WonkyDialogSpec` dialogs (MCP-operable), toasts through the shell,
/// custom menus collected for the menubar, selection and sheet activation.
class AppScriptUi implements ScriptUiDelegate {
  AppScriptUi(this.editor, {required this.onMenu});

  final SheetEditorController editor;

  /// A script added a custom menu (`Menu.addToUi()`).
  final void Function(ScriptMenu menu) onMenu;

  ShellServices get _s => editor.services;

  @override
  Future<ScriptDialogResponse> showDialog(ScriptDialogRequest request) async {
    final context = _s.navigatorContext;
    if (context == null || !context.mounted) {
      return const ScriptDialogResponse(ScriptButton.close);
    }
    final l = sheetsL10n(context);
    final buttons = switch (request.buttons) {
      ScriptButtonSet.ok => [
        DialogButtonSpec(id: 'ok', label: l.dialogOk, primary: true),
      ],
      ScriptButtonSet.okCancel => [
        DialogButtonSpec(id: 'cancel', label: l.scriptButtonCancel),
        DialogButtonSpec(id: 'ok', label: l.dialogOk, primary: true),
      ],
      ScriptButtonSet.yesNo => [
        DialogButtonSpec(id: 'no', label: l.scriptButtonNo),
        DialogButtonSpec(id: 'yes', label: l.scriptButtonYes, primary: true),
      ],
      ScriptButtonSet.yesNoCancel => [
        DialogButtonSpec(id: 'cancel', label: l.scriptButtonCancel),
        DialogButtonSpec(id: 'no', label: l.scriptButtonNo),
        DialogButtonSpec(id: 'yes', label: l.scriptButtonYes, primary: true),
      ],
    };
    final title = request.title?.trim();
    final r = await showWonkyFormDialog(
      context,
      WonkyDialogSpec(
        title: title == null || title.isEmpty ? l.scriptDialogTitle : title,
        description: request.message,
        dialogKey: request.prompt
            ? 'dialog.scriptPrompt'
            : 'dialog.scriptAlert',
        fields: [
          if (request.prompt)
            TextFieldSpec(id: 'text', label: l.scriptPromptLabel),
        ],
        buttons: buttons,
        cancelId: 'close',
      ),
    );
    final button = switch (r?.buttonId) {
      'ok' => ScriptButton.ok,
      'cancel' => ScriptButton.cancel,
      'yes' => ScriptButton.yes,
      'no' => ScriptButton.no,
      _ => ScriptButton.close,
    };
    return ScriptDialogResponse(button, r?.text('text') ?? '');
  }

  @override
  void showToast(String message, {String? title, double timeoutSeconds = 5}) {
    final t = title?.trim();
    final duration = timeoutSeconds < 0
        ? const Duration(days: 1)
        : Duration(milliseconds: (timeoutSeconds * 1000).round());
    if (t == null || t.isEmpty) {
      _s.toasts.show(message, duration: duration);
    } else {
      _s.toasts.show(t, description: message, duration: duration);
    }
  }

  @override
  void addMenu(ScriptMenu menu) => onMenu(menu);

  @override
  void select(ResolvedRange range) {
    if (range.sheetId != editor.activeSheetId) {
      editor.activateSheet(range.sheetId);
    }
    editor.selection.setRanges([
      (
        range.wholeRows
            ? SelectionKind.rows
            : range.wholeColumns
            ? SelectionKind.columns
            : SelectionKind.cells,
        range.rect,
      ),
    ]);
    editor.revealActive();
  }

  @override
  void activateSheet(String sheetId) => editor.activateSheet(sheetId);

  @override
  void showPanel(ScriptPanelRequest request) =>
      ScriptPanels.of(editor).show(request);

  @override
  void updatePanel(String panelId, Map<String, Object?> panel) =>
      ScriptPanels.of(editor).update(panelId, panel);

  @override
  void closePanel(String panelId) => ScriptPanels.of(editor).close(panelId);
}
