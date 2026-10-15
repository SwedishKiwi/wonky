import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/pdf.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/testing.dart';

import '../../support/chart_fixture.dart';
import '../../support/pdf_fixture.dart';

/// PDF builds as pages, the final animation state and frame content
/// (Slides 10 §11.1–§11.3, 06 §9.6; SL-33).
void main() {
  String fill(String hex) =>
      jsonEncode({'v': 1, 'type': 'solid', 'color': hex});

  /// The `rg` fill operator of [hex] as the PDF writes it.
  String rg(int r, int g, int b) {
    String c(int v) {
      final s = (v / 255).toStringAsFixed(5);
      return s.replaceFirst(RegExp(r'\.?0+$'), '');
    }

    return '${c(r)} ${c(g)} ${c(b)} rg';
  }

  int count(String pdf, String op) => op.allMatches(pdf).length;

  /// The page content streams of an uncompressed [pdf], in page order.
  List<String> contents(String pdf) => [
    for (final m in RegExp(
      r'stream\r?\n(.*?)endstream',
      dotAll: true,
    ).allMatches(pdf))
      if (m.group(1)!.contains(' cm')) m.group(1)!,
  ];

  String opts(Map<String, Object?> o) => jsonEncode({'v': 1, ...o});

  group('Given a slide whose three shapes build in on clicks', () {
    late DeckBuilder b;
    late String slide, a;
    setUp(() {
      b = DeckBuilder(title: 'Builds');
      slide = b.slide(layoutKey: 'blank');
      a = b.shape(slide, x: 100, fillJson: fill('#123456'));
      final s2 = b.shape(slide, x: 600, fillJson: fill('#00ff00'));
      final s3 = b.shape(slide, x: 1100, fillJson: fill('#0000ff'));
      for (final id in [a, s2, s3]) {
        b.build_(slide, id);
      }
    });

    test('when exporting without builds then the slide is one page with '
        'every shape (the print frame)', () async {
      final (r, pdf) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(),
      );

      expect(r.pageCount, 1);
      expect(count(pdf, rg(0x12, 0x34, 0x56)), 1);
    });

    test('when printing each build stage then there is one page per step '
        '(the empty first step shows the slide before any click)', () async {
      final (r, pdf) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(r.pageCount, 4);
      expect(PdfFixture.pageObjects(pdf), 4);
      // The first shape arrives on page 2 and stays.
      expect(count(pdf, rg(0x12, 0x34, 0x56)), 3);
      expect(count(pdf, rg(0, 0xff, 0)), 2);
      expect(count(pdf, rg(0, 0, 0xff)), 1);
    });

    test('when a click only pulses a shape then it is not a page of its own '
        '(identical settled frames are printed once)', () async {
      b.build_(slide, a, kind: SlideBuildKind.emphasis, effect: 'pulse');

      final (r, _) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(r.pageCount, 4);
    });

    test('when printing builds of several slides then each slide has one '
        'bookmark pointing at its first page and fonts are embedded', () async {
      final titled = b.slide(title: 'Second slide');
      b.textBox(titled, 'Body text', y: 400);

      final (r, pdf) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(r.pageCount, 5);
      final titles = PdfFixture.titles(pdf);
      expect(titles.where((t) => t == 'Second slide'), hasLength(1));
      expect(titles.where((t) => t == 'Slide 1'), hasLength(1));
      expect(pdf, contains('/FontFile2'));
    });

    test('when printing builds as notes pages then each slide is one page '
        'showing its final step', () async {
      final (r, pdf) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(
          layout: SlidesPdfLayout.notes,
          includeBuilds: true,
        ),
      );

      expect(r.pageCount, 1);
      expect(count(pdf, rg(0x12, 0x34, 0x56)), 1);
    });
  });

  group('Given a shape that builds out on a click', () {
    late DeckModel deck;
    setUp(() {
      final b = DeckBuilder();
      final slide = b.slide(layoutKey: 'blank');
      final s = b.shape(slide, fillJson: fill('#654321'));
      b.build_(slide, s, kind: SlideBuildKind.buildOut);
      deck = b.build();
    });

    test('when exporting then the print frame keeps it (Q24)', () async {
      final (_, pdf) = await PdfFixture.render(deck, const SlidesPdfOptions());

      expect(count(pdf, rg(0x65, 0x43, 0x21)), 1);
    });

    test('when showing the final animation state then it is gone', () async {
      final (_, pdf) = await PdfFixture.render(
        deck,
        const SlidesPdfOptions(finalAnimationState: true),
      );

      expect(count(pdf, rg(0x65, 0x43, 0x21)), 0);
    });

    test(
      'when printing handouts with builds then the final step is shown',
      () async {
        final (_, pdf) = await PdfFixture.render(
          deck,
          const SlidesPdfOptions(
            layout: SlidesPdfLayout.handouts,
            includeBuilds: true,
          ),
        );

        expect(count(pdf, rg(0x65, 0x43, 0x21)), 0);
      },
    );
  });

  group('Given text that builds by paragraph on clicks', () {
    late DeckBuilder b;
    late String slide, text;
    setUp(() {
      b = DeckBuilder();
      slide = b.slide(layoutKey: 'blank');
      text = b.textBox(slide, 'Alpha\nBeta\nGamma', height: 400);
    });

    int textObjects(String pdf) => RegExp(r'\bBT\b').allMatches(pdf).length;

    test('when printing each build stage then every page shows the '
        'paragraphs built so far', () async {
      b.build_(
        slide,
        text,
        optionsJson: opts({
          'delivery': {'by': 'paragraph', 'partTrigger': 'onClick'},
        }),
      );

      final (r, pdf) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(r.pageCount, 4);
      // 0 + 1 + 2 + 3 paragraphs drawn.
      expect(textObjects(pdf), 6);
    });

    test('when built paragraphs dim to a color then later pages draw them '
        'in that color', () async {
      b.build_(
        slide,
        text,
        optionsJson: opts({
          'delivery': {'by': 'paragraph', 'partTrigger': 'onClick'},
          'afterBuild': {'mode': 'dim', 'dimOpacity': 1, 'dimColor': '#888888'},
        }),
      );
      final dim = rg(0x88, 0x88, 0x88);

      final (_, plain) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(),
      );
      final (_, built) = await PdfFixture.render(
        b.build(),
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(count(plain, dim), 0);
      expect(count(built, dim), greaterThan(0));
    });
  });

  group('Given a code block with two highlight steps and a callout', () {
    late DeckModel deck;
    setUp(() {
      final b = DeckBuilder();
      final slide = b.slide(layoutKey: 'blank');
      final (code, _) = b.codeBlock(
        slide,
        states: ['void main() {\n  print("hi");\n}'],
        highlights: ['1|2'],
        annotations: [
          jsonEncode({
            'v': 1,
            'steps': {
              '1': {'text': 'The **entry** point'},
            },
          }),
        ],
      );
      for (final step in [1, 2]) {
        b.build_(
          slide,
          code,
          kind: SlideBuildKind.emphasis,
          effect: 'codeHighlight',
          optionsJson: opts({
            'params': {'step': step},
          }),
        );
      }
      deck = b.build();
    });

    Set<String> baseFonts(String pdf) => {
      for (final m in RegExp(r'/BaseFont\s*/([A-Za-z0-9+_-]+)').allMatches(pdf))
        m.group(1)!.replaceFirst(RegExp(r'^[A-Z]{6}\+'), ''),
    };

    test('when printing each build stage then each step is a page and the '
        'callout text embeds the body font', () async {
      final (plain, plainPdf) = await PdfFixture.render(
        deck,
        const SlidesPdfOptions(),
      );
      final (r, pdf) = await PdfFixture.render(
        deck,
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(plain.pageCount, 1);
      expect(r.pageCount, 3);
      expect(baseFonts(pdf).length, greaterThan(baseFonts(plainPdf).length));
    });

    test('when composing the frame of the first step then the code node '
        'shows step 1 with its callout', () {
      final slideId = deck.indexes.order.entries.first.id;
      final resolved = SlideResolver(deck).resolve(slideId)!;
      final scene = SlideSceneBuilder().build(
        resolved,
        SceneContext(
          theme: resolved.theme,
          textLayout: SlideTextLayout(),
          deck: deck,
          purpose: ScenePurpose.present,
        ),
      );
      final tl = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(deck, slideId, resolved: resolved),
      );

      final framed = SlideFrameScenes.apply(
        scene,
        tl.endOfStep(1),
        slide: resolved,
        deck: deck,
      );
      CodeScene codeOf(SlideScene s) {
        CodeScene? walk(List<SceneNode> nodes) {
          for (final n in nodes) {
            if (n is CodeNode) return n.scene;
            if (n is GroupNode) {
              final c = walk(n.children);
              if (c != null) return c;
            }
          }
          return null;
        }

        return walk(s.nodes)!;
      }

      expect(codeOf(scene).callouts, isEmpty);
      expect(codeOf(framed).step, 0);
      expect(codeOf(framed).callouts.single.text, 'The **entry** point');
    });
  });

  group('Given a linked chart that builds by series', () {
    late ChartFixture f;
    setUp(() {
      f = ChartFixture();
      f.scene.b.build_(
        f.scene.slideId,
        f.chart,
        optionsJson: opts({
          'delivery': {'by': 'series', 'partTrigger': 'onClick'},
        }),
      );
    });

    test('when composing the frame of the first series then the chart '
        'shows fewer marks than the full chart', () {
      final deck = f.scene.b.build();
      final resolved = SlideResolver(deck).resolve(f.scene.slideId)!;
      final charts = SlideChartLayout();
      final scene = SlideSceneBuilder().build(
        resolved,
        SceneContext(
          theme: resolved.theme,
          textLayout: SlideTextLayout(),
          deck: deck,
          purpose: ScenePurpose.present,
          charts: charts,
        ),
      );
      final tl = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(
          deck,
          f.scene.slideId,
          resolved: resolved,
          chartShapeOf: SlideChartMotion.shapes(deck),
        ),
      );
      int marks(SlideScene s) {
        int walk(List<SceneNode> nodes) {
          var n = 0;
          for (final x in nodes) {
            if (x is ChartNode) n += x.scene.primitives.length;
            if (x is GroupNode) n += walk(x.children);
          }
          return n;
        }

        return walk(s.nodes);
      }

      final first = SlideFrameScenes.apply(
        scene,
        tl.endOfStep(1),
        slide: resolved,
        deck: deck,
        charts: charts,
      );
      final last = SlideFrameScenes.apply(
        scene,
        tl.endOfStep(tl.stepCount),
        slide: resolved,
        deck: deck,
        charts: charts,
      );

      ChartScene chartOf(SlideScene s) {
        ChartScene? walk(List<SceneNode> nodes) {
          for (final x in nodes) {
            if (x is ChartNode) return x.scene;
            if (x is GroupNode) {
              final c = walk(x.children);
              if (c != null) return c;
            }
          }
          return null;
        }

        return walk(s.nodes)!;
      }

      expect(tl.stepCount, 2);
      expect(tl.endOfStep(1).elements[f.chart]?.chart, isNotNull);
      expect(identical(chartOf(first), chartOf(scene)), isFalse);
      expect(marks(last), marks(scene));
    });

    test('when printing each build stage then the chart is drawn on every '
        'page (no placeholder) with the series built so far', () async {
      final (r, pdf) = await PdfFixture.render(
        f.scene.b.build(),
        const SlidesPdfOptions(includeBuilds: true),
      );

      expect(r.pageCount, 3);
      final pages = contents(pdf);
      expect(pages, hasLength(3));
      // Each click adds a series: more marks on every page.
      final fills = [for (final p in pages) count(p, ' f')];
      expect(fills[1], greaterThan(fills[0]));
      expect(fills[2], greaterThan(fills[1]));
    });
  });
}
