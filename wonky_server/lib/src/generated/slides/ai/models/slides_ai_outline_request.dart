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

/// *Generate presentation* step 1 (Slides 11 §6.4): what the outline is
/// about and how it should look.
abstract class SlidesAiOutlineRequest
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SlidesAiOutlineRequest._({
    required this.source,
    required this.text,
    this.slideCount,
    this.audience,
    this.tone,
    this.language,
    bool? speakerNotes,
    bool? groups,
    bool? keepWording,
    this.outlineJson,
    this.slideIndex,
    this.instruction,
  }) : speakerNotes = speakerNotes ?? true,
       groups = groups ?? true,
       keepWording = keepWording ?? false;

  factory SlidesAiOutlineRequest({
    required String source,
    required String text,
    int? slideCount,
    String? audience,
    String? tone,
    String? language,
    bool? speakerNotes,
    bool? groups,
    bool? keepWording,
    String? outlineJson,
    int? slideIndex,
    String? instruction,
  }) = _SlidesAiOutlineRequestImpl;

  factory SlidesAiOutlineRequest.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return SlidesAiOutlineRequest(
      source: jsonSerialization['source'] as String,
      text: jsonSerialization['text'] as String,
      slideCount: jsonSerialization['slideCount'] as int?,
      audience: jsonSerialization['audience'] as String?,
      tone: jsonSerialization['tone'] as String?,
      language: jsonSerialization['language'] as String?,
      speakerNotes: jsonSerialization['speakerNotes'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['speakerNotes']),
      groups: jsonSerialization['groups'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['groups']),
      keepWording: jsonSerialization['keepWording'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['keepWording']),
      outlineJson: jsonSerialization['outlineJson'] as String?,
      slideIndex: jsonSerialization['slideIndex'] as int?,
      instruction: jsonSerialization['instruction'] as String?,
    );
  }

  /// prompt | outline (pasted bullets or deck-outline Markdown).
  String source;

  /// The prompt, or the pasted outline.
  String text;

  /// Wanted slide count (null = the model decides).
  int? slideCount;

  String? audience;

  String? tone;

  /// Language name ("English"); null = the language of the text.
  String? language;

  bool speakerNotes;

  bool groups;

  /// Outline source: only structure and complete the user's text.
  bool keepWording;

  /// Regenerate one slide: its index in the outline (0-based) and the
  /// current outline JSON plus an instruction.
  String? outlineJson;

  int? slideIndex;

  String? instruction;

  /// Returns a shallow copy of this [SlidesAiOutlineRequest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SlidesAiOutlineRequest copyWith({
    String? source,
    String? text,
    int? slideCount,
    String? audience,
    String? tone,
    String? language,
    bool? speakerNotes,
    bool? groups,
    bool? keepWording,
    String? outlineJson,
    int? slideIndex,
    String? instruction,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiOutlineRequest',
      'source': source,
      'text': text,
      if (slideCount != null) 'slideCount': slideCount,
      if (audience != null) 'audience': audience,
      if (tone != null) 'tone': tone,
      if (language != null) 'language': language,
      'speakerNotes': speakerNotes,
      'groups': groups,
      'keepWording': keepWording,
      if (outlineJson != null) 'outlineJson': outlineJson,
      if (slideIndex != null) 'slideIndex': slideIndex,
      if (instruction != null) 'instruction': instruction,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiOutlineRequest',
      'source': source,
      'text': text,
      if (slideCount != null) 'slideCount': slideCount,
      if (audience != null) 'audience': audience,
      if (tone != null) 'tone': tone,
      if (language != null) 'language': language,
      'speakerNotes': speakerNotes,
      'groups': groups,
      'keepWording': keepWording,
      if (outlineJson != null) 'outlineJson': outlineJson,
      if (slideIndex != null) 'slideIndex': slideIndex,
      if (instruction != null) 'instruction': instruction,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiOutlineRequestImpl extends SlidesAiOutlineRequest {
  _SlidesAiOutlineRequestImpl({
    required String source,
    required String text,
    int? slideCount,
    String? audience,
    String? tone,
    String? language,
    bool? speakerNotes,
    bool? groups,
    bool? keepWording,
    String? outlineJson,
    int? slideIndex,
    String? instruction,
  }) : super._(
         source: source,
         text: text,
         slideCount: slideCount,
         audience: audience,
         tone: tone,
         language: language,
         speakerNotes: speakerNotes,
         groups: groups,
         keepWording: keepWording,
         outlineJson: outlineJson,
         slideIndex: slideIndex,
         instruction: instruction,
       );

  /// Returns a shallow copy of this [SlidesAiOutlineRequest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SlidesAiOutlineRequest copyWith({
    String? source,
    String? text,
    Object? slideCount = _Undefined,
    Object? audience = _Undefined,
    Object? tone = _Undefined,
    Object? language = _Undefined,
    bool? speakerNotes,
    bool? groups,
    bool? keepWording,
    Object? outlineJson = _Undefined,
    Object? slideIndex = _Undefined,
    Object? instruction = _Undefined,
  }) {
    return SlidesAiOutlineRequest(
      source: source ?? this.source,
      text: text ?? this.text,
      slideCount: slideCount is int? ? slideCount : this.slideCount,
      audience: audience is String? ? audience : this.audience,
      tone: tone is String? ? tone : this.tone,
      language: language is String? ? language : this.language,
      speakerNotes: speakerNotes ?? this.speakerNotes,
      groups: groups ?? this.groups,
      keepWording: keepWording ?? this.keepWording,
      outlineJson: outlineJson is String? ? outlineJson : this.outlineJson,
      slideIndex: slideIndex is int? ? slideIndex : this.slideIndex,
      instruction: instruction is String? ? instruction : this.instruction,
    );
  }
}
