import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show RevertResult, SheetsImportProgress, SheetsImportStatus, UuidValue;
import 'package:wonky_sheets/features/history/server_change_undo.dart';
import 'package:wonky_sheets/features/import/import_pipeline.dart';
import 'package:wonky_sheets/features/import/server_import.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../support/sheets_harness.dart';

final _job = UuidValue.fromString('0190a000-0000-7000-8000-000000000001');
final _upload = UuidValue.fromString('0190a000-0000-7000-8000-000000000002');
final _change = UuidValue.fromString('0190a000-0000-7000-8000-000000000003');

/// A server that finishes the job after two progress events (or ends it
/// with [endStatus]).
class _FakeServer implements ServerImportApi {
  _FakeServer({this.endStatus = SheetsImportStatus.done});

  final SheetsImportStatus endStatus;
  ImportOptions? options;
  String? activeSheetId;
  String? uploadedName;
  int cancels = 0;

  SheetsImportProgress _p(
    SheetsImportStatus status, {
    int done = 0,
    int total = 4,
  }) => SheetsImportProgress(
    jobId: _job,
    status: status,
    done: done,
    total: total,
    queuePosition: 0,
    reportJson: status == SheetsImportStatus.done
        ? jsonEncode(
            ImportReport(
              fileName: 'big.csv',
              sheets: const [
                ImportSheetReport(
                  name: 'big',
                  sheetId: 'sheet-x',
                  rows: 2,
                  columns: 2,
                  cells: 4,
                ),
              ],
              warnings: const [],
            ).toJson(),
          )
        : null,
    changeId: status == SheetsImportStatus.done ? _change : null,
    sheetIds: status == SheetsImportStatus.done ? const ['sheet-x'] : null,
    error: status == SheetsImportStatus.failed ? 'Too many cells.' : null,
  );

  @override
  Future<UuidValue> upload(ImportFileData file) async {
    uploadedName = file.name;
    return _upload;
  }

  @override
  Future<UuidValue> importInto(
    UuidValue spreadsheet,
    UuidValue upload,
    ImportOptions options, {
    String? activeSheetId,
  }) async {
    this.options = options;
    this.activeSheetId = activeSheetId;
    return _job;
  }

  @override
  Stream<SheetsImportProgress> watch(UuidValue job) async* {
    yield _p(SheetsImportStatus.parsing);
    yield _p(SheetsImportStatus.writing, done: 2);
    yield _p(endStatus, done: 4);
  }

  @override
  Future<void> cancel(UuidValue job) async => cancels++;

  @override
  Future<ImportFileData> driveFile(UuidValue item, String name) async =>
      ImportFileData(name: '$name.xlsx', bytes: Uint8List(0));
}

void main() {
  late SheetsHarness s;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  Map<String, Object?> args(String location, {String? cell}) => {
    'fileName': 'big.csv',
    'text': 'a,b\n1,2\n',
    'onServer': true,
    'options': {'location': location, 'cell': ?cell},
  };

  group('Given a file imported by a server job', () {
    test('when the job finishes then the report is shown and one undo step '
        'reverts the server change', () async {
      final server = _FakeServer();
      ServerImportApi.install(s.services, server);
      final reverted = <String>[];
      s.services.undo.registerHandler(
        SheetsServerChangeHandler(
          s.services,
          revert: (id) async {
            reverted.add(id);
            return RevertResult(
              changeId: _upload,
              revertedCells: 4,
              skipped: const [],
            );
          },
        ),
      );

      final r = await s.run('sheets.file.import', args('insertSheets'));

      expect(r.isOk, isTrue, reason: r.message);
      expect(server.uploadedName, 'big.csv');
      expect(server.activeSheetId, s.sheetId);
      expect((r.data as Map?)?['changeId'], _change.uuid);
      expect(lastImportReport.value?.cellCount, 4);
      // Nothing was written locally: the rows arrive through sync.
      expect(s.model.sheets, hasLength(1));

      await s.undo();
      expect(reverted, [_change.uuid]);
    });

    test('when replacing data at the selected cell then the server gets the '
        'cell as A1', () async {
      final server = _FakeServer();
      ServerImportApi.install(s.services, server);
      await s.select('C7');

      await s.run('sheets.file.import', args('replaceAtCell'));

      expect(server.options?.cell, 'C7');
    });

    test('when the job fails then the command fails with its error', () async {
      ServerImportApi.install(
        s.services,
        _FakeServer(endStatus: SheetsImportStatus.failed),
      );

      final r = await s.run('sheets.file.import', args('append'));

      expect(r.isOk, isFalse);
      expect(r.message, contains('Too many cells.'));
    });

    test('when the job ends cancelled then the command is cancelled', () async {
      ServerImportApi.install(
        s.services,
        _FakeServer(endStatus: SheetsImportStatus.cancelled),
      );

      final r = await s.run('sheets.file.import', args('append'));

      expect(r.isOk, isFalse);
      expect(s.services.undo.canUndo.value, isFalse);
    });

    test('when sheets.file.cancelImport names a job then the server is '
        'asked to cancel it', () async {
      final server = _FakeServer();
      ServerImportApi.install(s.services, server);

      final r = await s.run('sheets.file.cancelImport', {'jobId': _job.uuid});

      expect(r.isOk, isTrue, reason: r.message);
      expect(server.cancels, 1);
      // Without a running job the command is disabled.
      await expectLater(s.run('sheets.file.cancelImport'), throwsA(anything));
    });

    test('when there is no server then onServer fails', () async {
      final r = await s.run('sheets.file.import', args('append'));

      expect(r.isOk, isFalse);
    });
  });

  group('Given the client thresholds', () {
    test('when a CSV has more than 300k cells then it runs on the server', () {
      ServerImportApi.install(s.services, _FakeServer());
      final f = ImportFileData(name: 'a.csv', bytes: utf8.encode('a,b'));

      expect(runsOnServer(s.services, f, cells: 10), isFalse);
      expect(runsOnServer(s.services, f, cells: 300001), isTrue);
    });

    test('when the device is offline then it never runs on the server', () {
      ServerImportApi.install(s.services, _FakeServer());
      s.services.connectivity.forceOffline(true);
      final f = ImportFileData(name: 'a.csv', bytes: utf8.encode('a,b'));

      expect(runsOnServer(s.services, f, cells: 999999), isFalse);
      s.services.connectivity.forceOffline(false);
    });
  });
}
