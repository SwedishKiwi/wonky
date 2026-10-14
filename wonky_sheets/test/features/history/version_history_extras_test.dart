import 'dart:convert';

import 'package:archive/archive.dart' show GZipEncoder;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart' show VersionHistoryScreen;
import 'package:wonky_client/wonky_client.dart'
    show ItemVersionView, UuidValue, VersionKind, VersionStorage;
import 'package:wonky_sheets/features/export/sheets_downloads.dart';
import 'package:wonky_sheets/features/history/sheets_version_view.dart';
import 'package:wonky_sheets/features/history/version_snapshots.dart';
import 'package:wonky_sheets/features/model/memory_workbook_session.dart';
import 'package:wonky_sheets/features/objects/objects_layer.dart';
import 'package:wonky_sheets_core/model.dart' hide ActorKind;
import 'package:shad/shad.dart' show ShadTheme;
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

ItemVersionView version(int id) => ItemVersionView(
  id: id,
  itemUuid: UuidValue.fromString(testItemUuid),
  kind: VersionKind.auto,
  createdAt: DateTime.utc(2026, 10, id),
  authors: [TestUsers.anna, TestUsers.bob],
  storageKind: VersionStorage.snapshotFile,
  sizeBytes: 100,
);

void main() {
  group('Given two versions edited by Anna and Bo', () {
    late SheetsHarness s;
    late List<int> v1;
    late List<int> v2;
    late String sheetId;
    late WorkbookModel model;

    setUp(() {
      s = SheetsHarness.open();
      final session = MemoryWorkbookSession.blank(
        itemUuid: UuidValue.fromString(testItemUuid),
      );
      model = session.model;
      sheetId = session.model.sheets.first.id;
      SheetsOperation set(int row, int col, String text) => SetCellInputs(
        sheetId: sheetId,
        row: row,
        col: col,
        inputs: [
          [CellInput.user(text)],
        ],
      );
      session.execute(set(0, 0, 'Region'));
      session.execute(set(1, 1, '10'));
      v1 = SnapshotCodec.encodeModel(
        session.model,
        capturedAt: DateTime.utc(2026, 10, 1),
      );
      session.execute(set(1, 1, '20'));
      session.execute(set(3, 2, 'New'));
      v2 = SnapshotCodec.encodeModel(
        session.model,
        capturedAt: DateTime.utc(2026, 10, 2),
      );
      final sheet = session.model.sheets.first;
      String row(int i) => sheet.rows.idAt(i);
      String col(int i) => sheet.columns.idAt(i);
      VersionSnapshots.clear();
      VersionSnapshots.fetch = (item, id) async => id == 1 ? v1 : v2;
      // B2 by Anna, C4 by Bo (later ranges win).
      SheetsVersionViewState.fetchChanges = (item, id) async => jsonEncode({
        'v': 1,
        'ranges': [
          {
            's': sheetId,
            'r1': row(0),
            'c1': col(0),
            'r2': row(3),
            'c2': col(2),
            'u': TestUsers.anna.id,
          },
          {
            's': sheetId,
            'r1': row(3),
            'c1': col(2),
            'r2': row(3),
            'c2': col(2),
            'u': TestUsers.bob.id,
          },
        ],
      });
      addTearDown(() {
        VersionSnapshots.fetch = null;
        VersionSnapshots.clear();
        SheetsVersionViewState.fetchChanges = null;
        SheetsVersionViewState.fetchServerDiff = null;
        SheetsVersionViewState.serverDiffCells = 500000;
        VersionHistoryScreen.showChanges.value = true;
      });
    });
    tearDown(() => s.dispose());

    Future<SheetsVersionViewState> show(
      WidgetTester tester, {
      bool dark = false,
      Size size = const Size(1200, 800),
    }) async {
      await pumpSheets(
        tester,
        s,
        dark: dark,
        size: size,
        child: SheetsVersionView(
          services: s.services,
          itemUuid: UuidValue.fromString(testItemUuid),
          version: version(2),
          previous: version(1),
          showChanges: true,
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pump();
      await tester.pump();
      return tester.state<SheetsVersionViewState>(
        find.byType(SheetsVersionView),
      );
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    for (final dark in [false, true]) {
      testWidgets('when shown (${dark ? 'dark' : 'light'}) then each changed '
          'cell has its author and color, and charts/images render through '
          'the objects host', (tester) async {
        final state = await show(tester, dark: dark);
        expect(state.changes, hasLength(2));
        final b2 = state.changes.first;
        final c4 = state.changes.last;
        expect(b2.authorId, TestUsers.anna.id);
        expect(c4.authorId, TestUsers.bob.id);
        final cs = ShadTheme.of(
          tester.element(find.byType(SheetsVersionView)),
        ).colorScheme;
        expect(state.colorOf(cs, b2), cs.presence(TestUsers.anna.colorIndex));
        expect(state.colorOf(cs, c4), cs.presence(TestUsers.bob.colorIndex));
        expect(state.colorOf(cs, null), cs.mutedForeground);
        expect(find.byType(SheetObjectsHost), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('sheets.version.authors')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    testWidgets('when the bar is 360 px wide then nothing overflows', (
      tester,
    ) async {
      await show(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets('when the version is big then the diff and the authors come '
        'from the server', (tester) async {
      SheetsVersionViewState.serverDiffCells = 0;
      final sheet = model.sheets.first;
      final diff = SnapshotDiff()
        ..cells.add(
          CellChange(
            sheetId,
            sheet.rows.idAt(1),
            sheet.columns.idAt(1),
            CellChangeKind.content,
          ),
        );
      var calls = 0;
      SheetsVersionViewState.fetchServerDiff = (item, id, prev) async {
        calls++;
        expect((id, prev), (2, 1));
        return GZipEncoder().encodeBytes(
          utf8.encode(
            jsonEncode({
              'diff': diff.toJson(),
              'a': [TestUsers.bob.id],
            }),
          ),
        );
      };
      final state = await show(tester);
      expect(calls, 1);
      expect(state.serverDiff, isTrue);
      expect(state.changes.single.authorId, TestUsers.bob.id);
      await close(tester);
    });

    testWidgets('when downloaded as CSV then the file holds the version\'s '
        'values', (tester) async {
      final state = await show(tester);
      late List<int> bytes;
      await tester.runAsync(() async {
        bytes = (await buildDownload(
          state.editor!,
          SheetsExportFormat.csv,
        )).bytes;
      });
      final text = utf8.decode(bytes);
      expect(text, contains('Region'));
      expect(text, contains('20'));
      await close(tester);
    });

    test('when Show changes is toggled by command then the history route '
        'follows', () async {
      expect(VersionHistoryScreen.showChanges.value, isTrue);
      final r = await s.run('sheets.history.toggleShowChanges');
      expect(r.isOk, isTrue);
      expect(VersionHistoryScreen.showChanges.value, isFalse);
      await s.run('sheets.history.toggleShowChanges');
      expect(VersionHistoryScreen.showChanges.value, isTrue);
    });
  });
}
