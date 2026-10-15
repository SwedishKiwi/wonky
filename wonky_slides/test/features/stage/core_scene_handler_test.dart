import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/elements/element_kind_handler.dart';
import 'package:wonky_slides/features/stage/core_scene_handler.dart';
import 'package:wonky_slides/features/stage/flutter_text_layout_engine.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';

import 'stage_fixture.dart';

class _ShapeHandler extends ElementKindHandler with CoreSceneBuilding {
  const _ShapeHandler();

  @override
  ElementKind get kind => ElementKind.shape;

  @override
  bool hitTest(
    ResolvedElement e,
    Offset localSu, {
    required double tolerancePx,
  }) => false;
}

void main() {
  group('Given a kind handler using the core scene builder', () {
    test('when building an element then its group node draws the shape', () {
      final f = StageFixture();
      final id = f.shape(text: 'Via handler');
      final slide = SlideResolver(f.model).resolve(f.slideId)!;
      final e = slide.element(id)!;

      final node = const _ShapeHandler().buildScene(
        e,
        SceneContext(theme: slide.theme, textLayout: FlutterTextLayoutEngine()),
      );

      expect(node, isA<GroupNode>().having((g) => g.elementId, 'id', id));
      expect((node as GroupNode).children.whereType<PathNode>(), hasLength(1));
      expect(node.children.whereType<TextNode>(), hasLength(1));
    });

    test('when the element is hidden then an empty group is returned', () {
      final f = StageFixture();
      final id = f.b.element(
        f.slideId,
        ElementKind.shape,
        columns: const {'hidden': true},
      );
      final slide = SlideResolver(f.model).resolve(f.slideId)!;

      final node = const _ShapeHandler().buildScene(
        slide.element(id)!,
        SceneContext(theme: slide.theme, textLayout: FlutterTextLayoutEngine()),
      );

      expect((node as GroupNode).children, isEmpty);
    });
  });
}
