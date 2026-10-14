import 'package:dart_eval/dart_eval.dart';
import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sheets_script/compiler.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// Sandbox escape and security tests (09 §21.3).
void main() {
  group('Given scripts that try to reach the host system', () {
    for (final import in [
      'dart:io',
      'dart:isolate',
      'dart:ffi',
      'dart:html',
      'dart:js_interop',
      'package:http/http.dart',
      'package:wonky/src/host.dart',
    ]) {
      test('when importing $import then the build fails', () {
        final r = const ScriptCompiler().compile([
          ScriptSourceFile('main.dart', "import '$import';\n\nvoid f() {}\n"),
        ]);
        expect(r.ok, isFalse);
        expect(
          r.diagnostics.map((d) => d.code),
          anyOf(contains('wonky_import'), contains('wonky_isolate')),
        );
      });
    }

    test(
      'when bytecode bypasses the lint and touches dart:io then the runtime denies it',
      () async {
        // Compiled without the Wonky lint, as a forged build would be.
        final compiler = Compiler()
          ..addPlugin(const WonkyCompilerPlugin())
          ..entrypoints.addAll([
            'package:wonky/wonky.dart',
            'package:script/__exports.dart',
          ]);
        final program = compiler.compile({
          'script': {
            'main.dart': '''
import 'dart:io';
Object? steal() => File('/etc/hosts').readAsStringSync();
''',
            '__exports.dart': '''
import 'main.dart';
Object? wonkyInvoke(String name, List<Object?> args, Map<String, Object?>? event) => steal();
''',
          },
        });
        final bench = ScriptTestBench(conformanceWorkbook());
        final r = await bench.run(
          ScriptProgram(
            buildHash: 'forged',
            bytecode: program.write(),
            exports: const ScriptExports(
              apiVersion: 1,
              functions: [
                ScriptFunctionInfo(
                  name: 'steal',
                  library: 'package:script/main.dart',
                  line: 2,
                ),
              ],
            ),
          ),
          'steal',
        );
        expect(r.status, ExecutionStatus.failed);
        expect(
          r.error!.message,
          contains("Permission 'filesystem:read' denied"),
        );
      },
    );

    test(
      'when calling a missing member dynamically then nothing escapes',
      () async {
        final program = compileScript({
          'main.dart': '''
import 'package:wonky/wonky.dart';
Object? probe() {
  dynamic ss = SpreadsheetApp.active;
  return ss.noSuchMethodHere();
}
''',
        });
        final r = await ScriptTestBench(
          conformanceWorkbook(),
        ).run(program, 'probe');
        expect(r.status, ExecutionStatus.failed);
      },
    );
  });

  group('Given a script host', () {
    late ModelWorkbookAccess access;
    setUp(() {
      access = ModelWorkbookAccess(
        model: conformanceWorkbook(),
        userId: testUser.id,
      );
    });
    tearDown(() => access.dispose());

    ScriptHost host({Role role = Role.editor}) => ScriptHost(
      workbook: access,
      context: ExecutionContext(
        kind: ExecutionKind.editor,
        activeUser: testUser,
        role: role,
      ),
    );

    test('when a forged handle id is used then the host rejects it', () {
      final reply = host().handle(const HostCall(999, 'range.values', []));
      expect((reply as HostReply).error!.code, 'invalid_argument');
    });

    test(
      'when a handle of another execution is used then the host rejects it',
      () {
        final first = host();
        final h =
            (first.handle(const HostCall(0, 'ss.getRange', ['A1:B2']))
                        as HostReply)
                    .value!
                as int;
        expect(
          (first.handle(HostCall(h, 'range.values', const [])) as HostReply)
              .isError,
          isFalse,
        );
        final second = host();
        final reply =
            second.handle(HostCall(h, 'range.values', const [])) as HostReply;
        expect(reply.error!.code, 'invalid_argument');
      },
    );

    test('when a sheet handle is used as a range then the host rejects it', () {
      final h = host();
      final sheet =
          (h.handle(const HostCall(0, 'app.activeSheet', [])) as HostReply)
                  .value!
              as int;
      final reply =
          h.handle(HostCall(sheet, 'range.values', const [])) as HostReply;
      expect(reply.error!.code, 'invalid_argument');
    });

    test('when an unknown host method is called then it fails', () {
      final reply =
          host().handle(const HostCall(0, 'system.exec', ['rm'])) as HostReply;
      expect(reply.error!.code, 'not_found');
    });
  });

  group('Given a protected range', () {
    late ScriptProgram program;
    setUpAll(() {
      program = compileScript({
        'main.dart': '''
import 'package:wonky/wonky.dart';
Object? writeA1() {
  SpreadsheetApp.active.getRange('A1').value = 99;
  SpreadsheetApp.flush();
  return SpreadsheetApp.active.getRange('A1').value;
}
Object? writeE5() {
  SpreadsheetApp.active.getRange('E5').value = 99;
  SpreadsheetApp.flush();
  return SpreadsheetApp.active.getRange('E5').value;
}
''',
      });
    });

    Future<ExecutionResult> run(
      String fn, {
      Role role = Role.editor,
      List<String> editors = const [],
    }) {
      final model = conformanceWorkbook();
      final bench = ScriptTestBench(model);
      bench.access.apply(
        AddProtection(
          model.sheets.first.id,
          range: const GridRect(0, 0, 2, 2),
          description: 'Header',
          editors: editors,
        ),
      );
      return bench.run(program, fn, role: role);
    }

    test(
      'when an editor writes into it then PermissionDeniedException is thrown',
      () async {
        final r = await run('writeA1');
        expect(r.error?.type, 'PermissionDeniedException');
      },
    );

    test('when an editor writes outside it then the write succeeds', () async {
      expect((await run('writeE5')).result, 99);
    });

    test('when the owner writes into it then the write succeeds', () async {
      expect((await run('writeA1', role: Role.owner)).result, 99);
    });

    test(
      'when a listed editor writes into it then the write succeeds',
      () async {
        expect((await run('writeA1', editors: [testUser.id])).result, 99);
      },
    );
  });
}
