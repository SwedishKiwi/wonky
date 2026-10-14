import 'package:test/test.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sync_models/ids.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

const _source = '''
import 'package:wonky/wonky.dart';

/// Converts Celsius to Fahrenheit.
///
/// @customfunction
/// @param celsius A value or range in °C.
/// @example =TO_F(A1:A3)
Object? TO_F(Object? celsius) {
  if (celsius is List) {
    return celsius.map((row) => (row as List).map(_convert).toList()).toList();
  }
  return _convert(celsius);
}

Object? _convert(Object? c) => c is num ? c * 9 / 5 + 32 : null;

/// @customfunction
Object? GREET(Object? name) => 'Hello \$name';

/// @customfunction
Object? FAIL(Object? x) => throw StateError('bad input');

/// @customfunction
Object? SPIN(Object? x) {
  while (true) {}
}

/// @customfunction
Object? PEEK(Object? x) => SpreadsheetApp.active.getRange('A1').value;

/// @customfunction
Object? ROWOF(Object? x) => [1, 2, 3];
''';

/// Custom functions evaluated by the formula engine (09 §8.6, 05 §13.6).
void main() {
  late ScriptProgram program;
  setUpAll(() => program = compileScript({'main.dart': _source}));

  group('Given a workbook whose engine uses the script custom functions', () {
    late WorkbookModel model;
    late ScriptCustomFunctions functions;
    late ModelWorkbookAccess access;
    late String sheetId;

    setUp(() {
      model = scriptWorkbook((b) {
        b.sheet('Sheet1', rows: 10, cols: 5);
        b.values('A1', [
          [0],
          [100],
          [-40],
        ]);
      });
      sheetId = model.sheets.first.id;
      late ModelWorkbookAccess evaluatorAccess;
      functions = ScriptCustomFunctions(
        evaluator: RunnerCustomFunctionEvaluator(
          runner: InlineScriptRunner(),
          workbook: _LazyAccess(() => evaluatorAccess),
          user: testUser,
          limits: const ExecutionLimits(timeout: Duration(milliseconds: 300)),
          timeZones: const FixedOffsetResolver(),
        ),
        isBuiltin: (n) => FunctionRegistry.standard.lookup(n) != null,
        timeZones: const FixedOffsetResolver(),
      )..setProgram(program);
      access = ModelWorkbookAccess(
        model: model,
        userId: testUser.id,
        binding: ModelEngineBinding.create(
          model,
          engineFactory: (view) =>
              FormulaEngine(workbook: view, customFunctions: functions),
        ),
      );
      evaluatorAccess = access;
    });

    Object? valueAt(String a1) {
      final r = model.parseA1(a1, contextSheetId: sheetId);
      return access.engine
          .valueAt(sheetId, r.rect.top, r.rect.left)
          .toCellValue();
    }

    void setFormula(String a1, String formula) {
      final r = model.parseA1(a1, contextSheetId: sheetId);
      access.apply(
        SetCellInputs(
          sheetId: sheetId,
          row: r.rect.top,
          col: r.rect.left,
          inputs: [
            [CellInput.user(formula)],
          ],
        ),
      );
    }

    test(
      'when a cell uses a custom function then it is #LOADING until evaluated',
      () async {
        setFormula('B1', '=TO_F(A1)');
        expect(valueAt('B1'), const ErrorValue(CellErrorKind.loading));
        await functions.idle();
        expect(valueAt('B1'), const NumberValue(32));
      },
    );

    test('when a range is passed then the result spills', () async {
      setFormula('B1', '=TO_F(A1:A3)');
      valueAt('B1');
      await functions.idle();
      expect(valueAt('B1'), const NumberValue(32));
      expect(valueAt('B2'), const NumberValue(212));
      expect(valueAt('B3'), const NumberValue(-40));
    });

    test('when a 1-D list is returned then it spills as one row', () async {
      setFormula('B1', '=ROWOF(1)');
      valueAt('B1');
      await functions.idle();
      expect(
        [valueAt('B1'), valueAt('C1'), valueAt('D1')],
        const [NumberValue(1), NumberValue(2), NumberValue(3)],
      );
    });

    test(
      'when the names are lower case in the formula then they still resolve',
      () async {
        setFormula('B1', '=greet("Bo")');
        valueAt('B1');
        await functions.idle();
        expect(valueAt('B1'), const TextValue('Hello Bo'));
      },
    );

    test(
      'when the function throws then the cell shows #ERROR! with the message',
      () async {
        setFormula('B1', '=FAIL(1)');
        valueAt('B1');
        await functions.idle();
        final v = valueAt('B1');
        expect(
          v,
          isA<ErrorValue>().having((e) => e.kind, 'kind', CellErrorKind.parse),
        );
        expect((v as ErrorValue).message, contains('bad input'));
      },
    );

    test(
      'when the function loops forever then it fails after its time limit',
      () async {
        setFormula('B1', '=SPIN(1)');
        setFormula('C1', '=TO_F(100)');
        valueAt('B1');
        valueAt('C1');
        await functions.idle();
        expect(
          (valueAt('B1') as ErrorValue).message,
          contains('Exceeded maximum execution time'),
        );
        expect(valueAt('C1'), const NumberValue(212));
      },
    );

    test('when the function reads the spreadsheet then it fails', () async {
      setFormula('B1', '=PEEK(1)');
      valueAt('B1');
      await functions.idle();
      expect(
        (valueAt('B1') as ErrorValue).message,
        contains('Custom functions cannot read'),
      );
    });

    test(
      'when an argument changes then the function is re-evaluated',
      () async {
        setFormula('B1', '=TO_F(A1)');
        valueAt('B1');
        await functions.idle();
        access.apply(
          SetCellInputs(
            sheetId: sheetId,
            row: 0,
            col: 0,
            inputs: const [
              [CellInput.raw(10)],
            ],
          ),
        );
        expect(valueAt('B1'), const ErrorValue(CellErrorKind.loading));
        await functions.idle();
        expect(valueAt('B1'), const NumberValue(50));
      },
    );

    test(
      'when a custom function shadows a built-in then the built-in wins',
      () {
        final shadow = compileScript({
          'main.dart': '/// @customfunction\nObject? SUM(Object? x) => 0;\n',
        });
        functions.setProgram(shadow);
        expect(functions.has('SUM'), isFalse);
      },
    );

    test('when scripts are disabled then calls show #ERROR!', () async {
      functions.disabledReason = 'Scripts are disabled';
      setFormula('B1', '=TO_F(A1)');
      expect((valueAt('B1') as ErrorValue).message, 'Scripts are disabled');
    });

    test('then help comes from the doc comment', () {
      final help = functions.help('TO_F');
      expect(help.summary, 'Converts Celsius to Fahrenheit.');
      expect(help.syntax, 'TO_F(celsius)');
      expect(help.args.single.description, 'A value or range in °C.');
      expect(help.examples, ['=TO_F(A1:A3)']);
    });
  });
}

/// Breaks the construction cycle between the provider and the access.
final class _LazyAccess implements WorkbookAccess {
  _LazyAccess(this._get);
  final WorkbookAccess Function() _get;
  @override
  List<AppliedPlan> get applied => _get().applied;
  @override
  MutationPlan apply(SheetsOperation operation, {bool undoable = true}) =>
      _get().apply(operation, undoable: undoable);
  @override
  FormulaEngine get engine => _get().engine;
  @override
  EffectiveFormatResolver get formats => _get().formats;
  @override
  FormulaHooks get formulas => _get().formulas;
  @override
  IdGenerator get ids => _get().ids;
  @override
  WorkbookModel get model => _get().model;
  @override
  String get userId => _get().userId;
}
