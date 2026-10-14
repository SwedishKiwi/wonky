import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/grid/grid_area.dart';
import 'package:wonky_sheets/features/objects/objects_controller.dart';
import 'package:wonky_sheets/features/objects/objects_layer.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../support/grid_pump.dart';
import '../../support/sheets_harness.dart';

void main() {
  late SheetsHarness s;

  ObjectsController objects() => ObjectsController.of(s.editor);

  Future<String> seedChart(WidgetTester tester, {bool dark = false}) async {
    await s.type('A1', 'Region');
    await s.type('B1', 'Sales');
    await s.type('A2', 'North');
    await s.type('B2', '10');
    await s.type('A3', 'South');
    await s.type('B3', '7');
    await pumpSheets(
      tester,
      s,
      dark: dark,
      child: WonkyPopupMenuHost(
        child: SheetObjectsHost(
          editor: s.editor,
          services: s.services,
          child: GridArea(controller: s.editor, services: s.services),
        ),
      ),
    );
    final r = await s.run('sheets.chart.insert', {
      'ranges': ['A1:B3'],
      'anchor': {'cell': 'C2', 'width': 300, 'height': 200},
    });
    await tester.pumpAndSettle();
    return (r.data! as Map)['objectId']! as String;
  }

  ChartRect rectOf(String id) =>
      objects().rectOf(objects().record(id)!, ghost: false)!;

  setUp(() => s = SheetsHarness.open());
  tearDown(() => s.dispose());

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  }

  group('Given a chart over the grid', () {
    testWidgets('when it is clicked then it is selected with resize handles '
        'and Esc deselects it', (tester) async {
      final id = await seedChart(tester);
      objects().select(null);
      await tester.pump();
      expect(find.byKey(const ValueKey('sheets.object.frame')), findsNothing);

      await tester.tapAt(
        tester.getCenter(find.byKey(ValueKey('sheets.object.$id'))),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(objects().selectedId, id);
      expect(find.byKey(const ValueKey('sheets.object.frame')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('sheets.object.handle.bottomRight')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(objects().selectedId, isNull);
      await settle(tester);
    });

    testWidgets('when its body is dragged then it moves once on drop (one '
        'undo step)', (tester) async {
      final id = await seedChart(tester);
      final before = rectOf(id);
      final steps = s.h.undoLabels.length;
      final center = tester.getCenter(
        find.byKey(ValueKey('sheets.object.$id')),
      );

      final g = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(20, 10));
      await g.moveBy(const Offset(30, 20));
      await tester.pump();
      expect(objects().drag, isNotNull, reason: 'live ghost');
      expect(rectOf(id), before, reason: 'no write while dragging');
      await g.up();
      await tester.pumpAndSettle();

      final after = rectOf(id);
      expect((after.left - before.left, after.top - before.top), (50.0, 30.0));
      expect(s.h.undoLabels.length, steps + 1);
      expect(objects().drag, isNull);
      await settle(tester);
    });

    testWidgets('when the bottom-right handle is dragged then it resizes', (
      tester,
    ) async {
      final id = await seedChart(tester);
      final before = rectOf(id);
      final handle = tester.getCenter(
        find.byKey(const ValueKey('sheets.object.handle.bottomRight')),
      );

      final g = await tester.startGesture(
        handle,
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(const Offset(40, 0));
      await g.moveBy(const Offset(0, 25));
      await g.up();
      await tester.pumpAndSettle();

      final after = rectOf(id);
      expect(
        (after.width, after.height),
        (before.width + 40, before.height + 25),
      );
      expect((after.left, after.top), (before.left, before.top));
      await settle(tester);
    });

    testWidgets('when arrow keys are pressed then it nudges and Delete '
        'removes it', (tester) async {
      final id = await seedChart(tester);
      objects().select(id);
      await tester.pump();
      final before = rectOf(id);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(rectOf(id).left, before.left + 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(objects().activeObjects, isEmpty);
      await settle(tester);
    });

    testWidgets('when rendered in dark mode then the automatic background is '
        'the dark card color', (tester) async {
      final id = await seedChart(tester, dark: true);
      final c = objects().chartById(id)!;
      final scene = c.sceneFor(
        300,
        200,
        dark: true,
        tokens: ChartUiTokens.dark,
      );
      expect(scene.background, ChartUiTokens.dark.card);
      expect(find.byKey(ValueKey('sheets.object.$id')), findsOneWidget);
      await settle(tester);
    });
  });
}
