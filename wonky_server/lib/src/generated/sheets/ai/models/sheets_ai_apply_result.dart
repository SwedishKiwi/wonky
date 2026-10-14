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
import 'package:serverpod/serverpod.dart' as _is;

/// The result of applying AI changes (a preview or Fill with AI): one
/// undoable server change (`sheets.serverChange`, `SheetsEndpoint.revertChange`).
abstract class SheetsAiApplyResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsAiApplyResult._({
    this.changeId,
    required this.label,
    required this.cellsAffected,
    required this.skipped,
  });

  factory SheetsAiApplyResult({
    _is.UuidValue? changeId,
    required String label,
    required int cellsAffected,
    required int skipped,
  }) = _SheetsAiApplyResultImpl;

  factory SheetsAiApplyResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsAiApplyResult(
      changeId: jsonSerialization['changeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['changeId']),
      label: jsonSerialization['label'] as String,
      cellsAffected: jsonSerialization['cellsAffected'] as int,
      skipped: jsonSerialization['skipped'] as int,
    );
  }

  /// Null when nothing changed.
  _is.UuidValue? changeId;

  String label;

  int cellsAffected;

  /// Columns kept because someone else changed them meanwhile.
  int skipped;

  /// Returns a shallow copy of this [SheetsAiApplyResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsAiApplyResult copyWith({
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
    String? label,
    int? cellsAffected,
    int? skipped,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsAiApplyResult',
      if (changeId != null) 'changeId': changeId?.toJson(),
      'label': label,
      'cellsAffected': cellsAffected,
      'skipped': skipped,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsAiApplyResult',
      if (changeId != null) 'changeId': changeId?.toJson(),
      'label': label,
      'cellsAffected': cellsAffected,
      'skipped': skipped,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _SheetsAiApplyResultImpl extends SheetsAiApplyResult {
  _SheetsAiApplyResultImpl({
    _is.UuidValue? changeId,
    required String label,
    required int cellsAffected,
    required int skipped,
  }) : super._(
         changeId: changeId,
         label: label,
         cellsAffected: cellsAffected,
         skipped: skipped,
       );

  /// Returns a shallow copy of this [SheetsAiApplyResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsAiApplyResult copyWith({
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
    String? label,
    int? cellsAffected,
    int? skipped,
  }) {
    return SheetsAiApplyResult(
      changeId: changeId is _is.UndefinedSentinel ? this.changeId : changeId,
      label: label ?? this.label,
      cellsAffected: cellsAffected ?? this.cellsAffected,
      skipped: skipped ?? this.skipped,
    );
  }
}
