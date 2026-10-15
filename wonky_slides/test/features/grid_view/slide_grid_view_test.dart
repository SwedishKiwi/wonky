import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/grid_view/grid_layout.dart';
import 'package:wonky_slides/features/navigator/navigator_controller.dart';
import 'package:wonky_slides/features/navigator/navigator_model.dart';
import 'package:wonky_slides_core/model.dart' show DeckModelIndexes;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_ui/testing.dart';

import '../../support/deck_screen.dart';

Finder key(String k) => find.byKey(ValueKey<String>(k));

/// The grid view — the light table (Slides 04 §9, SL-16).
void main() {
  group('Given the grid layout', () {
    late DeckBuilder b;
    late String t1, g, a1, a2, a3, t2;
    setUp(() {
      b = DeckBuilder();
      t1 = b.slide(title: 't1');
      g = b.group('Intro');
      a1 = b.slide(groupId: g);
      a2 = b.slide(groupId: g);
      a3 = b.slide(groupId: g);
      t2 = b.slide(title: 't2');
    });

    GridLayout layout({Set<String> collapsed = const {}}) => GridLayout.of(
      buildNavRows(b.build().indexes.order, collapsed),
      width: 600,
      tileWidth: 160,
      aspect: 9 / 16,
    );

    test('when laid out then groups are section headers spanning the row and '
        'their slides flow in lines below', () {
      final l = layout();
      expect(l.columns, 3);
      final header = l.items.firstWhere((i) => i.row.isGroup);
      expect(header.rect.width, 552);
      final a = {for (final i in l.items) i.row.id: i};
      expect(a[a1]!.rect.top, greaterThan(header.rect.bottom));
      expect(a[a1]!.line, a[a3]!.line);
      // The top-level slide after the group starts a new section line.
      expect(a[t2]!.rect.top, greaterThan(a[a1]!.rect.bottom));
      expect(a[t1]!.rect.bottom, lessThan(header.rect.top));
    });

    test('when collapsed then only the header stays, and ↓ from a tile goes '
        'to the nearest item of the next line', () {
      final l = layout(collapsed: {g});
      expect(l.items.map((i) => i.row.id), [t1, g, t2]);
      final full = layout();
      final down = full.vertical(
        full.items.firstWhere((i) => i.row.id == t1),
        down: true,
      );
      expect(down!.row.id, g);
    });

    test('when dropping then a tile gives the gap left/right of it, a header '
        'appends slides, and groups are refused inside a group', () {
      final l = layout();
      final a2Rect = l.items.firstWhere((i) => i.row.id == a2).rect;
      final right = resolveGridDrop(
        l,
        a2Rect.right - 4,
        a2Rect.center.dy,
        draggingGroups: false,
      );
      expect(
        right.target,
        isA<InGroup>().having((t) => t.afterId, 'after', a2),
      );
      expect(right.barX, a2Rect.right + 8);
      final header = l.items.firstWhere((i) => i.row.isGroup).rect;
      final append = resolveGridDrop(
        l,
        header.center.dx,
        header.center.dy,
        draggingGroups: false,
      );
      expect(append.highlightGroupId, g);
      expect(
        resolveGridDrop(
          l,
          a2Rect.left + 4,
          a2Rect.center.dy,
          draggingGroups: true,
        ).refused,
        isTrue,
      );
    });
  });

  testWidgets('Given the grid view when a tile is double-clicked then the '
      'slide opens in Normal view; arrows and the size slider work', (
    tester,
  ) async {
    final r = await pumpDeckScreen(tester);
    await r.run('slides.view.setMode', {'mode': 'grid'});
    await tester.pump();
    await tester.pump();
    final ids = [for (final e in r.editor.order.entries) e.id];
    expect(key('slides.grid.slide.${ids[3]}'), findsOneWidget);
    final g = r.editor.order.groups.single.group.id;
    expect(key('slides.grid.group.$g'), findsOneWidget);

    await tester.tap(key('slides.grid.slide.${ids[0]}'));
    await tester.pump();
    expect(r.editor.navigatorFocus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(navigatorOf(r.editor).focusKey, 'group:$g');

    navigatorOf(r.editor).setGridThumbSize(300);
    await tester.pump();
    expect(tester.getSize(key('slides.grid.slide.${ids[0]}')).width, 300);

    await tester.tap(key('slides.grid.slide.${ids[3]}'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(key('slides.grid.slide.${ids[3]}'));
    await tester.pump();
    expect(r.editor.mode, DeckViewMode.normal);
    expect(r.editor.currentSlideId, ids[3]);
    expect(tester.takeException(), isNull);
    await settleTooltips(tester);
    await r.close(tester);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Given the grid view in ${brightness.name} when a tile is '
        'dragged onto a section header then it is appended to the group in '
        'one undo step', (tester) async {
      final r = await pumpDeckScreen(tester, brightness: brightness);
      await r.run('slides.view.setMode', {'mode': 'grid'});
      await tester.pump();
      await tester.pump();
      final last = r.editor.order.entries.last.id;
      final g = r.editor.order.groups.single.group.id;
      final gesture = await tester.startGesture(
        tester.getCenter(key('slides.grid.slide.$last')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(key('slides.grid.group.$g')));
      await tester.pump();
      expect(r.session.model.slide(last)!.groupId, isNull);
      await gesture.up();
      await tester.pump();
      expect(r.session.model.slide(last)!.groupId, g);
      expect(r.session.model.indexes.order.range(g)!.length, 3);
      expect(r.h.undoLabels.length, 1);
      expect(tester.takeException(), isNull);
      await settleTooltips(tester);
      await r.close(tester);
    });
  }
}
