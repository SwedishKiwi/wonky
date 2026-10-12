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
import '../../platform/drive/drive_item_view.dart' as _ivpffrb8;

/// One page of drive items; pass [nextCursor] to get the next page.
abstract class DriveListPage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DriveListPage._({
    required this.items,
    this.nextCursor,
  });

  factory DriveListPage({
    required List<_ivpffrb8.DriveItemView> items,
    String? nextCursor,
  }) = _DriveListPageImpl;

  factory DriveListPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveListPage(
      items: _i8pkqg1o.Protocol().deserialize<List<_ivpffrb8.DriveItemView>>(
        jsonSerialization['items'],
      ),
      nextCursor: jsonSerialization['nextCursor'] as String?,
    );
  }

  List<_ivpffrb8.DriveItemView> items;

  String? nextCursor;

  /// Returns a shallow copy of this [DriveListPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DriveListPage copyWith({
    List<_ivpffrb8.DriveItemView>? items,
    String? nextCursor,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveListPage',
      'items': items.toJson(valueToJson: (v) => v.toJson()),
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveListPage',
      'items': items.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (nextCursor != null) 'nextCursor': nextCursor,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DriveListPageImpl extends DriveListPage {
  _DriveListPageImpl({
    required List<_ivpffrb8.DriveItemView> items,
    String? nextCursor,
  }) : super._(
         items: items,
         nextCursor: nextCursor,
       );

  /// Returns a shallow copy of this [DriveListPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DriveListPage copyWith({
    List<_ivpffrb8.DriveItemView>? items,
    Object? nextCursor = _Undefined,
  }) {
    return DriveListPage(
      items: items ?? this.items.map((e0) => e0.copyWith()).toList(),
      nextCursor: nextCursor is String? ? nextCursor : this.nextCursor,
    );
  }
}
