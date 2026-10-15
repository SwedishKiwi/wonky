/// Validator and normalizer of the Wonky Slides Text Schema v1 (02 §4.1,
/// §4.3) under the names of the spec: `SlidesDeltaValidator` reports what
/// is wrong with a stored or incoming body without changing it (MCP
/// arguments, importers, clipboard payloads), `SlidesDeltaNormalizer`
/// returns its canonical, valid form (planner writes, paste mappers). Both
/// sit on `SlidesText` (the schemas, SL-7) and `wonky_rich_text`'s
/// `RichTextNormalizer`.
library;

import 'dart:convert';

import 'package:wonky_rich_text/wonky_rich_text.dart';

import '../model/text/slides_text.dart';
import '../ops/plan_context.dart';

/// One problem of a text body found by [SlidesDeltaValidator].
final class SlidesDeltaIssue {
  /// Creates an issue.
  const SlidesDeltaIssue(this.code, this.message, {this.op, this.attribute});

  /// The JSON is not a list of Delta operations.
  static const notADelta = 'not_a_delta';

  /// A retain or delete in a stored body (documents are inserts only).
  static const notAnInsert = 'not_an_insert';

  /// An embed (images, tables… are elements, not inline content).
  static const embed = 'embed';

  /// The body does not end with `"\n"`.
  static const missingFinalNewline = 'missing_final_newline';

  /// Control characters other than `\n` and U+2028, or a tab.
  static const controlCharacter = 'control_character';

  /// An attribute the schema doesn't know (or on the wrong kind of insert:
  /// a block attribute on text, an inline attribute on `"\n"`).
  static const unknownAttribute = 'unknown_attribute';

  /// A known attribute with a value the schema refuses or would change.
  static const invalidAttribute = 'invalid_attribute';

  /// Empty inserts or adjacent inserts with equal attributes.
  static const notCanonical = 'not_canonical';

  /// More characters than the limit (02 §13).
  static const tooLong = 'too_long';

  /// Machine code (one of the constants above).
  final String code;

  /// English message (MCP `details`).
  final String message;

  /// Index of the operation, when the issue belongs to one.
  final int? op;

  /// The attribute, for attribute issues.
  final String? attribute;

  /// JSON form (`{code, message, op?, attribute?}`).
  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    'op': ?op,
    'attribute': ?attribute,
  };

  @override
  String toString() => 'SlidesDeltaIssue($code: $message)';
}

/// Checks a text body against the Slides text schema (02 §4.1; speaker
/// notes against the subset of §4.3 when [notes]). A body is valid when
/// [validate] returns no issue; a valid body is exactly what
/// [SlidesDeltaNormalizer] returns for it.
final class SlidesDeltaValidator {
  /// Creates a validator. [maxLength] defaults to the limits of 02 §13
  /// (20,000 characters per body, 50,000 for notes).
  SlidesDeltaValidator({this.notes = false, int? maxLength})
    : maxLength =
          maxLength ??
          (notes
              ? SlidesLimits.defaults.maxNotesLength
              : SlidesLimits.defaults.maxTextLength);

  /// Speaker notes schema.
  final bool notes;

  /// Max characters without the final newline.
  final int maxLength;

  RichTextSchema get _schema => SlidesText.schemaFor(notes: notes);

  /// The issues of stored Delta JSON (null = the empty body, valid).
  List<SlidesDeltaIssue> validateJson(String? json) {
    if (json == null) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      return [SlidesDeltaIssue(SlidesDeltaIssue.notADelta, 'Invalid JSON: $e')];
    }
    return validateValue(decoded);
  }

  /// The issues of a decoded Delta value (a JSON list of operations).
  List<SlidesDeltaIssue> validateValue(Object? value) {
    if (value is! List) {
      return const [
        SlidesDeltaIssue(
          SlidesDeltaIssue.notADelta,
          'A text body is a JSON list of insert operations.',
        ),
      ];
    }
    final Delta d;
    try {
      d = Delta.fromJson(value);
    } on Object catch (e) {
      return [
        SlidesDeltaIssue(SlidesDeltaIssue.notADelta, 'Invalid Delta: $e'),
      ];
    }
    return validate(d);
  }

  /// The issues of [body].
  List<SlidesDeltaIssue> validate(Delta body) {
    final issues = <SlidesDeltaIssue>[];
    final schema = _schema;
    var length = 0;
    var last = '';
    for (final (i, op) in body.operations.indexed) {
      if (!op.isInsert) {
        issues.add(
          SlidesDeltaIssue(
            SlidesDeltaIssue.notAnInsert,
            'Text bodies hold inserts only.',
            op: i,
          ),
        );
        continue;
      }
      final data = op.data;
      if (data is! String) {
        issues.add(
          SlidesDeltaIssue(
            SlidesDeltaIssue.embed,
            'Embeds are not allowed in text; images, tables and code are '
            'objects on the slide.',
            op: i,
          ),
        );
        continue;
      }
      if (data.isEmpty) {
        issues.add(
          SlidesDeltaIssue(
            SlidesDeltaIssue.notCanonical,
            'Empty insert.',
            op: i,
          ),
        );
        continue;
      }
      if (RichTextNormalizer.sanitizeText(
            data,
            tabReplacement: schema.tabReplacement,
          ) !=
          data) {
        issues.add(
          SlidesDeltaIssue(
            SlidesDeltaIssue.controlCharacter,
            'Only line breaks (\\n, U+2028) are allowed as control '
            'characters; tabs become spaces.',
            op: i,
          ),
        );
      }
      length += data.length;
      last = data;
      final attrs = op.attributes;
      if (attrs == null || attrs.isEmpty) continue;
      final hasText = data.replaceAll('\n', '').isNotEmpty;
      final hasNewline = data.contains('\n');
      if (hasText && hasNewline) {
        // Inline attributes would apply to the line break and block ones
        // to the text: the normalizer splits such inserts.
        issues.add(
          SlidesDeltaIssue(
            SlidesDeltaIssue.notCanonical,
            'Text and line breaks with attributes must be separate inserts.',
            op: i,
          ),
        );
        continue;
      }
      final allowed = hasText ? schema.inline : schema.block;
      for (final MapEntry(:key, :value) in attrs.entries) {
        final sanitize = allowed[key];
        if (sanitize == null) {
          final known =
              schema.inline.containsKey(key) || schema.block.containsKey(key);
          issues.add(
            SlidesDeltaIssue(
              SlidesDeltaIssue.unknownAttribute,
              known
                  ? '"$key" does not apply to '
                        '${hasText ? 'text' : 'a line break'}.'
                  : 'Unknown attribute "$key".',
              op: i,
              attribute: key,
            ),
          );
          continue;
        }
        final clean = sanitize(value);
        if (clean == null || clean != value) {
          issues.add(
            SlidesDeltaIssue(
              SlidesDeltaIssue.invalidAttribute,
              'Invalid value for "$key": ${jsonEncode(value)}.',
              op: i,
              attribute: key,
            ),
          );
        }
      }
    }
    if (!last.endsWith('\n')) {
      issues.add(
        const SlidesDeltaIssue(
          SlidesDeltaIssue.missingFinalNewline,
          'A text body ends with a line break.',
        ),
      );
    }
    final chars = last.endsWith('\n') ? length - 1 : length;
    if (chars > maxLength) {
      issues.add(
        SlidesDeltaIssue(
          SlidesDeltaIssue.tooLong,
          'A text can have at most $maxLength characters (has $chars).',
        ),
      );
    }
    if (issues.isEmpty && DeltaUtils.canonical(body) != body) {
      issues.add(
        const SlidesDeltaIssue(
          SlidesDeltaIssue.notCanonical,
          'Adjacent inserts with equal attributes must be merged.',
        ),
      );
    }
    return issues;
  }

  /// Whether [body] is valid.
  bool isValid(Delta body) => validate(body).isEmpty;
}

/// The result of [SlidesDeltaNormalizer.normalize].
final class SlidesDeltaNormalized {
  /// Creates a result.
  const SlidesDeltaNormalized(
    this.delta, {
    required this.changed,
    required this.truncated,
  });

  /// The canonical, valid body.
  final Delta delta;

  /// Whether anything was changed.
  final bool changed;

  /// Whether text beyond the length limit was cut.
  final bool truncated;

  /// The body as stored JSON.
  String get json => SlidesText.encode(delta);
}

/// Turns any Delta into a canonical, valid Slides text body (02 §4.1):
/// non-inserts and embeds dropped, control characters removed, tabs → four
/// spaces, unknown or invalid attributes dropped, adjacent equal inserts
/// merged, a final `"\n"` added and text beyond [maxLength] cut.
final class SlidesDeltaNormalizer {
  /// Creates a normalizer ([maxLength] as [SlidesDeltaValidator]).
  SlidesDeltaNormalizer({this.notes = false, int? maxLength})
    : maxLength =
          maxLength ??
          (notes
              ? SlidesLimits.defaults.maxNotesLength
              : SlidesLimits.defaults.maxTextLength);

  /// Speaker notes schema.
  final bool notes;

  /// Max characters without the final newline.
  final int maxLength;

  /// The normalized form of [body].
  SlidesDeltaNormalized normalize(Delta body) {
    final r = RichTextNormalizer(
      SlidesText.schemaFor(notes: notes),
    ).normalize(body);
    var out = r.document;
    var changed = r.changed || DeltaUtils.canonical(body) != body;
    var truncated = false;
    final length = DeltaUtils.documentLength(out) - 1;
    if (length > maxLength) {
      // Keep the first [maxLength] characters and the paragraph attributes
      // of the line the cut falls in.
      final head = out.slice(0, maxLength);
      Map<String, dynamic>? block;
      var pos = 0;
      for (final op in out.operations) {
        final s = op.data is String ? op.data! as String : '';
        final nl = s.indexOf('\n');
        if (nl >= 0 && pos + nl >= maxLength) {
          block = op.attributes;
          break;
        }
        pos += s.length;
      }
      out = DeltaUtils.canonical(head..insert('\n', block));
      changed = true;
      truncated = true;
    }
    return SlidesDeltaNormalized(out, changed: changed, truncated: truncated);
  }

  /// Normalizes stored Delta JSON (null stays null). Malformed JSON throws
  /// [FormatException].
  String? normalizeJson(String? json) {
    if (json == null) return null;
    return normalize(SlidesText.parse(json)).json;
  }

  /// Normalizes a decoded JSON value: a list of operations, or a plain
  /// string (one paragraph per line). Anything else is the empty body.
  SlidesDeltaNormalized normalizeValue(Object? value) {
    if (value is String) return normalize(fromPlainText(value, lists: false));
    if (value is List) {
      try {
        return normalize(Delta.fromJson(value));
      } on Object {
        // Falls through to the empty body.
      }
    }
    return SlidesDeltaNormalized(
      Delta()..insert('\n'),
      changed: true,
      truncated: false,
    );
  }

  static final _bullet = RegExp(r'^(\s*)[-*•]\s+');
  static final _ordered = RegExp(r'^(\s*)\d{1,4}[.)]\s+');

  /// A body from plain text (03 §12.5): one paragraph per line (`\r\n`,
  /// `\r` → `\n`); with [lists], lines starting with `- `, `* `, `• ` become
  /// bullets and `1. ` / `1) ` numbered items, two leading spaces per
  /// indent level. Not normalized (call [normalize]).
  Delta fromPlainText(String text, {bool lists = true}) {
    final d = Delta();
    final lines = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
    for (final line in lines) {
      var content = line;
      Map<String, dynamic>? block;
      if (lists) {
        final b = _bullet.firstMatch(line);
        final o = b == null ? _ordered.firstMatch(line) : null;
        final m = b ?? o;
        if (m != null) {
          final indent = (m.group(1)!.replaceAll('\t', '  ').length ~/ 2).clamp(
            0,
            8,
          );
          content = line.substring(m.end);
          block = {
            'list': b != null ? 'bullet' : 'ordered',
            'indent': ?(indent > 0 ? indent : null),
          };
        }
      }
      if (content.isNotEmpty) d.insert(content);
      d.insert('\n', block);
    }
    return d;
  }
}
