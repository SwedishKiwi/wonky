import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sync_kit/rows.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart';

import '../support/kit_harness.dart';

void main() {
  group('Given an empty replica and a writer', () {
    late SyncReplica replica;
    late RecordingWriter writer;
    final file = space(0x101);
    setUp(() async {
      replica = await openTestReplica();
      writer = RecordingWriter(replica);
      await grantLocally(replica, file);
    });

    test('when a plan is applied then its rows are stored, one change-log '
        'entry carries its summary and the space is marked dirty', () async {
      final plan = MutationPlan(
        label: 'Create',
        summary: JsonChangeSummary({
          'kinds': ['create'],
        }),
        changes: [rootRow(file), childRow(file, 0), childRow(file, 1)],
      );

      await writer.apply(
        plan,
        spaceId: file.uuid,
        actorKind: 'mcp',
        sessionId: 's1',
      );

      expect(await replica.rowCounts(file), {'spreadsheet': 1, 'sheet': 2});
      expect(writer.logs.single.summaryJson, '{"kinds":["create"]}');
      expect(writer.logs.single.actorKind, 'mcp');
      expect(writer.logs.single.spaceId, file);
      expect(await replica.dirtySpaces(), [file]);
    });

    test('when changes without a plan are written then the summary comes '
        'from the writer', () async {
      await writer.write(
        spaceId: file,
        changes: [rootRow(file)],
        label: 'Undo',
        actorKind: 'user',
        sessionId: 's1',
      );

      expect(writer.logs.single.summaryJson, '{"count":1}');
      expect(writer.logs.single.label, 'Undo');
    });

    test('when a row is updated then only the named column changes', () async {
      await writer.write(
        spaceId: file,
        changes: [rootRow(file, title: 'Old')],
        label: 'Create',
        actorKind: 'user',
        sessionId: 's1',
      );

      await writer.write(
        spaceId: file,
        changes: [
          RowChange.update(
            'spreadsheet',
            file.uuid,
            {'title': 'Old'},
            {'title': 'New'},
          ),
        ],
        label: 'Rename',
        actorKind: 'user',
        sessionId: 's1',
      );

      final rows = await replica.readRows({
        'spreadsheet': {file},
      });
      expect(rows['spreadsheet']![file.uuid], containsPair('title', 'New'));
      expect(rows['spreadsheet']![file.uuid], containsPair('locale', 'en_US'));
    });

    test('when a row is deleted and inserted again then it is revived with '
        'the same id', () async {
      await createFile(replica, writer, file);
      final row = childRow(file, 0);

      await writer.write(
        spaceId: file,
        changes: [row.inverse()],
        label: 'Delete',
        actorKind: 'user',
        sessionId: 's1',
      );
      expect(await replica.rowCounts(file), {'spreadsheet': 1});
      await writer.write(
        spaceId: file,
        changes: [row],
        label: 'Undo',
        actorKind: 'user',
        sessionId: 's1',
      );

      expect(await replica.hasRow('sheet', sheetId(file, 0)), isTrue);
    });
  });
}
