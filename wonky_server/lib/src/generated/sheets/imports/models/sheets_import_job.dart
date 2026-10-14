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
import '../../../sheets/imports/models/sheets_import_status.dart' as _i8aac5e2;

/// A server-side import into an existing spreadsheet (Sheets 11 §3.3,
/// A-11-2): queued by `sheetsImport.importInto`, run by the instance that
/// leases it, watched with `sheetsImport.watchImport`. One running job per
/// user; others wait queued.
abstract class SheetsImportJob
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  SheetsImportJob._({
    this.id,
    required this.uuid,
    required this.userId,
    required this.authUserId,
    required this.spreadsheetUuid,
    required this.uploadFileId,
    required this.fileName,
    required this.format,
    required this.optionsJson,
    this.activeSheetId,
    required this.status,
    required this.progressDone,
    required this.progressTotal,
    this.reportJson,
    this.sheetIdsJson,
    this.changeId,
    this.errorCode,
    this.error,
    bool? cancelRequested,
    required this.createdAt,
    required this.updatedAt,
    this.leaseOwner,
    this.leaseUntil,
  }) : cancelRequested = cancelRequested ?? false;

  factory SheetsImportJob({
    int? id,
    required _is.UuidValue uuid,
    required int userId,
    required _is.UuidValue authUserId,
    required _is.UuidValue spreadsheetUuid,
    required _is.UuidValue uploadFileId,
    required String fileName,
    required String format,
    required String optionsJson,
    String? activeSheetId,
    required _i8aac5e2.SheetsImportStatus status,
    required int progressDone,
    required int progressTotal,
    String? reportJson,
    String? sheetIdsJson,
    _is.UuidValue? changeId,
    String? errorCode,
    String? error,
    bool? cancelRequested,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? leaseOwner,
    DateTime? leaseUntil,
  }) = _SheetsImportJobImpl;

  factory SheetsImportJob.fromJson(Map<String, dynamic> jsonSerialization) {
    return SheetsImportJob(
      id: jsonSerialization['id'] as int?,
      uuid: _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      userId: jsonSerialization['userId'] as int,
      authUserId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['authUserId'],
      ),
      spreadsheetUuid: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['spreadsheetUuid'],
      ),
      uploadFileId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['uploadFileId'],
      ),
      fileName: jsonSerialization['fileName'] as String,
      format: jsonSerialization['format'] as String,
      optionsJson: jsonSerialization['optionsJson'] as String,
      activeSheetId: jsonSerialization['activeSheetId'] as String?,
      status: _i8aac5e2.SheetsImportStatus.fromJson(
        (jsonSerialization['status'] as String),
      ),
      progressDone: jsonSerialization['progressDone'] as int,
      progressTotal: jsonSerialization['progressTotal'] as int,
      reportJson: jsonSerialization['reportJson'] as String?,
      sheetIdsJson: jsonSerialization['sheetIdsJson'] as String?,
      changeId: jsonSerialization['changeId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['changeId']),
      errorCode: jsonSerialization['errorCode'] as String?,
      error: jsonSerialization['error'] as String?,
      cancelRequested: jsonSerialization['cancelRequested'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['cancelRequested'],
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      leaseOwner: jsonSerialization['leaseOwner'] as String?,
      leaseUntil: jsonSerialization['leaseUntil'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['leaseUntil']),
    );
  }

  static final t = SheetsImportJobTable();

  static const db = SheetsImportJobRepository._();

  @override
  int? id;

  _is.UuidValue uuid;

  /// UserProfile id and auth user of the importing user.
  int userId;

  _is.UuidValue authUserId;

  /// Drive item (= space) the file is imported into.
  _is.UuidValue spreadsheetUuid;

  /// The uploaded source (`StoredFileKind.importSource`), deleted after the job.
  _is.UuidValue uploadFileId;

  String fileName;

  String format;

  /// `ImportOptions` JSON (11 §9).
  String optionsJson;

  /// Target sheet of the in-sheet locations and insert position of new sheets.
  String? activeSheetId;

  _i8aac5e2.SheetsImportStatus status;

  /// Written cells (`writing`) of [progressTotal].
  int progressDone;

  int progressTotal;

  /// `ImportReport` JSON once done.
  String? reportJson;

  /// JSON list of the ids of the sheets the import created.
  String? sheetIdsJson;

  /// `ServerChangeRecord.changeId` of the import (undo: `sheets.serverChange`).
  _is.UuidValue? changeId;

  String? errorCode;

  String? error;

  bool cancelRequested;

  DateTime createdAt;

  DateTime updatedAt;

  String? leaseOwner;

  DateTime? leaseUntil;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [SheetsImportJob]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  SheetsImportJob copyWith({
    int? id,
    _is.UuidValue? uuid,
    int? userId,
    _is.UuidValue? authUserId,
    _is.UuidValue? spreadsheetUuid,
    _is.UuidValue? uploadFileId,
    String? fileName,
    String? format,
    String? optionsJson,
    String? activeSheetId,
    _i8aac5e2.SheetsImportStatus? status,
    int? progressDone,
    int? progressTotal,
    String? reportJson,
    String? sheetIdsJson,
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
    String? errorCode,
    String? error,
    bool? cancelRequested,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? leaseOwner,
    DateTime? leaseUntil = const _is.$UndefinedDateTime(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SheetsImportJob',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'userId': userId,
      'authUserId': authUserId.toJson(),
      'spreadsheetUuid': spreadsheetUuid.toJson(),
      'uploadFileId': uploadFileId.toJson(),
      'fileName': fileName,
      'format': format,
      'optionsJson': optionsJson,
      if (activeSheetId != null) 'activeSheetId': activeSheetId,
      'status': status.toJson(),
      'progressDone': progressDone,
      'progressTotal': progressTotal,
      if (reportJson != null) 'reportJson': reportJson,
      if (sheetIdsJson != null) 'sheetIdsJson': sheetIdsJson,
      if (changeId != null) 'changeId': changeId?.toJson(),
      if (errorCode != null) 'errorCode': errorCode,
      if (error != null) 'error': error,
      'cancelRequested': cancelRequested,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      if (leaseOwner != null) 'leaseOwner': leaseOwner,
      if (leaseUntil != null) 'leaseUntil': leaseUntil?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static SheetsImportJobInclude include() {
    return SheetsImportJobInclude._();
  }

  static SheetsImportJobIncludeList includeList({
    _is.WhereExpressionBuilder<SheetsImportJobTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    SheetsImportJobInclude? include,
  }) {
    return SheetsImportJobIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _SheetsImportJobImpl extends SheetsImportJob {
  _SheetsImportJobImpl({
    int? id,
    required _is.UuidValue uuid,
    required int userId,
    required _is.UuidValue authUserId,
    required _is.UuidValue spreadsheetUuid,
    required _is.UuidValue uploadFileId,
    required String fileName,
    required String format,
    required String optionsJson,
    String? activeSheetId,
    required _i8aac5e2.SheetsImportStatus status,
    required int progressDone,
    required int progressTotal,
    String? reportJson,
    String? sheetIdsJson,
    _is.UuidValue? changeId,
    String? errorCode,
    String? error,
    bool? cancelRequested,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? leaseOwner,
    DateTime? leaseUntil,
  }) : super._(
         id: id,
         uuid: uuid,
         userId: userId,
         authUserId: authUserId,
         spreadsheetUuid: spreadsheetUuid,
         uploadFileId: uploadFileId,
         fileName: fileName,
         format: format,
         optionsJson: optionsJson,
         activeSheetId: activeSheetId,
         status: status,
         progressDone: progressDone,
         progressTotal: progressTotal,
         reportJson: reportJson,
         sheetIdsJson: sheetIdsJson,
         changeId: changeId,
         errorCode: errorCode,
         error: error,
         cancelRequested: cancelRequested,
         createdAt: createdAt,
         updatedAt: updatedAt,
         leaseOwner: leaseOwner,
         leaseUntil: leaseUntil,
       );

  /// Returns a shallow copy of this [SheetsImportJob]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  SheetsImportJob copyWith({
    Object? id = _Undefined,
    _is.UuidValue? uuid,
    int? userId,
    _is.UuidValue? authUserId,
    _is.UuidValue? spreadsheetUuid,
    _is.UuidValue? uploadFileId,
    String? fileName,
    String? format,
    String? optionsJson,
    Object? activeSheetId = _Undefined,
    _i8aac5e2.SheetsImportStatus? status,
    int? progressDone,
    int? progressTotal,
    Object? reportJson = _Undefined,
    Object? sheetIdsJson = _Undefined,
    _is.UuidValue? changeId = const _is.$UndefinedUuidValue(),
    Object? errorCode = _Undefined,
    Object? error = _Undefined,
    bool? cancelRequested,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? leaseOwner = _Undefined,
    DateTime? leaseUntil = const _is.$UndefinedDateTime(),
  }) {
    return SheetsImportJob(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      userId: userId ?? this.userId,
      authUserId: authUserId ?? this.authUserId,
      spreadsheetUuid: spreadsheetUuid ?? this.spreadsheetUuid,
      uploadFileId: uploadFileId ?? this.uploadFileId,
      fileName: fileName ?? this.fileName,
      format: format ?? this.format,
      optionsJson: optionsJson ?? this.optionsJson,
      activeSheetId: activeSheetId is String?
          ? activeSheetId
          : this.activeSheetId,
      status: status ?? this.status,
      progressDone: progressDone ?? this.progressDone,
      progressTotal: progressTotal ?? this.progressTotal,
      reportJson: reportJson is String? ? reportJson : this.reportJson,
      sheetIdsJson: sheetIdsJson is String? ? sheetIdsJson : this.sheetIdsJson,
      changeId: changeId is _is.UndefinedSentinel ? this.changeId : changeId,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      error: error is String? ? error : this.error,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      leaseOwner: leaseOwner is String? ? leaseOwner : this.leaseOwner,
      leaseUntil: leaseUntil is _is.UndefinedSentinel
          ? this.leaseUntil
          : leaseUntil,
    );
  }
}

class SheetsImportJobUpdateTable extends _is.UpdateTable<SheetsImportJobTable> {
  SheetsImportJobUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.uuid,
        value,
      );

  _is.ColumnValue<int, int> userId(int value) => _is.ColumnValue(
    table.userId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> authUserId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.authUserId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> spreadsheetUuid(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.spreadsheetUuid,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uploadFileId(
    _is.UuidValue value,
  ) => _is.ColumnValue(
    table.uploadFileId,
    value,
  );

  _is.ColumnValue<String, String> fileName(String value) => _is.ColumnValue(
    table.fileName,
    value,
  );

  _is.ColumnValue<String, String> format(String value) => _is.ColumnValue(
    table.format,
    value,
  );

  _is.ColumnValue<String, String> optionsJson(String value) => _is.ColumnValue(
    table.optionsJson,
    value,
  );

  _is.ColumnValue<String, String> activeSheetId(String? value) =>
      _is.ColumnValue(
        table.activeSheetId,
        value,
      );

  _is.ColumnValue<_i8aac5e2.SheetsImportStatus, _i8aac5e2.SheetsImportStatus>
  status(_i8aac5e2.SheetsImportStatus value) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<int, int> progressDone(int value) => _is.ColumnValue(
    table.progressDone,
    value,
  );

  _is.ColumnValue<int, int> progressTotal(int value) => _is.ColumnValue(
    table.progressTotal,
    value,
  );

  _is.ColumnValue<String, String> reportJson(String? value) => _is.ColumnValue(
    table.reportJson,
    value,
  );

  _is.ColumnValue<String, String> sheetIdsJson(String? value) =>
      _is.ColumnValue(
        table.sheetIdsJson,
        value,
      );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> changeId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.changeId,
    value,
  );

  _is.ColumnValue<String, String> errorCode(String? value) => _is.ColumnValue(
    table.errorCode,
    value,
  );

  _is.ColumnValue<String, String> error(String? value) => _is.ColumnValue(
    table.error,
    value,
  );

  _is.ColumnValue<bool, bool> cancelRequested(bool value) => _is.ColumnValue(
    table.cancelRequested,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );

  _is.ColumnValue<String, String> leaseOwner(String? value) => _is.ColumnValue(
    table.leaseOwner,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> leaseUntil(DateTime? value) =>
      _is.ColumnValue(
        table.leaseUntil,
        value,
      );
}

class SheetsImportJobTable extends _is.Table<int?> {
  SheetsImportJobTable({super.tableRelation})
    : super(tableName: 'sheets_import_job') {
    updateTable = SheetsImportJobUpdateTable(this);
    uuid = _is.ColumnUuid(
      'uuid',
      this,
    );
    userId = _is.ColumnInt(
      'userId',
      this,
    );
    authUserId = _is.ColumnUuid(
      'authUserId',
      this,
    );
    spreadsheetUuid = _is.ColumnUuid(
      'spreadsheetUuid',
      this,
    );
    uploadFileId = _is.ColumnUuid(
      'uploadFileId',
      this,
    );
    fileName = _is.ColumnString(
      'fileName',
      this,
    );
    format = _is.ColumnString(
      'format',
      this,
    );
    optionsJson = _is.ColumnString(
      'optionsJson',
      this,
    );
    activeSheetId = _is.ColumnString(
      'activeSheetId',
      this,
    );
    status = _is.ColumnEnum(
      'status',
      this,
      _is.EnumSerialization.byName,
    );
    progressDone = _is.ColumnInt(
      'progressDone',
      this,
    );
    progressTotal = _is.ColumnInt(
      'progressTotal',
      this,
    );
    reportJson = _is.ColumnString(
      'reportJson',
      this,
    );
    sheetIdsJson = _is.ColumnString(
      'sheetIdsJson',
      this,
    );
    changeId = _is.ColumnUuid(
      'changeId',
      this,
    );
    errorCode = _is.ColumnString(
      'errorCode',
      this,
    );
    error = _is.ColumnString(
      'error',
      this,
    );
    cancelRequested = _is.ColumnBool(
      'cancelRequested',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
    leaseOwner = _is.ColumnString(
      'leaseOwner',
      this,
    );
    leaseUntil = _is.ColumnDateTime(
      'leaseUntil',
      this,
    );
  }

  late final SheetsImportJobUpdateTable updateTable;

  late final _is.ColumnUuid uuid;

  /// UserProfile id and auth user of the importing user.
  late final _is.ColumnInt userId;

  late final _is.ColumnUuid authUserId;

  /// Drive item (= space) the file is imported into.
  late final _is.ColumnUuid spreadsheetUuid;

  /// The uploaded source (`StoredFileKind.importSource`), deleted after the job.
  late final _is.ColumnUuid uploadFileId;

  late final _is.ColumnString fileName;

  late final _is.ColumnString format;

  /// `ImportOptions` JSON (11 §9).
  late final _is.ColumnString optionsJson;

  /// Target sheet of the in-sheet locations and insert position of new sheets.
  late final _is.ColumnString activeSheetId;

  late final _is.ColumnEnum<_i8aac5e2.SheetsImportStatus> status;

  /// Written cells (`writing`) of [progressTotal].
  late final _is.ColumnInt progressDone;

  late final _is.ColumnInt progressTotal;

  /// `ImportReport` JSON once done.
  late final _is.ColumnString reportJson;

  /// JSON list of the ids of the sheets the import created.
  late final _is.ColumnString sheetIdsJson;

  /// `ServerChangeRecord.changeId` of the import (undo: `sheets.serverChange`).
  late final _is.ColumnUuid changeId;

  late final _is.ColumnString errorCode;

  late final _is.ColumnString error;

  late final _is.ColumnBool cancelRequested;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  late final _is.ColumnString leaseOwner;

  late final _is.ColumnDateTime leaseUntil;

  @override
  List<_is.Column> get columns => [
    id,
    uuid,
    userId,
    authUserId,
    spreadsheetUuid,
    uploadFileId,
    fileName,
    format,
    optionsJson,
    activeSheetId,
    status,
    progressDone,
    progressTotal,
    reportJson,
    sheetIdsJson,
    changeId,
    errorCode,
    error,
    cancelRequested,
    createdAt,
    updatedAt,
    leaseOwner,
    leaseUntil,
  ];
}

class SheetsImportJobInclude extends _is.IncludeObject {
  SheetsImportJobInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => SheetsImportJob.t;
}

class SheetsImportJobIncludeList extends _is.IncludeList {
  SheetsImportJobIncludeList._({
    _is.WhereExpressionBuilder<SheetsImportJobTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SheetsImportJob.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => SheetsImportJob.t;
}

class SheetsImportJobRepository {
  const SheetsImportJobRepository._();

  /// Returns a list of [SheetsImportJob]s matching the given query parameters.
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
  Future<List<SheetsImportJob>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsImportJobTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SheetsImportJob>(
      where: where?.call(SheetsImportJob.t),
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SheetsImportJob]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SheetsImportJob.t`.
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
  _ida.Stream<List<SheetsImportJob>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsImportJobTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SheetsImportJob>(
      where: where?.call(SheetsImportJob.t),
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SheetsImportJob] matching the given query parameters.
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
  Future<SheetsImportJob?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsImportJobTable>? where,
    int? offset,
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SheetsImportJob>(
      where: where?.call(SheetsImportJob.t),
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SheetsImportJob] by its [id] or null if no such row exists.
  Future<SheetsImportJob?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SheetsImportJob>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SheetsImportJob]s in the list and returns the inserted rows.
  ///
  /// The returned [SheetsImportJob]s will have their `id` fields set.
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
  Future<List<SheetsImportJob>> insert(
    _is.DatabaseSession session,
    List<SheetsImportJob> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SheetsImportJob>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SheetsImportJob] and returns the inserted row.
  ///
  /// The returned [SheetsImportJob] will have its `id` field set.
  Future<SheetsImportJob> insertRow(
    _is.DatabaseSession session,
    SheetsImportJob row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<SheetsImportJob>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [SheetsImportJob]s in the list and returns the resulting rows.
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
  /// The returned [SheetsImportJob]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsImportJob>> upsert(
    _is.DatabaseSession session,
    List<SheetsImportJob> rows, {
    required _is.ColumnSelections<SheetsImportJobTable> conflictColumns,
    _is.ColumnSelections<SheetsImportJobTable>? updateColumns,
    _is.WhereExpressionBuilder<SheetsImportJobTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SheetsImportJob>(
      rows,
      conflictColumns: conflictColumns(SheetsImportJob.t),
      updateColumns: updateColumns?.call(SheetsImportJob.t),
      updateWhere: updateWhere?.call(SheetsImportJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SheetsImportJob] and returns the resulting row.
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
  /// The returned [SheetsImportJob] will have its `id` field set.
  Future<SheetsImportJob?> upsertRow(
    _is.DatabaseSession session,
    SheetsImportJob row, {
    required _is.ColumnSelections<SheetsImportJobTable> conflictColumns,
    _is.ColumnSelections<SheetsImportJobTable>? updateColumns,
    _is.WhereExpressionBuilder<SheetsImportJobTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SheetsImportJob>(
      row,
      conflictColumns: conflictColumns(SheetsImportJob.t),
      updateColumns: updateColumns?.call(SheetsImportJob.t),
      updateWhere: updateWhere?.call(SheetsImportJob.t),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsImportJob]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsImportJob>> update(
    _is.DatabaseSession session,
    List<SheetsImportJob> rows, {
    _is.ColumnSelections<SheetsImportJobTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SheetsImportJob>(
      rows,
      columns: columns?.call(SheetsImportJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SheetsImportJob]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SheetsImportJob> updateRow(
    _is.DatabaseSession session,
    SheetsImportJob row, {
    _is.ColumnSelections<SheetsImportJobTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<SheetsImportJob>(
      row,
      columns: columns?.call(SheetsImportJob.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SheetsImportJob] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SheetsImportJob?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<SheetsImportJobUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<SheetsImportJob>(
      id,
      columnValues: columnValues(SheetsImportJob.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SheetsImportJob]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SheetsImportJob>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<SheetsImportJobUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<SheetsImportJobTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SheetsImportJob>(
      columnValues: columnValues(SheetsImportJob.t.updateTable),
      where: where(SheetsImportJob.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SheetsImportJob]s in the list and returns the deleted rows.
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
  Future<List<SheetsImportJob>> delete(
    _is.DatabaseSession session,
    List<SheetsImportJob> rows, {
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SheetsImportJob>(
      rows,
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SheetsImportJob].
  Future<SheetsImportJob> deleteRow(
    _is.DatabaseSession session,
    SheetsImportJob row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SheetsImportJob>(
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
  Future<List<SheetsImportJob>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SheetsImportJobTable> where,
    _is.OrderByBuilder<SheetsImportJobTable>? orderBy,
    _is.OrderByListBuilder<SheetsImportJobTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SheetsImportJob>(
      where: where(SheetsImportJob.t),
      orderBy: orderBy?.call(SheetsImportJob.t),
      orderByList: orderByList?.call(SheetsImportJob.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<SheetsImportJobTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<SheetsImportJob>(
      where: where?.call(SheetsImportJob.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SheetsImportJob] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<SheetsImportJobTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SheetsImportJob>(
      where: where(SheetsImportJob.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
