import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/canvas_tools.dart';
import 'package:wonky_slides/features/format_painter/format_painter.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../canvas/canvas_rig.dart';

/// The armed insert tools and the format painter on the canvas (Slides 03
/// §6.3, §6.4, §9; SL-14).
void main() {
  List<SlideElementRec> added(CanvasRig r, Set<String> before) => [
    for (final e in r.model.elementsOf(r.fixture.slide))
      if (!before.contains(e.id)) e,
  ];

  Set<String> ids(CanvasRig r) => {
    for (final e in r.model.elementsOf(r.fixture.slide)) e.id,
  };

  group('Given an armed shape tool', () {
    testWidgets('when dragging on the slide then the shape takes the dragged '
        'box, is selected and the tool disarms', (tester) async {
      final r = await CanvasRig.pump(tester);
      final before = ids(r);
      await r.d.run('slides.insert.shape', {'geometry': 'ellipse'});
      await tester.pump();
      expect(CanvasTools.of(r.d.editor), isNotNull);

      final g = await r.drag(
        tester,
        const Offset(1650, 360),
        const Offset(1850, 520),
        hold: true,
      );
      // The live preview shows while dragging, nothing is written.
      expect(r.controller.toolPreview, isNotNull);
      expect(ids(r), before);
      await g.up();
      await tester.pumpAndSettle();

      final e = added(r, before).single;
      expect(e.kind, ElementKind.shape);
      expect(e.x, closeTo(1650, 3));
      expect(e.y, closeTo(360, 3));
      expect(e.width, closeTo(200, 6));
      expect(e.height, closeTo(160, 6));
      expect(jsonDecode(e.str(ElementCols.dataJson)!)['geometry'], 'ellipse');
      expect(r.selected, [e.id]);
      expect(r.d.editor.armedTool, isNull);
      expect(r.d.undoLabels.length, 1);
    });

    testWidgets('when clicking then the default size is centered on the '
        'click', (tester) async {
      final r = await CanvasRig.pump(tester);
      final before = ids(r);
      await r.d.run('slides.insert.shape', {'geometry': 'arrowRight'});

      await r.click(tester, 1750, 450);
      await tester.pumpAndSettle();

      final e = added(r, before).single;
      expect((e.width, e.height), (320.0, 160.0));
      expect(e.x! + e.width! / 2, closeTo(1750, 3));
      expect(e.y! + e.height! / 2, closeTo(450, 3));
    });

    testWidgets('when Shift-dragging then the shape is square', (tester) async {
      final r = await CanvasRig.pump(tester);
      final before = ids(r);
      await r.d.run('slides.insert.shape', {'geometry': 'rect'});

      await CanvasRig.holding(tester, LogicalKeyboardKey.shiftLeft, () async {
        await r.drag(tester, const Offset(1660, 380), const Offset(1860, 440));
      });

      final e = added(r, before).single;
      expect(e.width, closeTo(e.height!, 0.5));
      expect(e.width, closeTo(200, 6));
    });

    testWidgets('when Esc is pressed then the tool goes back to Select', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);
      await r.d.run('slides.insert.shape', {'geometry': 'rect'});
      await r.d.run('slides.select.escape');
      expect(r.d.editor.armedTool, isNull);
    });
  });

  group('Given an armed line tool', () {
    testWidgets('when dragging from one shape site to another then both ends '
        'glue', (tester) async {
      final r = await CanvasRig.pump(tester);
      final before = ids(r);
      await r.d.run('slides.insert.line', {
        'routing': 'elbow',
        'arrows': 'end',
      });

      // a's right site (500, 200) → b's left site (700, 200).
      await r.drag(tester, const Offset(503, 202), const Offset(697, 198));

      final e = added(r, before).single;
      expect(e.kind, ElementKind.line);
      final data = jsonDecode(e.str(ElementCols.dataJson)!) as Map;
      expect(data['routing'], 'elbow');
      expect((data['start'] as Map)['connect'], {
        'elementId': Base62Uuid.encode(r.fixture.a),
        'site': 'right',
      });
      expect((data['end'] as Map)['connect'], {
        'elementId': Base62Uuid.encode(r.fixture.bShape),
        'site': 'left',
      });
    });

    testWidgets('when clicking then a 400 su horizontal line is inserted', (
      tester,
    ) async {
      final r = await CanvasRig.pump(tester);
      final before = ids(r);
      await r.d.run('slides.insert.line', {
        'routing': 'straight',
        'arrows': 'none',
      });

      await r.click(tester, 1300, 1000);
      await tester.pumpAndSettle();

      final e = added(r, before).single;
      expect(e.width, closeTo(400, 0.5));
      expect(e.str(ElementCols.strokeJson), isNull);
    });
  });

  group('Given the format painter', () {
    testWidgets('when clicking another shape then it gets the source style '
        'and the brush disarms', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);
      await r.d.run('slides.format.paintFormat');
      expect(FormatPainter.armed(r.d.editor), isTrue);

      await r.click(tester, 1450, 700);
      await tester.pumpAndSettle();

      final a = r.model.element(r.fixture.a)!;
      final c = r.model.element(r.fixture.c)!;
      expect(c.str(ElementCols.fillJson), a.str(ElementCols.fillJson));
      expect(FormatPainter.armed(r.d.editor), isFalse);
      expect(r.selected, [r.fixture.c]);
    });

    testWidgets('when clicking beside the objects then one-shot painting '
        'ends without writing', (tester) async {
      final r = await CanvasRig.pump(tester);
      await r.click(tester, 300, 200);
      await r.d.run('slides.format.paintFormat');

      await r.click(tester, 1750, 450);
      await tester.pumpAndSettle();

      expect(FormatPainter.armed(r.d.editor), isFalse);
      expect(r.d.undoLabels, isEmpty);
    });
  });
}
