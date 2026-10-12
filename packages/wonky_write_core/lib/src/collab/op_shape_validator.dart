/// Permission-restricted op shapes for commenters (03 §5, 08 §2.10).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../delta/attributes.dart';

/// A rejected op shape.
final class OpShapeViolation {
  /// Creates a violation.
  const OpShapeViolation(this.offset, this.message);

  /// Offset in the pre-op document.
  final int offset;

  /// Reason.
  final String message;

  @override
  String toString() => 'OpShapeViolation@$offset: $message';
}

/// Validates that an op only contains shapes a commenter may submit:
/// (a) `cmt_*`-only retains; (b) inserts carrying exactly one own
/// `sug_<id>{t:ins}`; (c) retains adding an own `sug_<id>{t:del}`;
/// (d) formatting retains with an own `sug_<id>{t:fmt}` whose `before`
/// equals the pre-op attributes (or the existing own `fmt` `before`);
/// (e) retractions: deleting own insertions, removing own `sug_*` marks
/// (restoring `before` for own `fmt`); formatting own insertions directly.
abstract final class OpShapeValidator {
  /// Returns `null` when [op] (based on [docBefore]) is allowed for
  /// commenter [userUuid], otherwise the first violation.
  static OpShapeViolation? validateCommenterOp(
    Delta docBefore,
    Delta op,
    String userUuid,
  ) {
    final it = DeltaIterator(docBefore);
    var offset = 0;
    for (final o in op.operations) {
      if (o.isInsert) {
        final attrs = o.attributes ?? const <String, dynamic>{};
        final marks = Attributes.suggestions(attrs);
        final rawSug = attrs.keys.where(WonkyAttr.isSuggestion).length;
        if (marks.length != 1 || rawSug != 1) {
          return OpShapeViolation(
            offset,
            'Insert must carry exactly one suggestion mark',
          );
        }
        final m = marks.values.single;
        if (m.kind != SuggestionKind.ins || m.by != userUuid) {
          return OpShapeViolation(
            offset,
            'Insert must be an own insertion suggestion',
          );
        }
        continue;
      }
      var remaining = o.length!;
      if (o.isRetain && o.isPlain) {
        while (remaining > 0 && it.hasNext) {
          final p = it.next(remaining);
          remaining -= p.length!;
          offset += p.length!;
        }
        continue;
      }
      while (remaining > 0) {
        if (!it.hasNext) {
          return OpShapeViolation(offset, 'Op longer than the document');
        }
        final piece = it.next(remaining);
        final len = piece.length!;
        remaining -= len;
        final current = piece.attributes ?? const <String, dynamic>{};
        final marks = Attributes.suggestions(current);
        final ownIns = marks.values.any(
          (m) => m.kind == SuggestionKind.ins && m.by == userUuid,
        );
        if (o.isDelete) {
          if (!ownIns) {
            return OpShapeViolation(
              offset,
              'Only own suggested insertions may be deleted',
            );
          }
          offset += len;
          continue;
        }
        final violation = _checkRetain(
          o.attributes!,
          current,
          marks,
          ownIns,
          userUuid,
          piece.data == '\n',
        );
        if (violation != null) return OpShapeViolation(offset, violation);
        offset += len;
      }
    }
    return null;
  }

  static String? _checkRetain(
    Map<String, dynamic> patch,
    Map<String, dynamic> current,
    Map<String, SuggestionMark> marks,
    bool ownIns,
    String user,
    bool isNewline,
  ) {
    final content = {
      for (final e in patch.entries)
        if (!WonkyAttr.isOverlay(e.key)) e.key: e.value,
    };
    final sugChanges = {
      for (final e in patch.entries)
        if (WonkyAttr.isSuggestion(e.key))
          WonkyAttr.suggestionId(e.key)!: e.value,
    };
    // (a) comment-only.
    if (content.isEmpty && sugChanges.isEmpty) return null;
    // Removals of suggestion marks must be own marks.
    for (final e in sugChanges.entries) {
      if (e.value != null) continue;
      final existing = marks[e.key];
      if (existing == null) continue;
      if (existing.by != user) {
        return 'Cannot remove another user\'s suggestion';
      }
    }
    final added = <String, SuggestionMark>{};
    for (final e in sugChanges.entries) {
      if (e.value == null) continue;
      final m = SuggestionMark.tryParse(e.value);
      if (m == null || m.by != user) return 'Suggestion marks must be own';
      added[e.key] = m;
    }
    // Formatting own insertions directly.
    if (ownIns && added.isEmpty) return null;
    if (content.isEmpty) {
      // (c) deletion marks only.
      if (added.values.every((m) => m.kind == SuggestionKind.del)) return null;
      // Removing own marks (no content change).
      if (added.isEmpty) return null;
      return 'Invalid suggestion change';
    }
    final group = isNewline ? WonkyAttr.blockKeys : WonkyAttr.inlineKeys;
    if (content.keys.any((k) => !group.contains(k))) {
      return 'Attribute not allowed here';
    }
    // (e) restoring `before` while removing an own fmt.
    final removedOwnFmt = sugChanges.entries
        .where(
          (e) =>
              e.value == null &&
              marks[e.key]?.kind == SuggestionKind.fmt &&
              marks[e.key]?.by == user,
        )
        .map((e) => marks[e.key]!)
        .toList();
    final after =
        Attributes.apply(Attributes.withoutOverlays(current), content) ??
        const {};
    final afterGroup = {
      for (final e in after.entries)
        if (group.contains(e.key)) e.key: e.value,
    };
    if (added.isEmpty) {
      if (removedOwnFmt.isNotEmpty &&
          removedOwnFmt.any((m) => Attributes.equals(m.before, afterGroup))) {
        return null;
      }
      // Changing attributes of text under an own fmt keeps that fmt.
      final ownFmt = marks.values.where(
        (m) => m.kind == SuggestionKind.fmt && m.by == user,
      );
      if (ownFmt.isNotEmpty) return null;
      return 'Formatting changes must be suggestions';
    }
    // (d) a new fmt with the exact previous attributes.
    if (added.length != 1 || added.values.single.kind != SuggestionKind.fmt) {
      return 'Formatting must carry one own fmt suggestion';
    }
    final before = added.values.single.before ?? const <String, dynamic>{};
    final currentGroup = {
      for (final e in current.entries)
        if (group.contains(e.key)) e.key: e.value,
    };
    final existingOwn = marks.values.where(
      (m) => m.kind == SuggestionKind.fmt && m.by == user,
    );
    final ok =
        Attributes.equals(before, currentGroup) ||
        existingOwn.any((m) => Attributes.equals(m.before, before));
    return ok ? null : '"before" does not match the current attributes';
  }
}
