import 'package:wonky_sheets_core/model.dart';

/// The triangle indices of [face] for Flutter Scene (08 §23.7), in the
/// z-mirrored world of the GPU backend.
///
/// Flutter Scene draws `cross(b − a, c − a)` as a triangle's front side and
/// lights back-facing fragments of double-sided materials with the reversed
/// normal. The core winds faces counter-clockwise seen from outside in its
/// right-handed world; mirroring z reverses that, so every face would be lit
/// from inside (dark floors and tops, washed-out colors). Each triangle is
/// ordered against the face's outward normal instead.
List<int> gpuTriangleIndices(Chart3DFace face) {
  final tris = face.triangleIndices;
  final n = Vec3(face.normal.x, face.normal.y, -face.normal.z);
  final out = <int>[];
  for (var i = 0; i + 2 < tris.length; i += 3) {
    final a = tris[i], b = tris[i + 1], c = tris[i + 2];
    final pa = _mirror(face.points[a]);
    final cross = (_mirror(face.points[b]) - pa).cross(
      _mirror(face.points[c]) - pa,
    );
    if (cross.dot(n) >= 0) {
      out.addAll([a, b, c]);
    } else {
      out.addAll([a, c, b]);
    }
  }
  return out;
}

Vec3 _mirror(Vec3 p) => Vec3(p.x, p.y, -p.z);
