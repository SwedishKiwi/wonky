import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets/config/sheets_app_config.dart';
import 'package:wonky_sheets/features/clipboard/clipboard_service.dart';
import 'package:wonky_sheets/features/clipboard/system_clipboard.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets/features/sheet_editor/sheet_editor_controller.dart';
import 'package:wonky_sheets/features/sheet_editor/sheets_document_controller.dart';
import 'package:wonky_sheets_core/model.dart';

/// Fixed id of the spreadsheet item used by tests.
const testItemUuid = '01923456-789a-7bcd-8ef0-123456789abc';

/// A blank in-memory spreadsheet with the Sheets commands registered and a
/// [SheetsDocumentController] active, for command and controller tests.
class SheetsHarness {
  SheetsHarness._(this.h, this.session, this.doc, this.editor, this.clip);

  static SheetsHarness open({Role role = Role.owner}) {
    final h = CommandTestHarness(config: const SheetsAppConfig());
    final uuid = UuidValue.fromString(testItemUuid);
    h.drive.seed(name: 'Budget', uuid: uuid);
    final session = MemoryWorkbookSession.blank(itemUuid: uuid, role: role);
    final doc = SheetsDocumentController(
      services: h.services,
      itemUuid: uuid,
      title: 'Budget',
    );
    doc.update(role: role);
    final clip = MemoryClipboard();
    final editor = SheetEditorController(
      services: h.services,
      session: session,
      clipboard: (e) => ClipboardService(e, system: clip),
    );
    doc.attach(editor);
    h.services.activate(doc);
    return SheetsHarness._(h, session, doc, editor, clip);
  }

  final CommandTestHarness h;
  final MemoryWorkbookSession session;
  final SheetsDocumentController doc;
  final SheetEditorController editor;
  final MemoryClipboard clip;

  ShellServices get services => h.services;
  WorkbookModel get model => session.model;
  String get sheetId => editor.activeSheetId;
  SheetModel get sheet => editor.activeSheet!;

  /// Invokes a command as a UI gesture.
  Future<CommandResult> run(
    String id, [
    Map<String, Object?> args = const {},
  ]) => h.invoke(id, args, InvocationSource.ui);

  Future<void> undo() async => h.undo();
  Future<void> redo() async => h.redo();

  /// Types [input] into cell [a1] through `sheets.cell.setInput`.
  Future<void> type(String a1, String input) =>
      run('sheets.cell.setInput', {'a1': a1, 'input': input});

  /// Selects [a1] (one or several comma-separated ranges).
  Future<void> select(String a1) => run('sheets.select.range', {'a1': a1});

  /// The displayed text of [a1].
  String text(String a1) {
    final r = model.parseA1(a1, contextSheetId: sheetId);
    return editor.cells.displayAt(sheetId, r.rect.top, r.rect.left)?.text ?? '';
  }

  /// The stored content of [a1].
  String? content(String a1) {
    final r = model.parseA1(a1, contextSheetId: sheetId);
    return model.cellAt(sheetId, r.rect.top, r.rect.left)?.content;
  }

  /// The explicit format chain of [a1].
  CellFormat format(String a1) {
    final r = model.parseA1(a1, contextSheetId: sheetId);
    return model.explicitFormatChain(sheetId, r.rect.top, r.rect.left);
  }

  Future<void> dispose() async {
    services.deactivate(doc);
    editor.dispose();
    await session.dispose();
    await h.dispose();
  }
}
