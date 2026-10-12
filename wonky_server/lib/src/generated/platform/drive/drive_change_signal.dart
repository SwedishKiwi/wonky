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
import '../../platform/drive/drive_change_kind.dart' as _ijkkpwz4;

/// Internal session.messages payload on `drive:user:<userId>`.
abstract class DriveChangeSignal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  DriveChangeSignal._({
    required this.kind,
    required this.itemUuid,
  });

  factory DriveChangeSignal({
    required _ijkkpwz4.DriveChangeKind kind,
    required _is.UuidValue itemUuid,
  }) = _DriveChangeSignalImpl;

  factory DriveChangeSignal.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveChangeSignal(
      kind: _ijkkpwz4.DriveChangeKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      itemUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
    );
  }

  _ijkkpwz4.DriveChangeKind kind;

  _is.UuidValue itemUuid;

  /// Returns a shallow copy of this [DriveChangeSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveChangeSignal copyWith({
    _ijkkpwz4.DriveChangeKind? kind,
    _is.UuidValue? itemUuid,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveChangeSignal',
      'kind': kind.toJson(),
      'itemUuid': itemUuid.toJson(),
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

class _DriveChangeSignalImpl extends DriveChangeSignal {
  _DriveChangeSignalImpl({
    required _ijkkpwz4.DriveChangeKind kind,
    required _is.UuidValue itemUuid,
  }) : super._(
         kind: kind,
         itemUuid: itemUuid,
       );

  /// Returns a shallow copy of this [DriveChangeSignal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveChangeSignal copyWith({
    _ijkkpwz4.DriveChangeKind? kind,
    _is.UuidValue? itemUuid,
  }) {
    return DriveChangeSignal(
      kind: kind ?? this.kind,
      itemUuid: itemUuid ?? this.itemUuid,
    );
  }
}
