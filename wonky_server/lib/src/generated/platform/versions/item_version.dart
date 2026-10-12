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
import '../../platform/versions/version_kind.dart' as _i8rqnb03;
import '../../platform/versions/version_storage.dart' as _iozipb7v;

/// A version of a drive item (specs/07 §5).
abstract class ItemVersion
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  ItemVersion._({
    this.id,
    required this.itemId,
    required this.kind,
    this.name,
    required this.createdAt,
    this.createdById,
    required this.authors,
    required this.storageKind,
    this.revision,
    this.snapshotFileId,
    int? sizeBytes,
  }) : sizeBytes = sizeBytes ?? 0;

  factory ItemVersion({
    int? id,
    required int itemId,
    required _i8rqnb03.VersionKind kind,
    String? name,
    required DateTime createdAt,
    int? createdById,
    required List<int> authors,
    required _iozipb7v.VersionStorage storageKind,
    int? revision,
    _is.UuidValue? snapshotFileId,
    int? sizeBytes,
  }) = _ItemVersionImpl;

  factory ItemVersion.fromJson(Map<String, dynamic> jsonSerialization) {
    return ItemVersion(
      id: jsonSerialization['id'] as int?,
      itemId: jsonSerialization['itemId'] as int,
      kind: _i8rqnb03.VersionKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      createdById: jsonSerialization['createdById'] as int?,
      authors: _il4umwa0.Protocol().deserialize<List<int>>(
        jsonSerialization['authors'],
      ),
      storageKind: _iozipb7v.VersionStorage.fromJson(
        (jsonSerialization['storageKind'] as String),
      ),
      revision: jsonSerialization['revision'] as int?,
      snapshotFileId: jsonSerialization['snapshotFileId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['snapshotFileId'],
            ),
      sizeBytes: jsonSerialization['sizeBytes'] as int?,
    );
  }

  static final t = ItemVersionTable();

  static const db = ItemVersionRepository._();

  @override
  int? id;

  int itemId;

  _i8rqnb03.VersionKind kind;

  String? name;

  DateTime createdAt;

  int? createdById;

  /// Users who contributed since the previous version.
  List<int> authors;

  _iozipb7v.VersionStorage storageKind;

  int? revision;

  _is.UuidValue? snapshotFileId;

  int sizeBytes;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [ItemVersion]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  ItemVersion copyWith({
    int? id,
    int? itemId,
    _i8rqnb03.VersionKind? kind,
    String? name,
    DateTime? createdAt,
    int? createdById,
    List<int>? authors,
    _iozipb7v.VersionStorage? storageKind,
    int? revision,
    _is.UuidValue? snapshotFileId = const _is.$UndefinedUuidValue(),
    int? sizeBytes,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ItemVersion',
      if (id != null) 'id': id,
      'itemId': itemId,
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      'createdAt': createdAt.toJson(),
      if (createdById != null) 'createdById': createdById,
      'authors': authors.toJson(),
      'storageKind': storageKind.toJson(),
      if (revision != null) 'revision': revision,
      if (snapshotFileId != null) 'snapshotFileId': snapshotFileId?.toJson(),
      'sizeBytes': sizeBytes,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ItemVersion',
      if (id != null) 'id': id,
      'itemId': itemId,
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      'createdAt': createdAt.toJson(),
      if (createdById != null) 'createdById': createdById,
      'authors': authors.toJson(),
      'storageKind': storageKind.toJson(),
      if (revision != null) 'revision': revision,
      if (snapshotFileId != null) 'snapshotFileId': snapshotFileId?.toJson(),
      'sizeBytes': sizeBytes,
    };
  }

  static ItemVersionInclude include() {
    return ItemVersionInclude._();
  }

  static ItemVersionIncludeList includeList({
    _is.WhereExpressionBuilder<ItemVersionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    ItemVersionInclude? include,
  }) {
    return ItemVersionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ItemVersionImpl extends ItemVersion {
  _ItemVersionImpl({
    int? id,
    required int itemId,
    required _i8rqnb03.VersionKind kind,
    String? name,
    required DateTime createdAt,
    int? createdById,
    required List<int> authors,
    required _iozipb7v.VersionStorage storageKind,
    int? revision,
    _is.UuidValue? snapshotFileId,
    int? sizeBytes,
  }) : super._(
         id: id,
         itemId: itemId,
         kind: kind,
         name: name,
         createdAt: createdAt,
         createdById: createdById,
         authors: authors,
         storageKind: storageKind,
         revision: revision,
         snapshotFileId: snapshotFileId,
         sizeBytes: sizeBytes,
       );

  /// Returns a shallow copy of this [ItemVersion]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  ItemVersion copyWith({
    Object? id = _Undefined,
    int? itemId,
    _i8rqnb03.VersionKind? kind,
    Object? name = _Undefined,
    DateTime? createdAt,
    Object? createdById = _Undefined,
    List<int>? authors,
    _iozipb7v.VersionStorage? storageKind,
    Object? revision = _Undefined,
    _is.UuidValue? snapshotFileId = const _is.$UndefinedUuidValue(),
    int? sizeBytes,
  }) {
    return ItemVersion(
      id: id is int? ? id : this.id,
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      name: name is String? ? name : this.name,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById is int? ? createdById : this.createdById,
      authors: authors ?? this.authors.map((e0) => e0).toList(),
      storageKind: storageKind ?? this.storageKind,
      revision: revision is int? ? revision : this.revision,
      snapshotFileId: snapshotFileId is _is.UndefinedSentinel
          ? this.snapshotFileId
          : snapshotFileId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}

class ItemVersionUpdateTable extends _is.UpdateTable<ItemVersionTable> {
  ItemVersionUpdateTable(super.table);

  _is.ColumnValue<int, int> itemId(int value) => _is.ColumnValue(
    table.itemId,
    value,
  );

  _is.ColumnValue<_i8rqnb03.VersionKind, _i8rqnb03.VersionKind> kind(
    _i8rqnb03.VersionKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<String, String> name(String? value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<int, int> createdById(int? value) => _is.ColumnValue(
    table.createdById,
    value,
  );

  _is.ColumnValue<List<int>, List<int>> authors(List<int> value) =>
      _is.ColumnValue(
        table.authors,
        value,
      );

  _is.ColumnValue<_iozipb7v.VersionStorage, _iozipb7v.VersionStorage>
  storageKind(_iozipb7v.VersionStorage value) => _is.ColumnValue(
    table.storageKind,
    value,
  );

  _is.ColumnValue<int, int> revision(int? value) => _is.ColumnValue(
    table.revision,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> snapshotFileId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.snapshotFileId,
    value,
  );

  _is.ColumnValue<int, int> sizeBytes(int value) => _is.ColumnValue(
    table.sizeBytes,
    value,
  );
}

class ItemVersionTable extends _is.Table<int?> {
  ItemVersionTable({super.tableRelation}) : super(tableName: 'item_version') {
    updateTable = ItemVersionUpdateTable(this);
    itemId = _is.ColumnInt(
      'itemId',
      this,
    );
    kind = _is.ColumnEnum(
      'kind',
      this,
      _is.EnumSerialization.byName,
    );
    name = _is.ColumnString(
      'name',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    createdById = _is.ColumnInt(
      'createdById',
      this,
    );
    authors = _is.ColumnSerializable<List<int>>(
      'authors',
      this,
    );
    storageKind = _is.ColumnEnum(
      'storageKind',
      this,
      _is.EnumSerialization.byName,
    );
    revision = _is.ColumnInt(
      'revision',
      this,
    );
    snapshotFileId = _is.ColumnUuid(
      'snapshotFileId',
      this,
    );
    sizeBytes = _is.ColumnInt(
      'sizeBytes',
      this,
      hasDefault: true,
    );
  }

  late final ItemVersionUpdateTable updateTable;

  late final _is.ColumnInt itemId;

  late final _is.ColumnEnum<_i8rqnb03.VersionKind> kind;

  late final _is.ColumnString name;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt createdById;

  /// Users who contributed since the previous version.
  late final _is.ColumnSerializable<List<int>> authors;

  late final _is.ColumnEnum<_iozipb7v.VersionStorage> storageKind;

  late final _is.ColumnInt revision;

  late final _is.ColumnUuid snapshotFileId;

  late final _is.ColumnInt sizeBytes;

  @override
  List<_is.Column> get columns => [
    id,
    itemId,
    kind,
    name,
    createdAt,
    createdById,
    authors,
    storageKind,
    revision,
    snapshotFileId,
    sizeBytes,
  ];
}

class ItemVersionInclude extends _is.IncludeObject {
  ItemVersionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => ItemVersion.t;
}

class ItemVersionIncludeList extends _is.IncludeList {
  ItemVersionIncludeList._({
    _is.WhereExpressionBuilder<ItemVersionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(ItemVersion.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => ItemVersion.t;
}

class ItemVersionRepository {
  const ItemVersionRepository._();

  /// Returns a list of [ItemVersion]s matching the given query parameters.
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
  Future<List<ItemVersion>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ItemVersionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<ItemVersion>(
      where: where?.call(ItemVersion.t),
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [ItemVersion]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `ItemVersion.t`.
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
  _ida.Stream<List<ItemVersion>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ItemVersionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<ItemVersion>(
      where: where?.call(ItemVersion.t),
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [ItemVersion] matching the given query parameters.
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
  Future<ItemVersion?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ItemVersionTable>? where,
    int? offset,
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<ItemVersion>(
      where: where?.call(ItemVersion.t),
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [ItemVersion] by its [id] or null if no such row exists.
  Future<ItemVersion?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<ItemVersion>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [ItemVersion]s in the list and returns the inserted rows.
  ///
  /// The returned [ItemVersion]s will have their `id` fields set.
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
  Future<List<ItemVersion>> insert(
    _is.DatabaseSession session,
    List<ItemVersion> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<ItemVersion>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [ItemVersion] and returns the inserted row.
  ///
  /// The returned [ItemVersion] will have its `id` field set.
  Future<ItemVersion> insertRow(
    _is.DatabaseSession session,
    ItemVersion row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<ItemVersion>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [ItemVersion]s in the list and returns the resulting rows.
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
  /// The returned [ItemVersion]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ItemVersion>> upsert(
    _is.DatabaseSession session,
    List<ItemVersion> rows, {
    required _is.ColumnSelections<ItemVersionTable> conflictColumns,
    _is.ColumnSelections<ItemVersionTable>? updateColumns,
    _is.WhereExpressionBuilder<ItemVersionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<ItemVersion>(
      rows,
      conflictColumns: conflictColumns(ItemVersion.t),
      updateColumns: updateColumns?.call(ItemVersion.t),
      updateWhere: updateWhere?.call(ItemVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [ItemVersion] and returns the resulting row.
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
  /// The returned [ItemVersion] will have its `id` field set.
  Future<ItemVersion?> upsertRow(
    _is.DatabaseSession session,
    ItemVersion row, {
    required _is.ColumnSelections<ItemVersionTable> conflictColumns,
    _is.ColumnSelections<ItemVersionTable>? updateColumns,
    _is.WhereExpressionBuilder<ItemVersionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<ItemVersion>(
      row,
      conflictColumns: conflictColumns(ItemVersion.t),
      updateColumns: updateColumns?.call(ItemVersion.t),
      updateWhere: updateWhere?.call(ItemVersion.t),
      transaction: transaction,
    );
  }

  /// Updates all [ItemVersion]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ItemVersion>> update(
    _is.DatabaseSession session,
    List<ItemVersion> rows, {
    _is.ColumnSelections<ItemVersionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<ItemVersion>(
      rows,
      columns: columns?.call(ItemVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [ItemVersion]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<ItemVersion> updateRow(
    _is.DatabaseSession session,
    ItemVersion row, {
    _is.ColumnSelections<ItemVersionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<ItemVersion>(
      row,
      columns: columns?.call(ItemVersion.t),
      transaction: transaction,
    );
  }

  /// Updates a single [ItemVersion] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<ItemVersion?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<ItemVersionUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<ItemVersion>(
      id,
      columnValues: columnValues(ItemVersion.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [ItemVersion]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<ItemVersion>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<ItemVersionUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<ItemVersionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<ItemVersion>(
      columnValues: columnValues(ItemVersion.t.updateTable),
      where: where(ItemVersion.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [ItemVersion]s in the list and returns the deleted rows.
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
  Future<List<ItemVersion>> delete(
    _is.DatabaseSession session,
    List<ItemVersion> rows, {
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<ItemVersion>(
      rows,
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [ItemVersion].
  Future<ItemVersion> deleteRow(
    _is.DatabaseSession session,
    ItemVersion row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<ItemVersion>(
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
  Future<List<ItemVersion>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ItemVersionTable> where,
    _is.OrderByBuilder<ItemVersionTable>? orderBy,
    _is.OrderByListBuilder<ItemVersionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<ItemVersion>(
      where: where(ItemVersion.t),
      orderBy: orderBy?.call(ItemVersion.t),
      orderByList: orderByList?.call(ItemVersion.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<ItemVersionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<ItemVersion>(
      where: where?.call(ItemVersion.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [ItemVersion] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<ItemVersionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<ItemVersion>(
      where: where(ItemVersion.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
