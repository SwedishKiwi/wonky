import 'package:test/test.dart';
import 'package:wonky_sheets_script/compiler.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart'
    show ScriptExports;

const _compiler = ScriptCompiler();

List<ScriptDiagnostic> _diagnostics(String source) =>
    _compiler.compile([ScriptSourceFile('main.dart', source)]).diagnostics;

ScriptDiagnostic _only(String source, String code) {
  final found = _diagnostics(source).where((d) => d.code == code).toList();
  expect(found, isNotEmpty, reason: '${_diagnostics(source)}');
  return found.first;
}

void main() {
  group('Given the subset lint', () {
    final cases = <(String, String, int, DiagnosticSeverity)>[
      (
        'wonky_mixin',
        "import 'package:wonky/wonky.dart';\n\nmixin M {}\n",
        3,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_extension',
        "import 'package:wonky/wonky.dart';\n\nextension E on String {\n  int get twice => length * 2;\n}\n",
        3,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_late',
        "void f() {\n  late int x;\n}\n",
        2,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_typedef',
        "typedef F = int Function();\n",
        1,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_generator',
        "Iterable<int> f() sync* {\n  yield 1;\n}\n",
        1,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_await_for',
        "Future<void> f(Stream<int> s) async {\n  await for (final x in s) {}\n}\n",
        2,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_switch_expression',
        "int f(int x) {\n  return switch (x) { _ => 1 };\n}\n",
        2,
        DiagnosticSeverity.error,
      ),
      ('wonky_import', "import 'dart:io';\n", 1, DiagnosticSeverity.error),
      (
        'wonky_isolate',
        "import 'dart:isolate';\n",
        1,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_records_patterns',
        "Object f() {\n  return (1, 2);\n}\n",
        2,
        DiagnosticSeverity.warning,
      ),
      (
        'wonky_top_level_state',
        "var counter = 0;\n",
        1,
        DiagnosticSeverity.warning,
      ),
      (
        'wonky_custom_function_signature',
        "/// @customfunction\nObject? DOUBLE(int x) => x * 2;\n",
        2,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_builtin_shadowed',
        "/// @customfunction\nObject? sum(Object? x) => x;\n",
        2,
        DiagnosticSeverity.warning,
      ),
      (
        'wonky_trigger_signature',
        "void onEdit(Object a, Object b) {}\n",
        1,
        DiagnosticSeverity.error,
      ),
      (
        'wonky_reserved_name',
        "Object? wonkyInvoke() => null;\n",
        1,
        DiagnosticSeverity.error,
      ),
    ];
    for (final (code, source, line, severity) in cases) {
      test(
        'when the source triggers $code then it is reported on line $line',
        () {
          final d = _only(source, code);
          expect(d.line, line);
          expect(d.file, 'main.dart');
          expect(d.severity, severity);
          expect(d.message, isNotEmpty);
        },
      );
    }

    test('when a cell is read in a loop then a hint suggests values', () {
      final d = _only(
        "import 'package:wonky/wonky.dart';\n\nvoid f() {\n  for (var i = 1; i < 10; i++) {\n    SpreadsheetApp.activeSheet.getRangeAt(i, 1).value;\n  }\n}\n",
        'wonky_loop_read',
      );
      expect(d.severity, DiagnosticSeverity.info);
      expect(d.line, 5);
    });

    test('when importing packages other than wonky then it is an error', () {
      expect(
        _diagnostics("import 'package:http/http.dart';\n").map((d) => d.code),
        contains('wonky_import'),
      );
    });

    test('when importing a project file then it is allowed', () {
      final r = _compiler.compile(const [
        ScriptSourceFile(
          'main.dart',
          "import 'utils.dart';\n\nint f() => helper();\n",
        ),
        ScriptSourceFile('utils.dart', 'int helper() => 1;\n'),
      ]);
      expect(r.ok, isTrue, reason: '${r.diagnostics}');
    });
  });

  group('Given the compiler', () {
    test(
      'when the source has a syntax error then it is reported with its position',
      () {
        final d = _diagnostics(
          'void f() {\n  int x = ;\n}\n',
        ).where((d) => d.isError).first;
        expect(d.line, 2);
        expect(d.file, 'main.dart');
      },
    );

    test('when two files declare the same function then it is an error', () {
      final r = _compiler.compile(const [
        ScriptSourceFile('main.dart', 'void f() {}\n'),
        ScriptSourceFile('utils.dart', 'void f() {}\n'),
      ]);
      expect(
        r.diagnostics.map((d) => d.code),
        contains('wonky_duplicate_function'),
      );
      expect(r.ok, isFalse);
    });

    test('when file names are invalid then it is an error', () {
      final r = _compiler.compile(const [ScriptSourceFile('Main.dart', '')]);
      expect(r.diagnostics.map((d) => d.code), contains('wonky_project'));
    });

    test(
      'when an unknown member is used then the build fails with a compile error',
      () {
        final r = _compiler.compile(const [
          ScriptSourceFile(
            'main.dart',
            "import 'package:wonky/wonky.dart';\n\nvoid f() {\n  SpreadsheetApp.noSuchThing();\n}\n",
          ),
        ]);
        expect(r.ok, isFalse);
        expect(r.diagnostics.single.code, 'wonky_compile');
        expect(r.diagnostics.single.file, 'main.dart');
      },
    );

    test(
      'when compiling the same sources then the source hash is the same',
      () {
        const a = [
          ScriptSourceFile('b.dart', 'void b() {}'),
          ScriptSourceFile('a.dart', 'void a() {}'),
        ];
        const b = [
          ScriptSourceFile('a.dart', 'void a() {}'),
          ScriptSourceFile('b.dart', 'void b() {}'),
        ];
        expect(ScriptCompiler.sourceHash(a), ScriptCompiler.sourceHash(b));
        expect(
          ScriptCompiler.sourceHash(a),
          isNot(
            ScriptCompiler.sourceHash(const [
              ScriptSourceFile('a.dart', 'void a() {} '),
            ]),
          ),
        );
      },
    );

    test(
      'when compiling then exports describe functions, triggers and scopes',
      () {
        final r = _compiler.compile(const [
          ScriptSourceFile('main.dart', '''
import 'package:wonky/wonky.dart';

/// Converts Celsius to Fahrenheit.
///
/// @customfunction
/// @param celsius A temperature in °C.
/// @return The temperature in °F.
/// @example =TO_F(A2:A20)
Object? TO_F(Object? celsius) => celsius is num ? celsius * 9 / 5 + 32 : null;

void onOpen(OpenEvent e) {}

void fetchRates() {
  UrlFetchApp.fetch('https://example.com');
}

void _private() {}

int needsArg(int x) => x;
'''),
        ]);
        expect(r.ok, isTrue, reason: '${r.diagnostics}');
        final e = r.exports;
        expect(e.functions.map((f) => f.name), [
          'TO_F',
          'onOpen',
          'fetchRates',
          'needsArg',
        ]);
        final toF = e.function('TO_F')!;
        expect(toF.customFunction!.formulaName, 'TO_F');
        expect(toF.customFunction!.examples, ['=TO_F(A2:A20)']);
        expect(toF.doc, 'Converts Celsius to Fahrenheit.');
        expect(toF.params.single.doc, 'A temperature in °C.');
        expect(toF.line, 9);
        expect(e.triggers['onOpen'], 'package:script/main.dart');
        expect(e.triggers['onEdit'], isNull);
        expect(
          e.scopes,
          containsAll(['spreadsheet.current', 'ui', 'external_request']),
        );
        expect(e.function('needsArg')!.runnable, isFalse);
        expect(e.runnableFunctions.map((f) => f.name), [
          'onOpen',
          'fetchRates',
        ]);
        expect(e.customFunctions.keys, ['TO_F']);
        expect(ScriptExports.decode(e.encode()).function('TO_F')!.line, 9);
      },
    );

    test(
      'when analyzing unsaved content then lint diagnostics come back without bytecode',
      () {
        final d = _compiler.analyze('main.dart', 'extension E on int {}\n');
        expect(d.map((x) => x.code), ['wonky_extension']);
      },
    );
  });
}
