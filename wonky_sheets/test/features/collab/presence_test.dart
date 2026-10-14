import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        PresenceFollowerCount,
        PresenceLeft,
        PresenceRoster,
        PresenceState,
        PresenceUpdated;
import 'package:wonky_sheets/features/collab/presence/presence_cursor.dart';
import 'package:wonky_sheets/features/collab/presence/sheets_presence_controller.dart';
import 'package:wonky_sheets_core/formula.dart' show GridRect;

import 'support/collab_harness.dart';

void main() {
  group('Given a Sheets presence cursor', () {
    test('when encoded and parsed then it round-trips', () {
      const c = SheetsPresenceCursor(
        sheetId: 'S1',
        activeRowId: 'r1',
        activeColId: 'c1',
        ranges: [PresenceRange(r1: 'r1', c1: 'c1', r2: 'r2', c2: 'c2')],
        editing: true,
        viewport: PresenceViewport(topRowId: 'r1', leftColId: 'c1', zoom: 1.5),
        following: 'other',
      );

      expect(SheetsPresenceCursor.tryParse(c.encode()), c);
    });

    test('when the JSON is not a Sheets cursor then parsing returns null', () {
      expect(SheetsPresenceCursor.tryParse('{"x":1}'), isNull);
      expect(SheetsPresenceCursor.tryParse('not json'), isNull);
      expect(SheetsPresenceCursor.tryParse(null), isNull);
    });
  });

  group('Given an open spreadsheet with presence', () {
    late CollabHarness s;

    setUp(() async => s = await CollabHarness.open());
    tearDown(() => s.dispose());

    test('when a range is mapped then ids become grid indices and unknown '
        'bounds fall back to the known one', () {
      final (r2, c2) = s.ids('B2');
      final (r4, c4) = s.ids('D4');
      expect(
        SheetsPresenceController.rectOf(
          s.sheet,
          PresenceRange(r1: r2, c1: c2, r2: r4, c2: c4),
        ),
        const GridRect(1, 1, 3, 3),
      );
      expect(
        SheetsPresenceController.rectOf(
          s.sheet,
          PresenceRange(r1: r2, c1: c2, r2: 'unknown', c2: c4),
        ),
        const GridRect(1, 1, 1, 3),
      );
      expect(
        SheetsPresenceController.rectOf(
          s.sheet,
          const PresenceRange(r1: 'x', c1: 'y', r2: 'x', c2: 'y'),
        ),
        isNull,
      );
      // Whole column (no row ids).
      expect(
        SheetsPresenceController.rectOf(s.sheet, PresenceRange(c1: c2, c2: c2)),
        GridRect(0, 1, s.sheet.rows.length - 1, 1),
      );
    });

    test(
      'when the selection changes then the cursor is sent with ids',
      () async {
        await s.select('C5');
        await Future<void>.delayed(const Duration(milliseconds: 150));

        final sent = s.presenceRepo.updates
            .map((u) => SheetsPresenceCursor.tryParse(u.cursorJson))
            .whereType<SheetsPresenceCursor>()
            .last;
        final (r, c) = s.ids('C5');
        expect(sent.sheetId, s.sheetId);
        expect((sent.activeRowId, sent.activeColId), (r, c));
        expect(sent.viewport, isNull);
      },
    );

    test('when another participant selects a cell then their cursor is '
        'mapped, described and jumping to them reveals it', () async {
      final (r, c) = s.ids('B4');
      final cursor = SheetsPresenceCursor(
        sheetId: s.sheetId,
        activeRowId: r,
        activeColId: c,
      ).encode();
      s.presenceRepo.emit(
        PresenceRoster(
          sessionId: 'me',
          participants: [participant('me', userId: 1, name: 'Anna')],
        ),
      );
      await pumpEventQueue();
      s.presenceRepo.emit(
        PresenceUpdated(
          sessionId: 'bo',
          state: PresenceState.active,
          cursorJson: cursor,
          mode: 'editing',
        ),
      );
      await pumpEventQueue();
      // Updated only applies to known participants: join first.
      expect(s.collab.presence.cursors.value, isEmpty);

      s.presenceRepo.emit(
        PresenceRoster(
          sessionId: 'me',
          participants: [
            participant('me', userId: 1, name: 'Anna'),
            participant('bo', cursorJson: cursor),
          ],
        ),
      );
      await pumpEventQueue();

      final list = s.collab.presence.cursorsOn(s.sheetId);
      expect(list.single.displayName, 'Bo Stone');
      expect(
        s.presence.avatars().firstWhere((p) => p.sessionId == 'bo').detail,
        'Editing Sheet1!B4',
      );
      expect(s.collab.presence.jumpTo('bo'), isTrue);
      expect(s.collab.presence.flashSession, 'bo');
    });

    test('when following a participant then their sheet and cell are '
        'tracked until the local selection changes', () async {
      final (r, c) = s.ids('B4');
      String cursorOn(String sheetId) => SheetsPresenceCursor(
        sheetId: sheetId,
        activeRowId: r,
        activeColId: c,
      ).encode();
      await s.run('sheets.sheet.add');
      final second = s.editor.activeSheetId;
      await s.run('sheets.sheet.activate', {
        'sheetId': s.model.sheets.first.id,
      });
      final first = s.editor.activeSheetId;
      expect(first, isNot(second));
      s.presenceRepo.emit(
        PresenceRoster(
          sessionId: 'me',
          participants: [
            participant('me', userId: 1, name: 'Anna'),
            participant('bo', cursorJson: cursorOn(first)),
          ],
        ),
      );
      await pumpEventQueue();

      final r1 = await s.run('sheets.presence.follow', {'sessionId': 'bo'});
      expect(r1.isOk, isTrue);
      expect(s.presence.following, 'bo');

      s.presenceRepo.emit(
        PresenceUpdated(
          sessionId: 'bo',
          state: PresenceState.active,
          cursorJson: cursorOn(second),
          mode: 'editing',
        ),
      );
      await pumpEventQueue();
      expect(s.editor.activeSheetId, second);

      await s.select('H20');
      expect(s.collab.presence.following.value, isNull);
      expect(s.presence.following, isNull);
    });

    test('when followed then the viewport is sent, and a participant who '
        'leaves is no longer drawn', () async {
      s.presenceRepo.emit(
        PresenceRoster(
          sessionId: 'me',
          participants: [
            participant('me', userId: 1, name: 'Anna'),
            participant(
              'bo',
              cursorJson: SheetsPresenceCursor(sheetId: s.sheetId).encode(),
            ),
          ],
        ),
      );
      await pumpEventQueue();
      expect(s.collab.presence.cursors.value, hasLength(1));

      s.presenceRepo.emit(PresenceFollowerCount(count: 1));
      await pumpEventQueue();
      expect(s.presence.followerCount, 1);
      s.presenceRepo.emit(PresenceLeft(sessionId: 'bo'));
      await pumpEventQueue();
      expect(s.collab.presence.cursors.value, isEmpty);
    });
  });
}
