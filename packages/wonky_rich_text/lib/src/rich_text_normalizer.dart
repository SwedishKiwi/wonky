/// Schema-parameterized normalization of embed-free rich text bodies
/// (Slides 02 §4.1; the building block of `SlidesDeltaNormalizer`).
///
/// Write keeps its own `WonkyDeltaNormalizer` (embeds, overlays, tables and
/// the fix-up change for OT, Write 02 §1.4); it shares [TextRules] and
/// [DeltaUtils.canonical] with this one.
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'delta_utils.dart';
import 'text_rules.dart';

/// Sanitizes one attribute value: returns the value to keep (possibly
/// rewritten, e.g. clamped or canonicalized) or `null` to drop the key.
typedef RichTextAttributeSanitizer = Object? Function(Object? value);

/// The attributes a rich text body may carry.
final class RichTextSchema {
  /// Creates a schema. Keys missing from [inline] / [block] are dropped.
  const RichTextSchema({
    this.inline = const {},
    this.block = const {},
    this.tabReplacement = '    ',
  });

  /// Attributes allowed on text inserts, with their sanitizers.
  final Map<String, RichTextAttributeSanitizer> inline;

  /// Attributes allowed on the `"\n"` that ends a paragraph.
  final Map<String, RichTextAttributeSanitizer> block;

  /// What a tab becomes (`null` keeps tabs).
  final String? tabReplacement;

  /// Keeps `true` only (`bold: true`).
  static Object? trueOnly(Object? value) => value == true ? true : null;

  /// Keeps a value from [allowed].
  static RichTextAttributeSanitizer oneOf(Set<Object> allowed) =>
      (value) => value != null && allowed.contains(value) ? value : null;

  /// Keeps an integer clamped to `[min, max]` (numbers are rounded).
  static RichTextAttributeSanitizer intIn(int min, int max) => (value) {
    if (value is! num || !value.isFinite) return null;
    return value.round().clamp(min, max);
  };

  /// Keeps a number clamped to `[min, max]`.
  static RichTextAttributeSanitizer numIn(num min, num max) => (value) {
    if (value is! num || !value.isFinite) return null;
    return value.clamp(min, max);
  };

  /// Keeps a non-empty string of at most [maxLength] characters.
  static RichTextAttributeSanitizer string({int maxLength = 256}) =>
      (value) =>
          value is String && value.isNotEmpty && value.length <= maxLength
          ? value
          : null;
}

/// The result of [RichTextNormalizer.normalize].
final class RichTextNormalizeResult {
  /// Creates a result.
  const RichTextNormalizeResult(this.document, {required this.changed});

  /// The canonical, valid document (inserts only, ends with `"\n"`).
  final Delta document;

  /// Whether anything other than op structure was changed (characters,
  /// attributes, ops that are not text inserts, the trailing newline).
  final bool changed;
}

/// Normalizes a rich text body to its canonical form under a
/// [RichTextSchema]:
///
/// - only text inserts are kept (retains, deletes and embeds are dropped);
/// - lone surrogates and forbidden characters ([TextRules.isForbiddenUnit])
///   are removed, `\r\n`/`\r` become `\n`, U+2029 becomes the soft break
///   U+2028, tabs become [RichTextSchema.tabReplacement];
/// - text carries only the schema's inline attributes, each `"\n"` only its
///   block attributes (sanitized; invalid values are dropped);
/// - the body ends with `"\n"` (an empty body is `"\n"`);
/// - adjacent inserts with equal attributes are merged
///   ([DeltaUtils.canonical]).
///
/// `normalize` is idempotent.
final class RichTextNormalizer {
  /// Creates a normalizer for [schema].
  const RichTextNormalizer(this.schema);

  /// The allowed attributes.
  final RichTextSchema schema;

  /// Normalizes [body].
  RichTextNormalizeResult normalize(Delta body) {
    final out = Delta();
    var changed = false;
    var endsWithNewline = false;
    for (final op in body.operations) {
      if (!op.isInsert || op.data is! String) {
        changed = true;
        continue;
      }
      final raw = op.data as String;
      final text = sanitizeText(raw, tabReplacement: schema.tabReplacement);
      if (text != raw) changed = true;
      if (text.isEmpty) continue;
      final attrs = op.attributes;
      final inline = _sanitize(attrs, schema.inline);
      final block = _sanitize(attrs, schema.block);
      // An attribute is valid if it survives on the part it applies to.
      var start = 0;
      for (var i = 0; i < text.length; i++) {
        if (text.codeUnitAt(i) != 0x0A) continue;
        if (i > start) {
          out.insert(text.substring(start, i), inline);
          if (!_sameKeys(attrs, inline)) changed = true;
        }
        out.insert('\n', block);
        if (!_sameKeys(attrs, block)) changed = true;
        start = i + 1;
      }
      if (start < text.length) {
        out.insert(text.substring(start), inline);
        if (!_sameKeys(attrs, inline)) changed = true;
        endsWithNewline = false;
      } else {
        endsWithNewline = true;
      }
    }
    if (!endsWithNewline) {
      out.insert('\n');
      changed = true;
    }
    return RichTextNormalizeResult(DeltaUtils.canonical(out), changed: changed);
  }

  /// Whether [body] is already normalized (canonical and valid).
  bool isNormalized(Delta body) {
    final result = normalize(body);
    return !result.changed && DeltaUtils.canonical(body) == body;
  }

  /// [text] with the character rules applied: lone surrogates and
  /// forbidden units removed, `\r\n`/`\r` → `\n`, U+2029 → U+2028, tabs →
  /// [tabReplacement] (kept when `null`).
  static String sanitizeText(String text, {String? tabReplacement = '    '}) {
    var clean = TextRules.firstLoneSurrogate(text) < 0;
    for (var i = 0; clean && i < text.length; i++) {
      final u = text.codeUnitAt(i);
      if (u == 0x0D ||
          u == 0x2029 ||
          (u == 0x09 && tabReplacement != null) ||
          (u != 0x09 && TextRules.isForbiddenUnit(u))) {
        clean = false;
      }
    }
    if (clean) return text;
    final b = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final u = text.codeUnitAt(i);
      if (u >= 0xD800 && u <= 0xDBFF) {
        if (i + 1 < text.length) {
          final n = text.codeUnitAt(i + 1);
          if (n >= 0xDC00 && n <= 0xDFFF) {
            b.writeCharCode(u);
            b.writeCharCode(n);
            i++;
          }
        }
        continue;
      }
      if (u >= 0xDC00 && u <= 0xDFFF) continue;
      if (u == 0x0D) {
        b.write('\n');
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) i++;
        continue;
      }
      if (u == 0x2029) {
        b.write(softBreak);
        continue;
      }
      if (u == 0x09) {
        b.write(tabReplacement ?? '\t');
        continue;
      }
      if (TextRules.isForbiddenUnit(u)) continue;
      b.writeCharCode(u);
    }
    return b.toString();
  }

  static Map<String, dynamic>? _sanitize(
    Map<String, dynamic>? attrs,
    Map<String, RichTextAttributeSanitizer> allowed,
  ) {
    if (attrs == null || attrs.isEmpty) return null;
    final out = <String, dynamic>{};
    for (final MapEntry(:key, :value) in attrs.entries) {
      final sanitize = allowed[key];
      if (sanitize == null) continue;
      final v = sanitize(value);
      if (v != null) out[key] = v;
    }
    return out.isEmpty ? null : out;
  }

  /// Whether sanitizing kept every key with an unchanged value.
  static bool _sameKeys(
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  ) {
    final a = before ?? const <String, dynamic>{};
    final b = after ?? const <String, dynamic>{};
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      if (!b.containsKey(key) || b[key] != value) return false;
    }
    return true;
  }
}
