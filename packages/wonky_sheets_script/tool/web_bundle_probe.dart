// Measures the web bundle cost of the script runtime (Sheets 09 §3.1):
//
//   dart compile js -O4 -o /tmp/probe.js tool/web_bundle_probe.dart
//   dart compile wasm -O2 -o /tmp/probe.wasm tool/web_bundle_probe.dart
//
// and compare with the same command for an empty `main`. The probe uses what
// a client needs: InlineScriptRunner (GuestRuntime + dart_eval Runtime +
// WonkyRuntimePlugin) and ScriptHost over a WorkbookModel.
import 'dart:typed_data';

import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

Future<void> main(List<String> args) async {
  final model = WorkbookModel(spreadsheetId: 'x');
  final access = ModelWorkbookAccess(model: model, userId: 'u');
  final host = ScriptHost(
    workbook: access,
    context: const ExecutionContext(
      kind: ExecutionKind.editor,
      activeUser: ScriptUser(id: 'u', email: '', name: ''),
      role: Role.editor,
    ),
  );
  final r = await runScript(
    runner: InlineScriptRunner(),
    host: host,
    program: ScriptProgram(
      buildHash: 'h',
      bytecode: Uint8List(args.length),
      exports: ScriptExports.decode(args.isEmpty ? '{}' : args.first),
    ),
    functionName: args.length > 1 ? args[1] : 'f',
  );
  print(r.status);
}
