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
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../sheets/models/revert_skip.dart' as _iznbqmpl;

abstract class RevertResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  RevertResult._({
    required this.changeId,
    required this.revertedCells,
    required this.skipped,
  });

  factory RevertResult({
    required _isc.UuidValue changeId,
    required int revertedCells,
    required List<_iznbqmpl.RevertSkip> skipped,
  }) = _RevertResultImpl;

  factory RevertResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return RevertResult(
      changeId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['changeId'],
      ),
      revertedCells: jsonSerialization['revertedCells'] as int,
      skipped: _i8pkqg1o.Protocol().deserialize<List<_iznbqmpl.RevertSkip>>(
        jsonSerialization['skipped'],
      ),
    );
  }

  /// The record of the revert itself.
  _isc.UuidValue changeId;

  int revertedCells;

  List<_iznbqmpl.RevertSkip> skipped;

  /// Returns a shallow copy of this [RevertResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  RevertResult copyWith({
    _isc.UuidValue? changeId,
    int? revertedCells,
    List<_iznbqmpl.RevertSkip>? skipped,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RevertResult',
      'changeId': changeId.toJson(),
      'revertedCells': revertedCells,
      'skipped': skipped.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RevertResult',
      'changeId': changeId.toJson(),
      'revertedCells': revertedCells,
      'skipped': skipped.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _RevertResultImpl extends RevertResult {
  _RevertResultImpl({
    required _isc.UuidValue changeId,
    required int revertedCells,
    required List<_iznbqmpl.RevertSkip> skipped,
  }) : super._(
         changeId: changeId,
         revertedCells: revertedCells,
         skipped: skipped,
       );

  /// Returns a shallow copy of this [RevertResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  RevertResult copyWith({
    _isc.UuidValue? changeId,
    int? revertedCells,
    List<_iznbqmpl.RevertSkip>? skipped,
  }) {
    return RevertResult(
      changeId: changeId ?? this.changeId,
      revertedCells: revertedCells ?? this.revertedCells,
      skipped: skipped ?? this.skipped.map((e0) => e0.copyWith()).toList(),
    );
  }
}
