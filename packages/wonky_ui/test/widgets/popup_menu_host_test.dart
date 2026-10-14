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

Future<void> _open(WidgetTester tester, Offset at) async {
  await pumpWonky(
    tester,
    WonkyPopupMenuHost(key: _host, child: const SizedBox.expand()),
  );
  _host.currentState!.show(at, _entries);
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
}
