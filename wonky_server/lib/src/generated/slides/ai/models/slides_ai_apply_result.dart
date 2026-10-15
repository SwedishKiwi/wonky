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

/// The outcome of applying an AI result on the server (preview calls):
/// the change of the one undo step and what the skip rule kept.
abstract class SlidesAiApplyResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SlidesAiApplyResult._({
    this.changeId,
    required this.label,
    required this.appliedCalls,
    required this.skipped,
  });

  factory SlidesAiApplyResult({
    String? changeId,
    required String label,
    required int appliedCalls,
    required int skipped,
  }) = _SlidesAiApplyResultImpl;

  factory SlidesAiApplyResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiApplyResult(
      changeId: jsonSerialization['changeId'] as String?,
      label: jsonSerialization['label'] as String,
      appliedCalls: jsonSerialization['appliedCalls'] as int,
      skipped: jsonSerialization['skipped'] as int,
    );
  }

  String? changeId;

  /// The undo label ("AI: Apply 3 suggestions").
  String label;

  int appliedCalls;

  /// Values others changed since the preview, kept as they are.
  int skipped;

  /// Returns a shallow copy of this [SlidesAiApplyResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SlidesAiApplyResult copyWith({
    String? changeId,
    String? label,
    int? appliedCalls,
    int? skipped,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiApplyResult',
      if (changeId != null) 'changeId': changeId,
      'label': label,
      'appliedCalls': appliedCalls,
      'skipped': skipped,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiApplyResult',
      if (changeId != null) 'changeId': changeId,
      'label': label,
      'appliedCalls': appliedCalls,
      'skipped': skipped,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiApplyResultImpl extends SlidesAiApplyResult {
  _SlidesAiApplyResultImpl({
    String? changeId,
    required String label,
    required int appliedCalls,
    required int skipped,
  }) : super._(
         changeId: changeId,
         label: label,
         appliedCalls: appliedCalls,
         skipped: skipped,
       );

  /// Returns a shallow copy of this [SlidesAiApplyResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SlidesAiApplyResult copyWith({
    Object? changeId = _Undefined,
    String? label,
    int? appliedCalls,
    int? skipped,
  }) {
    return SlidesAiApplyResult(
      changeId: changeId is String? ? changeId : this.changeId,
      label: label ?? this.label,
      appliedCalls: appliedCalls ?? this.appliedCalls,
      skipped: skipped ?? this.skipped,
    );
  }
}
