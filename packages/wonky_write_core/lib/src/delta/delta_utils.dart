/// General Delta helpers: canonical form, lengths, builders.
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'attributes.dart';

/// Character used for embeds in addressing plain text (U+FFFC).
const embedChar = '\uFFFC';

/// Soft line break inside a line (U+2028).
const softBreak = '\u2028';

/// Helpers on [Delta]s that complement `dart_quill_delta`.
abstract final class DeltaUtils {
  /// Returns the canonical form of [delta]: no empty ops, empty attribute
  /// maps dropped, adjacent ops of the same kind and attributes merged,
  /// inserts placed before adjacent deletes and no trailing plain retain.
  ///
  /// `dart_quill_delta` 9.x does not merge an insert pushed after a delete
  /// with the insert before that delete, so composed/transformed deltas are
  /// not always canonical; compare deltas through this function.
  static Delta canonical(Delta delta) {
    final ops = <Operation>[];

    void pushOne(Operation op) {
      if (ops.isNotEmpty) {
        final last = ops.last;
        if (last.key == op.key &&
            Attributes.equals(last.attributes, op.attributes)) {
          if (op.isInsert) {
            if (last.data is String && op.data is String) {
              final text = (last.data as String) + (op.data as String);
              ops[ops.length - 1] = Operation.insert(text, last.attributes);
              return;
            }
          } else {
            ops[ops.length - 1] = op.isDelete
                ? Operation.delete(last.length! + op.length!)
                : Operation.retain(last.length! + op.length!, last.attributes);
            return;
          }
        }
      }
      ops.add(op);
    }

    for (final raw in delta.operations) {
      if (raw.length == null || raw.length! <= 0) continue;
      if (raw.isInsert && raw.data is String && (raw.data as String).isEmpty) {
        continue;
      }
      final attrs = Attributes.orNull(raw.attributes);
      final op = raw.isInsert
          ? Operation.insert(raw.data, attrs)
          : raw.isDelete
          ? Operation.delete(raw.length!)
          : Operation.retain(raw.length!, attrs);
      if (op.isInsert && ops.isNotEmpty && ops.last.isDelete) {
        final del = ops.removeLast();
        pushOne(op);
        pushOne(del);
      } else {
        pushOne(op);
      }
    }
    while (ops.isNotEmpty && ops.last.isRetain && ops.last.isPlain) {
      ops.removeLast();
    }
    return Delta.fromOperations(ops);
  }

  /// Whether two deltas are equal in canonical form.
  static bool equals(Delta a, Delta b) => canonical(a) == canonical(b);

  /// Whether [delta] contains only inserts (a document delta).
  static bool isDocument(Delta delta) =>
      delta.operations.every((o) => o.isInsert);

  /// Total length of a document delta (embeds count 1).
  static int documentLength(Delta document) {
    var n = 0;
    for (final op in document.operations) {
      if (op.isInsert) n += op.length!;
    }
    return n;
  }

  /// Length of the document a change applies to (`retain` + `delete`).
  static int baseLength(Delta change) {
    var n = 0;
    for (final op in change.operations) {
      if (!op.isInsert) n += op.length!;
    }
    return n;
  }

  /// Length change caused by [change] (`insert` − `delete`).
  static int lengthDelta(Delta change) {
    var n = 0;
    for (final op in change.operations) {
      if (op.isInsert) n += op.length!;
      if (op.isDelete) n -= op.length!;
    }
    return n;
  }

  /// Whether [change] is a no-op (empty after canonicalization).
  static bool isNoop(Delta change) => canonical(change).isEmpty;

  /// Concatenates document [parts] (canonical).
  static Delta concatAll(Iterable<Delta> parts) {
    final result = Delta();
    for (final p in parts) {
      for (final op in p.operations) {
        result.push(op);
      }
    }
    return canonical(result);
  }

  /// Builds a change that retains [offset], then applies [ops]
  /// (inserts/deletes/retains), as one canonical change delta.
  static Delta at(int offset, void Function(Delta d) ops) {
    final d = Delta();
    if (offset > 0) d.retain(offset);
    ops(d);
    return canonical(d);
  }

  /// A change that applies [attributes] to `[start, start + length)`.
  static Delta format(int start, int length, Map<String, dynamic> attributes) =>
      at(start, (d) => d.retain(length, attributes));

  /// A change that deletes `[start, start + length)`.
  static Delta deleteRange(int start, int length) =>
      at(start, (d) => d.delete(length));

  /// A change that inserts the document fragment [fragment] at [offset].
  static Delta insertAt(int offset, Delta fragment) => at(offset, (d) {
    for (final op in fragment.operations) {
      d.push(op);
    }
  });

  /// Plain text of a document delta with embeds as [embedChar] (1 code unit
  /// each), so string offsets equal Delta offsets.
  static String text(Delta document) {
    final b = StringBuffer();
    for (final op in document.operations) {
      if (!op.isInsert) continue;
      final data = op.data;
      b.write(data is String ? data : embedChar);
    }
    return b.toString();
  }

  /// Removes all attributes for which [drop] returns true from every op of
  /// [delta] (used to strip overlays: `cmt_*`/`sug_*`).
  static Delta mapAttributes(
    Delta delta,
    Map<String, dynamic>? Function(Map<String, dynamic>? attributes) f,
  ) {
    final result = Delta();
    for (final op in delta.operations) {
      final attrs = op.isDelete ? null : Attributes.orNull(f(op.attributes));
      if (op.isInsert) {
        result.push(Operation.insert(op.data, attrs));
      } else if (op.isRetain) {
        result.push(Operation.retain(op.length, attrs));
      } else {
        result.push(op);
      }
    }
    return canonical(result);
  }

  /// [document] without `cmt_*`/`sug_*` attributes.
  static Delta stripOverlays(Delta document) =>
      mapAttributes(document, Attributes.withoutOverlays);

  /// [document] without `cmt_*` attributes.
  static Delta stripComments(Delta document) => mapAttributes(
    document,
    (a) => {
      for (final e in (a ?? const <String, dynamic>{}).entries)
        if (!WonkyAttr.isComment(e.key)) e.key: e.value,
    },
  );

  /// Whether position [offset] in [text] lies between the two halves of a
  /// surrogate pair.
  static bool isInsideSurrogatePair(String text, int offset) {
    if (offset <= 0 || offset >= text.length) return false;
    final before = text.codeUnitAt(offset - 1);
    final after = text.codeUnitAt(offset);
    return before >= 0xD800 &&
        before <= 0xDBFF &&
        after >= 0xDC00 &&
        after <= 0xDFFF;
  }
}
