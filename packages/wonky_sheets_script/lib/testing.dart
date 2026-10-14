/// Test helpers for scripts (15 §2): compile scripts, build workbooks with a
/// script project and run functions against them. Imports the compiler, so
/// only use it from tests and tools.
library;

import 'dart:async';

import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/model_testing.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sync_models/ids.dart';

import 'compiler.dart';
import 'src/testing/conformance.dart';
import 'wonky_sheets_script.dart';

export 'package:wonky_sheets_core/model_testing.dart';
export 'src/testing/conformance.dart';

final _programs = <String, ScriptProgram>{};

/// Compiles [files] (name → source) and returns the program; throws a
/// [StateError] listing the errors when the build fails. Results are cached
/// by source hash.
ScriptProgram compileScript(Map<String, String> files) {
  final sources = [
    for (final e in files.entries) ScriptSourceFile(e.key, e.value),
  ];
  final hash = ScriptCompiler.sourceHash(sources);
  final cached = _programs[hash];
  if (cached != null) return cached;
  final result = const ScriptCompiler().compile(sources);
  final program = result.program;
  if (program == null) {
    throw StateError(
      'Script did not compile:\n${result.diagnostics.join('\n')}',
    );
  }
  return _programs[hash] = program;
}

/// A test user.
const testUser = ScriptUser(
  id: '00000000-0000-4000-8000-0000000000aa',
  email: 'anna@example.com',
  name: 'Anna',
);

/// The default conformance fixture (see [ConformanceCase]).
WorkbookModel conformanceWorkbook() => scriptWorkbook((b) {
  b.sheet('Sheet1', rows: 20, cols: 8);
  b.values('A1', [
    [1, 2, 3],
    [4, 5, 6],
    ['a', 'b', 'c'],
  ]);
  b.sheet('Sheet2', rows: 10, cols: 5);
});

/// Runs case [index] of [conformanceCorpus] on a fresh fixture with [runner];
/// returns the mismatches.
Future<List<String>> runConformanceCase(
  int index,
  ScriptProgram program,
  ScriptRunner runner,
) async {
  final c = conformanceCorpus[index];
  final model = conformanceWorkbook();
  final bench = ScriptTestBench(model, runner: runner);
  try {
    final r = await bench.run(
      program,
      conformanceFunctionName(index),
      kind: c.kind,
      role: c.role,
      scopes: c.scopes,
      isServer: c.isServer,
    );
    return checkConformance(
      c,
      status: r.status.name,
      result: r.result,
      errorType: r.error?.type,
      errorMessage: r.error?.message,
      logs: [for (final l in r.logs) l.message],
      valueOf: bench.value,
    );
  } finally {
    bench.dispose();
  }
}

/// Builds a workbook with one script project (id `script-project`).
WorkbookModel scriptWorkbook(void Function(WorkbookBuilder b) build) {
  final b = WorkbookBuilder();
  build(b);
  b.row(SheetsTables.scriptProject, 'script-project', {
    ScriptCols.name: 'Test script',
    ScriptCols.settingsJson: '{}',
    ScriptCols.createdAt: DateTime.utc(2026),
    'spreadsheetId': b.spreadsheetId,
  });
  return b.build();
}

/// A recording [ScriptUiDelegate] with scripted dialog answers.
final class FakeScriptUi implements ScriptUiDelegate {
  /// Answers returned by [showDialog], in order (default: OK / Yes).
  final List<ScriptDialogResponse> answers = [];

  /// Dialogs shown.
  final List<ScriptDialogRequest> dialogs = [];

  /// Toasts shown.
  final List<String> toasts = [];

  /// Menus added.
  final List<ScriptMenu> menus = [];

  /// Ranges selected.
  final List<ResolvedRange> selections = [];

  /// Sheets activated.
  final List<String> activatedSheets = [];

  @override
  Future<ScriptDialogResponse> showDialog(ScriptDialogRequest request) async {
    dialogs.add(request);
    if (answers.isNotEmpty) return answers.removeAt(0);
    return ScriptDialogResponse(
      request.buttons == ScriptButtonSet.yesNo ||
              request.buttons == ScriptButtonSet.yesNoCancel
          ? ScriptButton.yes
          : ScriptButton.ok,
    );
  }

  @override
  void showToast(String message, {String? title, double timeoutSeconds = 5}) =>
      toasts.add(title == null ? message : '$title: $message');

  @override
  void addMenu(ScriptMenu menu) => menus.add(menu);

  @override
  void select(ResolvedRange range) => selections.add(range);

  @override
  void activateSheet(String sheetId) => activatedSheets.add(sheetId);
}

/// A [UrlFetcher] with scripted responses keyed by URL.
final class FakeUrlFetcher implements UrlFetcher {
  /// Responses by URL.
  final Map<String, FetchResponseData> responses = {};

  /// Requests made.
  final List<FetchRequestData> requests = [];

  @override
  Future<FetchResponseData> fetch(
    FetchRequestData request, {
    required bool customFunction,
  }) async {
    requests.add(request);
    final r = responses[request.url];
    if (r == null) {
      throw FetchFailure('No response scripted for ${request.url}');
    }
    return r;
  }
}

/// Runs scripts against an in-memory workbook (conformance tests, tools).
final class ScriptTestBench {
  /// Creates a bench over [model].
  ScriptTestBench(
    this.model, {
    ScriptRunner? runner,
    this.userId = '00000000-0000-4000-8000-0000000000aa',
  }) : runner = runner ?? InlineScriptRunner() {
    access = ModelWorkbookAccess(
      model: model,
      userId: userId,
      ids: SeededIdGenerator(7),
    );
  }

  /// The workbook.
  final WorkbookModel model;

  /// Runner used by [run].
  final ScriptRunner runner;

  /// Auth user id of the caller.
  final String userId;

  /// Workbook access (applied plans accumulate here).
  late final ModelWorkbookAccess access;

  /// User properties shared by every run of the bench.
  final MemoryPropertyStore userProperties = MemoryPropertyStore();

  /// The sheet id of [name].
  String sheetId(String name) => model.sheetByName(name)!.id;

  /// Runs [function] of [program].
  Future<ExecutionResult> run(
    ScriptProgram program,
    String function, {
    ExecutionKind kind = ExecutionKind.editor,
    Role role = Role.editor,
    List<Object?> args = const [],
    ScriptEvent? event,
    ScriptUiDelegate? ui,
    UrlFetcher? fetcher,
    Set<String> scopes = const {},
    bool isServer = false,
    ScriptSelection? selection,
    ExecutionLimits? limits,
    bool authorized = true,
  }) {
    final host = ScriptHost(
      workbook: access,
      context: ExecutionContext(
        kind: kind,
        activeUser: testUser,
        role: role,
        grantedScopes: scopes,
        authorized: authorized,
        isServer: isServer,
        selection: selection,
        spreadsheetUrl: 'https://wonky.test/sheets/s/${model.spreadsheetId}',
      ),
      limits:
          limits ??
          (kind.isCustomFunction
              ? ExecutionLimits.customFunction
              : ExecutionLimits.client),
      ui: ui,
      fetcher: fetcher,
      userProperties: userProperties,
      knownFunctions: {for (final f in program.exports.functions) f.name},
      timeZones: const FixedOffsetResolver(),
    );
    return runScript(
      runner: runner,
      host: host,
      program: program,
      functionName: function,
      args: args,
      event: event,
    );
  }

  /// Computed value of [a1] (on the first sheet unless qualified).
  Object? value(String a1) {
    final r = model.parseA1(a1, contextSheetId: model.sheets.first.id);
    final v = access.engine.valueAt(r.sheetId, r.rect.top, r.rect.left);
    return CellValueConverter(
      timeZone: model.spreadsheet.timeZone,
      timeZones: const FixedOffsetResolver(),
    ).toScript(v);
  }

  /// Releases the engine binding.
  void dispose() => access.dispose();
}
