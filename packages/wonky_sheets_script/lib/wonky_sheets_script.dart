/// Dart scripting for Wonky Sheets (specs/wonky_sheets/09-scripting.md):
/// the Wonky Script API bridge, script hosts over the workbook model,
/// runners, custom functions and the macro recorder.
///
/// Client-safe (web and desktop): no analyzer, no `dart:io`. The compiler is
/// in `compiler.dart` (server only), the isolate sandbox in `native.dart`
/// (desktop and server).
library;

export 'src/api/api_index.dart';
export 'src/api/script_completion.dart';
export 'src/api/api_source.dart'
    show wonkyApiVersion, wonkyApiLibrary, wonkyHostLibrary;
export 'src/build/script_exports.dart';
export 'src/compiler/diagnostics.dart';
export 'src/guest/guest_bridge.dart' show GuestTransport, ScriptAbort;
export 'src/guest/guest_runtime.dart'
    show
        ExecutionStatus,
        GuestOutcome,
        GuestRequest,
        GuestRuntime,
        ScriptFailure,
        ScriptStackFrame;
export 'src/host/cell_values.dart';
export 'src/host/limits.dart';
export 'src/host/lock_cache.dart';
export 'src/host/model_stores.dart';
export 'src/host/script_host.dart';
export 'src/host/services.dart';
export 'src/host/workbook_access.dart';
export 'src/protocol/messages.dart';
export 'src/protocol/values.dart';
export 'src/runner/execution.dart';
export 'src/runner/inline_runner.dart';
export 'src/custom_functions/custom_functions.dart';
export 'src/macro/macro_recorder.dart';
export 'src/session/script_session.dart';
