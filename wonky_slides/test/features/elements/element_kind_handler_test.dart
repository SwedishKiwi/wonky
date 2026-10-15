import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/elements/element_kind_handler.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/testing.dart';

/// A rectangle handler as the shape handler (SL-14) will register it.
class _RectHandler extends ElementKindHandler {
  const _RectHandler();

  @override
  ElementKind get kind => ElementKind.shape;

  @override
  SceneNode buildScene(ResolvedElement e, SceneContext ctx) => PathNode(
    elementId: e.id,
    path: ScenePath([
      const PMoveTo(0, 0),
      PLineTo(e.frame.width, 0),
      PLineTo(e.frame.width, e.frame.height),
      const PClose(),
    ]),
  );

  @override
  bool hitTest(
    ResolvedElement e,
    Offset localSu, {
    required double tolerancePx,
  }) =>
      localSu.dx >= 0 &&
      localSu.dy >= 0 &&
      localSu.dx <= e.frame.width &&
      localSu.dy <= e.frame.height;
}

void main() {
  group('Given a registry with a shape handler', () {
    final b = DeckBuilder();
    final slide = b.slide(layoutKey: 'blank');
    final shape = b.shape(slide, width: 200, height: 100);
    final model = b.build();
    final record = model.element(shape)!;
    final resolved = ResolvedElement(record: record, frame: record.frame!);

    test('when looking up an element then its kind handler answers hit '
        'tests and default snap points', () {
      final registry = ElementKindRegistry([const _RectHandler()]);

      final h = registry.of(resolved)!;
      expect(h.hitTest(resolved, const Offset(10, 10), tolerancePx: 4), isTrue);
      expect(
        h.hitTest(resolved, const Offset(250, 10), tolerancePx: 4),
        isFalse,
      );
      expect(h.snapPoints(resolved), hasLength(3));
      expect(h.activation(resolved), ElementActivation.none);
      expect(registry[ElementKind.chart], isNull);
    });

    test('when a second handler of the same kind registers then it is '
        'refused unless replacing', () {
      final registry = ElementKindRegistry([const _RectHandler()]);

      expect(() => registry.register(const _RectHandler()), throwsStateError);
      registry.register(const _RectHandler(), replace: true);
      expect(registry.kinds, [ElementKind.shape]);
    });
  });
}
