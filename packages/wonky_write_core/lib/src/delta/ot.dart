/// OT helpers over `dart_quill_delta` 9.x with a pinned transform convention
/// (specs/wonky_write/03-sync-protocol.md §2–§4).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'delta_utils.dart';

/// Thrown when a change does not fit the document it is applied to.
final class DeltaApplyException implements Exception {
  /// Creates the exception.
  const DeltaApplyException(this.message);

  /// Description.
  final String message;

  @override
  String toString() => 'DeltaApplyException: $message';
}

/// A selection as Delta offsets (`anchor` may be after `head`).
final class DeltaSelection {
  /// Creates a selection.
  const DeltaSelection(this.anchor, this.head);

  /// A collapsed selection (caret) at [offset].
  const DeltaSelection.collapsed(int offset) : this(offset, offset);

  /// Fixed end of the selection.
  final int anchor;

  /// Moving end of the selection.
  final int head;

  /// Smaller offset.
  int get start => anchor < head ? anchor : head;

  /// Larger offset.
  int get end => anchor < head ? head : anchor;

  /// Selected length.
  int get length => end - start;

  /// Whether the selection is a caret.
  bool get isCollapsed => anchor == head;

  @override
  bool operator ==(Object other) =>
      other is DeltaSelection && other.anchor == anchor && other.head == head;

  @override
  int get hashCode => Object.hash(anchor, head);

  @override
  String toString() => 'DeltaSelection($anchor, $head)';
}

/// OT operations with a documented, tested convention.
///
/// **Convention** (pinned by tests against `dart_quill_delta` 9.x):
/// `a.transform(b, p)` returns *b transformed against a*, i.e. a change that
/// applies after `a`; when `p == true`, `a`'s inserts at the same position
/// win ties (they end up first). [transform] wraps it with named arguments.
abstract final class WonkyOt {
  /// Returns [b] transformed against [a] (applies after [a]). When
  /// [aWinsTies], inserts of [a] at the same position as inserts of [b] are
  /// placed first. Result is canonical.
  static Delta transform(Delta a, Delta b, {required bool aWinsTies}) =>
      DeltaUtils.canonical(a.transform(b, aWinsTies));

  /// Transforms two concurrent changes against each other.
  ///
  /// Returns `(aPrime, bPrime)` where `aPrime` applies after [b] and `bPrime`
  /// applies after [a], so `doc∘a∘bPrime == doc∘b∘aPrime` (TP1). [aWinsTies]
  /// decides the order of inserts at the same position.
  static (Delta aPrime, Delta bPrime) transformPair(
    Delta a,
    Delta b, {
    required bool aWinsTies,
  }) => (
    transform(b, a, aWinsTies: !aWinsTies),
    transform(a, b, aWinsTies: aWinsTies),
  );

  /// Server rebase (03 §2 step 4): [clientOp] based on an older revision is
  /// transformed against the composition of the ops committed since
  /// ([serverOps], oldest first). Server ops win ties.
  static Delta rebaseOnServer(Delta clientOp, Iterable<Delta> serverOps) {
    final s = composeAll(serverOps);
    return transform(s, clientOp, aWinsTies: true);
  }

  /// Composes [a] then [b] (canonical).
  static Delta compose(Delta a, Delta b) => DeltaUtils.canonical(a.compose(b));

  /// Composes [changes] in order (canonical; empty for none).
  static Delta composeAll(Iterable<Delta> changes) {
    var result = Delta();
    for (final c in changes) {
      result = result.compose(c);
    }
    return DeltaUtils.canonical(result);
  }

  /// Applies [change] to the document delta [document] and returns the new
  /// document. Throws [DeltaApplyException] when [change] retains or deletes
  /// past the end of [document].
  static Delta apply(Delta document, Delta change) {
    final docLength = DeltaUtils.documentLength(document);
    final base = DeltaUtils.baseLength(change);
    if (base > docLength) {
      throw DeltaApplyException(
        'Change spans $base characters but the document has $docLength',
      );
    }
    return DeltaUtils.canonical(document.compose(change));
  }

  /// Inverse of [change] against [base] (the document before [change]):
  /// `base∘change∘invert(change, base) == base`. Linear in the sizes of both
  /// deltas. Throws [DeltaApplyException] when [change] does not fit.
  static Delta invert(Delta change, Delta base) {
    final inverted = Delta();
    final it = DeltaIterator(base);
    for (final op in change.operations) {
      final length = op.length!;
      if (op.isInsert) {
        inverted.delete(length);
      } else if (op.isRetain && op.isPlain) {
        inverted.retain(length);
        _skip(it, length);
      } else {
        var remaining = length;
        while (remaining > 0) {
          if (!it.hasNext) {
            throw const DeltaApplyException('Change is longer than its base');
          }
          final baseOp = it.next(remaining);
          if (op.isDelete) {
            inverted.push(Operation.insert(baseOp.data, baseOp.attributes));
          } else {
            final attrs = Delta.invertAttributes(
              op.attributes,
              baseOp.attributes,
            );
            inverted.retain(baseOp.length!, attrs.isEmpty ? null : attrs);
          }
          remaining -= baseOp.length!;
        }
      }
    }
    return DeltaUtils.canonical(inverted);
  }

  static void _skip(DeltaIterator it, int length) {
    var remaining = length;
    while (remaining > 0) {
      if (!it.hasNext) {
        throw const DeltaApplyException('Change is longer than its base');
      }
      remaining -= it.next(remaining).length!;
    }
  }

  /// Transforms [position] through [change].
  ///
  /// An insert exactly at [position] moves it right when [pushOnInsert] is
  /// true (remote edits at a collaborator's caret), and leaves it in place
  /// otherwise (the author's own op, or range starts that should not grow).
  static int transformPosition(
    Delta change,
    int position, {
    bool pushOnInsert = true,
  }) => change.transformPosition(position, force: pushOnInsert);

  /// Transforms a selection through [change] (both ends).
  static DeltaSelection transformSelection(
    Delta change,
    DeltaSelection selection, {
    bool pushOnInsert = true,
  }) {
    return DeltaSelection(
      transformPosition(change, selection.anchor, pushOnInsert: pushOnInsert),
      transformPosition(change, selection.head, pushOnInsert: pushOnInsert),
    );
  }

  /// Transforms a range `[start, start + length)` through [change]; inserts
  /// at the range boundaries do not extend it (comment composer, AI preview
  /// ranges). Returns `(start, length)`; length is 0 if the range was deleted.
  static (int start, int length) transformRange(
    Delta change,
    int start,
    int length,
  ) {
    final s = transformPosition(change, start, pushOnInsert: true);
    final e = transformPosition(change, start + length, pushOnInsert: false);
    return (s, e < s ? 0 : e - s);
  }

  /// Selective-undo rebase (03 §4): rebases undo-stack entries [stack]
  /// (oldest first; the newest applies to the current document) over a
  /// remote op [remote] that was just applied. Returns the rebased stack
  /// (same length and order; entries may become empty no-ops, which callers
  /// usually drop together with their selection data) and [remote] expressed
  /// past all entries.
  static (List<Delta> stack, Delta remote) rebaseStack(
    List<Delta> stack,
    Delta remote,
  ) {
    var r = remote;
    final rebased = List<Delta>.filled(stack.length, Delta());
    for (var i = stack.length - 1; i >= 0; i--) {
      final u = stack[i];
      final uPrime = transform(r, u, aWinsTies: true);
      r = transform(u, r, aWinsTies: false);
      rebased[i] = uPrime;
    }
    return (rebased, r);
  }
}
