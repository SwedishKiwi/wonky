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

/// What deleting the account would remove (shown in the confirm dialog).
abstract class AccountDeletionPreview
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AccountDeletionPreview._({
    required this.ownedDocuments,
    required this.ownedSpreadsheets,
    required this.ownedFolders,
    required this.sharedOwnedItems,
  });

  factory AccountDeletionPreview({
    required int ownedDocuments,
    required int ownedSpreadsheets,
    required int ownedFolders,
    required int sharedOwnedItems,
  }) = _AccountDeletionPreviewImpl;

  factory AccountDeletionPreview.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AccountDeletionPreview(
      ownedDocuments: jsonSerialization['ownedDocuments'] as int,
      ownedSpreadsheets: jsonSerialization['ownedSpreadsheets'] as int,
      ownedFolders: jsonSerialization['ownedFolders'] as int,
      sharedOwnedItems: jsonSerialization['sharedOwnedItems'] as int,
    );
  }

  int ownedDocuments;

  int ownedSpreadsheets;

  int ownedFolders;

  /// Owned items that are shared with other people.
  int sharedOwnedItems;

  /// Returns a shallow copy of this [AccountDeletionPreview]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AccountDeletionPreview copyWith({
    int? ownedDocuments,
    int? ownedSpreadsheets,
    int? ownedFolders,
    int? sharedOwnedItems,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccountDeletionPreview',
      'ownedDocuments': ownedDocuments,
      'ownedSpreadsheets': ownedSpreadsheets,
      'ownedFolders': ownedFolders,
      'sharedOwnedItems': sharedOwnedItems,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccountDeletionPreview',
      'ownedDocuments': ownedDocuments,
      'ownedSpreadsheets': ownedSpreadsheets,
      'ownedFolders': ownedFolders,
      'sharedOwnedItems': sharedOwnedItems,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _AccountDeletionPreviewImpl extends AccountDeletionPreview {
  _AccountDeletionPreviewImpl({
    required int ownedDocuments,
    required int ownedSpreadsheets,
    required int ownedFolders,
    required int sharedOwnedItems,
  }) : super._(
         ownedDocuments: ownedDocuments,
         ownedSpreadsheets: ownedSpreadsheets,
         ownedFolders: ownedFolders,
         sharedOwnedItems: sharedOwnedItems,
       );

  /// Returns a shallow copy of this [AccountDeletionPreview]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AccountDeletionPreview copyWith({
    int? ownedDocuments,
    int? ownedSpreadsheets,
    int? ownedFolders,
    int? sharedOwnedItems,
  }) {
    return AccountDeletionPreview(
      ownedDocuments: ownedDocuments ?? this.ownedDocuments,
      ownedSpreadsheets: ownedSpreadsheets ?? this.ownedSpreadsheets,
      ownedFolders: ownedFolders ?? this.ownedFolders,
      sharedOwnedItems: sharedOwnedItems ?? this.sharedOwnedItems,
    );
  }
}
