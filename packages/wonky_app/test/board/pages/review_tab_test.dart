import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/screen_pump.dart';
import 'support/board_pump.dart';

/// The admins' Review tab (specs/16 §9.2): sections with counts and their
/// actions; non-admins never see it.
void main() {
  BoardTest? current;
  BoardTest t() => current!;
  tearDown(() async {
    await current?.dispose();
    current = null;
  });

  FakeBoardRepository queue() {
    final b = FakeBoardRepository(isAdmin: true);
    b.seedPost(title: 'Held post', moderation: BoardModeration.held); // 1
    b.seedPost(title: 'Borderline post', needsCheck: true); // 2
    b.seedPost(
      title: 'Unchecked post',
      triageState: BoardTriageState.unchecked,
    ); // 3
    b.seedPost(title: 'Duplicate post', possibleDuplicateOf: 2); // 4
    b.seedComment(postNumber: 2, moderation: BoardModeration.held);
    b.seedSuggestion(title: 'Merged-cell paste bugs', postNumbers: [2, 3]);
    b.seedTask(title: 'A draft task', status: BoardTaskStatus.draft);
    return b;
  }

  testWidgets('Given an admin when the Review tab opens then every section '
      'shows its items and count', (tester) async {
    current = await pumpBoard(tester, '/improvements/review', board: queue());

    String countOf(String section) => (tester.widget<Text>(
      find.descendant(
        of: byKey('board.review.$section.count'),
        matching: find.byType(Text),
      ),
    )).data!;
    expect(countOf('held'), '2', reason: 'a post and a comment');
    expect(countOf('check'), '1');
    expect(countOf('unchecked'), '1');
    expect(countOf('duplicates'), '1');
    expect(countOf('bundles'), '1');
    expect(countOf('drafts'), '1');
    expect(find.text('#1 Held post'), findsOneWidget);
    expect(find.text('Review 2'), findsOneWidget, reason: 'held badge');
    await settleTooltips(tester);
  });

  testWidgets('Given a held post when Approve is pressed then it is visible '
      'and leaves the queue', (tester) async {
    final b = queue();
    current = await pumpBoard(tester, '/improvements/review', board: b);

    await tester.tap(byKey('board.review.held.1.approve'));
    await tester.pumpAndSettle();

    expect(b.posts[1]!.moderation, BoardModeration.visible);
    expect(byKey('board.review.held.1'), findsNothing);
    await t().h.undo();
    await tester.pumpAndSettle();
    expect(byKey('board.review.held.1'), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given checks and duplicates then Looks fine, Hold, Merge and '
      'Not a duplicate act on them', (tester) async {
    final b = queue();
    current = await pumpBoard(tester, '/improvements/review', board: b);

    await tester.tap(byKey('board.review.check.2.fine'));
    await tester.pumpAndSettle();
    expect(b.posts[2]!.needsCheck, isFalse);

    await tester.tap(byKey('board.review.unchecked.3.hold'));
    await tester.pumpAndSettle();
    expect(b.posts[3]!.moderation, BoardModeration.held);

    await tester.ensureVisible(byKey('board.review.duplicates.4.notDuplicate'));
    await tester.tap(byKey('board.review.duplicates.4.notDuplicate'));
    await tester.pumpAndSettle();
    expect(b.posts[4]!.possibleDuplicateOf, isNull);
    await settleTooltips(tester);
  });

  testWidgets('Given a held comment when it is approved then it is visible', (
    tester,
  ) async {
    final b = queue();
    current = await pumpBoard(tester, '/improvements/review', board: b);
    final c = b.comments.values.single;

    await tester.tap(byKey('board.review.held.comment.${c.uuid.uuid}.approve'));
    await tester.pumpAndSettle();

    expect(c.moderation, BoardModeration.visible);
    await settleTooltips(tester);
  });

  testWidgets('Given a suggested bundle when Create task is pressed then a '
      'draft task links its posts', (tester) async {
    final b = queue();
    current = await pumpBoard(tester, '/improvements/review', board: b);

    await tester.ensureVisible(byKey('board.review.bundle.1.create'));
    await tester.tap(byKey('board.review.bundle.1.create'));
    await tester.pumpAndSettle();

    final task = b.tasks.values.last;
    expect(task.title, 'Merged-cell paste bugs');
    expect(task.posts, [2, 3]);
    await settleTooltips(tester);
  });

  testWidgets('Given Suggest bundles then the admin command runs', (
    tester,
  ) async {
    final b = queue();
    current = await pumpBoard(tester, '/improvements/review', board: b);

    await tester.ensureVisible(byKey('board.review.suggestBundles'));
    await tester.tap(byKey('board.review.suggestBundles'));
    await tester.pumpAndSettle();

    expect(b.calls, contains('suggestBundles'));
    await settleTooltips(tester);
  });

  testWidgets('Given a non-admin when /improvements/review opens then the '
      'Improvements tab shows instead', (tester) async {
    final b = FakeBoardRepository()..seedPost(title: 'Public idea');
    current = await pumpBoard(tester, '/improvements/review', board: b);

    expect(byKey('board.review'), findsNothing);
    expect(byKey('board.tab.review'), findsNothing);
    expect(find.text('Public idea'), findsOneWidget);
    expect(b.calls.where((c) => c.startsWith('review')), isEmpty);
    await settleTooltips(tester);
  });

  for (final br in Brightness.values) {
    testWidgets('Given the Review tab in ${br.name} then it is accessible', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      current = await pumpBoard(
        tester,
        '/improvements/review',
        board: queue(),
        brightness: br,
      );

      await expectAccessible(tester);
      semantics.dispose();
      await settleTooltips(tester);
    });
  }
}
