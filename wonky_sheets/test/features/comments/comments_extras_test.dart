import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_sheets/features/comments/sheets_comments.dart';

import '../collab/support/collab_harness.dart';

void main() {
  group('Given comments on two sheets', () {
    late CollabHarness s;
    late String first;
    late String second;

    Future<String> comment(String a1, String body) async {
      await s.select(a1);
      final r = await s.run('shell.comments.create', {'body': body});
      return (r.data! as Map)['threadUuid'] as String;
    }

    setUp(() async {
      s = await CollabHarness.open();
      first = await comment('B4', 'On sheet 1');
      await s.run('sheets.sheet.add');
      second = await comment('A1', 'On sheet 2');
    });
    tearDown(() => s.dispose());

    test('when the scope is This sheet then only the active sheet\'s '
        'threads are listed, and All sheets groups them by sheet', () async {
      final c = s.comments;
      expect(c.scope, SheetsComments.scopeAll);
      expect([for (final t in c.visible) t.uuid.uuid], [first, second]);
      expect(s.collab.comments.groupOf(c.thread(first)!), 'Sheet1');
      expect(s.collab.comments.groupOf(c.thread(second)!), 'Sheet2');

      await s.run('sheets.comments.openPanel', {'scope': 'sheet'});
      expect(c.scope, SheetsComments.scopeSheet);
      expect([for (final t in c.visible) t.uuid.uuid], [second]);

      // The scope follows the active sheet.
      s.editor.activateSheet(s.model.sheets.first.id);
      await pumpEventQueue();
      expect([for (final t in c.visible) t.uuid.uuid], [first]);
    });
  });

  group('Given a comment on B4', () {
    late CollabHarness s;
    late String thread;

    setUp(() async {
      s = await CollabHarness.open();
      await s.type('B4', 'Pending');
      await s.select('B4');
      final r = await s.run('shell.comments.create', {'body': 'Check this'});
      thread = (r.data! as Map)['threadUuid'] as String;
    });
    tearDown(() => s.dispose());

    String? where() =>
        s.collab.comments.referenceOf(s.comments.thread(thread)!);

    test('when B4 is cut and pasted to F10 then the comment moves to F10, '
        'and one undo puts both back', () async {
      await s.select('B4');
      await s.run('sheets.edit.cut');
      await s.select('F10');
      await s.run('sheets.edit.paste');
      await pumpEventQueue();
      expect(where(), 'Sheet1!F10');
      expect(
        s.commentRepo.threads[thread]!.anchorJson,
        s.comments.thread(thread)!.anchorJson,
      );
      expect(s.text('F10'), 'Pending');

      await s.h.undo();
      await pumpEventQueue();
      expect(where(), 'Sheet1!B4');
      expect(s.text('B4'), 'Pending');
    });

    test('when B4 is copied and pasted then the comment stays', () async {
      await s.select('B4');
      await s.run('sheets.edit.copy');
      await s.select('F10');
      await s.run('sheets.edit.paste');
      await pumpEventQueue();
      expect(where(), 'Sheet1!B4');
    });

    test('when a comment is created without a body then the composer opens '
        'next to the cell instead of the panel', () async {
      await s.select('D2');
      await s.run('shell.comments.create');
      expect(s.comments.draftAnchor, isNotNull);
      expect(s.services.panels.isOpen(ShellPanels.comments), isFalse);
      s.comments.cancelDraft();
    });
  });

  group('Given the app is offline', () {
    late CollabHarness s;

    setUp(() async {
      s = await CollabHarness.open();
      await s.type('C3', 'x');
      s.services.connectivity.forceOffline(true);
    });
    tearDown(() async {
      s.services.connectivity.forceOffline(false);
      await s.dispose();
    });

    test('when a comment and a reply are written then they show as pending '
        'and are posted when the connection is back', () async {
      await s.select('C3');
      final r = await s.run('shell.comments.create', {'body': 'Offline'});
      final id = (r.data! as Map)['threadUuid'] as String;
      await s.run('shell.comments.reply', {'threadUuid': id, 'body': 'More'});

      expect(s.comments.isPending(id), isTrue);
      expect(s.comments.thread(id)!.comments, hasLength(2));
      expect(
        s.comments.isPendingComment(s.comments.thread(id)!.comments.first),
        isTrue,
      );
      expect(s.commentRepo.threads, isEmpty);
      expect(s.collab.comments.threadsAt(s.sheetId, 2, 2), hasLength(1));
      // Persisted for a reload.
      expect(s.comments.pendingOps, hasLength(2));

      s.services.connectivity.forceOffline(false);
      await pumpEventQueue(times: 50);
      expect(s.comments.pendingOps, isEmpty);
      expect(s.comments.isPending(id), isFalse);
      expect(s.commentRepo.threads[id]!.comments, hasLength(2));
      expect(s.comments.thread(id)!.comments.first.body, 'Offline');
    });

    test('when an offline comment is undone then it is dropped without '
        'reaching the server', () async {
      await s.select('C3');
      final r = await s.run('shell.comments.create', {'body': 'Oops'});
      final id = (r.data! as Map)['threadUuid'] as String;
      await s.h.undo();
      await pumpEventQueue();
      expect(s.comments.thread(id), isNull);
      expect(s.comments.pendingOps, isEmpty);

      s.services.connectivity.forceOffline(false);
      await pumpEventQueue(times: 50);
      expect(s.commentRepo.threads, isEmpty);
    });
  });
}
