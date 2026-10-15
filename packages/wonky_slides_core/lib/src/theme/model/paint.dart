/// Fill, stroke and shadow values (Slides 02 §5.2–§5.4) as used by theme
/// JSON (backgrounds, default object styles).
library;

import '../color/color_ref.dart';
import '../json/json_util.dart';
import 'common.dart';

/// Image fit modes of an image fill.
const Set<String> imageFitValues = {'cover', 'contain', 'tile', 'stretch'};

/// Stroke dash styles.
const Set<String> dashValues = {'solid', 'dash', 'dot', 'dashDot', 'longDash'};

/// Line arrow heads.
const Set<String> arrowValues = {
  'none',
  'triangle',
  'open',
  'stealth',
  'circle',
  'diamond',
  'bar',
};

/// A fill (`fillJson`, 02 §5.2).
sealed class SlideFill {
  const SlideFill();

  /// `{"type":"none"}`.
  static const SlideFill none = NoFill();

  /// JSON form (with `"v": 1`).
  JsonMap toJson();

  /// Every color the fill references.
  Iterable<ColorRef> get colors;

  /// Parses a fill (`"v"` optional). Errors → `null`.
  static SlideFill? fromJson(Object? json, String path, IssueSink sink) {
    if (json is! Map) {
      sink.error(
        path,
        json == null ? 'missing' : 'wrong_type',
        'Expected a fill object.',
      );
      return null;
    }
    final type = json['type'];
    switch (type) {
      case 'none':
        JsonReader(
          json.cast<String, Object?>(),
          path,
          sink,
          known: {'v', 'type'},
        ).version();
        return const NoFill();
      case 'solid':
        final r = JsonReader(
          json.cast<String, Object?>(),
          path,
          sink,
          known: {'v', 'type', 'color'},
        );
        r.version();
        final c = readColor(r, 'color', required: true);
        return c == null ? null : SolidFill(c);
      case 'gradient':
        final r = JsonReader(
          json.cast<String, Object?>(),
          path,
          sink,
          known: {'v', 'type', 'kind', 'angle', 'stops', 'center', 'radius'},
        );
        r.version();
        final kind = r.string(
          'kind',
          allowed: {'linear', 'radial'},
          fallback: 'linear',
        )!;
        final angle = r.number('angle', min: -360, max: 360) ?? 0;
        final center = r.list('center');
        final radius = r.number('radius', min: 0, max: 4);
        final stops = <GradientStop>[];
        final list = r.list('stops', required: true) ?? const [];
        for (var i = 0; i < list.length; i++) {
          final s = JsonReader.object(
            list[i],
            '${r.at('stops')}[$i]',
            sink,
            known: {'at', 'color'},
          );
          if (s == null) continue;
          final at = s.number('at', required: true, min: 0, max: 1);
          final c = readColor(s, 'color', required: true);
          if (at != null && c != null) stops.add(GradientStop(at, c));
        }
        if (stops.length < 2) {
          sink.error(
            r.at('stops'),
            'too_few',
            'A gradient needs at least 2 stops.',
          );
          return null;
        }
        double? cx, cy;
        if (center != null) {
          if (center.length == 2 && center.every((v) => v is num)) {
            cx = (center[0] as num).toDouble();
            cy = (center[1] as num).toDouble();
          } else {
            sink.error(
              r.at('center'),
              'wrong_type',
              'Expected [x, y] fractions.',
            );
          }
        }
        return GradientFill(
          kind: kind,
          angle: angle,
          stops: List.unmodifiable(stops),
          centerX: cx,
          centerY: cy,
          radius: radius,
        );
      case 'image':
        final r = JsonReader(
          json.cast<String, Object?>(),
          path,
          sink,
          known: {'v', 'type', 'fileUuid', 'fit', 'opacity'},
        );
        r.version();
        final file = r.string('fileUuid', required: true);
        final fit = r.string(
          'fit',
          allowed: imageFitValues,
          fallback: 'cover',
        )!;
        final opacity = r.number('opacity', min: 0, max: 1) ?? 1;
        return file == null
            ? null
            : ImageFill(file, fit: fit, opacity: opacity);
      default:
        sink.error('$path.type', 'out_of_range', 'Unknown fill type "$type".');
        return null;
    }
  }
}

/// No fill.
final class NoFill extends SlideFill {
  /// The empty fill.
  const NoFill();

  @override
  JsonMap toJson() => {'v': 1, 'type': 'none'};

  @override
  Iterable<ColorRef> get colors => const [];

  @override
  bool operator ==(Object other) => other is NoFill;

  @override
  int get hashCode => 7;
}

/// A solid color.
final class SolidFill extends SlideFill {
  /// Creates a solid fill.
  const SolidFill(this.color);

  /// The color.
  final ColorRef color;

  @override
  JsonMap toJson() => {'v': 1, 'type': 'solid', 'color': color.json};

  @override
  Iterable<ColorRef> get colors => [color];

  @override
  bool operator ==(Object other) => other is SolidFill && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

/// One gradient stop.
final class GradientStop {
  /// Creates a stop.
  const GradientStop(this.at, this.color);

  /// Position 0–1.
  final double at;

  /// Color.
  final ColorRef color;

  /// JSON form.
  JsonMap toJson() => {'at': normalizeJsonNumber(at), 'color': color.json};
}

/// A linear or radial gradient.
final class GradientFill extends SlideFill {
  /// Creates a gradient.
  const GradientFill({
    this.kind = 'linear',
    this.angle = 0,
    required this.stops,
    this.centerX,
    this.centerY,
    this.radius,
  });

  /// `linear` or `radial`.
  final String kind;

  /// Linear: direction in degrees (0 = left → right, clockwise).
  final double angle;

  /// Stops (≥ 2).
  final List<GradientStop> stops;

  /// Radial: center as fractions of the box (default 0.5, 0.5).
  final double? centerX;

  /// Radial: center as fractions of the box.
  final double? centerY;

  /// Radial: radius as a fraction of the box diagonal (default 0.5).
  final double? radius;

  @override
  JsonMap toJson() => {
    'v': 1,
    'type': 'gradient',
    'kind': kind,
    'angle': normalizeJsonNumber(angle),
    'stops': [for (final s in stops) s.toJson()],
    if (centerX != null && centerY != null)
      'center': [normalizeJsonNumber(centerX!), normalizeJsonNumber(centerY!)],
    if (radius != null) 'radius': normalizeJsonNumber(radius!),
  };

  @override
  Iterable<ColorRef> get colors => [for (final s in stops) s.color];

  @override
  bool operator ==(Object other) =>
      other is GradientFill && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

/// An uploaded image (`fileUuid`).
final class ImageFill extends SlideFill {
  /// Creates an image fill.
  const ImageFill(this.fileUuid, {this.fit = 'cover', this.opacity = 1});

  /// The uploaded file.
  final String fileUuid;

  /// `cover`, `contain`, `tile`, `stretch`.
  final String fit;

  /// 0–1.
  final double opacity;

  @override
  JsonMap toJson() => {
    'v': 1,
    'type': 'image',
    'fileUuid': fileUuid,
    'fit': fit,
    'opacity': normalizeJsonNumber(opacity),
  };

  @override
  Iterable<ColorRef> get colors => const [];

  @override
  bool operator ==(Object other) =>
      other is ImageFill && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

/// A stroke (`strokeJson`, 02 §5.3). Properties may be partial in theme
/// defaults (null = renderer default); [isNone] is `{"type":"none"}`.
final class SlideStroke {
  /// Creates a stroke.
  const SlideStroke({
    this.color,
    this.width,
    this.dash,
    this.cap,
    this.join,
    this.startArrow,
    this.endArrow,
    this.arrowSize,
  }) : isNone = false;

  /// No stroke.
  const SlideStroke.none()
    : isNone = true,
      color = null,
      width = null,
      dash = null,
      cap = null,
      join = null,
      startArrow = null,
      endArrow = null,
      arrowSize = null;

  /// Whether this is "no stroke".
  final bool isNone;

  /// Color.
  final ColorRef? color;

  /// Width (su).
  final double? width;

  /// Dash style.
  final String? dash;

  /// `butt`, `round`, `square`.
  final String? cap;

  /// `miter`, `round`, `bevel`.
  final String? join;

  /// Line start arrow.
  final String? startArrow;

  /// Line end arrow.
  final String? endArrow;

  /// `s`, `m`, `l`.
  final String? arrowSize;

  /// A copy with the width multiplied by [s].
  SlideStroke scaled(double s) => isNone || width == null
      ? this
      : SlideStroke(
          color: color,
          width: width! * s,
          dash: dash,
          cap: cap,
          join: join,
          startArrow: startArrow,
          endArrow: endArrow,
          arrowSize: arrowSize,
        );

  /// JSON form (with `"v": 1`).
  JsonMap toJson() {
    if (isNone) return {'v': 1, 'type': 'none'};
    final out = <String, Object?>{'v': 1};
    putIfNotNull(out, 'color', color?.json);
    putIfNotNull(out, 'width', width);
    putIfNotNull(out, 'dash', dash);
    putIfNotNull(out, 'cap', cap);
    putIfNotNull(out, 'join', join);
    putIfNotNull(out, 'startArrow', startArrow);
    putIfNotNull(out, 'endArrow', endArrow);
    putIfNotNull(out, 'arrowSize', arrowSize);
    return out;
  }

  /// Parses a stroke (`"v"` optional). Errors → `null`.
  static SlideStroke? fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {
        'v',
        'type',
        'color',
        'width',
        'dash',
        'cap',
        'join',
        'startArrow',
        'endArrow',
        'arrowSize',
      },
    );
    if (r == null) return null;
    r.version();
    final type = r.string('type', allowed: {'none', 'solid'});
    if (type == 'none') return const SlideStroke.none();
    final before = sink.errors.length;
    final stroke = SlideStroke(
      color: readColor(r, 'color'),
      width: r.number('width', min: 0, max: 400),
      dash: r.string('dash', allowed: dashValues),
      cap: r.string('cap', allowed: {'butt', 'round', 'square'}),
      join: r.string('join', allowed: {'miter', 'round', 'bevel'}),
      startArrow: r.string('startArrow', allowed: arrowValues),
      endArrow: r.string('endArrow', allowed: arrowValues),
      arrowSize: r.string('arrowSize', allowed: {'s', 'm', 'l'}),
    );
    return sink.errors.length > before ? null : stroke;
  }

  @override
  bool operator ==(Object other) =>
      other is SlideStroke && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}

/// An outer shadow (02 §5.4 `shadow`).
final class SlideShadow {
  /// Creates a shadow.
  const SlideShadow({
    required this.color,
    this.blur = 24,
    this.dx = 0,
    this.dy = 12,
    this.spread = 0,
  });

  /// Color (usually translucent).
  final ColorRef color;

  /// Blur radius (su).
  final double blur;

  /// Horizontal offset (su).
  final double dx;

  /// Vertical offset (su).
  final double dy;

  /// Spread (su).
  final double spread;

  /// JSON form.
  JsonMap toJson() => {
    'color': color.json,
    'blur': normalizeJsonNumber(blur),
    'dx': normalizeJsonNumber(dx),
    'dy': normalizeJsonNumber(dy),
    if (spread != 0) 'spread': normalizeJsonNumber(spread),
  };

  /// Parses a shadow. Errors → `null`.
  static SlideShadow? fromJson(Object? json, String path, IssueSink sink) {
    final r = JsonReader.object(
      json,
      path,
      sink,
      known: {'color', 'blur', 'dx', 'dy', 'spread'},
    );
    if (r == null) return null;
    final color = readColor(r, 'color', required: true);
    if (color == null) return null;
    return SlideShadow(
      color: color,
      blur: r.number('blur', min: 0, max: 400) ?? 24,
      dx: r.number('dx', min: -400, max: 400) ?? 0,
      dy: r.number('dy', min: -400, max: 400) ?? 12,
      spread: r.number('spread', min: -400, max: 400) ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SlideShadow && jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => canonicalJson(toJson()).hashCode;
}
