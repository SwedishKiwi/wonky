import 'package:wonky_client/wonky_client.dart' show ScriptRuntimeKind;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

import 'script_runners_native.dart'
    if (dart.library.js_interop) 'script_runners_web.dart'
    as platform;

/// Creates the runner of one guest (09 §8.8): a sandbox isolate on desktop,
/// the inline runner on the web (09 §8.2.3). Tests replace it.
ScriptRunner Function() createScriptRunner = platform.createPlatformRunner;

/// Where client executions run (`ScriptExecution.runtime`).
ScriptRuntimeKind get clientRuntimeKind => platform.runtimeKind;
