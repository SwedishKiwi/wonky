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

abstract class DocumentMetaView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocumentMetaView._({
    this.themeId,
    required this.pageSetupJson,
    this.language,
    this.frontMatter,
  });

  factory DocumentMetaView({
    _is.UuidValue? themeId,
    required String pageSetupJson,
    String? language,
    String? frontMatter,
  }) = _DocumentMetaViewImpl;

  factory DocumentMetaView.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocumentMetaView(
      themeId: jsonSerialization['themeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['themeId']),
      pageSetupJson: jsonSerialization['pageSetupJson'] as String,
      language: jsonSerialization['language'] as String?,
      frontMatter: jsonSerialization['frontMatter'] as String?,
    );
  }

  _is.UuidValue? themeId;

  String pageSetupJson;

  String? language;

  String? frontMatter;

  /// Returns a shallow copy of this [DocumentMetaView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocumentMetaView copyWith({
    _is.UuidValue? themeId = const _is.$UndefinedUuidValue(),
    String? pageSetupJson,
    String? language,
    String? frontMatter,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocumentMetaView',
      if (themeId != null) 'themeId': themeId?.toJson(),
      'pageSetupJson': pageSetupJson,
      if (language != null) 'language': language,
      if (frontMatter != null) 'frontMatter': frontMatter,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocumentMetaView',
      if (themeId != null) 'themeId': themeId?.toJson(),
      'pageSetupJson': pageSetupJson,
      if (language != null) 'language': language,
      if (frontMatter != null) 'frontMatter': frontMatter,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocumentMetaViewImpl extends DocumentMetaView {
  _DocumentMetaViewImpl({
    _is.UuidValue? themeId,
    required String pageSetupJson,
    String? language,
    String? frontMatter,
  }) : super._(
         themeId: themeId,
         pageSetupJson: pageSetupJson,
         language: language,
         frontMatter: frontMatter,
       );

  /// Returns a shallow copy of this [DocumentMetaView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocumentMetaView copyWith({
    _is.UuidValue? themeId = const _is.$UndefinedUuidValue(),
    String? pageSetupJson,
    Object? language = _Undefined,
    Object? frontMatter = _Undefined,
  }) {
    return DocumentMetaView(
      themeId: themeId is _is.UndefinedSentinel ? this.themeId : themeId,
      pageSetupJson: pageSetupJson ?? this.pageSetupJson,
      language: language is String? ? language : this.language,
      frontMatter: frontMatter is String? ? frontMatter : this.frontMatter,
    );
  }
}
