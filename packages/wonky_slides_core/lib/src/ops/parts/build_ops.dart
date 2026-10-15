part of '../operations.dart';

// Builds (02 §3.7, 06; planner SL-24).

/// A new build of [AddBuilds] (`SlideBuild` columns besides the slide,
/// order and id).
final class BuildSpec {
  const BuildSpec({
    required this.elementId,
    required this.kind,
    required this.effect,
    this.trigger = SlideBuildTrigger.onClick,
    this.delayMs = 0,
    required this.durationMs,
    this.easing = 'easeOut',
    this.optionsJson,
  });

  final String elementId;
  final SlideBuildKind kind;
  final String effect;
  final SlideBuildTrigger trigger;
  final int delayMs;
  final int durationMs;
  final String easing;
  final String? optionsJson;
}

/// Adds builds to a slide after [afterBuildId] (null = at the end).
final class AddBuilds extends SlidesOperation {
  const AddBuilds(this.slideId, this.builds, {this.afterBuildId});

  final String slideId;
  final List<BuildSpec> builds;
  final String? afterBuildId;

  @override
  String get name => 'AddBuilds';
}

/// Updates build columns (by column name, 02 §3.7).
final class UpdateBuilds extends SlidesOperation {
  const UpdateBuilds(this.updates);

  /// Build id → columns to write.
  final Map<String, Map<String, Object?>> updates;

  @override
  String get name => 'UpdateBuilds';
}

/// Reorders builds of a slide.
final class MoveBuilds extends SlidesOperation {
  const MoveBuilds(this.buildIds, {this.beforeId, this.afterId});

  final List<String> buildIds;
  final String? beforeId;
  final String? afterId;

  @override
  String get name => 'MoveBuilds';
}

/// Deletes builds.
final class DeleteBuilds extends SlidesOperation {
  const DeleteBuilds(this.buildIds);

  final List<String> buildIds;

  @override
  String get name => 'DeleteBuilds';
}
