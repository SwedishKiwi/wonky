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

/// Every PR the GitHub App has seen (specs/16 §13).
abstract class BoardPullRequest
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  BoardPullRequest._({
    this.id,
    required this.prNumber,
    this.taskId,
    required this.authorLogin,
    required this.headSha,
    required this.state,
    required this.gateState,
    this.gateReason,
    this.gateFirstFailedAt,
    this.gateCommentId,
    this.reviewCommentId,
    this.lastReviewSha,
    this.lastReviewJson,
    this.lastReviewAt,
    this.reviewDay,
    int? reviewCount,
    this.mergeCommitSha,
    this.reviewPendingSha,
    this.reviewDueAt,
    required this.createdAt,
    required this.updatedAt,
  }) : reviewCount = reviewCount ?? 0;

  factory BoardPullRequest({
    int? id,
    required int prNumber,
    int? taskId,
    required String authorLogin,
    required String headSha,
    required String state,
    required String gateState,
    String? gateReason,
    DateTime? gateFirstFailedAt,
    int? gateCommentId,
    int? reviewCommentId,
    String? lastReviewSha,
    String? lastReviewJson,
    DateTime? lastReviewAt,
    String? reviewDay,
    int? reviewCount,
    String? mergeCommitSha,
    String? reviewPendingSha,
    DateTime? reviewDueAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _BoardPullRequestImpl;

  factory BoardPullRequest.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardPullRequest(
      id: jsonSerialization['id'] as int?,
      prNumber: jsonSerialization['prNumber'] as int,
      taskId: jsonSerialization['taskId'] as int?,
      authorLogin: jsonSerialization['authorLogin'] as String,
      headSha: jsonSerialization['headSha'] as String,
      state: jsonSerialization['state'] as String,
      gateState: jsonSerialization['gateState'] as String,
      gateReason: jsonSerialization['gateReason'] as String?,
      gateFirstFailedAt: jsonSerialization['gateFirstFailedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['gateFirstFailedAt'],
            ),
      gateCommentId: jsonSerialization['gateCommentId'] as int?,
      reviewCommentId: jsonSerialization['reviewCommentId'] as int?,
      lastReviewSha: jsonSerialization['lastReviewSha'] as String?,
      lastReviewJson: jsonSerialization['lastReviewJson'] as String?,
      lastReviewAt: jsonSerialization['lastReviewAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['lastReviewAt'],
            ),
      reviewDay: jsonSerialization['reviewDay'] as String?,
      reviewCount: jsonSerialization['reviewCount'] as int?,
      mergeCommitSha: jsonSerialization['mergeCommitSha'] as String?,
      reviewPendingSha: jsonSerialization['reviewPendingSha'] as String?,
      reviewDueAt: jsonSerialization['reviewDueAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['reviewDueAt'],
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = BoardPullRequestTable();

  static const db = BoardPullRequestRepository._();

  @override
  int? id;

  int prNumber;

  int? taskId;

  String authorLogin;

  String headSha;

  /// open | closed | merged
  String state;

  /// pending | passed | failed | exempt
  String gateState;

  String? gateReason;

  DateTime? gateFirstFailedAt;

  int? gateCommentId;

  int? reviewCommentId;

  String? lastReviewSha;

  String? lastReviewJson;

  DateTime? lastReviewAt;

  /// yyyy-mm-dd of [reviewCount].
  String? reviewDay;

  int reviewCount;

  String? mergeCommitSha;

  /// The head SHA a review is scheduled for (debounce, budget or daily
  /// limit postponement; specs/16 §13.5) and when it is due.
  String? reviewPendingSha;

  DateTime? reviewDueAt;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [BoardPullRequest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardPullRequest copyWith({
    int? id,
    int? prNumber,
    int? taskId,
    String? authorLogin,
    String? headSha,
    String? state,
    String? gateState,
    String? gateReason,
    DateTime? gateFirstFailedAt = const _is.$UndefinedDateTime(),
    int? gateCommentId,
    int? reviewCommentId,
    String? lastReviewSha,
    String? lastReviewJson,
    DateTime? lastReviewAt = const _is.$UndefinedDateTime(),
    String? reviewDay,
    int? reviewCount,
    String? mergeCommitSha,
    String? reviewPendingSha,
    DateTime? reviewDueAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardPullRequest',
      if (id != null) 'id': id,
      'prNumber': prNumber,
      if (taskId != null) 'taskId': taskId,
      'authorLogin': authorLogin,
      'headSha': headSha,
      'state': state,
      'gateState': gateState,
      if (gateReason != null) 'gateReason': gateReason,
      if (gateFirstFailedAt != null)
        'gateFirstFailedAt': gateFirstFailedAt?.toJson(),
      if (gateCommentId != null) 'gateCommentId': gateCommentId,
      if (reviewCommentId != null) 'reviewCommentId': reviewCommentId,
      if (lastReviewSha != null) 'lastReviewSha': lastReviewSha,
      if (lastReviewJson != null) 'lastReviewJson': lastReviewJson,
      if (lastReviewAt != null) 'lastReviewAt': lastReviewAt?.toJson(),
      if (reviewDay != null) 'reviewDay': reviewDay,
      'reviewCount': reviewCount,
      if (mergeCommitSha != null) 'mergeCommitSha': mergeCommitSha,
      if (reviewPendingSha != null) 'reviewPendingSha': reviewPendingSha,
      if (reviewDueAt != null) 'reviewDueAt': reviewDueAt?.toJson(),
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static BoardPullRequestInclude include() {
    return BoardPullRequestInclude._();
  }

  static BoardPullRequestIncludeList includeList({
    _is.WhereExpressionBuilder<BoardPullRequestTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    BoardPullRequestInclude? include,
  }) {
    return BoardPullRequestIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardPullRequestImpl extends BoardPullRequest {
  _BoardPullRequestImpl({
    int? id,
    required int prNumber,
    int? taskId,
    required String authorLogin,
    required String headSha,
    required String state,
    required String gateState,
    String? gateReason,
    DateTime? gateFirstFailedAt,
    int? gateCommentId,
    int? reviewCommentId,
    String? lastReviewSha,
    String? lastReviewJson,
    DateTime? lastReviewAt,
    String? reviewDay,
    int? reviewCount,
    String? mergeCommitSha,
    String? reviewPendingSha,
    DateTime? reviewDueAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         prNumber: prNumber,
         taskId: taskId,
         authorLogin: authorLogin,
         headSha: headSha,
         state: state,
         gateState: gateState,
         gateReason: gateReason,
         gateFirstFailedAt: gateFirstFailedAt,
         gateCommentId: gateCommentId,
         reviewCommentId: reviewCommentId,
         lastReviewSha: lastReviewSha,
         lastReviewJson: lastReviewJson,
         lastReviewAt: lastReviewAt,
         reviewDay: reviewDay,
         reviewCount: reviewCount,
         mergeCommitSha: mergeCommitSha,
         reviewPendingSha: reviewPendingSha,
         reviewDueAt: reviewDueAt,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [BoardPullRequest]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardPullRequest copyWith({
    Object? id = _Undefined,
    int? prNumber,
    Object? taskId = _Undefined,
    String? authorLogin,
    String? headSha,
    String? state,
    String? gateState,
    Object? gateReason = _Undefined,
    DateTime? gateFirstFailedAt = const _is.$UndefinedDateTime(),
    Object? gateCommentId = _Undefined,
    Object? reviewCommentId = _Undefined,
    Object? lastReviewSha = _Undefined,
    Object? lastReviewJson = _Undefined,
    DateTime? lastReviewAt = const _is.$UndefinedDateTime(),
    Object? reviewDay = _Undefined,
    int? reviewCount,
    Object? mergeCommitSha = _Undefined,
    Object? reviewPendingSha = _Undefined,
    DateTime? reviewDueAt = const _is.$UndefinedDateTime(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BoardPullRequest(
      id: id is int? ? id : this.id,
      prNumber: prNumber ?? this.prNumber,
      taskId: taskId is int? ? taskId : this.taskId,
      authorLogin: authorLogin ?? this.authorLogin,
      headSha: headSha ?? this.headSha,
      state: state ?? this.state,
      gateState: gateState ?? this.gateState,
      gateReason: gateReason is String? ? gateReason : this.gateReason,
      gateFirstFailedAt: gateFirstFailedAt is _is.UndefinedSentinel
          ? this.gateFirstFailedAt
          : gateFirstFailedAt,
      gateCommentId: gateCommentId is int? ? gateCommentId : this.gateCommentId,
      reviewCommentId: reviewCommentId is int?
          ? reviewCommentId
          : this.reviewCommentId,
      lastReviewSha: lastReviewSha is String?
          ? lastReviewSha
          : this.lastReviewSha,
      lastReviewJson: lastReviewJson is String?
          ? lastReviewJson
          : this.lastReviewJson,
      lastReviewAt: lastReviewAt is _is.UndefinedSentinel
          ? this.lastReviewAt
          : lastReviewAt,
      reviewDay: reviewDay is String? ? reviewDay : this.reviewDay,
      reviewCount: reviewCount ?? this.reviewCount,
      mergeCommitSha: mergeCommitSha is String?
          ? mergeCommitSha
          : this.mergeCommitSha,
      reviewPendingSha: reviewPendingSha is String?
          ? reviewPendingSha
          : this.reviewPendingSha,
      reviewDueAt: reviewDueAt is _is.UndefinedSentinel
          ? this.reviewDueAt
          : reviewDueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BoardPullRequestUpdateTable
    extends _is.UpdateTable<BoardPullRequestTable> {
  BoardPullRequestUpdateTable(super.table);

  _is.ColumnValue<int, int> prNumber(int value) => _is.ColumnValue(
    table.prNumber,
    value,
  );

  _is.ColumnValue<int, int> taskId(int? value) => _is.ColumnValue(
    table.taskId,
    value,
  );

  _is.ColumnValue<String, String> authorLogin(String value) => _is.ColumnValue(
    table.authorLogin,
    value,
  );

  _is.ColumnValue<String, String> headSha(String value) => _is.ColumnValue(
    table.headSha,
    value,
  );

  _is.ColumnValue<String, String> state(String value) => _is.ColumnValue(
    table.state,
    value,
  );

  _is.ColumnValue<String, String> gateState(String value) => _is.ColumnValue(
    table.gateState,
    value,
  );

  _is.ColumnValue<String, String> gateReason(String? value) => _is.ColumnValue(
    table.gateReason,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> gateFirstFailedAt(DateTime? value) =>
      _is.ColumnValue(
        table.gateFirstFailedAt,
        value,
      );

  _is.ColumnValue<int, int> gateCommentId(int? value) => _is.ColumnValue(
    table.gateCommentId,
    value,
  );

  _is.ColumnValue<int, int> reviewCommentId(int? value) => _is.ColumnValue(
    table.reviewCommentId,
    value,
  );

  _is.ColumnValue<String, String> lastReviewSha(String? value) =>
      _is.ColumnValue(
        table.lastReviewSha,
        value,
      );

  _is.ColumnValue<String, String> lastReviewJson(String? value) =>
      _is.ColumnValue(
        table.lastReviewJson,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastReviewAt(DateTime? value) =>
      _is.ColumnValue(
        table.lastReviewAt,
        value,
      );

  _is.ColumnValue<String, String> reviewDay(String? value) => _is.ColumnValue(
    table.reviewDay,
    value,
  );

  _is.ColumnValue<int, int> reviewCount(int value) => _is.ColumnValue(
    table.reviewCount,
    value,
  );

  _is.ColumnValue<String, String> mergeCommitSha(String? value) =>
      _is.ColumnValue(
        table.mergeCommitSha,
        value,
      );

  _is.ColumnValue<String, String> reviewPendingSha(String? value) =>
      _is.ColumnValue(
        table.reviewPendingSha,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> reviewDueAt(DateTime? value) =>
      _is.ColumnValue(
        table.reviewDueAt,
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
}

class BoardPullRequestTable extends _is.Table<int?> {
  BoardPullRequestTable({super.tableRelation})
    : super(tableName: 'board_pull_request') {
    updateTable = BoardPullRequestUpdateTable(this);
    prNumber = _is.ColumnInt(
      'prNumber',
      this,
    );
    taskId = _is.ColumnInt(
      'taskId',
      this,
    );
    authorLogin = _is.ColumnString(
      'authorLogin',
      this,
    );
    headSha = _is.ColumnString(
      'headSha',
      this,
    );
    state = _is.ColumnString(
      'state',
      this,
    );
    gateState = _is.ColumnString(
      'gateState',
      this,
    );
    gateReason = _is.ColumnString(
      'gateReason',
      this,
    );
    gateFirstFailedAt = _is.ColumnDateTime(
      'gateFirstFailedAt',
      this,
    );
    gateCommentId = _is.ColumnInt(
      'gateCommentId',
      this,
    );
    reviewCommentId = _is.ColumnInt(
      'reviewCommentId',
      this,
    );
    lastReviewSha = _is.ColumnString(
      'lastReviewSha',
      this,
    );
    lastReviewJson = _is.ColumnString(
      'lastReviewJson',
      this,
    );
    lastReviewAt = _is.ColumnDateTime(
      'lastReviewAt',
      this,
    );
    reviewDay = _is.ColumnString(
      'reviewDay',
      this,
    );
    reviewCount = _is.ColumnInt(
      'reviewCount',
      this,
      hasDefault: true,
    );
    mergeCommitSha = _is.ColumnString(
      'mergeCommitSha',
      this,
    );
    reviewPendingSha = _is.ColumnString(
      'reviewPendingSha',
      this,
    );
    reviewDueAt = _is.ColumnDateTime(
      'reviewDueAt',
      this,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final BoardPullRequestUpdateTable updateTable;

  late final _is.ColumnInt prNumber;

  late final _is.ColumnInt taskId;

  late final _is.ColumnString authorLogin;

  late final _is.ColumnString headSha;

  /// open | closed | merged
  late final _is.ColumnString state;

  /// pending | passed | failed | exempt
  late final _is.ColumnString gateState;

  late final _is.ColumnString gateReason;

  late final _is.ColumnDateTime gateFirstFailedAt;

  late final _is.ColumnInt gateCommentId;

  late final _is.ColumnInt reviewCommentId;

  late final _is.ColumnString lastReviewSha;

  late final _is.ColumnString lastReviewJson;

  late final _is.ColumnDateTime lastReviewAt;

  /// yyyy-mm-dd of [reviewCount].
  late final _is.ColumnString reviewDay;

  late final _is.ColumnInt reviewCount;

  late final _is.ColumnString mergeCommitSha;

  /// The head SHA a review is scheduled for (debounce, budget or daily
  /// limit postponement; specs/16 §13.5) and when it is due.
  late final _is.ColumnString reviewPendingSha;

  late final _is.ColumnDateTime reviewDueAt;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    prNumber,
    taskId,
    authorLogin,
    headSha,
    state,
    gateState,
    gateReason,
    gateFirstFailedAt,
    gateCommentId,
    reviewCommentId,
    lastReviewSha,
    lastReviewJson,
    lastReviewAt,
    reviewDay,
    reviewCount,
    mergeCommitSha,
    reviewPendingSha,
    reviewDueAt,
    createdAt,
    updatedAt,
  ];
}

class BoardPullRequestInclude extends _is.IncludeObject {
  BoardPullRequestInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => BoardPullRequest.t;
}

class BoardPullRequestIncludeList extends _is.IncludeList {
  BoardPullRequestIncludeList._({
    _is.WhereExpressionBuilder<BoardPullRequestTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(BoardPullRequest.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => BoardPullRequest.t;
}

class BoardPullRequestRepository {
  const BoardPullRequestRepository._();

  /// Returns a list of [BoardPullRequest]s matching the given query parameters.
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
  Future<List<BoardPullRequest>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPullRequestTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<BoardPullRequest>(
      where: where?.call(BoardPullRequest.t),
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [BoardPullRequest]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `BoardPullRequest.t`.
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
  _ida.Stream<List<BoardPullRequest>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPullRequestTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<BoardPullRequest>(
      where: where?.call(BoardPullRequest.t),
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [BoardPullRequest] matching the given query parameters.
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
  Future<BoardPullRequest?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPullRequestTable>? where,
    int? offset,
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<BoardPullRequest>(
      where: where?.call(BoardPullRequest.t),
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [BoardPullRequest] by its [id] or null if no such row exists.
  Future<BoardPullRequest?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<BoardPullRequest>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [BoardPullRequest]s in the list and returns the inserted rows.
  ///
  /// The returned [BoardPullRequest]s will have their `id` fields set.
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
  Future<List<BoardPullRequest>> insert(
    _is.DatabaseSession session,
    List<BoardPullRequest> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<BoardPullRequest>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [BoardPullRequest] and returns the inserted row.
  ///
  /// The returned [BoardPullRequest] will have its `id` field set.
  Future<BoardPullRequest> insertRow(
    _is.DatabaseSession session,
    BoardPullRequest row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<BoardPullRequest>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [BoardPullRequest]s in the list and returns the resulting rows.
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
  /// The returned [BoardPullRequest]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPullRequest>> upsert(
    _is.DatabaseSession session,
    List<BoardPullRequest> rows, {
    required _is.ColumnSelections<BoardPullRequestTable> conflictColumns,
    _is.ColumnSelections<BoardPullRequestTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardPullRequestTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<BoardPullRequest>(
      rows,
      conflictColumns: conflictColumns(BoardPullRequest.t),
      updateColumns: updateColumns?.call(BoardPullRequest.t),
      updateWhere: updateWhere?.call(BoardPullRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [BoardPullRequest] and returns the resulting row.
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
  /// The returned [BoardPullRequest] will have its `id` field set.
  Future<BoardPullRequest?> upsertRow(
    _is.DatabaseSession session,
    BoardPullRequest row, {
    required _is.ColumnSelections<BoardPullRequestTable> conflictColumns,
    _is.ColumnSelections<BoardPullRequestTable>? updateColumns,
    _is.WhereExpressionBuilder<BoardPullRequestTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<BoardPullRequest>(
      row,
      conflictColumns: conflictColumns(BoardPullRequest.t),
      updateColumns: updateColumns?.call(BoardPullRequest.t),
      updateWhere: updateWhere?.call(BoardPullRequest.t),
      transaction: transaction,
    );
  }

  /// Updates all [BoardPullRequest]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPullRequest>> update(
    _is.DatabaseSession session,
    List<BoardPullRequest> rows, {
    _is.ColumnSelections<BoardPullRequestTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<BoardPullRequest>(
      rows,
      columns: columns?.call(BoardPullRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [BoardPullRequest]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<BoardPullRequest> updateRow(
    _is.DatabaseSession session,
    BoardPullRequest row, {
    _is.ColumnSelections<BoardPullRequestTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<BoardPullRequest>(
      row,
      columns: columns?.call(BoardPullRequest.t),
      transaction: transaction,
    );
  }

  /// Updates a single [BoardPullRequest] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<BoardPullRequest?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<BoardPullRequestUpdateTable>
    columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<BoardPullRequest>(
      id,
      columnValues: columnValues(BoardPullRequest.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [BoardPullRequest]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<BoardPullRequest>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<BoardPullRequestUpdateTable>
    columnValues,
    required _is.WhereExpressionBuilder<BoardPullRequestTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<BoardPullRequest>(
      columnValues: columnValues(BoardPullRequest.t.updateTable),
      where: where(BoardPullRequest.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [BoardPullRequest]s in the list and returns the deleted rows.
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
  Future<List<BoardPullRequest>> delete(
    _is.DatabaseSession session,
    List<BoardPullRequest> rows, {
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<BoardPullRequest>(
      rows,
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [BoardPullRequest].
  Future<BoardPullRequest> deleteRow(
    _is.DatabaseSession session,
    BoardPullRequest row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<BoardPullRequest>(
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
  Future<List<BoardPullRequest>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardPullRequestTable> where,
    _is.OrderByBuilder<BoardPullRequestTable>? orderBy,
    _is.OrderByListBuilder<BoardPullRequestTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<BoardPullRequest>(
      where: where(BoardPullRequest.t),
      orderBy: orderBy?.call(BoardPullRequest.t),
      orderByList: orderByList?.call(BoardPullRequest.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<BoardPullRequestTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<BoardPullRequest>(
      where: where?.call(BoardPullRequest.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [BoardPullRequest] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<BoardPullRequestTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<BoardPullRequest>(
      where: where(BoardPullRequest.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
