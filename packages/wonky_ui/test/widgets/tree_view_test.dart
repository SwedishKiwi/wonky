import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/testing.dart';
import 'package:wonky_ui/wonky_ui.dart';

const _tree = {
  null: ['a', 'b'],
  'a': ['a1', 'a2'],
  'b': <String>[],
  'a1': <String>[],
  'a2': <String>[],
};

WonkyTreeController<String> _controller() => WonkyTreeController<String>(
  loader: (parent) async => [
    for (final id in _tree[parent?.id]!)
      WonkyTreeNode(
        id: id,
        label: 'Folder $id',
        value: id,
        icon: LucideIcons.folder,
        hasChildren: (_tree[id] ?? const []).isNotEmpty,
      ),
  ],
);

void main() {
  group('Given a tree controller', () {
    test('when expanding a node then its children become visible rows', () async {
      final c = _controller();
      await c.ensureLoaded();
      expect(c.rows.map((r) => r.node.id), ['a', 'b']);
      await c.expand('a');
      expect(c.rows.map((r) => (r.node.id, r.depth)), [
        ('a', 0),
        ('a1', 1),
        ('a2', 1),
        ('b', 0),
      ]);
      c.collapse('a');
      expect(c.rows, hasLength(2));
    });

    test('when a loader fails then the error is exposed', () async {
      final c = WonkyTreeController<String>(loader: (_) async => throw StateError('x'));
      await c.ensureLoaded();
      expect(c.error, isA<StateError>());
    });
  });

  for (final b in Brightness.values) {
    testWidgets('Given a tree view in ${b.name} when using the keyboard then '
        'focus moves, expands and activates', (tester) async {
      final c = _controller();
      final activated = <String>[];
      await pumpWonky(
        tester,
        SizedBox(
          height: 400,
          width: 300,
          child: WonkyTreeView<String>(
            controller: c,
            onActivate: (n) => activated.add(n.id),
          ),
        ),
        brightness: b,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Folder a'));
      await tester.pumpAndSettle();
      expect(activated, ['a']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Folder a1'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(activated, ['a', 'a2']);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(c.focusedId, 'a');
    });
  }

  testWidgets('Given a renameable tree when pressing F2 and typing then '
      'onRename gets the new name', (tester) async {
    final c = _controller();
    String? renamed;
    await pumpWonky(
      tester,
      SizedBox(
        height: 300,
        width: 300,
        child: WonkyTreeView<String>(
          controller: c,
          onRename: (n, name) {
            renamed = '${n.id}=$name';
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folder b'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Renamed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(renamed, 'b=Renamed');
    expect(c.renamingId, isNull);
  });

  testWidgets('Given draggable nodes when dropping one onto another then '
      'onDrop reports the target', (tester) async {
    final c = _controller();
    final drops = <String>[];
    await pumpWonky(
      tester,
      SizedBox(
        height: 300,
        width: 300,
        child: WonkyTreeView<String>(
          controller: c,
          dragData: (n) => n.id,
          onDrop: (data, target, pos) => drops.add('$data->${target.id}:${pos.name}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final from = tester.getCenter(find.text('Folder b'));
    final to = tester.getCenter(find.text('Folder a'));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(to);
    await tester.pump();
    await g.moveTo(to + const Offset(0, 1));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(drops, ['b->a:inside']);
  });
}
