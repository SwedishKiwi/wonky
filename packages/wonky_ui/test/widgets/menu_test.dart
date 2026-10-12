import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

List<WonkyMenuEntry> _entries(List<String> log) => [
  const WonkyMenuLabel('Section'),
  WonkyMenuItem(
    key: const ValueKey('m.open'),
    label: 'Open',
    icon: LucideIcons.folderOpen,
    shortcut: const ['⌘', 'O'],
    onSelected: () => log.add('open'),
  ),
  const WonkyMenuSeparator(),
  WonkyMenuCheckItem(
    label: 'Ruler',
    checked: true,
    onSelected: () => log.add('ruler'),
  ),
  WonkyMenuRadioItem(
    label: 'Light',
    selected: false,
    onSelected: () => log.add('light'),
  ),
  WonkyMenuItem(
    label: 'Print',
    enabled: false,
    onSelected: () => log.add('print'),
  ),
  WonkyMenuSubmenu(
    label: 'Zoom',
    children: [WonkyMenuItem(label: '100%', onSelected: () => log.add('100'))],
  ),
  const WonkyMenuSeparator(),
];

Widget _dropdown(List<String> log) => WonkyDropdownMenu(
  entries: () => _entries(log),
  builder: (context, c) => ShadButton(
    key: const ValueKey('trigger'),
    onPressed: c.toggle,
    child: const Text('Menu'),
  ),
);

void main() {
  for (final b in Brightness.values) {
    testWidgets('Given a dropdown in ${b.name} when opened then entries, '
        'labels and shortcuts render', (tester) async {
      final log = <String>[];
      await pumpWonky(tester, _dropdown(log), brightness: b, center: true);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.byType(ShadKbd), findsWidgets);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });
  }

  testWidgets('Given an open dropdown when tapping an item then it fires and '
      'the menu closes', (tester) async {
    final log = <String>[];
    await pumpWonky(tester, _dropdown(log), center: true);
    await tester.tap(find.byKey(const ValueKey('trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('m.open')));
    await tester.pumpAndSettle();
    expect(log, ['open']);
    expect(find.text('Section'), findsNothing);
  });

  testWidgets(
    'Given an open dropdown when tapping a disabled item then nothing '
    'happens',
    (tester) async {
      final log = <String>[];
      await pumpWonky(tester, _dropdown(log), center: true);
      await tester.tap(find.byKey(const ValueKey('trigger')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Print'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    },
  );

  testWidgets('Given an open dropdown when typing a letter then focus jumps to '
      'the matching item', (tester) async {
    final log = <String>[];
    await pumpWonky(tester, _dropdown(log), center: true);
    await tester.tap(find.byKey(const ValueKey('trigger')));
    await tester.pumpAndSettle();
    // Focus the first item, then type "l" for "Light".
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(log, ['light']);
  });

  test(
    'Given entries with stray separators when tidied then they are removed',
    () {
      final tidy = <WonkyMenuEntry>[
        const WonkyMenuSeparator(),
        const WonkyMenuItem(label: 'a'),
        const WonkyMenuSeparator(),
        const WonkyMenuSeparator(),
        const WonkyMenuItem(label: 'b'),
        const WonkyMenuSeparator(),
      ].tidy();
      expect(tidy.map((e) => e.runtimeType.toString()), [
        'WonkyMenuItem',
        'WonkyMenuSeparator',
        'WonkyMenuItem',
      ]);
    },
  );

  for (final b in Brightness.values) {
    testWidgets('Given a menubar in ${b.name} when opening a menu via the '
        'controller then its items show', (tester) async {
      final log = <String>[];
      final controller = WonkyMenubarController();
      addTearDown(controller.dispose);
      await pumpWonky(
        tester,
        WonkyMenubar(
          controller: controller,
          menus: [
            WonkyMenubarMenu(
              id: 'file',
              label: 'File',
              entries: () => _entries(log),
            ),
            WonkyMenubarMenu(
              id: 'edit',
              label: 'Edit',
              entries: () => [
                WonkyMenuItem(label: 'Undo', onSelected: () => log.add('undo')),
              ],
            ),
          ],
        ),
        brightness: b,
      );
      expect(find.text('File'), findsOneWidget);
      expect(controller.openByMnemonic('e'), isTrue);
      await tester.pumpAndSettle();
      expect(controller.openMenuId, 'edit');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(log, ['undo']);
    });
  }

  testWidgets('Given a menubar when tapping a menu then it opens', (
    tester,
  ) async {
    await pumpWonky(
      tester,
      WonkyMenubar(
        menus: [
          WonkyMenubarMenu(
            id: 'view',
            label: 'View',
            entries: () => const [WonkyMenuItem(label: 'Zoom in')],
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('menubar.view')));
    await tester.pumpAndSettle();
    expect(find.text('Zoom in'), findsOneWidget);
  });

  testWidgets(
    'Given a menu closed with Escape when hovering another title then no menu opens',
    (tester) async {
      final controller = WonkyMenubarController();
      addTearDown(controller.dispose);
      await pumpWonky(
        tester,
        WonkyMenubar(
          controller: controller,
          menus: [
            WonkyMenubarMenu(
              id: 'edit',
              label: 'Edit',
              entries: () => const [WonkyMenuItem(label: 'Undo')],
            ),
            WonkyMenubarMenu(
              id: 'view',
              label: 'View',
              entries: () => const [WonkyMenuItem(label: 'Zoom in')],
            ),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('menubar.edit')));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(controller.openMenuId, isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('View')));
      await tester.pumpAndSettle();
      expect(find.text('Zoom in'), findsNothing);
    },
  );

  testWidgets(
    'Given a focused field when a menu opened with the pointer closes with Escape then the field has focus again',
    (tester) async {
      final field = FocusNode(debugLabel: 'field');
      addTearDown(field.dispose);
      await pumpWonky(
        tester,
        Column(
          children: [
            WonkyMenubar(
              menus: [
                WonkyMenubarMenu(
                  id: 'edit',
                  label: 'Edit',
                  entries: () => const [WonkyMenuItem(label: 'Undo')],
                ),
              ],
            ),
            Focus(focusNode: field, child: const SizedBox(height: 40)),
          ],
        ),
      );
      field.requestFocus();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('menubar.edit')));
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget);
      expect(field.hasFocus, isFalse, reason: 'the open menu takes the keys');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsNothing);
      expect(field.hasFocus, isTrue);
    },
  );
}
