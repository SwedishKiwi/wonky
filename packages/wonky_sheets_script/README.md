# wonky_sheets_script

Dart scripting for Wonky Sheets on [dart_eval](../../third_party/dart_eval)
(spec: [`specs/wonky_sheets/09-scripting.md`](../../specs/wonky_sheets/09-scripting.md)).
Pure Dart; used by the Sheets app (runtime only) and the server (runtime and compiler).

| Library | Who imports it | Content |
|---------|----------------|---------|
| `wonky_sheets_script.dart` | app, server | Script host over the workbook model, runners, custom functions, macro recorder, protocol, exports/diagnostics models, `ScriptSession`. Web-safe (no analyzer, no `dart:io`). |
| `native.dart` | desktop app, server | `IsolateScriptRunner`: sandbox isolates with a synchronous `Mailbox` bridge. |
| `compiler.dart` | **server only** | `ScriptCompiler` (subset lint, exports, dart_eval compile). Pulls in the analyzer; Flutter apps must not import it (`tool/check_dependencies.dart`). |
| `testing.dart` | tests, tools | `compileScript`, `ScriptTestBench`, `FakeScriptUi`, `FakeUrlFetcher`, the conformance corpus. |

## How it works

```
script (dart_eval bytecode)                     host (app or server)
  package:wonky/wonky.dart  ── wonkyHostCall ──►  ScriptHost ──► WorkbookAccess (model + planner)
  (interpreted API classes)   (one bridge fn)      │  handles, roles, scopes, quotas, logs
                                                    ├─► ScriptUiDelegate (alerts, toasts, menus)
                                                    ├─► UrlFetcher (server proxy)
                                                    └─► PropertyStore / TriggerStore
```

- **The API is Dart source** (`lib/src/api/api_source.dart`): `SpreadsheetApp`, `Spreadsheet`,
  `Sheet`, `Range`, `Ui`, `Menu`, `Session`, `UrlFetchApp`, `Utilities`, `Logger`,
  `PropertiesService`, `ScriptApp`, event classes and exceptions are small interpreted classes
  compiled together with every script. Each member forwards to the host through one bridge
  function (`wonkyHostCall(target, method, args)`). Only `CellError` is a bridged class.
  This replaces the `@Bind` + `dart_eval bind` approach of the first spec draft: one source of
  truth, typed exceptions scripts can catch, no generated bindings.
- **Handles**: API objects hold host handle ids (per execution); ranges remember row/column
  ids, so they keep pointing at their cells when rows are inserted.
- **Writes** become `SheetsOperation`s planned by `SheetsMutationPlanner` and applied to the
  model at once (scripts read their own writes). `ExecutionResult.applied` lists the plans;
  the caller persists them (app: `SheetsWriter`, one undo step "Script: fn"; server:
  `SheetsBulkWriter`). Cell-sized writes are batched in the guest (09 §8.2.4); their errors
  surface on the next call that reaches the host.
- **Runners** (`ScriptRunner`):
  - `IsolateScriptRunner` (desktop, server): one guest isolate per runner, synchronous
    `Mailbox` calls, watchdog for the time limit (UI waits excluded) and the process RSS.
  - `InlineScriptRunner` (web, tests): runs on the calling thread; the time limit is enforced
    by dart_eval checkpoints (patch DE-2). Alerts/prompts and `UrlFetchApp` are unavailable
    (they need to wait asynchronously); see 09 §8.2.3.
- **Custom functions**: `ScriptCustomFunctions` implements the formula engine's
  `CustomFunctionProvider`: cache hit → value; miss → `#LOADING` and one batch per
  recalculation pass, evaluated by a `CustomFunctionEvaluator` (pure executions, 3 s each).

## Client-facing API (for the app's `ScriptService`)

One `ScriptSession` per open spreadsheet:

```dart
final session = ScriptSession(
  workbook: myWorkbookAccess,          // WorkbookAccess over the live WorkbookModel
  uiRunner: IsolateScriptRunner(),      // web: InlineScriptRunner()
  pureRunner: IsolateScriptRunner(),    // custom functions
  user: ScriptUser(id: authUserId, email: email, name: name),
  role: role,
  ui: myScriptUiDelegate,              // dialogs, toasts, menus, selection
  fetcher: myServerFetcher,            // forwards to ScriptEndpoint.urlFetch
  userProperties: myUserPropertyStore, // ScriptUserProperty rows (personal space)
  grantedScopes: grantFromServer,      // ScriptEndpoint.authorization
  spreadsheetUrl: url,
);

// Last good build (ScriptBuild.lastGood*; bytecode via ScriptEndpoint.bytecode):
session.setProgram(ScriptProgram(buildHash: hash, bytecode: bytes,
    exports: ScriptExports.decode(build.lastGoodExportsJson!)));

// Formula engine: FormulaEngine(customFunctions: session.customFunctions, …);
// autocomplete: session.customFunctions.names / .help(name).

session.selection = ScriptSelection(sheetId: id, ranges: [rect], currentCell: pos);
await session.fireSimpleTrigger(ExecutionKind.onOpen, const OpenEventData());
session.menus;                                  // menus added by onOpen
final r = await session.run('archive', kind: ExecutionKind.menu);
r.applied;                                      // persist as one undo step
r.status; r.error?.frames; r.logs;              // error card, log panel
session.executions.listen(uploadBatch);         // ScriptEndpoint.reportExecutions
```

What the app implements:

- `ScriptUiDelegate` — `showDialog` (alert/prompt as `WonkyFormDialog`), `showToast`
  (`ShadSonner`), `addMenu` (`ScriptMenuRegistry`), `select`, `activateSheet`.
- `WorkbookAccess` — `ModelWorkbookAccess` works on the app's `WorkbookModel` (pass the app's
  `ModelEngineBinding`); listen with `onApplied` or read `ExecutionResult.applied` and
  persist through `SheetsWriter`.
- `UrlFetcher` — call `ScriptEndpoint.urlFetch(spreadsheetUuid, request.toJson())`; throw
  `FetchFailure(code: 'offline')` when offline.
- `PropertyStore` for user properties.
- The macro recorder: forward each recordable operation to
  `MacroRecorder.record(op, modelBeforeApply)`; on *Save* call
  `MacroRecorder.functionNameFor`, `functionSource` and `MacroRecorder.appendTo`
  (`macros.dart`), then write the file and the `Macro` row.

Server endpoints (`ScriptEndpoint`, endpoint name `script`): `compile`, `analyze`,
`bytecode`, `run` (Run on server), `executions`, `reportExecutions`, `urlFetch`,
`authorization`, `authorize`, `revokeAuthorization`, `notifyOpen`.

## Tests

`dart test` — the conformance corpus (`lib/src/testing/conformance.dart`, ~150 cases, run on
both runners), compiler and lint diagnostics, sandbox escape, time/memory limits, custom
functions through the formula engine, the macro recorder, sessions and the isolate bridge
(UI waits, fetches, stack traces). The server runs the same corpus against a workbook loaded
from the database (`wonky_server/test/integration/sheets/scripts`).
