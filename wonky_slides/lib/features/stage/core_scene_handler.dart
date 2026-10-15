import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';

import '../elements/element_kind_handler.dart';

/// [ElementKindHandler.buildScene] through the core `SlideSceneBuilder`
/// (03 §1.3: "implemented in core"). Kind handlers (SL-12…SL-15, SL-31,
/// SL-32) mix this in; the stage itself builds whole slides with
/// `SlideRenderer`, which also resolves glued connectors.
mixin CoreSceneBuilding on ElementKindHandler {
  static final SlideSceneBuilder _builder = SlideSceneBuilder();

  @override
  SceneNode buildScene(ResolvedElement e, SceneContext ctx) =>
      _builder.buildElement(e, ctx) ??
      GroupNode(elementId: e.id, children: const []);
}
