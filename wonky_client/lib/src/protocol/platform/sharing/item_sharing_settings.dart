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

/// The owner-only sharing settings (specs/06 §1).
abstract class ItemSharingSettings
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ItemSharingSettings._({
    required this.editorsCanShare,
    required this.nonEditorsCanExport,
    required this.viewersSeeComments,
  });

  factory ItemSharingSettings({
    required bool editorsCanShare,
    required bool nonEditorsCanExport,
    required bool viewersSeeComments,
  }) = _ItemSharingSettingsImpl;

  factory ItemSharingSettings.fromJson(Map<String, dynamic> jsonSerialization) {
    return ItemSharingSettings(
      editorsCanShare: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['editorsCanShare'],
      ),
      nonEditorsCanExport: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['nonEditorsCanExport'],
      ),
      viewersSeeComments: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['viewersSeeComments'],
      ),
    );
  }

  bool editorsCanShare;

  bool nonEditorsCanExport;

  bool viewersSeeComments;

  /// Returns a shallow copy of this [ItemSharingSettings]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ItemSharingSettings copyWith({
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ItemSharingSettings',
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ItemSharingSettings',
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ItemSharingSettingsImpl extends ItemSharingSettings {
  _ItemSharingSettingsImpl({
    required bool editorsCanShare,
    required bool nonEditorsCanExport,
    required bool viewersSeeComments,
  }) : super._(
         editorsCanShare: editorsCanShare,
         nonEditorsCanExport: nonEditorsCanExport,
         viewersSeeComments: viewersSeeComments,
       );

  /// Returns a shallow copy of this [ItemSharingSettings]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ItemSharingSettings copyWith({
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
  }) {
    return ItemSharingSettings(
      editorsCanShare: editorsCanShare ?? this.editorsCanShare,
      nonEditorsCanExport: nonEditorsCanExport ?? this.nonEditorsCanExport,
      viewersSeeComments: viewersSeeComments ?? this.viewersSeeComments,
    );
  }
}
