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
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/drive/template_category.dart' as _i4yf368z;

/// A template in the gallery (`drive.listTemplates`, specs/05 §3.1).
abstract class TemplateView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  TemplateView._({
    required this.uuid,
    this.key,
    required this.kind,
    required this.name,
    required this.description,
    required this.category,
    required this.builtin,
    required this.previewText,
    this.thumbnailFileId,
  });

  factory TemplateView({
    required _isc.UuidValue uuid,
    String? key,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required String description,
    required _i4yf368z.TemplateCategory category,
    required bool builtin,
    required String previewText,
    _isc.UuidValue? thumbnailFileId,
  }) = _TemplateViewImpl;

  factory TemplateView.fromJson(Map<String, dynamic> jsonSerialization) {
    return TemplateView(
      uuid: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      key: jsonSerialization['key'] as String?,
      kind: _i26ubj99.DriveItemKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String,
      category: _i4yf368z.TemplateCategory.fromJson(
        (jsonSerialization['category'] as String),
      ),
      builtin: _isc.BoolJsonExtension.fromJson(jsonSerialization['builtin']),
      previewText: jsonSerialization['previewText'] as String,
      thumbnailFileId: jsonSerialization['thumbnailFileId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(
              jsonSerialization['thumbnailFileId'],
            ),
    );
  }

  /// Built-ins: UUIDv5(url, "wonky-template:<key>"); published items: the item uuid.
  _isc.UuidValue uuid;

  /// Stable key of built-in templates, e.g. "write.meeting-notes".
  String? key;

  _i26ubj99.DriveItemKind kind;

  String name;

  String description;

  _i4yf368z.TemplateCategory category;

  bool builtin;

  /// Short plain-text preview for the template card.
  String previewText;

  _isc.UuidValue? thumbnailFileId;

  /// Returns a shallow copy of this [TemplateView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  TemplateView copyWith({
    _isc.UuidValue? uuid,
    String? key,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    String? description,
    _i4yf368z.TemplateCategory? category,
    bool? builtin,
    String? previewText,
    _isc.UuidValue? thumbnailFileId = const _isc.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TemplateView',
      'uuid': uuid.toJson(),
      if (key != null) 'key': key,
      'kind': kind.toJson(),
      'name': name,
      'description': description,
      'category': category.toJson(),
      'builtin': builtin,
      'previewText': previewText,
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'TemplateView',
      'uuid': uuid.toJson(),
      if (key != null) 'key': key,
      'kind': kind.toJson(),
      'name': name,
      'description': description,
      'category': category.toJson(),
      'builtin': builtin,
      'previewText': previewText,
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TemplateViewImpl extends TemplateView {
  _TemplateViewImpl({
    required _isc.UuidValue uuid,
    String? key,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required String description,
    required _i4yf368z.TemplateCategory category,
    required bool builtin,
    required String previewText,
    _isc.UuidValue? thumbnailFileId,
  }) : super._(
         uuid: uuid,
         key: key,
         kind: kind,
         name: name,
         description: description,
         category: category,
         builtin: builtin,
         previewText: previewText,
         thumbnailFileId: thumbnailFileId,
       );

  /// Returns a shallow copy of this [TemplateView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  TemplateView copyWith({
    _isc.UuidValue? uuid,
    Object? key = _Undefined,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    String? description,
    _i4yf368z.TemplateCategory? category,
    bool? builtin,
    String? previewText,
    _isc.UuidValue? thumbnailFileId = const _isc.$UndefinedUuidValue(),
  }) {
    return TemplateView(
      uuid: uuid ?? this.uuid,
      key: key is String? ? key : this.key,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      builtin: builtin ?? this.builtin,
      previewText: previewText ?? this.previewText,
      thumbnailFileId: thumbnailFileId is _isc.UndefinedSentinel
          ? this.thumbnailFileId
          : thumbnailFileId,
    );
  }
}
