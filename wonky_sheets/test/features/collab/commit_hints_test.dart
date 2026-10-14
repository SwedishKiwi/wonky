import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show PresenceHints, PresenceRoster;
import 'package:wonky_sheets/features/collab/hints/commit_hints.dart';

import 'support/collab_harness.dart';

void main() {
  group('Given an open spreadsheet with commit hints', () {
    late CollabHarness s;

    setUp(() async {
      s = await CollabHarness.open();
      s.presenceRepo.emit(
        PresenceRoster(
          sessionId: 'me',
          participants: [
            participant('me', userId: 1, name: 'Anna'),
            participant('bo'),
          ],
        ),
      );
      await pumpEventQueue();
    });
    tearDown(() => s.dispose());

    Map<String, Object?> lastHint() {
      final hints = s.presenceRepo.updates.expand((u) => u.hints ?? const []);
      return (jsonDecode(hints.last) as Map).cast<String, Object?>();
    }

    test('when a cell is committed then a cell hint with its stored content '
        'is sent', () async {
      await s.type('B2', '42');
      await pumpEventQueue();
      await Future<void>.delayed(Duration.zero);

      final h = lastHint();
      final (r, c) = s.ids('B2');
      expect(h['t'], 'cell');
      expect((h['rowId'], h['colId'], h['content']), (r, c, 'n:42'));
    });

    test(
      'when a formula is committed then its computed value is sent too',
      () async {
        await s.type('A1', '2');
        await s.type('A2', '=A1*21');
        await Future<void>.delayed(Duration.zero);

        // Both commits ran in one turn: one range hint.
        final h = lastHint();
        expect(h['t'], 'range');
        final formula = (h['cells']! as List).cast<Map>().singleWhere(
          (c) => (c['content'] as String).startsWith('='),
        );
        expect(formula['v'], 'n:42');
      },
    );

    test('when a hint arrives then the cell shows the hinted value until the '
        'synced change arrives', () async {
      final (r, c) = s.ids('C3');
      s.presenceRepo.emit(
        PresenceHints(
          sessionId: 'bo',
          hints: [
            jsonEncode({
              't': 'cell',
              'sheetId': s.sheetId,
              'rowId': r,
              'colId': c,
              'content': 's:Hello',
              'hlcMillis': 1,
            }),
          ],
        ),
      );
      await pumpEventQueue();
      expect(s.text('C3'), 'Hello');
      expect(s.model.cellAt(s.sheetId, 2, 2), isNull);

      // A local edit of the cell wins over the hint.
      await s.type('C3', 'Mine');
      await Future<void>.delayed(Duration.zero);
      expect(s.collab.hints.cells, isEmpty);
      expect(s.text('C3'), 'Mine');
    });

    test('when 5 s pass then the hint expires', () async {
      final (r, c) = s.ids('D4');
      final t0 = DateTime(2026, 10, 1, 12);
      withClock(Clock.fixed(t0), () {
        s.collab.hints.receive(
          PresenceHints(
            sessionId: 'bo',
            hints: [
              jsonEncode({
                't': 'range',
                'sheetId': s.sheetId,
                'cells': [
                  {'rowId': r, 'colId': c, 'content': 'n:7'},
                  {'rowId': 'unknown', 'colId': c, 'content': 'n:8'},
                ],
                'hlcMillis': 1,
              }),
            ],
          ),
        );
      });
      expect(s.collab.hints.cells, hasLength(1));
      expect(s.text('D4'), '7');

      withClock(
        Clock.fixed(t0.add(CommitHints.lifetime + const Duration(seconds: 1))),
        s.collab.hints.expire,
      );
      expect(s.collab.hints.cells, isEmpty);
      expect(s.text('D4'), '');
    });

    test('when the sender leaves then their hints are dropped', () async {
      final (r, c) = s.ids('A5');
      s.collab.hints.receive(
        PresenceHints(
          sessionId: 'bo',
          hints: [
            jsonEncode({
              't': 'cell',
              'sheetId': s.sheetId,
              'rowId': r,
              'colId': c,
              'content': 'b:1',
            }),
          ],
        ),
      );
      expect(s.collab.hints.cells, hasLength(1));
      s.presenceRepo.emit(
        PresenceRoster(
          sessionId: 'me',
          participants: [participant('me', userId: 1, name: 'Anna')],
        ),
      );
      await pumpEventQueue();
      expect(s.collab.hints.cells, isEmpty);
    });
  });
}
