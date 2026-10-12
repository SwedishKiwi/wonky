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
import '../../platform/drive/import_warning_view.dart' as _ibijl4o7;

abstract class ExportResultView
    implements _is.SerializableModel, _is.ProtocolSerialization {
  ExportResultView._({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.pageCount,
    required this.downloadUrl,
    required this.expiresAt,
    this.inlineText,
    required this.warnings,
  });

  factory ExportResultView({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    int? pageCount,
    required String downloadUrl,
    required DateTime expiresAt,
    String? inlineText,
    required List<_ibijl4o7.ImportWarningView> warnings,
  }) = _ExportResultViewImpl;

  factory ExportResultView.fromJson(Map<String, dynamic> jsonSerialization) {
    return ExportResultView(
      fileName: jsonSerialization['fileName'] as String,
      mimeType: jsonSerialization['mimeType'] as String,
      sizeBytes: jsonSerialization['sizeBytes'] as int,
      pageCount: jsonSerialization['pageCount'] as int?,
      downloadUrl: jsonSerialization['downloadUrl'] as String,
      expiresAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['expiresAt'],
      ),
      inlineText: jsonSerialization['inlineText'] as String?,
      warnings: _il4umwa0.Protocol()
          .deserialize<List<_ibijl4o7.ImportWarningView>>(
            jsonSerialization['warnings'],
          ),
    );
  }

  String fileName;

  String mimeType;

  int sizeBytes;

  int? pageCount;

  /// Signed URL (15 min).
  String downloadUrl;

  DateTime expiresAt;

  /// Set for md/txt exports up to 1 MB.
  String? inlineText;

  List<_ibijl4o7.ImportWarningView> warnings;

  /// Returns a shallow copy of this [ExportResultView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ExportResultView copyWith({
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    int? pageCount,
    String? downloadUrl,
    DateTime? expiresAt,
    String? inlineText,
    List<_ibijl4o7.ImportWarningView>? warnings,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ExportResultView',
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      if (pageCount != null) 'pageCount': pageCount,
      'downloadUrl': downloadUrl,
      'expiresAt': expiresAt.toJson(),
      if (inlineText != null) 'inlineText': inlineText,
      'warnings': warnings.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ExportResultView',
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      if (pageCount != null) 'pageCount': pageCount,
      'downloadUrl': downloadUrl,
      'expiresAt': expiresAt.toJson(),
      if (inlineText != null) 'inlineText': inlineText,
      'warnings': warnings.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ExportResultViewImpl extends ExportResultView {
  _ExportResultViewImpl({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    int? pageCount,
    required String downloadUrl,
    required DateTime expiresAt,
    String? inlineText,
    required List<_ibijl4o7.ImportWarningView> warnings,
  }) : super._(
         fileName: fileName,
         mimeType: mimeType,
         sizeBytes: sizeBytes,
         pageCount: pageCount,
         downloadUrl: downloadUrl,
         expiresAt: expiresAt,
         inlineText: inlineText,
         warnings: warnings,
       );

  /// Returns a shallow copy of this [ExportResultView]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ExportResultView copyWith({
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    Object? pageCount = _Undefined,
    String? downloadUrl,
    DateTime? expiresAt,
    Object? inlineText = _Undefined,
    List<_ibijl4o7.ImportWarningView>? warnings,
  }) {
    return ExportResultView(
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      pageCount: pageCount is int? ? pageCount : this.pageCount,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      expiresAt: expiresAt ?? this.expiresAt,
      inlineText: inlineText is String? ? inlineText : this.inlineText,
      warnings: warnings ?? this.warnings.map((e0) => e0.copyWith()).toList(),
    );
  }
}
