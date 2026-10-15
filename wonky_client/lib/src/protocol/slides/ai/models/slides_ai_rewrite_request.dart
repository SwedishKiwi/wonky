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

/// *Rewrite text* (Slides 11 §6.5): the element's text as Markdown and
/// what to do with it.
abstract class SlidesAiRewriteRequest
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SlidesAiRewriteRequest._({
    required this.mode,
    this.instruction,
    this.language,
    required this.markdown,
    this.slideTitle,
    this.role,
    this.capacityChars,
    this.previous,
  });

  factory SlidesAiRewriteRequest({
    required String mode,
    String? instruction,
    String? language,
    required String markdown,
    String? slideTitle,
    String? role,
    int? capacityChars,
    String? previous,
  }) = _SlidesAiRewriteRequestImpl;

  factory SlidesAiRewriteRequest.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return SlidesAiRewriteRequest(
      mode: jsonSerialization['mode'] as String,
      instruction: jsonSerialization['instruction'] as String?,
      language: jsonSerialization['language'] as String?,
      markdown: jsonSerialization['markdown'] as String,
      slideTitle: jsonSerialization['slideTitle'] as String?,
      role: jsonSerialization['role'] as String?,
      capacityChars: jsonSerialization['capacityChars'] as int?,
      previous: jsonSerialization['previous'] as String?,
    );
  }

  /// shorter | longer | clearer | formal | grammar | punchier | bullets |
  /// paragraph | translate | custom.
  String mode;

  String? instruction;

  /// Target language of translate.
  String? language;

  String markdown;

  String? slideTitle;

  /// The element's placeholder role (title, body, …) or null.
  String? role;

  /// Characters that fit the box at ≥ 80 % of the current size.
  int? capacityChars;

  /// The previous result to refine ("even shorter").
  String? previous;

  /// Returns a shallow copy of this [SlidesAiRewriteRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SlidesAiRewriteRequest copyWith({
    String? mode,
    String? instruction,
    String? language,
    String? markdown,
    String? slideTitle,
    String? role,
    int? capacityChars,
    String? previous,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiRewriteRequest',
      'mode': mode,
      if (instruction != null) 'instruction': instruction,
      if (language != null) 'language': language,
      'markdown': markdown,
      if (slideTitle != null) 'slideTitle': slideTitle,
      if (role != null) 'role': role,
      if (capacityChars != null) 'capacityChars': capacityChars,
      if (previous != null) 'previous': previous,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiRewriteRequest',
      'mode': mode,
      if (instruction != null) 'instruction': instruction,
      if (language != null) 'language': language,
      'markdown': markdown,
      if (slideTitle != null) 'slideTitle': slideTitle,
      if (role != null) 'role': role,
      if (capacityChars != null) 'capacityChars': capacityChars,
      if (previous != null) 'previous': previous,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiRewriteRequestImpl extends SlidesAiRewriteRequest {
  _SlidesAiRewriteRequestImpl({
    required String mode,
    String? instruction,
    String? language,
    required String markdown,
    String? slideTitle,
    String? role,
    int? capacityChars,
    String? previous,
  }) : super._(
         mode: mode,
         instruction: instruction,
         language: language,
         markdown: markdown,
         slideTitle: slideTitle,
         role: role,
         capacityChars: capacityChars,
         previous: previous,
       );

  /// Returns a shallow copy of this [SlidesAiRewriteRequest]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SlidesAiRewriteRequest copyWith({
    String? mode,
    Object? instruction = _Undefined,
    Object? language = _Undefined,
    String? markdown,
    Object? slideTitle = _Undefined,
    Object? role = _Undefined,
    Object? capacityChars = _Undefined,
    Object? previous = _Undefined,
  }) {
    return SlidesAiRewriteRequest(
      mode: mode ?? this.mode,
      instruction: instruction is String? ? instruction : this.instruction,
      language: language is String? ? language : this.language,
      markdown: markdown ?? this.markdown,
      slideTitle: slideTitle is String? ? slideTitle : this.slideTitle,
      role: role is String? ? role : this.role,
      capacityChars: capacityChars is int? ? capacityChars : this.capacityChars,
      previous: previous is String? ? previous : this.previous,
    );
  }
}
