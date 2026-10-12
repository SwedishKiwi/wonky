import 'dart:convert';

import '../format/attributes.dart';
import '../model/records.dart';
import '../model/schema.dart';
import '../mutations/row_change.dart';
import 'snapshot.dart';

/// Kind of a changed cell between two versions (10 §5.2).
enum CellChangeKind {
  /// Content (value/formula) changed, added or removed.
  content,

  /// Only the note changed.
  note,

  /// Only format attributes changed (outlined dashed).
  format,
}

/// One changed cell.
final class CellChange {
  /// Creates a change.
  const CellChange(this.sheetId, this.rowId, this.colId, this.kind);

  final String sheetId;
  final String rowId;
  final String colId;
  final CellChangeKind kind;

  /// Compact JSON.
  Map<String, Object?> toJson() => {'s': sheetId, 'r': rowId, 'c': colId, 'k': kind.name};

  @override
  bool operator ==(Object other) =>
      other is CellChange &&
      other.sheetId == sheetId &&
      other.rowId == rowId &&
      other.colId == colId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(sheetId, rowId, colId, kind);

  @override
  String toString() => 'CellChange($sheetId, $rowId, $colId, ${kind.name})';
}

/// Structural differences of one sheet.
final class SheetStructureChange {
  /// Creates a change.
  SheetStructureChange(this.sheetId);

  final String sheetId;
  final List<String> rowsAdded = [];
  final List<String> rowsRemoved = [];
  final List<String> columnsAdded = [];
  final List<String> columnsRemoved = [];

  /// Whether nothing changed.
  bool get isEmpty =>
      rowsAdded.isEmpty && rowsRemoved.isEmpty && columnsAdded.isEmpty && columnsRemoved.isEmpty;

  /// JSON.
  Map<String, Object?> toJson() => {
    's': sheetId,
    if (rowsAdded.isNotEmpty) 'ra': rowsAdded,
    if (rowsRemoved.isNotEmpty) 'rr': rowsRemoved,
    if (columnsAdded.isNotEmpty) 'ca': columnsAdded,
    if (columnsRemoved.isNotEmpty) 'cr': columnsRemoved,
  };
}

/// Differences between two snapshots (previous → current version).
final class SnapshotDiff {
  /// Creates a diff.
  SnapshotDiff();

  /// Changed cells (by cell id).
  final List<CellChange> cells = [];

  /// Added sheets.
  final List<String> sheetsAdded = [];

  /// Removed sheets (shown as strikethrough tabs).
  final List<String> sheetsRemoved = [];

  /// Renamed sheets: id → (old name, new name).
  final Map<String, (String, String)> sheetsRenamed = {};

  /// Per-sheet structure changes.
  final Map<String, SheetStructureChange> structure = {};

  /// Sheets with any change (tab dots).
  Set<String> get changedSheets => {
    for (final c in cells) c.sheetId,
    ...sheetsAdded,
    ...sheetsRenamed.keys,
    for (final s in structure.values)
      if (!s.isEmpty) s.sheetId,
  };

  /// Compact JSON (server-side cache `<versionId>.diff.gz`).
  Map<String, Object?> toJson() => {
    'cells': [for (final c in cells) c.toJson()],
    'sheetsAdded': sheetsAdded,
    'sheetsRemoved': sheetsRemoved,
    'sheetsRenamed': {
      for (final e in sheetsRenamed.entries) e.key: [e.value.$1, e.value.$2],
    },
    'structure': [
      for (final s in structure.values)
        if (!s.isEmpty) s.toJson(),
    ],
  };

  /// From [toJson].
  static SnapshotDiff fromJson(Map<String, Object?> m) {
    final d = SnapshotDiff();
    for (final c in (m['cells'] as List? ?? const [])) {
      final x = c as Map;
      d.cells.add(
        CellChange(
          x['s'] as String,
          x['r'] as String,
          x['c'] as String,
          CellChangeKind.values.byName(x['k'] as String),
        ),
      );
    }
    d.sheetsAdded.addAll((m['sheetsAdded'] as List? ?? const []).cast<String>());
    d.sheetsRemoved.addAll((m['sheetsRemoved'] as List? ?? const []).cast<String>());
    (m['sheetsRenamed'] as Map? ?? const {}).forEach((k, v) {
      final l = (v as List).cast<String>();
      d.sheetsRenamed[k as String] = (l[0], l[1]);
    });
    for (final s in (m['structure'] as List? ?? const [])) {
      final x = s as Map;
      final sc = SheetStructureChange(x['s'] as String)
        ..rowsAdded.addAll((x['ra'] as List? ?? const []).cast<String>())
        ..rowsRemoved.addAll((x['rr'] as List? ?? const []).cast<String>())
        ..columnsAdded.addAll((x['ca'] as List? ?? const []).cast<String>())
        ..columnsRemoved.addAll((x['cr'] as List? ?? const []).cast<String>());
      d.structure[sc.sheetId] = sc;
    }
    return d;
  }

  /// JSON string.
  String encode() => jsonEncode(toJson());
}

/// Computes version diffs and restore plans (10 §5.2–§5.3).
abstract final class SnapshotDiffer {
  static final Set<String> _formatColumns = {for (final a in FormatAttr.values) a.column};

  /// Cell-level and structural differences from [previous] to [current].
  static SnapshotDiff diff(Snapshot previous, Snapshot current) =>
      diffRows(previous.rows, current.rows);

  /// [diff] over raw row lists.
  static SnapshotDiff diffRows(
    Iterable<(String, Map<String, Object?>)> previous,
    Iterable<(String, Map<String, Object?>)> current,
  ) {
    Map<String, Map<String, Map<String, Object?>>> index(
      Iterable<(String, Map<String, Object?>)> rows,
    ) {
      final m = <String, Map<String, Map<String, Object?>>>{};
      for (final (t, c) in rows) {
        (m[t] ??= {})[c[Cols.id].toString()] = c;
      }
      return m;
    }

    final a = index(previous);
    final b = index(current);
    final d = SnapshotDiff();
    // Sheets.
    final sa = a[SheetsTables.sheet] ?? const {};
    final sb = b[SheetsTables.sheet] ?? const {};
    for (final id in sb.keys) {
      if (!sa.containsKey(id)) {
        d.sheetsAdded.add(id);
      } else if (sa[id]![Cols.name] != sb[id]![Cols.name]) {
        d.sheetsRenamed[id] = (sa[id]![Cols.name] as String, sb[id]![Cols.name] as String);
      }
    }
    for (final id in sa.keys) {
      if (!sb.containsKey(id)) d.sheetsRemoved.add(id);
    }
    // Rows/columns.
    void dims(String table, bool rows) {
      final x = a[table] ?? const {};
      final y = b[table] ?? const {};
      SheetStructureChange sc(Map<String, Object?> r) {
        final s = r[Cols.sheetId] as String;
        return d.structure.putIfAbsent(s, () => SheetStructureChange(s));
      }

      for (final e in y.entries) {
        if (!x.containsKey(e.key)) {
          (rows ? sc(e.value).rowsAdded : sc(e.value).columnsAdded).add(e.key);
        }
      }
      for (final e in x.entries) {
        if (!y.containsKey(e.key)) {
          (rows ? sc(e.value).rowsRemoved : sc(e.value).columnsRemoved).add(e.key);
        }
      }
    }

    dims(SheetsTables.sheetRow, true);
    dims(SheetsTables.sheetColumn, false);
    // Cells.
    final ca = a[SheetsTables.cell] ?? const {};
    final cb = b[SheetsTables.cell] ?? const {};
    void cell(Map<String, Object?>? before, Map<String, Object?>? after) {
      final ref = after ?? before!;
      CellChangeKind? kind;
      if (before?[CellCols.content] != after?[CellCols.content]) {
        kind = CellChangeKind.content;
      } else if (before?[CellCols.note] != after?[CellCols.note]) {
        kind = CellChangeKind.note;
      } else if (_formatColumns.any((k) => before?[k] != after?[k])) {
        kind = CellChangeKind.format;
      }
      if (kind == null) return;
      d.cells.add(
        CellChange(
          ref[Cols.sheetId] as String,
          ref[CellCols.rowId] as String,
          ref[CellCols.columnId] as String,
          kind,
        ),
      );
    }

    for (final e in cb.entries) {
      cell(ca[e.key], e.value);
    }
    for (final e in ca.entries) {
      if (!cb.containsKey(e.key)) cell(e.value, null);
    }
    return d;
  }

  /// Row changes that turn [current] into [target] (version restore,
  /// 10 §5.3): inserts (same ids, reviving tombstones) for rows only in
  /// [target], deletes for rows only in [current], updates naming only the
  /// differing columns. `script_trigger`, `script_build` and `change_log` are
  /// excluded. Ordered parents first for inserts, children first for deletes.
  static MutationPlan restorePlan(
    Iterable<(String, Map<String, Object?>)> target,
    Iterable<(String, Map<String, Object?>)> current, {
    String label = 'Restore version',
  }) {
    Map<(String, String), Map<String, Object?>> index(
      Iterable<(String, Map<String, Object?>)> rows,
    ) => {
      for (final (t, c) in rows)
        if (!SnapshotCodec.excludedTables.contains(t)) (t, c[Cols.id].toString()): c,
    };
    final t = index(target);
    final c = index(current);
    final inserts = <RowChange>[];
    final deletes = <RowChange>[];
    final updates = <RowChange>[];
    bool same(Object? x, Object? y) {
      if (x is num && y is num) return x.toDouble() == y.toDouble();
      if (x is DateTime && y is DateTime) return x.isAtSameMomentAs(y);
      return x == y;
    }

    for (final e in t.entries) {
      final cur = c[e.key];
      if (cur == null) {
        inserts.add(RowChange.insert(e.key.$1, e.key.$2, e.value));
        continue;
      }
      final before = <String, Object?>{};
      final after = <String, Object?>{};
      final keys = {...e.value.keys, ...cur.keys}..remove(Cols.id);
      for (final k in keys) {
        if (!same(e.value[k], cur[k])) {
          before[k] = cur[k];
          after[k] = e.value[k];
        }
      }
      if (after.isNotEmpty) updates.add(RowChange.update(e.key.$1, e.key.$2, before, after));
    }
    for (final e in c.entries) {
      if (!t.containsKey(e.key)) deletes.add(RowChange.delete(e.key.$1, e.key.$2, e.value));
    }
    int rank(RowChange x) => SheetsTables.rank(x.table);
    deletes.sort((x, y) => rank(y).compareTo(rank(x)));
    inserts.sort((x, y) => rank(x).compareTo(rank(y)));
    updates.sort((x, y) => rank(x).compareTo(rank(y)));
    final summary = ChangeSummary(kinds: {ChangeKinds.restore});
    for (final d in deletes) {
      switch (d.table) {
        case SheetsTables.sheetRow:
          summary.addDeleted('rows', d.rowId);
        case SheetsTables.sheetColumn:
          summary.addDeleted('cols', d.rowId);
        case SheetsTables.sheet:
          summary.addDeleted('sheets', d.rowId);
      }
    }
    for (final i in inserts) {
      switch (i.table) {
        case SheetsTables.sheetRow:
          summary.addRevived('rows', i.rowId);
        case SheetsTables.sheetColumn:
          summary.addRevived('cols', i.rowId);
        case SheetsTables.sheet:
          summary.addRevived('sheets', i.rowId);
      }
    }
    for (final r in [...inserts, ...updates, ...deletes]) {
      if (r.table == SheetsTables.cell) {
        final s = (r.columnsAfter[Cols.sheetId] ?? r.columnsBefore[Cols.sheetId]) as String?;
        if (s != null) summary.sheets.add(s);
      }
    }
    return MutationPlan(
      label: label,
      summary: summary,
      changes: [...deletes, ...inserts, ...updates],
    );
  }

  /// Records of [rows] converted (helper for tests and UIs).
  static Iterable<SyncRecord> records(Iterable<(String, Map<String, Object?>)> rows) =>
      rows.map((r) => recordFromColumns(r.$1, r.$2));
}
