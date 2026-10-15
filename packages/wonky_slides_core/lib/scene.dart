/// The renderer-independent slide scene of Wonky Slides (specs/wonky_slides
/// 02 §11, 03 §1, 12 §5.4): scene nodes (`GroupNode`, `PathNode`,
/// `ImageNode`, `TextNode`, `ChartNode`, `CodeNode`, `PromptNode`),
/// `SlideScene`, paint values, the `TextLayoutEngine` contract and the code
/// sub-scene; and (SL-10) the `SlideSceneBuilder`, the `ShapeLibrary`
/// geometry, connector routing (`ConnectorRouter`, `ArrowHeads`), auto-fit
/// (`AutoFit`), the shared paragraph model (`TextParagraphs`) and the
/// pure-Dart `SlideTextLayout` engine.
///
/// Pure Dart (client, server, MCP).
library;

// Path commands of the shared chart engine, used by `ScenePath`.
export 'package:wonky_charts/wonky_charts.dart'
    show
        PathCmd,
        PMoveTo,
        PLineTo,
        PCubicTo,
        PClose,
        PathBuilder,
        ChartScene,
        SStrokeCap,
        SStrokeJoin;

export 'src/connectors/connector_router.dart';
export 'src/geometry/path_ops.dart';
export 'src/geometry/shape_library.dart';
export 'src/geometry/svg_path.dart';
export 'src/layout/auto_fit.dart';
export 'src/scene/builder/code_layout.dart';
export 'src/scene/builder/image_adjust.dart';
export 'src/scene/builder/paint_resolve.dart';
export 'src/scene/builder/slide_scene_builder.dart';
export 'src/scene/hit/scene_hit_test.dart';

export 'src/scene/nodes/code_scene.dart';
export 'src/scene/nodes/scene_nodes.dart';
export 'src/scene/nodes/text_layout.dart';
export 'src/text_layout/slide_text_layout.dart';
export 'src/text_layout/text_paragraphs.dart';
