import 'dart:math' as math;

import '../scene/scene.dart';
import '../spec/three_d_options.dart';
import 'vec3.dart';

/// The lighting model of 3D charts (08 §23.5), shared by the software renderer and (as
/// parameters) the GPU backend: an ambient term, one key light fixed relative to the view
/// (upper left, in front), a Blinn-Phong highlight, a contact darkening near the floor and a
/// soft floor shadow.
final class Chart3DShading {
  const Chart3DShading._({
    required this.ambient,
    required this.diffuse,
    required this.specular,
    required this.shininess,
    required this.gradients,
    required this.contact,
    required this.shadowAlpha,
    required this.edgeDarken,
  });

  /// The model of a [Chart3DLighting] preset.
  factory Chart3DShading.of(Chart3DLighting lighting) => switch (lighting) {
    Chart3DLighting.soft => const Chart3DShading._(
      ambient: 0.6,
      diffuse: 0.46,
      specular: 0.12,
      shininess: 26,
      gradients: true,
      contact: 0.12,
      shadowAlpha: 0.14,
      edgeDarken: 0.22,
    ),
    Chart3DLighting.bright => const Chart3DShading._(
      ambient: 0.5,
      diffuse: 0.62,
      specular: 0.3,
      shininess: 44,
      gradients: true,
      contact: 0.14,
      shadowAlpha: 0.2,
      edgeDarken: 0.25,
    ),
    Chart3DLighting.flat => const Chart3DShading._(
      ambient: 0.74,
      diffuse: 0.3,
      specular: 0,
      shininess: 1,
      gradients: false,
      contact: 0,
      shadowAlpha: 0,
      edgeDarken: 0.32,
    ),
  };

  /// Light reaching every face (0..1).
  final double ambient;

  /// Strength of the key light.
  final double diffuse;

  /// Strength of the highlight.
  final double specular;
  final double shininess;

  /// Whether large faces get gradient fills (software renderer).
  final bool gradients;

  /// Darkening of vertical faces where they meet the floor (0..1).
  final double contact;

  /// Opacity of the floor shadow (0 = none).
  final double shadowAlpha;

  /// How much darker face outlines are than the face.
  final double edgeDarken;

  /// Direction to the key light in view space (x right, y up, z toward the viewer).
  static final Vec3 keyLightView = const Vec3(-0.45, 0.78, 0.55).normalized;

  /// [base] lit with unit normal [n], unit direction to the light [l] and to the eye [v],
  /// darkened by [contactFactor] (0 = none, 1 = full [contact]).
  int shade(int base, Vec3 n, Vec3 l, Vec3 v, {double contactFactor = 0}) {
    final ndl = math.max(0.0, n.dot(l));
    var k = ambient + diffuse * ndl;
    k *= 1 - contact * contactFactor.clamp(0.0, 1.0);
    var s = 0.0;
    if (specular > 0 && ndl > 0) {
      final h = (l + v).normalized;
      s = specular * math.pow(math.max(0.0, n.dot(h)), shininess) * 255;
    }
    int ch(int c) => (c * k + s).round().clamp(0, 255);
    return Argb.of(
      Argb.alpha(base),
      ch(Argb.red(base)),
      ch(Argb.green(base)),
      ch(Argb.blue(base)),
    );
  }

  /// [base] of the floor and walls: barely shaded, so they stay light and calm.
  int shadeFrame(int base, Vec3 n, Vec3 l) {
    final k = 0.9 + 0.12 * math.max(0.0, n.dot(l));
    int ch(int c) => (c * k).round().clamp(0, 255);
    return Argb.of(
      Argb.alpha(base),
      ch(Argb.red(base)),
      ch(Argb.green(base)),
      ch(Argb.blue(base)),
    );
  }

  /// Relative luminance proxy of an ARGB color (0..255).
  static double luma(int c) =>
      0.2126 * Argb.red(c) + 0.7152 * Argb.green(c) + 0.0722 * Argb.blue(c);
}
