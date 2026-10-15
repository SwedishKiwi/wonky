import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/themes.dart' show SuRect;

/// `crop` of an image's `dataJson` (02 §6.4): fractions of the natural
/// size removed from each side.
@immutable
class ImageCrop {
  const ImageCrop({this.l = 0, this.t = 0, this.r = 0, this.b = 0});

  static const none = ImageCrop();

  final double l;
  final double t;
  final double r;
  final double b;

  /// Reads `dataJson.crop` (null/invalid = none).
  factory ImageCrop.fromJson(Object? raw) {
    if (raw is! Map) return none;
    double v(String k) {
      final x = raw[k];
      return x is num ? x.toDouble().clamp(0.0, 1.0) : 0.0;
    }

    return ImageCrop(l: v('l'), t: v('t'), r: v('r'), b: v('b'));
  }

  bool get isNone => l == 0 && t == 0 && r == 0 && b == 0;

  /// The visible fraction of the width / height.
  double get visibleWidth => math.max(1e-6, 1 - l - r);
  double get visibleHeight => math.max(1e-6, 1 - t - b);

  /// The stored value (4 decimals; all keys, so a merge patch replaces
  /// the whole crop).
  Map<String, double> toJson() => {
    'l': _r(l),
    't': _r(t),
    'r': _r(r),
    'b': _r(b),
  };

  static double _r(double v) => (v.clamp(0.0, 1.0) * 10000).round() / 10000;

  @override
  bool operator ==(Object other) =>
      other is ImageCrop &&
      (other.l - l).abs() < 1e-6 &&
      (other.t - t).abs() < 1e-6 &&
      (other.r - r).abs() < 1e-6 &&
      (other.b - b).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(_r(l), _r(t), _r(r), _r(b));

  @override
  String toString() => 'ImageCrop($l, $t, $r, $b)';
}

/// Image placement and crop math (03 §6.5): pure, shared by the insert
/// commands, *Replace*, *Reset* and crop mode.
abstract final class ImageGeometry {
  /// Where a new image of [naturalW] × [naturalH] px goes on a slide of
  /// [slideW] × [slideH] su (03 §6.5.1): 1 px = 1 su, scaled down to fit
  /// 80 % of the slide, centered (or centered on [at], kept on the slide).
  static SuRect place(
    double naturalW,
    double naturalH, {
    required double slideW,
    required double slideH,
    ({double x, double y})? at,
  }) {
    var w = math.max(1.0, naturalW), h = math.max(1.0, naturalH);
    final k = math.min(1.0, math.min(slideW * .8 / w, slideH * .8 / h));
    w *= k;
    h *= k;
    var x = (at?.x ?? slideW / 2) - w / 2;
    var y = (at?.y ?? slideH / 2) - h / 2;
    x = x.clamp(0.0, math.max(0.0, slideW - w));
    y = y.clamp(0.0, math.max(0.0, slideH - h));
    return SuRect(_r(x), _r(y), _r(w), _r(h));
  }

  /// The crop that makes an image of [naturalW] × [naturalH] cover a frame
  /// of [frameW] × [frameH] (centered; 03 §6.5.2 *Replace* and picture
  /// placeholders "fill and crop to cover").
  static ImageCrop cover(
    double naturalW,
    double naturalH,
    double frameW,
    double frameH,
  ) {
    if (naturalW <= 0 || naturalH <= 0 || frameW <= 0 || frameH <= 0) {
      return ImageCrop.none;
    }
    final img = naturalW / naturalH, frame = frameW / frameH;
    if ((img - frame).abs() < 1e-6) return ImageCrop.none;
    if (img > frame) {
      // Wider: crop left and right.
      final keep = frame / img;
      final side = (1 - keep) / 2;
      return ImageCrop(l: side, r: side);
    }
    final keep = img / frame;
    final side = (1 - keep) / 2;
    return ImageCrop(t: side, b: side);
  }

  /// The frame height that shows [crop] of a [naturalW] × [naturalH] image
  /// undistorted at [width] (*Reset image* keeps the width, 03 §6.5.2).
  static double heightFor(
    double naturalW,
    double naturalH,
    double width, {
    ImageCrop crop = ImageCrop.none,
  }) {
    if (naturalW <= 0 || naturalH <= 0) return width;
    final w = naturalW * crop.visibleWidth;
    final h = naturalH * crop.visibleHeight;
    return _r(width * h / w);
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}

/// The live state of crop mode (03 §6.5.4) in the element-local su of the
/// frame crop mode started from (origin = its top-left, unrotated): the
/// whole image rectangle [image] and the visible crop box [box]. The box
/// stays inside the image; the stored crop is the box's place in the
/// image, the new frame is the box.
@immutable
class CropState {
  const CropState(this.image, this.box);

  /// The state of a frame of [frameW] × [frameH] showing [crop].
  factory CropState.of(ImageCrop crop, double frameW, double frameH) {
    final iw = frameW / crop.visibleWidth;
    final ih = frameH / crop.visibleHeight;
    return CropState(
      SuRect(-crop.l * iw, -crop.t * ih, iw, ih),
      SuRect(0, 0, frameW, frameH),
    );
  }

  final SuRect image;
  final SuRect box;

  /// The crop the state stores.
  ImageCrop get crop => ImageCrop(
    l: (box.x - image.x) / image.width,
    t: (box.y - image.y) / image.height,
    r: (image.right - box.right) / image.width,
    b: (image.bottom - box.bottom) / image.height,
  );

  /// Smallest box side (su).
  static const minSide = 8.0;

  /// Moves the box edges by ([dl], [dt], [dr], [db]) (a handle drag),
  /// clamped to the image; with [aspect] (w / h) the box keeps that ratio
  /// (the dragged edges lead).
  CropState resizeBox(
    double dl,
    double dt,
    double dr,
    double db, {
    double? aspect,
  }) {
    var l = box.x + dl, t = box.y + dt;
    var r = box.right + dr, b = box.bottom + db;
    l = l.clamp(image.x, r - minSide);
    t = t.clamp(image.y, b - minSide);
    r = r.clamp(l + minSide, image.right);
    b = b.clamp(t + minSide, image.bottom);
    if (aspect != null && aspect > 0) {
      final horizontal = dl != 0 || dr != 0;
      final vertical = dt != 0 || db != 0;
      var w = r - l, h = b - t;
      if (horizontal && !vertical) {
        h = w / aspect;
      } else if (vertical && !horizontal) {
        w = h * aspect;
      } else {
        // Corner: the larger change leads.
        if (w / h > aspect) {
          w = h * aspect;
        } else {
          h = w / aspect;
        }
      }
      // Anchor at the edges that didn't move.
      if (dl != 0 && dr == 0) l = r - w;
      if (dr != 0 || dl == 0) r = l + w;
      if (dt != 0 && db == 0) t = b - h;
      if (db != 0 || dt == 0) b = t + h;
      final fitted = _fitInImage(SuRect(l, t, r - l, b - t), aspect);
      return CropState(image, fitted);
    }
    return CropState(image, SuRect(l, t, r - l, b - t));
  }

  /// Moves the image by ([dx], [dy]) under the box (it keeps covering it).
  CropState moveImage(double dx, double dy) {
    final x = (image.x + dx).clamp(box.right - image.width, box.x);
    final y = (image.y + dy).clamp(box.bottom - image.height, box.y);
    return CropState(SuRect(x, y, image.width, image.height), box);
  }

  /// The box with [aspect] (w / h; null = the image's own, *Original*):
  /// the largest box of that ratio around the current box's center that
  /// fits the image.
  CropState withAspect(double? aspect) {
    final a = aspect ?? image.width / image.height;
    var w = box.width, h = box.height;
    if (w / h > a) {
      w = h * a;
    } else {
      h = w / a;
    }
    final c = (x: box.x + box.width / 2, y: box.y + box.height / 2);
    return CropState(
      image,
      _fitInImage(SuRect(c.x - w / 2, c.y - h / 2, w, h), a),
    );
  }

  /// *Fill*: the image scaled to cover the box (centered on it).
  CropState fill() {
    final k = math.max(box.width / image.width, box.height / image.height);
    final w = image.width * k, h = image.height * k;
    return CropState(
      SuRect(box.x + (box.width - w) / 2, box.y + (box.height - h) / 2, w, h),
      box,
    );
  }

  /// *Fit*: the whole image, scaled to fit inside the box (the box becomes
  /// the image, centered where the box was).
  CropState fit() {
    final k = math.min(box.width / image.width, box.height / image.height);
    final w = image.width * k, h = image.height * k;
    final r = SuRect(
      box.x + (box.width - w) / 2,
      box.y + (box.height - h) / 2,
      w,
      h,
    );
    return CropState(r, r);
  }

  /// [r] shrunk (keeping [aspect] and its center) and moved to lie inside
  /// the image.
  SuRect _fitInImage(SuRect r, double aspect) {
    var w = r.width, h = r.height;
    final k = math.min(1.0, math.min(image.width / w, image.height / h));
    w *= k;
    h *= k;
    var x = r.x + (r.width - w) / 2, y = r.y + (r.height - h) / 2;
    x = x.clamp(image.x, image.right - w);
    y = y.clamp(image.y, image.bottom - h);
    return SuRect(x, y, w, h);
  }
}
