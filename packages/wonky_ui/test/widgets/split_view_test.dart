import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

final _panels = [
  SidePanelSpec(
    id: 'comments',
    title: 'Comments',
    icon: LucideIcons.messageSquare,
    builder: (_) => const Center(child: Text('comments body')),
  ),
  SidePanelSpec(
    id: 'outline',
    title: 'Outline',
    icon: LucideIcons.list,
    builder: (_) => const Focus(autofocus: true, child: Text('outline body')),
  ),
];

void main() {
  group('Given a split view controller', () {
    test(
      'when opening panels then the most recent is first and toggling closes',
      () {
        final c = WonkySplitViewController();
        c.open('comments');
        c.open('outline');
        expect(c.recentPanelIds, ['outline', 'comments']);
        c.toggle('outline');
        expect(c.activePanelId, isNull);
      },
    );

    test('when cycling then panels rotate through the recent list', () {
      final c = WonkySplitViewController()
        ..open('a')
        ..open('b');
      c.cycle(1);
      expect(c.activePanelId, 'a');
      c.cycle(-1, available: ['a', 'b', 'c']);
      expect(c.activePanelId, 'c');
    });

    test('when committing a width then every panel has it and the callback '
        'persists it', () {
      final widths = <double>[];
      final c = WonkySplitViewController(onWidthChanged: widths.add);
      expect(c.width, WonkySplitViewController.defaultWidth);
      c.setWidth(400, commit: true);
      expect(widths, [400]);
      c.open('comments');
      expect(c.width, 400);
      c.open('outline');
      expect(c.width, 400);
    });
  });

  for (final b in Brightness.values) {
    testWidgets('Given a split view in ${b.name} when a panel opens then it '
        'shows next to the content with tabs for the panels', (tester) async {
      final c = WonkySplitViewController();
      await pumpWonky(
        tester,
        WonkySplitView(
          controller: c,
          panels: _panels,
          child: const Text('main'),
        ),
        brightness: b,
      );
      expect(find.text('comments body'), findsNothing);
      c.open('comments');
      await tester.pumpAndSettle();
      expect(find.text('comments body'), findsOneWidget);
      expect(find.text('main'), findsOneWidget);
      c.open('outline');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('panel.tab.comments')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('panel.collapse')));
      await tester.pumpAndSettle();
      expect(c.activePanelId, isNull);
    });
  }

  testWidgets(
    'Given an open panel when pressing Esc inside it then it closes',
    (tester) async {
      final c = WonkySplitViewController()..open('outline');
      await pumpWonky(
        tester,
        WonkySplitView(
          controller: c,
          panels: _panels,
          child: const Text('main'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(c.activePanelId, isNull);
    },
  );

  testWidgets('Given a narrow window when a panel opens then it overlays the '
      'content and the scrim closes it', (tester) async {
    final c = WonkySplitViewController()..open('comments');
    await pumpWonky(
      tester,
      WonkySplitView(controller: c, panels: _panels, child: const Text('main')),
      size: const Size(500, 800),
    );
    await tester.pumpAndSettle();
    expect(find.text('comments body'), findsOneWidget);
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(c.activePanelId, isNull);
  });

  testWidgets('Given one open panel when shown then every panel is offered '
      'as a tab and a tab switches to it', (tester) async {
    final c = WonkySplitViewController()..open('comments');
    await pumpWonky(
      tester,
      WonkySplitView(controller: c, panels: _panels, child: const Text('main')),
    );
    await tester.pumpAndSettle();
    for (final p in _panels) {
      expect(find.byKey(ValueKey('panel.tab.${p.id}')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('panel.tab.outline')));
    await tester.pumpAndSettle();
    expect(c.activePanelId, 'outline');
    await settleTooltips(tester);
  });

  testWidgets('Given collapsed panels when shown then every panel is an icon '
      'in the rail, an icon opens its panel and collapsing returns to the '
      'rail', (tester) async {
    final c = WonkySplitViewController();
    await pumpWonky(
      tester,
      WonkySplitView(controller: c, panels: _panels, child: const Text('main')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('panel.rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('panel.rail.outline')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('panel.rail.outline')));
    await tester.pumpAndSettle();
    expect(find.text('outline body'), findsOneWidget);
    expect(find.text('Outline'), findsNothing, reason: 'no panel heading');
    expect(find.byKey(const ValueKey('panel.rail')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('panel.collapse')));
    await tester.pumpAndSettle();
    expect(c.activePanelId, isNull);
    expect(find.byKey(const ValueKey('panel.rail')), findsOneWidget);
    await settleTooltips(tester);
  });

  testWidgets('Given a split view without a rail when the panel closes then '
      'it is hidden', (tester) async {
    final c = WonkySplitViewController()..open('comments');
    await pumpWonky(
      tester,
      WonkySplitView(
        controller: c,
        panels: _panels.take(1).toList(),
        rail: false,
        child: const Text('main'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('panel.close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('panel.rail')), findsNothing);
    expect(find.text('comments body'), findsNothing);
    await settleTooltips(tester);
  });
}
