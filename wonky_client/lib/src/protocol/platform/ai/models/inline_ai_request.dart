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

/// An inline AI request (Write 09 §5.3–5.5): rewrite a selection, continue
/// writing or a document-level action. Offsets are Delta offsets of
/// [revision].
abstract class InlineAiRequest
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  InlineAiRequest._({
    required this.itemUuid,
    required this.action,
    this.revision,
    this.start,
    this.length,
    this.selectedMarkdown,
    this.contextBefore,
    this.contextAfter,
    this.instruction,
    this.tone,
    this.targetLanguage,
    this.summaryLength,
    this.previousOutput,
    this.maxWords,
  });

  factory InlineAiRequest({
    required _isc.UuidValue itemUuid,
    required String action,
    int? revision,
    int? start,
    int? length,
    String? selectedMarkdown,
    String? contextBefore,
    String? contextAfter,
    String? instruction,
    String? tone,
    String? targetLanguage,
    String? summaryLength,
    String? previousOutput,
    int? maxWords,
  }) = _InlineAiRequestImpl;

  factory InlineAiRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return InlineAiRequest(
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      action: jsonSerialization['action'] as String,
      revision: jsonSerialization['revision'] as int?,
      start: jsonSerialization['start'] as int?,
      length: jsonSerialization['length'] as int?,
      selectedMarkdown: jsonSerialization['selectedMarkdown'] as String?,
      contextBefore: jsonSerialization['contextBefore'] as String?,
      contextAfter: jsonSerialization['contextAfter'] as String?,
      instruction: jsonSerialization['instruction'] as String?,
      tone: jsonSerialization['tone'] as String?,
      targetLanguage: jsonSerialization['targetLanguage'] as String?,
      summaryLength: jsonSerialization['summaryLength'] as String?,
      previousOutput: jsonSerialization['previousOutput'] as String?,
      maxWords: jsonSerialization['maxWords'] as int?,
    );
  }

  _isc.UuidValue itemUuid;

  /// improve, fixGrammar, shorter, longer, tone, translate, custom,
  /// explain, summarize, continueWriting, summarizeDocument,
  /// generateOutline.
  String action;

  int? revision;

  int? start;

  int? length;

  String? selectedMarkdown;

  String? contextBefore;

  String? contextAfter;

  String? instruction;

  String? tone;

  String? targetLanguage;

  /// short | medium | detailed (summarizeDocument).
  String? summaryLength;

  /// Refinement: the previous output to change.
  String? previousOutput;

  int? maxWords;

  /// Returns a shallow copy of this [InlineAiRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  InlineAiRequest copyWith({
    _isc.UuidValue? itemUuid,
    String? action,
    int? revision,
    int? start,
    int? length,
    String? selectedMarkdown,
    String? contextBefore,
    String? contextAfter,
    String? instruction,
    String? tone,
    String? targetLanguage,
    String? summaryLength,
    String? previousOutput,
    int? maxWords,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InlineAiRequest',
      'itemUuid': itemUuid.toJson(),
      'action': action,
      if (revision != null) 'revision': revision,
      if (start != null) 'start': start,
      if (length != null) 'length': length,
      if (selectedMarkdown != null) 'selectedMarkdown': selectedMarkdown,
      if (contextBefore != null) 'contextBefore': contextBefore,
      if (contextAfter != null) 'contextAfter': contextAfter,
      if (instruction != null) 'instruction': instruction,
      if (tone != null) 'tone': tone,
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (summaryLength != null) 'summaryLength': summaryLength,
      if (previousOutput != null) 'previousOutput': previousOutput,
      if (maxWords != null) 'maxWords': maxWords,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InlineAiRequest',
      'itemUuid': itemUuid.toJson(),
      'action': action,
      if (revision != null) 'revision': revision,
      if (start != null) 'start': start,
      if (length != null) 'length': length,
      if (selectedMarkdown != null) 'selectedMarkdown': selectedMarkdown,
      if (contextBefore != null) 'contextBefore': contextBefore,
      if (contextAfter != null) 'contextAfter': contextAfter,
      if (instruction != null) 'instruction': instruction,
      if (tone != null) 'tone': tone,
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (summaryLength != null) 'summaryLength': summaryLength,
      if (previousOutput != null) 'previousOutput': previousOutput,
      if (maxWords != null) 'maxWords': maxWords,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InlineAiRequestImpl extends InlineAiRequest {
  _InlineAiRequestImpl({
    required _isc.UuidValue itemUuid,
    required String action,
    int? revision,
    int? start,
    int? length,
    String? selectedMarkdown,
    String? contextBefore,
    String? contextAfter,
    String? instruction,
    String? tone,
    String? targetLanguage,
    String? summaryLength,
    String? previousOutput,
    int? maxWords,
  }) : super._(
         itemUuid: itemUuid,
         action: action,
         revision: revision,
         start: start,
         length: length,
         selectedMarkdown: selectedMarkdown,
         contextBefore: contextBefore,
         contextAfter: contextAfter,
         instruction: instruction,
         tone: tone,
         targetLanguage: targetLanguage,
         summaryLength: summaryLength,
         previousOutput: previousOutput,
         maxWords: maxWords,
       );

  /// Returns a shallow copy of this [InlineAiRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  InlineAiRequest copyWith({
    _isc.UuidValue? itemUuid,
    String? action,
    Object? revision = _Undefined,
    Object? start = _Undefined,
    Object? length = _Undefined,
    Object? selectedMarkdown = _Undefined,
    Object? contextBefore = _Undefined,
    Object? contextAfter = _Undefined,
    Object? instruction = _Undefined,
    Object? tone = _Undefined,
    Object? targetLanguage = _Undefined,
    Object? summaryLength = _Undefined,
    Object? previousOutput = _Undefined,
    Object? maxWords = _Undefined,
  }) {
    return InlineAiRequest(
      itemUuid: itemUuid ?? this.itemUuid,
      action: action ?? this.action,
      revision: revision is int? ? revision : this.revision,
      start: start is int? ? start : this.start,
      length: length is int? ? length : this.length,
      selectedMarkdown: selectedMarkdown is String?
          ? selectedMarkdown
          : this.selectedMarkdown,
      contextBefore: contextBefore is String?
          ? contextBefore
          : this.contextBefore,
      contextAfter: contextAfter is String? ? contextAfter : this.contextAfter,
      instruction: instruction is String? ? instruction : this.instruction,
      tone: tone is String? ? tone : this.tone,
      targetLanguage: targetLanguage is String?
          ? targetLanguage
          : this.targetLanguage,
      summaryLength: summaryLength is String?
          ? summaryLength
          : this.summaryLength,
      previousOutput: previousOutput is String?
          ? previousOutput
          : this.previousOutput,
      maxWords: maxWords is int? ? maxWords : this.maxWords,
    );
  }
}
