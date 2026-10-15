# wonky_sheets_core

Pure-Dart core of Wonky Sheets: the workbook model, formula engine, mutation planner with undo,
formatting, data tools, rules, pivots, charts, clipboard and import/export. Used by the Flutter
app (`wonky_sheets`) and the server (`wonky_server`). Specs: `specs/wonky_sheets/`.

## Barrels

Import the two barrels together; they have no name clashes (`test/barrels_test.dart` checks
this).

| Import | Contents |
|--------|----------|
| `package:wonky_sheets_core/formula.dart` | Addressing (A1), formula parser and locales, A1 ⇄ stored codec, evaluator, ~517 functions, recalculation engine, editor services |
| `package:wonky_sheets_core/model.dart` | Everything else (table below) |
| `package:wonky_sheets_core/wonky_sheets_core.dart` | Both of the above |
| `package:wonky_sheets_core/model_testing.dart` | Test helpers (`WorkbookBuilder`); never import it from `lib/` code |

Each area also has its own barrel under `lib/src/<area>/<area>.dart`, and `model.dart`
re-exports all of them.

## Main entry points

### Formula (`formula.dart`)
- `FormulaEngine` is the recalculation facade: values, spills, cycles and iterative calculation.
  - `compileWithBindings` / `evaluateWithBindings` evaluate a formula with named values; pivot calculated fields use them.
- `FormulaCodec` converts between A1 and the stored form with id tokens. `ReferenceRewriter` rewrites references.
- `FormulaLocale.forId(id).withLanguage('de')` adds a display language (`FormulaLanguage`: de, fr, es, sv) for function names and booleans in A1 text; the stored form stays English.
- `FunctionRegistry.standard` holds the functions. `FunctionCatalog` lists them for the function menu and help.
- Editor services:
  - `completionsAt` (autocomplete)
  - `signatureAt` (signature help)
  - `FormulaHighlighter` (token spans and reference colors)
  - `validateFormula` / `describeError` (diagnostics)
  - `explainCell` (Explain formula)
  - `autoFix`, `cycleAbsolute`, `toggleArrayFormula` (editing helpers)

### Model, planner, undo (`model.dart`)
- `WorkbookModel` and `SheetModel` hold the in-memory workbook built from sync rows. `model.applyPlan(plan)` applies a plan; `model.parseA1` parses A1 input.
- `SheetsMutationPlanner().plan(op, model, PlanContext)` turns a `SheetsOperation` into a `MutationPlan` of `RowChange`s.
  - Every operation in `operations.dart` is planned.
  - `steps(op, model, ctx)` plans cooperatively (progress values, then the plan; sort, randomize and remove duplicates report progress); `SheetsMutationPlanner.offer(op, model, plan)` hands such a plan to the next `plan` of that op.
  - `UndoInverter.invert(plan, model)` builds the undo plan.
  - `WorkbookMaintenance` repairs invariants such as anchors, group depths and names.
- Engine bridge:
  - `ModelEngineBinding.create(model)` keeps a `FormulaEngine` in sync with the model.
  - `EngineFormulaHooks` is the `FormulaHooks` passed in `PlanContext.formulas`.
  - `ModelWorkbookView` and `ModelCellSource` give read access to the model.
  - `ModelWorkbookView.overlays` (`ComputedOverlaySource`) layers computed cells (the app's pivot output) under empty cells; the engine reads them as literal inputs.
  - `EnginePivotFormulaEvaluator` evaluates pivot calculated fields.
- Snapshots and copies: `SpaceCopier`, `snapshot.dart`, `diff.dart` (version diff).

### Formatting, number formats, input, fill
- `EffectiveFormatResolver` (in `format_resolver.dart`) works out a cell's effective format; themes, banding and borders sit alongside it.
- Number formats (the pattern engine is the shared package `wonky_numfmt`, re-exported here):
  - `NumberFormatter` formats a cell value with a pattern and locale, including section colors (on `wonky_numfmt`'s `NumberPatternFormatter`).
  - `CellTextFormatter` gives the display text of a cell's effective value.
  - `NumberFormatPresets` holds the menu and toolbar presets.
  - `DecimalsAdjuster` handles the decimal-places steps; `NumberFormatParser` / `NumberFormatInfo` validate and classify patterns.
- `InputParser.parse` turns typed text into a value or formula plus an inferred format.
- `SeriesDetector` detects fill and auto-fill series.

### Rules, data tools, pivots
- Conditional formatting: `CfEvaluator` (`evaluate`, `evaluateRect` for the visible window), plus `CfRule` and `CfPresets`.
- Data validation: `DvEvaluator` returns markers, typed-input checks (accept, warn or reject), dropdown items and checkboxes. `DvCriteria` is the rule model.
- Conditions: `ConditionEvaluator`, the condition model shared by CF, DV, filters and pivots.
- Filter: `FilterEngine`, `FilterCriteria`, `ViewRowOrder` (`forRows` for a sorted filter view; display offsets, hit testing and `modelRuns` for the grid).
- Find and replace: `FindEngine`, `ReplaceEngine`, `FindQuery`.
- Sort: `SortSpec`, `SortPermutation`, `SortStrategy`.
- Cleanup and split: `Dedupe`, `WhitespaceTrimmer`, `TextSplitter`.
- Other data tools: `ColumnStats`, `GroupLayout`, `NameRules`, `ProtectionGuard`.
- Pivots:
  - `PivotEngine().compute(spec, SourceTable, PivotContext)` returns a `PivotResult`; `applyDelta` updates it in place for changed source rows (decomposable aggregates); `SourceTableBuilder` reads a source in slices.
  - `PivotLayout.build(result)` turns it into a `PivotGrid`.
  - `PivotDataLookup.lookup` implements GETPIVOTDATA.

### Charts and objects
- The chart engine (spec, `ChartData`, layout, scene, 3D, SVG/PDF/PNG renderers, stats, describer) is the shared package `wonky_charts`; `model.dart` re-exports it (08 §24).
- `SheetsChartPipeline` is the Sheets entry point for charts:
  - `resolve` turns a spec and the workbook's cells into `ChartData` (`ChartDataResolver`).
  - `build` produces a `ChartBuild`: the data plus a `ChartScene` for the Flutter painter (`wonky_charts_flutter`).
  - `exportSvg`, `exportPdf` and `exportPng` export a chart; `printSceneFor` supplies charts to the print renderer.
  - Without a workbook, `ChartPipeline` (`wonky_charts`) lays out and exports resolved `ChartData`.
- `ChartDataSpec.ranges` are opaque `DataRangeRef`s holding GridRange JSON: `GridRange.fromRef` / `toRef`, `spec.data.gridRanges`, `ranges.toRefs()`. `SpreadsheetTheme` is the charts' `ChartThemeSource`.
- Sheets-only chart parts: `ChartRecommender`, `HeaderDetection`, `SparklineRenderer`, `ImageSpec` (objects).
- Objects:
  - `ObjectAnchor` and `ObjectPlacement` position objects.
  - `ObjectGeometry`, `GridSnap` and `SmartGuides` handle move, resize and snapping.
  - `ZOrder` sets stacking order; `AnchorMaintenance` re-anchors objects.

### Clipboard
- `ClipboardEncoder.copy` turns a selection into TSV, HTML and a Wonky payload (`rowOrder:` copies rows in a display order).
- `ClipboardDecoder.decode` turns clipboard HTML or text into a `ClipboardPasteInput`, whose `PasteSource` feeds the `PasteClipboard` operation.
- Lower-level parts: `TsvCodec`, `HtmlTableCodec`, `PasteTiling`, `R1C1Relative`.

### Import and export
All formats go through the intermediate representation (`WorkbookDocument`).
- Import:
  - Parse the file into IR with `CsvImporter.import`, `XlsxImporter.import`, `OdsImporter.import` or `JsonWorkbook.import` (or `SheetsFileImporter.parse`, which detects the format).
  - `IrToRowsPlanner.estimate` checks the cell limit for the import dialog.
  - `IrToRowsPlanner.plan(doc, model, ctx, options:)` returns an undoable plan and an import report.
  - Big documents: `IrToRowsPlanner.planChunked(doc, model, ctx, options:, chunkCells: 5000)` returns
    `IrImportChunks`: apply and write `head` (every row but the cells), then loop
    `for (var p = chunks.next(); p != null; p = chunks.next())`, applying each plan to the model
    (`model.applyPlan`, in-place writes read it) and writing it before the next. `progress`,
    `totalCells`, `sheetIds`, `imageUploads`, `report` and `result` (final report) are on the
    object; the concatenated plans equal `plan`'s changes (one undo step: keep them together).
- Export:
  - `ModelToIr.convert(model, …)` builds the IR, then `XlsxExporter`, `OdsExporter` or `JsonWorkbook.export` writes the file (`SheetsWorkbookExporter.toDocument` / `writeDocument`; with `chartSource:` charts Excel can't hold become PNG pictures, `chartPng`).
  - `CsvExporter.export` writes the displayed values.
  - `HtmlExporter.export` writes HTML.
- Print and PDF: `PrintSettings`, then `Paginator.paginate`, then `SheetsPdfRenderer.render`. Fonts come from `BuiltInPdfFontProvider` or `TtfPdfFontProvider`; `BundledPdfFonts.load` builds the provider of the bundled TTF set (same faces and family mapping in the app and on the server). `darkTheme: true` renders dark pages.

## Tests

`dart test` runs the default suite; `slow` is excluded by `dart_test.yaml`, so use `dart test -P slow`
for the benchmarks. Property tests (`property` tag) use fixed seeds; replay one with
`WONKY_SEED=<seed> dart test <file>`. See `specs/15-writing-tests.md`.
