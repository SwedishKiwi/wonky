# Wonky Sheets — implementation status (paused)

Work on Wonky Sheets was **paused** on 2026-10-12 so the first iteration could ship a complete
Wonky Write. Everything below compiles (`dart analyze` reports 0 errors); nothing is wired
into a running UI yet. Use this file to pick the work back up. The plan to follow is
[13-implementation-plan.md](13-implementation-plan.md).

## Summary

| Area | Package / path | State |
|------|----------------|-------|
| Sync models (`database: sync`) | `packages/wonky_sync_models/lib/src/models/*.spy.yaml` | **Done.** All tables of 02 §3 and the feature additions of 02 §9 are defined and generated. They are part of the server migration. |
| Ids, fractional index, base-62 UUID | `packages/wonky_sync_models/lib/ids.dart` → `lib/src/ids/` | **Done and tested** (`dart test test/ids test/property`). |
| Formula engine | `packages/wonky_sheets_core/lib/formula.dart` → `lib/src/addressing/`, `lib/src/formula/` | **Mostly done.** Parser (locales), A1 ⇄ stored codec with id tokens, reference rewriter, evaluator, spill, LAMBDA/LET, QUERY, dependency graph and recalculation. About 380 functions registered (catalog target ~480). Services: autocomplete, signature help, highlighter, diagnostics, explain. |
| Workbook model | `lib/src/model/`, `lib/src/content/` | **Done and tested.** `WorkbookModel`, `AxisIndex` (Fenwick), `CellStore`, `RectIndex`, `GridRange`, `CellContent` codec, rich text. |
| Mutation planner + undo | `lib/src/mutations/` | **Mostly done.** `SheetsMutationPlanner().plan(op, model, PlanContext)` returns a `MutationPlan` of `RowChange`s; undo via `UndoInverter.invert`. `WorkbookMaintenance` is in the same folder. |
| Engine ↔ model bridge | `lib/src/engine_bridge/` | **Done.** `ModelEngineBinding`, `ModelWorkbookView`, `EngineFormulaHooks`, `ModelCellSource`. |
| Formatting core | `lib/src/format/` | **Done.** Effective-format resolver, themes, banding, borders. |
| Number formats, input parsing, fill series | `lib/src/format/number_format/`, `lib/src/input/`, `lib/src/fill/` | **Done and tested** (641 tests). Only the contract files are exported from `lib/model.dart` (see open items). |
| Rules (CF/DV), data tools, pivots | `lib/src/rules/`, `lib/src/data_tools/`, `lib/src/pivot/` | **Partial.** The helper was cut off while writing its cleanup/split/random/stats tests. Not reviewed; not exported. |
| Charts engine + objects | `lib/src/charts/`, `lib/src/objects/` | **Partial / large** (about 12.6k lines). Cut off while writing test support. Not reviewed; not exported. |
| CSV/TSV/XLSX/ODS import/export | `lib/src/io/` | **Partial.** In-house OOXML/ODS reader/writer on `archive` + `xml` (no `excel_plus`; spec 11 §5.1 updated). Not reviewed; not exported. |
| Clipboard codecs, HTML export, print/PDF | `lib/src/clipboard/`, `lib/src/io/html/`, `lib/src/io/print/` | **Partial.** Cut off while writing HTML fixtures and codec tests. |
| Snapshots / version diff, space copy | `lib/src/snapshot/`, `lib/src/copy/` | **Done.** |
| Server: spaces, sync endpoint, change log, versions | `wonky_server/lib/src/sheets/` | **Partial.** Models and endpoints exist (reserve/subscribe spaces, custom sync endpoint, change-log consumer skeleton); not exercised by a client. Server-side `createSpreadsheet` may be incomplete. |
| Flutter app | `wonky_sheets/lib/` | **Shell only.** The app boots through `wonky_app` (sign-in, home filtered to spreadsheets). `/s/:uuid` shows a "coming soon" placeholder. No sync controller, grid, menus or panels. |
| Scripting | `packages/wonky_sheets_script/` | **Not started.** |
| MCP / AI for Sheets | — | **Not started.** |

## Test status (`dart test -x slow` in `packages/wonky_sheets_core`)

2,956 tests pass and 5 fail. All five failures are in `test/formula/recalc/engine_test.dart`:
- moving rows: references don't follow the data;
- two spills collide: the earlier anchor doesn't win;
- circular references (three tests): two-cell cycle error propagation, recomputing after the cycle is broken, and iterative convergence.

## Open items to finish the core before UI work

1. **Exports.** Add the helper barrels to `lib/model.dart`:
   - in place of the contract files: `format/number_format/number_format.dart`, `input/input.dart`, `fill/fill.dart`;
   - plus `rules`, `data_tools`, `pivot`, `charts`, `objects`, `io`, `clipboard`.

   Review each barrel first and check for export name clashes with `lib/formula.dart`.
2. **Planner ops** still throw `PlanException('unsupported')` in `lib/src/mutations/handlers/data.dart`:
   - SortRange, RemoveDuplicates, TrimWhitespace, SplitTextToColumns, FindReplace, FillSeries, AdjustDecimals, GroupOperation.

   The row-permutation machinery is ready in `handlers/row_move.dart`; each op only needs the matching helper engine wired in.
3. **Tests.** Add `dart_test.yaml` to `wonky_sheets_core` declaring the `property` and `slow` tags. Then fix the five failing engine tests above.
4. **Function catalog.** Fill the gap from about 380 to the ~480 functions of 05.
5. **Spec fixes:**
   - 03 §8.6: change currency detection to match 06 §5.9 (`"$"#,##0`; other symbols `[$€]`).
   - 06 §5.9: list the time formats `h:mm`, `h:mm AM/PM`, `h:mm:ss.000` as in 03 §8.6.
   - 01 §2.1 and the vendored-package table: remove `excel_plus`.
6. **Known limit:** when an anchor id is gone and there's no sort-key hint, `WorkbookMaintenance` re-anchors pivots and objects to the first row/column instead of the nearest one.

## Next steps (UI, in the order of 13 §6)

Sync controller and `SheetsWriter` (`wonky_sheets/lib/features/sync`, `features/model`) →
grid rendering → selection/editing/formula bar/clipboard/fill → menus/toolbar/tabs (04) →
formatting UI → CF/DV/filters → charts → pivots → import/export/print → comments/history →
MCP/AI → scripting.

The `toptap` project (`~/Projects/toptap`) is a working reference for the offline-sync client
(`createSyncSession`, `syncContinuously`, web SQLite with `sqlite3.wasm` + `db_worker.js`,
`sqlite3_web` pinned to 0.9.4).

### Integration notes from the core agents
- **App/server writers:**
  - apply `plan.changes` in ≤5,000-row chunks, naming `RowChange.touchedColumns` in `columnValues`;
  - write the ChangeLog row from `plan.changeLogColumns(...)`;
  - ingest locally with `model.applyPlan(plan)`.
- **Headless:** `ModelEngineBinding.create(model)`, then pass `EngineFormulaHooks(model, engine: binding.engine)` in the `PlanContext`.
- **A1 input:** `model.parseA1`; failures throw `InvalidRangeException`.
- **Input parsing:** `+`/`-` input can only become a formula when `isFormula` is passed (for example backed by `FormulaHooks`).
- **Currency presets:** en_US uses `"$"`; every other locale uses `[$sym-LCID]`.
