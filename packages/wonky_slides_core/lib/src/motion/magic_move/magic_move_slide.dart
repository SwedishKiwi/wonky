/// What Magic Move sees of a slide (06 §8.1, §8.3): the elements of one
/// frame (the outgoing slide's final frame, the incoming slide's initial
/// frame) with what the matcher and the morph plan need — match key, kind,
/// name, content signature, geometry, colors, outlines, laid-out text, code,
/// chart camera, image crop and group children.
///
/// [MagicMoveSlide.fromDeck] builds it from a deck; tests and renderers with
/// their own geometry can build the elements directly.
library;

import 'dart:convert';

import 'package:wonky_code/wonky_code.dart' show CodeLayout;

import '../../code/code_element_layout.dart';
import '../../model/api/deck_model.dart';
import '../../model/api/deck_reader.dart';
import '../../model/api/kinds.dart';
import '../../model/api/resolved.dart';
import '../../model/resolve/slide_resolver.dart';
import '../../scene/builder/slide_scene_builder.dart';
import '../../scene/nodes/scene_nodes.dart';
import '../../scene/nodes/text_layout.dart';
import '../../text_layout/slide_text_layout.dart';
import '../../theme/model/common.dart' show SuRect;
import '../../theme/resolve/resolved_theme.dart';
import '../builds/parts.dart' show MotionText;
import '../timeline/slide_frame.dart';
import '../util/seeded_random.dart' show stableHash;
import 'chart_camera.dart';
import 'morph_geometry.dart';

/// Laid-out text of an element (text boxes, shapes with text): the plain
/// text and its layout in element-local space.
final class MagicMoveText {
  /// Creates a text.
  const MagicMoveText({
    required this.plain,
    this.layout,
    this.originX = 0,
    this.originY = 0,
    this.rangeBox,
  });

  /// The body's plain text (the offsets of the layout).
  final String plain;

  /// The text layout, or null (glyph morphs then fall back to crossfade).
  final TextLayoutResult? layout;

  /// Origin of [layout] in the element's local space (su).
  final double originX, originY;

  /// Exact element-local box of a character range on one line, or null
  /// (the renderer's text engine — Flutter `TextPainter` — can supply exact
  /// glyph boxes; by default the run widths are split by character
  /// advance classes, exact for the core's approximate measurer).
  final SuRect? Function(int start, int end)? rangeBox;
}

/// The displayed code of a code element (07 §5.6 token morph).
final class MagicMoveCode {
  /// Creates the code.
  const MagicMoveCode({
    required this.code,
    this.language = '',
    this.stateIndex = 0,
    this.layout,
    this.originX = 0,
    this.originY = 0,
  });

  /// Source of the displayed state.
  final String code;
  final String language;

  /// The displayed state (0-based).
  final int stateIndex;

  /// The state's layout at the element's size, or null (unwrapped default
  /// layout).
  final CodeLayout? layout;

  /// Top-left of the code area in the element's local space (su).
  final double originX, originY;
}

/// The chart of a chart element: its data source (Magic Move morphs the
/// chart scene only between charts of the same source, 08 §9.4) and the 3D
/// camera.
final class MagicMoveChart {
  /// Creates the chart.
  const MagicMoveChart({required this.source, this.dataHash = 0, this.camera});

  /// `link:<spreadsheet>/<chart>` or `data:<hash>`.
  final String source;

  /// Hash of the chart's data and spec (snapshot): equal = same picture.
  final int dataHash;

  /// The 3D camera shown (authored `dataJson.camera`, or a persistent
  /// `chartCamera` emphasis of the frame), or null (2D, or the default).
  final ChartCameraView? camera;
}

/// The image of an image element.
final class MagicMoveImage {
  /// Creates the image.
  const MagicMoveImage({required this.src, this.crop});

  /// `dataJson.src` (file uuid or URL).
  final String src;

  /// `dataJson.crop` (image fractions `{x, y, w, h}`), or null.
  final Map<String, Object?>? crop;
}

/// One element of a [MagicMoveSlide].
final class MagicMoveElement {
  /// Creates an element.
  MagicMoveElement({
    required this.id,
    required this.kind,
    required this.frame,
    this.matchKey = '',
    this.name,
    this.rotation = 0,
    this.literalRotation,
    this.opacity = 1,
    this.z = 0,
    this.signature,
    this.contentKey,
    this.geometryKey,
    this.fillColor,
    this.strokeColor,
    this.outline,
    this.text,
    this.code,
    this.chart,
    this.image,
    this.children = const [],
    ElementVisualState? state,
  }) : state = state ?? ElementVisualState.edit;

  final String id;
  final ElementKind kind;

  /// `SlideElement.matchKey` (06 §8.2); empty = none.
  final String matchKey;

  /// `SlideElement.name` (pass 3).
  final String? name;

  /// Effective frame (su, unrotated).
  final SuRect frame;

  /// Effective rotation (degrees clockwise, `[0, 360)`).
  final double rotation;

  /// The stored rotation (`rotation: literal`), or null = [rotation].
  final double? literalRotation;

  /// Effective opacity (0..1, group opacity included).
  final double opacity;

  /// Paint rank among its siblings (back to front).
  final int z;

  /// Content signature of pass 2 (06 §8.3), or null (never matched by
  /// content).
  final String? signature;

  /// Everything drawn except geometry and solid colors: two matched
  /// elements with the same key draw the same content (no crossfade).
  /// Null = always crossfade (tables).
  final String? contentKey;

  /// Shape geometry (type + adjustments): equal keys resize, different
  /// keys morph the outline (or crossfade).
  final String? geometryKey;

  /// Solid fill and stroke colors (ARGB), or null: interpolated in OKLab.
  final int? fillColor, strokeColor;

  /// The shape body's outline in element-local space (path morph).
  final ScenePath? outline;
  final MagicMoveText? text;
  final MagicMoveCode? code;
  final MagicMoveChart? chart;
  final MagicMoveImage? image;

  /// Children of an element group, back to front.
  final List<MagicMoveElement> children;

  /// The element's state in its frame (the outgoing slide's final state:
  /// persistent emphasis, dimmed parts; the incoming slide's initial state).
  final ElementVisualState state;

  /// The geometry the audience sees (the frame state's transform applied).
  late final MorphGeometry geometry = MorphGeometry.of(
    frame,
    rotation,
    state.transform,
  );

  /// The opacity the audience sees.
  double get shownOpacity => opacity * state.opacity;

  /// Every element of this subtree (this first).
  Iterable<MagicMoveElement> get subtree sync* {
    yield this;
    for (final c in children) {
      yield* c.subtree;
    }
  }
}

/// A slide as Magic Move sees it.
final class MagicMoveSlide {
  /// Creates a slide.
  MagicMoveSlide({
    required this.slideId,
    this.width = 1920,
    this.height = 1080,
    required this.elements,
    this.frame = SlideFrame.edit,
    this.chrome = const [],
    this.chromeKey = '',
    this.backgroundKey = '',
  });

  final String slideId;

  /// Slide size (su).
  final double width, height;

  /// Top-level elements shown in [frame], back to front (elements hidden in
  /// the frame — builds, `hidden` — are left out).
  final List<MagicMoveElement> elements;

  /// The frame the elements come from (A's `finalFrame`, B's `initial`).
  final SlideFrame frame;

  /// Ids of the layout/master decorations drawn under the elements.
  final List<String> chrome;

  /// Equal keys = the same layout/master decorations (they stay still).
  final String chromeKey;

  /// Equal keys = the same background (no crossfade).
  final String backgroundKey;

  /// The slide of [slideId] in [deck] shown with [frame]: elements from
  /// [resolved] (or a `SlideResolver` when [deck] is a `DeckModel`), shapes,
  /// text layout, colors and code from [scene] (built with
  /// [textLayout] — default: the core's `SlideTextLayout` — when not
  /// given).
  factory MagicMoveSlide.fromDeck(
    DeckReader deck,
    String slideId, {
    SlideFrame frame = SlideFrame.edit,
    ResolvedSlide? resolved,
    SlideScene? scene,
    TextLayoutEngine? textLayout,
  }) {
    final rs =
        resolved ??
        (deck is DeckModel ? SlideResolver(deck).resolve(slideId) : null);
    if (rs == null) {
      throw ArgumentError.value(slideId, 'slideId', 'Cannot resolve slide');
    }
    final sc =
        scene ??
        SlideSceneBuilder().build(
          rs,
          SceneContext(
            theme: rs.theme,
            textLayout: textLayout ?? SlideTextLayout(),
            deck: deck,
            purpose: ScenePurpose.present,
          ),
        );
    final b = _SlideReader(deck, rs, sc, frame);
    final elements = <MagicMoveElement>[];
    var z = 0;
    for (final e in rs.elements) {
      final m = b.element(e, z);
      if (m != null) {
        elements.add(m);
        z++;
      }
    }
    final chrome = [
      for (final e in rs.masterElements)
        if (!e.hidden) e.id,
      for (final e in rs.layoutElements)
        if (!e.hidden) e.id,
    ];
    return MagicMoveSlide(
      slideId: slideId,
      width: sc.width,
      height: sc.height,
      elements: elements,
      frame: frame,
      chrome: chrome,
      chromeKey: '${rs.layout?.id}|${rs.master?.id}|${chrome.join(',')}',
      backgroundKey:
          '${rs.slide.backgroundJson ?? ''}|${rs.layout?.backgroundJson ?? ''}'
          '|${rs.master?.backgroundJson ?? ''}|${rs.theme.contentHash}',
    );
  }
}

/// Builds [MagicMoveElement]s of one resolved slide.
final class _SlideReader {
  _SlideReader(this.deck, this.slide, this.scene, this.frame);

  final DeckReader deck;
  final ResolvedSlide slide;
  final SlideScene scene;
  final SlideFrame frame;

  ResolvedTheme get theme => slide.theme;

  MagicMoveElement? element(ResolvedElement e, int z) {
    if (e.hidden) return null;
    final state = frame.stateOf(e.id);
    if (!state.visible) return null;
    final rec = e.record;
    final kind = rec.kind;
    final children = <MagicMoveElement>[];
    if (kind == ElementKind.group) {
      var cz = 0;
      for (final c in e.children) {
        final m = element(c, cz);
        if (m != null) {
          children.add(m);
          cz++;
        }
      }
    }
    final node = scene.nodesOf(e.id).whereType<GroupNode>().firstOrNull;
    PathNode? body;
    TextNode? textNode;
    if (node != null && kind != ElementKind.group) {
      for (final n in _walk(node.children)) {
        if (body == null && n is PathNode && n.fill != null) body = n;
        if (textNode == null && n is TextNode && n.partId == null) {
          textNode = n;
        }
      }
    }
    final data = e.data ?? const <String, Object?>{};
    final plain = kind.hasText ? MotionText.fromDelta(rec.text).plain : null;
    MagicMoveText? text;
    if (plain != null && plain.trim().isNotEmpty) {
      text = MagicMoveText(
        plain: plain,
        layout: textNode?.layout,
        originX: textNode?.originX ?? 0,
        originY: textNode?.originY ?? 0,
      );
    }
    final code = kind == ElementKind.code ? _code(e, state) : null;
    final chart = kind == ElementKind.chart ? _chart(e, data, state) : null;
    MagicMoveImage? image;
    if (kind == ElementKind.image && data['src'] is String) {
      image = MagicMoveImage(
        src: data['src']! as String,
        crop: data['crop'] is Map
            ? (data['crop']! as Map).cast<String, Object?>()
            : null,
      );
    }
    final fill = body?.fill;
    final normText = plain == null ? '' : _normalize(plain);
    final signature = switch (kind) {
      ElementKind.text => normText.isEmpty ? null : 'text:$normText',
      ElementKind.shape => 'shape:${data['geometry']}|$normText',
      ElementKind.image => image == null ? null : 'image:${image.src}',
      ElementKind.chart => chart == null ? null : 'chart:${chart.source}',
      ElementKind.code => code == null ? null : 'code:${code.code}',
      ElementKind.icon =>
        'icon:${data['set'] ?? 'lucide'}:${data['name'] ?? data['char']}',
      _ => null,
    };
    final strip = switch (kind) {
      ElementKind.shape => const {'geometry', 'adjust'},
      ElementKind.chart => const {'camera'},
      ElementKind.image => const {'crop'},
      _ => const <String>{},
    };
    final contentKey = kind == ElementKind.table || kind == ElementKind.group
        ? null
        : [
            kind.name,
            jsonEncode(_without(data, strip)),
            rec.text ?? '',
            rec.textStyleJson ?? '',
            rec.effectsJson ?? '',
            _fillKind(fill),
            body?.stroke == null
                ? 'nostroke'
                : 'stroke:${body!.stroke!.width}:${body.stroke!.dash}',
            if (code != null) '${code.stateIndex}:${code.code}',
            if (chart != null) '${chart.dataHash}',
          ].join('\u0001');
    return MagicMoveElement(
      id: e.id,
      kind: kind,
      matchKey: rec.matchKey,
      name: rec.name,
      frame: scene.frameOf(e),
      rotation: e.rotation,
      literalRotation: rec.rotation,
      opacity: e.opacity,
      z: z,
      signature: signature,
      contentKey: contentKey,
      geometryKey: kind == ElementKind.shape
          ? '${data['geometry']}|${jsonEncode(data['adjust'])}'
          : null,
      fillColor: fill is ResolvedSolidFill ? fill.color : null,
      strokeColor: body?.stroke?.color,
      outline: kind == ElementKind.shape ? body?.path : null,
      text: text,
      code: code,
      chart: chart,
      image: image,
      children: children,
      state: state,
    );
  }

  MagicMoveCode? _code(ResolvedElement e, ElementVisualState state) {
    final states = deck.codeStatesOf(e.id);
    if (states.isEmpty) return null;
    final i = (state.code?.stateIndex ?? state.codeStateIndex ?? 0).clamp(
      0,
      states.length - 1,
    );
    final s = states[i];
    final f = scene.frameOf(e);
    try {
      final composer = const CodeElementLayout().composer(e, deck, theme);
      final fit = composer.fit(f.width, f.height, [i]);
      final g = composer.geometry(f.width, f.height, fit.fontSize, i);
      return MagicMoveCode(
        code: s.code,
        language: s.language ?? composer.data.language,
        stateIndex: i,
        layout: CodeLayout.layout(s.code, g.layoutOptions()),
        originX: g.codeArea.left,
        originY: g.codeArea.top,
      );
    } on Object {
      return MagicMoveCode(
        code: s.code,
        language: s.language ?? '',
        stateIndex: i,
      );
    }
  }

  MagicMoveChart _chart(
    ResolvedElement e,
    Map<String, Object?> data,
    ElementVisualState state,
  ) {
    final link = deck.chartLinkOf(e.id);
    final source = link != null
        ? 'link:${link.spreadsheetItemUuid}/${link.chartObjectId}'
        : 'data:${stableHash(jsonEncode([data['spec'], data['data'], data['snapshot']]))}';
    final dataHash = stableHash(
      [
        link?.dataSnapshotJson ?? '',
        link?.sourceSpecJson ?? '',
        jsonEncode(_without(data, const {'camera'})),
      ].join('\u0001'),
    );
    var camera = ChartCameraView.fromJson(data['camera']);
    final cs = state.chart;
    if (cs != null && cs.camera != null && cs.cameraMix >= 1) {
      camera = ChartCameraView.fromJson(
        cs.camera,
        fallback: camera ?? ChartCameraView.defaults,
      );
    }
    return MagicMoveChart(source: source, dataHash: dataHash, camera: camera);
  }

  static Iterable<SceneNode> _walk(List<SceneNode> nodes) sync* {
    for (final n in nodes) {
      yield n;
      if (n is GroupNode && n.elementId == null) yield* _walk(n.children);
    }
  }

  static String _normalize(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ');

  static Map<String, Object?> _without(
    Map<String, Object?> m,
    Set<String> keys,
  ) => {
    for (final k in m.keys.toList()..sort())
      if (!keys.contains(k)) k: m[k],
  };

  static String _fillKind(ResolvedFill? f) => switch (f) {
    null => 'nofill',
    ResolvedSolidFill() => 'solid',
    ResolvedNoFill() => 'none',
    _ => 'fill:${f.runtimeType}:${f.representativeColor}',
  };
}
