# Sheets 11 · Import, Export and Print

This spec covers getting data into and out of Wonky Sheets: **import** of CSV/TSV, XLSX, XLS
and ODS (dialog, pipeline, mappings, limits), **export** to XLSX, ODS, CSV/TSV, PDF, HTML and
JSON, and **print/PDF** (print settings route, live preview, pagination, cell rendering,
headers and footers, page breaks).

Read first: [02-data-model.md](02-data-model.md) (content encoding, ids, `SheetsWriter`, cell
limits), suite [05-drive-and-files.md](../05-drive-and-files.md) (`DriveEndpoint.import`,
upload dialogs), suite [12-offline-and-sync.md](../12-offline-and-sync.md) §5 (cell
limits), [05-formula-engine.md](05-formula-engine.md) (function catalog, A1 codec),
[06-formatting.md](06-formatting.md) (number formats, borders, fonts),
[07-data-tools.md](07-data-tools.md) (DV, CF, filters, pivots),
[08-charts-and-objects.md](08-charts-and-objects.md) (charts, images, renderers).

Priorities: P0 = first complete release, P1 = v1 if possible, P2 = later.

| Format | Import | Export |
|--------|--------|--------|
| CSV / TSV | P0 | P0 |
| XLSX | P0 (values, formulas, formats, structure) / P1 (DV, CF, images, charts) | P0 (values, formulas, formats, structure) / P1 (DV, CF, images, charts) |
| PDF | — | P0 (via print pipeline) |
| ODS | P1 | P1 |
| XLS (BIFF8, legacy) | P2 (read-only; not supported by the in-house OOXML reader — users convert to .xlsx) | — (never) |
| HTML (zipped) | — | P1 |
| JSON (developer) | P2 | P2 |

---

## 1. Architecture

All format code is **pure Dart** in `wonky_sheets_core/lib/io/`, so the same code runs in the
Flutter app (offline, small files, current state) and on the server (large imports,
`drive.export`, MCP, version downloads).

```
wonky_sheets_core/lib/io/
  ir/               WorkbookDocument IR (format-neutral), validation, statistics
  formula/          ExcelFormulaTranslator (Wonky A1 ⇄ Excel A1, shared/array formulas),
                    OpenFormulaTranslator (ODS of:= ⇄ A1)
  numfmt/           Excel built-in format ids ⇄ patterns, locale tag stripping
  color/            theme/indexed/tint color resolution
  csv/              CsvImporter (streaming), CsvExporter, encoding + delimiter detection
  xlsx/             XlsxImporter, XlsxExporter (own OOXML reader/writer on archive + xml)
  ods/              OdsImporter, OdsExporter (archive + xml)
  html/             HtmlExporter
  json/             JsonExporter/Importer (P2)
  print/            PrintSettings model, Paginator, SheetsPdfRenderer (pdf package)
  write/            IrToRowsPlanner: IR → synced row operations (ids, sort keys, stored formulas)
  read/             ModelToIr: WorkbookModel (live, snapshot or headless) → IR
```

### 1.1 Intermediate representation (`WorkbookDocument`)

```dart
class WorkbookDocument {
  String? title; String? locale; String? timeZone;
  bool date1904;                                // XLSX epoch flag (converted to serials on our epoch)
  WorkbookTheme? theme;                         // fonts, accent1–6
  List<IrSheet> sheets;
  List<IrNamedRange> namedRanges;
  List<ImportWarning> warnings;                 // accumulated during import
}
class IrSheet {
  String name; bool hidden; String? tabColor; bool rtl; bool showGridlines;
  int frozenRows, frozenColumns;
  double? defaultRowHeight, defaultColumnWidth;
  SparseAxis<IrDim> rows, columns;              // size, hidden, outline level, default format
  SparseGrid<IrCell> cells;                     // row-major sparse grid
  List<IrRange> merges;
  List<IrDataValidation> validations;
  List<IrConditionalFormat> conditionalFormats;
  IrFilter? autoFilter;
  List<IrImage> images; List<IrChart> charts;
  IrPrintSettings? print;
}
class IrCell {
  IrValue? value;          // number | text | bool | error | richText ; dates are numbers
  String? formulaA1;       // Wonky A1 syntax (already translated), without leading '='
  IrFormulaKind formulaKind; // normal | array (CSE) | dynamicArray
  IrRange? arrayRef;       // for array formulas
  IrFormat? format;        // numberFormat, font, fill, borders, alignment, wrap, rotation
  String? note; String? link;
}
```

The IR is memory-efficient for large files: `SparseGrid` stores rows as chunked arrays and
formats as indices into a deduplicated `IrFormat` table (like XLSX `cellXfs`).

### 1.2 IR → spreadsheet rows (`IrToRowsPlanner`)
Produces the row operations for a target location (§2.2). It is used by the client
(`SheetsWriter`) and the server (`ServerSheetsWriter`):
- Creates `Sheet`, `SheetRow`, `SheetColumn` entities with ids (UUIDv7) and evenly spaced
  `sortKey`s (`FractionalIndex.nBetween`), sized to `max(used + 1, 1000)` rows and
  `max(used, 26)` columns (Google Sheets: imports keep the file's grid but at least the default).
- Cells: deterministic ids `SheetsIds.cellId`; `content` encoded per
  [02-data-model.md](02-data-model.md) §2; formulas converted A1 → stored form with
  `FormulaCodec.toStored` **after** all rows/columns/sheets exist in the plan (two passes: entities,
  then cells and rules).
- Format attributes: only non-default attributes are written; formats identical across a whole
  column are written as `SheetColumn.formatJson` (column default) instead of per cell when
  ≥ 90 % of the column's used cells share them (reduces rows).
- Rules (merges, DV, CF, filter, named ranges, objects) with `GridRange` id JSON.
- Emits operations in chunks of ≤ 5,000 row changes.

### 1.3 Model → IR (`ModelToIr`)
Reads any `WorkbookModel` implementation (client live model, read-only snapshot model of a
version, server `HeadlessWorkbook`) including **computed values** from the formula engine
(exports write cached results). Pivot tables and array-formula spills are exported as their
computed cells.

---

## 2. Import UX

### 2.1 Entry points
- *File › Import…* (`sheets.file.import`): dialog with tabs **Upload** (drop zone + *Browse*),
  **Recent uploads** (P2), **Drive** (P2: import a file stored in Drive).
- Dropping a file onto the grid opens the import dialog preselected to "Insert new sheet(s)".
- Drive: *New › Upload file* and dropping `.csv/.tsv/.xlsx/.xls/.ods` on the drive list
  (suite 05) → "Create new spreadsheet" without the options dialog (defaults), progress toast.
- Paste of large tab-separated clipboard text is handled by paste, not import
  ([03-grid-and-editing.md](03-grid-and-editing.md)).

### 2.2 Import options dialog

```
┌ Import file ─────────────────────────────────────────────── ✕ ┐
│ File: orders-2026.csv (4.2 MB · ~180,000 cells)               │
│ Import location                                               │
│  ○ Create new spreadsheet                                     │
│  ● Insert new sheet(s)                                        │
│  ○ Replace spreadsheet                                        │
│  ○ Replace current sheet                                      │
│  ○ Append to current sheet                                    │
│  ○ Replace data at selected cell (B4)                         │
│ Separator type   [ Detect automatically ▾ ]  (custom: [ ; ]) │  CSV/TSV/TXT only
│ Encoding         [ Detect automatically (UTF-8) ▾ ]          │  CSV/TSV/TXT only
│ Locale for numbers & dates  [ Spreadsheet (de_DE) ▾ ]        │  CSV only
│ ☑ Convert text to numbers, dates, and formulas                │
│ Sheets to import  ☑ Orders  ☑ Customers  ☐ Hidden calc       │  XLSX/ODS only
│ Unsupported formulas [ Keep last calculated value ▾ ]        │  XLSX/ODS only
│ ┌ Preview (first 20 rows) ────────────────────────────────┐   │
│ │  A        B           C        D                         │   │
│ │  Order    Date        Amount   Region                    │   │
│ │  1001     2026-01-02  12.50    North                     │   │
│ └──────────────────────────────────────────────────────────┘   │
│                                       [ Cancel ] [ Import data ]│
└───────────────────────────────────────────────────────────────┘
```

| Location | CSV/TSV | XLSX/XLS/ODS | Behavior |
|----------|---------|--------------|----------|
| Create new spreadsheet | ✓ | ✓ | New Drive item named after the file (without extension) in the current folder (or My Drive). |
| Insert new sheet(s) | ✓ | ✓ | Adds sheets after the active sheet. Name conflicts get " (2)". |
| Replace spreadsheet | ✓ | ✓ | Deletes all sheets (and their rules/objects), then inserts the imported sheets. Keeps title, sharing, comments (orphaned if anchors vanish), scripts. Confirmation required. |
| Replace current sheet | ✓ | — | Clears the active sheet (contents, formats, rules, objects, rows/cols beyond the default) and writes the data from A1. |
| Append to current sheet | ✓ | — | Writes after the last row with content (`lastRow + 1`, column A). |
| Replace data at selected cell | ✓ | — | Writes starting at the active cell, overwriting; grows the grid as needed. |

- The dialog is a `WonkyDialogSpec` form (MCP-operable).
- The preview updates on option changes (re-parses the first 64 KB, debounced 150 ms).
- **Convert text to numbers, dates, and formulas** (default on): each field is parsed with the
  same `CellInputParser` as typing in a cell ([03-grid-and-editing.md](03-grid-and-editing.md)),
  using the chosen locale. Off: every field becomes text (`s:`). For XLSX/ODS the checkbox is
  hidden (types come from the file).
- **Unsupported formulas** (XLSX/ODS): *Keep last calculated value* (default: the cell gets the
  cached value from the file, plus a note "Imported value — original formula used unsupported
  function FOO: =FOO(A1)") or *Keep formula as text* (the cell content is the formula text as
  `s:` with the same note). Either way the import report lists them.

### 2.3 Import report
After import, a toast "Imported 3 sheets, 182,113 cells — 4 warnings · View" opens the **Import
summary** dialog: counts per sheet, and a warnings table (severity, sheet, cell/range,
message), e.g. "12 cells used unsupported function CUBEVALUE", "Pattern fill approximated as
solid color (230 cells)", "VBA macros were not imported", "Pivot table on 'Summary' imported as
values". *Copy report* copies the table as TSV. The report is also stored as a `StoredFile`
JSON referenced from the `ActivityEvent` (`exported`/`created` summary) so it can be reopened
from the activity feed (P2).

### 2.4 Undo
- Imports into an existing spreadsheet are **one undo step** ("Import orders.csv"). Client-side:
  normal `SheetsWriter` bulk step (chunked). Server-side: `sheets.serverChange` undo entry
  with the import's `changeId` ([10-collaboration-history.md](10-collaboration-history.md) A-10-5).
- *Create new spreadsheet* is not undoable (Drive: move to trash).

---

## 3. Import pipeline

### 3.1 Client vs server

| Condition | Where |
|-----------|-------|
| CSV/TSV ≤ 20 MB and ≤ 300k estimated cells | client |
| XLSX/ODS ≤ 5 MB and ≤ 200k estimated cells | client |
| Offline (any size up to the cell limit) | client (with a warning above the thresholds: "Large import on this device may take a while") |
| Otherwise | server |
| XLS (legacy) | client if ≤ 5 MB, else server |

Estimated cells: CSV = sampled average fields/line × (file size / average line length); XLSX =
sum of `<dimension ref>` areas (or sheet XML sizes ÷ 40 bytes when missing).

### 3.2 Client import
Runs in a background isolate (desktop) or as chunked work on the main isolate with
`scheduleTask` yielding every 8 ms (web; XLSX decoding is synchronous on web). Steps:
parse → IR → `IrToRowsPlanner` → `SheetsWriter` chunks → model ingest. Progress dialog with
Cancel (cancelling rolls back already written chunks via the undo step's inverse).

### 3.3 Server import

```
client                                   server
  │ upload (StoredFile upload description) │
  │──────────────────────────────────────►│
  │ DriveEndpoint.import(uploadId, kind=spreadsheet, options)   (create new)
  │ SheetsEndpoint.importInto(spreadsheetUuid, uploadId, options) (into existing)
  │──────────────────────────────────────►│ create SheetsImportJob (queued) → returns jobId
  │ SheetsEndpoint.watchImport(jobId) ◄──── Stream<ImportProgress{phase, done, total, warnings}>
  │                                        │ worker isolate: parse → IR → planner
  │                                        │ new spreadsheet: spaces.createFor(user), Spreadsheet row,
  │                                        │   DriveItem (registerSpreadsheet), SpaceSubscription(open)
  │                                        │ ServerSheetsWriter: transactionForUser(user, space) per chunk
  │                                        │   + ChangeLog(label "Import <file>") + ServerChangeRecord
  │◄── done {itemUuid, changeId, report}   │
  │ (new) navigate to /s/<uuid>; sync downloads rows (progress UI from suite 12 §2.3)
```

- Jobs run on script/background workers (the same `ScriptJob`-style lease mechanism; table
  `SheetsImportJob`, Additions A-11-2), one job per user at a time (others queued).
- Phases: `uploading` (client), `parsing`, `writing` (done/total cells), `finalizing`
  (registration, search text, thumbnail), `done` / `failed`.
- Cancel: `SheetsEndpoint.cancelImport(jobId)`; already written chunks are reverted with the
  stored inverse; for a new spreadsheet the item is deleted.
- MCP `drive.import` and `sheets.import_csv` use the same pipeline synchronously (wait ≤ 120 s,
  then return `job_id` for polling).

### 3.4 Cell-limit enforcement
Before writing, compute the resulting grid size (rows × columns per sheet, summed) and compare
with `sheets.maxCellsPerSpreadsheet` (1M at M3). If exceeded: the dialog shows "This import
would make the spreadsheet 1.4 million cells; the limit is 1 million." with options *Import
selected sheets only* (sheet checklist), *Trim empty rows and columns* (P1, applied
automatically: trailing empty rows/columns are never imported), *Cancel*. The server enforces
the same limit and fails with `cell_limit_exceeded`.

---

## 4. CSV / TSV import

Library: **`csv` 8.0.0** (`Csv` class; `csv.decoder` is a `StreamTransformer` emitting rows;
configurable field delimiter, quote and escape characters; handles `\r`, `\n`, `\r\n`;
auto-detects `,` `;` `\t` `|` and `sep=` headers). Our wrapper adds encoding detection,
delimiter scoring, locale-aware conversion, limits and streaming into the planner.

### 4.1 Encoding detection (`EncodingSniffer`)
1. BOM: `EF BB BF` → UTF-8; `FF FE` → UTF-16LE; `FE FF` → UTF-16BE.
2. No BOM: if ≥ 10 % of the first 4 KB's odd (even) bytes are `00` → UTF-16LE (BE).
3. Strict UTF-8 decode of the first 64 KB (ignoring a truncated final sequence) succeeds →
   UTF-8.
4. Otherwise → Windows-1252 (superset of Latin-1 for printable range); the dialog shows the
   detected encoding so users can switch (UTF-8, UTF-16LE/BE, Windows-1252, ISO-8859-1,
   ISO-8859-15, Mac Roman; P2: Shift_JIS, GB18030, EUC-KR via `charset` package).
Decoding is streamed (`Utf8Decoder` / a custom single-byte table decoder / UTF-16 decoder).

### 4.2 Delimiter detection
If the file starts with `sep=<c>`, use it. Otherwise score candidates `,` `;` `\t` `|` on the
first 50 records (quote-aware): score = (number of records with the modal field count ≥ 2) ×
modal count − variance penalty; ties prefer `\t` for `.tsv`, `,` otherwise; for `de_DE`-like
locales (decimal comma) ties prefer `;`. "Custom" allows any single character or string.

### 4.3 Parsing rules
- RFC 4180 quotes: `"` quoting, `""` escaped quote, embedded delimiters and newlines in quoted
  fields. Lenient: a quote inside an unquoted field is literal; an unterminated quote at EOF
  closes the field (warning "Unterminated quote at line 18,203").
- Ragged rows are allowed (shorter rows padded with empty cells).
- Max field length 50,000 characters (Google Sheets cell limit); longer fields are truncated
  with a warning.
- Leading/trailing whitespace is preserved in text; for conversion, numbers are trimmed first.
- Empty fields → no cell.
- Formula conversion only for fields beginning with `=` when *Convert…* is on. Formulas that
  use external-data functions (`IMPORTDATA`, `IMPORTRANGE`, `IMAGE` with http URLs,
  `HYPERLINK` is fine) are imported but **disabled** until the user clicks *Allow* in the
  import summary (P1; mitigates CSV formula injection), shown as `#BLOCKED!`.

### 4.4 Locale-aware conversion
The chosen locale drives decimal and grouping separators (`1.234,56` in `de_DE`), date order
(`03/04/2026` = 3 April in `en_GB`, March 4 in `en_US`), and boolean words (`TRUE`/`WAHR`).
ISO dates (`2026-04-03`, with optional time and `T`) are always recognized. Percentages
(`12%`) → 0.12 with a percent format; currency symbols of the locale → number + currency format.
Detected formats are applied per **column** when ≥ 95 % of the non-empty cells share it
(otherwise per cell), using `SheetColumn.formatJson`.

### 4.5 Streaming
The file is read as a byte stream (desktop: `File.openRead`; web: `Blob.slice` chunks of 1 MB;
server: storage stream), decoded and parsed incrementally; every 5,000 records the planner
emits a chunk. Memory stays O(chunk) except the column format statistics.

---

## 5. XLSX / XLS / ODS import

### 5.1 Library decision
**Decision (M3, implementation): our own OOXML reader and writer** in `io/xlsx/`, built on
`archive` (zip) and `xml`, behind the IR boundary — **no `excel_plus`**. Reasons found while
implementing: we need parts `excel_plus` does not expose reliably (shared/array/dynamic formulas,
data validations, conditional formatting with dxfs, print settings, outline groups, legacy
comments + VML, `date1904`), deterministic output for round-trip goldens, and full control of
streaming and memory at 1M cells. The reader parses `workbook.xml`, relationships,
`sharedStrings.xml` (rich runs), `styles.xml` (numFmts, fonts, fills, borders, cellXfs, dxfs),
`theme1.xml`, worksheets, comments and drawings; the writer emits ECMA-376-ordered parts
(`[Content_Types].xml`, rels, workbook, styles with deduplicated records and custom numFmt ids
≥ 164, sharedStrings, sheets, comments/VML, docProps) that Excel and LibreOffice open without
repair. Legacy `.xls` (BIFF8) import is P2 (not supported; the import dialog asks users to save
as `.xlsx`). ODS uses the same approach (`io/ods/`). If a gap appears later, vendoring a library
under `third_party/` remains possible without touching code outside `io/xlsx/`.

### 5.2 XLSX → Wonky mapping

| XLSX feature | Wonky | Prio | Notes |
|--------------|-------|------|-------|
| Cell values: number, shared/inline string, boolean, error | `n:` / `s:` / `b:` / `e:` | P0 | Rich text runs → `r:` JSON (bold, italic, underline, strike, color, font, size; links). |
| Dates (number + date format) | number + format | P0 | `date1904` → add 1462 days. Excel's fictitious 1900-02-29 (serial 60) → `#VALUE!` text warning. |
| Formulas (A1) | `=` stored form | P0 | Translated by `ExcelFormulaTranslator` (§5.3). Cached `<v>` used for the computed-value cache until first recalc. |
| Shared formulas | expanded per cell | P0 | Relative references offset per cell from the master formula. |
| Array formulas (CSE, `t="array"`) | array formula anchored at the top-left, spilling over `ref` | P0 | Stored as `=ARRAYFORMULA(...)`. |
| Dynamic arrays (Excel 365 spills) | spill formula | P1 | `_xlfn.`/`_xlws.` prefixes stripped; `ANCHORARRAY(x)` (`x#`) → range of the spill (P1). |
| Unsupported functions | value or text + note | P0 | Per dialog option (§2.2); report lists names and counts. |
| Number formats (built-in ids 0–49, custom) | `numberFormat` pattern | P0 | Built-in id table in `io/numfmt/`; `[$-409]` locale tags removed; `[$€-407]` currency tags kept as currency; `[Red]`, conditions `[<0]`, `@`, `?/?` kept (supported subset per [06-formatting.md](06-formatting.md); unsupported tokens → closest + warning). |
| Fonts (name, size, b/i/u/strike, color) | font attributes | P0 | Unknown font families kept by name (render with fallback); color theme+tint resolved to hex, or `theme:accentN` when tint = 0. |
| Fills | `fillColor` | P0 | Solid → color; pattern → foreground color (if pattern density ≥ 50 %) else background + warning; gradient → first stop + warning. |
| Borders | `borderTop/Right/Bottom/Left` | P0 | thin/hair → thin; medium → medium; thick → thick; dashed, mediumDashed, dashDot, dashDotDot, slantDashDot → dashed; dotted → dotted; double → double. Diagonal borders ignored (warning). |
| Alignment | `hAlign`, `vAlign`, `wrap`, `rotation` | P0 | general → null; fill/justify/distributed/centerContinuous → left/left/center/center (warning); `textRotation` 0–180 (91–180 = −1..−90) → −90..90; 255 → stacked; `shrinkToFit` ignored; indent → P2. |
| Merged cells | `MergedRange` | P0 | |
| Column widths | `SheetColumn.width` px | P0 | px = trunc(((256·w + trunc(128/MDW)) / 256) · MDW), MDW = 7 (Calibri 11 at 96 dpi). `defaultColWidth`/`baseColWidth` → `Sheet.defaultColumnWidth`. |
| Row heights | `SheetRow.height` px | P0 | px = pt × 4/3; `customHeight=0` rows → null (auto). |
| Hidden rows/columns | `hidden` | P0 | |
| Outline groups | `DimensionGroup` | P1 | From `outlineLevel` runs; `collapsed`. |
| Frozen panes | `frozenRows/Columns` | P0 | `pane state="frozen"` xSplit/ySplit; split (unfrozen) panes ignored. |
| Sheet visibility | `hidden` | P0 | `veryHidden` → hidden (warning). |
| Tab color, gridlines, RTL, zoom | `tabColor`, `showGridlines`, `rightToLeft` | P0 | Zoom → per-user view state (ignored). |
| Defined names | `NamedRange` | P0 | Workbook scope → name. Sheet scope → `<Sheet>_<Name>` if no conflict (warning). Names with formulas → `formula`. `_xlnm.*` built-ins → print settings / filter, not names. |
| Data validation | `DataValidationRule` | P1 | list (literal or range), whole, decimal, date, time, textLength, custom formula → our criteria ([07](07-data-tools.md)); `showDropDown` inverted semantics handled; error style stop → `strict`. |
| Conditional formatting | `ConditionalFormatRule` | P1 | cellIs, expression, containsText/notContains/beginsWith/endsWith, containsBlanks/notBlanks/errors, timePeriod, top10, aboveAverage, duplicate/unique, colorScale (2/3) → supported; dataBar, iconSet → P2 (skipped with warning). dxf styles → format. Priority order → `sortKey`. |
| AutoFilter | `BasicFilter` | P1 | Criteria: values lists, custom (simple), color filters → dropped (warning). |
| Tables (ListObjects) | P2: banding + filter + named range per table; structured refs → A1 | P2 | P0/P1: values only; structured references in formulas translated to A1 if the table part is readable, else unsupported. |
| Legacy notes (`comments*.xml`) | `Cell.note` | P0 | Author prefix "Author:\n" removed if it matches. |
| Threaded comments | Comment threads | P1 | Authors mapped by email to users with access; otherwise body prefixed "[Name]". Requires online (comments in Postgres); offline imports convert them to notes. |
| Hyperlinks | `linkUrl` / rich-text link | P0 | External → URL; internal `#Sheet2!A1` → `#gid=<sheetId>&range=A1` internal link format ([06](06-formatting.md)). |
| Images (drawing anchors) | `EmbeddedObject(kind=image)` | P1 | `twoCellAnchor`/`oneCellAnchor` from cell + EMU offsets (px = EMU / 9525); `absoluteAnchor` → A1 + offsets. EMF/WMF → skipped (warning). Images uploaded as `StoredFile` (server-side import) or queued uploads (client). |
| In-cell pictures (Excel 365 `IMAGE`, rich value images) | `=IMAGE()` / skipped | P2 | |
| Charts | `EmbeddedObject(kind=chart)` | P1 | Via the OOXML chart parts (`c:chartSpace`): bar/col (clustered/stacked/percent), line (smooth), area, pie, doughnut, scatter, bubble, radar, stock → candlestick; titles, legend position, axis titles/min/max/log/number format, series colors, data labels (basic), trendlines. Unmappable → skipped with warning. |
| Pivot tables | values only | P0 | Cells are already present in the sheet XML as cached values; definitions ignored (warning "imported as values"). |
| Sparklines (x14) | `=SPARKLINE()` | P2 | |
| Sheet/workbook protection | ignored | P0 | Info warning "Protection was not imported". |
| Print settings | `Sheet.printSettingsJson` | P1 | orientation, paper size, scale/fitToWidth/Height, margins (in → our units), gridlines/headings, print titles → `repeatRows/Cols`, `rowBreaks`/`colBreaks` → page breaks, header/footer codes `&P &N &D &T &F &A` → our tokens. |
| VBA (`.xlsm`), external links, data connections, slicers, form controls, OLE, SmartArt | ignored | — | Warning per kind; external link formulas keep cached values. |

### 5.3 Formula translation (`ExcelFormulaTranslator`)
Wonky's formula language follows Google Sheets syntax ([05-formula-engine.md](05-formula-engine.md)).
- **Import** (Excel → Wonky A1): strip `_xlfn.`, `_xlfn._xlws.`, `_xlpm.` (LAMBDA params);
  map renamed functions via a table (e.g. `CEILING.MATH` → `CEILING.MATH` (same), `NETWORKDAYS.INTL`
  same, `T.TEST` → `T.TEST`; Excel-only → unsupported list such as `CUBEVALUE`, `WEBSERVICE`,
  `FILTERXML`, `INFO`, `CELL("filename")` partial); `@` implicit intersection operator removed
  (warning if semantics might differ); sheet names with quotes kept; external references
  (`[1]Sheet!A1`) → unsupported; `#REF!` literals kept; R1C1 is not used in OOXML storage.
  Booleans `TRUE()` → `TRUE`.
- **Export** (Wonky → Excel A1): prefix functions introduced after Excel 2007 with `_xlfn.`
  (table generated from Excel's documentation list: `IFS`, `SWITCH`, `XLOOKUP`, `FILTER`,
  `SORT`, `UNIQUE`, `SEQUENCE`, `LET`, `LAMBDA`, `CONCAT`, `TEXTJOIN`, …); Google-only functions
  (`ARRAYFORMULA`, `QUERY`, `SPLIT`, `REGEXMATCH`, `GOOGLEFINANCE`, `IMPORTRANGE`,
  `SPARKLINE`, custom script functions…) are written as-is with the cached value (Excel shows
  `#NAME?` after recalculation) and listed in the export report; `ARRAYFORMULA(x)` at the spill
  anchor is written as a dynamic-array formula `x` (`cm="1"`) or a legacy array formula
  (option "Excel 2016 compatible", P2).
- Round-trip tests: every function in our catalog has an import/export expectation row in
  `io/formula/function_map.dart`.

### 5.4 XLS (legacy BIFF8) (P2)
Not read in v1 (no BIFF reader in the in-house OOXML code). The import dialog rejects `.xls`
with "Save the file as .xlsx and import it again". Export to `.xls` is never offered.

### 5.5 ODS import (P1)
Custom reader in `io/ods/` (`archive` + `xml` SAX over `content.xml`, `styles.xml`,
`settings.xml`, `meta.xml`):
- `table:table` → sheet (`table:display="false"` → hidden); `table:table-column`
  (`number-columns-repeated`, `table:style-name` → `style:column-width` in cm/in/pt → px,
  `table:visibility="collapse"` → hidden); `table:table-row` (`number-rows-repeated`, height,
  visibility); `table:table-cell` / `covered-table-cell` with
  `number-columns-repeated` (huge trailing repeats are capped at the used range),
  `office:value-type` (float, percentage, currency, date (ISO → serial), time (ISO duration →
  fraction), boolean, string), `office:value`, `text:p` (multiple paragraphs joined with `\n`;
  `text:span` styles → rich text; `text:a` → link), `table:formula="of:=SUM([.A1:.A3])"` →
  `OpenFormulaTranslator` (`[.A1]`, `[Sheet1.A1:.B2]`, `;` separators, `of:`/`msoxl:` prefixes),
  `number-columns-spanned`/`rows-spanned` → merges, `office:annotation` → note.
- Styles: `style:text-properties` (font name, size, weight, style, underline, color),
  `style:table-cell-properties` (background, borders `0.06pt solid #000`, wrap
  `fo:wrap-option`, vertical align, rotation), `style:paragraph-properties` (text-align);
  number styles (`number:number-style`, `date-style`, `percentage-style`, `currency-style`) →
  patterns.
- `settings.xml`: `HorizontalSplitMode=2`/`VerticalSplitMode=2` + positions → frozen panes;
  active sheet ignored.
- Named ranges (`table:named-range`, `named-expression`), content validations (P2), conditional
  formats (`calcext:conditional-formats`, P2), images (`draw:frame` + `draw:image`, P2).

---

## 6. Export

### 6.1 Entry points
*File › Download ▸* Microsoft Excel (.xlsx) · OpenDocument (.ods) · PDF (.pdf) · Web page
(.html, zipped) · Comma-separated values (.csv, current sheet) · Tab-separated values (.tsv,
current sheet) · JSON (P2). Command `sheets.file.download {format, options}`. Drive context
menu *Download as ▸* and MCP `drive.export {uuid, format, sheet?, range?, versionId?}` run the
same exporters server-side. Viewers/commenters can export only if the owner allows it
(suite 06 setting).

- Client exports run on the current local model (offline OK), in a background isolate on
  desktop (the model is serialized to IR in chunks first) and chunked on web; the file is saved
  with `file_saver` (desktop save dialog; web download).
- Server exports produce a `StoredFile` with a signed URL (15 min) and an `ActivityEvent`
  (`exported`).

### 6.2 XLSX export (Wonky → XLSX)
Writer: our own streaming OOXML writer (styles, merges, widths, freeze panes, formulas, DV, CF, comments,
hyperlinks, images, charts, defined names, `encodeToStream` for large workbooks). If the M5
spike finds gaps or performance problems at 1M cells, `XlsxExporter` switches to our own
streaming `OoxmlWriter` (`archive` `ZipEncoder` streaming + string buffers) behind the same
IR. Mapping is the reverse of §5.2 with these specifics:

| Wonky | XLSX | Notes |
|-------|------|-------|
| Values | `<c t="n|s|b|e|str|inlineStr">` | Shared string table deduplicated; rich text as `<r>` runs. |
| Formulas | `<f>` Excel A1 + cached `<v>` | Translator §5.3; array formulas `t="array" ref`; spills as dynamic arrays. Cached values from the engine's computed values; volatile functions export their current value. |
| Custom script functions | formula + cached value | Export option "Replace script functions with their values" (default **on**: Excel can't run them). |
| Number formats | `numFmts` custom ids ≥ 164 | Patterns not representable in Excel (rare Google tokens) → closest + report. |
| Fonts/fills/borders/alignment | `fonts`/`fills`/`borders`/`cellXfs` | Deduplicated styles; theme colors exported as RGB plus `theme` attribute when the spreadsheet theme maps 1:1. Row/column default formats → `<row s customFormat>` / `<col style>`. |
| Widths/heights | `<col width>` (chars, reverse formula) / `<row ht customHeight>` | |
| Merges, frozen panes, hidden, groups, tab color, gridlines, RTL | native | |
| Named ranges | `<definedName>` | |
| DV | `<dataValidations>` | Checkbox validation → list `TRUE,FALSE` (P1 Excel 365 checkbox: P2). Dropdown chips styles lost (report). |
| CF | `<conditionalFormatting>` + `dxfs` | Unsupported rule types (if any) dropped with report. |
| Basic filter | `<autoFilter>` | Filter views not exported. |
| Notes | legacy comments (`comments1.xml` + VML) | |
| Comments | threaded comments (P2); P1: appended to the note text "[Comment] Anna: …" (option) | |
| Hyperlinks | `<hyperlinks>` + relationships | Internal links → `location="'Sheet 2'!A1"`. |
| Images over cells | drawing part, `oneCellAnchor` (EMU) | Original bytes (PNG/JPEG/GIF); SVG → PNG. |
| `=IMAGE()` in cell | `https://` URLs: formula `_xlfn.IMAGE(url)` (Excel 365 has `IMAGE`). `wonky-file://` URLs are private, so the cell is exported as the text "[image]" and, with option *Export in-cell images as pictures* (default on, P1), an over-cell picture sized to the cell is added. | P1 |
| Charts | DrawingML charts | See §6.3. |
| Pivot tables | values (cells) | Definitions not exported (P2: pivot cache). |
| Sparklines | values `""` (P2: x14 sparklines) | |
| Protected ranges | not exported (P2: sheet protection with unlocked ranges) | |
| Slicers, filter views, scripts, macros, version history, comments resolved state | not exported | Listed in the export report shown as a toast link when anything was dropped. |
| Print settings | `pageSetup`, `pageMargins`, `printOptions`, `headerFooter`, breaks, print titles | |

### 6.3 Chart export mapping

| Wonky type | XLSX | Fallback |
|------------|------|----------|
| column/bar (+stacked, 100 %) | `c:barChart` `barDir`, `grouping` clustered/stacked/percentStacked | — |
| line, smooth line | `c:lineChart` (`c:smooth val=1`) | — |
| area (+stacked) | `c:areaChart` | — |
| combo | multiple chart groups sharing axes; right axis via secondary `c:valAx` | — |
| pie, doughnut | `c:pieChart` / `c:doughnutChart` (`holeSize`) | — |
| scatter | `c:scatterChart` (`lineMarker` style) | — |
| bubble | `c:bubbleChart` | — |
| radar | `c:radarChart` | — |
| candlestick | `c:stockChart` (open/high/low/close series order) | — |
| histogram, waterfall, scorecard, table, gauge, treemap, org, timeline, geo | — | Static PNG image of the chart (rendered with `RasterChartRenderer` on server or `ChartPainter` on client) placed at the same anchor; report "Exported as image". |
| Trendlines | `c:trendline` (linear, exp, poly order, log, power, movingAvg period; dispEq, dispRSqr) | — |
| Titles, legend position, axis min/max/log/format/titles, gridlines, series colors, data labels | DrawingML equivalents | Fonts approximated. |

### 6.4 ODS export (P1)
Custom `OdsExporter` writing `mimetype` (stored, first), `META-INF/manifest.xml`,
`content.xml` (streamed), `styles.xml` (automatic styles deduplicated), `meta.xml`,
`settings.xml` (frozen panes). Formulas via `OpenFormulaTranslator` (`of:=` syntax), cached
values in `office:value`, repeated empty rows/columns collapsed with `number-*-repeated`.
Charts → images (P1); notes → annotations; merges; widths/heights; named ranges; DV and CF P2.

### 6.5 CSV / TSV export
- Scope: the **active sheet** (Google parity). MCP and `drive.export` take `sheet` and optional
  `range`.
- Values: **formatted (as displayed)** by default, like Google Sheets. *Download ▸ CSV (raw
  values)* (P1, `options.values: raw`) writes unformatted numbers (shortest round-trip),
  ISO dates (`yyyy-mm-dd` / `yyyy-mm-ddTHH:MM:SS`) and `TRUE`/`FALSE`.
- Formulas → their values. Errors → the error text (`#N/A`). Empty trailing columns/rows
  trimmed. Hidden and filtered rows are **included**.
- Encoding UTF-8 without BOM (option *Include BOM for Excel*, P1), line endings CRLF (RFC 4180),
  delimiter `,` / `\t`, quote fields containing delimiter, quote, CR or LF (TSV: tabs/newlines in
  values are replaced with spaces, as in Google Sheets).
- P2 option *Protect against formula injection*: prefix text values starting with `= + - @`
  (and tab/CR) with `'`.

### 6.6 HTML export (P1)
Zip `<title>.zip` containing `index.html` (sheet links) and one `<sheet>.html` per visible
sheet (`<table>` with `colgroup` widths, `rowspan`/`colspan` merges, inline styles generated
from effective formats incl. CF results, displayed values, hyperlinks), `resources/` with
images and charts as SVG (`SvgChartRenderer`). Always light theme. Gridlines as 1 px
`#e0e0e0` borders when the sheet shows gridlines.

### 6.7 JSON (P2)
`{"title", "locale", "sheets":[{"name","values":[[…]],"formulas":[[…]]?, "formats"?: …}]}`
(values unformatted). A full-fidelity IR JSON (for developers/tests) is available via MCP only.

### 6.8 PDF
Uses the print pipeline (§7) with the sheet's stored print settings (or defaults); *File ›
Download ▸ PDF* opens the print route with *Export* preselected. MCP `drive.export` with
`format: pdf` accepts `scope`, `sheet`, `range` and overrides of `PrintSettings`.

---

## 7. Print and PDF

### 7.1 Route and layout
`Mod+P` / *File › Print* → full-screen in-app route **`/s/:uuid/print`** (suite routing). Back
arrow or Esc returns to the grid.

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ ← Print settings · Budget 2026                         [ Export PDF ]  [ Print ]       │
├──────────────────────────────────────────────────────────┬───────────────────────────┤
│  canvas (light page images on `canvas` token background) │ Print           [Current sheet ▾] │
│   ┌──────────────┐  ┌──────────────┐                     │ Paper size      [Letter ▾]  │
│   │ page 1       │  │ page 2       │                     │ Page orientation (●Portrait ○Landscape) │
│   │              │  │              │                     │ Scale           [Normal (100%) ▾]  │
│   └──────────────┘  └──────────────┘                     │ Margins         [Normal ▾]  │
│                                                          │ ▸ Formatting                │
│                                                          │ ▸ Headers & footers         │
│  [− 75% +]   Page 1 of 12  ‹ ›                           │ [ Set custom page breaks ]  │
└──────────────────────────────────────────────────────────┴───────────────────────────┘
```

- Settings panel (360 px, `ShadAccordion` for the collapsible sections) on the right; preview
  on the left, scrollable, zoom (fit width / 50–200 %), page navigation, thumbnails strip (P2).
- The chrome follows the app theme; **pages are always rendered light** (paper). *Export PDF*
  has an option *Use dark theme* (suite 02 §8).

### 7.2 Settings (`PrintSettings`)

| Setting | Options | Default |
|---------|---------|---------|
| Print scope | Current sheet · Workbook (all visible grid sheets + chart sheets) · Selected cells (current selection, P0) · Named range (P1) | Current sheet |
| Paper size | Letter (8.5×11 in) · Tabloid · Legal · Statement · Executive · Folio · A3 · A4 · A5 · B4 · B5 · Custom (w × h, in/cm) | Letter for `en_US`/`en_CA`/`es_MX` locales, A4 otherwise |
| Page orientation | Portrait · Landscape | Portrait |
| Scale | Normal (100 %) · Fit to width · Fit to height · Fit to page · Custom number (10–400 %) | Normal |
| Margins | Normal (0.75 in top/bottom, 0.7 in left/right) · Narrow (0.25 in) · Wide (1 in) · Custom (top/bottom/left/right) | Normal |
| Formatting › Show gridlines | ☐ | off |
| Formatting › Show notes | ☐ (notes printed as endnotes list after each sheet: "A4: text") | off |
| Formatting › Page order | Down, then over · Over, then down | Down, then over |
| Formatting › Alignment | Horizontal: Left · Center · Right; Vertical: Top · Middle · Bottom | Left, Top |
| Formatting › Repeat frozen rows / columns | ☑ (each page repeats the sheet's frozen rows at the top and frozen columns at the left) | on when frozen |
| Formatting › Show row & column headers | ☐ (prints A, B, C / 1, 2, 3 headers) (P1) | off |
| Headers & footers | ☐ Page numbers · ☐ Workbook title · ☐ Sheet name · ☐ Current date · ☐ Current time · *Edit custom fields* | Page numbers |
| Custom page breaks | §7.6 | none |

`PrintSettings` JSON stored per sheet in `Sheet.printSettingsJson` (Additions A-11-1):

```jsonc
{ "v": 1,
  "paper": "letter", "customSize": null,           // {w, h, unit: "in"|"cm"}
  "orientation": "portrait",
  "scale": { "mode": "normal" },                   // normal | fitWidth | fitHeight | fitPage | custom {percent}
  "margins": { "preset": "normal" },               // or {preset: "custom", top, bottom, left, right, unit}
  "gridlines": false, "notes": false,
  "pageOrder": "downThenOver",
  "align": { "h": "left", "v": "top" },
  "repeatFrozen": true, "headings": false,
  "repeatRows": null, "repeatCols": null,          // explicit print titles from XLSX import (row/col id ranges)
  "headerFooter": {
    "header": { "left": "", "center": "", "right": "" },
    "footer": { "left": "", "center": "", "right": "{page}" },
    "flags": { "pageNumbers": true, "title": false, "sheetName": false, "date": false, "time": false } },
  "pageBreaks": { "rows": ["<rowId>", …], "cols": ["<colId>", …] },   // break BEFORE these
  "printArea": null }                              // GridRange (P1: from XLSX Print_Area)
```

- Changes in the print route are written through `SheetsWriter` (`sheets.print.updateSettings`,
  merge patch) and are undoable ("Change print settings"; slider/stepper bursts coalesce).
  With scope *Workbook*, a checkbox *Apply to all sheets* (default on) writes every sheet's
  settings in one step; otherwise each sheet prints with its own settings.
- Viewers can change settings locally for their print job (not persisted: kept in
  `LocalViewState`).

### 7.3 Pagination (`Paginator`, pure Dart)
1. Determine the **print range** per sheet: scope selection / named range / `printArea` /
   used range (bounding box of non-empty cells, objects and merges; empty sheets print one blank
   page only if they're the only sheet). Hidden rows/columns are skipped. Filter-hidden rows
   are skipped (basic filter, not filter views).
2. Printable area = paper (orientation applied) − margins − header height (if any header
   content: font 10 pt, 0.3 in) − footer height.
3. Repeated rows/columns: `repeatFrozen` → the sheet's frozen rows/cols (or `repeatRows/Cols`)
   are reserved at the top/left of every page. If they exceed 50 % of the page, they repeat only
   on the first page (warning in the panel).
4. Scale: `normal` 1.0; `custom` p/100; `fitWidth` = min(1, availableWidth / totalWidth);
   `fitHeight` = min(1, availableHeight / totalHeight); `fitPage` = min of both. Fit modes
   may also enlarge? No: max 1.0 (Google behavior), min 0.1 (then paginate).
5. Column breaks: greedily accumulate scaled column widths; break before a column that
   overflows, or at a custom `cols` break. A single column wider than the page is clipped
   (warning). Same for rows (row heights from the grid's layout, including auto-fit heights
   computed with the shared text measurer).
6. Page order: `downThenOver` = all row-chunks of the first column-chunk, then next; or
   `overThenDown`.
7. Max 1,000 pages per job (preview warns at 200: "This will print 1,240 pages").
8. Output: `List<PageSpec {sheetId, rowIds range, colIds range, repeatRows, repeatCols, scale,
   pageNumber}>` – deterministic and unit-testable.

### 7.4 PDF rendering (`SheetsPdfRenderer`, `pdf` 3.13.x)
Pure Dart, runs on client and server. For each `PageSpec` it draws with `PdfGraphics`:
- **Fonts**: bundled TTFs of the curated cell font list (Inter, Roboto, Open Sans, Lato,
  Merriweather, Roboto Mono, … see [06-formatting.md](06-formatting.md)) embedded as subsets
  via `pw.Font.ttf`; bold/italic variants; fallback chain per glyph (Noto Sans → Noto Sans
  Symbols → Noto Color Emoji as image P2 → Noto Sans CJK subsets P1, downloaded lazily on
  desktop/web and present on the server).
- **Text**: display values from the formula engine + number formatter; horizontal/vertical
  alignment, rotation (incl. stacked), wrapping (same line-breaking rules as the grid using the
  font's metrics), **overflow** into empty neighbor cells (same algorithm as the grid), clip
  strategy; rich text runs; underline/strikethrough; hyperlinks become PDF link annotations
  (`PdfUriAnnotation`, internal links → `PdfAnnotLink` to the page of the target cell if
  printed).
- **Fills** and **CF results** (computed fill, text color, bold…), **banding** colors.
- **Borders**: thin 0.75 pt, medium 1.5 pt, thick 2.25 pt, dashed `[3,2]`, dotted `[1,1]`,
  double (two 0.5 pt lines 1.5 pt apart); conflict resolution as on the grid.
- **Gridlines** (if on): 0.5 pt `#D0D0D0`, drawn under borders, not across merged areas.
- **Merges**: drawn as one cell; a merge split by a page break is clipped per page (content
  drawn in the first part only, Google behavior).
- **Images** over cells: placed by anchor (scaled), clipped to the page area; in-cell images
  per `IMAGE()` mode. **Checkboxes** drawn as vector boxes; **dropdown chips** as rounded
  rectangles with text; **sparklines** via the chart scene; **charts** via `PdfChartRenderer`
  (vector) at their anchor; chart sheets print one chart per page, fit to the printable area.
- **Headers/footers**: tokens `{page}`, `{pages}` (pages in the whole job), `{title}`,
  `{sheet}`, `{date}`, `{time}` (spreadsheet locale and time zone), custom text; 9 pt.
- Notes endnotes page if *Show notes*.
- Row/column headings if enabled (grey header band like the grid).
- PDF metadata: title, author (exporting user), creator "Wonky Sheets", creation date.

### 7.5 Live preview
- On every settings change (debounced 250 ms) the client runs `Paginator` (fast) and renders
  only the **visible pages** to images: native → background isolate builds the PDF document
  for those pages, rasterized with `Printing.raster` at the current zoom × device pixel ratio;
  web → page images are produced by drawing the same page layout directly with a Flutter
  `CustomPainter` (`PrintPagePainter`, shares the layout code with `SheetsPdfRenderer` through a
  `PageCanvas` abstraction) to avoid pdf.js rasterization cost. A cancellation token aborts
  stale renders.
- The preview widget is custom (not `PdfPreview`'s toolbar) so it matches shad styling.
- First visible page within 500 ms for a 10k-cell sheet; page count updates within 200 ms.

### 7.6 Custom page breaks (P1)
*Set custom page breaks* switches the print route into **break mode**: the left side shows the
sheet grid (read-only, scaled) with automatic breaks as dashed grey lines and custom breaks as
solid blue lines with drag handles. Dragging a break moves it to the nearest row/column
boundary; dragging off the page removes it; *Add break* buttons on row/column headers.
*Confirm breaks* writes `pageBreaks` (row/col ids, break before) via
`sheets.print.updateSettings`; *Reset breaks* clears them. Breaks referencing deleted rows are
ignored.

### 7.7 Print and export actions
- **Print** (`sheets.print.print`): generates the full PDF (background isolate / chunked on
  web, progress for > 20 pages) and calls `Printing.layoutPdf` (desktop: native print dialog;
  web: the browser's print dialog for the PDF).
- **Export PDF** (`sheets.print.exportPdf`): same PDF → `file_saver` as `<title>.pdf`
  (`<title> - <sheet>.pdf` for single-sheet scope).
- Server-side (`drive.export pdf`, MCP): `SheetsPdfRenderer` on the headless model; charts via
  `PdfChartRenderer`; images fetched from storage.

---

## 8. Fidelity summary

| Feature | XLSX in | XLSX out | ODS in | ODS out | CSV in | CSV out | PDF |
|---------|---------|----------|--------|---------|--------|---------|-----|
| Values & types | ✓ | ✓ | ✓ | ✓ | ✓ (parsed) | ✓ (formatted/raw) | ✓ |
| Formulas | ✓ (translated) | ✓ (+cached) | ✓ | ✓ | ✓ (`=…`) | values | values |
| Number formats | ✓ | ✓ | ✓ | ✓ | detected | as displayed | ✓ |
| Fonts, colors, fills, borders, alignment, wrap, rotation | ✓ (approx. patterns/gradients) | ✓ | ✓ | ✓ | — | — | ✓ |
| Merges, widths, heights, hidden, frozen | ✓ | ✓ | ✓ | ✓ | — | — | ✓ |
| Groups | P1 | P1 | P2 | P2 | — | — | — |
| Named ranges | ✓ | ✓ | ✓ | ✓ | — | — | — |
| DV | P1 | P1 | P2 | P2 | — | — | chips |
| CF | P1 (subset) | P1 | P2 | P2 | — | — | results |
| Filters | P1 | P1 | P2 | P2 | — | — | applied |
| Notes / comments | ✓ / P1 | ✓ / P2 | ✓ / — | ✓ / — | — | — | notes opt. |
| Hyperlinks | ✓ | ✓ | ✓ | ✓ | — | — | ✓ |
| Images | P1 | P1 | P2 | P2 | — | — | ✓ |
| Charts | P1 | P1 (some as images) | — | images | — | — | ✓ |
| Pivots | values | values | values | values | — | values | values |
| Print settings | P1 | P1 | — | — | — | — | ✓ |
| Scripts/macros | — | — | — | — | — | — | — |

---

## 9. Commands

| Command id | Args | Undoable | Role |
|------------|------|----------|------|
| `sheets.file.import` | `{source?: upload, file?, options?: ImportOptions}` | ✓ (into existing) | Editor (Viewer+ for "create new") |
| `sheets.file.cancelImport` | `{jobId}` | — | |
| `sheets.file.showImportReport` | `{jobId?}` | — | |
| `sheets.file.download` | `{format: xlsx\|ods\|pdf\|html\|csv\|tsv\|json, sheetId?, range?, options?}` | — | Viewer+ (if export allowed) |
| `sheets.print.open` | `{scope?}` | — | Viewer+ (if print allowed) |
| `sheets.print.updateSettings` | `{sheetId?, patch, applyToAll?}` | ✓ (Editor) / local (Viewer) | |
| `sheets.print.resetSettings` | `{sheetId?}` | ✓ | Editor |
| `sheets.print.enterBreakMode` / `exitBreakMode` | — | — | |
| `sheets.print.setPageBreaks` | `{sheetId, rows: [rowId], cols: [colId]}` | ✓ | Editor |
| `sheets.print.print` | — | — | |
| `sheets.print.exportPdf` | `{darkTheme?}` | — | |

`ImportOptions` JSON (shared by the dialog, commands, MCP): `{location: createNew|insertSheets|
replaceSpreadsheet|replaceSheet|append|replaceAtCell, cell?: A1, separator?: auto|","|";"|"\t"|
"|"|string, encoding?: auto|utf-8|utf-16le|utf-16be|windows-1252|iso-8859-1|iso-8859-15|macintosh,
locale?, convert: bool, sheets?: [names], unsupportedFormulas: value|text}`.

MCP: `drive.import` (suite) accepts `options: ImportOptions` for spreadsheets; Sheets adds
`sheets.import_csv` (CSV text into a range) — see [12-mcp-and-ai.md](12-mcp-and-ai.md) §3.13.
`drive.export` formats for spreadsheets: `xlsx, ods, pdf, csv, tsv, html, json`.

---

## 10. Additions to 02-data-model

| # | Change |
|---|--------|
| A-11-1 | `Sheet` gains `printSettingsJson: String?` (schema §7.2; null = defaults). |
| A-11-2 | Server table `SheetsImportJob(uuid, userId, spreadsheetUuid?, uploadFileId, fileName, format, optionsJson, status (queued/parsing/writing/finalizing/done/failed/cancelled), progressDone, progressTotal, reportFileId?, changeId?, error?, createdAt, leaseOwner?, leaseUntil?)`. |
| A-11-3 | `ChangeLog.summaryJson.kinds` uses `import` for import writes (label "Import <file>"). |

---

## 11. Acceptance criteria

1. A 50 MB, 1M-cell UTF-8 CSV imports server-side into a new spreadsheet in < 90 s with live
   progress; types are converted per locale; the spreadsheet opens and syncs (suite perf gate).
2. Semicolon-separated Windows-1252 CSV with `1.234,56` and `03.04.2026` imports correctly with
   locale `de_DE` (auto-detected delimiter and encoding shown in the dialog).
3. CSV edge cases: quoted newlines, `""` escapes, ragged rows, BOM, `sep=;` header, a 60k-char
   field (truncated with a warning).
4. Each import location option behaves as specified; imports into an existing spreadsheet are
   one undo step (client and server paths).
5. The XLSX corpus (§12) imports with values identical to the files' cached values after our
   recalculation for supported functions (tolerance 1e-9 relative), formats mapped as in
   §5.2, and an accurate import report.
6. Exported XLSX files open in Excel and LibreOffice without repair prompts; re-importing an
   exported file yields an identical spreadsheet (values, formulas, formats, merges, sizes,
   frozen panes, named ranges, DV, CF, images, mapped charts).
7. CSV export matches displayed values; raw option writes unformatted values.
8. Print route: changing scale/margins/orientation updates the preview within 500 ms; *Fit to
   width* puts all columns on one page width; frozen rows repeat; page numbers and sheet name
   appear in the footer/header; custom page breaks persist and survive row insertions.
9. The same PDF is produced client-side and server-side (`drive.export`), byte-identical except
   timestamps/IDs for the same fonts.
10. Exports from a historical version (version history › Download) contain the version's data.
11. Offline: CSV/XLSX import into the current spreadsheet and all client exports/print work
    without a connection.

## 12. Tests

- **Unit**: encoding sniffer, delimiter scoring, CSV parser edge cases (property-based: random
  tables → encode → decode round-trip), locale conversion tables, number-format id table,
  width/height conversions, color theme/tint resolution, formula translator (table-driven over
  the function map; shared formula expansion), OpenFormula translator, paginator (fixtures
  with expected `PageSpec`s), header/footer token rendering.
- **XLSX corpus** (`wonky_sheets_core/test/fixtures/xlsx/`, ~120 files): generated by Excel,
  LibreOffice, Google Sheets exports, our own writer, and real-world anonymized files; categories:
  types & dates (1900/1904), formats, styles, merges, large (1M cells), shared/array/dynamic
  formulas, every supported function, DV, CF, filters, names, images, charts, print settings,
  rich text, comments (legacy/threaded), hidden/very hidden, RTL, unicode sheet names, broken
  files (must fail gracefully with an error report, never crash).
- **Round-trip goldens**: import → export → import; compare IR JSON (normalized).
- **LibreOffice headless validation in CI**: `soffice --headless --convert-to csv/pdf` on every
  exported XLSX/ODS; assert conversion succeeds (file valid), compare CSV values with our
  expected values, and run `--convert-to xlsx` back for a second-generation import check.
  Also validate XLSX against the ECMA-376 schemas (subset) with an XSD validator step.
- **PDF goldens**: render fixtures to PDF; rasterize pages (`pdftoppm` in CI; `Printing.raster`
  locally) and compare with golden PNGs (pixel tolerance 0.5 %); text extraction checks with
  `pdftotext`.
- **Performance**: 1M-cell CSV import (client desktop < 60 s, server < 90 s), 1M-cell XLSX
  export < 60 s, 100-page PDF < 10 s on desktop.
