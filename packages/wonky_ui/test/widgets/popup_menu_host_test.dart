import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

final _host = GlobalKey<WonkyPopupMenuHostState>();

List<WonkyMenuEntry> _entries() => [
  WonkyMenuItem(
    key: const ValueKey('m.cut'),
    label: 'Cut',
    shortcut: const ['⌘', 'X'],
    onSelected: () {},
  ),
  WonkyMenuItem(label: 'Insert 1 row above', onSelected: () {}),
];

List<WonkyMenuEntry> _long(int n) => [
  for (var i = 0; i < n; i++)
    WonkyMenuItem(
      key: ValueKey('m.item$i'),
      label: 'Item $i',
      onSelected: () {},
    ),
];

Future<void> _open(
  WidgetTester tester,
  Offset at, {
  List<WonkyMenuEntry> Function() entries = _entries,
  Size size = const Size(1280, 800),
}) async {
  await pumpWonky(
    tester,
    WonkyPopupMenuHost(key: _host, child: const SizedBox.expand()),
    size: size,
  );
  _host.currentState!.show(at, entries);
  await tester.pumpAndSettle();
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('Given a context menu opened at a point (${b.name}) then '
        'its top-left corner is at the pointer, not centred on it', (
      tester,
    ) async {
      await _open(tester, const Offset(300, 200));

      final item = tester.getRect(find.byKey(const ValueKey('m.cut')));
      // The menu opens at the pointer, not a few pixels right of it.
      expect(item.left, inInclusiveRange(299, 302));
      expect(item.top, greaterThanOrEqualTo(200));
    });
  }

  testWidgets('Given a point near the right edge then the menu opens to the '
      'left of the pointer and stays on screen', (tester) async {
    await _open(tester, const Offset(1270, 200));

    final item = tester.getRect(find.byKey(const ValueKey('m.cut')));
    expect(item.right, lessThanOrEqualTo(1270));
    expect(item.left, greaterThanOrEqualTo(0));
  });

  testWidgets('Given a long menu opened low on the screen then it moves up '
      'and stays on screen (it ran off the bottom edge)', (tester) async {
    await _open(
      tester,
      const Offset(300, 500),
      entries: () => _long(20),
      size: const Size(1280, 800),
    );

    final first = tester.getRect(find.byKey(const ValueKey('m.item0')));
    final last = tester.getRect(find.byKey(const ValueKey('m.item19')));
    expect(first.top, greaterThanOrEqualTo(8));
    expect(last.bottom, lessThanOrEqualTo(800 - 8));
    expect(first.left, inInclusiveRange(299, 302));
  });

  testWidgets('Given a menu taller than the screen then it fits the screen '
      'and scrolls to its last item', (tester) async {
    await _open(
      tester,
      const Offset(300, 100),
      entries: () => _long(40),
      size: const Size(1280, 400),
    );

    final first = tester.getRect(find.byKey(const ValueKey('m.item0')));
    expect(first.top, greaterThanOrEqualTo(8));
    final last = find.byKey(const ValueKey('m.item39'));
    await tester.scrollUntilVisible(
      last,
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(400 - 8));
  });

  test('Given the space around the pointer then the menu opens below, above '
      'or shifted to fit', () {
    expect(WonkyPopupMenuHostState.topFor(100, 200, 800), 100);
    expect(WonkyPopupMenuHostState.topFor(700, 200, 800), 500);
    expect(WonkyPopupMenuHostState.topFor(400, 600, 800), 192);
    expect(WonkyPopupMenuHostState.topFor(400, 900, 800), 8);
  });

  testWidgets('Given entries that depend on state the open menu changes then '
      'the entries built when it opened stay (the menu is placed by a second '
      'build after it took the focus)', (tester) async {
    var built = 0;
    var label = 'Suggestion';
    await _open(
      tester,
      const Offset(300, 200),
      entries: () {
        built++;
        return [WonkyMenuItem(label: label, onSelected: () {})];
      },
    );
    label = 'Changed';
    tester.element(find.byType(WonkyPopupMenuHost)).markNeedsBuild();
    await tester.pumpAndSettle();

    expect(built, 1);
    expect(find.text('Suggestion'), findsOneWidget);
  });
}
