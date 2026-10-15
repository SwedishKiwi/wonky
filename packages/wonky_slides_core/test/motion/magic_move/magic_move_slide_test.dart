import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/schema.dart';

import '../../support/magic_move_fixture.dart';

void main() {
  group('Given a slide read for Magic Move (06 §8.1)', () {
    test('when reading shapes and text then signatures, colors, outlines '
        'and layouts are filled in', () {
      final f = MagicMoveFixture();
      final shape = f.shape(
        f.a,
        key: 'k',
        fill: '#336699',
        text: 'Go   now',
        name: 'Button',
      );
      final text = f.text(f.a, 'Hello');
      final s = f.slideA();
      final e = s.elements.first;

      expect(s.elements.map((e) => e.id), [shape, text]);
      expect(e.matchKey, 'k');
      expect(e.name, 'Button');
      expect(e.signature, 'shape:rect|Go now');
      expect(e.fillColor, 0xFF336699);
      expect(e.outline, isNotNull);
      expect(e.geometryKey, 'rect|null');
      expect(s.elements.last.signature, 'text:Hello');
      expect(s.elements.last.text!.layout!.lines, isNotEmpty);
      expect(e.z, 0);
      expect(s.elements.last.z, 1);
    });

    test('when an element is hidden by builds or by its flag then it does '
        'not take part', () {
      final f = MagicMoveFixture();
      final built = f.shape(f.a);
      f.b.element(f.a, ElementKind.shape, columns: {SlidesCols.hidden: true});
      final s = f.slideA(
        frame: SlideFrame({built: ElementVisualState(visible: false)}),
      );

      expect(s.elements, isEmpty);
    });

    test('when an image is read then its signature is the file', () {
      final f = MagicMoveFixture();
      f.element(
        f.a,
        ElementKind.image,
        data: {
          'src': 'file-1',
          'crop': {'x': 0.1, 'y': 0, 'w': 0.5, 'h': 1},
        },
      );
      final e = f.slideA().elements.single;

      expect(e.signature, 'image:file-1');
      expect(e.image!.crop, {'x': 0.1, 'y': 0, 'w': 0.5, 'h': 1});
    });

    test('when both slides use the same layout and background then the '
        'decorations and background keys are equal', () {
      final f = MagicMoveFixture();

      expect(f.slideA().chromeKey, f.slideB().chromeKey);
      expect(f.slideA().backgroundKey, f.slideB().backgroundKey);
    });

    test('when the outgoing slide ended with a grow emphasis then Magic '
        'Move starts from the grown shape (06 §8.4)', () {
      final f = MagicMoveFixture();
      final el = f.shape(f.a, key: 'k');
      f.b.build_(
        f.a,
        el,
        kind: SlideBuildKind.emphasis,
        effect: 'grow',
        optionsJson: jsonEncode({
          'v': 1,
          'params': {'scale': 1.5},
        }),
      );
      f.shape(f.bSlide, key: 'k');
      final timeline = SlideTimelineCompiler.compile(
        SlideMotionInput.fromDeck(f.model, f.a),
      );
      final a = f.slideA(frame: timeline.finalFrame);

      expect(a.elements.single.geometry.width, closeTo(600, 1e-6));
      final plan = MagicMovePlan.compile(a, f.slideB());
      expect(
        plan.frameAt(0).pairs.values.single.geometry.width,
        closeTo(600, 1e-6),
      );
    });
  });
}
