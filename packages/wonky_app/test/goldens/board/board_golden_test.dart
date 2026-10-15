@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/board/report/board_report_dialog.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart' hide BoardPostPage;

import '../../board/pages/support/board_pump.dart';
import '../../board/report/support/report_fakes.dart';

/// Goldens of Bugs & Improvements in light and dark (specs/16 §4.7, §15):
/// the board page (list), the post page and the report dialog. Masters are
/// made and compared on CI Linux only (specs/15 §7): run locally with
/// `-x golden`.
void main() {
  FakeBoardRepository seeded() {
    final b = FakeBoardRepository();
    b.seedPost(
      title: 'Dark mode for slides',
      area: BoardArea.slides,
      score: 5,
      aiLabels: true,
    );
    b.seedPost(title: 'Comment threads in Sheets', score: 9);
    b.seedPost(
      title: 'Write tables of contents',
      area: BoardArea.write,
      size: BoardSize.medium,
      score: 2,
      hasScreenshot: true,
    );
    return b;
  }

  for (final b in Brightness.values) {
    testWidgets('board page ${b.name}', (tester) async {
      final t = await pumpBoard(
        tester,
        '/improvements',
        board: seeded(),
        brightness: b,
        size: const Size(1280, 800),
      );
      addTearDown(t.dispose);
      await expectLater(
        find.byType(BoardPage),
        matchesGoldenFile('board_page_${b.name}.png'),
      );
    });

    testWidgets('post page ${b.name}', (tester) async {
      final board = FakeBoardRepository();
      final p = board.seedPost(
        title: 'Paste into merged cells drops styles',
        body:
            '## What happened\nPasting into a merged cell loses the '
            '**bold**.\n\n## Expected\nThe formatting stays.',
        kind: BoardPostKind.bug,
        aiLabels: true,
        score: 14,
        contextJson: '{"app":"Sheets 2.3.1","route":"/s/:id"}',
      );
      board.seedComment(postNumber: p.number, body: 'Same *here*.');
      final t = await pumpBoard(
        tester,
        '/improvements/p/${p.number}',
        board: board,
        brightness: b,
        size: const Size(1280, 800),
      );
      addTearDown(t.dispose);
      await expectLater(
        find.byType(BoardPostPage),
        matchesGoldenFile('post_page_${b.name}.png'),
      );
    });

    testWidgets('report dialog ${b.name}', (tester) async {
      final h = reportHarness();
      addTearDown(h.dispose);
      await pumpReportShell(
        tester,
        h,
        const InvokeButton('shell.board.report'),
        brightness: b,
      );
      await tester.tap(key('test.invoke'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const ValueKey<String>(BoardReportKeys.dialog)),
        matchesGoldenFile('report_dialog_${b.name}.png'),
      );
    });
  }
}
