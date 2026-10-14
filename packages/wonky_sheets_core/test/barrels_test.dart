// Guards the public surface: the app and the server import `model.dart` and
// `formula.dart` together, so every main entry point must be reachable
// through them without ambiguous names (an ambiguity is a compile error here).
import 'package:test/test.dart';
import 'package:wonky_sheets_core/formula.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart' as all;

void main() {
  group('Given the public barrels imported together', () {
    test('when naming the main entry points then each one resolves', () {
      const entryPoints = <Type>[
        // Model, planner, undo.
        WorkbookModel, SheetsMutationPlanner, UndoInverter, PlanContext,
        PlanException, WorkbookMaintenance, SheetsOperation, MutationPlan,
        // Engine and bridge.
        FormulaEngine, ModelEngineBinding, EngineFormulaHooks,
        EnginePivotFormulaEvaluator, BoundFormula, FunctionRegistry,
        FunctionCatalog, FormulaHighlighter,
        // Number formats, input, fill.
        NumberFormatter, CellTextFormatter, NumberFormatPresets,
        DecimalsAdjuster, InputParser, SeriesDetector,
        // Rules, data tools, pivots.
        CfEvaluator, DvEvaluator, FilterEngine, FindEngine, ReplaceEngine,
        SortSpec, ColumnStats, PivotEngine, PivotLayout, PivotDataLookup,
        // Charts and objects.
        ChartPipeline, ChartLayoutEngine, ChartScene, SvgChartRenderer,
        ObjectAnchor, SmartGuides,
        // Clipboard and import/export.
        TsvCodec, HtmlTableCodec, ClipboardEncoder, ClipboardDecoder,
        CsvImporter, CsvExporter, XlsxImporter, XlsxExporter, OdsImporter,
        OdsExporter, ModelToIr, IrToRowsPlanner, HtmlExporter, Paginator,
        SheetsPdfRenderer, PrintSettings,
        // Test helpers.
        WorkbookBuilder,
      ];

      expect(entryPoints.toSet(), hasLength(entryPoints.length));
    });

    test('when using the umbrella library then it exposes the same types', () {
      expect(all.WorkbookModel, same(WorkbookModel));
      expect(all.FormulaEngine, same(FormulaEngine));
    });

    test('when naming the formula editor services then they resolve', () {
      final services = <Function>[
        completionsAt,
        signatureAt,
        validateFormula,
        describeError,
        explainCell,
        autoFix,
      ];

      expect(services, hasLength(6));
    });
  });
}
