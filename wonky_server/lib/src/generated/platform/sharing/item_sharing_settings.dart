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

/// The owner-only sharing settings (specs/06 §1).
abstract class ItemSharingSettings
    implements _is.SerializableModel, _is.ProtocolSerialization {
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
      editorsCanShare: _is.BoolJsonExtension.fromJson(
        jsonSerialization['editorsCanShare'],
      ),
      nonEditorsCanExport: _is.BoolJsonExtension.fromJson(
        jsonSerialization['nonEditorsCanExport'],
      ),
      viewersSeeComments: _is.BoolJsonExtension.fromJson(
        jsonSerialization['viewersSeeComments'],
      ),
    );
  }

  bool editorsCanShare;

  bool nonEditorsCanExport;

  bool viewersSeeComments;

  /// Returns a shallow copy of this [ItemSharingSettings]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
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
    return _is.SerializationManager.encode(this);
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
  @_is.useResult
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
