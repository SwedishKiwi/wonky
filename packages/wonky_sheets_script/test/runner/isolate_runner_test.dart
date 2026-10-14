import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:wonky_sheets_script/native.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

const _source = '''
import 'package:wonky/wonky.dart';

Object? ask() {
  final ui = SpreadsheetApp.ui;
  final a = ui.alert('Continue?', title: 'Check', buttons: ButtonSet.yesNo);
  final p = ui.prompt('Your name');
  return [a.name, p.selectedButton.name, p.responseText];
}

Object? fetchJson() {
  final res = UrlFetchApp.fetch('https://api.example.com/rates',
      FetchOptions(headers: {'Accept': 'application/json'}));
  final data = res.json() as Map;
  return [res.statusCode, data['eur']];
}

Object? fetchMissing() {
  try {
    UrlFetchApp.fetch('https://api.example.com/missing');
    return 'no';
  } on UrlFetchException catch (e) {
    return e.statusCode;
  }
}

Object? fetchMuted() =>
    UrlFetchApp.fetch('https://api.example.com/missing', FetchOptions(muteHttpExceptions: true)).statusCode;

Object? fetchAll() => UrlFetchApp.fetchAll([
      FetchRequest('https://api.example.com/rates'),
      FetchRequest('https://api.example.com/missing', FetchOptions(muteHttpExceptions: true)),
    ]).map((r) => r.statusCode).toList();

void logs() {
  Logger.log('a');
  print('b');
  Logger.warn('c');
}

int helper(int x) {
  if (x > 2) {
    throw StateError('too big');
  }
  return x;
}

Object? failDeep() => helper(5);
''';

FetchResponseData _response(int status, String body) => FetchResponseData(
  statusCode: status,
  bytes: Uint8List.fromList(utf8.encode(body)),
  contentText: body,
);

/// The isolate sandbox with UI waits and URL fetches (09 §8.2, §8.3).
void main() {
  late ScriptProgram program;
  late IsolateScriptRunner runner;
  setUpAll(() {
    program = compileScript({'main.dart': _source});
    runner = IsolateScriptRunner();
  });
  tearDownAll(() => runner.close());

  ScriptTestBench bench() =>
      ScriptTestBench(conformanceWorkbook(), runner: runner);

  test(
    'when the script shows an alert and a prompt then it waits for the answers',
    () async {
      final ui = FakeScriptUi()
        ..answers.addAll(const [
          ScriptDialogResponse(ScriptButton.no),
          ScriptDialogResponse(ScriptButton.ok, 'Bo'),
        ]);
      final r = await bench().run(program, 'ask', ui: ui);
      expect(r.result, ['no', 'ok', 'Bo']);
      expect(ui.dialogs.first.title, 'Check');
      expect(ui.dialogs.first.buttons, ScriptButtonSet.yesNo);
      expect(ui.dialogs.last.prompt, isTrue);
    },
  );

  group('Given URL fetches', () {
    late FakeUrlFetcher fetcher;
    setUp(() {
      fetcher = FakeUrlFetcher()
        ..responses['https://api.example.com/rates'] = _response(
          200,
          '{"eur": 1.1}',
        )
        ..responses['https://api.example.com/missing'] = _response(404, 'nope');
    });

    test('when the scope is granted then the response is returned', () async {
      final r = await bench().run(
        program,
        'fetchJson',
        fetcher: fetcher,
        scopes: {'external_request'},
      );
      expect(r.result, [200, 1.1]);
      expect(fetcher.requests.single.headers, {'Accept': 'application/json'});
      expect(r.counters.fetchCalls, 1);
    });

    test(
      'when the scope is missing then ScopeNotGrantedException is thrown',
      () async {
        final r = await bench().run(program, 'fetchJson', fetcher: fetcher);
        expect(r.error!.type, 'ScopeNotGrantedException');
        expect(fetcher.requests, isEmpty);
      },
    );

    test(
      'when the response is an HTTP error then UrlFetchException carries the status',
      () async {
        final r = await bench().run(
          program,
          'fetchMissing',
          fetcher: fetcher,
          scopes: {'external_request'},
        );
        expect(r.result, 404);
      },
    );

    test(
      'when muteHttpExceptions is set then the error response is returned',
      () async {
        final r = await bench().run(
          program,
          'fetchMuted',
          fetcher: fetcher,
          scopes: {'external_request'},
        );
        expect(r.result, 404);
      },
    );

    test('when fetching several URLs then all responses come back', () async {
      final r = await bench().run(
        program,
        'fetchAll',
        fetcher: fetcher,
        scopes: {'external_request'},
      );
      expect(r.result, [200, 404]);
    });

    test(
      'when there is no connection then OfflineException is thrown',
      () async {
        final r = await bench().run(
          program,
          'fetchJson',
          scopes: {'external_request'},
        );
        expect(r.error!.type, 'OfflineException');
      },
    );
  });

  test(
    'when the script logs then logs and print output arrive in order',
    () async {
      final r = await bench().run(program, 'logs');
      expect(r.logs.map((l) => '${l.level.name}:${l.message}'), [
        'info:a',
        'info:b',
        'warn:c',
      ]);
    },
  );

  test(
    'when the script fails then the stack points at the source lines',
    () async {
      final r = await bench().run(program, 'failDeep');
      expect(r.error!.type, 'StateError');
      expect(r.error!.message, contains('too big'));
      final frames = r.error!.frames;
      expect(frames.first.function, 'helper()');
      expect(frames.first.file, 'main.dart');
      // Frames point at the declaration of the function (patch DE-1).
      expect(frames.first.line, 40);
      expect(frames[1].function, 'failDeep()');
    },
  );
}
