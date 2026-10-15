import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/editor_screen/canvas_region.dart';
import 'package:wonky_slides/features/editor_screen/deck_editor_controller.dart';
import 'package:wonky_slides/features/elements/image/image_adjust_preview.dart';
import 'package:wonky_slides/features/inspector/deck_inspector.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';
import 'package:wonky_slides/features/text_editing/text_editing_host.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../harness/deck_harness.dart';
import '../../support/slides_harness.dart';
import '../stage/stage_fixture.dart' show RecordingFontRegistry;

/// The live preview of the image adjustment sliders (03 §6.5.5, SL-44).
void main() {
  late DeckHarness d;
  late String photo;

  ImageNode? stageImage(WidgetTester tester) {
    final stage = tester.widget<SlideStage>(find.byType(SlideStage));
    ImageNode? walk(SceneNode n) => switch (n) {
      ImageNode() => n,
      GroupNode() => n.children.map(walk).nonNulls.firstOrNull,
      _ => null,
    };
    return stage.scene.nodes.map(walk).nonNulls.firstOrNull;
  }

  Map<String, Object?> adjust() {
    final data =
        jsonDecode(d.model.element(photo)!.str(ElementCols.dataJson)!) as Map;
    return (data['adjust'] as Map? ?? const {}).cast<String, Object?>();
  }

  for (final brightness in Brightness.values) {
    testWidgets('Given a selected image (${brightness.name}) when a '
        'brightness slider is dragged then the canvas previews it without '
        'writing, and the release writes one step', (tester) async {
      final b = DeckBuilder(title: 'Images');
      final slide = b.slide(layoutKey: 'blank');
      photo = b.element(
        slide,
        ElementKind.image,
        x: 400,
        y: 100,
        width: 600,
        height: 300,
        columns: {
          ElementCols.dataJson: jsonEncode({
            'v': 1,
            'src': 'wonky-file://0190a000-0000-7000-8000-0000000000cc',
            'naturalWidth': 1200,
            'naturalHeight': 600,
          }),
        },
      );
      d = DeckHarness.open(fixture: b);
      d.editor.setCurrentSlide(slide);
      final renderer = SlideRenderer(
        model: d.session.model,
        fonts: RecordingFontRegistry(),
      );
      final c = SlideCanvasController.attach(d.editor, renderer: renderer);
      addTearDown(() async {
        textEditingOf(d.editor).dispose();
        c.dispose();
        renderer.dispose();
        await d.dispose();
      });
      selectionOf(d.editor).select([photo]);
      d.editor.openInspector(InspectorTab.format, section: 'image');
      await pumpSlides(
        tester,
        d.h,
        Row(
          children: [
            Expanded(
              child: CanvasRegion(
                services: d.services,
                editor: d.editor,
                onContextMenu: (_, _) {},
              ),
            ),
            SizedBox(
              width: 360,
              child: DeckInspector(services: d.services, editor: d.editor),
            ),
          ],
        ),
        size: const Size(1400, 1400),
        brightness: brightness,
      );
      expect(stageImage(tester)!.colorMatrix, isNull);

      final slider = find.byKey(
        const ValueKey<String>('slides.image.adjust.brightness.0.0'),
      );
      expect(slider, findsOneWidget);
      final rect = tester.getRect(slider);
      final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await g.down(rect.center);
      await tester.pump();
      for (var i = 1; i <= 5; i++) {
        await g.moveTo(rect.center + Offset(rect.width / 20 * i, 0));
        await tester.pump();
      }

      final preview = ImageAdjustPreview.of(d.editor)!;
      expect(preview.elementId, photo);
      expect(preview.adjust!['brightness'], greaterThan(0));
      expect(
        stageImage(tester)!.colorMatrix,
        ImageAdjust.matrix(preview.adjust),
      );
      expect(adjust(), isEmpty);
      expect(d.undoLabels, isEmpty);

      await g.up();
      await tester.pumpAndSettle();
      expect(preview.elementId, isNull);
      expect(adjust()['brightness'], greaterThan(0));
      expect(d.undoLabels, hasLength(1));
      expect(stageImage(tester)!.colorMatrix, isNotNull);
      expect(tester.takeException(), isNull);

      await d.undo();
      await tester.pump();
      expect(adjust(), isEmpty);
      expect(stageImage(tester)!.colorMatrix, isNull);
    });
  }
}
