part of '../operations.dart';

// Slide groups (02 §3.4, 04 §5.12, D11).

/// Creates a group holding [slideIds] at the position of the first one.
final class CreateGroup extends SlidesOperation {
  const CreateGroup(this.slideIds, {this.title, this.color, this.groupId});

  final List<String> slideIds;

  /// Title (null = generated "Group 3").
  final String? title;
  final String? color;

  /// Id of the new group (null = a fresh id from the context).
  final String? groupId;

  @override
  String get name => 'CreateGroup';
}

/// Dissolves a group; its slides take its place in the top-level space.
final class Ungroup extends SlidesOperation {
  const Ungroup(this.groupId);

  final String groupId;

  @override
  String get name => 'Ungroup';
}

/// Moves groups in the top-level key space.
final class MoveGroups extends SlidesOperation {
  const MoveGroups(this.groupIds, {this.beforeId, this.afterId});

  final List<String> groupIds;
  final String? beforeId;
  final String? afterId;

  @override
  String get name => 'MoveGroups';
}

/// Group properties (null = unchanged).
final class SetGroupProps extends SlidesOperation {
  const SetGroupProps(this.groupIds, {this.title, this.color, this.skipped});

  final List<String> groupIds;
  final String? title;
  final Patch<String?>? color;
  final bool? skipped;

  @override
  String get name => 'SetGroupProps';
}

/// Deletes groups; [withSlides] deletes their slides too, else the slides
/// are ungrouped in place.
final class DeleteGroups extends SlidesOperation {
  const DeleteGroups(this.groupIds, {this.withSlides = false});

  final List<String> groupIds;
  final bool withSlides;

  @override
  String get name => 'DeleteGroups';
}

/// Duplicates groups with their slides, each after its source.
final class DuplicateGroups extends SlidesOperation {
  const DuplicateGroups(this.groupIds);

  final List<String> groupIds;

  @override
  String get name => 'DuplicateGroups';
}
