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
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/drive/template_category.dart' as _i4yf368z;
import '../../platform/drive/template_preview_style.dart' as _i23vdgk2;

/// A template in the gallery (`drive.listTemplates`, specs/05 §3.1).
abstract class TemplateView
    implements _is.SerializableModel, _is.ProtocolSerialization {
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
    this.themeKey,
    this.previewStyle,
    int? sizeBytes,
  }) : sizeBytes = sizeBytes ?? 0;

  factory TemplateView({
    required _is.UuidValue uuid,
    String? key,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required String description,
    required _i4yf368z.TemplateCategory category,
    required bool builtin,
    required String previewText,
    _is.UuidValue? thumbnailFileId,
    String? themeKey,
    _i23vdgk2.TemplatePreviewStyle? previewStyle,
    int? sizeBytes,
  }) = _TemplateViewImpl;

  factory TemplateView.fromJson(Map<String, dynamic> jsonSerialization) {
    return TemplateView(
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      key: jsonSerialization['key'] as String?,
      kind: _i26ubj99.DriveItemKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String,
      description: jsonSerialization['description'] as String,
      category: _i4yf368z.TemplateCategory.fromJson(
        (jsonSerialization['category'] as String),
      ),
      builtin: _is.BoolJsonExtension.fromJson(jsonSerialization['builtin']),
      previewText: jsonSerialization['previewText'] as String,
      thumbnailFileId: jsonSerialization['thumbnailFileId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['thumbnailFileId'],
            ),
      themeKey: jsonSerialization['themeKey'] as String?,
      previewStyle: jsonSerialization['previewStyle'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<_i23vdgk2.TemplatePreviewStyle>(
              jsonSerialization['previewStyle'],
            ),
      sizeBytes: jsonSerialization['sizeBytes'] as int?,
    );
  }

  /// Built-ins: UUIDv5(url, "wonky-template:<key>"); published items: the item uuid.
  _is.UuidValue uuid;

  /// Stable key of built-in templates, e.g. "write.meeting-notes".
  String? key;

  _i26ubj99.DriveItemKind kind;

  String name;

  String description;

  _i4yf368z.TemplateCategory category;

  bool builtin;

  /// Short plain-text preview for the template card.
  String previewText;

  _is.UuidValue? thumbnailFileId;

  /// Key of the built-in Write theme a document template creates documents
  /// with (e.g. "classic-serif"), if any.
  String? themeKey;

  /// Colors and traits of the card's miniature page; null = neutral page.
  _i23vdgk2.TemplatePreviewStyle? previewStyle;

  /// (v2) Counted size of an item created from this template (Drive 03
  /// §6.5: disabled with "Not enough storage" when it doesn't fit).
  int sizeBytes;

  /// Returns a shallow copy of this [TemplateView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  TemplateView copyWith({
    _is.UuidValue? uuid,
    String? key,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    String? description,
    _i4yf368z.TemplateCategory? category,
    bool? builtin,
    String? previewText,
    _is.UuidValue? thumbnailFileId = const _is.$UndefinedUuidValue(),
    String? themeKey,
    _i23vdgk2.TemplatePreviewStyle? previewStyle =
        const _UndefinedTemplateView$previewStyle(),
    int? sizeBytes,
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
      if (themeKey != null) 'themeKey': themeKey,
      if (previewStyle != null) 'previewStyle': previewStyle?.toJson(),
      'sizeBytes': sizeBytes,
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
      if (themeKey != null) 'themeKey': themeKey,
      if (previewStyle != null)
        'previewStyle': previewStyle?.toJsonForProtocol(),
      'sizeBytes': sizeBytes,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedTemplateView$previewStyle extends _is.UndefinedSentinel
    implements _i23vdgk2.TemplatePreviewStyle {
  const _UndefinedTemplateView$previewStyle();
}

class _TemplateViewImpl extends TemplateView {
  _TemplateViewImpl({
    required _is.UuidValue uuid,
    String? key,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required String description,
    required _i4yf368z.TemplateCategory category,
    required bool builtin,
    required String previewText,
    _is.UuidValue? thumbnailFileId,
    String? themeKey,
    _i23vdgk2.TemplatePreviewStyle? previewStyle,
    int? sizeBytes,
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
         themeKey: themeKey,
         previewStyle: previewStyle,
         sizeBytes: sizeBytes,
       );

  /// Returns a shallow copy of this [TemplateView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  TemplateView copyWith({
    _is.UuidValue? uuid,
    Object? key = _Undefined,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    String? description,
    _i4yf368z.TemplateCategory? category,
    bool? builtin,
    String? previewText,
    _is.UuidValue? thumbnailFileId = const _is.$UndefinedUuidValue(),
    Object? themeKey = _Undefined,
    _i23vdgk2.TemplatePreviewStyle? previewStyle =
        const _UndefinedTemplateView$previewStyle(),
    int? sizeBytes,
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
      thumbnailFileId: thumbnailFileId is _is.UndefinedSentinel
          ? this.thumbnailFileId
          : thumbnailFileId,
      themeKey: themeKey is String? ? themeKey : this.themeKey,
      previewStyle: previewStyle is _is.UndefinedSentinel
          ? this.previewStyle?.copyWith()
          : previewStyle,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}
