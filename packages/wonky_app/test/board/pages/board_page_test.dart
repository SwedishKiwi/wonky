import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/screen_pump.dart';
import 'support/board_pump.dart';

/// The board page (specs/16 §4.4): tabs with counts, filters, sort,
/// paging, the vote control (incl. keyboard), the signed-out banner and
/// the admin selection mode.
void main() {
  BoardTest? current;
  BoardTest t() => current!;
  tearDown(() async {
    await current?.dispose();
    current = null;
  });

  FakeBoardRepository seeded() {
    final b = FakeBoardRepository();
    b.seedPost(title: 'Dark mode for slides', area: BoardArea.slides, score: 5);
    b.seedPost(title: 'Comment threads in Sheets', score: 9);
    b.seedPost(
      title: 'Write tables of contents',
      area: BoardArea.write,
      score: 2,
      hasScreenshot: true,
    );
    b.seedPost(title: 'Paste loses styles', kind: BoardPostKind.bug, score: 4);
    b.seedPost(
      title: 'Shipped idea',
      status: BoardPostStatus.shipped,
      score: 30,
    );
    return b;
  }

  Finder row(int n) => byKey('board.row.$n');
  String? tabCount(String tab) =>
      (find
                  .descendant(
                    of: byKey('board.tab.$tab.count'),
                    matching: find.byType(Text),
                  )
                  .evaluate()
                  .single
                  .widget
              as Text)
          .data;

  testWidgets('Given the board when it opens then Improvements lists open '
      'ideas by trending score with counts on the tabs', (tester) async {
    current = await pumpBoard(tester, '/improvements', board: seeded());

    expect(row(2), findsOneWidget);
    expect(row(1), findsOneWidget);
    expect(row(4), findsNothing, reason: 'bugs are on the Bugs tab');
    expect(row(5), findsNothing, reason: 'shipped is on Done');
    expect(
      tester.getTopLeft(row(2)).dy,
      lessThan(tester.getTopLeft(row(1)).dy),
    );
    expect(tabCount('improvements'), '3');
    expect(tabCount('bugs'), '1');
    expect(byKey('board.signedOutBanner'), findsNothing);
    expect(byKey('board.tab.review'), findsNothing);
    await settleTooltips(tester);
  });

  testWidgets('Given the board when the Bugs tab is chosen then the route '
      'changes and bugs show the I hit this too pill', (tester) async {
    current = await pumpBoard(tester, '/improvements', board: seeded());

    await tester.tap(byKey('board.tab.bugs'));
    await tester.pumpAndSettle();

    expect(t().location, '/improvements/bugs');
    expect(row(4), findsOneWidget);
    expect(byKey('board.vote.4.hit'), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given the Done tab then done and shipped posts show', (
    tester,
  ) async {
    current = await pumpBoard(tester, '/improvements/done', board: seeded());

    expect(row(5), findsOneWidget);
    expect(row(1), findsNothing);
    await settleTooltips(tester);
  });

  testWidgets('Given the board when filtering by area then only that area '
      'is listed', (tester) async {
    current = await pumpBoard(tester, '/improvements', board: seeded());

    await tester.tap(byKey('board.filter.area'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('board.filter.area.write'));
    await tester.pumpAndSettle();

    expect(row(3), findsOneWidget);
    expect(row(1), findsNothing);
    expect(row(2), findsNothing);
    await settleTooltips(tester);
  });

  testWidgets('Given the board when sorting by New then the newest post '
      'comes first', (tester) async {
    current = await pumpBoard(tester, '/improvements', board: seeded());

    await tester.tap(byKey('board.filter.sort'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('board.sort.newest'));
    await tester.pumpAndSettle();

    // Seeded posts are an hour older per number: #1 is the newest.
    expect(
      tester.getTopLeft(row(1)).dy,
      lessThan(tester.getTopLeft(row(2)).dy),
    );
    expect(t().board.calls, contains('list idea newest null'));
    await settleTooltips(tester);
  });

  testWidgets('Given 35 ideas when Load more is pressed then the next page '
      'is appended', (tester) async {
    final b = FakeBoardRepository();
    for (var i = 0; i < 35; i++) {
      b.seedPost(title: 'Idea number $i', score: 100 - i);
    }
    current = await pumpBoard(tester, '/improvements', board: b);
    final rows = find.descendant(
      of: byKey('board.rows'),
      matching: find.byType(Scrollable),
    );

    await tester.scrollUntilVisible(
      byKey('board.loadMore'),
      400,
      scrollable: rows.first,
    );
    expect(find.text('30 of 35'), findsOneWidget);
    await tester.ensureVisible(byKey('board.loadMore'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('board.loadMore'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('35 of 35'),
      400,
      scrollable: rows.first,
    );

    expect(byKey('board.loadMore'), findsNothing);
    expect(
      t().board.calls.where((c) => c.startsWith('list idea')).last,
      endsWith(' 30'),
    );
    await settleTooltips(tester);
  });

  testWidgets('Given an idea when the up arrow is pressed then the vote is '
      'cast, pressed and labelled, and pressing again removes it', (
    tester,
  ) async {
    final b = seeded();
    current = await pumpBoard(tester, '/improvements', board: b);
    final semantics = tester.ensureSemantics();

    expect(find.bySemanticsLabel('Upvote, 5 votes'), findsOneWidget);
    await tester.tap(byKey('board.vote.1.up'));
    await tester.pumpAndSettle();

    expect(b.posts[1]!.votes[1], 1);
    expect(
      tester.getSemantics(byKey('board.vote.1.up')),
      isSemantics(
        isButton: true,
        isToggled: true,
        isEnabled: true,
        hasTapAction: true,
        label: 'Remove upvote',
      ),
    );

    await tester.tap(byKey('board.vote.1.up'));
    await tester.pumpAndSettle();
    expect(b.posts[1]!.votes.containsKey(1), isFalse);
    semantics.dispose();
    await settleTooltips(tester);
  });

  testWidgets('Given a focused row when + and - are pressed then the idea is '
      'voted up and then down', (tester) async {
    final b = seeded();
    current = await pumpBoard(tester, '/improvements', board: b);

    Focus.of(tester.element(find.text('Dark mode for slides'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pumpAndSettle();
    expect(b.posts[1]!.votes[1], 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pumpAndSettle();
    expect(b.posts[1]!.votes[1], -1);

    await t().h.undo();
    expect(b.posts[1]!.votes[1], 1, reason: 'keyboard votes are undoable');
    await settleTooltips(tester);
  });

  testWidgets('Given a signed-out visitor then the banner asks to sign in and '
      'voting goes to sign-in', (tester) async {
    current = await pumpBoard(
      tester,
      '/improvements',
      board: seeded(),
      signedIn: false,
    );

    expect(byKey('board.signedOutBanner'), findsOneWidget);
    expect(find.text('Sign in to vote and post.'), findsOneWidget);
    expect(byKey('board.filter.mine'), findsNothing);
    await tester.tap(byKey('board.vote.1.up'));
    await tester.pumpAndSettle();

    expect(t().location, '/signin?next=%2Fimprovements');
    expect(t().board.calls.where((c) => c.startsWith('vote')), isEmpty);
  });

  testWidgets('Given the board open when a report is posted then the list '
      'refreshes and shows it', (tester) async {
    final b = seeded();
    current = await pumpBoard(tester, '/improvements', board: b);
    expect(find.text('Charts in dark mode'), findsNothing);

    await t().h.invoke('shell.board.createPost', {
      'kind': 'idea',
      'title': 'Charts in dark mode',
      'body': '## Idea\n\nA dark palette',
    });
    await tester.pumpAndSettle();

    expect(find.text('Charts in dark mode'), findsOneWidget);
    await t().h.undo();
    await tester.pumpAndSettle();
    expect(find.text('Charts in dark mode'), findsNothing);
    await settleTooltips(tester);
  });

  testWidgets('Given no posts then the tab shows its empty state', (
    tester,
  ) async {
    current = await pumpBoard(tester, '/improvements/bugs');

    expect(byKey('board.empty'), findsOneWidget);
    expect(find.text('No bugs here'), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given an admin when selecting two posts then Create task '
      'makes a draft task from both and opens it', (tester) async {
    final b = seeded()..isAdmin = true;
    current = await pumpBoard(tester, '/improvements', board: b);
    expect(byKey('board.tab.review'), findsOneWidget);

    await tester.tap(byKey('board.select'));
    await tester.pumpAndSettle();
    await tester.tap(byKey('board.row.1.select'));
    await tester.tap(byKey('board.row.2.select'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(byKey('board.selection.createTask'));
    await tester.pumpAndSettle();
    expect(byKey('dialog.board.task'), findsOneWidget);
    await tester.tap(byKey('dialog.board.task.ok'));
    await tester.pumpAndSettle();

    final task = b.tasks.values.single;
    expect(task.posts.toSet(), {1, 2});
    expect(task.status, BoardTaskStatus.draft);
    expect(t().location, '/improvements/t/${task.number}');
    await settleTooltips(tester);
  });

  testWidgets('Given a narrow window then rows stack with the vote control '
      'at the start', (tester) async {
    current = await pumpBoard(
      tester,
      '/improvements',
      board: seeded(),
      size: const Size(400, 800),
    );

    expect(
      tester.getTopLeft(byKey('board.vote.1.up')).dx,
      lessThan(tester.getTopLeft(find.text('Dark mode for slides')).dx),
    );
    expect(tester.takeException(), isNull);
    await settleTooltips(tester);
  });

  for (final b in Brightness.values) {
    testWidgets('Given the board in ${b.name} then it is accessible', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      current = await pumpBoard(
        tester,
        '/improvements',
        board: seeded(),
        brightness: b,
      );

      await expectAccessible(tester);
      semantics.dispose();
      await settleTooltips(tester);
    });
  }
}
