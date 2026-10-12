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
import '../../platform/drive/drive_item_kind.dart' as _i26ubj99;
import '../../platform/drive/template_category.dart' as _i4yf368z;

/// A file or folder in Wonky Drive (specs/05 §1, sharing settings 06 §2).
abstract class DriveItem
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DriveItem._({
    this.id,
    _is.UuidValue? uuid,
    required this.kind,
    required this.name,
    required this.ownerId,
    this.parentId,
    this.description,
    this.contentRef,
    this.thumbnailFileId,
    int? sizeBytes,
    required this.createdAt,
    required this.createdById,
    required this.modifiedAt,
    this.modifiedById,
    this.trashedAt,
    this.trashedById,
    this.templateOf,
    this.templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
    this.searchText,
  }) : uuid = uuid ?? const _is.Uuid().v7obj(),
       sizeBytes = sizeBytes ?? 0,
       editorsCanShare = editorsCanShare ?? true,
       nonEditorsCanExport = nonEditorsCanExport ?? true,
       viewersSeeComments = viewersSeeComments ?? false;

  factory DriveItem({
    int? id,
    _is.UuidValue? uuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required int ownerId,
    int? parentId,
    String? description,
    _is.UuidValue? contentRef,
    _is.UuidValue? thumbnailFileId,
    int? sizeBytes,
    required DateTime createdAt,
    required int createdById,
    required DateTime modifiedAt,
    int? modifiedById,
    DateTime? trashedAt,
    int? trashedById,
    _i4yf368z.TemplateCategory? templateOf,
    String? templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
    String? searchText,
  }) = _DriveItemImpl;

  factory DriveItem.fromJson(Map<String, dynamic> jsonSerialization) {
    return DriveItem(
      id: jsonSerialization['id'] as int?,
      uuid: jsonSerialization['uuid'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['uuid']),
      kind: _i26ubj99.DriveItemKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String,
      ownerId: jsonSerialization['ownerId'] as int,
      parentId: jsonSerialization['parentId'] as int?,
      description: jsonSerialization['description'] as String?,
      contentRef: jsonSerialization['contentRef'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['contentRef'],
            ),
      thumbnailFileId: jsonSerialization['thumbnailFileId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['thumbnailFileId'],
            ),
      sizeBytes: jsonSerialization['sizeBytes'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      createdById: jsonSerialization['createdById'] as int,
      modifiedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['modifiedAt'],
      ),
      modifiedById: jsonSerialization['modifiedById'] as int?,
      trashedAt: jsonSerialization['trashedAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['trashedAt']),
      trashedById: jsonSerialization['trashedById'] as int?,
      templateOf: jsonSerialization['templateOf'] == null
          ? null
          : _i4yf368z.TemplateCategory.fromJson(
              (jsonSerialization['templateOf'] as String),
            ),
      templateKey: jsonSerialization['templateKey'] as String?,
      editorsCanShare: jsonSerialization['editorsCanShare'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['editorsCanShare'],
            ),
      nonEditorsCanExport: jsonSerialization['nonEditorsCanExport'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['nonEditorsCanExport'],
            ),
      viewersSeeComments: jsonSerialization['viewersSeeComments'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['viewersSeeComments'],
            ),
      searchText: jsonSerialization['searchText'] as String?,
    );
  }

  static final t = DriveItemTable();

  static const db = DriveItemRepository._();

  @override
  int? id;

  /// Public id used in URLs: /d/<uuid>, /s/<uuid>.
  _is.UuidValue uuid;

  _i26ubj99.DriveItemKind kind;

  String name;

  int ownerId;

  /// Null = the owner's root.
  int? parentId;

  String? description;

  /// Documents: Document.uuid; spreadsheets: the sync space UUID (= Spreadsheet.id).
  _is.UuidValue? contentRef;

  _is.UuidValue? thumbnailFileId;

  int sizeBytes;

  DateTime createdAt;

  int createdById;

  /// Last content modification (any user).
  DateTime modifiedAt;

  int? modifiedById;

  DateTime? trashedAt;

  int? trashedById;

  /// Non-null = this item is a template in the gallery.
  _i4yf368z.TemplateCategory? templateOf;

  /// Built-in template key (gallery seeding), e.g. "write.meeting-notes".
  String? templateKey;

  bool editorsCanShare;

  bool nonEditorsCanExport;

  bool viewersSeeComments;

  /// Extracted plain text for search (document text; sheet names + cells).
  String? searchText;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DriveItem]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DriveItem copyWith({
    int? id,
    _is.UuidValue? uuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    int? ownerId,
    int? parentId,
    String? description,
    _is.UuidValue? contentRef = const _is.$UndefinedUuidValue(),
    _is.UuidValue? thumbnailFileId = const _is.$UndefinedUuidValue(),
    int? sizeBytes,
    DateTime? createdAt,
    int? createdById,
    DateTime? modifiedAt,
    int? modifiedById,
    DateTime? trashedAt = const _is.$UndefinedDateTime(),
    int? trashedById,
    _i4yf368z.TemplateCategory? templateOf,
    String? templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
    String? searchText,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DriveItem',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      'ownerId': ownerId,
      if (parentId != null) 'parentId': parentId,
      if (description != null) 'description': description,
      if (contentRef != null) 'contentRef': contentRef?.toJson(),
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toJson(),
      'createdById': createdById,
      'modifiedAt': modifiedAt.toJson(),
      if (modifiedById != null) 'modifiedById': modifiedById,
      if (trashedAt != null) 'trashedAt': trashedAt?.toJson(),
      if (trashedById != null) 'trashedById': trashedById,
      if (templateOf != null) 'templateOf': templateOf?.toJson(),
      if (templateKey != null) 'templateKey': templateKey,
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
      if (searchText != null) 'searchText': searchText,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DriveItem',
      if (id != null) 'id': id,
      'uuid': uuid.toJson(),
      'kind': kind.toJson(),
      'name': name,
      'ownerId': ownerId,
      if (parentId != null) 'parentId': parentId,
      if (description != null) 'description': description,
      if (contentRef != null) 'contentRef': contentRef?.toJson(),
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId?.toJson(),
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toJson(),
      'createdById': createdById,
      'modifiedAt': modifiedAt.toJson(),
      if (modifiedById != null) 'modifiedById': modifiedById,
      if (trashedAt != null) 'trashedAt': trashedAt?.toJson(),
      if (trashedById != null) 'trashedById': trashedById,
      if (templateOf != null) 'templateOf': templateOf?.toJson(),
      if (templateKey != null) 'templateKey': templateKey,
      'editorsCanShare': editorsCanShare,
      'nonEditorsCanExport': nonEditorsCanExport,
      'viewersSeeComments': viewersSeeComments,
    };
  }

  static DriveItemInclude include() {
    return DriveItemInclude._();
  }

  static DriveItemIncludeList includeList({
    _is.WhereExpressionBuilder<DriveItemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    DriveItemInclude? include,
  }) {
    return DriveItemIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DriveItemImpl extends DriveItem {
  _DriveItemImpl({
    int? id,
    _is.UuidValue? uuid,
    required _i26ubj99.DriveItemKind kind,
    required String name,
    required int ownerId,
    int? parentId,
    String? description,
    _is.UuidValue? contentRef,
    _is.UuidValue? thumbnailFileId,
    int? sizeBytes,
    required DateTime createdAt,
    required int createdById,
    required DateTime modifiedAt,
    int? modifiedById,
    DateTime? trashedAt,
    int? trashedById,
    _i4yf368z.TemplateCategory? templateOf,
    String? templateKey,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
    String? searchText,
  }) : super._(
         id: id,
         uuid: uuid,
         kind: kind,
         name: name,
         ownerId: ownerId,
         parentId: parentId,
         description: description,
         contentRef: contentRef,
         thumbnailFileId: thumbnailFileId,
         sizeBytes: sizeBytes,
         createdAt: createdAt,
         createdById: createdById,
         modifiedAt: modifiedAt,
         modifiedById: modifiedById,
         trashedAt: trashedAt,
         trashedById: trashedById,
         templateOf: templateOf,
         templateKey: templateKey,
         editorsCanShare: editorsCanShare,
         nonEditorsCanExport: nonEditorsCanExport,
         viewersSeeComments: viewersSeeComments,
         searchText: searchText,
       );

  /// Returns a shallow copy of this [DriveItem]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DriveItem copyWith({
    Object? id = _Undefined,
    _is.UuidValue? uuid,
    _i26ubj99.DriveItemKind? kind,
    String? name,
    int? ownerId,
    Object? parentId = _Undefined,
    Object? description = _Undefined,
    _is.UuidValue? contentRef = const _is.$UndefinedUuidValue(),
    _is.UuidValue? thumbnailFileId = const _is.$UndefinedUuidValue(),
    int? sizeBytes,
    DateTime? createdAt,
    int? createdById,
    DateTime? modifiedAt,
    Object? modifiedById = _Undefined,
    DateTime? trashedAt = const _is.$UndefinedDateTime(),
    Object? trashedById = _Undefined,
    Object? templateOf = _Undefined,
    Object? templateKey = _Undefined,
    bool? editorsCanShare,
    bool? nonEditorsCanExport,
    bool? viewersSeeComments,
    Object? searchText = _Undefined,
  }) {
    return DriveItem(
      id: id is int? ? id : this.id,
      uuid: uuid ?? this.uuid,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      parentId: parentId is int? ? parentId : this.parentId,
      description: description is String? ? description : this.description,
      contentRef: contentRef is _is.UndefinedSentinel
          ? this.contentRef
          : contentRef,
      thumbnailFileId: thumbnailFileId is _is.UndefinedSentinel
          ? this.thumbnailFileId
          : thumbnailFileId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      createdById: createdById ?? this.createdById,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      modifiedById: modifiedById is int? ? modifiedById : this.modifiedById,
      trashedAt: trashedAt is _is.UndefinedSentinel
          ? this.trashedAt
          : trashedAt,
      trashedById: trashedById is int? ? trashedById : this.trashedById,
      templateOf: templateOf is _i4yf368z.TemplateCategory?
          ? templateOf
          : this.templateOf,
      templateKey: templateKey is String? ? templateKey : this.templateKey,
      editorsCanShare: editorsCanShare ?? this.editorsCanShare,
      nonEditorsCanExport: nonEditorsCanExport ?? this.nonEditorsCanExport,
      viewersSeeComments: viewersSeeComments ?? this.viewersSeeComments,
      searchText: searchText is String? ? searchText : this.searchText,
    );
  }
}

class DriveItemUpdateTable extends _is.UpdateTable<DriveItemTable> {
  DriveItemUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> uuid(_is.UuidValue value) =>
      _is.ColumnValue(
        table.uuid,
        value,
      );

  _is.ColumnValue<_i26ubj99.DriveItemKind, _i26ubj99.DriveItemKind> kind(
    _i26ubj99.DriveItemKind value,
  ) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<String, String> name(String value) => _is.ColumnValue(
    table.name,
    value,
  );

  _is.ColumnValue<int, int> ownerId(int value) => _is.ColumnValue(
    table.ownerId,
    value,
  );

  _is.ColumnValue<int, int> parentId(int? value) => _is.ColumnValue(
    table.parentId,
    value,
  );

  _is.ColumnValue<String, String> description(String? value) => _is.ColumnValue(
    table.description,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> contentRef(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.contentRef,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> thumbnailFileId(
    _is.UuidValue? value,
  ) => _is.ColumnValue(
    table.thumbnailFileId,
    value,
  );

  _is.ColumnValue<int, int> sizeBytes(int value) => _is.ColumnValue(
    table.sizeBytes,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<int, int> createdById(int value) => _is.ColumnValue(
    table.createdById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> modifiedAt(DateTime value) =>
      _is.ColumnValue(
        table.modifiedAt,
        value,
      );

  _is.ColumnValue<int, int> modifiedById(int? value) => _is.ColumnValue(
    table.modifiedById,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> trashedAt(DateTime? value) =>
      _is.ColumnValue(
        table.trashedAt,
        value,
      );

  _is.ColumnValue<int, int> trashedById(int? value) => _is.ColumnValue(
    table.trashedById,
    value,
  );

  _is.ColumnValue<_i4yf368z.TemplateCategory, _i4yf368z.TemplateCategory>
  templateOf(_i4yf368z.TemplateCategory? value) => _is.ColumnValue(
    table.templateOf,
    value,
  );

  _is.ColumnValue<String, String> templateKey(String? value) => _is.ColumnValue(
    table.templateKey,
    value,
  );

  _is.ColumnValue<bool, bool> editorsCanShare(bool value) => _is.ColumnValue(
    table.editorsCanShare,
    value,
  );

  _is.ColumnValue<bool, bool> nonEditorsCanExport(bool value) =>
      _is.ColumnValue(
        table.nonEditorsCanExport,
        value,
      );

  _is.ColumnValue<bool, bool> viewersSeeComments(bool value) => _is.ColumnValue(
    table.viewersSeeComments,
    value,
  );

  _is.ColumnValue<String, String> searchText(String? value) => _is.ColumnValue(
    table.searchText,
    value,
  );
}

class DriveItemTable extends _is.Table<int?> {
  DriveItemTable({super.tableRelation}) : super(tableName: 'drive_item') {
    updateTable = DriveItemUpdateTable(this);
    uuid = _is.ColumnUuid(
      'uuid',
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
    ownerId = _is.ColumnInt(
      'ownerId',
      this,
    );
    parentId = _is.ColumnInt(
      'parentId',
      this,
    );
    description = _is.ColumnString(
      'description',
      this,
    );
    contentRef = _is.ColumnUuid(
      'contentRef',
      this,
    );
    thumbnailFileId = _is.ColumnUuid(
      'thumbnailFileId',
      this,
    );
    sizeBytes = _is.ColumnInt(
      'sizeBytes',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    createdById = _is.ColumnInt(
      'createdById',
      this,
    );
    modifiedAt = _is.ColumnDateTime(
      'modifiedAt',
      this,
    );
    modifiedById = _is.ColumnInt(
      'modifiedById',
      this,
    );
    trashedAt = _is.ColumnDateTime(
      'trashedAt',
      this,
    );
    trashedById = _is.ColumnInt(
      'trashedById',
      this,
    );
    templateOf = _is.ColumnEnum(
      'templateOf',
      this,
      _is.EnumSerialization.byName,
    );
    templateKey = _is.ColumnString(
      'templateKey',
      this,
    );
    editorsCanShare = _is.ColumnBool(
      'editorsCanShare',
      this,
      hasDefault: true,
    );
    nonEditorsCanExport = _is.ColumnBool(
      'nonEditorsCanExport',
      this,
      hasDefault: true,
    );
    viewersSeeComments = _is.ColumnBool(
      'viewersSeeComments',
      this,
      hasDefault: true,
    );
    searchText = _is.ColumnString(
      'searchText',
      this,
    );
  }

  late final DriveItemUpdateTable updateTable;

  /// Public id used in URLs: /d/<uuid>, /s/<uuid>.
  late final _is.ColumnUuid uuid;

  late final _is.ColumnEnum<_i26ubj99.DriveItemKind> kind;

  late final _is.ColumnString name;

  late final _is.ColumnInt ownerId;

  /// Null = the owner's root.
  late final _is.ColumnInt parentId;

  late final _is.ColumnString description;

  /// Documents: Document.uuid; spreadsheets: the sync space UUID (= Spreadsheet.id).
  late final _is.ColumnUuid contentRef;

  late final _is.ColumnUuid thumbnailFileId;

  late final _is.ColumnInt sizeBytes;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnInt createdById;

  /// Last content modification (any user).
  late final _is.ColumnDateTime modifiedAt;

  late final _is.ColumnInt modifiedById;

  late final _is.ColumnDateTime trashedAt;

  late final _is.ColumnInt trashedById;

  /// Non-null = this item is a template in the gallery.
  late final _is.ColumnEnum<_i4yf368z.TemplateCategory> templateOf;

  /// Built-in template key (gallery seeding), e.g. "write.meeting-notes".
  late final _is.ColumnString templateKey;

  late final _is.ColumnBool editorsCanShare;

  late final _is.ColumnBool nonEditorsCanExport;

  late final _is.ColumnBool viewersSeeComments;

  /// Extracted plain text for search (document text; sheet names + cells).
  late final _is.ColumnString searchText;

  @override
  List<_is.Column> get columns => [
    id,
    uuid,
    kind,
    name,
    ownerId,
    parentId,
    description,
    contentRef,
    thumbnailFileId,
    sizeBytes,
    createdAt,
    createdById,
    modifiedAt,
    modifiedById,
    trashedAt,
    trashedById,
    templateOf,
    templateKey,
    editorsCanShare,
    nonEditorsCanExport,
    viewersSeeComments,
    searchText,
  ];
}

class DriveItemInclude extends _is.IncludeObject {
  DriveItemInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DriveItem.t;
}

class DriveItemIncludeList extends _is.IncludeList {
  DriveItemIncludeList._({
    _is.WhereExpressionBuilder<DriveItemTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DriveItem.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DriveItem.t;
}

class DriveItemRepository {
  const DriveItemRepository._();

  /// Returns a list of [DriveItem]s matching the given query parameters.
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
  Future<List<DriveItem>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DriveItem>(
      where: where?.call(DriveItem.t),
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [DriveItem]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `DriveItem.t`.
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
  _ida.Stream<List<DriveItem>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<DriveItem>(
      where: where?.call(DriveItem.t),
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [DriveItem] matching the given query parameters.
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
  Future<DriveItem?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemTable>? where,
    int? offset,
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DriveItem>(
      where: where?.call(DriveItem.t),
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DriveItem] by its [id] or null if no such row exists.
  Future<DriveItem?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DriveItem>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DriveItem]s in the list and returns the inserted rows.
  ///
  /// The returned [DriveItem]s will have their `id` fields set.
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
  Future<List<DriveItem>> insert(
    _is.DatabaseSession session,
    List<DriveItem> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DriveItem>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DriveItem] and returns the inserted row.
  ///
  /// The returned [DriveItem] will have its `id` field set.
  Future<DriveItem> insertRow(
    _is.DatabaseSession session,
    DriveItem row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DriveItem>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DriveItem]s in the list and returns the resulting rows.
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
  /// The returned [DriveItem]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DriveItem>> upsert(
    _is.DatabaseSession session,
    List<DriveItem> rows, {
    required _is.ColumnSelections<DriveItemTable> conflictColumns,
    _is.ColumnSelections<DriveItemTable>? updateColumns,
    _is.WhereExpressionBuilder<DriveItemTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DriveItem>(
      rows,
      conflictColumns: conflictColumns(DriveItem.t),
      updateColumns: updateColumns?.call(DriveItem.t),
      updateWhere: updateWhere?.call(DriveItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DriveItem] and returns the resulting row.
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
  /// The returned [DriveItem] will have its `id` field set.
  Future<DriveItem?> upsertRow(
    _is.DatabaseSession session,
    DriveItem row, {
    required _is.ColumnSelections<DriveItemTable> conflictColumns,
    _is.ColumnSelections<DriveItemTable>? updateColumns,
    _is.WhereExpressionBuilder<DriveItemTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DriveItem>(
      row,
      conflictColumns: conflictColumns(DriveItem.t),
      updateColumns: updateColumns?.call(DriveItem.t),
      updateWhere: updateWhere?.call(DriveItem.t),
      transaction: transaction,
    );
  }

  /// Updates all [DriveItem]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DriveItem>> update(
    _is.DatabaseSession session,
    List<DriveItem> rows, {
    _is.ColumnSelections<DriveItemTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DriveItem>(
      rows,
      columns: columns?.call(DriveItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DriveItem]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DriveItem> updateRow(
    _is.DatabaseSession session,
    DriveItem row, {
    _is.ColumnSelections<DriveItemTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DriveItem>(
      row,
      columns: columns?.call(DriveItem.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DriveItem] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DriveItem?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DriveItemUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DriveItem>(
      id,
      columnValues: columnValues(DriveItem.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DriveItem]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DriveItem>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DriveItemUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<DriveItemTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DriveItem>(
      columnValues: columnValues(DriveItem.t.updateTable),
      where: where(DriveItem.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DriveItem]s in the list and returns the deleted rows.
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
  Future<List<DriveItem>> delete(
    _is.DatabaseSession session,
    List<DriveItem> rows, {
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DriveItem>(
      rows,
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DriveItem].
  Future<DriveItem> deleteRow(
    _is.DatabaseSession session,
    DriveItem row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DriveItem>(
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
  Future<List<DriveItem>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DriveItemTable> where,
    _is.OrderByBuilder<DriveItemTable>? orderBy,
    _is.OrderByListBuilder<DriveItemTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DriveItem>(
      where: where(DriveItem.t),
      orderBy: orderBy?.call(DriveItem.t),
      orderByList: orderByList?.call(DriveItem.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DriveItemTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DriveItem>(
      where: where?.call(DriveItem.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DriveItem] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DriveItemTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DriveItem>(
      where: where(DriveItem.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
