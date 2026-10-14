import 'package:wonky_client/wonky_client.dart' show ScriptRuntimeKind;
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// Web: the inline runner (no alerts/prompts or `UrlFetchApp`, 09 §8.2.3).
ScriptRunner createPlatformRunner() => InlineScriptRunner();

const runtimeKind = ScriptRuntimeKind.clientWeb;
