# Sheets 02 · Data Model (Offline-First Sync)

Read first: suite [12-offline-and-sync.md](../12-offline-and-sync.md) §2 (engine
rules). All synced models live in the shared package `packages/wonky_sync_models`
(`database: sync`), so server, client and Flutter app share them. Id helpers (UUIDv5
namespaces, fractional indexing, the 22-char base-62 UUID codec) live in the same package as a
pure-Dart library without Serverpod imports (`lib/ids.dart`, implementation in `lib/src/ids/`)
so server and clients compute identical ids.

## 1. Modeling principles

| # | Principle | Why |
|---|-----------|-----|
| S1 | **One spreadsheet = one space**; `Spreadsheet.id` = space UUID. | Space is the unit of sharing and replication. |
| S2 | **Rows and columns are entities with stable UUIDs** (`SheetRow`, `SheetColumn`) ordered by a **fractional index** `sortKey` (base-62 string, tie-break on `id`). | Inserting/deleting/moving rows or columns is O(1) writes and merges cleanly with concurrent edits; cells never need to be renumbered. |
| S3 | **Cells are addressed by (rowId, colId)**, one `Cell` row per *non-empty* cell, with a **deterministic id** `UUIDv5(ns, "cell:<sheetId>:<rowId>:<colId>")`. | Two offline users writing the same cell produce the same row → one CRDT chain, field-level LWW. No unique index needed. |
| S4 | **Each format attribute is its own column.** | Concurrent "bold" and "fill color" on the same cell both survive (field-level merge). |
| S5 | **Cell content is a single column** (`content`) in a typed text encoding. | Value + type change atomically (no half-merged states). |
| S6 | **Formulas are stored with id-based references** and rendered as A1 for display/editing. | Concurrent row/column inserts never require rewriting formulas, so offline edits merge without formula corruption. |
| S7 | **Range-based rules** (conditional formats, validation, filters, protected ranges, charts, pivots) store ranges as id-based `GridRange` JSON, not FKs. | Ranges span many rows; FK-per-boundary is brittle. Missing ids shrink/ignore at evaluation time. |
| S8 | **Every update names its columns** (`columnValues:`); enforced by a lint test over repositories (toptap pattern). | Otherwise the engine records all fields as touched and clobbers concurrent edits. |
| S9 | **Computed values are never synced.** Each client (and the server for headless use) evaluates formulas locally with `wonky_sheets_core`. | Keeps sync volume proportional to user edits; avoids recalculation write storms. |
| S10 | **A synced `ChangeLog` row per undo transaction** records what changed. | Substitutes for missing per-change server hooks: drives server-side triggers, activity, cell edit history, MCP revert. |

## 2. Identifiers and encodings (`wonky_sync_models/lib/src/`)

- `SheetsIds.cellId(sheetId, rowId, colId)`, `SheetsIds.basicFilterId(sheetId)`,
  `SheetsIds.scriptBuildId(projectId)` — UUIDv5 with fixed namespace UUIDs (constants, never
  change).
- **Fractional index** (`FractionalIndex.between(a, b)`, `.before(a)`, `.after(b)`,
  `.nBetween(a, b, n)`): base-62 strings (Figma/`fractional-indexing` algorithm); generating n keys
  for bulk inserts produces evenly spaced short keys. Ties (concurrent identical keys) sort by
  `id`.
- **Content encoding** (`CellContent`):
  | Prefix | Meaning | Example |
  |--------|---------|---------|
  | `=` | Formula in stored-reference form | `=SUM(⟦R:5Kq…;C:9zA…⟧:⟦R:7Hb…;C:9zA…⟧)` |
  | `n:` | Number (Dart double, shortest round-trip repr) | `n:42.5` |
  | `s:` | Text | `s:Hello` |
  | `b:` | Boolean `0`/`1` | `b:1` |
  | `e:` | Error literal | `e:#N/A` |
  | `r:` | Rich text JSON `{"t":"text","runs":[{"s":0,"e":5,"f":{"bold":true,"link":"https://…"}}]}` | |
  Dates/times are numbers (serial date, 1899-12-30 epoch) + a date number format. Text that
  looks like a number but was forced as text (leading `'`) is stored as `s:`.
- **Reference tokens** inside stored formulas: `⟦` + `;`-separated fields + `⟧` where fields are
  `S:<sheetId>` (omitted for same sheet), `R:<rowId>`, `C:<colId>`, `$R`, `$C` (absolute flags).
  UUIDs are written in a 22-char base-62 form. Whole column = only `C:`, whole row = only `R:`.
  Range = `token:token`. Named ranges and functions stay textual.
  `FormulaCodec.toStored(a1Formula, context)` and `.toA1(storedFormula, context)` (in
  `wonky_sheets_core`) convert. A **single-cell** reference whose row/column no longer exists
  renders and evaluates as `#REF!`; a deleted **range endpoint** shrinks the range instead
  (delete commands rewrite endpoints; range tokens also carry `K:`/`KC:` sortKey hints so
  concurrent offline deletes resolve identically on every replica). Full grammar, unbound `X:`
  tokens and rewrite rules: [05-formula-engine.md](05-formula-engine.md).
- **GridRange JSON**: `{"s":"<sheetId>","r1":"<rowId>","r2":"<rowId>","c1":"<colId>","c2":"<colId>"}`
  with any bound optional (unbounded). Resolved to index ranges by the current ordering.

## 3. Synced tables

All tables get the injected `id: UuidValue` and `spaceId`. Non-nullable FKs are `deferred`.
Field lists below omit `id`/`spaceId`. Every model has `createdAt: DateTime` unless noted.

### 3.1 Spreadsheet & sheets

```yaml
class: Spreadsheet                       # id == space UUID
table: spreadsheet
database: sync
fields:
  title: String                          # mirrored to DriveItem.name by the server
  locale: String                         # e.g. en_US, de_DE — number/date parsing & formatting, function arg separator
  timeZone: String                       # IANA
  recalcMode: RecalcMode                 # onChange, onChangeAndEveryMinute, onChangeAndEveryHour
  iterativeCalc: bool
  maxIterations: int                     # default 50
  convergenceThreshold: double           # default 0.05
  defaultFontFamily: String              # theme default (Arial-like default: "Inter")
  defaultFontSize: double                # 10
  themeJson: String                      # {fonts, accent1-6, link, text, background}
  createdBy: UuidValue                   # user UUID (cross-boundary plain UUID)
  createdAt: DateTime

class: Sheet
table: sheet
database: sync
fields:
  spreadsheet: Spreadsheet?, relation(name=spreadsheet_sheets, onDelete=Cascade)
  name: String
  sortKey: String
  kind: SheetKind                        # grid, chart (object sheet holding one chart)
  hidden: bool
  tabColor: String?
  rightToLeft: bool
  showGridlines: bool
  frozenRows: int                        # count from top in current order
  frozenColumns: int
  defaultRowHeight: double               # px at 100% zoom (21)
  defaultColumnWidth: double             # 100
  formatJson: String?                    # sheet-level default format (rarely used)
indexes:
  sheet_order_idx: { fields: spreadsheetId, sortKey }
```

Sheet name uniqueness is **not** a DB constraint (engine would rewrite losers with conflict
markers); instead the client prevents duplicates and, if a merge produces duplicates, the UI
shows both with a warning badge and formula references use sheet **ids** so nothing breaks;
the later-created sheet is auto-renamed by the first client that notices (`"Sheet1 (2)"`,
idempotent deterministic rename rule: append ` (2)` to the one with the larger id).

### 3.2 Rows and columns

```yaml
class: SheetRow
table: sheet_row
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_rows, onDelete=Cascade)
  sortKey: String
  height: double?                        # null = default/auto-fit
  hidden: bool                           # user-hidden (filter-hidden is computed, not stored)
  formatJson: String?                    # row default format (applies to empty cells in row)
indexes:
  sheet_row_order_idx: { fields: sheetId, sortKey }

class: SheetColumn
table: sheet_column
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_columns, onDelete=Cascade)
  sortKey: String
  width: double?
  hidden: bool
  formatJson: String?                    # column default format
indexes:
  sheet_column_order_idx: { fields: sheetId, sortKey }
```

A new sheet creates 1,000 rows × 26 columns (entities only; no cells). "Add 1000 more rows" at
the bottom of the grid creates more. The **grid size** counts toward the cell limit
(rows × columns), like Google Sheets.

### 3.3 Cells

```yaml
class: Cell
table: cell
database: sync
fields:
  id: UuidValue, defaultModel=random_v7   # always overwritten with SheetsIds.cellId(...) before insert
  sheet: Sheet?, relation(name=sheet_cells, onDelete=Cascade)
  row: SheetRow?, relation(name=row_cells, onDelete=Cascade)
  column: SheetColumn?, relation(name=column_cells, onDelete=Cascade)
  content: String?                       # §2 encoding; null = no value
  note: String?                          # cell note (not a comment)
  # ---- format (each independently merged; null = inherit row/column/sheet default) ----
  numberFormat: String?                  # pattern, e.g. "#,##0.00", "yyyy-mm-dd", "[$€]#,##0", or preset id
  fontFamily: String?
  fontSize: double?
  bold: bool?
  italic: bool?
  underline: bool?
  strikethrough: bool?
  textColor: String?                     # "#RRGGBB" or "theme:accent3"
  fillColor: String?
  hAlign: HorizontalAlign?               # left, center, right (null = general: numbers right, text left)
  vAlign: VerticalAlign?                 # top, middle, bottom
  wrap: WrapStrategy?                    # overflow, wrap, clip
  rotation: int?                         # -90..90 degrees; 255 = vertical stacked
  borderTop: String?                     # "<style>|<color>" style ∈ thin, medium, thick, dashed, dotted, double; "none"
  borderRight: String?
  borderBottom: String?
  borderLeft: String?
  linkUrl: String?                       # whole-cell hyperlink (runs use r: content)
indexes:
  cell_row_idx: { fields: sheetId, rowId }
  cell_col_idx: { fields: sheetId, columnId }
```

- A cell row exists iff at least one field is non-null; clearing all fields deletes it
  (tombstone; re-creating revives the same deterministic id).
- Effective format = cell ▸ row ▸ column ▸ sheet ▸ spreadsheet theme defaults (per attribute).
- Border conflicts between adjacent cells (A1.bottom vs A2.top): render the heavier style; if
  equal, the top/left cell wins.
- Concurrency semantics (documented to users in help): last writer wins **per cell value** and
  **per format attribute**; deleting a row/column wins over concurrent edits to its cells.

### 3.4 Structure & ranges

```yaml
class: MergedRange
table: merged_range
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_merges, onDelete=Cascade)
  rangeJson: String                       # GridRange with all four bounds

class: DimensionGroup                      # row/column grouping (outline)
table: dimension_group
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_groups, onDelete=Cascade)
  dimension: Dimension                     # rows, columns
  startId: UuidValue
  endId: UuidValue
  depth: int                               # 1..8
  collapsed: bool

class: NamedRange
table: named_range
database: sync
fields:
  spreadsheet: Spreadsheet?, relation(name=spreadsheet_named_ranges, onDelete=Cascade)
  name: String                             # validated: letters, digits, _, not A1-like, case-insensitive unique (client-enforced)
  rangeJson: String?                       # GridRange, or null when `formula` used
  formula: String?                         # named formula / LAMBDA (stored-ref form)
  comment: String?

class: ProtectedRange
table: protected_range
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_protections, onDelete=Cascade)
  rangeJson: String?                       # null = whole sheet
  exceptRangesJson: String?                # for sheet protection: unprotected ranges
  description: String?
  warningOnly: bool
  editorsJson: String                      # list of user UUIDs allowed to edit (owner always)
  createdBy: UuidValue
```

### 3.5 Rules, filters, objects

```yaml
class: ConditionalFormatRule
table: conditional_format_rule
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_cf_rules, onDelete=Cascade)
  sortKey: String                           # priority (first = highest)
  rangesJson: String                        # list of GridRange
  ruleJson: String                          # {type: boolean|colorScale, condition, format | gradient}
  enabled: bool

class: DataValidationRule
table: data_validation_rule
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_dv_rules, onDelete=Cascade)
  rangesJson: String
  criteriaJson: String                      # type + values (see data tools spec)
  strict: bool                              # reject invalid input vs. show warning
  showDropdown: bool                        # for list types: chip/arrow/plain
  displayStyle: String?                     # chip, arrow, plainText
  helpText: String?

class: BasicFilter                          # id = SheetsIds.basicFilterId(sheetId): max one per sheet
table: basic_filter
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_basic_filter, onDelete=Cascade)
  rangeJson: String
  criteriaJson: String                      # {colId: criteria}
  sortJson: String?                         # [{colId, ascending}]

class: FilterView
table: filter_view
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_filter_views, onDelete=Cascade)
  name: String
  rangeJson: String
  criteriaJson: String
  sortJson: String?
  createdBy: UuidValue

class: Banding                              # alternating colors
table: banding
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_bandings, onDelete=Cascade)
  rangeJson: String
  styleJson: String                         # header, first band, second band, footer colors

class: EmbeddedObject                       # charts, images, drawings (images only in v1), slicers
table: embedded_object
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_objects, onDelete=Cascade)
  kind: EmbeddedObjectKind                  # chart, image, slicer
  anchorJson: String                        # {rowId, colId, dx, dy, width, height} or {"ownSheet":true}
  specJson: String                          # chart spec / slicer spec / image {fileUuid, alt, fit}
  zIndex: int
  title: String?
  altText: String?

class: PivotTable
table: pivot_table
database: sync
fields:
  sheet: Sheet?, relation(name=sheet_pivots, onDelete=Cascade)   # sheet that displays the pivot
  anchorRowId: UuidValue
  anchorColId: UuidValue
  sourceRangeJson: String
  specJson: String                          # rows, columns, values, filters, options
```

Pivot output cells are **computed locally** (like formulas) and rendered as a read-only overlay
anchored at (anchorRowId, anchorColId); they are not stored as `Cell` rows (avoids write storms
and conflicts). Same for array-formula spill results.

### 3.6 Scripts

```yaml
class: ScriptProject                        # one per spreadsheet (bound script), created on first use
table: script_project
database: sync
fields:
  spreadsheet: Spreadsheet?, relation(name=spreadsheet_script, onDelete=Cascade)
  name: String
  settingsJson: String                      # time zone, runtime options

class: ScriptFile
table: script_file
database: sync
fields:
  project: ScriptProject?, relation(name=project_files, onDelete=Cascade)
  name: String                              # e.g. "main.dart"
  sortKey: String
  source: String                            # whole-file LWW (editor warns on concurrent edit)
  updatedBy: UuidValue
  updatedAt: DateTime

class: ScriptBuild                          # written by the server (id = SheetsIds.scriptBuildId)
table: script_build
database: sync
fields:
  project: ScriptProject?, relation(name=project_build, onDelete=Cascade)
  sourceHash: String
  bytecodeFileUuid: UuidValue?              # EVC bytecode in cloud storage (null if errors)
  diagnosticsJson: String
  exportsJson: String                       # functions, custom functions (with JSDoc-like metadata), macros
  builtAt: DateTime

class: ScriptTrigger
table: script_trigger
database: sync
fields:
  project: ScriptProject?, relation(name=project_triggers, onDelete=Cascade)
  kind: TriggerKind                         # onOpen, onEdit, onChange, onSelectionChange, timeDriven
  functionName: String
  scheduleJson: String?                     # for timeDriven
  runAsUserId: UuidValue                    # installer; must keep edit access
  enabled: bool

class: Macro
table: macro
database: sync
fields:
  project: ScriptProject?, relation(name=project_macros, onDelete=Cascade)
  name: String
  functionName: String
  shortcutSlot: int?                        # 1..10 → Mod+Alt+Shift+<n>

class: ScriptProperty
table: script_property
database: sync
fields:
  project: ScriptProject?, relation(name=project_properties, onDelete=Cascade)
  key: String
  value: String
```

Execution logs and quotas are server-side Postgres tables (see scripting spec).

### 3.7 Change log

```yaml
class: ChangeLog
table: change_log
database: sync
fields:
  spreadsheet: Spreadsheet?, relation(name=spreadsheet_changes, onDelete=Cascade)
  userId: UuidValue
  actorKind: ActorKind                       # user, mcp, ai, script
  sessionId: String
  label: String                              # undo label ("Paste", "Insert 3 rows")
  summaryJson: String                        # {sheets:[id], ranges:[GridRange], kinds:[values, format, structure, …]}
  detailJson: String?                        # before/after content for ≤ 200 cells (cell history, revert); null if larger
  at: DateTime
indexes:
  change_log_at_idx: { fields: spreadsheetId, at }
```

- Written in the same transaction as the change (same space).
- Server consumption (after `onMergeSuccess`): activity events, `onEdit`/`onChange` installable
  triggers, notification rules, `DriveItem.modifiedAt`, search-text refresh, cell edit history.
- Pruned by the server after 30 days (keeps the latest per cell for history up to 100 entries —
  stored server-side in `CellHistory` Postgres table before pruning).

## 4. Local-only client tables (`database: client`, not synced)

| Table | Purpose |
|-------|---------|
| `ReservedSpace` | Pool of reserved space UUIDs for offline creation (toptap pattern). |
| `SheetsDirtySpace` | Spaces with local writes since the last complete sync (pending-change guard, suite 12 §2.3). |
| `SheetsRowJournal` / `SheetsJournalSpace` | Local change journal of the open spreadsheets (suite 12 §4 U11): trigger-fed `(space, table, row)` entries with a monotonic id. |
| `ComputedValueCache` | `(cellId, valueJson, formattedText?, engineVersion)` for fast reopen of large sheets; invalidated per engine version. **Deferred:** measured reopen cost is model build and formula compilation, not evaluation (150k formulas: model 2.1 s, first window 1.2 s, the visible window's values a few ms; viewport-first loading spreads the compile over the streamed chunks). It would still help formulas over rows that are streaming in (they show partial values meanwhile). |
| `LocalUndoStack` | Serialized undo/redo stacks per spreadsheet (best effort). |
| `LocalViewState` | Per spreadsheet: active sheet, selection, scroll, zoom, panel states, temporary filter views. **As built:** not a table but small JSON in the user's local key-value store (`sheets.view.<spreadsheetId>`, newest 200 kept, like the shell's per-user data, suite 12 §3); also the viewport hint of viewport-first loading and the "last opened" order of the IndexedDB cell cap. |
| ~~`PendingDriveRegistration`~~ | Not a table: offline registrations use the shell's `PendingDriveOp` queue (`registerSpreadsheet`, suite 12 §3). |

## 5. Server-only tables (Postgres, `database: server`)

`SpaceSubscription` (see suite offline spec), `SpaceReservation`, `CellHistory`
(`spreadsheetUuid, sheetId, rowId, colId, userId, at, before, after`), `ScriptExecution`
(logs), `ScriptQuotaUsage`, `SheetsSnapshotIndex` (versions are in `ItemVersion`).

## 6. In-memory model (`wonky_sheets_core/lib/src/model/`, pure Dart, exported by `lib/model.dart`)

The SQLite replica is the persistence layer; the UI and formula engine work on an in-memory
`WorkbookModel` built from it. It lives in **pure Dart** (`wonky_sheets_core`) because the
server needs the same model for headless MCP tools, version snapshots/diffs, exports and
scripts; the Flutter app adds viewport/painter adapters and the DB-backed loaders
(`wonky_sheets/lib/features/model/`). Mutations are planned by a shared
`SheetsMutationPlanner` (core) and persisted by `SheetsWriter` (client) or the server writer
(see [12-mcp-and-ai.md](12-mcp-and-ai.md)):

- `AxisIndex` per sheet and dimension: ordered list of row/col ids (sorted by `sortKey`, then
  `id`) with an id→index hash map and a Fenwick tree of sizes (heights/widths, hidden = 0) for
  O(log n) pixel ↔ index lookups.
- `CellStore` per sheet: sparse columnar map `rowIndex → colIndex → CellRecord` (content,
  format attribute bitset + value table) loaded at open (viewport-first, then background
  streaming). **As built** (`SyncedWorkbookSession`): every table but `cell` loads first, then
  the cells of the active sheet's frozen rows and 200 rows from the restored top row
  (`ViewportHint`: `LocalViewState` or `?gid=`) → `WorkbookReady`; spreadsheets of ≤ 2,000
  rows load completely first. The rest streams in blocks of 500 rows (cells read through the
  `(sheetId, rowId)` index, applied ≤ 5,000 per frame, announced on `remoteBatches`), the
  active sheet first and rows the grid shows first (`WorkbookRowLoading.prioritize`). Streamed
  rows never overwrite cells written locally or patched from the journal meanwhile; writes
  that would touch rows still loading — or read whole ranges (sort, find and replace, shift,
  duplicate sheet) over them — are refused (`LoadingGate`, "Still loading this part of the
  sheet…").
- `RuleIndex`: interval trees for CF, DV, merges, protected ranges, filters, banding.
- **Generic ingestion**: the model holds plain Dart records (`records.dart`), independent of the
  generated Serverpod classes; it ingests `RowChange`s (`table`, `rowId`, column-name maps; UUIDs as
  strings, enums by name) so the app, the server and snapshots share one path
  (`WorkbookModel.applyChanges`). `ModelWorkbookView` adapts it to the formula engine's
  `WorkbookView` and `ModelEngineBinding` forwards change batches to the engine.
- **Change ingestion**:
  - Local writes update the model synchronously (optimistic) and the DB asynchronously.
  - Remote writes: after each `onMergeSuccess(spaceUuid, hlc)` the session reads the rows the
    local change journal recorded for the space since its cursor (upstream requirement **U11**,
    implemented app-side with SQLite triggers — suite 12 §4), re-reads them (visible → upsert,
    gone → delete), overlays local writes still queued for the writer, and patches the model
    (`RemotePatch`); the patch is emitted on `WorkbookSession.remoteBatches`. Rows equal to the
    model (the echo of the device's own writes) produce no change. After an error the session
    falls back to a full diff of the space against the model. A property test checks that the
    incremental patch equals a full reload.
- Formula engine (`wonky_sheets_core`) consumes the model through a `CellSource` interface; see
  formula spec for the dependency graph and recalculation.

## 7. Writes and undo (`sheets.rows` undo domain)

All mutations go through `SheetsWriter` (repository), which:
1. Opens `transactionForUser(userUuid, spaceId: spreadsheetId)`.
2. For each touched row: reads current values of the columns it will change, writes with
   `columnValues` naming only those columns (or inserts/deletes), and records
   `RowChange {table, rowId, op, columnsBefore, columnsAfter}`.
3. Inserts the `ChangeLog` row.
4. Commits; pushes an `UndoStep` (domain `sheets.rows`) with the recorded changes.

Undo replays inverses with the same naming discipline; a column whose current value differs from
`columnsAfter` (someone else changed it since) is skipped (see suite undo spec §3.3). Deleted
rows are restored by re-inserting the same id (engine revives the tombstone), so references and
deterministic ids stay valid.

Bulk operations (paste 100k cells, import, sort) are chunked into transactions of ≤ 5,000 row
changes while remaining **one undo step** (the step holds the list of chunks); the UI shows
progress for operations > 20k cells.

## 8. Invariants & maintenance (client-side, idempotent)

Run after merges (debounced) by the first client that detects them; all are deterministic so
concurrent fixes converge:
- Sheet name duplicates → rename rule (§3.1).
- `frozenRows/Columns` > visible counts → clamp.
- Merges overlapping → keep the one with the smaller id, delete others.
- Basic filter / pivot anchors pointing at deleted rows → delete rule / move anchor to nearest
  surviving row.
- Cells whose row or column is missing (FK repair already hides them) → ignored.

## 9. Additions defined in feature specs

Feature specs add fields and tables next to the features that need them. They are part of this
data model and **must be applied together with it** (synced-schema changes are lock-step, so
batch them into the M3/M5/M6 sync schema releases):

| Spec | Section | Highlights |
|------|---------|------------|
| [03 · Grid & editing](03-grid-and-editing.md) | §20 | Grid/view-state keys, commit-hint `sessionId` |
| [04 · Screens, menus & toolbar](04-screens-menus-toolbar.md) | §15 | `Spreadsheet.displayLanguage`, `LocalViewState` keys, `sheetsDefaults` keys |
| [05 · Formula engine](05-formula-engine.md) | §24 (F1–F8) | Reference token `K:`/`KC:`/`X:` fields, GridRange key fields, engine caches |
| [06 · Formatting](06-formatting.md) | §19 | `themeJson`/banding `styleJson` schemas, `preset:*` number formats, CF `dataBar`/`iconSet`/`stopIfTrue`, smart-chip runs |
| [07 · Data tools](07-data-tools.md) | §22 (D1–D10) | Filter/DV/pivot/named-function JSON schemas, protection details |
| [08 · Charts & objects](08-charts-and-objects.md) | §20 | `ChartSpec` schema, object anchor fields |
| [09 · Scripting](09-scripting.md) | §19 | `ScriptBuild.lastGood*` fields, `ScriptUserProperty` (personal space), `ScriptExecution` (server) |
| [10 · Collaboration & history](10-collaboration-history.md) | §14 (A-10-x) | `ChangeLog.summaryJson` deletions, version state tables, `PendingCommentOp`, `LocalConflict`, `sheets.serverChange` undo domain |
| [11 · Import, export & print](11-import-export-print.md) | §10 | `Sheet.printSettingsJson` |
| [12 · MCP & AI](12-mcp-and-ai.md) | §8 (A-12-x) | Model in `wonky_sheets_core`, `SheetsMutationPlanner`, `ServerChangeRecord`, `AiFunctionCache` |

Known LWW granularity limits (documented, accepted): row/column/sheet default `formatJson`,
`BasicFilter.criteriaJson`, chart `specJson` and `ScriptFile.source` merge as whole values.
