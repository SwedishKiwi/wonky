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
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;
import '../../../platform/ai/models/proofread_issue.dart' as _il2uitfb;

abstract class ProofreadEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ProofreadEvent._({
    required this.type,
    this.issues,
    this.sectionsDone,
    this.sectionsTotal,
    this.revision,
    this.error,
    this.errorCode,
  });

  factory ProofreadEvent({
    required String type,
    List<_il2uitfb.ProofreadIssue>? issues,
    int? sectionsDone,
    int? sectionsTotal,
    int? revision,
    String? error,
    String? errorCode,
  }) = _ProofreadEventImpl;

  factory ProofreadEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProofreadEvent(
      type: jsonSerialization['type'] as String,
      issues: jsonSerialization['issues'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<_il2uitfb.ProofreadIssue>>(
              jsonSerialization['issues'],
            ),
      sectionsDone: jsonSerialization['sectionsDone'] as int?,
      sectionsTotal: jsonSerialization['sectionsTotal'] as int?,
      revision: jsonSerialization['revision'] as int?,
      error: jsonSerialization['error'] as String?,
      errorCode: jsonSerialization['errorCode'] as String?,
    );
  }

  /// issues | done | refusal | error
  String type;

  List<_il2uitfb.ProofreadIssue>? issues;

  int? sectionsDone;

  int? sectionsTotal;

  int? revision;

  String? error;

  String? errorCode;

  /// Returns a shallow copy of this [ProofreadEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ProofreadEvent copyWith({
    String? type,
    List<_il2uitfb.ProofreadIssue>? issues =
        const _is.$UndefinedList<_il2uitfb.ProofreadIssue>(),
    int? sectionsDone,
    int? sectionsTotal,
    int? revision,
    String? error,
    String? errorCode,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProofreadEvent',
      'type': type,
      if (issues != null)
        'issues': issues?.toJson(valueToJson: (v) => v.toJson()),
      if (sectionsDone != null) 'sectionsDone': sectionsDone,
      if (sectionsTotal != null) 'sectionsTotal': sectionsTotal,
      if (revision != null) 'revision': revision,
      if (error != null) 'error': error,
      if (errorCode != null) 'errorCode': errorCode,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProofreadEvent',
      'type': type,
      if (issues != null)
        'issues': issues?.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (sectionsDone != null) 'sectionsDone': sectionsDone,
      if (sectionsTotal != null) 'sectionsTotal': sectionsTotal,
      if (revision != null) 'revision': revision,
      if (error != null) 'error': error,
      if (errorCode != null) 'errorCode': errorCode,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProofreadEventImpl extends ProofreadEvent {
  _ProofreadEventImpl({
    required String type,
    List<_il2uitfb.ProofreadIssue>? issues,
    int? sectionsDone,
    int? sectionsTotal,
    int? revision,
    String? error,
    String? errorCode,
  }) : super._(
         type: type,
         issues: issues,
         sectionsDone: sectionsDone,
         sectionsTotal: sectionsTotal,
         revision: revision,
         error: error,
         errorCode: errorCode,
       );

  /// Returns a shallow copy of this [ProofreadEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ProofreadEvent copyWith({
    String? type,
    List<_il2uitfb.ProofreadIssue>? issues =
        const _is.$UndefinedList<_il2uitfb.ProofreadIssue>(),
    Object? sectionsDone = _Undefined,
    Object? sectionsTotal = _Undefined,
    Object? revision = _Undefined,
    Object? error = _Undefined,
    Object? errorCode = _Undefined,
  }) {
    return ProofreadEvent(
      type: type ?? this.type,
      issues: issues is _is.UndefinedSentinel
          ? this.issues?.map((e0) => e0.copyWith()).toList()
          : issues,
      sectionsDone: sectionsDone is int? ? sectionsDone : this.sectionsDone,
      sectionsTotal: sectionsTotal is int? ? sectionsTotal : this.sectionsTotal,
      revision: revision is int? ? revision : this.revision,
      error: error is String? ? error : this.error,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
    );
  }
}
