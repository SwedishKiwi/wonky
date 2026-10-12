/// Minimal document diffs that preserve overlays (09 §2.2 `replace_range`,
/// `set_markdown`; 08 §4.5 restore).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:diff_match_patch/diff_match_patch.dart' as dmp;

import 'attributes.dart';
import 'delta_utils.dart';

/// Document diffs.
abstract final class DeltaDiff {
  /// The change turning document [a] into document [b] (both inserts only).
  ///
  /// Unlike `Delta.diff` from `dart_quill_delta` 9.x, equal embeds (deep
  /// equality) are retained instead of replaced, and attribute changes are
  /// expressed as retains. When [ignoreOverlays] is true, `cmt_*`/`sug_*`
  /// attributes are ignored on both sides, so applying the result to the
  /// original [a] keeps comment anchors and suggestions on unchanged text.
  static Delta diff(Delta a, Delta b, {bool ignoreOverlays = false}) {
    final left = ignoreOverlays ? DeltaUtils.stripOverlays(a) : DeltaUtils.canonical(a);
    final right = ignoreOverlays ? DeltaUtils.stripOverlays(b) : DeltaUtils.canonical(b);
    if (left == right) return Delta();

    // Map embeds to private-use characters so equal embeds compare equal.
    final embedCodes = <String, int>{};
    String encode(Delta d) {
      final buf = StringBuffer();
      for (final op in d.operations) {
        final data = op.data;
        if (data is String) {
          buf.write(data);
        } else {
          final key = canonicalEmbedKey(data);
          final code = embedCodes.putIfAbsent(key, () => 0xF0000 + embedCodes.length);
          buf.writeCharCode(code);
        }
      }
      return buf.toString();
    }

    final textA = encode(left);
    final textB = encode(right);
    final diffs = dmp.diff(textA, textB, timeout: 2.0);
    dmp.DiffMatchPatch().diffCleanupSemantic(diffs);

    final result = Delta();
    final itA = DeltaIterator(left);
    final itB = DeltaIterator(right);
    for (final d in diffs) {
      // Lengths in Delta units: supplementary-plane placeholders are 2 code
      // units in the string but 1 in the Delta.
      var length = _deltaLength(d.text);
      while (length > 0) {
        switch (d.operation) {
          case dmp.DIFF_INSERT:
            final op = itB.next(length);
            result.push(Operation.insert(op.data, op.attributes));
            length -= op.length!;
          case dmp.DIFF_DELETE:
            final op = itA.next(length);
            result.delete(op.length!);
            length -= op.length!;
          default:
            final n = [itA.peekLength(), itB.peekLength(), length].reduce((x, y) => x < y ? x : y);
            final opA = itA.next(n);
            final opB = itB.next(n);
            result.retain(n, Attributes.orNull(Attributes.diff(opA.attributes, opB.attributes)));
            length -= n;
        }
      }
    }
    return DeltaUtils.canonical(result);
  }

  /// Delta length of a diff fragment (supplementary code points count 1).
  static int _deltaLength(String s) {
    var n = 0;
    for (var i = 0; i < s.length; i++) {
      final u = s.codeUnitAt(i);
      if (u >= 0xDB80 && u <= 0xDBBF && i + 1 < s.length) {
        // High surrogate of plane 15/16 (our embed placeholders).
        n++;
        i++;
        continue;
      }
      n++;
    }
    return n;
  }

  /// A stable key for an embed `insert` value (deep, key-order independent).
  static String canonicalEmbedKey(Object? data) {
    final b = StringBuffer();
    void w(Object? v) {
      if (v is Map) {
        final keys = v.keys.map((k) => '$k').toList()..sort();
        b.write('{');
        for (final k in keys) {
          b
            ..write(k)
            ..write(':');
          w(v[k]);
          b.write(',');
        }
        b.write('}');
      } else if (v is List) {
        b.write('[');
        for (final e in v) {
          w(e);
          b.write(',');
        }
        b.write(']');
      } else {
        b.write(v is String ? '"$v"' : '$v');
      }
    }

    w(data);
    return b.toString();
  }
}
