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
import '../../platform/drive/drive_item_view.dart' as _ivpffrb8;
import '../../platform/drive/import_warning_view.dart' as _ibijl4o7;
import '../../write/models/document_meta_view.dart' as _ib1lt9eb;

abstract class DocumentInfo
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DocumentInfo._({
    required this.documentUuid,
    required this.item,
    required this.headRevision,
    required this.meta,
    required this.charCount,
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.importWarnings,
  });

  factory DocumentInfo({
    required _is.UuidValue documentUuid,
    required _ivpffrb8.DriveItemView item,
    required int headRevision,
    required _ib1lt9eb.DocumentMetaView meta,
    required int charCount,
    required int wordCount,
    required DateTime createdAt,
    required DateTime updatedAt,
    List<_ibijl4o7.ImportWarningView>? importWarnings,
  }) = _DocumentInfoImpl;

  factory DocumentInfo.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocumentInfo(
      documentUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['documentUuid'],
      ),
      item: _il4umwa0.Protocol().deserialize<_ivpffrb8.DriveItemView>(
        jsonSerialization['item'],
      ),
      headRevision: jsonSerialization['headRevision'] as int,
      meta: _il4umwa0.Protocol().deserialize<_ib1lt9eb.DocumentMetaView>(
        jsonSerialization['meta'],
      ),
      charCount: jsonSerialization['charCount'] as int,
      wordCount: jsonSerialization['wordCount'] as int,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      importWarnings: jsonSerialization['importWarnings'] == null
          ? null
          : _il4umwa0.Protocol().deserialize<List<_ibijl4o7.ImportWarningView>>(
              jsonSerialization['importWarnings'],
            ),
    );
  }

  _is.UuidValue documentUuid;

  _ivpffrb8.DriveItemView item;

  int headRevision;

  _ib1lt9eb.DocumentMetaView meta;

  int charCount;

  int wordCount;

  DateTime createdAt;

  DateTime updatedAt;

  /// Warnings of an import made by the caller, shown once (Write 07 §3.2).
  List<_ibijl4o7.ImportWarningView>? importWarnings;

  /// Returns a shallow copy of this [DocumentInfo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocumentInfo copyWith({
    _is.UuidValue? documentUuid,
    _ivpffrb8.DriveItemView? item,
    int? headRevision,
    _ib1lt9eb.DocumentMetaView? meta,
    int? charCount,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<_ibijl4o7.ImportWarningView>? importWarnings =
        const _is.$UndefinedList<_ibijl4o7.ImportWarningView>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocumentInfo',
      'documentUuid': documentUuid.toJson(),
      'item': item.toJson(),
      'headRevision': headRevision,
      'meta': meta.toJson(),
      'charCount': charCount,
      'wordCount': wordCount,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (importWarnings != null)
        'importWarnings': importWarnings?.toJson(
          valueToJson: (v) => v.toJson(),
        ),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocumentInfo',
      'documentUuid': documentUuid.toJson(),
      'item': item.toJsonForProtocol(),
      'headRevision': headRevision,
      'meta': meta.toJsonForProtocol(),
      'charCount': charCount,
      'wordCount': wordCount,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (importWarnings != null)
        'importWarnings': importWarnings?.toJson(
          valueToJson: (v) => v.toJsonForProtocol(),
        ),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _DocumentInfoImpl extends DocumentInfo {
  _DocumentInfoImpl({
    required _is.UuidValue documentUuid,
    required _ivpffrb8.DriveItemView item,
    required int headRevision,
    required _ib1lt9eb.DocumentMetaView meta,
    required int charCount,
    required int wordCount,
    required DateTime createdAt,
    required DateTime updatedAt,
    List<_ibijl4o7.ImportWarningView>? importWarnings,
  }) : super._(
         documentUuid: documentUuid,
         item: item,
         headRevision: headRevision,
         meta: meta,
         charCount: charCount,
         wordCount: wordCount,
         createdAt: createdAt,
         updatedAt: updatedAt,
         importWarnings: importWarnings,
       );

  /// Returns a shallow copy of this [DocumentInfo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocumentInfo copyWith({
    _is.UuidValue? documentUuid,
    _ivpffrb8.DriveItemView? item,
    int? headRevision,
    _ib1lt9eb.DocumentMetaView? meta,
    int? charCount,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<_ibijl4o7.ImportWarningView>? importWarnings =
        const _is.$UndefinedList<_ibijl4o7.ImportWarningView>(),
  }) {
    return DocumentInfo(
      documentUuid: documentUuid ?? this.documentUuid,
      item: item ?? this.item.copyWith(),
      headRevision: headRevision ?? this.headRevision,
      meta: meta ?? this.meta.copyWith(),
      charCount: charCount ?? this.charCount,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      importWarnings: importWarnings is _is.UndefinedSentinel
          ? this.importWarnings?.map((e0) => e0.copyWith()).toList()
          : importWarnings,
    );
  }
}
