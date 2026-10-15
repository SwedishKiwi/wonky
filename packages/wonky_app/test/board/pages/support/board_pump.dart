import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/routing/router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../../support/screen_pump.dart';

/// A board under test: the harness (real router, dispatcher, undo) over a
/// [FakeBoardRepository].
class BoardTest {
  BoardTest(this.h, this.board);

  final CommandTestHarness h;
  final FakeBoardRepository board;

  ShellServices get s => h.services;

  String get location => s.router.state.uri.toString();

  Future<void> go(WidgetTester tester, String location) async {
    s.router.go(location);
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    await h.dispose();
    await board.dispose();
  }
}

/// Pumps the shell router at [location] with [board] (default: signed in
/// as Anna, user 1, not an admin).
Future<BoardTest> pumpBoard(
  WidgetTester tester,
  String location, {
  FakeBoardRepository? board,
  bool signedIn = true,
  Brightness brightness = Brightness.light,
  Size size = const Size(1440, 900),
}) async {
  final b = board ?? FakeBoardRepository();
  if (!signedIn) b.userId = null;
  final h = CommandTestHarness(
    board: b,
    auth: FakeAuthRepository(signedIn: signedIn),
  );
  if (!signedIn) h.services.currentUser.value = null;
  h.services.router = buildShellRouter(h.services);
  await pumpScreen(
    tester,
    h,
    Router.withConfig(config: h.services.router),
    brightness: brightness,
    size: size,
  );
  h.services.router.go(location);
  await tester.pumpAndSettle();
  return BoardTest(h, b);
}

/// Records clipboard writes (the platform channel has no handler in tests).
List<String> recordClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// Pumps a few frames without settling: a page showing a spinner (the AI
/// writing a prompt) never settles.
Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Finder byKey(String key) => find.byKey(ValueKey<String>(key));
