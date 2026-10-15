import 'dart:convert';

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart' show SlideAppearance;
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

/// A deck with one blank slide plus helpers to add elements and build its
/// scene with the core text layout engine.
final class SceneFixture {
  SceneFixture({String layoutKey = 'blank', String? theme}) {
    if (theme != null) b.theme(theme);
    slideId = b.slide(layoutKey: layoutKey);
  }

  final DeckBuilder b = DeckBuilder();
  late final String slideId;
  final SlideTextLayout engine = SlideTextLayout();
  final SlideSceneBuilder builder = SlideSceneBuilder();

  String shape({
    double x = 100,
    double y = 100,
    double w = 400,
    double h = 200,
    String geometry = 'rect',
    String? text,
    Map<String, Object?> columns = const {},
    Map<String, Object?>? data,
    String? parentId,
  }) => b.element(
    slideId,
    ElementKind.shape,
    x: x,
    y: y,
    width: w,
    height: h,
    parentId: parentId,
    columns: {
      ElementCols.dataJson: jsonEncode(data ?? {'v': 1, 'geometry': geometry}),
      if (text != null) SlidesCols.text: deltaOf(text),
      ...columns,
    },
  );

  String element(
    ElementKind kind, {
    double x = 100,
    double y = 100,
    double w = 400,
    double h = 200,
    double? rotation,
    Map<String, Object?> columns = const {},
    String? parentId,
    String? id,
  }) => b.element(
    slideId,
    kind,
    x: x,
    y: y,
    width: w,
    height: h,
    rotation: rotation,
    parentId: parentId,
    id: id,
    columns: columns,
  );

  /// A line from ([x1], [y1]) to ([x2], [y2]) (slide space), optionally
  /// glued.
  String line(
    double x1,
    double y1,
    double x2,
    double y2, {
    String routing = 'straight',
    (String, String)? startGlue,
    (String, String)? endGlue,
    Map<String, Object?>? stroke,
    List<(double, double)> waypoints = const [],
  }) {
    final x = x1 < x2 ? x1 : x2, y = y1 < y2 ? y1 : y2;
    final w = (x2 - x1).abs(), h = (y2 - y1).abs();
    double nx(double v) => w == 0 ? 0 : (v - x) / w;
    double ny(double v) => h == 0 ? 0 : (v - y) / h;
    Map<String, Object?>? glue((String, String)? g) =>
        g == null ? null : {'elementId': Base62Uuid.encode(g.$1), 'site': g.$2};
    return element(
      ElementKind.line,
      x: x,
      y: y,
      w: w,
      h: h,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'routing': routing,
          'start': {'x': nx(x1), 'y': ny(y1), 'connect': glue(startGlue)},
          'end': {'x': nx(x2), 'y': ny(y2), 'connect': glue(endGlue)},
          if (waypoints.isNotEmpty)
            'waypoints': [
              for (final (px, py) in waypoints) [nx(px), ny(py)],
            ],
        }),
        if (stroke != null) ElementCols.strokeJson: jsonEncode(stroke),
      },
    );
  }

  DeckModel model() => b.build();

  ResolvedSlide resolve({DeckModel? model, SlideAppearance? appearance}) =>
      SlideResolver(
        model ?? this.model(),
      ).resolve(slideId, appearance: appearance)!;

  SlideScene scene({
    DeckModel? model,
    bool editing = false,
    ScenePurpose purpose = ScenePurpose.edit,
    SlideAppearance? appearance,
    SlideIconSource? icons,
    ChartSceneSource? charts,
  }) {
    final m = model ?? this.model();
    final slide = resolve(model: m, appearance: appearance);
    return builder.build(
      slide,
      SceneContext(
        theme: slide.theme,
        textLayout: engine,
        editing: editing,
        deck: m,
        purpose: purpose,
        icons: icons,
        charts: charts,
      ),
    );
  }

  /// The element group node of [id].
  static GroupNode groupOf(SlideScene scene, String id) =>
      scene.nodesOf(id).whereType<GroupNode>().first;

  /// Every node below [n] (depth first).
  static Iterable<SceneNode> descendants(SceneNode n) sync* {
    yield n;
    if (n is GroupNode) {
      for (final c in n.children) {
        yield* descendants(c);
      }
    }
  }
}
