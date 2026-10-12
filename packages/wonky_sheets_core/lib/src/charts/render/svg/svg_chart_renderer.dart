import 'dart:math' as math;

import '../../scene/path.dart';
import '../../scene/scene.dart';
import '../render_geometry.dart';

/// Renders a [ChartScene] as a standalone SVG 1.1 document (08 §13: SVG download).
///
/// Text is emitted as `<text>` elements with the style's font family first, followed by
/// [fontFamilyFallback]. Output is deterministic: numbers are rounded to at most 2 decimals and
/// clip ids are numbered in paint order with [idPrefix].
final class SvgChartRenderer {
  /// Creates a renderer.
  const SvgChartRenderer({
    this.fontFamilyFallback = "Inter, 'Helvetica Neue', Arial, sans-serif",
    this.idPrefix = 'wc',
  });

  /// CSS font-family list appended after the text style's own family.
  final String fontFamilyFallback;

  /// Prefix of generated element ids (clip paths), so several charts can share a page.
  final String idPrefix;

  /// The SVG document for [scene].
  String render(ChartScene scene) => _SvgWriter(this).write(scene);

  /// Deterministic number format: at most 2 decimals, no trailing zeros, `0` for -0, NaN and
  /// infinities.
  static String formatNumber(double v) {
    if (!v.isFinite) return '0';
    final clamped = v.clamp(-1e12, 1e12);
    final hundredths = (clamped * 100).round();
    if (hundredths == 0) return '0';
    if (hundredths % 100 == 0) return '${hundredths ~/ 100}';
    var s = (hundredths / 100).toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }
}

final class _SvgWriter {
  _SvgWriter(this.renderer);

  final SvgChartRenderer renderer;
  final StringBuffer _b = StringBuffer();
  int _clipCount = 0;
  int _depth = 1;

  static String _n(double v) => SvgChartRenderer.formatNumber(v);

  String write(ChartScene scene) {
    final w = _n(scene.width), h = _n(scene.height);
    _b
      ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..write('<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="$w" height="$h" ')
      ..write('viewBox="0 0 $w $h">\n');
    if (RenderGeometry.fillVisible(scene.background)) {
      _line('<rect x="0" y="0" width="$w" height="$h"${_fill(scene.background)}/>');
    }
    _list(scene.primitives);
    _b.write('</svg>\n');
    return _b.toString();
  }

  void _line(String s) {
    for (var i = 0; i < _depth; i++) {
      _b.write('  ');
    }
    _b
      ..write(s)
      ..write('\n');
  }

  void _list(List<ScenePrimitive> list) {
    for (final p in list) {
      _primitive(p);
    }
  }

  void _primitive(ScenePrimitive p) {
    switch (p) {
      case SRect():
        _rect(p);
      case SPath(:final cmds, :final fill, :final stroke, :final evenOdd):
        final d = _pathData(cmds);
        if (d.isEmpty) return;
        final rule = evenOdd ? ' fill-rule="evenodd"' : '';
        _line('<path d="$d"$rule${_fill(fill)}${_stroke(stroke)}/>');
      case SPolyline(:final xy, :final stroke):
        if (xy.length < 2) return;
        final pts = StringBuffer();
        for (var i = 0; i + 1 < xy.length; i += 2) {
          if (i > 0) pts.write(' ');
          pts
            ..write(_n(xy[i]))
            ..write(',')
            ..write(_n(xy[i + 1]));
        }
        _line('<polyline points="$pts" fill="none"${_stroke(stroke)}/>');
      case SMarkers():
        _markers(p);
      case SArc():
        final d = _pathData(p.toPath());
        if (d.isEmpty) return;
        final rule = p.isFullCircle && p.innerRadius > 0 ? ' fill-rule="evenodd"' : '';
        _line('<path d="$d"$rule${_fill(p.fill)}${_stroke(p.stroke)}/>');
      case SText():
        _text(p);
      case SClip(:final rect, :final children):
        final r = RenderGeometry.normalize(rect);
        final id = '${renderer.idPrefix}-clip-${++_clipCount}';
        _line('<defs>');
        _depth++;
        _line('<clipPath id="$id">');
        _depth++;
        _line(
          '<rect x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
          'height="${_n(r.height)}"/>',
        );
        _depth--;
        _line('</clipPath>');
        _depth--;
        _line('</defs>');
        _line('<g clip-path="url(#$id)">');
        _depth++;
        _list(children);
        _depth--;
        _line('</g>');
      case SGroup(:final children, :final opacity):
        if (!(opacity > 0)) return;
        _line(opacity >= 1 ? '<g>' : '<g opacity="${_n(opacity)}">');
        _depth++;
        _list(children);
        _depth--;
        _line('</g>');
    }
  }

  void _rect(SRect p) {
    final r = RenderGeometry.normalize(p.rect);
    final radius = RenderGeometry.clampRadius(r, p.radius);
    final rr = radius > 0 ? ' rx="${_n(radius)}" ry="${_n(radius)}"' : '';
    _line(
      '<rect x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
      'height="${_n(r.height)}"$rr${_fill(p.fill)}${_stroke(p.stroke)}/>',
    );
  }

  void _markers(SMarkers p) {
    if (p.length == 0) return;
    final shared = p.fills == null ? _fill(p.fill) : '';
    _line('<g$shared${_stroke(p.stroke)}>');
    _depth++;
    for (var k = 0; k < p.length; k++) {
      final x = p.xy[2 * k], y = p.xy[2 * k + 1];
      final size = p.sizeOf(k);
      if (!(size > 0) || !x.isFinite || !y.isFinite) continue;
      final fill = p.fills == null ? '' : _fill(p.fillOf(k));
      final r = size / 2;
      switch (p.shape) {
        case MarkerShape.circle:
          _line('<circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(r)}"$fill/>');
        case MarkerShape.square:
          _line(
            '<rect x="${_n(x - r)}" y="${_n(y - r)}" width="${_n(size)}" '
            'height="${_n(size)}"$fill/>',
          );
        default:
          final d = _pathData(RenderGeometry.markerPath(p.shape, x, y, size));
          _line('<path d="$d"$fill/>');
      }
    }
    _depth--;
    _line('</g>');
  }

  void _text(SText p) {
    final text = _escapeText(p.text);
    if (text.isEmpty) return;
    final s = p.style;
    final attrs = StringBuffer()
      ..write('x="${_n(p.at.x)}" y="${_n(p.at.y)}"')
      ..write(' font-family="${_escapeAttr(_fontFamily(s.family))}"')
      ..write(' font-size="${_n(s.size)}"');
    if (s.bold) attrs.write(' font-weight="bold"');
    if (s.italic) attrs.write(' font-style="italic"');
    attrs.write(_fill(s.color));
    final anchor = p.anchor.hFactor <= 0.25 ? null : (p.anchor.hFactor >= 0.75 ? 'end' : 'middle');
    if (anchor != null) attrs.write(' text-anchor="$anchor"');
    if (!p.anchor.isBaseline) {
      if (p.height > 0) {
        final ascent = p.ascent > 0 ? p.ascent : p.height * 0.8;
        final (_, dy) = p.anchor.baselineOrigin(p.width, p.height, ascent);
        final dys = _n(dy);
        if (dys != '0') attrs.write(' dy="$dys"');
      } else {
        // No layout metrics: let the SVG user agent place the baseline.
        final baseline = p.anchor.isTop
            ? 'text-before-edge'
            : (p.anchor.isMiddle ? 'central' : 'text-after-edge');
        attrs.write(' dominant-baseline="$baseline"');
      }
    }
    if (p.angle != 0 && p.angle.isFinite) {
      final deg = _n(p.angle * 180 / math.pi);
      if (deg != '0') attrs.write(' transform="rotate($deg ${_n(p.at.x)} ${_n(p.at.y)})"');
    }
    if (p.text.startsWith(' ') || p.text.endsWith(' ') || p.text.contains('  ')) {
      attrs.write(' xml:space="preserve"');
    }
    _line('<text $attrs>$text</text>');
  }

  String _fontFamily(String? family) {
    final f = family?.replaceAll(RegExp('["\'<>&;]'), '').trim() ?? '';
    if (f.isEmpty) return renderer.fontFamilyFallback;
    final quoted = RegExp(r'^[A-Za-z][A-Za-z0-9-]*$').hasMatch(f) ? f : "'$f'";
    return '$quoted, ${renderer.fontFamilyFallback}';
  }

  static String _fill(int? argb) {
    if (!RenderGeometry.fillVisible(argb)) return ' fill="none"';
    final a = Argb.alpha(argb!);
    final op = a < 255 ? ' fill-opacity="${_n(a / 255)}"' : '';
    return ' fill="${Argb.rgbHex(argb).toLowerCase()}"$op';
  }

  static String _stroke(SStroke? s) {
    if (!RenderGeometry.strokeVisible(s)) return '';
    final b = StringBuffer(' stroke="${Argb.rgbHex(s!.color).toLowerCase()}"');
    final a = Argb.alpha(s.color);
    if (a < 255) b.write(' stroke-opacity="${_n(a / 255)}"');
    b.write(' stroke-width="${_n(s.width)}"');
    final dash = RenderGeometry.effectiveDash(s.dash);
    if (dash != null) b.write(' stroke-dasharray="${dash.map(_n).join(' ')}"');
    switch (s.cap) {
      case SStrokeCap.butt:
        break;
      case SStrokeCap.round:
        b.write(' stroke-linecap="round"');
      case SStrokeCap.square:
        b.write(' stroke-linecap="square"');
    }
    switch (s.join) {
      case SStrokeJoin.miter:
        break;
      case SStrokeJoin.round:
        b.write(' stroke-linejoin="round"');
      case SStrokeJoin.bevel:
        b.write(' stroke-linejoin="bevel"');
    }
    return b.toString();
  }

  static String _pathData(List<PathCmd> cmds) {
    final b = StringBuffer();
    for (final c in cmds) {
      if (b.isNotEmpty) b.write(' ');
      switch (c) {
        case PMoveTo(:final x, :final y):
          b.write('M${_n(x)} ${_n(y)}');
        case PLineTo(:final x, :final y):
          b.write('L${_n(x)} ${_n(y)}');
        case PCubicTo(:final x1, :final y1, :final x2, :final y2, :final x, :final y):
          b.write('C${_n(x1)} ${_n(y1)} ${_n(x2)} ${_n(y2)} ${_n(x)} ${_n(y)}');
        case PClose():
          b.write('Z');
      }
    }
    return b.toString();
  }

  static final RegExp _invalidXml = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]');

  static String _escapeText(String s) => s
      .replaceAll(_invalidXml, '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('\n', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\t', ' ');

  static String _escapeAttr(String s) => s
      .replaceAll(_invalidXml, '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('"', '&quot;');
}
