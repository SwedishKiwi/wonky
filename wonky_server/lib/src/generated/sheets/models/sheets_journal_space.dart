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

/// Spaces whose writes are journaled in [SheetsRowJournal] (the spreadsheets
/// open on this device). Client-only; never synced.
abstract class SheetsJournalSpace
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsJournalSpace._({
    this.id,
    required this.spaceKey,
  });

  factory SheetsJournalSpace({
    int? id,
    required int spaceKey,
  }) = _SheetsJournalSpaceImpl;

  factory SheetsJournalSpace.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsJournalSpace(
      id: jsonSerialization['id'] as int?,
      spaceKey: jsonSerialization['spaceKey'] as int,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// `offline_sync_spaces.id` (local integer id).
  int spaceKey;

  /// Returns a shallow copy of this [SheetsJournalSpace]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsJournalSpace copyWith({
    int? id,
    int? spaceKey,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsJournalSpace',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsJournalSpace',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsJournalSpaceImpl extends SheetsJournalSpace {
  _SheetsJournalSpaceImpl({
    int? id,
    required int spaceKey,
  }) : super._(
         id: id,
         spaceKey: spaceKey,
       );

  /// Returns a shallow copy of this [SheetsJournalSpace]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsJournalSpace copyWith({
    Object? id = _Undefined,
    int? spaceKey,
  }) {
    return SheetsJournalSpace(
      id: id is int? ? id : this.id,
      spaceKey: spaceKey ?? this.spaceKey,
    );
  }
}
