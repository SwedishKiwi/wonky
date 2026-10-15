import 'package:test/test.dart';
import 'package:wonky_slides_core/motion.dart';

void main() {
  group('Given the transition catalog metadata (06 §5.1, §7.2)', () {
    test('when listing then every available catalog type has metadata and '
        'P2 types are left out', () {
      expect(TransitionInfo.all.map((i) => i.id), [
        for (final t in TransitionCatalog.types)
          if (t.available) t.id,
      ]);
      expect(TransitionInfo.of('pageCurl'), isNull);
    });

    test('when grouping then the 3D group is exactly the 3D types', () {
      expect(TransitionInfo.inGroup(TransitionGroup.threeD).map((i) => i.id), [
        for (final t in TransitionCatalog.types)
          if (t.is3d && t.available) t.id,
      ]);
      expect(TransitionInfo.inGroup(TransitionGroup.magic).map((i) => i.id), [
        'magicMove',
      ]);
    });

    test('when a type has a direction parameter then the metadata names '
        'it', () {
      for (final i in TransitionInfo.all) {
        final hasDirection = i.spec.params.any((p) => p.key == 'direction');
        expect(i.directionParam != null, hasDirection, reason: i.id);
      }
    });

    test('when serialized then the catalog entry and the metadata are '
        'combined', () {
      expect(TransitionInfo.of('cube')!.toJson(), {
        'id': 'cube',
        'name': 'Cube',
        'defaultDurationMs': 1000,
        'params': [
          {
            'key': 'direction',
            'type': 'choice',
            'default': 'left',
            'choices': ['left', 'right', 'up', 'down'],
          },
        ],
        '3d': true,
        'group': 'threeD',
        'description':
            'Both slides are faces of a cube that turns a quarter turn.',
        'icon': 'box',
        'directionParam': 'direction',
        'reducedMotion': 'fade',
      });
    });

    test('when previewing a tile then the plan samples frames without '
        'slides', () {
      final frames = TransitionCompiler.preview(
        TransitionSpec.of('push'),
      ).sample(5);

      expect(frames.map((f) => f.progress).first, 0);
      expect(frames.last.progress, 1);
      expect(frames, hasLength(5));
    });
  });
}
