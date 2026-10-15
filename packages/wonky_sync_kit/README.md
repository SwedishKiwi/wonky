# wonky_sync_kit

Pure-Dart half of the shared offline-sync kit of Wonky Work, extracted from Wonky Sheets for
Wonky Slides (specs/wonky_slides/12-implementation-plan.md §5.1, specs/12-offline-and-sync.md
§2.6, Drive 05 D-6). The client half is `wonky_sync_kit_flutter`.

| Library | API |
|---------|-----|
| `rows.dart` | `RowOp`, `RowChange`, `CurrentRowReader`, `ChangeSummary` (+ `JsonChangeSummary`), `MutationPlan<S>`, `UndoInverter` with the table hooks `CoupledColumns` (+ `TableCoupledColumns`) and `ColumnwiseInserts` (+ `TableColumnwiseInserts`), `SyncTxAdapter`, `RowPatch` (replica rows + pending writes → model changes) |
| `tables.dart` | `SyncTableSet` (an app's synced tables: dependency order, model tables, root table) on the `wonky_sync_models` table codec |
| `undo.dart` | `RowsUndoEntry`, `RowsUndoTarget`, `RowsUndoHandler` — the `*.rows` undo domains (`sheets.rows`, `slides.rows`) |

Apps supply their table set, change summary and table hooks: Sheets' `ChangeSummary`,
`MutationPlan` (= `MutationPlan<ChangeSummary>`) and `SheetsUndo` (the cell rule as a
`ColumnwiseInserts` hook) live in `wonky_sheets_core`.
