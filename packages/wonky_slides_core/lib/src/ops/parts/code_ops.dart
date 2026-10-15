part of '../operations.dart';

// Code (02 §3.8, 07; planner SL-26).

/// Replaces the source of a code state (whole value).
final class SetCode extends SlidesOperation {
  const SetCode(this.stateId, this.code);

  final String stateId;
  final String code;

  @override
  String get name => 'SetCode';
}

/// Adds code states after [afterStateId] (null = at the end); each map
/// holds `CodeState` columns (`code`, `label`, `highlight`, …).
final class AddCodeStates extends SlidesOperation {
  const AddCodeStates(this.elementId, this.states, {this.afterStateId});

  final String elementId;
  final List<Map<String, Object?>> states;
  final String? afterStateId;

  @override
  String get name => 'AddCodeStates';
}

/// Updates code state columns.
final class UpdateCodeState extends SlidesOperation {
  const UpdateCodeState(this.stateId, this.columns);

  final String stateId;
  final Map<String, Object?> columns;

  @override
  String get name => 'UpdateCodeState';
}

/// Reorders code states.
final class MoveCodeStates extends SlidesOperation {
  const MoveCodeStates(this.stateIds, {this.beforeId, this.afterId});

  final List<String> stateIds;
  final String? beforeId;
  final String? afterId;

  @override
  String get name => 'MoveCodeStates';
}

/// Deletes code states (never the last one, 07 A-07-2).
final class DeleteCodeStates extends SlidesOperation {
  const DeleteCodeStates(this.stateIds);

  final List<String> stateIds;

  @override
  String get name => 'DeleteCodeStates';
}
