import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_client/wonky_client.dart'
    show CommentAnchorKind, CommentStatus;
import 'package:wonky_sheets/features/comments/sheets_comments.dart';

import '../collab/support/collab_harness.dart';

void main() {
  group('Given a Sheets comment anchor', () {
    test('when a cell or range anchor is encoded then it parses back', () {
      const cell = SheetsCommentAnchor(sheetId: 's', r1: 'r', c1: 'c');
      const range = SheetsCommentAnchor(
        sheetId: 's',
        r1: 'a',
        c1: 'b',
        r2: 'c',
        c2: 'd',
      );
      final p1 = SheetsCommentAnchor.parse(
        CommentAnchorKind.cell,
        cell.encode(),
      )!;
      final p2 = SheetsCommentAnchor.parse(
        CommentAnchorKind.range,
        range.encode(),
      )!;
      expect((p1.isCell, p1.r1, p1.c1), (true, 'r', 'c'));
      expect((p2.r1, p2.c1, p2.r2, p2.c2), ('a', 'b', 'c', 'd'));
      expect(jsonDecode(cell.encode())['v'], 1);
      expect(
        SheetsCommentAnchor.parse(CommentAnchorKind.textRange, cell.encode()),
        isNull,
      );
    });
  });

  group('Given a spreadsheet with a comment on B4', () {
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

    test('when created then the anchor is the cell by ids with its value '
        'quoted, and the indicator sits on B4', () {
      final t = s.comments.thread(thread)!;
      expect(t.anchorKind, CommentAnchorKind.cell);
      final a = SheetsCommentAnchor.parse(t.anchorKind, t.anchorJson)!;
      expect((a.r1, a.c1), s.ids('B4'));
      expect(t.quotedText, 'Pending');
      expect(s.collab.comments.threadsAt(s.sheetId, 3, 1), hasLength(1));
      expect(s.collab.comments.labelFor(t), 'Sheet1!B4 · Pending');
    });

    test('when rows are inserted above then the comment stays on the same '
        'cell (now B6)', () async {
      await s.select('A1:A2');
      await s.run('sheets.rows.insertAbove');
      final t = s.comments.thread(thread)!;
      expect(s.collab.comments.labelFor(t), startsWith('Sheet1!B6'));
      expect(s.collab.comments.threadsAt(s.sheetId, 5, 1), hasLength(1));
    });

    test('when its row is deleted then it is no longer placed, and undo '
        'brings it back', () async {
      await s.select('A4');
      await s.run('sheets.rows.delete');
      expect(s.collab.comments.bySheet[s.sheetId] ?? const [], isEmpty);
      expect(
        s.collab.comments.labelFor(s.comments.thread(thread)!),
        contains('was deleted'),
      );
      await s.h.undo();
      expect(s.collab.comments.threadsAt(s.sheetId, 3, 1), hasLength(1));
    });

    test('when undoing the creation then the thread is deleted', () async {
      await s.h.undo();
      expect(s.commentRepo.threads, isEmpty);
    });

    test('when navigating to the next comment then it wraps in reading '
        'order', () async {
      await s.type('D9', 'x');
      await s.select('D9');
      await s.run('shell.comments.create', {'body': 'Second'});
      await s.select('A1');

      await s.run('sheets.comments.next');
      expect(s.editor.activeA1, 'B4');
      await s.run('sheets.comments.next');
      expect(s.editor.activeA1, 'D9');
      await s.run('sheets.comments.next');
      expect(s.editor.activeA1, 'B4');
      await s.run('sheets.comments.previous');
      expect(s.editor.activeA1, 'D9');
    });

    test('when resolved then the indicator disappears; hiding indicators '
        'is a toggle', () async {
      await s.run('sheets.view.toggleCommentIndicators');
      expect(s.collab.comments.indicatorsOn, isFalse);
      await s.run('sheets.view.toggleCommentIndicators');
      expect(s.collab.comments.indicatorsOn, isTrue);
      await s.run('shell.comments.resolve', {'threadUuid': thread});
      expect(s.comments.thread(thread)!.status, CommentStatus.resolved);
      expect(s.collab.comments.threadsAt(s.sheetId, 3, 1), isEmpty);
    });

    test('when a range is selected then the new comment anchors to the '
        'range', () async {
      await s.select('C2:D3');
      final a = s.collab.comments.anchorForSelection()!;
      expect(a.kind, CommentAnchorKind.range);
      expect(a.label, 'Sheet1!C2:D3');
    });
  });
}
