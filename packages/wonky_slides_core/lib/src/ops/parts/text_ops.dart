part of '../operations.dart';

// Text (02 §4, §12.1 "Text", 03 §6.1).

/// Replaces a whole text body with [delta] (Delta JSON; validated and
/// normalized by the planner, 02 §4.1). [coalesceKey] groups typing.
final class SetText extends SlidesOperation {
  const SetText(this.target, this.delta);

  final TextTarget target;

  /// Delta JSON (`[{"insert":"…\n"}]`), or null to clear (not for notes).
  final String? delta;

  @override
  String get name => 'SetText';
}

/// Applies inline/block attributes to text bodies. [start]/[length] select
/// a range of a single target (null = the whole body).
final class FormatText extends SlidesOperation {
  const FormatText(this.targets, this.attributes, {this.start, this.length});

  final List<TextTarget> targets;

  /// Delta attributes; a null value removes the attribute.
  final Map<String, Object?> attributes;
  final int? start;
  final int? length;

  @override
  String get name => 'FormatText';
}

/// Box-level text properties (`textStyleJson`, 02 §5.1) as a JSON merge
/// patch.
final class SetTextBoxStyle extends SlidesOperation {
  const SetTextBoxStyle(this.elementIds, this.patch);

  final List<String> elementIds;
  final Map<String, Object?> patch;

  @override
  String get name => 'SetTextBoxStyle';
}

/// *Reset to layout* of placeholder instances (03 §6.2, 05 §5.3): their
/// frame, rotation, box text properties, fill, stroke, effects and opacity
/// go back to null, so they inherit from the layout placeholder again. The
/// text stays.
final class ResetPlaceholders extends SlidesOperation {
  const ResetPlaceholders(this.elementIds);

  final List<String> elementIds;

  @override
  String get name => 'ResetPlaceholders';
}
