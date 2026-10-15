import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides/features/canvas/slide_canvas_controller.dart';
import 'package:wonky_slides/features/elements/line/line_tool.dart';
import 'package:wonky_slides/features/elements/shape/shape_tool.dart';
import 'package:wonky_slides/features/elements/style/element_style.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_sync_models/ids.dart' show Base62Uuid;

import '../features/canvas/canvas_rig.dart' show CanvasFixture, solid;
import '../harness/deck_harness.dart';

void main() {
  late CanvasFixture f;
  late DeckHarness d;
  late String icon;

  setUp(() {
    f = CanvasFixture();
    icon = f.b.element(
      f.slide,
      ElementKind.icon,
      x: 1500,
      y: 900,
      width: 160,
      height: 160,
      columns: {
        ElementCols.dataJson: jsonEncode({
          'v': 1,
          'set': 'lucide',
          'name': 'rocket',
          'strokeWidth': 2,
        }),
      },
    );
    d = DeckHarness.open(fixture: f.b);
    d.editor.setCurrentSlide(f.slide);
  });
  tearDown(() => d.dispose());

  void select(List<String> ids) => selectionOf(d.editor).select(ids);

  Map<String, Object?> data(String id) =>
      jsonDecode(d.model.element(id)!.str(ElementCols.dataJson)!)
          as Map<String, Object?>;

  Map<String, Object?>? json(String id, String col) {
    final v = d.model.element(id)!.str(col);
    return v == null ? null : jsonDecode(v) as Map<String, Object?>;
  }

  Future<CommandResult> agent(String id, Map<String, Object?> args) =>
      d.h.invoke(id, args, InvocationSource.mcp);

  /// Runs [id] and checks execute → undo → redo returns to the same rows
  /// as one undo step.
  Future<CommandResult> roundTrip(
    String id, [
    Map<String, Object?> args = const {},
    InvocationSource source = InvocationSource.ui,
  ]) async {
    final before = d.model.dump();
    final steps = d.undoLabels.length;
    final r = await d.h.invoke(id, args, source);
    expect(r.status, CommandStatus.ok, reason: '$id: ${r.message}');
    final after = d.model.dump();
    expect(after, isNot(equals(before)), reason: '$id changed nothing');
    expect(d.undoLabels.length, steps + 1, reason: '$id: one undo step');
    await d.undo();
    expect(d.model.dump(), before, reason: '$id undo');
    await d.redo();
    expect(d.model.dump(), after, reason: '$id redo');
    return r;
  }

  String newest(CommandResult r) => (r.data! as Map)['elementId'] as String;

  group('Given insert commands', () {
    test('when the UI inserts a shape without a frame then the tool is armed '
        'and nothing is written', () async {
      final before = d.model.dump();
      final r = await d.run('slides.insert.shape', {'geometry': 'ellipse'});

      expect(r.status, CommandStatus.ok);
      expect(d.editor.armedTool, ShapeInsert.toolName('ellipse'));
      expect(d.model.dump(), before);
      expect(d.undoLabels, isEmpty);

      // S repeats the last shape.
      d.editor.armTool(null);
      await d.run('slides.insert.shape');
      expect(d.editor.armedTool, 'shape:ellipse');
    });

    test('when a shape is inserted with a frame then it is selected, the '
        'tool disarms and it round-trips', () async {
      d.editor.armTool('shape:star5');
      final r = await roundTrip('slides.insert.shape', {
        'geometry': 'star5',
        'x': 100,
        'y': 120,
        'width': 300,
        'height': 200,
      });
      final id = newest(r);
      final e = d.model.element(id)!;
      expect(e.kind, ElementKind.shape);
      expect((e.x, e.y, e.width, e.height), (100.0, 120.0, 300.0, 200.0));
      expect(data(id)['geometry'], 'star5');
      // Theme defaults stay unbaked (05 §2.7).
      expect(e.str(ElementCols.fillJson), isNull);
      expect(d.editor.selectedElementIds, [id]);
      expect(d.editor.armedTool, isNull);
    });

    test('when an agent inserts an arrow shape then it is centered at its '
        'natural size', () async {
      final r = await agent('slides.insert.shape', {'geometry': 'arrowRight'});
      final e = d.model.element(newest(r))!;
      expect((e.width, e.height), (320.0, 160.0));
      expect((e.x, e.y), ((1920 - 320) / 2, (1080 - 160) / 2));
    });

    test(
      'when an unknown geometry is inserted then the command fails',
      () async {
        await expectLater(
          agent('slides.insert.shape', {'geometry': 'blob'}),
          throwsA(isA<InvalidCommandArgs>()),
        );
      },
    );

    test('when a connector is drawn between two shapes then both ends are '
        'glued and it round-trips', () async {
      final r = await roundTrip('slides.insert.line', {
        'routing': 'elbow',
        'arrows': 'end',
        'start': {'x': 500, 'y': 200, 'elementId': f.a, 'site': 'right'},
        'end': {'x': 700, 'y': 200, 'elementId': f.bShape, 'site': 'left'},
      });
      final id = newest(r);
      final e = d.model.element(id)!;
      expect(e.kind, ElementKind.line);
      // The planner keeps sides ≥ 1 su (02 §13).
      expect((e.x, e.y, e.width, e.height), (500.0, 200.0, 200.0, 1.0));
      final dj = data(id);
      expect(dj['routing'], 'elbow');
      expect((dj['start'] as Map)['connect'], {
        'elementId': Base62Uuid.encode(f.a),
        'site': 'right',
      });
      expect((dj['end'] as Map)['x'], 1);
      expect(json(id, ElementCols.strokeJson), {
        'v': 1,
        'endArrow': 'triangle',
      });
    });

    test('when the UI inserts a line without ends then the line tool is '
        'armed', () async {
      await d.run('slides.insert.line', {
        'routing': 'curved',
        'arrows': 'both',
      });
      expect(d.editor.armedTool, LineInsert.toolName('curved', 'both'));
      expect(LineInsert.parse(d.editor.armedTool), ('curved', 'both'));
    });

    test('when an icon is inserted by name then it is a 160 su Lucide icon '
        'with the chosen color', () async {
      final r = await roundTrip('slides.insert.icon', {
        'name': 'alert-circle',
        'strokeWidth': 1.4,
        'color': 'theme:accent2',
      });
      final id = newest(r);
      final e = d.model.element(id)!;
      expect((e.width, e.height), (160.0, 160.0));
      expect(data(id), {
        'v': 1,
        'set': 'lucide',
        'name': 'circle-alert',
        'strokeWidth': 1.5,
      });
      expect(json(id, ElementCols.strokeJson)!['color'], 'theme:accent2');
    });

    test(
      'when an agent inserts an icon without a name then it fails',
      () async {
        final r = await agent('slides.insert.icon', const {});
        expect(r.status, CommandStatus.failed);
        final unknown = await agent('slides.insert.icon', {'name': 'nope-x'});
        expect(unknown.status, CommandStatus.failed);
      },
    );

    test('when an emoji is inserted then it is a 240 su emoji icon', () async {
      final r = await roundTrip('slides.insert.emoji', {'char': '🚀'});
      final id = newest(r);
      expect(d.model.element(id)!.width, 240);
      expect(data(id), {'v': 1, 'set': 'emoji', 'char': '🚀'});
    });
  });

  group('Given shape commands', () {
    test('when changing the shape then geometry changes and adjusts go, the '
        'frame and fill stay', () async {
      await d.run('slides.element.adjust', {
        'id': f.a,
        'key': 'radius',
        'value': 0.3,
      });
      select([f.a, f.bShape, f.line]);
      final fill = d.model.element(f.a)!.str(ElementCols.fillJson);

      await roundTrip('slides.shape.change', {'geometry': 'hexagon'});

      expect(data(f.a)['geometry'], 'hexagon');
      expect(data(f.a).containsKey('adjust'), isFalse);
      expect(data(f.bShape)['geometry'], 'hexagon');
      expect(d.model.element(f.a)!.str(ElementCols.fillJson), fill);
      expect(d.model.element(f.a)!.x, 100);
      expect(d.model.element(f.line)!.kind, ElementKind.line);
    });

    test('when no shape is selected then Change shape is disabled', () {
      select([f.line]);
      final st = d.services.dispatcher.stateOf('slides.shape.change', {
        'geometry': 'rect',
      });
      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Select a shape');
    });

    test('when applying a quick style then fill, border and text color '
        'change in one step', () async {
      select([f.a]);
      await roundTrip('slides.shape.applyQuickStyle', {'index': 6});
      final q = ElementStyle.quickStyles(ElementStyle.themeOf(d.editor))[6];
      expect(json(f.a, ElementCols.fillJson), {'v': 1, ...q.fill!.toJson()});
      expect(json(f.a, ElementCols.strokeJson), {
        'v': 1,
        ...q.stroke!.toJson(),
      });
      expect(
        (json(f.a, ElementCols.textStyleJson)!['defaults'] as Map)['color'],
        q.textColor?.json,
      );
    });
  });

  group('Given line commands', () {
    test(
      'when setting arrowheads then only the stroke arrow keys change',
      () async {
        select([f.line]);
        await roundTrip('slides.line.setArrow', {
          'end': 'both',
          'style': 'stealth',
        });
        expect(json(f.line, ElementCols.strokeJson), {
          'v': 1,
          'color': '#111111',
          'width': 6,
          'startArrow': 'stealth',
          'endArrow': 'stealth',
        });
        await roundTrip('slides.line.setArrow', {
          'end': 'start',
          'style': 'none',
        });
        expect(
          json(f.line, ElementCols.strokeJson)!.containsKey('startArrow'),
          isFalse,
        );
        await roundTrip('slides.line.setArrow', {'size': 'l'});
        expect(json(f.line, ElementCols.strokeJson)!['arrowSize'], 'l');
      },
    );

    test('when changing the routing then waypoints reset', () async {
      select([f.line]);
      expect(
        d.services.dispatcher.stateOf('slides.line.setRouting', {
          'routing': 'straight',
        }).checked,
        isTrue,
      );
      await roundTrip('slides.line.setRouting', {'routing': 'elbow'});
      expect(data(f.line)['routing'], 'elbow');
      expect(data(f.line)['waypoints'], isEmpty);
    });
  });

  group('Given icon commands', () {
    test('when replacing an icon by name then the glyph changes and the '
        'stroke width stays', () async {
      select([icon]);
      await roundTrip('slides.icon.replace', {'name': 'cloud-rain'});
      expect(data(icon)['name'], 'cloud-rain');
      expect(data(icon)['strokeWidth'], 2);
    });

    test('when setting the stroke width then it snaps to the offered '
        'widths', () async {
      select([icon]);
      await roundTrip('slides.icon.setStrokeWidth', {'value': 2.6});
      expect(data(icon)['strokeWidth'], 2.5);
      expect(
        d.services.dispatcher.stateOf('slides.icon.setStrokeWidth', {
          'value': 2.5,
        }).checked,
        isTrue,
      );
    });

    test('when an icon is selected then Enter activates replace', () {
      select([icon]);
      expect(
        d.services.dispatcher.stateOf('slides.element.activate').enabled,
        isTrue,
      );
    });
  });

  group('Given element groups', () {
    ({double x, double y, double w, double h}) frame(String id) {
      final e = d.model.element(id)!;
      return (x: e.x!, y: e.y!, w: e.width!, h: e.height!);
    }

    test(
      'when grouping and ungrouping then the frames come back exactly',
      () async {
        select([f.a, f.bShape, f.c]);
        final before = {
          for (final id in [f.a, f.bShape, f.c]) id: frame(id),
        };
        final r = await roundTrip('slides.arrange.group');
        final gid = (r.data! as Map)['groupId'] as String;
        expect(d.editor.selectedElementIds, [gid]);
        final g = d.model.element(gid)!;
        expect(g.kind, ElementKind.group);
        expect((g.x, g.y, g.width, g.height), (100.0, 100.0, 1500.0, 700.0));
        expect(d.model.element(f.a)!.parentId, gid);

        await roundTrip('slides.arrange.ungroup');
        expect(d.model.element(gid), isNull);
        expect(d.editor.selectedElementIds.toSet(), {f.a, f.bShape, f.c});
        for (final MapEntry(:key, :value) in before.entries) {
          expect(frame(key), value);
        }
      },
    );

    test('when a resized group is ungrouped then the scale is baked into '
        'the children', () async {
      select([f.g]);
      await d.run('slides.element.resize', {
        'frames': [
          {'id': f.g, 'x': 100, 'y': 600, 'width': 1200, 'height': 300},
        ],
      });
      // Children aren't written by the group resize.
      expect(frame(f.g1), (x: 100.0, y: 600.0, w: 200.0, h: 100.0));

      await roundTrip('slides.arrange.ungroup');

      expect(frame(f.g1), (x: 100.0, y: 600.0, w: 400.0, h: 100.0));
      expect(frame(f.g2), (x: 900.0, y: 800.0, w: 400.0, h: 100.0));
      expect(d.model.element(f.g1)!.parentId, isNull);
    });

    test('when objects are at different levels then Group is disabled with '
        'a reason', () {
      select([f.g1, f.a]);
      final st = d.services.dispatcher.stateOf('slides.arrange.group');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, 'Select objects in the same group');
      select([f.a]);
      expect(
        d.services.dispatcher.stateOf('slides.arrange.group').disabledReason,
        isNotNull,
      );
    });

    test('when a placeholder is selected then Group is disabled', () async {
      final h = DeckHarness.open();
      addTearDown(h.dispose);
      final slide = h.editor.currentSlideId!;
      final ph = h.model.indexes.tree(slide).roots.first.id;
      final shape =
          (await h.h.invoke('slides.insert.shape', {
                'geometry': 'rect',
              }, InvocationSource.mcp)).data!
              as Map;
      selectionOf(h.editor).select([ph, shape['elementId'] as String]);
      final st = h.services.dispatcher.stateOf('slides.arrange.group');
      expect(st.enabled, isFalse);
      expect(st.disabledReason, "Placeholders can't be grouped");
    });

    test('when Mod+G is pressed on the canvas then Group is bound in the '
        'canvas scope', () {
      final c = d.services.registry.byId('slides.arrange.group')!;
      expect(c.keyScope.name, 'slidesCanvas');
      expect(
        c.defaultBindings.map((b) => (b.key, b.mod, b.alt)),
        containsAll([('G', true, false), ('G', true, true)]),
      );
    });
  });

  group('Given alt text and names', () {
    test('when setting alt text and decorative then both are written in one '
        'step', () async {
      select([f.a]);
      await roundTrip('slides.element.editAltText', {
        'altText': 'A red box',
        'decorative': false,
      });
      expect(d.model.element(f.a)!.altText, 'A red box');
      await roundTrip('slides.element.editAltText', {'decorative': true});
      expect(d.model.element(f.a)!.decorative, isTrue);
    });

    test('when renaming then the name is stored and an empty name clears '
        'it', () async {
      select([f.a]);
      await roundTrip('slides.element.rename', {'name': 'Hero'});
      expect(d.model.element(f.a)!.name, 'Hero');
      await roundTrip('slides.element.rename', {'name': ' '});
      expect(d.model.element(f.a)!.name, isNull);
    });
  });

  test('when solid() fills are used then the fixture is styled', () {
    expect(jsonDecode(solid('#123456'))['color'], '#123456');
  });
}
