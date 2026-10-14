import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

void main() {
  late CommandTestHarness h;
  late KeymapService keymap;
  late List<String> ran;

  CallbackCommand bound(String id, KeyBinding b, {KeyScope? scope}) =>
      CallbackCommand(
        id: id,
        title: (_) => id,
        defaultBindings: [b],
        keyScope: scope ?? KeyScope.global,
        run: (ctx, a) async {
          ran.add(id);
          return const CommandResult.ok();
        },
      );

  setUp(() {
    ran = [];
    h = CommandTestHarness(
      config: TestAppConfig(
        extraCommands: [
          bound('test.global', const KeyBinding('K', mod: true)),
          bound(
            'test.drive',
            const KeyBinding('K', mod: true),
            scope: KeyScope.drive,
          ),
          bound('test.plain', const KeyBinding('J')),
          bound(
            'test.digit',
            const KeyBinding('1', mod: true, alt: true, shift: true),
          ),
        ],
      ),
      registerShellCommands: false,
    );
    keymap = KeymapService(
      registry: h.services.registry,
      dispatcher: h.services.dispatcher,
      platform: KeyPlatform.otherDesktop,
    );
  });
  tearDown(() async {
    keymap.dispose();
    await h.dispose();
  });

  Future<void> pumpDriveScope(WidgetTester tester) => tester.pumpWidget(
    KeymapScope(
      scope: KeyScope.global,
      keymap: keymap,
      child: KeymapScope(
        scope: KeyScope.drive,
        keymap: keymap,
        child: const Focus(autofocus: true, child: SizedBox()),
      ),
    ),
  );

  Future<void> pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  testWidgets('Given the same chord in the drive and global scopes when it '
      'is pressed inside the drive then the inner scope wins', (tester) async {
    await pumpDriveScope(tester);

    await pressCtrl(tester, LogicalKeyboardKey.keyK);

    expect(ran, ['test.drive']);
  });

  testWidgets('Given a chord bound in the global scope when it is pressed '
      'then its command runs once', (tester) async {
    await tester.pumpWidget(
      KeymapScope(
        scope: KeyScope.global,
        keymap: keymap,
        child: const Focus(autofocus: true, child: SizedBox()),
      ),
    );

    await pressCtrl(tester, LogicalKeyboardKey.keyK);

    expect(ran, ['test.global']);
  });

  testWidgets('Given a digit shortcut with Shift when the layout types a '
      'symbol then the key position matches', (tester) async {
    await tester.pumpWidget(
      KeymapScope(
        scope: KeyScope.global,
        keymap: keymap,
        child: const Focus(autofocus: true, child: SizedBox()),
      ),
    );

    // The web reports the typed symbol as the logical key.
    const web = 'web';
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.controlLeft,
      platform: web,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft, platform: web);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft, platform: web);
    await tester.sendKeyEvent(
      LogicalKeyboardKey.exclamation,
      physicalKey: PhysicalKeyboardKey.digit1,
      platform: web,
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: web);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft, platform: web);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft, platform: web);
    await tester.pump();

    expect(ran, ['test.digit']);
  });

  testWidgets('Given a text field has focus when typing a plain letter then '
      'the global binding does not steal it', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: KeymapScope(
          scope: KeyScope.global,
          keymap: keymap,
          child: EditableText(
            controller: controller,
            focusNode: FocusNode(),
            autofocus: true,
            style: const TextStyle(),
            cursorColor: const Color(0xff000000),
            backgroundCursorColor: const Color(0xff000000),
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();

    expect(ran, isEmpty);
  });

  test('Given an override when resolving bindings then the override replaces '
      'the default and the labels follow', () {
    keymap.setOverride('test.global', const [KeyBinding('L', mod: true)]);

    expect(keymap.bindingsOf('test.global').single.key, 'L');
    expect(keymap.labelsOf('test.global'), ['Ctrl', 'L']);
  });
}
