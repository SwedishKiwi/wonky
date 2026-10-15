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
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;

/// A presentation (Slides 02 §3.1). Its id is always the uuidSpaceId of the
/// space it lives in and the UUID of its drive item (one deck per space, P1).
abstract class Deck
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  Deck._({
    _iss.UuidValue? id,
    this.spaceId,
    required this.title,
    double? width,
    double? height,
    _i810rwvy.SlideSizePreset? sizePreset,
    this.themeId,
    _i810rwvy.DeckAppearance? appearance,
    this.language,
    bool? showSlideNumbers,
    bool? hideNumberOnTitle,
    int? firstSlideNumber,
    this.footerText,
    this.defaultsJson,
    this.guidesJson,
    this.presentJson,
    required this.createdBy,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       width = width ?? 1920.0,
       height = height ?? 1080.0,
       sizePreset = sizePreset ?? _i810rwvy.SlideSizePreset.widescreen16x9,
       appearance = appearance ?? _i810rwvy.DeckAppearance.light,
       showSlideNumbers = showSlideNumbers ?? false,
       hideNumberOnTitle = hideNumberOnTitle ?? true,
       firstSlideNumber = firstSlideNumber ?? 1,
       createdAt = createdAt ?? DateTime.now();

  factory Deck({
    _iss.UuidValue? id,
    int? spaceId,
    required String title,
    double? width,
    double? height,
    _i810rwvy.SlideSizePreset? sizePreset,
    _iss.UuidValue? themeId,
    _i810rwvy.DeckAppearance? appearance,
    String? language,
    bool? showSlideNumbers,
    bool? hideNumberOnTitle,
    int? firstSlideNumber,
    String? footerText,
    String? defaultsJson,
    String? guidesJson,
    String? presentJson,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) = _DeckImpl;

  factory Deck.fromJson(Map<String, dynamic> jsonSerialization) {
    return Deck(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      title: jsonSerialization['title'] as String,
      width: (jsonSerialization['width'] as num?)?.toDouble(),
      height: (jsonSerialization['height'] as num?)?.toDouble(),
      sizePreset: jsonSerialization['sizePreset'] == null
          ? null
          : _i810rwvy.SlideSizePreset.fromJson(
              (jsonSerialization['sizePreset'] as String),
            ),
      themeId: jsonSerialization['themeId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['themeId']),
      appearance: jsonSerialization['appearance'] == null
          ? null
          : _i810rwvy.DeckAppearance.fromJson(
              (jsonSerialization['appearance'] as String),
            ),
      language: jsonSerialization['language'] as String?,
      showSlideNumbers: jsonSerialization['showSlideNumbers'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(
              jsonSerialization['showSlideNumbers'],
            ),
      hideNumberOnTitle: jsonSerialization['hideNumberOnTitle'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(
              jsonSerialization['hideNumberOnTitle'],
            ),
      firstSlideNumber: jsonSerialization['firstSlideNumber'] as int?,
      footerText: jsonSerialization['footerText'] as String?,
      defaultsJson: jsonSerialization['defaultsJson'] as String?,
      guidesJson: jsonSerialization['guidesJson'] as String?,
      presentJson: jsonSerialization['presentJson'] as String?,
      createdBy: _iss.UuidValueJsonExtension.fromJson(
        jsonSerialization['createdBy'],
      ),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = DeckTable();

  static const db = DeckRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  /// Mirrored to DriveItem.name by the server (both ways).
  String title;

  /// Design size in slide units (su); 1920 x 1080 for 16:9 (02 §2.2).
  double width;

  double height;

  _i810rwvy.SlideSizePreset sizePreset;

  /// Default DeckTheme for new slides (same space; plain UUID, not an FK).
  /// Missing = the theme with the smallest id (02 §10).
  _iss.UuidValue? themeId;

  /// Which color scheme of the themes is used (05 §2.4).
  _i810rwvy.DeckAppearance appearance;

  /// BCP-47 for spelling / hyphenation; null = the user's locale.
  String? language;

  /// Master slide-number placeholders visible.
  bool showSlideNumbers;

  /// No number on slides whose layout key is `title`.
  bool hideNumberOnTitle;

  int firstSlideNumber;

  /// Master footer placeholders' text; null = hidden.
  String? footerText;

  /// {transition, build, codeFontSize, ...}; keys owned by 06/07 (A-06-7).
  String? defaultsJson;

  /// User guides [{"axis":"v"|"h","at":<su>}], whole-value LWW (03 A-03-1).
  String? guidesJson;

  /// Presenting options (10 A-10-1, schema 10 §3); null = defaults.
  String? presentJson;

  /// Auth user UUID of the creator.
  _iss.UuidValue createdBy;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [Deck]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  Deck copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    String? title,
    double? width,
    double? height,
    _i810rwvy.SlideSizePreset? sizePreset,
    _iss.UuidValue? themeId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.DeckAppearance? appearance,
    String? language,
    bool? showSlideNumbers,
    bool? hideNumberOnTitle,
    int? firstSlideNumber,
    String? footerText,
    String? defaultsJson,
    String? guidesJson,
    String? presentJson,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Deck',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'title': title,
      'width': width,
      'height': height,
      'sizePreset': sizePreset.toJson(),
      if (themeId != null) 'themeId': themeId?.toJson(),
      'appearance': appearance.toJson(),
      if (language != null) 'language': language,
      'showSlideNumbers': showSlideNumbers,
      'hideNumberOnTitle': hideNumberOnTitle,
      'firstSlideNumber': firstSlideNumber,
      if (footerText != null) 'footerText': footerText,
      if (defaultsJson != null) 'defaultsJson': defaultsJson,
      if (guidesJson != null) 'guidesJson': guidesJson,
      if (presentJson != null) 'presentJson': presentJson,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Deck',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      'title': title,
      'width': width,
      'height': height,
      'sizePreset': sizePreset.toJson(),
      if (themeId != null) 'themeId': themeId?.toJson(),
      'appearance': appearance.toJson(),
      if (language != null) 'language': language,
      'showSlideNumbers': showSlideNumbers,
      'hideNumberOnTitle': hideNumberOnTitle,
      'firstSlideNumber': firstSlideNumber,
      if (footerText != null) 'footerText': footerText,
      if (defaultsJson != null) 'defaultsJson': defaultsJson,
      if (guidesJson != null) 'guidesJson': guidesJson,
      if (presentJson != null) 'presentJson': presentJson,
      'createdBy': createdBy.toJson(),
      'createdAt': createdAt.toJson(),
    };
  }

  static DeckInclude include() {
    return DeckInclude._();
  }

  static DeckIncludeList includeList({
    _isd.WhereExpressionBuilder<DeckTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    DeckInclude? include,
  }) {
    return DeckIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DeckImpl extends Deck {
  _DeckImpl({
    _iss.UuidValue? id,
    int? spaceId,
    required String title,
    double? width,
    double? height,
    _i810rwvy.SlideSizePreset? sizePreset,
    _iss.UuidValue? themeId,
    _i810rwvy.DeckAppearance? appearance,
    String? language,
    bool? showSlideNumbers,
    bool? hideNumberOnTitle,
    int? firstSlideNumber,
    String? footerText,
    String? defaultsJson,
    String? guidesJson,
    String? presentJson,
    required _iss.UuidValue createdBy,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         title: title,
         width: width,
         height: height,
         sizePreset: sizePreset,
         themeId: themeId,
         appearance: appearance,
         language: language,
         showSlideNumbers: showSlideNumbers,
         hideNumberOnTitle: hideNumberOnTitle,
         firstSlideNumber: firstSlideNumber,
         footerText: footerText,
         defaultsJson: defaultsJson,
         guidesJson: guidesJson,
         presentJson: presentJson,
         createdBy: createdBy,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [Deck]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  Deck copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    String? title,
    double? width,
    double? height,
    _i810rwvy.SlideSizePreset? sizePreset,
    _iss.UuidValue? themeId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.DeckAppearance? appearance,
    Object? language = _Undefined,
    bool? showSlideNumbers,
    bool? hideNumberOnTitle,
    int? firstSlideNumber,
    Object? footerText = _Undefined,
    Object? defaultsJson = _Undefined,
    Object? guidesJson = _Undefined,
    Object? presentJson = _Undefined,
    _iss.UuidValue? createdBy,
    DateTime? createdAt,
  }) {
    return Deck(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      title: title ?? this.title,
      width: width ?? this.width,
      height: height ?? this.height,
      sizePreset: sizePreset ?? this.sizePreset,
      themeId: themeId is _iss.UndefinedSentinel ? this.themeId : themeId,
      appearance: appearance ?? this.appearance,
      language: language is String? ? language : this.language,
      showSlideNumbers: showSlideNumbers ?? this.showSlideNumbers,
      hideNumberOnTitle: hideNumberOnTitle ?? this.hideNumberOnTitle,
      firstSlideNumber: firstSlideNumber ?? this.firstSlideNumber,
      footerText: footerText is String? ? footerText : this.footerText,
      defaultsJson: defaultsJson is String? ? defaultsJson : this.defaultsJson,
      guidesJson: guidesJson is String? ? guidesJson : this.guidesJson,
      presentJson: presentJson is String? ? presentJson : this.presentJson,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DeckUpdateTable extends _isd.UpdateTable<DeckTable> {
  DeckUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<String, String> title(String value) =>
      _isd.ColumnValue(table.title, value);

  _isd.ColumnValue<double, double> width(double value) =>
      _isd.ColumnValue(table.width, value);

  _isd.ColumnValue<double, double> height(double value) =>
      _isd.ColumnValue(table.height, value);

  _isd.ColumnValue<_i810rwvy.SlideSizePreset, _i810rwvy.SlideSizePreset>
  sizePreset(_i810rwvy.SlideSizePreset value) =>
      _isd.ColumnValue(table.sizePreset, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> themeId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.themeId, value);

  _isd.ColumnValue<_i810rwvy.DeckAppearance, _i810rwvy.DeckAppearance>
  appearance(_i810rwvy.DeckAppearance value) =>
      _isd.ColumnValue(table.appearance, value);

  _isd.ColumnValue<String, String> language(String? value) =>
      _isd.ColumnValue(table.language, value);

  _isd.ColumnValue<bool, bool> showSlideNumbers(bool value) =>
      _isd.ColumnValue(table.showSlideNumbers, value);

  _isd.ColumnValue<bool, bool> hideNumberOnTitle(bool value) =>
      _isd.ColumnValue(table.hideNumberOnTitle, value);

  _isd.ColumnValue<int, int> firstSlideNumber(int value) =>
      _isd.ColumnValue(table.firstSlideNumber, value);

  _isd.ColumnValue<String, String> footerText(String? value) =>
      _isd.ColumnValue(table.footerText, value);

  _isd.ColumnValue<String, String> defaultsJson(String? value) =>
      _isd.ColumnValue(table.defaultsJson, value);

  _isd.ColumnValue<String, String> guidesJson(String? value) =>
      _isd.ColumnValue(table.guidesJson, value);

  _isd.ColumnValue<String, String> presentJson(String? value) =>
      _isd.ColumnValue(table.presentJson, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> createdBy(
    _iss.UuidValue value,
  ) => _isd.ColumnValue(table.createdBy, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class DeckTable extends _isd.Table<_iss.UuidValue> {
  DeckTable({super.tableRelation}) : super(tableName: 'deck') {
    updateTable = DeckUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    title = _isd.ColumnString('title', this);
    width = _isd.ColumnDouble('width', this, hasDefault: true);
    height = _isd.ColumnDouble('height', this, hasDefault: true);
    sizePreset = _isd.ColumnEnum(
      'sizePreset',
      this,
      _isd.EnumSerialization.byName,
      hasDefault: true,
    );
    themeId = _isd.ColumnUuid('themeId', this);
    appearance = _isd.ColumnEnum(
      'appearance',
      this,
      _isd.EnumSerialization.byName,
      hasDefault: true,
    );
    language = _isd.ColumnString('language', this);
    showSlideNumbers = _isd.ColumnBool(
      'showSlideNumbers',
      this,
      hasDefault: true,
    );
    hideNumberOnTitle = _isd.ColumnBool(
      'hideNumberOnTitle',
      this,
      hasDefault: true,
    );
    firstSlideNumber = _isd.ColumnInt(
      'firstSlideNumber',
      this,
      hasDefault: true,
    );
    footerText = _isd.ColumnString('footerText', this);
    defaultsJson = _isd.ColumnString('defaultsJson', this);
    guidesJson = _isd.ColumnString('guidesJson', this);
    presentJson = _isd.ColumnString('presentJson', this);
    createdBy = _isd.ColumnUuid('createdBy', this);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final DeckUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  /// Mirrored to DriveItem.name by the server (both ways).
  late final _isd.ColumnString title;

  /// Design size in slide units (su); 1920 x 1080 for 16:9 (02 §2.2).
  late final _isd.ColumnDouble width;

  late final _isd.ColumnDouble height;

  late final _isd.ColumnEnum<_i810rwvy.SlideSizePreset> sizePreset;

  /// Default DeckTheme for new slides (same space; plain UUID, not an FK).
  /// Missing = the theme with the smallest id (02 §10).
  late final _isd.ColumnUuid themeId;

  /// Which color scheme of the themes is used (05 §2.4).
  late final _isd.ColumnEnum<_i810rwvy.DeckAppearance> appearance;

  /// BCP-47 for spelling / hyphenation; null = the user's locale.
  late final _isd.ColumnString language;

  /// Master slide-number placeholders visible.
  late final _isd.ColumnBool showSlideNumbers;

  /// No number on slides whose layout key is `title`.
  late final _isd.ColumnBool hideNumberOnTitle;

  late final _isd.ColumnInt firstSlideNumber;

  /// Master footer placeholders' text; null = hidden.
  late final _isd.ColumnString footerText;

  /// {transition, build, codeFontSize, ...}; keys owned by 06/07 (A-06-7).
  late final _isd.ColumnString defaultsJson;

  /// User guides [{"axis":"v"|"h","at":<su>}], whole-value LWW (03 A-03-1).
  late final _isd.ColumnString guidesJson;

  /// Presenting options (10 A-10-1, schema 10 §3); null = defaults.
  late final _isd.ColumnString presentJson;

  /// Auth user UUID of the creator.
  late final _isd.ColumnUuid createdBy;

  late final _isd.ColumnDateTime createdAt;

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    title,
    width,
    height,
    sizePreset,
    themeId,
    appearance,
    language,
    showSlideNumbers,
    hideNumberOnTitle,
    firstSlideNumber,
    footerText,
    defaultsJson,
    guidesJson,
    presentJson,
    createdBy,
    createdAt,
  ];
}

class DeckInclude extends _isd.IncludeObject {
  DeckInclude._();

  @override
  Map<String, _isd.Include?> get includes => {};

  @override
  _isd.Table<_iss.UuidValue> get table => Deck.t;
}

class DeckIncludeList extends _isd.IncludeList {
  DeckIncludeList._({
    _isd.WhereExpressionBuilder<DeckTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Deck.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => Deck.t;
}

class DeckRepository {
  const DeckRepository._();

  /// Returns a list of [Deck]s matching the given query parameters.
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
  Future<List<Deck>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Deck>(
      where: where?.call(Deck.t),
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Deck]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `Deck.t`.
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
  _ida.Stream<List<Deck>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Deck>(
      where: where?.call(Deck.t),
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Deck] matching the given query parameters.
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
  Future<Deck?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckTable>? where,
    int? offset,
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Deck>(
      where: where?.call(Deck.t),
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Deck] by its [id] or null if no such row exists.
  Future<Deck?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Deck>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Deck]s in the list and returns the inserted rows.
  ///
  /// The returned [Deck]s will have their `id` fields set.
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
  Future<List<Deck>> insert(
    _isd.DatabaseSession session,
    List<Deck> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Deck>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Deck] and returns the inserted row.
  ///
  /// The returned [Deck] will have its `id` field set.
  Future<Deck> insertRow(
    _isd.DatabaseSession session,
    Deck row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<Deck>(row, transaction: transaction);
  }

  /// Upserts all [Deck]s in the list and returns the resulting rows.
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
  /// The returned [Deck]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Deck>> upsert(
    _isd.DatabaseSession session,
    List<Deck> rows, {
    required _isd.ColumnSelections<DeckTable> conflictColumns,
    _isd.ColumnSelections<DeckTable>? updateColumns,
    _isd.WhereExpressionBuilder<DeckTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Deck>(
      rows,
      conflictColumns: conflictColumns(Deck.t),
      updateColumns: updateColumns?.call(Deck.t),
      updateWhere: updateWhere?.call(Deck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Deck] and returns the resulting row.
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
  /// The returned [Deck] will have its `id` field set.
  Future<Deck?> upsertRow(
    _isd.DatabaseSession session,
    Deck row, {
    required _isd.ColumnSelections<DeckTable> conflictColumns,
    _isd.ColumnSelections<DeckTable>? updateColumns,
    _isd.WhereExpressionBuilder<DeckTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Deck>(
      row,
      conflictColumns: conflictColumns(Deck.t),
      updateColumns: updateColumns?.call(Deck.t),
      updateWhere: updateWhere?.call(Deck.t),
      transaction: transaction,
    );
  }

  /// Updates all [Deck]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Deck>> update(
    _isd.DatabaseSession session,
    List<Deck> rows, {
    _isd.ColumnSelections<DeckTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Deck>(
      rows,
      columns: columns?.call(Deck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Deck]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Deck> updateRow(
    _isd.DatabaseSession session,
    Deck row, {
    _isd.ColumnSelections<DeckTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<Deck>(
      row,
      columns: columns?.call(Deck.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Deck] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Deck?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<DeckUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<Deck>(
      id,
      columnValues: columnValues(Deck.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Deck]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Deck>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<DeckUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<DeckTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Deck>(
      columnValues: columnValues(Deck.t.updateTable),
      where: where(Deck.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Deck]s in the list and returns the deleted rows.
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
  Future<List<Deck>> delete(
    _isd.DatabaseSession session,
    List<Deck> rows, {
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Deck>(
      rows,
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Deck].
  Future<Deck> deleteRow(
    _isd.DatabaseSession session,
    Deck row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Deck>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Deck>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DeckTable> where,
    _isd.OrderByBuilder<DeckTable>? orderBy,
    _isd.OrderByListBuilder<DeckTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Deck>(
      where: where(Deck.t),
      orderBy: orderBy?.call(Deck.t),
      orderByList: orderByList?.call(Deck.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<DeckTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<Deck>(
      where: where?.call(Deck.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Deck] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<DeckTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Deck>(
      where: where(Deck.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
