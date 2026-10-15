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

abstract class FilePreviewFutureCallGenerateModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  FilePreviewFutureCallGenerateModel._({required this.itemId});

  factory FilePreviewFutureCallGenerateModel({required int itemId}) =
      _FilePreviewFutureCallGenerateModelImpl;

  factory FilePreviewFutureCallGenerateModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return FilePreviewFutureCallGenerateModel(
      itemId: jsonSerialization['itemId'] as int,
    );
  }

  int itemId;

  /// Returns a shallow copy of this [FilePreviewFutureCallGenerateModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  FilePreviewFutureCallGenerateModel copyWith({int? itemId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FilePreviewFutureCallGenerateModel',
      'itemId': itemId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _FilePreviewFutureCallGenerateModelImpl
    extends FilePreviewFutureCallGenerateModel {
  _FilePreviewFutureCallGenerateModelImpl({required int itemId})
    : super._(itemId: itemId);

  /// Returns a shallow copy of this [FilePreviewFutureCallGenerateModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  FilePreviewFutureCallGenerateModel copyWith({int? itemId}) {
    return FilePreviewFutureCallGenerateModel(itemId: itemId ?? this.itemId);
  }
}
