import 'dart:convert';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/fonts.dart';
import 'package:wonky_app/wonky_app.dart' show UndoService;
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_slides/features/model/memory_deck_session.dart';
import 'package:wonky_slides/features/stage/flutter_text_layout_engine.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/stage/slide_stage.dart';
import 'package:wonky_slides/features/text_editing/slide_text_editor.dart';
import 'package:wonky_slides/features/text_editing/text_edit_geometry.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/planner.dart';
import 'package:wonky_slides_core/scene.dart' show TextParagraphs;
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/session.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart'
    show SlidePlaceholderType, SlidesFonts;

/// Serves the bundled font files of `wonky_fonts` from disk (tests load the
/// real faces, 15 §4: "goldens load bundled fonts only").
class DiskFontBundle extends CachingAssetBundle {
  DiskFontBundle(this.root);

  /// The `wonky_fonts/fonts` folder.
  final Directory root;

  /// The bundle of the workspace's `wonky_fonts` package (tests run in
  /// the package folder).
  static DiskFontBundle locate() => DiskFontBundle(
    Directory('${Directory.current.path}/../packages/wonky_fonts/fonts'),
  );

  @override
  Future<ByteData> load(String key) async {
    final name = key.split('/').last;
    final bytes = await File('${root.path}/$name').readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

/// Real fonts registered with the engine once per test process.
final AssetFontRegistry realFonts = AssetFontRegistry(
  bundle: DiskFontBundle.locate(),
);

/// A deck with one blank slide, a memory session, a renderer (real fonts)
/// and an undo service wired like the editor (`slides.rows`).
class TextEditFixture {
  TextEditFixture({String layoutKey = 'blank', String? title}) {
    slideId = b.slide(layoutKey: layoutKey, title: title);
  }

  final DeckBuilder b = DeckBuilder();
  late final String slideId;

  late final MemoryDeckSession session = MemoryDeckSession(
    itemUuid: UuidValue.fromString(b.deckId),
    userId: '00000000-0000-7000-8000-000000000001',
    model: DeckModel.fromRows(b.deckId, b.rows),
    planner: const SlidesPlanner(),
  );

  late final SlideRenderer renderer = SlideRenderer(
    model: session.model,
    fonts: realFonts,
  );

  late final UndoService undo = UndoService()
    ..registerHandler(SlidesRowsUndoHandler(() => session));

  /// A text-capable element with a Delta [ops] body.
  String element(
    List<Map<String, Object?>> ops, {
    ElementKind kind = ElementKind.text,
    double x = 200,
    double y = 150,
    double w = 900,
    double h = 200,
    double rotation = 0,
    Map<String, Object?>? textStyle,
    Map<String, Object?>? data,
  }) => b.element(
    slideId,
    kind,
    x: x,
    y: y,
    width: w,
    height: h,
    rotation: rotation == 0 ? null : rotation,
    columns: {
      SlidesCols.text: jsonEncode(ops),
      ElementCols.textStyleJson: ?(textStyle == null
          ? null
          : jsonEncode({'v': 1, ...textStyle})),
      ElementCols.dataJson: ?(data == null
          ? null
          : jsonEncode({'v': 1, ...data})),
    },
  );

  /// The slide's placeholder instance of [type].
  String placeholder(SlidePlaceholderType type) =>
      slide.elements.firstWhere((e) => e.placeholderType == type).id;

  /// Loads every font family the slide draws with (real metrics).
  Future<void> loadFonts(WidgetTester tester) async {
    await tester.runAsync(() => realFonts.ensureAll(SlidesFonts.families));
    renderer.textLayout.clear();
  }

  /// The resolved slide.
  ResolvedSlide get slide => renderer.resolver.resolve(slideId)!;

  /// A controller over [elementId] that records typing steps.
  SlideTextEditController controller(String elementId, {int? caretOffset}) {
    late final SlideTextEditController c;
    c = SlideTextEditController(
      session: session,
      renderer: renderer,
      slideId: slideId,
      elementId: elementId,
      caretOffset: caretOffset,
      onCommitted: (plan) =>
          recordTypingStep(undo, plan, coalesceKey: c.coalesceKey),
    );
    return c;
  }

  /// The static geometry of [elementId] (stored body).
  TextEditGeometry geometry(String elementId) => TextEditGeometry.of(
    slide: slide,
    element: slide.element(elementId)!,
    engine: renderer.textLayout,
    deck: session.model,
  )!;
}

/// Key of the static stage layer in [pumpEditing].
const stageKey = ValueKey<String>('test.stage');

/// Key of the boundary around stage + overlay.
const canvasKey = ValueKey<String>('test.canvas');

/// Pumps the slide at [zoom] with the edited element's static text hidden
/// and the overlay on top (or, with [overlay] false, the plain static
/// rendering).
Future<void> pumpEditing(
  WidgetTester tester,
  TextEditFixture f,
  SlideTextEditController? c, {
  double zoom = 0.5,
  bool overlay = true,
  Color caretColor = const Color(0xFF2563EB),
  double? overlayZoom,
}) async {
  final scene = f.renderer.scene(f.slideId)!;
  final shown = c != null && overlay
      ? sceneWithoutText(scene, c.elementId)
      : scene;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 800)),
        child: Overlay(
          // A new overlay per pump (initial entries are read once).
          key: UniqueKey(),
          initialEntries: [
            OverlayEntry(
              builder: (_) => Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: canvasKey,
                  child: SizedBox(
                    width: scene.width * zoom,
                    height: scene.height * zoom,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SlideStage(key: stageKey, scene: shown, scale: zoom),
                        if (c != null && overlay)
                          Positioned.fill(
                            child: SlideTextEditorOverlay(
                              controller: c,
                              zoom: overlayZoom ?? zoom,
                              caretColor: caretColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Asserts that the overlay's paragraphs equal the static engine's.
void expectOverlayMatchesStatic(
  WidgetTester tester,
  SlideTextEditController c,
) {
  final overlay = overlayParagraphs(tester);
  final placed = staticParagraphs(c);
  final root = tester.renderObject<RenderBox>(
    find.descendant(
      of: find.byType(SlideTextEditorOverlay),
      matching: find.byType(CustomScrollView),
    ),
  );

  expect(overlay, hasLength(placed.length));
  expect(
    root.size.height,
    moreOrLessEquals(c.geometry.contentHeight, epsilon: 0.01),
    reason: 'overlay height = static content height',
  );
  expect(root.size.width, moreOrLessEquals(c.geometry.spec.width));
  for (var i = 0; i < overlay.length; i++) {
    final rp = overlay[i];
    final p = placed[i];
    final origin = rp.localToGlobal(Offset.zero, ancestor: root);
    expect(origin.dx, moreOrLessEquals(p.dx, epsilon: 0.01), reason: 'x #$i');
    expect(origin.dy, moreOrLessEquals(p.dy, epsilon: 0.01), reason: 'y #$i');
    final text = rp.text.toPlainText(includePlaceholders: false);
    expect(
      rp.size.height,
      moreOrLessEquals(p.paragraph.height, epsilon: 0.01),
      reason: 'height of paragraph #$i',
    );
    for (var j = 0; j < text.length; j++) {
      final a = rp.getBoxesForSelection(
        TextSelection(baseOffset: j, extentOffset: j + 1),
      );
      final b = p.paragraph.getBoxesForRange(j, j + 1);
      expect(a.length, b.length, reason: 'boxes of char $j in #$i');
      for (var k = 0; k < a.length; k++) {
        expect(
          [a[k].left, a[k].top, a[k].right, a[k].bottom],
          pairwise((num x, num y) => (x - y).abs() < 0.01, [
            b[k].left,
            b[k].top,
            b[k].right,
            b[k].bottom,
          ]),
          reason: 'char $j "${text[j]}" of paragraph #$i',
        );
      }
    }
  }
}

Matcher pairwise(bool Function(num, num) same, List<num> expected) =>
    predicate<List<num>>(
      (actual) =>
          actual.length == expected.length &&
          [for (var i = 0; i < actual.length; i++) same(actual[i], expected[i])]
              .every((x) => x),
      'equals $expected',
    );

/// The overlay's text paragraphs in document order.
List<RenderParagraph> overlayParagraphs(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byType(SlideTextEditorOverlay),
            matching: find.byWidgetPredicate((w) => w is RichText),
          )
          .evaluate())
    e.renderObject! as RenderParagraph,
];

/// The static engine's text paragraphs (markers skipped) of the body being
/// edited.
List<PlacedParagraph> staticParagraphs(SlideTextEditController c) {
  final spec = c.geometry.spec;
  final body = c.mapper.bodyOf(c.document);
  final layout = c.renderer.textLayout.layout(
    body,
    spec.styles,
    width: spec.width,
    scale: spec.scale,
  );
  final placed = FlutterTextLayoutEngine.paragraphsOf(layout)!.paragraphs;
  final paras = TextParagraphs.build(body, spec.styles, scale: spec.scale);
  final out = <PlacedParagraph>[];
  var k = 0;
  for (final p in paras) {
    out.add(placed[k++]);
    if (p.marker != null) k++;
  }
  return out;
}
