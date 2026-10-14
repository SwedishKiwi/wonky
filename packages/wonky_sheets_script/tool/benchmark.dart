// Script call overhead (Sheets 09 §2, §8.2): `dart run tool/benchmark.dart`.
import 'package:wonky_sheets_script/native.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

const _source = '''
import 'package:wonky/wonky.dart';

Object? loop() {
  var s = 0;
  for (var i = 0; i < 1000000; i++) {
    s += i;
  }
  return s;
}

Object? reads() {
  final r = SpreadsheetApp.active.getRange('A1');
  var n = 0;
  for (var i = 0; i < 10000; i++) {
    if (r.value != null) n++;
  }
  return n;
}

Object? writes() {
  final s = SpreadsheetApp.activeSheet;
  for (var i = 1; i <= 10000; i++) {
    s.getRangeAt(i % 100 + 1, 2).value = i;
  }
  return 0;
}

Object? bulkRead() => SpreadsheetApp.activeSheet.getRange('A1:J10000').values.length;

Object? bulkWrite() {
  final rows = <List<Object?>>[];
  for (var r = 0; r < 10000; r++) {
    rows.add([r, r * 2, 'x']);
  }
  SpreadsheetApp.activeSheet.getRange('A1:C10000').values = rows;
  return rows.length;
}
''';

Future<void> main() async {
  final program = compileScript({'main.dart': _source});
  for (final (name, runner) in <(String, ScriptRunner)>[
    ('inline', InlineScriptRunner()),
    ('isolate', IsolateScriptRunner()),
  ]) {
    for (final fn in ['loop', 'reads', 'writes', 'bulkRead', 'bulkWrite']) {
      final model = scriptWorkbook((b) {
        b.sheet('Sheet1', rows: 10000, cols: 10);
        b.values('A1', [
          for (var r = 0; r < 100; r++) [r, 'text'],
        ]);
      });
      final bench = ScriptTestBench(model, runner: runner);
      await bench.run(program, 'loop'); // warm up the guest
      final w = Stopwatch()..start();
      final r = await bench.run(
        program,
        fn,
        limits: const ExecutionLimits(timeout: Duration(minutes: 2)),
      );
      print(
        '$name $fn: ${w.elapsedMilliseconds} ms (${r.status.name}, '
        '${r.bridgeCalls} bridge calls, ${r.instructions} instructions)',
      );
      bench.dispose();
    }
    await runner.close();
  }
}
