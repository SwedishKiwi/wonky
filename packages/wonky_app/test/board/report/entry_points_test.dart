import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/auth/screens/sign_in_screen.dart';
import 'package:wonky_app/src/board/report/board_report_dialog.dart';
import 'package:wonky_app/src/board/report/report_draft.dart';
import 'package:wonky_app/src/settings/sections/other_sections.dart';
import 'package:wonky_app/src/shell/overlays/shell_overlays.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import 'support/report_fakes.dart';

/// The entry points of Bugs & Improvements that replaced *Report a bug*
/// (specs/16 §4.1). The Help menu is covered in
/// `commands/shell_commands/shell_v2_commands_test.dart`, the left menu in
/// `drive/scoped_home_test.dart`.
void main() {
  late CommandTestHarness h;
  late FakeReportBoard board;

  setUp(() {
    board = FakeReportBoard();
    h = reportHarness(board: board);
  });
  tearDown(() => h.dispose());

  BoardReportDialogState dialog(WidgetTester tester) =>
      tester.state<BoardReportDialogState>(find.byType(BoardReportDialog));

  testWidgets('Given the sign-in screen when the Bugs & Improvements link is '
      'used then the board page opens (no dialog)', (tester) async {
    await h.dispose();
    h = reportHarness(board: board, auth: FakeAuthRepository(signedIn: false));
    await pumpReportShell(tester, h, SignInScreen(services: h.services));

    expect(key('auth.reportBug'), findsNothing);
    await tester.ensureVisible(key('auth.board'));
    await tester.tap(key('auth.board'));
    await tester.pumpAndSettle();

    expect(routerPath(h), '/improvements');
    expect(key(BoardReportKeys.dialog), findsNothing);
  });

  testWidgets('Given Settings › About when Bugs & Improvements is pressed '
      'then the report dialog opens', (tester) async {
    await pumpReportShell(tester, h, AboutSection(services: h.services));

    expect(key('settings.about.reportBug'), findsNothing);
    await tester.tap(key('settings.about.board'));
    await tester.pumpAndSettle();

    expect(key(BoardReportKeys.dialog), findsOneWidget);
  });

  testWidgets('Given an open document when the title-row button is pressed '
      'then the report dialog opens', (tester) async {
    final doc = h.drive.seed(name: 'Plan');
    await pumpReportShell(
      tester,
      h,
      EditorScaffold(
        services: h.services,
        itemUuid: doc.uuid.uuid,
        body: (context, item) => const SizedBox.expand(),
        commentsButton: false,
        historyPanel: false,
        showStatusBar: false,
      ),
      size: const Size(1280, 800),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(key('editor.reportBug'), findsNothing);
    await tester.tap(key('editor.board'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(key(BoardReportKeys.dialog), findsOneWidget);
    // Unmount (the editor keeps animating) so no timers are left.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Given the error card when "Report this bug" is pressed then '
      'the dialog opens on Bug with the error attached', (tester) async {
    final details = FlutterErrorDetails(
      exception: StateError('Widget exploded'),
      stack: StackTrace.fromString('#0 main (package:x/y.dart:1:1)'),
    );
    await pumpReportShell(
      tester,
      h,
      ErrorCard(details: details, services: h.services),
    );

    await tester.tap(key('error.reportBug'));
    await tester.pumpAndSettle();

    final d = dialog(tester);
    expect(d.draft.kind, BoardPostKind.bug);
    expect(d.draft.includeError, isTrue);
    expect(find.textContaining('Include the last error'), findsOneWidget);
    await enterField(
      tester,
      BoardReportKeys.field(BoardReportField.title),
      'The card shows an error',
    );
    await enterField(
      tester,
      BoardReportKeys.field(BoardReportField.happened),
      'Exploded',
    );
    await tester.tap(key(BoardReportKeys.post));
    await tester.pumpAndSettle();

    expect(board.posted.single.contextJson, contains('Widget exploded'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
  });
}
