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

/// Proposed speaker notes of one slide (Slides 11 §6.7).
abstract class SlidesAiNote
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SlidesAiNote._({
    required this.slideId,
    required this.markdown,
    this.existing,
  });

  factory SlidesAiNote({
    required String slideId,
    required String markdown,
    String? existing,
  }) = _SlidesAiNoteImpl;

  factory SlidesAiNote.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiNote(
      slideId: jsonSerialization['slideId'] as String,
      markdown: jsonSerialization['markdown'] as String,
      existing: jsonSerialization['existing'] as String?,
    );
  }

  String slideId;

  String markdown;

  /// The slide's notes when the proposal was made (Markdown).
  String? existing;

  /// Returns a shallow copy of this [SlidesAiNote]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SlidesAiNote copyWith({
    String? slideId,
    String? markdown,
    String? existing,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiNote',
      'slideId': slideId,
      'markdown': markdown,
      if (existing != null) 'existing': existing,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiNote',
      'slideId': slideId,
      'markdown': markdown,
      if (existing != null) 'existing': existing,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiNoteImpl extends SlidesAiNote {
  _SlidesAiNoteImpl({
    required String slideId,
    required String markdown,
    String? existing,
  }) : super._(
         slideId: slideId,
         markdown: markdown,
         existing: existing,
       );

  /// Returns a shallow copy of this [SlidesAiNote]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SlidesAiNote copyWith({
    String? slideId,
    String? markdown,
    Object? existing = _Undefined,
  }) {
    return SlidesAiNote(
      slideId: slideId ?? this.slideId,
      markdown: markdown ?? this.markdown,
      existing: existing is String? ? existing : this.existing,
    );
  }
}
