import 'dart:typed_data';

import 'package:wonky_client/wonky_client.dart'
    show ScriptExecution, ScriptExecutionStatus, UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets/features/macros/macro_service.dart';
import 'package:wonky_sheets/features/scripts/runtime/script_runners.dart';
import 'package:wonky_sheets/features/scripts/script_backend.dart';
import 'package:wonky_sheets/features/scripts/script_project.dart';
import 'package:wonky_sheets/features/scripts/script_service.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sheets_script/testing.dart' show compileScript;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import '../../support/sheets_harness.dart';

/// The server as the app sees it, in memory: `compile` builds the synced
/// sources of the workbook with the real compiler (`testing.dart`).
class FakeScriptBackend implements ScriptBackend {
  FakeScriptBackend(this.model);

  final WorkbookModel Function() model;
  ScriptProgram? last;
  Set<String> granted = {};
  final List<ScriptExecution> reported = [];
  int compiles = 0;
  int revokes = 0;

  @override
  Future<Uint8List?> bytecode(UuidValue item) async => last?.bytecode;

  @override
  Future<ScriptCompileResult> compile(UuidValue item) async {
    compiles++;
    final files = {
      for (final f in ScriptProjectRows.files(model()))
        ScriptProjectRows.nameOf(f): ScriptProjectRows.sourceOf(f),
    };
    try {
      final p = compileScript(files);
      last = p;
      return ScriptCompileResult(
        ok: true,
        sourceHash: p.buildHash,
        exportsJson: p.exports.encode(),
      );
    } on StateError catch (e) {
      return ScriptCompileResult(
        ok: false,
        sourceHash: 'failed',
        diagnostics: [
          ScriptDiagnostic(
            severity: DiagnosticSeverity.error,
            code: 'compile',
            message: e.message,
            file: 'main.dart',
            line: 1,
            column: 1,
          ),
        ],
      );
    }
  }

  @override
  Future<List<ScriptDiagnostic>> analyze(
    UuidValue item,
    String fileName,
    String source,
  ) async => const [];

  @override
  Future<ServerRunResult> runOnServer(UuidValue item, String functionName) =>
      throw UnimplementedError();

  @override
  Future<List<ScriptExecution>> executions(
    UuidValue item, {
    String? functionName,
    ScriptExecutionStatus? status,
    int limit = 50,
  }) async => [
    for (final r in reported.reversed)
      if ((functionName == null || r.functionName == functionName) &&
          (status == null || r.status == status))
        r,
  ];

  @override
  Future<void> reportExecutions(
    UuidValue item,
    List<ScriptExecution> rows,
  ) async => reported.addAll(rows);

  @override
  Future<FetchResponseData> urlFetch(
    UuidValue item,
    FetchRequestData request, {
    required bool customFunction,
  }) => throw const FetchFailure('no network in tests');

  @override
  Future<Set<String>> authorization(UuidValue item) async => {...granted};

  @override
  Future<Set<String>> authorize(UuidValue item, List<String> scopes) async =>
      granted = {...scopes};

  @override
  Future<void> revokeAuthorization(UuidValue item) async {
    revokes++;
    granted = {};
  }

  @override
  Future<void> notifyOpen(UuidValue item) async {}

  @override
  Future<String> revertChange(String changeId) async => 'revert-$changeId';
}

/// A harness with a script project of [files] built and installed (inline
/// runner, fake backend).
class ScriptHarness {
  ScriptHarness._(this.s, this.svc, this.backend);

  static Future<ScriptHarness> open(
    Map<String, String> files, {
    Role role = Role.owner,
  }) async {
    createScriptRunner = InlineScriptRunner.new;
    late SheetsHarness s;
    final fake = FakeScriptBackend(() => s.model);
    ScriptService.backendFactory = (_) => fake;
    s = SheetsHarness.open(role: role);
    final svc = ScriptService.of(s.editor);
    // As the editor screen does: dynamic macro commands.
    MacroService.of(s.editor);
    final w = ScriptProjectWriter(s.editor)..ensureProject(null);
    for (final e in files.entries) {
      final f = ScriptProjectRows.fileNamed(s.model, e.key);
      if (f == null) {
        w.createFile(null, e.key, source: e.value);
      } else {
        w.saveSource(f.id, e.value);
      }
    }
    await svc.compile();
    await pumpScripts();
    return ScriptHarness._(s, svc, fake);
  }

  final SheetsHarness s;
  final ScriptService svc;
  final FakeScriptBackend backend;

  Future<void> dispose() => s.dispose();
}

/// Lets queued script work (onOpen, triggers, custom function batches) run.
Future<void> pumpScripts([int rounds = 5]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
