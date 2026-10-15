import 'dart:convert';

import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/testing.dart';
import 'package:wonky_slides_core/themes.dart';

import '../support/scene_fixture.dart';

(double, double) _map(GroupNode g, double x, double y) {
  final v = g.transform.transform3(Vector3(x, y, 0));
  return ((v.x * 1e6).roundToDouble() / 1e6, (v.y * 1e6).roundToDouble() / 1e6);
}

Iterable<T> _all<T>(SceneNode n) => SceneFixture.descendants(n).whereType<T>();

class _Icons implements SlideIconSource {
  @override
  IconGlyph? lucide(String name, double strokeWidth) =>
      name == 'rocket' ? const IconGlyph('Lucide400', '') : null;

  @override
  String? get emojiFamily => 'Noto Color Emoji';
}

class _Charts implements ChartSceneSource {
  @override
  ChartScene? chartScene(
    ResolvedElement element,
    DeckReader? deck,
    ResolvedTheme theme, {
    required double width,
    required double height,
  }) => ChartScene(width: width, height: height, background: 0, primitives: []);
}

void main() {
  group('Given a slide with elements', () {
    test('when building the scene then it has the slide size, background and '
        'one node per visible element in z-order', () {
      final f = SceneFixture();
      final a = f.shape(x: 10);
      final b = f.shape(x: 20);

      final scene = f.scene();

      expect(scene.width, 1920);
      expect(scene.height, 1080);
      expect(scene.slideId, f.slideId);
      final ids = [for (final n in scene.nodes) n.elementId];
      expect(ids.indexOf(a), lessThan(ids.indexOf(b)));
    });

    test('when an element is hidden then it is not drawn', () {
      final f = SceneFixture();
      final a = f.shape(columns: {SlidesCols.hidden: true});

      expect(f.scene().nodesOf(a), isEmpty);
    });

    test('when building twice from the same resolved slide then node '
        'identities are kept', () {
      final f = SceneFixture();
      final a = f.shape(text: 'Hi');
      final m = f.model();
      final slide = f.resolve(model: m);
      final ctx = SceneContext(
        theme: slide.theme,
        textLayout: f.engine,
        deck: m,
      );

      final s1 = f.builder.build(slide, ctx);
      final s2 = f.builder.build(slide, ctx);

      expect(identical(s1.nodesOf(a).first, s2.nodesOf(a).first), isTrue);
    });
  });

  group('Given a shape', () {
    test('when building then its group maps local coordinates onto the frame '
        'and the default fill is the theme accent', () {
      final f = SceneFixture();
      final a = f.shape(x: 100, y: 50, w: 400, h: 200);

      final scene = f.scene();
      final g = SceneFixture.groupOf(scene, a);
      final path = _all<PathNode>(g).single;

      expect(_map(g, 0, 0), (100, 50));
      expect(_map(g, 400, 200), (500, 250));
      final accent = f.resolve().theme.colorOf('accent1');
      expect(
        path.fill,
        isA<ResolvedSolidFill>().having((x) => x.color, 'color', accent),
      );
      expect(path.stroke, isNull);
    });

    test('when rotated 90° then the local top-left maps around the center', () {
      final f = SceneFixture();
      final a = f.element(
        ElementKind.shape,
        x: 0,
        y: 0,
        w: 200,
        h: 100,
        rotation: 90,
      );

      final g = SceneFixture.groupOf(f.scene(), a);

      expect(_map(g, 0, 0), (150, -50));
    });

    test('when it has fill, stroke and shadow JSON then they resolve '
        'against the theme', () {
      final f = SceneFixture();
      final a = f.shape(
        columns: {
          ElementCols.fillJson: jsonEncode({
            'v': 1,
            'type': 'solid',
            'color': '#FF0000',
          }),
          ElementCols.strokeJson: jsonEncode({
            'v': 1,
            'color': 'theme:text1',
            'width': 6,
            'dash': 'dash',
          }),
          ElementCols.effectsJson: jsonEncode({
            'v': 1,
            'shadow': {'color': '#00000040', 'blur': 24, 'dx': 0, 'dy': 12},
          }),
        },
      );

      final g = SceneFixture.groupOf(f.scene(), a);
      final path = _all<PathNode>(g).single;

      expect((path.fill! as ResolvedSolidFill).color, 0xffff0000);
      expect(path.stroke!.width, 6);
      expect(path.stroke!.dash, [24, 18]);
      expect(g.effects.shadows.single.dy, 12);
    });

    test('when it holds text then the text is centered vertically', () {
      final f = SceneFixture();
      final a = f.shape(x: 0, y: 0, w: 600, h: 400, text: 'Middle');

      final text = _all<TextNode>(SceneFixture.groupOf(f.scene(), a)).single;
      final h = text.layout.height;

      expect(text.originY, closeTo((400 - h) / 2, 1));
      expect(text.layout.lines.single.runs.single.text, 'Middle');
    });

    test('when its text overflows then it shrinks (shapes default to '
        'shrink)', () {
      final f = SceneFixture();
      final a = f.shape(
        w: 200,
        h: 80,
        text: 'A lot of text that cannot possibly fit into this small box',
      );

      final text = _all<TextNode>(SceneFixture.groupOf(f.scene(), a)).single;

      expect(text.layout.fitScale, lessThan(1));
    });

    test('when flipped then the text stays readable (un-flipped group)', () {
      final f = SceneFixture();
      final a = f.shape(text: 'Flip', columns: {ElementCols.flipH: true});

      final g = SceneFixture.groupOf(f.scene(), a);
      final inner = g.children.whereType<GroupNode>().single;

      expect(inner.transform.storage[0], -1);
      expect(inner.children.single, isA<TextNode>());
    });

    test('when it is a cube then the shaded faces have lighter and darker '
        'fills', () {
      final f = SceneFixture();
      final a = f.shape(geometry: 'cube');

      final fills = [
        for (final p in _all<PathNode>(SceneFixture.groupOf(f.scene(), a)))
          (p.fill! as ResolvedSolidFill).color,
      ];

      expect(fills.toSet(), hasLength(3));
    });
  });

  group('Given a text box', () {
    test('when its text needs more height then the derived frame grows '
        '(resize is the text box default)', () {
      final f = SceneFixture();
      final t = f.element(
        ElementKind.text,
        x: 0,
        y: 0,
        w: 300,
        h: 40,
        columns: {
          SlidesCols.text: deltaOf('line one line two line three line four'),
        },
      );

      final scene = f.scene();

      expect(scene.frames[t]!.height, greaterThan(40));
      expect(scene.frames[t]!.width, 300);
    });

    test('when it does not wrap then the derived width follows the text', () {
      final f = SceneFixture();
      final t = f.element(
        ElementKind.text,
        x: 0,
        y: 0,
        w: 2000,
        h: 80,
        columns: {
          SlidesCols.text: deltaOf('Auto'),
          ElementCols.textStyleJson: jsonEncode({'v': 1, 'wrap': false}),
        },
      );

      final scene = f.scene();

      expect(scene.frames[t]!.width, lessThan(400));
      expect(
        _all<TextNode>(SceneFixture.groupOf(scene, t)).single.layout.lines,
        hasLength(1),
      );
    });

    test('when it is empty then nothing is drawn', () {
      final f = SceneFixture();
      final t = f.element(ElementKind.text);

      expect(SceneFixture.groupOf(f.scene(), t).children, isEmpty);
    });
  });

  group('Given an empty title placeholder', () {
    late SceneFixture f;
    setUp(() => f = SceneFixture(layoutKey: 'titleBody'));

    String titleId(SlideScene s) => f
        .resolve()
        .elements
        .firstWhere((e) => e.placeholderType?.name == 'title')
        .id;

    test('when editing then its prompt is drawn', () {
      final scene = f.scene(editing: true);

      final prompt = scene.nodesOf(titleId(scene)).whereType<PromptNode>();
      expect(prompt.single.text, isNotEmpty);
      expect(prompt.single.layout, isNotNull);
    });

    for (final purpose in [
      ScenePurpose.thumbnail,
      ScenePurpose.present,
      ScenePurpose.print,
    ]) {
      test('when building for ${purpose.name} then no prompt is drawn', () {
        final scene = f.scene(purpose: purpose);

        expect(
          SceneFixture.descendants(
            SceneFixture.groupOf(scene, titleId(scene)),
          ).whereType<PromptNode>(),
          isEmpty,
        );
      });
    }
  });

  group('Given slide numbers are shown', () {
    test('when building then the number field is drawn as text', () {
      final f = SceneFixture(layoutKey: 'titleBody');
      final rows = [
        for (final (t, c) in f.b.rows)
          (
            t,
            t == SlidesTables.deck
                ? {...c, DeckCols.showSlideNumbers: true}
                : c,
          ),
      ];
      final m = DeckModel.fromRows(f.b.deckId, rows);

      final scene = f.scene(model: m);
      final texts = [
        for (final n in scene.nodes)
          for (final t in _all<TextNode>(n))
            t.layout.lines.expand((l) => l.runs).map((r) => r.text).join(),
      ];

      expect(texts, contains('1'));
    });
  });

  group('Given an element group', () {
    test('when building then the group node holds its children and their '
        'opacity includes the group opacity', () {
      final f = SceneFixture();
      final gid = f.b.ids.newId();
      final child = f.shape(
        x: 0,
        y: 0,
        parentId: gid,
        columns: {ElementCols.opacity: 0.5},
      );
      f.b.elementGroup(
        f.slideId,
        groupId: gid,
        x: 0,
        y: 0,
        width: 400,
        height: 200,
      );
      final rows = [
        for (final (t, c) in f.b.rows)
          (t, c[SlidesCols.id] == gid ? {...c, ElementCols.opacity: 0.5} : c),
      ];

      final scene = f.scene(model: DeckModel.fromRows(f.b.deckId, rows));
      final g = scene.nodes.whereType<GroupNode>().firstWhere(
        (n) => n.elementId == gid,
      );

      expect(g.children.single.elementId, child);
      expect((g.children.single as GroupNode).opacity, closeTo(0.25, 1e-9));
    });
  });

  group('Given a line with arrows', () {
    test('when building then the route is recorded and the end arrow is a '
        'filled head', () {
      final f = SceneFixture();
      final l = f.line(
        100,
        100,
        500,
        100,
        stroke: {
          'v': 1,
          'color': '#112233',
          'width': 4,
          'endArrow': 'triangle',
        },
      );

      final scene = f.scene();
      final paths = _all<PathNode>(SceneFixture.groupOf(scene, l)).toList();

      expect(scene.routes[l], [(x: 100.0, y: 100.0), (x: 500.0, y: 100.0)]);
      expect(paths, hasLength(2));
      expect(paths[0].stroke!.color, 0xff112233);
      expect((paths[1].fill! as ResolvedSolidFill).color, 0xff112233);
      // The shaft stops short of the tip.
      final shaft = PathOps.bounds(paths[0].path.commands)!;
      expect(shaft.right, lessThan(500));
    });

    test('when glued then the scene route follows the shape', () {
      final f = SceneFixture();
      final a = f.shape(x: 100, y: 100, w: 200, h: 100);
      final l = f.line(0, 0, 900, 900, startGlue: (a, 'bottom'));

      expect(f.scene().routes[l]!.first, (x: 200.0, y: 200.0));
    });
  });

  group('Given an image', () {
    Map<String, Object?> img(Map<String, Object?> extra) => {
      ElementCols.dataJson: jsonEncode({
        'v': 1,
        'src': 'wonky-file://abc',
        'naturalWidth': 1000,
        'naturalHeight': 500,
        ...extra,
      }),
    };

    test('when cropped then the source rectangle is in image pixels', () {
      final f = SceneFixture();
      final i = f.element(
        ElementKind.image,
        columns: img({
          'crop': {'l': 0.1, 't': 0, 'r': 0.2, 'b': 0.5},
        }),
      );

      final node = _all<ImageNode>(SceneFixture.groupOf(f.scene(), i)).single;

      expect(node.image.fileUuid, 'abc');
      expect(node.src.toList(), [100, 0, 700, 250]);
      expect(node.dst.toList(), [0, 0, 400, 200]);
    });

    test('when masked and adjusted then the mask path and color matrix are '
        'set', () {
      final f = SceneFixture();
      final i = f.element(
        ElementKind.image,
        columns: img({
          'mask': 'ellipse',
          'adjust': {'grayscale': true},
        }),
      );

      final node = _all<ImageNode>(SceneFixture.groupOf(f.scene(), i)).single;

      expect(node.mask, isNotNull);
      expect(
        ImageAdjust.apply(node.colorMatrix!, 0xffff0000) & 0xffffff,
        isNot(0xff0000),
      );
    });

    test('when it has a stroke then a border is drawn over the image', () {
      final f = SceneFixture();
      final i = f.element(
        ElementKind.image,
        columns: {
          ...img({}),
          ElementCols.strokeJson: jsonEncode({'v': 1, 'width': 3}),
        },
      );

      final kids = SceneFixture.groupOf(f.scene(), i).children;

      expect(
        kids.last,
        isA<PathNode>().having((p) => p.stroke?.width, 'stroke', 3),
      );
    });
  });

  group('Given a table', () {
    test('when building then cells draw text, the header row has the theme '
        'header fill and long text grows the row', () {
      final f = SceneFixture();
      final (t, rows, cols) = f.b.table(
        f.slideId,
        rows: 2,
        cols: 2,
        x: 0,
        y: 0,
        width: 400,
        height: 100,
      );
      f.b.cell(t, rows[0], cols[0], 'Head');
      f.b.cell(
        t,
        rows[1],
        cols[1],
        'A long cell text that wraps over many lines in a narrow column',
      );

      final scene = f.scene();
      final g = SceneFixture.groupOf(scene, t);
      final theme = f.resolve().theme;

      expect(_all<TextNode>(g), hasLength(2));
      final fills = [
        for (final p in _all<PathNode>(g))
          if (p.fill case ResolvedSolidFill(:final color)) color,
      ];
      expect(fills, contains(theme.colorOf('accent1')));
      expect(scene.frames[t]!.height, greaterThan(100));
    });
  });

  group('Given a table grid (SL-15)', () {
    test('when computing the grid then it matches the drawn layout, tags '
        'cell text with its part id and honors merges', () {
      final f = SceneFixture();
      final (t, rows, cols) = f.b.table(
        f.slideId,
        rows: 2,
        cols: 3,
        x: 0,
        y: 0,
        width: 300,
        height: 100,
      );
      f.b.cell(t, rows[1], cols[2], 'Body');
      final m = f.model();
      final slide = f.resolve(model: m);
      final ctx = SceneContext(
        theme: slide.theme,
        textLayout: f.engine,
        deck: m,
      );
      final e = slide.element(t)!;

      final grid = f.builder.tableGrid(e, ctx)!;
      final scene = f.builder.build(slide, ctx);

      expect(grid.columnX.first, 0);
      expect(grid.columnX.last, closeTo(300, 1e-6));
      expect(grid.cells, hasLength(6));
      expect(grid.height, closeTo(scene.frameOf(e).height, 1e-6));
      final text = _all<TextNode>(SceneFixture.groupOf(scene, t)).single;
      expect(text.partId, '${rows[1]}|${cols[2]}');
      final cell = grid.cellOf(rows[1], cols[2])!;
      final o = cell.textOrigin(cell.layout!.height);
      expect(text.originX, closeTo(o.x, 1e-6));
      expect(text.originY, closeTo(o.y, 1e-6));
      expect(grid.cellAtPoint(cell.x + 1, cell.y + 1), same(cell));
    });

    test('when a cell body is overridden then the grid lays it out instead '
        'of the stored text', () {
      final f = SceneFixture();
      final (t, rows, cols) = f.b.table(
        f.slideId,
        rows: 1,
        cols: 1,
        width: 200,
        height: 40,
      );
      final m = f.model();
      final slide = f.resolve(model: m);
      final ctx = SceneContext(
        theme: slide.theme,
        textLayout: f.engine,
        deck: m,
      );
      final key = '${rows[0]}|${cols[0]}';

      final grid = f.builder.tableGrid(
        slide.element(t)!,
        ctx,
        cellText: {key: '[{"insert":"one\\ntwo\\nthree\\nfour\\n"}]'},
      )!;

      expect(grid.cells.single.layout, isNotNull);
      expect(grid.height, greaterThan(40));
    });
  });

  group('Given an icon', () {
    test('when the icon source knows the glyph then it is drawn as text in '
        'the stroke color', () {
      final f = SceneFixture();
      final i = f.element(
        ElementKind.icon,
        w: 160,
        h: 160,
        columns: {
          ElementCols.dataJson: jsonEncode({
            'v': 1,
            'set': 'lucide',
            'name': 'rocket',
          }),
        },
      );

      final text = _all<TextNode>(
        SceneFixture.groupOf(f.scene(icons: _Icons()), i),
      ).single;
      final run = text.layout.lines.single.runs.single;

      expect(run.fontFamily, 'Lucide400');
      expect(run.fontSize, 160);
      expect(run.color, f.resolve().theme.colorOf('text1'));
    });

    test('when no source knows the glyph then a neutral frame is drawn', () {
      final f = SceneFixture();
      final i = f.element(
        ElementKind.icon,
        columns: {
          ElementCols.dataJson: jsonEncode({
            'v': 1,
            'set': 'lucide',
            'name': 'unknown',
          }),
        },
      );

      final g = SceneFixture.groupOf(f.scene(icons: _Icons()), i);

      expect(_all<PathNode>(g).single.stroke, isNotNull);
    });

    test('when it is an emoji then the emoji family is used', () {
      final f = SceneFixture();
      final i = f.element(
        ElementKind.icon,
        columns: {
          ElementCols.dataJson: jsonEncode({
            'v': 1,
            'set': 'emoji',
            'char': '🚀',
          }),
        },
      );

      final run = _all<TextNode>(
        SceneFixture.groupOf(f.scene(icons: _Icons()), i),
      ).single.layout.lines.single.runs.single;

      expect(run.text, '🚀');
      expect(run.fontFamily, 'Noto Color Emoji');
    });
  });

  group('Given a code element with two states', () {
    late SceneFixture f;
    late String code;
    late DeckModel model;
    setUp(() {
      f = SceneFixture();
      code = f.element(
        ElementKind.code,
        w: 800,
        h: 400,
        columns: {
          ElementCols.dataJson: jsonEncode({'v': 1, 'language': 'dart'}),
        },
      );
      SlidesRow state(String id, String key, String src) => (
        SlidesTables.codeState,
        {
          for (final c in SlidesTables.columns[SlidesTables.codeState]!)
            c: null,
          SlidesCols.id: id,
          SlidesCols.elementId: code,
          SlidesCols.sortKey: key,
          CodeStateCols.code: src,
          SlidesCols.createdAt: testNow,
        },
      );
      model = DeckModel.fromRows(f.b.deckId, [
        ...f.b.rows,
        state('00000000-0000-7000-8000-00000000c001', 'a0', 'void main() {}'),
        state(
          '00000000-0000-7000-8000-00000000c002',
          'a1',
          'void main() {\n  print(1);\n}',
        ),
      ]);
    });

    CodeNode codeNode(SlideScene s) =>
        _all<CodeNode>(SceneFixture.groupOf(s, code)).single;

    test('when editing then the first state is shown with colored tokens', () {
      final node = codeNode(f.scene(model: model));

      expect(node.scene.lines, hasLength(1));
      expect(
        node.scene.lines.single.runs.map((r) => r.color).toSet().length,
        greaterThan(1),
      );
      expect(node.scene.numbersRight, isNotNull);
    });

    test('when building a thumbnail then the last state is shown', () {
      final node = codeNode(
        f.scene(model: model, purpose: ScenePurpose.thumbnail),
      );

      expect(node.scene.lines, hasLength(3));
    });

    test('when building then the code box has the theme shadow', () {
      final g = SceneFixture.groupOf(f.scene(model: model), code);

      expect(g.effects.shadows, isNotEmpty);
    });
  });

  group('Given a chart element', () {
    test('when no chart source is available then a placeholder is drawn', () {
      final f = SceneFixture();
      final c = f.element(ElementKind.chart);

      final g = SceneFixture.groupOf(f.scene(), c);

      expect(_all<PathNode>(g).length, 4);
      expect(_all<ChartNode>(g), isEmpty);
    });

    test('when a chart source lays it out then the chart scene is drawn', () {
      final f = SceneFixture();
      final c = f.element(ElementKind.chart, w: 600, h: 300);

      final node = _all<ChartNode>(
        SceneFixture.groupOf(f.scene(charts: _Charts()), c),
      ).single;

      expect(node.dst.toList(), [0, 0, 600, 300]);
    });
  });

  group('Given the deck appearance', () {
    test('when building in dark then the background and accent fills are the '
        'dark scheme', () {
      final f = SceneFixture();
      final a = f.shape();

      final light = f.scene(appearance: SlideAppearance.light);
      final dark = f.scene(appearance: SlideAppearance.dark);
      int fill(SlideScene s) =>
          (_all<PathNode>(SceneFixture.groupOf(s, a)).single.fill!
                  as ResolvedSolidFill)
              .color;

      expect(
        dark.background.effectiveColor(0xffffffff),
        isNot(light.background.effectiveColor(0xffffffff)),
      );
      expect(
        fill(dark),
        f.resolve(appearance: SlideAppearance.dark).theme.colorOf('accent1'),
      );
    });
  });
}
