import 'package:wonky_client/wonky_client.dart' show ScriptRuntimeKind;
import 'package:wonky_sheets_script/native.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// Desktop: one sandbox isolate per runner.
ScriptRunner createPlatformRunner() => IsolateScriptRunner();

const runtimeKind = ScriptRuntimeKind.clientDesktop;
