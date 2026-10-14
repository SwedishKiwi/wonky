/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// A cell changed by a previewed AI tool call (before → after).
abstract class SheetsAiPreviewCell
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SheetsAiPreviewCell._({
    required this.cell,
    this.before,
    this.after,
  });

  factory SheetsAiPreviewCell({
    required String cell,
    String? before,
    String? after,
  }) = _SheetsAiPreviewCellImpl;

  factory SheetsAiPreviewCell.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsAiPreviewCell(
      cell: jsonSerialization['cell'] as String,
      before: jsonSerialization['before'] as String?,
      after: jsonSerialization['after'] as String?,
    );
  }

  String cell;

  String? before;

  String? after;

  /// Returns a shallow copy of this [SheetsAiPreviewCell]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SheetsAiPreviewCell copyWith({
    String? cell,
    String? before,
    String? after,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsAiPreviewCell',
      'cell': cell,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsAiPreviewCell',
      'cell': cell,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsAiPreviewCellImpl extends SheetsAiPreviewCell {
  _SheetsAiPreviewCellImpl({
    required String cell,
    String? before,
    String? after,
  }) : super._(
         cell: cell,
         before: before,
         after: after,
       );

  /// Returns a shallow copy of this [SheetsAiPreviewCell]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SheetsAiPreviewCell copyWith({
    String? cell,
    Object? before = _Undefined,
    Object? after = _Undefined,
  }) {
    return SheetsAiPreviewCell(
      cell: cell ?? this.cell,
      before: before is String? ? before : this.before,
      after: after is String? ? after : this.after,
    );
  }
}
