part of '../operations.dart';

// Maintenance (02 §10).

/// A detected invariant violation (02 §10), by rule key and row.
final class DeckViolation {
  const DeckViolation(this.rule, this.table, this.rowId);

  /// Rule key (`orphanSlide`, `dupPlaceholder`, `groupCycle`, `emptyGroup`,
  /// `foreignParent`, `missingDeckTheme`, `noTheme`, `mergeOverlap`,
  /// `codeWithoutState`, `danglingPlaceholder`).
  final String rule;
  final String table;
  final String rowId;

  @override
  bool operator ==(Object other) =>
      other is DeckViolation &&
      other.rule == rule &&
      other.table == table &&
      other.rowId == rowId;

  @override
  int get hashCode => Object.hash(rule, table, rowId);

  @override
  String toString() => 'DeckViolation($rule, $table, $rowId)';
}

/// Repairs violations deterministically ("Repair presentation", not on the
/// undo stack).
final class RepairDeck extends SlidesOperation {
  const RepairDeck(this.violations);

  final List<DeckViolation> violations;

  @override
  String get name => 'RepairDeck';
}
