import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/board/report/board_report_dialog.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' hide BoardPostPage;
import 'package:wonky_ui/testing.dart';

import '../report/support/report_fakes.dart' as report;
import 'support/board_pump.dart';

/// The layout of Bugs & improvements matches the rest of the suite
/// (specs/16 §4.3–4.7): the settings page frame and content column, the
/// drive's filter bar and selection bar, and the shared dialog surface.
void main() {
  BoardTest? current;
  tearDown(() async {
    await current?.dispose();
    current = null;
  });

  FakeBoardRepository seeded() => FakeBoardRepository()
    ..seedPost(title: 'Dark mode for slides', area: BoardArea.slides, score: 5)
    ..seedPost(title: 'Comment threads in Sheets', score: 9);

  testWidgets('Given the board on a wide window then it is a settings-like '
      'page: the shared page frame and the 760 px content column', (
    tester,
  ) async {
    current = await pumpBoard(tester, '/improvements', board: seeded());

    expect(find.byType(ShellPageFrame), findsOneWidget);
    expect(byKey('shell.page.back'), findsOneWidget);
    expect(find.byType(AccountMenuButton), findsOneWidget);
    // 1440 px window: the column starts at (1440 − 760) / 2.
    expect(shellPageInset(1440), 340);
    expect(tester.getTopLeft(byKey('board.reportBug')).dx, 340);
    expect(tester.getTopRight(byKey('board.search')).dx, 1440 - 340);
    expect(tester.getTopLeft(byKey('board.filter.area')).dx, 340);
    // Rows are inset by their own 8 px: the vote control lines up inside.
    expect(
      tester.getTopLeft(byKey('board.row.1')).dx,
      340 - 8,
      reason: 'row tiles start 8 px before the column',
    );
    await settleTooltips(tester);
  });

  testWidgets('Given a 400 px window then the page uses 16 px gutters, the '
      'search goes full width and nothing overflows', (tester) async {
    current = await pumpBoard(
      tester,
      '/improvements',
      board: seeded(),
      size: const Size(400, 800),
    );

    expect(tester.getTopLeft(byKey('board.reportBug')).dx, 16);
    expect(tester.getSize(byKey('board.search')).width, 400 - 32);
    expect(byKey('board.contribute'), findsNothing);
    expect(tester.takeException(), isNull);
    await settleTooltips(tester);
  });

  testWidgets('Given a signed-out visitor then the frame offers Sign in in '
      'place of the account menu', (tester) async {
    current = await pumpBoard(
      tester,
      '/improvements',
      board: seeded(),
      signedIn: false,
    );

    expect(byKey('board.signIn'), findsOneWidget);
    expect(find.byType(AccountMenuButton), findsNothing);
    await settleTooltips(tester);
  });

  testWidgets('Given the post page then its content is in the settings '
      'column', (tester) async {
    final b = FakeBoardRepository()..seedPost(title: 'A post');
    current = await pumpBoard(tester, '/improvements/p/1', board: b);

    expect(find.byType(ShellPageBody), findsOneWidget);
    final body = tester.getRect(
      find
          .descendant(
            of: find.byType(ShellPageBody),
            matching: find.byType(Column),
          )
          .first,
    );
    expect(body.left, 340);
    expect(body.width, shellPageMaxWidth);
    await settleTooltips(tester);
  });

  testWidgets('Given an admin selecting posts then the selection bar '
      'replaces the filter bar in place, like the drive', (tester) async {
    final b = seeded()..isAdmin = true;
    current = await pumpBoard(tester, '/improvements', board: b);
    final rowTop = tester.getTopLeft(byKey('board.row.1')).dy;

    await tester.tap(byKey('board.select'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('board.row.1.select'));
    await tester.pumpAndSettle();

    expect(byKey('board.selectionBar'), findsOneWidget);
    expect(byKey('board.filterBar'), findsNothing);
    expect(tester.getTopLeft(byKey('board.row.1')).dy, rowTop);

    await tester.tap(byKey('board.selection.clear'));
    await tester.pumpAndSettle();
    expect(byKey('board.selectionBar'), findsNothing);
    expect(byKey('board.row.1.select'), findsNothing);
    await settleTooltips(tester);
  });

  group('Given the report dialog', () {
    Future<CommandTestHarness> open(WidgetTester tester, Size size) async {
      final h = report.reportHarness();
      addTearDown(h.dispose);
      await report.pumpReportShell(
        tester,
        h,
        const report.InvokeButton('shell.board.report'),
        size: size,
      );
      await tester.tap(report.key('test.invoke'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('when wide then it is 640 px with Cancel before the primary '
        'on one row', (tester) async {
      await open(tester, const Size(1280, 800));

      final dialog = report.key(BoardReportKeys.dialog);
      expect(tester.getSize(dialog).width, 640);
      final cancel = tester.getRect(report.key(BoardReportKeys.cancel));
      final post = tester.getRect(report.key(BoardReportKeys.post));
      expect(cancel.top, post.top);
      expect(cancel.right, lessThan(post.left));
    });

    testWidgets('when narrower than 600 px then it is full screen and the '
        'actions stack, the primary on top', (tester) async {
      await open(tester, const Size(400, 800));

      final dialog = report.key(BoardReportKeys.dialog);
      expect(tester.getSize(dialog), const Size(400, 800));
      final cancel = tester.getRect(report.key(BoardReportKeys.cancel));
      final post = tester.getRect(report.key(BoardReportKeys.post));
      expect(post.bottom, lessThanOrEqualTo(cancel.top));
      expect(post.width, cancel.width);
      expect(tester.takeException(), isNull);
    });
  });
}
