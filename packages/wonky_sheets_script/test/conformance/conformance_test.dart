import 'package:test/test.dart';
import 'package:wonky_sheets_script/native.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

/// The API conformance corpus (09 §21.1) on both native runners; the server
/// runs the same corpus against workbooks loaded from the database.
void main() {
  late ScriptProgram program;
  setUpAll(() => program = compileScript(conformanceProgramSource()));

  for (final (name, create) in <(String, ScriptRunner Function())>[
    ('inline runner', InlineScriptRunner.new),
    ('isolate runner', IsolateScriptRunner.new),
  ]) {
    group('Given the conformance corpus on the $name', () {
      late ScriptRunner runner;
      setUpAll(() => runner = create());
      tearDownAll(() => runner.close());

      for (var i = 0; i < conformanceCorpus.length; i++) {
        test(
          'when running "${conformanceCorpus[i].name}" then it conforms',
          () async {
            expect(await runConformanceCase(i, program, runner), isEmpty);
          },
        );
      }
    });
  }
}
