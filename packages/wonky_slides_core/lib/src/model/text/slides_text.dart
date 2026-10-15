/// Wonky Slides Text Schema v1 (02 §4.1, §4.3) on the shared
/// `RichTextNormalizer` of `wonky_rich_text`: the attributes text bodies
/// and speaker notes may carry, canonical normalization of stored Delta
/// JSON, plain text and range formatting. Used by the planner before every
/// write (client and server) and by renderers.
library;

import 'dart:convert';

import 'package:wonky_rich_text/wonky_rich_text.dart';

import '../../theme/color/color_ref.dart';

/// The Slides rich-text schemas and helpers (02 §4).
abstract final class SlidesText {
  /// Theme text style keys a paragraph `style` may name (02 §4.1).
  static const styleKeys = {
    'title',
    'subtitle',
    'heading',
    'body',
    'body2',
    'caption',
    'quote',
    'attribution',
    'bigNumber',
    'label',
  };

  static const _bullets = {
    'disc',
    'circle',
    'square',
    'dash',
    'arrow',
    'check',
    'star',
    'none',
    'decimal',
    'lowerAlpha',
    'upperAlpha',
    'lowerRoman',
    'upperRoman',
  };

  static Object? _color(Object? v) =>
      v is String && ColorRef.tryParse(v) != null ? v : null;

  static Object? _weight(Object? v) {
    if (v is! num || !v.isFinite) return null;
    return ((v / 100).round() * 100).clamp(100, 900);
  }

  static Object? _listStyle(Object? v) {
    if (v is! String) return null;
    if (_bullets.contains(v)) return v;
    if (v.startsWith('emoji:') && v.length > 6 && v.length <= 16) return v;
    return null;
  }

  static final _slideLink = RegExp(r'^slide:[0-9A-Za-z]{22}$');

  /// A `link` value of 02 §4.1 (`https://…`, `mailto:`, `slide:<b62>`,
  /// `wonky://…`), canonicalized; null when not allowed.
  static Object? link(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    if (_slideLink.hasMatch(t)) return t;
    final n = LinkPolicy.normalizeLink(t);
    if (n == null) return null;
    if (n.startsWith('https://') ||
        n.startsWith('mailto:') ||
        n.startsWith('wonky://')) {
      return n;
    }
    return null;
  }

  /// Inline attributes of text boxes, shapes, placeholders and cells.
  static final RichTextSchema bodySchema = RichTextSchema(
    inline: {
      'bold': RichTextSchema.trueOnly,
      'italic': RichTextSchema.trueOnly,
      'underline': RichTextSchema.trueOnly,
      'strike': RichTextSchema.trueOnly,
      'code': RichTextSchema.trueOnly,
      'font': RichTextSchema.string(maxLength: 64),
      'weight': _weight,
      'size': RichTextSchema.numIn(6, 800),
      'color': _color,
      'highlight': _color,
      'script': RichTextSchema.oneOf({'super', 'sub'}),
      'caps': RichTextSchema.oneOf({'all', 'small', 'title'}),
      'letterSpacing': RichTextSchema.numIn(-0.2, 1),
      'link': link,
    },
    block: {
      'style': RichTextSchema.oneOf(styleKeys),
      'align': RichTextSchema.oneOf({'left', 'center', 'right', 'justify'}),
      'list': RichTextSchema.oneOf({'bullet', 'ordered', 'check', 'unchecked'}),
      'listStyle': _listStyle,
      'listStart': RichTextSchema.intIn(0, 100000),
      'indent': RichTextSchema.intIn(0, 8),
      'lineHeight': RichTextSchema.numIn(0.7, 3),
      'spaceBefore': RichTextSchema.numIn(0, 400),
      'spaceAfter': RichTextSchema.numIn(0, 400),
      'dir': RichTextSchema.oneOf({'rtl'}),
    },
  );

  /// Speaker notes (02 §4.3): a subset of [bodySchema].
  static final RichTextSchema notesSchema = RichTextSchema(
    inline: {
      'bold': RichTextSchema.trueOnly,
      'italic': RichTextSchema.trueOnly,
      'underline': RichTextSchema.trueOnly,
      'strike': RichTextSchema.trueOnly,
      'link': link,
      'highlight': _color,
    },
    block: {
      'list': RichTextSchema.oneOf({'bullet', 'ordered'}),
      'indent': RichTextSchema.intIn(0, 8),
    },
  );

  /// The schema of a body ([notes] = speaker notes).
  static RichTextSchema schemaFor({bool notes = false}) =>
      notes ? notesSchema : bodySchema;

  /// Whether [key] is a block (paragraph) attribute of the body schema.
  static bool isBlockAttribute(String key) => bodySchema.block.containsKey(key);

  /// Parses stored Delta JSON (null = empty body `"\n"`). Throws
  /// [FormatException] when the JSON is not a Delta.
  static Delta parse(String? json) {
    if (json == null || json.isEmpty) return Delta()..insert('\n');
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      rethrow;
    }
    if (decoded is! List) {
      throw const FormatException('A text body is a JSON list of ops.');
    }
    try {
      return Delta.fromJson(decoded);
    } on Object catch (e) {
      throw FormatException('Invalid Delta: $e');
    }
  }

  /// Encodes a Delta as stored JSON.
  static String encode(Delta d) => jsonEncode(d.toJson());

  /// The canonical, valid form of [d] under the schema.
  static Delta normalize(Delta d, {bool notes = false}) =>
      RichTextNormalizer(schemaFor(notes: notes)).normalize(d).document;

  /// Normalizes stored Delta JSON; null stays null. Throws
  /// [FormatException] for malformed JSON.
  static String? normalizeJson(String? json, {bool notes = false}) {
    if (json == null) return null;
    return encode(normalize(parse(json), notes: notes));
  }

  /// The plain text of a body (with the final `"\n"`).
  static String plainText(String? json) {
    if (json == null) return '';
    try {
      final b = StringBuffer();
      for (final op in parse(json).operations) {
        final d = op.data;
        if (op.isInsert && d is String) b.write(d);
      }
      return b.toString();
    } on FormatException {
      return '';
    }
  }

  /// The number of characters of a body, without the final `"\n"` (02 §13).
  static int lengthOf(String? json) {
    final t = plainText(json);
    return t.endsWith('\n') ? t.length - 1 : t.length;
  }

  /// Whether a body holds no visible text.
  static bool isBlank(String? json) => plainText(json).trim().isEmpty;

  /// Applies [attributes] (null values remove) to [doc]: inline attributes
  /// to the characters of `[start, start + length)` (whole body when null),
  /// block attributes to every paragraph overlapping it. The result is
  /// normalized.
  static Delta format(
    Delta doc,
    Map<String, Object?> attributes, {
    int? start,
    int? length,
    bool notes = false,
  }) {
    final schema = schemaFor(notes: notes);
    final text = StringBuffer();
    for (final op in doc.operations) {
      if (op.isInsert && op.data is String) text.write(op.data);
    }
    final plain = text.toString();
    final total = plain.length;
    final from = (start ?? 0).clamp(0, total);
    final to = (length == null ? total : from + length).clamp(from, total);
    final inline = <String, dynamic>{
      for (final e in attributes.entries)
        if (schema.inline.containsKey(e.key)) e.key: e.value,
    };
    final block = <String, dynamic>{
      for (final e in attributes.entries)
        if (schema.block.containsKey(e.key)) e.key: e.value,
    };
    var out = doc;
    if (inline.isNotEmpty && to > from) {
      final change = Delta()
        ..retain(from)
        ..retain(to - from, inline);
      out = out.compose(change);
    }
    if (block.isNotEmpty) {
      // The newline ending each paragraph that overlaps [from, to).
      final newlines = <int>[];
      var paraStart = 0;
      for (var i = 0; i < plain.length; i++) {
        if (plain.codeUnitAt(i) != 0x0A) continue;
        final overlaps = to > from
            ? paraStart < to && i >= from
            : from >= paraStart && from <= i;
        if (overlaps) newlines.add(i);
        paraStart = i + 1;
      }
      if (newlines.isNotEmpty) {
        final change = Delta();
        var pos = 0;
        for (final n in newlines) {
          if (n > pos) change.retain(n - pos);
          change.retain(1, block);
          pos = n + 1;
        }
        out = out.compose(change);
      }
    }
    return normalize(out, notes: notes);
  }
}
