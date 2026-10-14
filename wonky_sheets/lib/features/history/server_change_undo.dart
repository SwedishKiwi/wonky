import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show RevertResult, UuidValue, WonkyErrorCode, WonkyException;
import 'package:wonky_core/wonky_core.dart';

import '../../l10n/sheets_l10n.dart';

/// Undo domain of changes applied on the server (Sheets 10 A-10-5): version
/// restores, MCP/AI/script edits surfaced in the UI.
const sheetsServerChangeDomain = 'sheets.serverChange';

/// One server-side change: undo reverts it (`SheetsEndpoint.revertChange`,
/// per-column skip rule), redo reverts the revert. [changeId] is always the
/// latest record (the original, then its revert, then the revert of that …).
class SheetsServerChangeEntry extends UndoEntry {
  const SheetsServerChangeEntry({required this.changeId, this.label = ''});

  final String changeId;

  /// "Restore version", "Claude: fill B2:B9" (diagnostics).
  final String label;

  @override
  String get domain => sheetsServerChangeDomain;

  /// Remote edits are handled by the server's skip rule at undo time.
  @override
  UndoEntry? rebase(RemoteChange change) => this;

  @override
  Map<String, Object?> toJson() => {'changeId': changeId, 'label': label};

  static SheetsServerChangeEntry? fromJson(Map<String, Object?> j) {
    final id = j['changeId'];
    if (id is! String) return null;
    return SheetsServerChangeEntry(
      changeId: id,
      label: j['label'] as String? ?? '',
    );
  }
}

/// Calls the server for [SheetsServerChangeEntry]s. Registered globally at
/// sign-in so restores made from the history screen (shell stack) undo too.
class SheetsServerChangeHandler extends UndoHandler<SheetsServerChangeEntry> {
  SheetsServerChangeHandler(this.services, {this.revert});

  final ShellServices services;

  /// Overrides the server call (tests).
  final Future<RevertResult> Function(String changeId)? revert;

  @override
  String get domain => sheetsServerChangeDomain;

  @override
  UndoEntryDecoder? get decoder => SheetsServerChangeEntry.fromJson;

  Future<RevertResult> _revert(String changeId) {
    final f = revert;
    if (f != null) return f(changeId);
    final client = services.client;
    if (client == null || Api.simulatedOffline) {
      throw const UndoConflict('Offline');
    }
    return client.sheets.revertChange(UuidValue.fromString(changeId));
  }

  Future<SheetsServerChangeEntry> _apply(SheetsServerChangeEntry e) async {
    final RevertResult r;
    try {
      r = await _revert(e.changeId);
    } on WonkyException catch (err) {
      if (err.code == WonkyErrorCode.notFound ||
          err.code == WonkyErrorCode.expired) {
        throw UndoConflict(err.message);
      }
      rethrow;
    }
    // Columns edited by others since were kept (partial undo, 10 §9).
    if (r.skipped.isNotEmpty) {
      services.toasts.show(sheetsL10nOf(services).toastUndoPartial);
    }
    return SheetsServerChangeEntry(changeId: r.changeId.uuid, label: e.label);
  }

  @override
  Future<SheetsServerChangeEntry> undo(SheetsServerChangeEntry entry) =>
      _apply(entry);

  @override
  Future<SheetsServerChangeEntry> redo(SheetsServerChangeEntry entry) =>
      _apply(entry);
}
