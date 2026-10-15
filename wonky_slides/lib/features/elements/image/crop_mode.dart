import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource, KeyScope;
import 'package:wonky_slides_core/model.dart' show ElementFrame, ElementKind;
import 'package:wonky_slides_core/scene.dart';
import 'package:wonky_slides_core/snapping.dart' show FrameTransforms;
import 'package:wonky_slides_core/themes.dart' show SuRect;

import '../../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../../l10n/slides_l10n.dart';
import '../../canvas/canvas_interactions.dart';
import '../../canvas/canvas_tokens.dart';
import '../../canvas/slide_canvas_controller.dart';
import '../../editor_screen/deck_editor_controller.dart';
import '../../selection/slide_elements.dart';
import '../../text_editing/text_edit_geometry.dart';
import 'image_geometry.dart';

/// Aspect presets of the crop bar (03 §6.5.4): key → w / h (null = free,
/// `original` = the image's own).
const cropAspects = <String, double?>{
  'free': null,
  'original': null,
  '1:1': 1,
  '4:3': 4 / 3,
  '16:9': 16 / 9,
  '3:2': 3 / 2,
  '9:16': 9 / 16,
};

enum _CropDrag { none, box, image }

/// Image crop mode (03 §6.5.4, `slidesCrop` scope): the whole image shows
/// dimmed outside the crop box; the box's eight handles change the visible
/// area, dragging the image moves it under the box, the crop bar offers
/// aspect presets, *Fill* and *Fit*. Enter, *Done* or a click outside
/// commits (one undo step "Crop image" — `slides.image.crop` writes
/// `dataJson.crop` and the frame); Esc or *Cancel* leaves without writing.
///
/// A modal [CanvasInteraction]: one per canvas, found with [of].
class ImageCropMode extends CanvasInteraction {
  ImageCropMode(super.c) {
    c.editor.addListener(_onEditor);
  }

  /// The crop mode of [ed]'s canvas, or null without a canvas.
  static ImageCropMode? of(DeckEditorController ed) {
    final canvas = SlideCanvasController.of(ed);
    return canvas == null
        ? null
        : CanvasInteractions.find<ImageCropMode>(canvas);
  }

  String? _id;
  String? _slideId;
  ElementFrame? _start;
  CropState? _state;
  CropState? _downState;
  Offset _downLocal = Offset.zero;
  _CropDrag _drag = _CropDrag.none;
  (int, int)? _edges; // (-1|0|1 horizontal, -1|0|1 vertical)
  String _aspect = 'free';

  /// The image being cropped, or null.
  String? get elementId => _id;

  /// The live crop (tests).
  CropState? get state => _state;

  /// The active aspect preset key.
  String get aspect => _aspect;

  @override
  bool get modal => true;

  @override
  bool get active => _id != null;

  @override
  bool get hidesSelectionChrome => active;

  @override
  List<KeyScope> get keyScopes => active ? [SlidesKeyScopes.crop] : const [];

  /// Whether image [id] can be cropped (a placed image on the current slide).
  bool canCrop(String id) {
    final e = c.elements?[id];
    if (e == null || e.record.kind != ElementKind.image || e.locked) {
      return false;
    }
    final src = e.data?['src'];
    return src is String && src.isNotEmpty;
  }

  /// Enters crop mode on image [id] (selects it). Returns whether it did.
  bool begin(String id) {
    if (!canCrop(id) || !c.editor.canEdit) return false;
    final f = c.frameOf(id);
    final e = c.elements![id]!;
    if (f == null) return false;
    _id = id;
    _slideId = c.editor.surfaceId;
    _start = f;
    _state = CropState.of(
      ImageCrop.fromJson(e.data?['crop']),
      f.width,
      f.height,
    );
    _aspect = 'free';
    if (c.editor.selectedElementIds.length != 1 ||
        c.editor.selectedElementIds.single != id) {
      c.selection.select([id], enteredGroup: c.elements?.parentOf(id)?.id);
    }
    c.editor.armTool(null);
    c.refresh();
    return true;
  }

  /// Leaves crop mode without writing (Esc, *Cancel*).
  void cancelCrop() {
    if (_id == null) return;
    _id = null;
    _state = null;
    _drag = _CropDrag.none;
    c.refresh();
  }

  /// The arguments of `slides.image.crop` for the live state (crop and the
  /// new frame in the element's parent space), or null.
  Map<String, Object?>? commitArgs() {
    final id = _id, f = _start, s = _state;
    if (id == null || f == null || s == null) return null;
    final box = s.box;
    // The box center relative to the start frame's center, through flips
    // and rotation back into slide space.
    var dx = box.x + box.width / 2 - f.width / 2;
    var dy = box.y + box.height / 2 - f.height / 2;
    if (f.flipH) dx = -dx;
    if (f.flipV) dy = -dy;
    final a = f.rotation * math.pi / 180;
    final cx = f.cx + dx * math.cos(a) - dy * math.sin(a);
    final cy = f.cy + dx * math.sin(a) + dy * math.cos(a);
    var frame = ElementFrame(
      cx - box.width / 2,
      cy - box.height / 2,
      box.width,
      box.height,
      rotation: f.rotation,
      flipH: f.flipH,
      flipV: f.flipV,
    );
    final parent = c.elements?.parentOf(id);
    if (parent != null) {
      frame = FrameTransforms.toChild(
        frame,
        SlideElements.frameOf(parent),
        SlideElements.childBoundsOf(parent),
      );
    }
    double r(double v) => (v * 100).roundToDouble() / 100;
    return {
      'id': id,
      'crop': s.crop.toJson(),
      'x': r(frame.x),
      'y': r(frame.y),
      'width': r(frame.width),
      'height': r(frame.height),
    };
  }

  /// Commits (Enter, *Done*, a click outside): runs `slides.image.crop`
  /// with the live state (nothing is written when it didn't change).
  Future<void> commit({BuildContext? context}) async {
    final args = commitArgs();
    final start = _start;
    final id = _id;
    cancelCrop();
    if (args == null || start == null || id == null) return;
    final unchanged =
        ImageCrop.fromJson(c.elements?[id]?.data?['crop']) ==
            ImageCrop.fromJson(args['crop']) &&
        ((args['width']! as double) - start.width).abs() < 0.01 &&
        ((args['height']! as double) - start.height).abs() < 0.01;
    if (unchanged) return;
    await c.editor.invokeCommand(
      'slides.image.crop',
      args,
      InvocationSource.ui,
      context,
    );
  }

  /// Applies an aspect preset of the crop bar.
  void setAspect(String key) {
    final s = _state;
    if (s == null || !cropAspects.containsKey(key)) return;
    _aspect = key;
    if (key != 'free') _state = s.withAspect(cropAspects[key]);
    c.refresh();
  }

  /// *Fill*: the image covers the box.
  void fill() {
    final s = _state;
    if (s == null) return;
    _state = s.fill();
    c.refresh();
  }

  /// *Fit*: the whole image inside the box.
  void fit() {
    final s = _state;
    if (s == null) return;
    _state = s.fit();
    c.refresh();
  }

  double? get _lockedAspect => switch (_aspect) {
    'free' => null,
    'original' =>
      _state == null ? null : _state!.image.width / _state!.image.height,
    _ => cropAspects[_aspect],
  };

  void _onEditor() {
    final id = _id;
    if (id == null) return;
    final ed = c.editor;
    if (ed.surfaceId != _slideId ||
        !ed.selectedElementIds.contains(id) ||
        ed.model.element(id) == null ||
        !ed.canEdit) {
      cancelCrop();
    }
  }

  // ------------------------------------------------------------ pointer

  Offset _local(Offset su) => SlideCanvasController.slideToLocal(_start!, su);

  /// Handle positions (local su) with their edges.
  List<(Offset, (int, int))> _handles() {
    final b = _state!.box;
    final xs = [b.x, b.x + b.width / 2, b.right];
    final ys = [b.y, b.y + b.height / 2, b.bottom];
    return [
      for (var i = 0; i < 3; i++)
        for (var j = 0; j < 3; j++)
          if (i != 1 || j != 1) (Offset(xs[i], ys[j]), (i - 1, j - 1)),
    ];
  }

  @override
  bool down(CanvasPointer p) {
    if (!active || _state == null) return false;
    final local = _local(p.su);
    final tol = 8 / math.max(c.viewport.scale, 1e-3);
    for (final (pt, edges) in _handles()) {
      if ((pt - local).distance <= tol) {
        _drag = _CropDrag.box;
        _edges = edges;
        _downState = _state;
        _downLocal = local;
        return true;
      }
    }
    final img = _state!.image;
    if (local.dx >= img.x &&
        local.dx <= img.right &&
        local.dy >= img.y &&
        local.dy <= img.bottom) {
      _drag = _CropDrag.image;
      _downState = _state;
      _downLocal = local;
      return true;
    }
    // A click outside commits; the press goes on as usual.
    unawaited(commit());
    return false;
  }

  @override
  void move(CanvasPointer p) {
    final s0 = _downState;
    if (s0 == null || _drag == _CropDrag.none) return;
    final d = _local(p.su) - _downLocal;
    if (_drag == _CropDrag.image) {
      _state = s0.moveImage(d.dx, d.dy);
    } else {
      final (h, v) = _edges!;
      final aspect = p.modifiers.shift && _aspect == 'free'
          ? s0.box.width / s0.box.height
          : _lockedAspect;
      _state = s0.resizeBox(
        h < 0 ? d.dx : 0,
        v < 0 ? d.dy : 0,
        h > 0 ? d.dx : 0,
        v > 0 ? d.dy : 0,
        aspect: aspect,
      );
    }
    c.refresh();
  }

  @override
  void up(CanvasPointer p) {
    _drag = _CropDrag.none;
    _downState = null;
  }

  @override
  void cancel() {
    final s0 = _downState;
    if (s0 != null) _state = s0;
    _drag = _CropDrag.none;
    _downState = null;
    c.refresh();
  }

  @override
  MouseCursor? cursorAt(Offset su) {
    if (!active || _state == null) return null;
    final local = _local(su);
    final tol = 8 / math.max(c.viewport.scale, 1e-3);
    for (final (pt, (h, v)) in _handles()) {
      if ((pt - local).distance <= tol) {
        return h == 0
            ? SystemMouseCursors.resizeUpDown
            : v == 0
            ? SystemMouseCursors.resizeLeftRight
            : (h == v
                  ? SystemMouseCursors.resizeUpLeftDownRight
                  : SystemMouseCursors.resizeUpRightDownLeft);
      }
    }
    final img = _state!.image;
    final inside =
        local.dx >= img.x &&
        local.dx <= img.right &&
        local.dy >= img.y &&
        local.dy <= img.bottom;
    return inside ? SystemMouseCursors.move : SystemMouseCursors.basic;
  }

  // ------------------------------------------------------------- render

  @override
  SlideScene sceneFor(SlideScene scene) {
    final id = _id;
    if (id == null) return scene;
    SceneNode? strip(SceneNode n) {
      if (n.elementId == id) return null;
      if (n is GroupNode) {
        return GroupNode(
          elementId: n.elementId,
          transform: n.transform,
          opacity: n.opacity,
          clip: n.clip,
          effects: n.effects,
          children: [for (final ch in n.children) ?strip(ch)],
        );
      }
      return n;
    }

    return SlideScene(
      slideId: scene.slideId,
      width: scene.width,
      height: scene.height,
      background: scene.background,
      nodes: [for (final n in scene.nodes) ?strip(n)],
      frames: scene.frames,
      routes: scene.routes,
    );
  }

  @override
  void paint(Canvas canvas, CanvasTokens tokens) {
    final id = _id, f = _start, s = _state;
    if (id == null || f == null || s == null) return;
    final e = c.elements?[id];
    final data = e?.data ?? const <String, Object?>{};
    final v = c.viewport;
    canvas.save();
    canvas.translate(v.origin.dx, v.origin.dy);
    canvas.scale(v.scale);
    canvas.transform(
      TextEditGeometry.elementMatrix(
        SuRect(f.x, f.y, f.width, f.height),
        rotation: f.rotation,
        flipH: f.flipH,
        flipV: f.flipV,
      ).storage,
    );
    final src = data['src'];
    final image = src is String
        ? c.renderer.images.imageOf(
            SlideImageRef(
              src,
              naturalWidth: (data['naturalWidth'] as num?)?.toInt(),
              naturalHeight: (data['naturalHeight'] as num?)?.toInt(),
            ),
          )
        : null;
    final dst = Rect.fromLTWH(
      s.image.x,
      s.image.y,
      s.image.width,
      s.image.height,
    );
    final box = Rect.fromLTWH(s.box.x, s.box.y, s.box.width, s.box.height);
    if (image != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      final adjust = data['adjust'] is Map
          ? (data['adjust'] as Map).cast<String, Object?>()
          : null;
      final m = ImageAdjust.matrix(adjust);
      final paint = Paint()..filterQuality = FilterQuality.medium;
      if (m != null) paint.colorFilter = ColorFilter.matrix(m);
      canvas.drawImageRect(
        image,
        srcRect,
        dst,
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = const Color(0x59000000),
      );
      canvas.save();
      canvas.clipRect(box);
      canvas.drawImageRect(image, srcRect, dst, paint);
      canvas.restore();
    } else {
      canvas.drawRect(dst, Paint()..color = const Color(0x33808080));
    }
    final px = 1 / math.max(v.scale, 1e-3);
    canvas.drawRect(
      dst,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px
        ..color = tokens.selection.withValues(alpha: .5),
    );
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * px
        ..color = tokens.selection,
    );
    // Thirds.
    final thirds = Paint()
      ..strokeWidth = px
      ..color = tokens.handleFill.withValues(alpha: .6);
    for (final k in [1 / 3, 2 / 3]) {
      canvas.drawLine(
        Offset(box.left + box.width * k, box.top),
        Offset(box.left + box.width * k, box.bottom),
        thirds,
      );
      canvas.drawLine(
        Offset(box.left, box.top + box.height * k),
        Offset(box.right, box.top + box.height * k),
        thirds,
      );
    }
    // Crop handles: thick L corners and edge bars.
    final bar = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * px
      ..strokeCap = StrokeCap.square
      ..color = tokens.selection;
    final len = math.min(16 * px, math.min(box.width, box.height) / 3);
    for (final (pt, (h, vv)) in _handles()) {
      final path = ui.Path();
      if (h != 0 && vv != 0) {
        path
          ..moveTo(pt.dx - h * len, pt.dy)
          ..lineTo(pt.dx, pt.dy)
          ..lineTo(pt.dx, pt.dy - vv * len);
      } else if (h == 0) {
        path
          ..moveTo(pt.dx - len / 2, pt.dy)
          ..lineTo(pt.dx + len / 2, pt.dy);
      } else {
        path
          ..moveTo(pt.dx, pt.dy - len / 2)
          ..lineTo(pt.dx, pt.dy + len / 2);
      }
      canvas.drawPath(path, bar);
    }
    canvas.restore();
  }

  @override
  List<Widget> overlays(BuildContext context) {
    final f = _start, s = _state;
    if (!active || f == null || s == null) return const [];
    final r = c.viewport.rectToViewport(f.bounds);
    return [
      Positioned(
        left: math.max(8, r.left),
        top: math.max(8, r.top - 48),
        child: CanvasChrome(child: _CropBar(mode: this)),
      ),
    ];
  }

  @override
  void dispose() {
    c.editor.removeListener(_onEditor);
  }
}

/// The floating crop bar: aspect presets, *Fill*, *Fit*, *Cancel*, *Done*.
class _CropBar extends StatelessWidget {
  const _CropBar({required this.mode});

  final ImageCropMode mode;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    final theme = ShadTheme.of(context);
    String label(String k) => switch (k) {
      'free' => l.cropAspectFree,
      'original' => l.cropAspectOriginal,
      _ => k,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: DecoratedBox(
        key: const ValueKey<String>('slides.image.cropBar'),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.border),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 112,
                child: ShadSelect<String>(
                  key: ValueKey<String>(
                    'slides.image.cropAspect.${mode.aspect}',
                  ),
                  initialValue: mode.aspect,
                  minWidth: 112,
                  options: [
                    for (final k in cropAspects.keys)
                      ShadOption<String>(value: k, child: Text(label(k))),
                  ],
                  selectedOptionBuilder: (_, v) => Text(label(v)),
                  onChanged: (v) {
                    if (v != null) mode.setAspect(v);
                  },
                ),
              ),
              ShadButton.ghost(
                key: const ValueKey<String>('slides.image.cropFill'),
                size: ShadButtonSize.sm,
                onPressed: mode.fill,
                child: Text(l.cropFill),
              ),
              ShadButton.ghost(
                key: const ValueKey<String>('slides.image.cropFit'),
                size: ShadButtonSize.sm,
                onPressed: mode.fit,
                child: Text(l.cropFit),
              ),
              ShadButton.outline(
                key: const ValueKey<String>('slides.image.cropCancel'),
                size: ShadButtonSize.sm,
                onPressed: mode.cancelCrop,
                child: Text(l.dialogCancel),
              ),
              ShadButton(
                key: const ValueKey<String>('slides.image.cropDone'),
                size: ShadButtonSize.sm,
                onPressed: () => unawaited(mode.commit(context: context)),
                child: Text(l.cropDone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
