/// Version diffs with per-author attribution (08 §4.2).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../delta/attributes.dart';
import '../delta/delta_diff.dart';
import '../delta/delta_utils.dart';

/// An op with its author (from the op log).
final class AuthoredOp {
  /// Creates an authored op.
  const AuthoredOp(this.delta, {this.authorUuid, this.actorKind = 'user'});

  /// The op as applied.
  final Delta delta;

  /// Author user UUID (`null` = unknown/system).
  final String? authorUuid;

  /// `user`, `mcp`, `ai`, `script`, `system`.
  final String actorKind;
}

/// Diff overlay attribute keys in [WriteDiff.delta].
abstract final class DiffAttr {
  /// Inserted text: `{by}`.
  static const ins = 'diff_ins';

  /// Deleted text (tombstone): `{by}`.
  static const del = 'diff_del';

  /// Formatting change: `{by, before}`.
  static const fmt = 'diff_fmt';
}

/// Per-author change statistics.
final class DiffAuthorStats {
  /// Creates stats.
  DiffAuthorStats(this.userUuid, this.actorKind);

  /// Author (`null` = unknown, "Multiple people").
  final String? userUuid;

  /// Actor kind of the first op seen.
  final String actorKind;

  /// Inserted characters.
  int inserted = 0;

  /// Deleted characters.
  int deleted = 0;

  /// Formatted characters.
  int formatted = 0;

  /// JSON form (the server adds name and color).
  Map<String, dynamic> toJson() => {
    'userUuid': userUuid,
    'actorKind': actorKind,
    'inserted': inserted,
    'deleted': deleted,
    'formatted': formatted,
  };
}

/// Result of a diff (`WriteDiffView` without server fields).
final class WriteDiff {
  /// Creates a diff.
  const WriteDiff({
    required this.delta,
    required this.exact,
    required this.authors,
    required this.changeCount,
  });

  /// doc(B) plus tombstones, with `diff_*` overlay attributes (overlays
  /// `cmt_*`/`sug_*` stripped).
  final Delta delta;

  /// Whether authorship is exact (attributed replay).
  final bool exact;

  /// Per-author statistics.
  final List<DiffAuthorStats> authors;

  /// Number of contiguous change regions.
  final int changeCount;

  /// JSON form (`deltaJson` as an ops list).
  Map<String, dynamic> toJson() => {
    'exact': exact,
    'delta': delta.toJson(),
    'authors': [for (final a in authors) a.toJson()],
    'changeCount': changeCount,
  };
}

enum _Mark { orig, ins, del, fmt }

final class _Piece {
  _Piece(this.data, this.attrs, this.mark, {this.by, this.before});

  Object data; // String or embed map
  Map<String, dynamic>? attrs;
  _Mark mark;
  String? by;
  Map<String, dynamic>? before;

  int get length => data is String ? (data as String).length : 1;

  bool get isTombstone => mark == _Mark.del;

  _Piece split(int at) {
    final s = data as String;
    final tail = _Piece(s.substring(at), attrs, mark, by: by, before: before);
    data = s.substring(0, at);
    return tail;
  }
}

/// Computes attributed diffs.
abstract final class AttributedDiff {
  /// Maximum ops for exact replay (08 §4.2).
  static const maxReplayOps = 20000;

  /// Exact diff by replaying [ops] (in order) on [docA]. Retain/delete
  /// lengths count only non-tombstone characters.
  static WriteDiff diff(Delta docA, List<AuthoredOp> ops) {
    final pieces = <_Piece>[
      for (final op in DeltaUtils.stripOverlays(docA).operations)
        if (op.isInsert)
          _Piece(op.data!, Attributes.orNull(op.attributes), _Mark.orig),
    ];
    final kinds = <String?, String>{};
    for (final authored in ops) {
      kinds.putIfAbsent(authored.authorUuid, () => authored.actorKind);
      _replay(
        pieces,
        _reorder(DeltaUtils.stripOverlays(authored.delta)),
        authored.authorUuid,
      );
    }
    for (final p in pieces) {
      if (p.mark == _Mark.fmt && Attributes.equals(p.attrs, p.before)) {
        p
          ..mark = _Mark.orig
          ..by = null
          ..before = null;
      }
    }
    return _result(pieces, exact: true, kinds: kinds);
  }

  /// Unattributed fallback diff of two snapshots (`doc(A).diff(doc(B))`);
  /// all changes are attributed to `null` ("Multiple people").
  static WriteDiff diffSnapshots(Delta docA, Delta docB) {
    final a = DeltaUtils.stripOverlays(docA);
    final change = DeltaDiff.diff(a, DeltaUtils.stripOverlays(docB));
    final pieces = <_Piece>[
      for (final op in a.operations)
        _Piece(op.data!, Attributes.orNull(op.attributes), _Mark.orig),
    ];
    _replay(pieces, _reorder(change), null);
    for (final p in pieces) {
      if (p.mark == _Mark.fmt && Attributes.equals(p.attrs, p.before)) {
        p.mark = _Mark.orig;
      }
    }
    return _result(pieces, exact: false, kinds: {null: 'user'});
  }

  /// Places deletes before inserts at the same position so a replacement
  /// renders as "~~old~~new".
  static List<Operation> _reorder(Delta d) {
    final ops = List<Operation>.of(DeltaUtils.canonical(d).operations);
    for (var i = 0; i + 1 < ops.length; i++) {
      if (ops[i].isInsert && ops[i + 1].isDelete) {
        final t = ops[i];
        ops[i] = ops[i + 1];
        ops[i + 1] = t;
        i++;
      }
    }
    return ops;
  }

  static void _replay(List<_Piece> pieces, List<Operation> ops, String? by) {
    var index = 0; // piece index
    var offset = 0; // offset inside pieces[index]

    void normalizePosition() {
      while (index < pieces.length && offset >= pieces[index].length) {
        index++;
        offset = 0;
      }
    }

    // Splits so that a piece starts at the current position; returns its index.
    int splitHere() {
      normalizePosition();
      if (index < pieces.length && offset > 0) {
        final tail = pieces[index].split(offset);
        pieces.insert(index + 1, tail);
        index++;
        offset = 0;
      }
      return index;
    }

    for (final op in ops) {
      if (op.isInsert) {
        splitHere();
        // Insert after tombstones at this position.
        while (index < pieces.length && pieces[index].isTombstone) {
          index++;
        }
        pieces.insert(
          index,
          _Piece(op.data!, Attributes.orNull(op.attributes), _Mark.ins, by: by),
        );
        index++;
        offset = 0;
        continue;
      }
      var remaining = op.length!;
      while (remaining > 0) {
        splitHere();
        if (index >= pieces.length) return;
        final p = pieces[index];
        if (p.isTombstone) {
          index++;
          continue;
        }
        if (p.length > remaining) {
          pieces.insert(index + 1, p.split(remaining));
        }
        final len = p.length;
        remaining -= len;
        if (op.isDelete) {
          if (p.mark == _Mark.ins) {
            pieces.removeAt(index);
            continue;
          }
          p
            ..mark = _Mark.del
            ..by = by;
          index++;
        } else {
          final patch = op.attributes;
          if (patch != null && patch.isNotEmpty) {
            final next = Attributes.apply(p.attrs, patch);
            if (!Attributes.equals(next, p.attrs)) {
              if (p.mark == _Mark.orig) {
                p
                  ..before = p.attrs ?? const {}
                  ..mark = _Mark.fmt
                  ..by = by;
              } else if (p.mark == _Mark.fmt) {
                p.by = by;
              }
              p.attrs = next;
            }
          }
          index++;
        }
      }
    }
  }

  static WriteDiff _result(
    List<_Piece> pieces, {
    required bool exact,
    required Map<String?, String> kinds,
  }) {
    final d = Delta();
    final stats = <String?, DiffAuthorStats>{};
    DiffAuthorStats statsFor(String? by) =>
        stats.putIfAbsent(by, () => DiffAuthorStats(by, kinds[by] ?? 'user'));
    var regions = 0;
    var inChange = false;
    for (final p in pieces) {
      final attrs = Map<String, dynamic>.from(p.attrs ?? const {});
      switch (p.mark) {
        case _Mark.orig:
          inChange = false;
        case _Mark.ins:
          attrs[DiffAttr.ins] = {'by': p.by};
          statsFor(p.by).inserted += p.length;
        case _Mark.del:
          attrs[DiffAttr.del] = {'by': p.by};
          statsFor(p.by).deleted += p.length;
        case _Mark.fmt:
          attrs[DiffAttr.fmt] = {
            'by': p.by,
            'before': p.before ?? const <String, dynamic>{},
          };
          statsFor(p.by).formatted += p.length;
      }
      if (p.mark != _Mark.orig && !inChange) {
        regions++;
        inChange = true;
      }
      d.push(Operation.insert(p.data, attrs.isEmpty ? null : attrs));
    }
    return WriteDiff(
      delta: DeltaUtils.canonical(d),
      exact: exact,
      authors: stats.values.toList(),
      changeCount: regions,
    );
  }
}
