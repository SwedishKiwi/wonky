import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_sheets_core/model.dart';

import 'workbook_session.dart';

/// Undo domain of synced-row changes (suite 08 §3.3).
const sheetsRowsDomain = 'sheets.rows';

/// One `sheets.rows` undo entry: the [RowChange]s a plan applied (in order).
/// Undo writes their inverse against the current state with the per-column
/// skip rule (`UndoInverter`), so collaborators' later edits are never
/// reverted.
class SheetsRowsUndoEntry extends UndoEntry {
  SheetsRowsUndoEntry(List<RowChange> changes, {this.label = ''})
    : changes = List.unmodifiable(changes);

  final List<RowChange> changes;

  /// The plan label ("Paste", "Insert 3 rows").
  final String label;

  @override
  String get domain => sheetsRowsDomain;

  /// Remote changes are handled at undo time by the skip rule.
  @override
  UndoEntry? rebase(RemoteChange change) => this;

  /// Entries of one step on the same stack merge into one list.
  @override
  UndoEntry? coalesce(UndoEntry next) => next is SheetsRowsUndoEntry
      ? SheetsRowsUndoEntry([...changes, ...next.changes], label: label)
      : null;

  @override
  Map<String, Object?> toJson() => {
    'label': label,
    'changes': [for (final c in changes) c.toJson()],
  };

  static SheetsRowsUndoEntry? fromJson(Map<String, Object?> json) {
    final raw = json['changes'];
    if (raw is! List) return null;
    try {
      return SheetsRowsUndoEntry([
        for (final c in raw) RowChange.fromJson((c as Map).cast()),
      ], label: json['label'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }
}

/// Applies `sheets.rows` entries through the open [WorkbookSession].
///
/// Undo and redo are the same operation: invert the entry's changes against
/// the current model (skipping columns someone else changed since) and
/// apply the result; the returned entry holds what was applied, so its
/// inversion is the next redo/undo.
class SheetsRowsUndoHandler extends UndoHandler<SheetsRowsUndoEntry> {
  SheetsRowsUndoHandler(this.session, {this.onPartial});

  final WorkbookSession Function() session;

  /// Called when some (not all) columns were skipped.
  final void Function()? onPartial;

  @override
  String get domain => sheetsRowsDomain;

  @override
  UndoEntryDecoder? get decoder => SheetsRowsUndoEntry.fromJson;

  @override
  Future<SheetsRowsUndoEntry> undo(SheetsRowsUndoEntry entry) async =>
      _apply(entry, 'Undo');

  @override
  Future<SheetsRowsUndoEntry> redo(SheetsRowsUndoEntry entry) async =>
      _apply(entry, 'Redo');

  SheetsRowsUndoEntry _apply(SheetsRowsUndoEntry entry, String verb) {
    final s = session();
    var skipped = 0;
    final inverse = UndoInverter.invertChanges(
      entry.changes,
      s.model,
      skipped: (_, _, _) => skipped++,
    );
    if (inverse.isEmpty) {
      if (entry.changes.isEmpty) return entry;
      throw const UndoConflict('Changed by someone else');
    }
    s.applyChanges(
      inverse,
      label: entry.label.isEmpty ? verb : '$verb ${entry.label}',
    );
    if (skipped > 0) onPartial?.call();
    return SheetsRowsUndoEntry(inverse, label: entry.label);
  }
}
