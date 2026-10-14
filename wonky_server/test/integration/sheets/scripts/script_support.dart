import 'package:serverpod/serverpod.dart';
import 'package:wonky_server/src/platform/config/wonky_config.dart';
import 'package:wonky_server/src/sheets/changelog/change_log_consumer.dart';
import 'package:wonky_server/src/sheets/headless/headless_workbook_provider.dart';
import 'package:wonky_server/src/sheets/scripts/script_service.dart';
import 'package:wonky_server/src/sheets/scripts/script_triggers.dart';
import 'package:wonky_sheets_script/native.dart';

/// Turns scripting on for a test group (config/test.yaml keeps it off) and
/// runs change-triggered work inline.
void enableScripting() {
  WonkyConfig.current = WonkyConfig(
    scriptingEnabled: true,
    scriptServerTimeoutMs: 20000,
  );
  ScriptTriggerService.runInline = true;
  ScriptService.runnerOverride ??= IsolateScriptRunner();
  if (!ChangeLogConsumer.plugins.any((p) => p is ScriptChangeLogPlugin)) {
    ChangeLogConsumer.plugins.add(ScriptChangeLogPlugin());
  }
}

/// Undoes [enableScripting].
Future<void> disableScripting() async {
  ChangeLogConsumer.plugins.removeWhere((p) => p is ScriptChangeLogPlugin);
  await ScriptService.runnerOverride?.close();
  ScriptService.runnerOverride = null;
  ScriptService.proxyOverride = null;
  ScriptTriggerService.runInline = false;
  WonkyConfig.current = WonkyConfig();
  HeadlessWorkbookProvider.clear();
}

/// The space uuid of a drive item uuid string.
UuidValue uuidOf(String s) => UuidValue.fromString(s);
