import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Matrix4, immutable;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesCols;
import 'package:wonky_slides_core/themes.dart' show BoxTextStyle, SuRect;

import 'slides_text_components.dart';

/// Where the text being edited sits and how it is laid out — taken from
/// the scene builder itself (one `TextLayoutEngine` for static and overlay
/// metrics, 12 R4): the element is rebuilt with the body being edited, so
/// auto-fit, `resize`, auto width, vertical anchor, insets, the shape's
/// text rectangle, rotation and flips are exactly the static renderer's.
@immutable
class TextEditGeometry {
  const TextEditGeometry({
    required this.textToSlide,
    required this.spec,
    required this.layout,
    required this.frame,
    this.cellBox,
  });

  /// The edited table cell's box in element-local su (SL-15), else null.
  final SuRect? cellBox;

  /// Text-local su (origin = top-left of the laid-out text) → slide su.
  final Matrix4 textToSlide;

  /// Styles, layout width and auto-fit scale of the overlay's paragraphs.
  final SlidesTextLayoutSpec spec;

  /// The static layout of the body (height, lines, `fitScale`).
  final TextLayoutResult layout;

  /// The element's effective box with this text (slide space, before
  /// rotation; auto-fit `resize` growth and auto width applied): the
  /// selection chrome follows it while typing (03 §6.1).
  final SuRect frame;

  /// Laid-out text height (su).
  double get contentHeight => layout.height;

  /// Computes the geometry of [element] on [slide] with the body [textJson]
  /// (the text being edited; null = the stored one). A blank body is laid
  /// out as one zero-width character with the same paragraph attributes,
  /// which has the height of an empty paragraph, so the caret of an empty
  /// box or placeholder sits where its first line will be. Null when the
  /// element holds no text.
  static TextEditGeometry? of({
    required ResolvedSlide slide,
    required ResolvedElement element,
    required TextLayoutEngine engine,
    String? textJson,
    DeckReader? deck,
    SlideSceneBuilder? builder,
  }) {
    final base = element.textStyles;
    if (base == null) return null;
    final json = textJson ?? element.text;
    var body = TextBody.fromJson(json);
    if (body.isBlank) body = TextBody([zeroWidthOp, ...body.ops]);
    final edited = withText(element, body.toJson());
    final scene = (builder ?? SlideSceneBuilder()).buildElements(
      element.id,
      [edited],
      width: slide.bounds.width,
      height: slide.bounds.height,
      background: slide.background,
      context: SceneContext(theme: slide.theme, textLayout: engine, deck: deck),
    );
    final node = scene.nodes.isEmpty ? null : scene.nodes.first;
    final found = _textNode(node, Matrix4.identity());
    if (found == null) return null;
    final (text, m) = found;
    final theme = slide.theme;
    final defaults = element.record.kind == ElementKind.shape
        ? theme.shapeStyles.shape
        : theme.shapeStyles.text;
    final styles = base.withBox(
      (defaults.textStyle ?? BoxTextStyle.empty).merge(element.textStyle),
    );
    return TextEditGeometry(
      textToSlide: m
        ..multiply(Matrix4.translationValues(text.originX, text.originY, 0)),
      spec: SlidesTextLayoutSpec(
        styles: styles,
        width: text.layout.width,
        scale: text.layout.fitScale,
      ),
      layout: text.layout,
      frame: scene.frames[element.id] ?? element.frame,
    );
  }

  /// The geometry of table cell [rowId] × [columnId] of [element] (SL-15,
  /// 03 §6.6): the cell's text laid out by the table layout of the scene
  /// builder (rows grow with the text, merges, padding, vertical align),
  /// with [textJson] as the cell's body (null = the stored one). A blank
  /// body is laid out as one zero-width character (the caret's line).
  static TextEditGeometry? ofCell({
    required ResolvedSlide slide,
    required ResolvedElement element,
    required TextLayoutEngine engine,
    required DeckReader deck,
    required String rowId,
    required String columnId,
    String? textJson,
    SlideSceneBuilder? builder,
  }) {
    final key = '$rowId|$columnId';
    final stored = deck is DeckModel
        ? deck.indexes.table(element.id).cell(rowId, columnId)?.text
        : null;
    var body = TextBody.fromJson(textJson ?? stored);
    if (body.isBlank) body = TextBody([zeroWidthOp, ...body.ops]);
    final grid = (builder ?? SlideSceneBuilder()).tableGrid(
      element,
      SceneContext(theme: slide.theme, textLayout: engine, deck: deck),
      cellText: {key: body.toJson()},
    );
    final cell = grid?.cellOf(rowId, columnId);
    final layout = cell?.layout;
    if (grid == null || cell == null || layout == null) return null;
    final o = cell.textOrigin(layout.height);
    final f = element.frame;
    final frame = SuRect(f.x, f.y, f.width, grid.height);
    return TextEditGeometry(
      textToSlide: elementMatrix(
        frame,
        rotation: element.rotation,
        flipH: element.flipH,
        flipV: element.flipV,
      )..multiply(Matrix4.translationValues(o.x, o.y, 0)),
      spec: SlidesTextLayoutSpec(
        styles: cell.styles,
        width: cell.textWidth,
        scale: layout.fitScale,
      ),
      layout: layout,
      frame: frame,
      cellBox: SuRect(cell.x, cell.y, cell.width, cell.height),
    );
  }

  /// Element-local su → slide su of a frame (the scene builder's element
  /// transform: rotation about the center, flips).
  static Matrix4 elementMatrix(
    SuRect f, {
    double rotation = 0,
    bool flipH = false,
    bool flipV = false,
  }) {
    final a0 = rotation * math.pi / 180;
    final cos = math.cos(a0), sin = math.sin(a0);
    final fx = flipH ? -1.0 : 1.0, fy = flipV ? -1.0 : 1.0;
    final a = cos * fx, b = sin * fx, c = -sin * fy, d = cos * fy;
    final cx = f.x + f.width / 2, cy = f.y + f.height / 2;
    final ex = cx - a * f.width / 2 - c * f.height / 2;
    final ey = cy - b * f.width / 2 - d * f.height / 2;
    return Matrix4(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, ex, ey, 0, 1);
  }

  /// The insert that stands in for a blank body.
  static const Map<String, Object?> zeroWidthOp = {'insert': '​'};

  /// A copy of [e] whose record holds [textJson].
  static ResolvedElement withText(ResolvedElement e, String? textJson) =>
      ResolvedElement(
        record: SlideElementRec({
          ...e.record.columns,
          SlidesCols.text: textJson,
        }),
        frame: e.frame,
        rotation: e.rotation,
        flipH: e.flipH,
        flipV: e.flipV,
        opacity: e.opacity,
        inherited: e.inherited,
        children: e.children,
        placeholderType: e.placeholderType,
        dangling: e.dangling,
        fill: e.fill,
        stroke: e.stroke,
        effects: e.effects,
        data: e.data,
        textStyle: e.textStyle,
        styleKey: e.styleKey,
        textStyles: e.textStyles,
        prompt: e.prompt,
        fieldText: e.fieldText,
        parentId: e.parentId,
      );

  static (TextNode, Matrix4)? _textNode(SceneNode? node, Matrix4 m) {
    switch (node) {
      case TextNode():
        return (node, m);
      case GroupNode():
        final inner = m.multiplied(node.transform);
        for (final c in node.children) {
          final r = _textNode(c, inner);
          if (r != null) return r;
        }
        return null;
      default:
        return null;
    }
  }
}

/// [scene] without the text of [elementId] (the overlay draws it while
/// the element is being edited); fills, strokes and everything else stay.
/// With [partId] only that body goes (a table cell, SL-15).
SlideScene sceneWithoutText(
  SlideScene scene,
  String elementId, {
  String? partId,
}) {
  SceneNode? strip(SceneNode n, bool inside) {
    final mine = inside || n.elementId == elementId;
    switch (n) {
      case TextNode() when mine && (partId == null || n.partId == partId):
        return null;
      case PromptNode() when mine && partId == null:
        return null;
      case GroupNode():
        if (!mine && !_contains(n, elementId)) return n;
        return GroupNode(
          elementId: n.elementId,
          transform: n.transform,
          opacity: n.opacity,
          clip: n.clip,
          effects: n.effects,
          children: [for (final c in n.children) ?strip(c, mine)],
        );
      default:
        return n;
    }
  }

  return SlideScene(
    slideId: scene.slideId,
    width: scene.width,
    height: scene.height,
    background: scene.background,
    nodes: [for (final n in scene.nodes) ?strip(n, false)],
    frames: scene.frames,
    routes: scene.routes,
  );
}

bool _contains(GroupNode g, String id) => g.children.any(
  (c) => c.elementId == id || (c is GroupNode && _contains(c, id)),
);
