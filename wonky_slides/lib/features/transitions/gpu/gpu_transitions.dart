import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;
import 'package:wonky_slides_core/motion.dart';

import '../transition_painter.dart';

/// The `flutter_scene` (Flutter GPU / WebGL2) renderer of the 3D slide
/// transitions — flip, cube, doorway, swap, revolve (Slides 06 §7.2,
/// §12.2–§12.3 as built by SL-29): the two slide snapshots become textured
/// quads in a real 3D scene with a depth buffer and multisampling, seen by
/// a camera at 2.2 × the slide width in front of the slide center — the
/// same projection as the core's frames, so the first and last frame line
/// up with the flat slides. Colors are display-referred (unlit, no tone
/// mapping) and faces turned away are shaded like the 2D path.
///
/// It starts lazily (the shader bundle loads when the first 3D transition
/// is prefetched) and is used only where Flutter GPU runs — the web build
/// (WebGL2). Until it is ready, when a snapshot's texture isn't uploaded
/// yet, or when it fails, the projective 2D painter ([TransitionPainter])
/// draws the frame.
class GpuTransitions {
  GpuTransitions._();

  static final GpuTransitions instance = GpuTransitions._();

  /// Whether the GPU renderer may start (off in VM tests and desktop
  /// builds, where Flutter GPU needs an engine flag).
  static bool enabled = kIsWeb;

  /// The transition types drawn with the GPU.
  static const types = {'flip', 'cube', 'doorway', 'swap', 'revolve'};

  /// null = not started, true = ready, false = unavailable.
  final ValueNotifier<bool?> available = ValueNotifier(null);

  Future<void>? _starting;

  /// Starts `flutter_scene` (once).
  Future<void> ensureStarted() {
    if (!enabled) {
      available.value = false;
      return Future.value();
    }
    return _starting ??= () async {
      try {
        await fs.Scene.initializeStaticResources();
        available.value = true;
        debugPrint('Slides transitions: GPU renderer ready (flutter_scene)');
      } on Object catch (e) {
        available.value = false;
        debugPrint('Slides transitions: GPU unavailable, using 2D: $e');
      }
    }();
  }

  bool get ready => available.value == true;

  final LinkedHashMap<ui.Image, Future<fs.Texture2D?>> _uploads =
      LinkedHashMap.identity();
  final Map<ui.Image, fs.Texture2D> _textures = Map.identity();

  /// Uploads [image] as a texture ahead of the transition.
  void prepare(ui.Image image) {
    if (!ready || _uploads.containsKey(image)) return;
    _uploads[image] = () async {
      try {
        final t = await fs.Texture2D.fromImage(
          image,
          opaque: true,
          sampling: const fs.TextureSampling(mipmaps: false),
        );
        _textures[image] = t;
        _warmUp(image);
        return t;
      } on Object catch (e) {
        debugPrint('Slides transitions: texture upload failed: $e');
        return null;
      }
    }();
    while (_uploads.length > 6) {
      final old = _uploads.keys.first;
      _uploads.remove(old);
      _textures.remove(old);
    }
  }

  bool _warmed = false;

  /// Renders one throwaway frame once the first texture is up, so the
  /// GPU pipelines are compiled before the first 3D transition (06 §14:
  /// transition start latency ≤ 1 frame).
  void _warmUp(ui.Image image) {
    if (_warmed) return;
    _warmed = true;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final w = image.width.toDouble(), h = image.height.toDouble();
    final turn = Matrix4.identity()
      ..translateByDouble(w / 2, h / 2, 0, 1)
      ..multiply(Matrix4.identity()..setEntry(3, 2, -1 / (2.2 * w)))
      ..rotateY(0.4)
      ..translateByDouble(-w / 2, -h / 2, 0, 1);
    paint(
      canvas,
      const Size(64, 36),
      frame: TransitionFrame(
        progress: 0.5,
        quads: [
          TransitionQuad(layer: TransitionLayer.outgoing, transform: turn),
          TransitionQuad(layer: TransitionLayer.incoming, shade: 0.1),
        ],
      ),
      outgoing: image,
      incoming: image,
      slideWidth: w,
      slideHeight: h,
      origin: Offset.zero,
      scale: 64 / w,
      pixelRatio: 1,
    );
    rec.endRecording().dispose();
  }

  /// The uploaded texture of [image], or null (not uploaded yet).
  fs.Texture2D? textureOf(ui.Image image) => _textures[image];

  // Created once the GPU is ready (touching Flutter GPU without Impeller
  // throws).
  fs.Scene? _gpuScene;
  fs.Scene get _scene => _gpuScene ??= fs.Scene()..maxGpuFramesInFlight = 0;
  final List<_Quad> _quads = [];

  /// Renders [frame] (a 3D type's quads) into [canvas]: the slide of
  /// [slideWidth] × [slideHeight] su at [origin] scaled by [scale] in a
  /// canvas of [size]; false when the GPU can't draw it (the caller paints
  /// the 2D fallback).
  bool paint(
    Canvas canvas,
    Size size, {
    required TransitionFrame frame,
    required ui.Image? outgoing,
    required ui.Image? incoming,
    required double slideWidth,
    required double slideHeight,
    required Offset origin,
    required double scale,
    required double pixelRatio,
  }) {
    if (!ready || outgoing == null || incoming == null) return false;
    final tOut = textureOf(outgoing), tIn = textureOf(incoming);
    if (tOut == null || tIn == null) {
      prepare(outgoing);
      prepare(incoming);
      return false;
    }
    try {
      final w = slideWidth, h = slideHeight;
      final quads = frame.quads;
      while (_quads.length < quads.length) {
        final q = _Quad();
        _quads.add(q);
        _scene.add(q.node);
      }
      for (var i = 0; i < _quads.length; i++) {
        final slot = _quads[i];
        if (i >= quads.length) {
          slot.node.visible = false;
          continue;
        }
        final q = quads[i];
        final tex = q.layer == TransitionLayer.outgoing ? tOut : tIn;
        slot.update(q, tex, w, h, order: i);
      }
      // The camera of the core's projection: 2.2 × the width in front of
      // the slide center; the viewport is the whole canvas with the slide
      // centered where the stage put it.
      final d = 2.2 * w;
      final cx = w / 2, cy = h / 2;
      final viewTop = -origin.dy / scale;
      final viewH = size.height / scale;
      // Vertical field of view so that the z = 0 plane maps 1 su → scale px.
      final fov = 2 * math.atan((viewH / 2) / d);
      // Shift the look-at so the slide center lands at the stage's center
      // (the stage centers it; small offsets are corrected here).
      final offY = (viewTop + viewH / 2) - cy;
      final viewLeft = -origin.dx / scale;
      final viewW = size.width / scale;
      final offX = (viewLeft + viewW / 2) - cx;
      final camera = fs.PerspectiveCamera(
        fovRadiansY: fov,
        position: vm.Vector3(cx + offX, -(cy + offY), -d),
        target: vm.Vector3(cx + offX, -(cy + offY), 0),
        up: vm.Vector3(0, 1, 0),
        fovNear: d * 0.05,
        fovFar: d * 6,
      );
      final backdrop = frame.backdrop;
      if (backdrop != null) {
        canvas.drawRect(
          Rect.fromLTWH(origin.dx, origin.dy, w * scale, h * scale),
          Paint()..color = Color(backdrop),
        );
      }
      _scene.render(
        camera,
        canvas,
        viewport: Offset.zero & size,
        pixelRatio: pixelRatio,
      );
      return true;
    } on Object catch (e, st) {
      debugPrint('Slides transitions: GPU rendering failed: $e\n$st');
      available.value = false;
      return false;
    }
  }
}

/// One quad slot of the GPU scene.
class _Quad {
  _Quad() {
    material = fs.UnlitMaterial()
      ..displayReferred = true
      ..doubleSided = true;
    node = fs.Node(mesh: fs.Mesh(_geometry(0, 0, 1, 1, 1, 1), material));
  }

  late final fs.UnlitMaterial material;
  late final fs.Node node;
  String? _geometryKey;

  static fs.MeshGeometry _geometry(
    double x,
    double y,
    double w,
    double h,
    double sw,
    double sh,
  ) {
    // Slide space (x right, y down) → world (x right, y up); the quad faces
    // the camera (−z).
    final positions = Float32List.fromList([
      x, -y, 0, //
      x + w, -y, 0, //
      x + w, -(y + h), 0, //
      x, -(y + h), 0, //
    ]);
    final normals = Float32List.fromList([
      0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, //
    ]);
    final uv = Float32List.fromList([
      x / sw, y / sh, //
      (x + w) / sw, y / sh, //
      (x + w) / sw, (y + h) / sh, //
      x / sw, (y + h) / sh, //
    ]);
    return fs.MeshGeometry.fromArrays(
      positions: positions,
      normals: normals,
      texCoords: uv,
      indices: const [0, 2, 1, 0, 3, 2],
    );
  }

  /// S = diag(1, −1, −1): slide space (y down, +z toward the viewer) ↔
  /// world (y up, +z away from the viewer).
  static final vm.Matrix4 _flip = vm.Matrix4.diagonal3Values(1, -1, -1);

  void update(
    TransitionQuad q,
    fs.Texture2D texture,
    double w,
    double h, {
    required int order,
  }) {
    final r = q.region;
    final (x, y, rw, rh) = r == null
        ? (0.0, 0.0, w, h)
        : (r.x, r.y, r.width, r.height);
    final key = '$x|$y|$rw|$rh|$w|$h';
    if (key != _geometryKey) {
      _geometryKey = key;
      node.mesh = fs.Mesh(_geometry(x, y, rw, rh, w, h), material);
    }
    material.baseColorTexture = texture;
    final k = 1 - q.shade.clamp(0.0, 1.0);
    final a = q.opacity.clamp(0.0, 1.0);
    material.baseColorFactor = vm.Vector4(k, k, k, a);
    material.alphaMode = a < 1 ? fs.AlphaMode.blend : fs.AlphaMode.opaque;
    node.visible = q.visible && a > 0;
    // The quad's body: the core transform without the camera's
    // perspective (T(c)·P·T(−c)), in world space.
    final m = vm.Matrix4.fromList(_body(q.transform, w, h));
    node.localTransform = _flip.clone()
      ..multiply(m)
      ..multiply(_flip);
  }

  static List<double> _body(Matrix4 t, double w, double h) {
    // view = T(c)·P·T(−c); body = view⁻¹ · t.
    final view = vm.Matrix4.identity()
      ..translateByDouble(w / 2, h / 2, 0, 1)
      ..multiply(vm.Matrix4.identity()..setEntry(3, 2, -1 / (2.2 * w)))
      ..translateByDouble(-w / 2, -h / 2, 0, 1);
    final inv = vm.Matrix4.inverted(view);
    final tm = vm.Matrix4.fromList([for (final v in t.storage) v]);
    return (inv..multiply(tm)).storage;
  }
}
