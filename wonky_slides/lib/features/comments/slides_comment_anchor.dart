import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart' show CommentAnchorKind;

/// A Slides comment anchor (Slides 09 §3.1):
///
/// | kind | `anchorJson` |
/// |------|--------------|
/// | `slide` | `{"v":1,"slideId":"…","point":{"x":1440,"y":200}?}` — [point] in su |
/// | `element` | `{"v":1,"slideId":"…","elementId":"…","point":{"x":0.9,"y":0.1}?}` — [point] normalized in the element's frame (default top-right) |
/// | `document` | `{"v":1}` |
///
/// The element id is authoritative; the slide id of an element anchor is a
/// hint (the client resolves the element's current slide from the model).
@immutable
class SlidesCommentAnchor {
  const SlidesCommentAnchor.slide(String this.slideId, {this.point})
    : kind = CommentAnchorKind.slide,
      elementId = null;

  const SlidesCommentAnchor.element(
    String this.slideId,
    String this.elementId, {
    this.point,
  }) : kind = CommentAnchorKind.element;

  const SlidesCommentAnchor.document()
    : kind = CommentAnchorKind.document,
      slideId = null,
      elementId = null,
      point = null;

  final CommentAnchorKind kind;
  final String? slideId;
  final String? elementId;

  /// Slide anchors: su on the slide; element anchors: 0…1 in the frame.
  final Offset? point;

  /// The default point of an element pin: the frame's top-right corner.
  static const elementDefaultPoint = Offset(1, 0);

  String encode() => jsonEncode({
    'v': 1,
    'slideId': ?slideId,
    'elementId': ?elementId,
    if (point case final p?) 'point': {'x': _round(p.dx), 'y': _round(p.dy)},
  });

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;

  /// This anchor with [slideId] (the element moved to another slide).
  SlidesCommentAnchor withSlide(String slideId) => switch (kind) {
    CommentAnchorKind.element => SlidesCommentAnchor.element(
      slideId,
      elementId!,
      point: point,
    ),
    _ => SlidesCommentAnchor.slide(slideId, point: point),
  };

  /// This anchor on element [elementId] of [slideId] (cut & paste).
  SlidesCommentAnchor moved({required String slideId, String? elementId}) =>
      elementId != null && kind == CommentAnchorKind.element
      ? SlidesCommentAnchor.element(slideId, elementId, point: point)
      : SlidesCommentAnchor.slide(slideId, point: point);

  /// Parses `anchorJson` of a `slide`, `element` or `document` thread (null
  /// for other kinds and malformed JSON).
  static SlidesCommentAnchor? parse(CommentAnchorKind kind, String json) {
    if (kind == CommentAnchorKind.document) {
      return const SlidesCommentAnchor.document();
    }
    if (kind != CommentAnchorKind.slide && kind != CommentAnchorKind.element) {
      return null;
    }
    try {
      final j = jsonDecode(json);
      if (j is! Map) return null;
      final slide = j['slideId'];
      final element = j['elementId'];
      final p = j['point'];
      final point = p is Map && p['x'] is num && p['y'] is num
          ? Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble())
          : null;
      if (slide is! String) return null;
      if (kind == CommentAnchorKind.slide) {
        return SlidesCommentAnchor.slide(slide, point: point);
      }
      if (element is! String) return null;
      return SlidesCommentAnchor.element(slide, element, point: point);
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SlidesCommentAnchor && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}
