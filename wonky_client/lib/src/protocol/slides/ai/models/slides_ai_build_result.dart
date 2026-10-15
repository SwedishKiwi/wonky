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

/// The result of building an AI outline (Slides 11 §6.4 step 2).
abstract class SlidesAiBuildResult
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SlidesAiBuildResult._({
    required this.itemUuid,
    this.changeId,
    required this.slideIds,
    required this.warnings,
  });

  factory SlidesAiBuildResult({
    required _isc.UuidValue itemUuid,
    String? changeId,
    required List<String> slideIds,
    required List<String> warnings,
  }) = _SlidesAiBuildResultImpl;

  factory SlidesAiBuildResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlidesAiBuildResult(
      itemUuid: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['itemUuid'],
      ),
      changeId: jsonSerialization['changeId'] as String?,
      slideIds: _i8pkqg1o.Protocol().deserialize<List<String>>(
        jsonSerialization['slideIds'],
      ),
      warnings: _i8pkqg1o.Protocol().deserialize<List<String>>(
        jsonSerialization['warnings'],
      ),
    );
  }

  /// The new presentation (new deck) or the deck the slides went into.
  _isc.UuidValue itemUuid;

  /// The server change of an insert into an open deck (one undo step
  /// "AI: Generate slides"); null for a new presentation.
  String? changeId;

  List<String> slideIds;

  List<String> warnings;

  /// Returns a shallow copy of this [SlidesAiBuildResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SlidesAiBuildResult copyWith({
    _isc.UuidValue? itemUuid,
    String? changeId,
    List<String>? slideIds,
    List<String>? warnings,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlidesAiBuildResult',
      'itemUuid': itemUuid.toJson(),
      if (changeId != null) 'changeId': changeId,
      'slideIds': slideIds.toJson(),
      'warnings': warnings.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlidesAiBuildResult',
      'itemUuid': itemUuid.toJson(),
      if (changeId != null) 'changeId': changeId,
      'slideIds': slideIds.toJson(),
      'warnings': warnings.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SlidesAiBuildResultImpl extends SlidesAiBuildResult {
  _SlidesAiBuildResultImpl({
    required _isc.UuidValue itemUuid,
    String? changeId,
    required List<String> slideIds,
    required List<String> warnings,
  }) : super._(
         itemUuid: itemUuid,
         changeId: changeId,
         slideIds: slideIds,
         warnings: warnings,
       );

  /// Returns a shallow copy of this [SlidesAiBuildResult]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SlidesAiBuildResult copyWith({
    _isc.UuidValue? itemUuid,
    Object? changeId = _Undefined,
    List<String>? slideIds,
    List<String>? warnings,
  }) {
    return SlidesAiBuildResult(
      itemUuid: itemUuid ?? this.itemUuid,
      changeId: changeId is String? ? changeId : this.changeId,
      slideIds: slideIds ?? this.slideIds.map((e0) => e0).toList(),
      warnings: warnings ?? this.warnings.map((e0) => e0).toList(),
    );
  }
}
