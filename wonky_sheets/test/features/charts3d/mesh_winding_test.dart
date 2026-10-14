import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/charts3d/gpu/mesh_winding.dart';
import 'package:wonky_sheets_core/model.dart';

/// `cross(b − a, c − a)` of triangle [i] in the GPU's z-mirrored world.
Vec3 _frontOf(Chart3DFace f, List<int> idx, int i) {
  Vec3 m(Vec3 p) => Vec3(p.x, p.y, -p.z);
  final a = m(f.points[idx[i]]);
  return (m(f.points[idx[i + 1]]) - a).cross(m(f.points[idx[i + 2]]) - a);
}

void main() {
  group('Given core faces wound counter-clockwise from outside', () {
    // A floor top (normal +y) and a front wall (normal +z), CCW seen from
    // the side their normals point to.
    final floor = Chart3DFace(const [
      Vec3(0, 0, 0),
      Vec3(0, 0, 1),
      Vec3(1, 0, 1),
      Vec3(1, 0, 0),
    ], const Vec3(0, 1, 0));
    final front = Chart3DFace(const [
      Vec3(0, 0, 1),
      Vec3(1, 0, 1),
      Vec3(1, 1, 1),
      Vec3(0, 1, 1),
    ], const Vec3(0, 0, 1));

    test('when meshed for the GPU then every triangle faces along the '
        'mirrored outward normal (lit from outside)', () {
      for (final f in [floor, front]) {
        final idx = gpuTriangleIndices(f);
        expect(idx, hasLength(6));
        final n = Vec3(f.normal.x, f.normal.y, -f.normal.z);
        for (var i = 0; i < idx.length; i += 3) {
          expect(_frontOf(f, idx, i).dot(n), greaterThan(0));
        }
      }
    });

    test('when a face is already wound for the GPU then it is kept', () {
      final f = Chart3DFace(const [
        Vec3(0, 0, 0),
        Vec3(1, 0, 0),
        Vec3(0, 0, 1),
      ], const Vec3(0, 1, 0));
      expect(gpuTriangleIndices(f), [0, 1, 2]);
    });
  });
}
