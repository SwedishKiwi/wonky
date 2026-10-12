import 'dart:convert';

import '../../addressing/grid_geometry.dart';
import '../../model/events.dart';
import '../../model/grid_range.dart';
import '../../model/records.dart';
import '../../model/schema.dart';
import '../../model/sheet_model.dart';
import '../../model/workbook_model.dart';

/// Error code of writes refused by a protection (MCP, server scripts, 07 §10.3).
const String kProtectedRangeErrorCode = 'protected_range';

/// A write a command intends to make (07 §10.3).
sealed class WriteIntent {
  const WriteIntent(this.sheetId);

  /// The sheet written.
  final String sheetId;
}

/// Cell writes (values, formulas, formats, notes, links, DV toggles; paste,
/// fill, sort, randomize, dedupe, split, find-replace).
final class CellWrites extends WriteIntent {
  /// Creates the intent.
  const CellWrites(super.sheetId, this.rects);

  final List<GridRect> rects;
}

/// Structural operations on rows/columns.
enum StructuralOp { insert, delete, move }

/// Insert/delete/move rows or columns at [indices] (current indices; for
/// inserts the rows/columns next to the insertion point).
final class Structural extends WriteIntent {
  /// Creates the intent.
  const Structural(super.sheetId, this.dimension, this.indices, this.op);

  final Dimension dimension;
  final List<int> indices;
  final StructuralOp op;
}

/// Rule changes (merge/unmerge, CF, DV, banding) over [rects].
final class RuleWrite extends WriteIntent {
  /// Creates the intent.
  const RuleWrite(super.sheetId, this.kind, this.rects);

  final RuleKind kind;
  final List<GridRect> rects;
}

/// Sheet operations (rename, delete, move, hide, tab color, freeze).
final class SheetOp extends WriteIntent {
  /// Creates the intent.
  const SheetOp(super.sheetId, this.op);

  /// Free-form operation name (for messages/logging).
  final String op;
}

/// Charts, images and slicers on a sheet.
final class ObjectWrite extends WriteIntent {
  /// Creates the intent.
  const ObjectWrite(super.sheetId);
}

/// Basic filter create/change over [range] (filter views are always allowed).
final class FilterWrite extends WriteIntent {
  /// Creates the intent.
  const FilterWrite(super.sheetId, this.range, {this.isView = false});

  final GridRect range;
  final bool isView;
}

/// Named ranges / named functions (never protected).
final class NameWrite extends WriteIntent {
  /// Creates the intent.
  const NameWrite() : super('');
}

/// Outcome of a guard check.
enum GuardStatus { allowed, warnings, blocked }

/// A protection touched by a write.
final class ProtectionHit {
  /// Creates a hit.
  const ProtectionHit(this.protectionId, this.rect, {required this.warningOnly});

  final String protectionId;

  /// The touched protected area (intersection), or the whole intent rect.
  final GridRect? rect;
  final bool warningOnly;

  @override
  bool operator ==(Object other) =>
      other is ProtectionHit && other.protectionId == protectionId && other.rect == rect && other.warningOnly == warningOnly;

  @override
  int get hashCode => Object.hash(protectionId, rect, warningOnly);

  @override
  String toString() => 'ProtectionHit($protectionId, ${rect?.a1}, warning: $warningOnly)';
}

/// Result of [ProtectionGuard.check].
final class GuardResult {
  /// Creates a result.
  const GuardResult(this.status, [this.hits = const []]);

  /// Allowed without protections.
  static const GuardResult allowed = GuardResult(GuardStatus.allowed);

  final GuardStatus status;

  /// Protections that block (when blocked) or warn.
  final List<ProtectionHit> hits;

  bool get isAllowed => status == GuardStatus.allowed;
  bool get isBlocked => status == GuardStatus.blocked;
  bool get hasWarnings => status == GuardStatus.warnings;

  /// Distinct protection ids.
  Set<String> get protectionIds => {for (final h in hits) h.protectionId};

  /// Blocked cells message (03 §16 / Sheets wording).
  static const String blockedMessage =
      "You are trying to edit a protected cell or object. Please contact the spreadsheet owner to remove "
      "protection if you need to edit.";

  /// Warning message (warning-only protections).
  static const String warningMessage =
      'Heads up! You are trying to edit part of this sheet that shouldn\'t be changed accidentally. Edit anyway?';

  @override
  String toString() => 'GuardResult(${status.name}, $hits)';
}

/// One protection resolved to rectangles.
final class _Prot {
  _Prot(this.record, this.rects, this.except, this.editors);
  final ProtectedRangeRecord record;

  /// Protected rectangles (whole sheet grid for sheet protections).
  final List<GridRect> rects;
  final List<GridRect> except;
  final Set<String> editors;
  bool get isSheet => record.rangeJson == null;
}

/// Interval index of the protections of one sheet (07 §10.3) built on the
/// sheet's `RuleIndex` (O(log n + k) per rectangle).
final class ProtectedIndex {
  /// Creates the index over [sheet].
  ProtectedIndex(this.sheet);

  final SheetModel sheet;

  /// Protections intersecting [rect] (ids, insertion order).
  List<String> intersecting(GridRect rect) => sheet.rulesIntersecting(RuleKind.protection, rect);

  /// Protections covering a cell (except ranges subtracted).
  List<String> at(int row, int col) => [
    for (final id in sheet.rulesAt(RuleKind.protection, row, col))
      if (!_exceptContains(id, row, col)) id,
  ];

  bool _exceptContains(String id, int row, int col) {
    final p = sheet.protections[id];
    if (p == null) return false;
    return ProtectionGuard._exceptRects(sheet, p).any((r) => r.contains(row, col));
  }
}

/// Enforces protected sheets and ranges (07 §10).
///
/// Who may edit a protection's cells: the spreadsheet owner, the protection's
/// creator and its editors. Warning-only protections let everyone edit after
/// a warning. A write touching any protected cell the user can't edit is
/// blocked entirely.
final class ProtectionGuard {
  /// Creates the guard over [model].
  ProtectionGuard(this.model);

  final WorkbookModel model;

  /// Editors (user UUIDs) of a protection.
  static Set<String> editorsOf(ProtectedRangeRecord p) {
    try {
      final d = jsonDecode(p.editorsJson);
      if (d is List) return {for (final e in d) e.toString().toLowerCase()};
    } on FormatException {
      // fallthrough
    }
    return const {};
  }

  static List<GridRect> _exceptRects(SheetModel sheet, ProtectedRangeRecord p) => [
    for (final r in GridRange.parseList(p.exceptRangesJson))
      if (sheet.resolve(r) case final ResolvedRange rr) rr.rect,
  ];

  /// Whether [userId] may edit cells of [p] without warning.
  static bool canEdit(ProtectedRangeRecord p, String userId, {required bool isOwner}) {
    if (isOwner) return true;
    final u = userId.toLowerCase();
    if (p.createdBy.toLowerCase() == u) return true;
    return editorsOf(p).contains(u);
  }

  /// Whether [userId] may change or remove [p] (owner and its editors).
  static bool canManage(ProtectedRangeRecord p, String userId, {required bool isOwner}) =>
      canEdit(p, userId, isOwner: isOwner);

  _Prot? _resolve(SheetModel sheet, String id) {
    final p = sheet.protections[id];
    if (p == null) return null;
    final rects = sheet.ruleRects(RuleKind.protection, id);
    return _Prot(p, rects, _exceptRects(sheet, p), editorsOf(p));
  }

  /// Checks [intent] for [userId].
  GuardResult check(WriteIntent intent, String userId, {required bool isOwner}) {
    if (intent is NameWrite) return GuardResult.allowed;
    if (intent is FilterWrite && intent.isView) return GuardResult.allowed;
    final sheet = model.sheet(intent.sheetId);
    if (sheet == null || sheet.protections.isEmpty) return GuardResult.allowed;
    final hits = <ProtectionHit>[];
    var blocked = false;
    void hit(_Prot p, GridRect? rect) {
      final editable = canEdit(p.record, userId, isOwner: isOwner);
      if (editable) return;
      hits.add(ProtectionHit(p.record.id, rect, warningOnly: p.record.warningOnly));
      if (!p.record.warningOnly) blocked = true;
    }

    switch (intent) {
      case CellWrites(:final rects):
        _checkRects(sheet, rects, hit);
      case RuleWrite(:final rects):
        _checkRects(sheet, rects, hit);
      case FilterWrite(:final range):
        _checkRects(sheet, [range], hit);
        for (final id in sheet.protections.keys) {
          final p = _resolve(sheet, id)!;
          if (p.isSheet && !hits.any((h) => h.protectionId == id)) hit(p, range);
        }
      case SheetOp():
      case ObjectWrite():
        for (final id in sheet.protections.keys) {
          final p = _resolve(sheet, id)!;
          if (p.isSheet) hit(p, null);
        }
      case Structural(:final dimension, :final indices):
        _checkStructural(sheet, dimension, indices, hit);
      case NameWrite():
        break;
    }
    if (hits.isEmpty) return GuardResult.allowed;
    return GuardResult(blocked ? GuardStatus.blocked : GuardStatus.warnings, _dedupe(hits));
  }

  static List<ProtectionHit> _dedupe(List<ProtectionHit> hits) {
    final seen = <ProtectionHit>{};
    return [
      for (final h in hits)
        if (seen.add(h)) h,
    ];
  }

  void _checkRects(SheetModel sheet, List<GridRect> rects, void Function(_Prot, GridRect?) hit) {
    for (final rect in rects) {
      for (final id in sheet.rulesIntersecting(RuleKind.protection, rect)) {
        final p = _resolve(sheet, id);
        if (p == null) continue;
        for (final pr in p.rects) {
          final i = pr.intersection(rect);
          if (i == null) continue;
          // Remaining protected cells after removing exceptions.
          var rest = [i];
          for (final e in p.except) {
            rest = RectSet.subtractAll(rest, e);
          }
          if (rest.isNotEmpty) {
            hit(p, rest.first);
            break;
          }
        }
      }
    }
  }

  void _checkStructural(SheetModel sheet, Dimension dim, List<int> indices, void Function(_Prot, GridRect?) hit) {
    if (indices.isEmpty) return;
    final grid = sheet.gridRect;
    if (grid == null) return;
    for (final id in sheet.protections.keys) {
      final p = _resolve(sheet, id);
      if (p == null) continue;
      for (final idx in indices) {
        final line = dim == Dimension.rows
            ? GridRect(idx, grid.left, idx, grid.right)
            : GridRect(grid.top, idx, grid.bottom, idx);
        GridRect? touched;
        for (final pr in p.rects) {
          final i = pr.intersection(line);
          if (i == null) continue;
          var rest = [i];
          for (final e in p.except) {
            rest = RectSet.subtractAll(rest, e);
          }
          if (rest.isNotEmpty) {
            touched = rest.first;
            break;
          }
        }
        if (touched != null) {
          hit(p, touched);
          break;
        }
      }
    }
  }
}
