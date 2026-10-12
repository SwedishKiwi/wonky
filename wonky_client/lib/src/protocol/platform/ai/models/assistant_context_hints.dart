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
import '../../../platform/ai/models/ai_apply_mode.dart' as _iinkwvx0;

/// Volatile context of a chat message (Write 09 §5.6).
abstract class AssistantContextHints
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantContextHints._({
    this.documentSessionId,
    required this.applyMode,
    this.revision,
    this.selectionStart,
    this.selectionLength,
    this.selectionText,
    this.caretHeadingPath,
    bool? includeComments,
    this.localTime,
  }) : includeComments = includeComments ?? false;

  factory AssistantContextHints({
    String? documentSessionId,
    required _iinkwvx0.AiApplyMode applyMode,
    int? revision,
    int? selectionStart,
    int? selectionLength,
    String? selectionText,
    String? caretHeadingPath,
    bool? includeComments,
    String? localTime,
  }) = _AssistantContextHintsImpl;

  factory AssistantContextHints.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AssistantContextHints(
      documentSessionId: jsonSerialization['documentSessionId'] as String?,
      applyMode: _iinkwvx0.AiApplyMode.fromJson(
        (jsonSerialization['applyMode'] as String),
      ),
      revision: jsonSerialization['revision'] as int?,
      selectionStart: jsonSerialization['selectionStart'] as int?,
      selectionLength: jsonSerialization['selectionLength'] as int?,
      selectionText: jsonSerialization['selectionText'] as String?,
      caretHeadingPath: jsonSerialization['caretHeadingPath'] as String?,
      includeComments: jsonSerialization['includeComments'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['includeComments'],
            ),
      localTime: jsonSerialization['localTime'] as String?,
    );
  }

  /// The client's document stream session (`DocInit.sessionId`): ops of
  /// the run carry it as `onBehalfOfSessionId` (one undo step there).
  String? documentSessionId;

  _iinkwvx0.AiApplyMode applyMode;

  /// Selection in Delta offsets of [revision] plus its plain text.
  int? revision;

  int? selectionStart;

  int? selectionLength;

  String? selectionText;

  /// Heading path of the caret ("Plan › Budget").
  String? caretHeadingPath;

  /// Include open comments (quick prompt "Address comments").
  bool includeComments;

  /// The user's local date/time ("2026-10-13 14:05 Europe/Stockholm").
  String? localTime;

  /// Returns a shallow copy of this [AssistantContextHints]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantContextHints copyWith({
    String? documentSessionId,
    _iinkwvx0.AiApplyMode? applyMode,
    int? revision,
    int? selectionStart,
    int? selectionLength,
    String? selectionText,
    String? caretHeadingPath,
    bool? includeComments,
    String? localTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantContextHints',
      if (documentSessionId != null) 'documentSessionId': documentSessionId,
      'applyMode': applyMode.toJson(),
      if (revision != null) 'revision': revision,
      if (selectionStart != null) 'selectionStart': selectionStart,
      if (selectionLength != null) 'selectionLength': selectionLength,
      if (selectionText != null) 'selectionText': selectionText,
      if (caretHeadingPath != null) 'caretHeadingPath': caretHeadingPath,
      'includeComments': includeComments,
      if (localTime != null) 'localTime': localTime,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantContextHints',
      if (documentSessionId != null) 'documentSessionId': documentSessionId,
      'applyMode': applyMode.toJson(),
      if (revision != null) 'revision': revision,
      if (selectionStart != null) 'selectionStart': selectionStart,
      if (selectionLength != null) 'selectionLength': selectionLength,
      if (selectionText != null) 'selectionText': selectionText,
      if (caretHeadingPath != null) 'caretHeadingPath': caretHeadingPath,
      'includeComments': includeComments,
      if (localTime != null) 'localTime': localTime,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantContextHintsImpl extends AssistantContextHints {
  _AssistantContextHintsImpl({
    String? documentSessionId,
    required _iinkwvx0.AiApplyMode applyMode,
    int? revision,
    int? selectionStart,
    int? selectionLength,
    String? selectionText,
    String? caretHeadingPath,
    bool? includeComments,
    String? localTime,
  }) : super._(
         documentSessionId: documentSessionId,
         applyMode: applyMode,
         revision: revision,
         selectionStart: selectionStart,
         selectionLength: selectionLength,
         selectionText: selectionText,
         caretHeadingPath: caretHeadingPath,
         includeComments: includeComments,
         localTime: localTime,
       );

  /// Returns a shallow copy of this [AssistantContextHints]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantContextHints copyWith({
    Object? documentSessionId = _Undefined,
    _iinkwvx0.AiApplyMode? applyMode,
    Object? revision = _Undefined,
    Object? selectionStart = _Undefined,
    Object? selectionLength = _Undefined,
    Object? selectionText = _Undefined,
    Object? caretHeadingPath = _Undefined,
    bool? includeComments,
    Object? localTime = _Undefined,
  }) {
    return AssistantContextHints(
      documentSessionId: documentSessionId is String?
          ? documentSessionId
          : this.documentSessionId,
      applyMode: applyMode ?? this.applyMode,
      revision: revision is int? ? revision : this.revision,
      selectionStart: selectionStart is int?
          ? selectionStart
          : this.selectionStart,
      selectionLength: selectionLength is int?
          ? selectionLength
          : this.selectionLength,
      selectionText: selectionText is String?
          ? selectionText
          : this.selectionText,
      caretHeadingPath: caretHeadingPath is String?
          ? caretHeadingPath
          : this.caretHeadingPath,
      includeComments: includeComments ?? this.includeComments,
      localTime: localTime is String? ? localTime : this.localTime,
    );
  }
}
