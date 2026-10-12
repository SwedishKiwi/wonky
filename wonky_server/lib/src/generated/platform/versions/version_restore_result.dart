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
import '../../platform/versions/item_version_view.dart' as _iqydg6py;

abstract class VersionRestoreResult
    implements _is.SerializableModel, _is.ProtocolSerialization {
  VersionRestoreResult._({
    required this.restorePoint,
    this.revision,
    this.changeId,
  });

  factory VersionRestoreResult({
    required _iqydg6py.ItemVersionView restorePoint,
    int? revision,
    _is.UuidValue? changeId,
  }) = _VersionRestoreResultImpl;

  factory VersionRestoreResult.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return VersionRestoreResult(
      restorePoint: _il4umwa0.Protocol().deserialize<_iqydg6py.ItemVersionView>(
        jsonSerialization['restorePoint'],
      ),
      revision: jsonSerialization['revision'] as int?,
      changeId: jsonSerialization['changeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['changeId']),
    );
  }

  /// The restore point captured before restoring.
  _iqydg6py.ItemVersionView restorePoint;

  /// Write: revision of the restore op.
  int? revision;

  /// Sheets: the ServerChangeRecord for undo (`sheets.revertChange`).
  _is.UuidValue? changeId;

  /// Returns a shallow copy of this [VersionRestoreResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  VersionRestoreResult copyWith({
    _iqydg6py.ItemVersionView? restorePoint,
    int? revision,
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'VersionRestoreResult',
      'restorePoint': restorePoint.toJson(),
      if (revision != null) 'revision': revision,
      if (changeId != null) 'changeId': changeId?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'VersionRestoreResult',
      'restorePoint': restorePoint.toJsonForProtocol(),
      if (revision != null) 'revision': revision,
      if (changeId != null) 'changeId': changeId?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _VersionRestoreResultImpl extends VersionRestoreResult {
  _VersionRestoreResultImpl({
    required _iqydg6py.ItemVersionView restorePoint,
    int? revision,
    _is.UuidValue? changeId,
  }) : super._(
         restorePoint: restorePoint,
         revision: revision,
         changeId: changeId,
       );

  /// Returns a shallow copy of this [VersionRestoreResult]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  VersionRestoreResult copyWith({
    _iqydg6py.ItemVersionView? restorePoint,
    Object? revision = _Undefined,
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
  }) {
    return VersionRestoreResult(
      restorePoint: restorePoint ?? this.restorePoint.copyWith(),
      revision: revision is int? ? revision : this.revision,
      changeId: changeId is _is.UndefinedSentinel ? this.changeId : changeId,
    );
  }
}
