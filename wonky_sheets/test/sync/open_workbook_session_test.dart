import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_sheets/features/sync/sheets_sessions.dart';

import '../support/sheets_harness.dart';

void main() {
  test('Given the data layer is installed but its replica fails to open '
      'when a spreadsheet opens then it fails instead of showing an empty '
      'in-memory spreadsheet', () async {
    final s = SheetsHarness.open();
    SheetsData.install(
      s.services,
      open: (_) async => throw StateError('sqlite3.wasm failed to load'),
    );

    await expectLater(
      openWorkbookSession(
        s.services,
        UuidValue.fromString('01a13917-7cdf-7a38-9d0c-6c7f8ba7db90'),
        readyTimeout: const Duration(milliseconds: 200),
      ),
      throwsA(isA<SheetsDataUnavailableException>()),
    );
  });
}
