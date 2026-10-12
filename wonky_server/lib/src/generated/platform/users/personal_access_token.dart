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
import 'dart:async' as _ida;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:wonky_server/src/generated/protocol.dart' as _il4umwa0;

/// A personal access token for MCP (specs/04 §3, 09 §2). Only the SHA-256 of
/// the secret is stored; the secret is shown once.
abstract class PersonalAccessToken
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  PersonalAccessToken._({
    this.id,
    required this.userId,
    required this.name,
    required this.tokenHash,
    required this.prefix,
    required this.scopes,
    this.expiresAt,
    this.lastUsedAt,
    required this.createdAt,
    this.revokedAt,
  });

  factory PersonalAccessToken({
    int? id,
    required int userId,
    required String name,
    required String tokenHash,
    required String prefix,
    required List<String> scopes,
    DateTime? expiresAt,
    DateTime? lastUsedAt,
    required DateTime createdAt,
    DateTime? revokedAt,
  }) = _PersonalAccessTokenImpl;

  factory PersonalAccessToken.fromJson(Map<String, dynamic> jsonSerialization) {
    return PersonalAccessToken(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int,
      name: jsonSerialization['name'] as String,
      tokenHash: jsonSerialization['tokenHash'] as String,
      prefix: jsonSerialization['prefix'] as String,
      scopes: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['scopes'],
      ),
      expiresAt: jsonSerialization['expiresAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['expiresAt']),
      lastUsedAt: jsonSerialization['lastUsedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['lastUsedAt']),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      revokedAt: jsonSerialization['revokedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['revokedAt']),
    );
  }

  static final t = PersonalAccessTokenTable();

  static const db = PersonalAccessTokenRepository._();

  @override
  int? id;

  int userId;

  String name;

  String tokenHash;

  /// First characters of the secret for display, e.g. "wkpat_ab12".
  String prefix;

  /// e.g. ["drive:read", "write:edit", "sheets:edit", "ui:control"].
  List<String> scopes;

  DateTime? expiresAt;

  DateTime? lastUsedAt;

  DateTime createdAt;

  DateTime? revokedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [PersonalAccessToken]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PersonalAccessToken copyWith({
    int? id,
    int? userId,
    String? name,
    String? tokenHash,
    String? prefix,
    List<String>? scopes,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PersonalAccessToken',
      if (id != null) 'id': id,
      'userId': userId,
      'name': name,
      'tokenHash': tokenHash,
      'prefix': prefix,
      'scopes': scopes.toJson(),
      if (expiresAt != null) 'expiresAt': expiresAt?.toJson(),
      if (lastUsedAt != null) 'lastUsedAt': lastUsedAt?.toJson(),
      'createdAt': createdAt.toJson(),
      if (revokedAt != null) 'revokedAt': revokedAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static PersonalAccessTokenInclude include() {
    return PersonalAccessTokenInclude._();
  }

  static PersonalAccessTokenIncludeList includeList({
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    PersonalAccessTokenInclude? include,
  }) {
    return PersonalAccessTokenIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PersonalAccessTokenImpl extends PersonalAccessToken {
  _PersonalAccessTokenImpl({
    int? id,
    required int userId,
    required String name,
    required String tokenHash,
    required String prefix,
    required List<String> scopes,
    DateTime? expiresAt,
    DateTime? lastUsedAt,
    required DateTime createdAt,
    DateTime? revokedAt,
  }) : super._(
         id: id,
         userId: userId,
         name: name,
         tokenHash: tokenHash,
         prefix: prefix,
         scopes: scopes,
         expiresAt: expiresAt,
         lastUsedAt: lastUsedAt,
         createdAt: createdAt,
         revokedAt: revokedAt,
       );

  /// Returns a shallow copy of this [PersonalAccessToken]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PersonalAccessToken copyWith({
    Object? id = _Undefined,
    int? userId,
    String? name,
    String? tokenHash,
    String? prefix,
    List<String>? scopes,
    DateTime? expiresAt = const _is.$UndefinedDateTime(),
    DateTime? lastUsedAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? revokedAt = const _is.$UndefinedDateTime(),
  }) {
    return PersonalAccessToken(
      id: id is int? ? id : this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      tokenHash: tokenHash ?? this.tokenHash,
      prefix: prefix ?? this.prefix,
      scopes: scopes ?? this.scopes.map((e0) => e0).toList(),
      expiresAt: expiresAt is _is.UndefinedSentinel
          ? this.expiresAt
          : expiresAt,
      lastUsedAt: lastUsedAt is _is.UndefinedSentinel
          ? this.lastUsedAt
          : lastUsedAt,
      createdAt: createdAt ?? this.createdAt,
      revokedAt: revokedAt is _is.UndefinedSentinel
          ? this.revokedAt
          : revokedAt,
    );
  }
}

class PersonalAccessTokenUpdateTable
    extends _is.UpdateTable<PersonalAccessTokenTable> {
  PersonalAccessTokenUpdateTable(super.table);

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<String, String> tokenHash(String value) => _is.ColumnValue(
    table.tokenHash,
    value,
  );

  _is.ColumnValue<String, String> prefix(String value) => _is.ColumnValue(
    table.prefix,
    value,
  );

  _is.ColumnValue<List<String>, List<String>> scopes(List<String> value) =>
      _is.ColumnValue(
        table.scopes,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> expiresAt(DateTime? value) =>
      _is.ColumnValue(
        table.expiresAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastUsedAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastUsedAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> revokedAt(DateTime? value) =>
      _is.ColumnValue(
        table.revokedAt,
        value,
      );
}

class PersonalAccessTokenTable extends _is.Table<int?> {
  PersonalAccessTokenTable({super.tableRelation})
    : super(tableName: 'personal_access_token') {
    updateTable = PersonalAccessTokenUpdateTable(this);
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    tokenHash = _is.ColumnString(
      'tokenHash',
      this,
    );
    prefix = _is.ColumnString(
      'prefix',
      this,
    );
    scopes = _is.ColumnSerializable<List<String>>(
      'scopes',
      this,
    );
    expiresAt = _is.ColumnDateTime(
      'expiresAt',
      this,
    );
    lastUsedAt = _is.ColumnDateTime(
      'lastUsedAt',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    revokedAt = _is.ColumnDateTime(
      'revokedAt',
      this,
    );
  }

  late final PersonalAccessTokenUpdateTable updateTable;

  late final _is.ColumnInt userId;

  late final _is.ColumnString name;

  late final _is.ColumnString tokenHash;

  /// First characters of the secret for display, e.g. "wkpat_ab12".
  late final _is.ColumnString prefix;

  /// e.g. ["drive:read", "write:edit", "sheets:edit", "ui:control"].
  late final _is.ColumnSerializable<List<String>> scopes;

  late final _is.ColumnDateTime expiresAt;

  late final _is.ColumnDateTime lastUsedAt;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime revokedAt;

  @override
  List<_is.Column> get columns => [
    id,
    userId,
    name,
    tokenHash,
    prefix,
    scopes,
    expiresAt,
    lastUsedAt,
    createdAt,
    revokedAt,
  ];
}

class PersonalAccessTokenInclude extends _is.IncludeObject {
  PersonalAccessTokenInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => PersonalAccessToken.t;
}

class PersonalAccessTokenIncludeList extends _is.IncludeList {
  PersonalAccessTokenIncludeList._({
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(PersonalAccessToken.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => PersonalAccessToken.t;
}

class PersonalAccessTokenRepository {
  const PersonalAccessTokenRepository._();

  /// Returns a list of [PersonalAccessToken]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<PersonalAccessToken>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<PersonalAccessToken>(
      where: where?.call(PersonalAccessToken.t),
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [PersonalAccessToken]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `PersonalAccessToken.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<PersonalAccessToken>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<PersonalAccessToken>(
      where: where?.call(PersonalAccessToken.t),
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [PersonalAccessToken] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<PersonalAccessToken?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? where,
    int? offset,
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<PersonalAccessToken>(
      where: where?.call(PersonalAccessToken.t),
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [PersonalAccessToken] by its [id] or null if no such row exists.
  Future<PersonalAccessToken?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<PersonalAccessToken>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [PersonalAccessToken]s in the list and returns the inserted rows.
  ///
  /// The returned [PersonalAccessToken]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PersonalAccessToken>> insert(
    _is.DatabaseSession session,
    List<PersonalAccessToken> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<PersonalAccessToken>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [PersonalAccessToken] and returns the inserted row.
  ///
  /// The returned [PersonalAccessToken] will have its `id` field set.
  Future<PersonalAccessToken> insertRow(
    _is.DatabaseSession session,
    PersonalAccessToken row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<PersonalAccessToken>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [PersonalAccessToken]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [PersonalAccessToken]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PersonalAccessToken>> upsert(
    _is.DatabaseSession session,
    List<PersonalAccessToken> rows, {
    required _is.ColumnSelections<PersonalAccessTokenTable> conflictColumns,
    _is.ColumnSelections<PersonalAccessTokenTable>? updateColumns,
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<PersonalAccessToken>(
      rows,
      conflictColumns: conflictColumns(PersonalAccessToken.t),
      updateColumns: updateColumns?.call(PersonalAccessToken.t),
      updateWhere: updateWhere?.call(PersonalAccessToken.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [PersonalAccessToken] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [PersonalAccessToken] will have its `id` field set.
  Future<PersonalAccessToken?> upsertRow(
    _is.DatabaseSession session,
    PersonalAccessToken row, {
    required _is.ColumnSelections<PersonalAccessTokenTable> conflictColumns,
    _is.ColumnSelections<PersonalAccessTokenTable>? updateColumns,
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<PersonalAccessToken>(
      row,
      conflictColumns: conflictColumns(PersonalAccessToken.t),
      updateColumns: updateColumns?.call(PersonalAccessToken.t),
      updateWhere: updateWhere?.call(PersonalAccessToken.t),
      transaction: transaction,
    );
  }

  /// Updates all [PersonalAccessToken]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PersonalAccessToken>> update(
    _is.DatabaseSession session,
    List<PersonalAccessToken> rows, {
    _is.ColumnSelections<PersonalAccessTokenTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<PersonalAccessToken>(
      rows,
      columns: columns?.call(PersonalAccessToken.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [PersonalAccessToken]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<PersonalAccessToken> updateRow(
    _is.DatabaseSession session,
    PersonalAccessToken row, {
    _is.ColumnSelections<PersonalAccessTokenTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<PersonalAccessToken>(
      row,
      columns: columns?.call(PersonalAccessToken.t),
      transaction: transaction,
    );
  }

  /// Updates a single [PersonalAccessToken] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<PersonalAccessToken?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<PersonalAccessTokenUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<PersonalAccessToken>(
      id,
      columnValues: columnValues(PersonalAccessToken.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [PersonalAccessToken]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PersonalAccessToken>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<PersonalAccessTokenUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<PersonalAccessTokenTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<PersonalAccessToken>(
      columnValues: columnValues(PersonalAccessToken.t.updateTable),
      where: where(PersonalAccessToken.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [PersonalAccessToken]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PersonalAccessToken>> delete(
    _is.DatabaseSession session,
    List<PersonalAccessToken> rows, {
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<PersonalAccessToken>(
      rows,
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [PersonalAccessToken].
  Future<PersonalAccessToken> deleteRow(
    _is.DatabaseSession session,
    PersonalAccessToken row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<PersonalAccessToken>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<PersonalAccessToken>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PersonalAccessTokenTable> where,
    _is.OrderByBuilder<PersonalAccessTokenTable>? orderBy,
    _is.OrderByListBuilder<PersonalAccessTokenTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<PersonalAccessToken>(
      where: where(PersonalAccessToken.t),
      orderBy: orderBy?.call(PersonalAccessToken.t),
      orderByList: orderByList?.call(PersonalAccessToken.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<PersonalAccessTokenTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<PersonalAccessToken>(
      where: where?.call(PersonalAccessToken.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [PersonalAccessToken] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<PersonalAccessTokenTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<PersonalAccessToken>(
      where: where(PersonalAccessToken.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
