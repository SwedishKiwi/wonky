import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

List<ToolbarGroup> _groups(List<String> log, {bool bold = false}) => [
  ToolbarGroup([
    ToolbarButton(
      id: 'tb.undo',
      icon: LucideIcons.undo2,
      label: 'Undo',
      priority: 1,
      onPressed: () => log.add('undo'),
    ),
    ToolbarButton(
      id: 'tb.redo',
      icon: LucideIcons.redo2,
      label: 'Redo',
      priority: 1,
      onPressed: () => log.add('redo'),
    ),
  ]),
  ToolbarGroup([
    ToolbarToggleButton(
      id: 'tb.bold',
      icon: LucideIcons.bold,
      label: 'Bold',
      value: bold,
      priority: 2,
      onChanged: (v) => log.add('bold:$v'),
    ),
    for (var i = 0; i < 12; i++)
      ToolbarButton(
        id: 'tb.extra$i',
        icon: LucideIcons.star,
        label: 'Extra $i',
        priority: 5,
        onPressed: () => log.add('extra$i'),
      ),
  ]),
];

void main() {
  for (final b in Brightness.values) {
    group('Given a toolbar in ${b.name} mode', () {
      testWidgets('when wide enough then every item is visible and there is no '
          'overflow button', (tester) async {
        final log = <String>[];
        await pumpWonky(tester, WonkyToolbar(groups: _groups(log)), brightness: b);
        expect(find.byKey(const ValueKey('tb.extra11')).hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey('toolbar.overflow')).hitTestable(), findsNothing);
      });

      testWidgets('when narrow then low-priority items move to the overflow menu',
          (tester) async {
        final log = <String>[];
        await pumpWonky(
          tester,
          SizedBox(width: 220, child: WonkyToolbar(groups: _groups(log))),
          brightness: b,
          center: true,
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('tb.undo')).hitTestable(), findsOneWidget);
        expect(find.byKey(const ValueKey('tb.extra11')).hitTestable(), findsNothing);
        expect(find.byKey(const ValueKey('toolbar.overflow')).hitTestable(), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('toolbar.overflow')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Extra 11'));
        await tester.pumpAndSettle();
        expect(log, ['extra11']);
      });
    });
  }

  testWidgets('Given a toolbar when pressing a toggle then onChanged gets the '
      'new value', (tester) async {
    final log = <String>[];
    await pumpWonky(tester, WonkyToolbar(groups: _groups(log)));
    await tester.tap(find.byKey(const ValueKey('tb.bold')));
    expect(log, ['bold:true']);
  });

  testWidgets('Given a focused toolbar when pressing arrows and Esc then focus '
      'moves and onEscape fires', (tester) async {
    final log = <String>[];
    final controller = WonkyToolbarController();
    await pumpWonky(
      tester,
      WonkyToolbar(
        groups: _groups(log),
        controller: controller,
        onEscape: () => log.add('esc'),
      ),
    );
    controller.focus();
    await tester.pump();
    expect(controller.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, ['redo']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(log, ['redo', 'esc']);
  });
}
