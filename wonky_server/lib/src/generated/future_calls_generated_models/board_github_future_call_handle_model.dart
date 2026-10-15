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

abstract class BoardGithubFutureCallHandleModel
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardGithubFutureCallHandleModel._({required this.deliveryId});

  factory BoardGithubFutureCallHandleModel({required String deliveryId}) =
      _BoardGithubFutureCallHandleModelImpl;

  factory BoardGithubFutureCallHandleModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BoardGithubFutureCallHandleModel(
      deliveryId: jsonSerialization['deliveryId'] as String,
    );
  }

  String deliveryId;

  /// Returns a shallow copy of this [BoardGithubFutureCallHandleModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardGithubFutureCallHandleModel copyWith({String? deliveryId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardGithubFutureCallHandleModel',
      'deliveryId': deliveryId,
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

class _BoardGithubFutureCallHandleModelImpl
    extends BoardGithubFutureCallHandleModel {
  _BoardGithubFutureCallHandleModelImpl({required String deliveryId})
    : super._(deliveryId: deliveryId);

  /// Returns a shallow copy of this [BoardGithubFutureCallHandleModel]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardGithubFutureCallHandleModel copyWith({String? deliveryId}) {
    return BoardGithubFutureCallHandleModel(
      deliveryId: deliveryId ?? this.deliveryId,
    );
  }
}
