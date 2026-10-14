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

/// Local change journal of the Sheets replica (suite 12 §4 U11): SQLite
/// triggers on the synced tables and on `crdt_data_rows` append the
/// (table, row) of every write in a journaled space, so an open spreadsheet
/// patches its in-memory model with only the rows a merge touched.
/// Client-only; never synced. Pruned by the app.
abstract class SheetsRowJournal
    implements _is.SerializableModel, _is.ProtocolSerialization {
  SheetsRowJournal._({
    this.id,
    required this.spaceKey,
    required this.syncTable,
    required this.rowId,
  });

  factory SheetsRowJournal({
    int? id,
    required int spaceKey,
    required String syncTable,
    required _is.UuidValue rowId,
  }) = _SheetsRowJournalImpl;

  factory SheetsRowJournal.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsRowJournal(
      id: jsonSerialization['id'] as int?,
      spaceKey: jsonSerialization['spaceKey'] as int,
      syncTable: jsonSerialization['syncTable'] as String,
      rowId: _is.UuidValueJsonExtension.fromJson(jsonSerialization['rowId']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  /// `offline_sync_spaces.id` (local integer id) of the row's space.
  int spaceKey;

  /// Synced table name (`cell`, `sheet_row`, …).
  String syncTable;

  _is.UuidValue rowId;

  /// Returns a shallow copy of this [SheetsRowJournal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsRowJournal copyWith({
    int? id,
    int? spaceKey,
    String? syncTable,
    _is.UuidValue? rowId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsRowJournal',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
      'syncTable': syncTable,
      'rowId': rowId.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SheetsRowJournal',
      if (id != null) 'id': id,
      'spaceKey': spaceKey,
      'syncTable': syncTable,
      'rowId': rowId.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsRowJournalImpl extends SheetsRowJournal {
  _SheetsRowJournalImpl({
    int? id,
    required int spaceKey,
    required String syncTable,
    required _is.UuidValue rowId,
  }) : super._(
         id: id,
         spaceKey: spaceKey,
         syncTable: syncTable,
         rowId: rowId,
       );

  /// Returns a shallow copy of this [SheetsRowJournal]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsRowJournal copyWith({
    Object? id = _Undefined,
    int? spaceKey,
    String? syncTable,
    _is.UuidValue? rowId,
  }) {
    return SheetsRowJournal(
      id: id is int? ? id : this.id,
      spaceKey: spaceKey ?? this.spaceKey,
      syncTable: syncTable ?? this.syncTable,
      rowId: rowId ?? this.rowId,
    );
  }
}
