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

/// A proposed alt text of one element (Slides 11 §6.8), or why there is
/// none (`skipped`: noImageSupport, unsupported, empty).
abstract class SlidesAiAltText
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SlidesAiAltText._({
    required this.elementId,
    this.slideId,
    required this.kind,
    this.altText,
    this.skipped,
  });

  factory SlidesAiAltText({
    required String elementId,
    String? slideId,
    required String kind,
    String? altText,
    String? skipped,
  }) = _SlidesAiAltTextImpl;

  factory SlidesAiAltText.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiAltText(
      elementId: jsonSerialization['elementId'] as String,
      slideId: jsonSerialization['slideId'] as String?,
      kind: jsonSerialization['kind'] as String,
      altText: jsonSerialization['altText'] as String?,
      skipped: jsonSerialization['skipped'] as String?,
    );
  }

  String elementId;

  String? slideId;

  String kind;

  String? altText;

  String? skipped;

  /// Returns a shallow copy of this [SlidesAiAltText]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SlidesAiAltText copyWith({
    String? elementId,
    String? slideId,
    String? kind,
    String? altText,
    String? skipped,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiAltText',
      'elementId': elementId,
      if (slideId != null) 'slideId': slideId,
      'kind': kind,
      if (altText != null) 'altText': altText,
      if (skipped != null) 'skipped': skipped,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiAltText',
      'elementId': elementId,
      if (slideId != null) 'slideId': slideId,
      'kind': kind,
      if (altText != null) 'altText': altText,
      if (skipped != null) 'skipped': skipped,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiAltTextImpl extends SlidesAiAltText {
  _SlidesAiAltTextImpl({
    required String elementId,
    String? slideId,
    required String kind,
    String? altText,
    String? skipped,
  }) : super._(
         elementId: elementId,
         slideId: slideId,
         kind: kind,
         altText: altText,
         skipped: skipped,
       );

  /// Returns a shallow copy of this [SlidesAiAltText]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SlidesAiAltText copyWith({
    String? elementId,
    Object? slideId = _Undefined,
    String? kind,
    Object? altText = _Undefined,
    Object? skipped = _Undefined,
  }) {
    return SlidesAiAltText(
      elementId: elementId ?? this.elementId,
      slideId: slideId is String? ? slideId : this.slideId,
      kind: kind ?? this.kind,
      altText: altText is String? ? altText : this.altText,
      skipped: skipped is String? ? skipped : this.skipped,
    );
  }
}
