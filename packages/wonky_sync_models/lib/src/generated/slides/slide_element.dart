/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_null_comparison

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _ida;
import 'package:serverpod_database/serverpod_database.dart' as _isd;
import 'package:serverpod_serialization/serverpod_serialization.dart' as _iss;
import 'package:wonky_sync_models/wonky_sync_models.dart' as _i810rwvy;

/// Any object on a slide, layout or master (Slides 02 §3.5). Exactly one
/// owner FK (slide, layout, master: optional relations) is set; a child of
/// an element group has the owner of its group.
abstract class SlideElement
    implements _isd.TableRow<_iss.UuidValue>, _iss.ProtocolSerialization {
  SlideElement._({
    _iss.UuidValue? id,
    this.spaceId,
    this.slideId,
    this.slide,
    this.layoutId,
    this.layout,
    this.masterId,
    this.master,
    this.parentId,
    this.parent,
    required this.kind,
    this.name,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation,
    bool? flipH,
    bool? flipV,
    required this.zKey,
    this.readingKey,
    bool? locked,
    bool? hidden,
    this.placeholderType,
    this.placeholderOf,
    required this.matchKey,
    this.text,
    this.textStyleJson,
    this.fillJson,
    this.strokeJson,
    this.effectsJson,
    this.opacity,
    this.dataJson,
    this.linkJson,
    this.altText,
    bool? decorative,
    DateTime? createdAt,
  }) : id = id ?? const _iss.Uuid().v7obj(),
       flipH = flipH ?? false,
       flipV = flipV ?? false,
       locked = locked ?? false,
       hidden = hidden ?? false,
       decorative = decorative ?? false,
       createdAt = createdAt ?? DateTime.now();

  factory SlideElement({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? slideId,
    _i810rwvy.Slide? slide,
    _iss.UuidValue? layoutId,
    _i810rwvy.SlideLayout? layout,
    _iss.UuidValue? masterId,
    _i810rwvy.SlideMaster? master,
    _iss.UuidValue? parentId,
    _i810rwvy.SlideElement? parent,
    required _i810rwvy.SlideElementKind kind,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? flipH,
    bool? flipV,
    required String zKey,
    String? readingKey,
    bool? locked,
    bool? hidden,
    _i810rwvy.PlaceholderType? placeholderType,
    _iss.UuidValue? placeholderOf,
    required String matchKey,
    String? text,
    String? textStyleJson,
    String? fillJson,
    String? strokeJson,
    String? effectsJson,
    double? opacity,
    String? dataJson,
    String? linkJson,
    String? altText,
    bool? decorative,
    DateTime? createdAt,
  }) = _SlideElementImpl;

  factory SlideElement.fromJson(Map<String, dynamic> jsonSerialization) {
    return SlideElement(
      id: jsonSerialization['id'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      spaceId: jsonSerialization['spaceId'] as int?,
      slideId: jsonSerialization['slideId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['slideId']),
      slide: jsonSerialization['slide'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.Slide>(
              jsonSerialization['slide'],
            ),
      layoutId: jsonSerialization['layoutId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['layoutId']),
      layout: jsonSerialization['layout'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideLayout>(
              jsonSerialization['layout'],
            ),
      masterId: jsonSerialization['masterId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['masterId']),
      master: jsonSerialization['master'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideMaster>(
              jsonSerialization['master'],
            ),
      parentId: jsonSerialization['parentId'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(jsonSerialization['parentId']),
      parent: jsonSerialization['parent'] == null
          ? null
          : _i810rwvy.Protocol().deserialize<_i810rwvy.SlideElement>(
              jsonSerialization['parent'],
            ),
      kind: _i810rwvy.SlideElementKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      name: jsonSerialization['name'] as String?,
      x: (jsonSerialization['x'] as num?)?.toDouble(),
      y: (jsonSerialization['y'] as num?)?.toDouble(),
      width: (jsonSerialization['width'] as num?)?.toDouble(),
      height: (jsonSerialization['height'] as num?)?.toDouble(),
      rotation: (jsonSerialization['rotation'] as num?)?.toDouble(),
      flipH: jsonSerialization['flipH'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['flipH']),
      flipV: jsonSerialization['flipV'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['flipV']),
      zKey: jsonSerialization['zKey'] as String,
      readingKey: jsonSerialization['readingKey'] as String?,
      locked: jsonSerialization['locked'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['locked']),
      hidden: jsonSerialization['hidden'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['hidden']),
      placeholderType: jsonSerialization['placeholderType'] == null
          ? null
          : _i810rwvy.PlaceholderType.fromJson(
              (jsonSerialization['placeholderType'] as String),
            ),
      placeholderOf: jsonSerialization['placeholderOf'] == null
          ? null
          : _iss.UuidValueJsonExtension.fromJson(
              jsonSerialization['placeholderOf'],
            ),
      matchKey: jsonSerialization['matchKey'] as String,
      text: jsonSerialization['text'] as String?,
      textStyleJson: jsonSerialization['textStyleJson'] as String?,
      fillJson: jsonSerialization['fillJson'] as String?,
      strokeJson: jsonSerialization['strokeJson'] as String?,
      effectsJson: jsonSerialization['effectsJson'] as String?,
      opacity: (jsonSerialization['opacity'] as num?)?.toDouble(),
      dataJson: jsonSerialization['dataJson'] as String?,
      linkJson: jsonSerialization['linkJson'] as String?,
      altText: jsonSerialization['altText'] as String?,
      decorative: jsonSerialization['decorative'] == null
          ? null
          : _iss.BoolJsonExtension.fromJson(jsonSerialization['decorative']),
      createdAt: jsonSerialization['createdAt'] == null
          ? null
          : _iss.DateTimeJsonExtension.fromJson(jsonSerialization['createdAt']),
    );
  }

  static final t = SlideElementTable();

  static const db = SlideElementRepository._();

  @override
  _iss.UuidValue id;

  /// The space owning this row. Maintained by the sync engine.
  int? spaceId;

  _iss.UuidValue? slideId;

  _i810rwvy.Slide? slide;

  _iss.UuidValue? layoutId;

  _i810rwvy.SlideLayout? layout;

  _iss.UuidValue? masterId;

  _i810rwvy.SlideMaster? master;

  _iss.UuidValue? parentId;

  /// Element group (kind group) this element belongs to. Deleting a group
  /// deletes its children.
  _i810rwvy.SlideElement? parent;

  _i810rwvy.SlideElementKind kind;

  /// Layers panel / animation pane label; null = generated ("Shape 3").
  String? name;

  /// Frame (02 §2.2) in su; x/y top-left of the unrotated box. Nullable only
  /// on placeholder instances (null = inherit). Coupled columns (P4).
  double? x;

  double? y;

  double? width;

  double? height;

  /// Degrees clockwise about the center; null = 0 (placeholders: inherit).
  double? rotation;

  bool flipH;

  bool flipV;

  /// Stacking order among siblings (same owner and parent).
  String zKey;

  /// Reading order override (03 §17); null = automatic.
  String? readingKey;

  /// Not selectable by click/marquee, can't move (03 §8.2).
  bool locked;

  /// Not drawn (still in the Layers panel); hidden in present/PDF.
  bool hidden;

  /// On layouts/masters: defines a placeholder; on slides: an instance.
  _i810rwvy.PlaceholderType? placeholderType;

  /// Instance -> the layout (or master) placeholder it inherits from (plain UUID).
  _iss.UuidValue? placeholderOf;

  /// Magic Move key (06 §8.2): 22-character key generated on create.
  String matchKey;

  /// Rich text Delta (02 §4) of text/shape/placeholder; null for code.
  String? text;

  /// Box-level text properties (02 §5.1).
  String? textStyleJson;

  /// Fill (02 §5.2); null = inherit/none per kind.
  String? fillJson;

  /// Stroke (02 §5.3).
  String? strokeJson;

  /// Shadow, glow, blur, reflection (02 §5.4).
  String? effectsJson;

  /// 0..1; null = 1.
  double? opacity;

  /// Kind-specific payload (02 §6), always with "v".
  String? dataJson;

  /// Click action when presenting: {url} | {slideId} | {action} (03 §6.9).
  String? linkJson;

  String? altText;

  /// Excluded from alt-text checks and screen readers.
  bool decorative;

  DateTime createdAt;

  @override
  _isd.Table<_iss.UuidValue> get table => t;

  /// Returns a shallow copy of this [SlideElement]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  SlideElement copyWith({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? slideId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.Slide? slide = const _UndefinedSlideElement$slide(),
    _iss.UuidValue? layoutId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.SlideLayout? layout = const _UndefinedSlideElement$layout(),
    _iss.UuidValue? masterId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.SlideMaster? master = const _UndefinedSlideElement$master(),
    _iss.UuidValue? parentId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.SlideElement? parent = const _UndefinedSlideElement$parent(),
    _i810rwvy.SlideElementKind? kind,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? flipH,
    bool? flipV,
    String? zKey,
    String? readingKey,
    bool? locked,
    bool? hidden,
    _i810rwvy.PlaceholderType? placeholderType,
    _iss.UuidValue? placeholderOf = const _iss.$UndefinedUuidValue(),
    String? matchKey,
    String? text,
    String? textStyleJson,
    String? fillJson,
    String? strokeJson,
    String? effectsJson,
    double? opacity,
    String? dataJson,
    String? linkJson,
    String? altText,
    bool? decorative,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SlideElement',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      if (slideId != null) 'slideId': slideId?.toJson(),
      if (slide != null) 'slide': slide?.toJson(),
      if (layoutId != null) 'layoutId': layoutId?.toJson(),
      if (layout != null) 'layout': layout?.toJson(),
      if (masterId != null) 'masterId': masterId?.toJson(),
      if (master != null) 'master': master?.toJson(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJson(),
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (rotation != null) 'rotation': rotation,
      'flipH': flipH,
      'flipV': flipV,
      'zKey': zKey,
      if (readingKey != null) 'readingKey': readingKey,
      'locked': locked,
      'hidden': hidden,
      if (placeholderType != null) 'placeholderType': placeholderType?.toJson(),
      if (placeholderOf != null) 'placeholderOf': placeholderOf?.toJson(),
      'matchKey': matchKey,
      if (text != null) 'text': text,
      if (textStyleJson != null) 'textStyleJson': textStyleJson,
      if (fillJson != null) 'fillJson': fillJson,
      if (strokeJson != null) 'strokeJson': strokeJson,
      if (effectsJson != null) 'effectsJson': effectsJson,
      if (opacity != null) 'opacity': opacity,
      if (dataJson != null) 'dataJson': dataJson,
      if (linkJson != null) 'linkJson': linkJson,
      if (altText != null) 'altText': altText,
      'decorative': decorative,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SlideElement',
      'id': id.toJson(),
      if (spaceId != null) 'spaceId': spaceId,
      if (slideId != null) 'slideId': slideId?.toJson(),
      if (slide != null) 'slide': slide?.toJsonForProtocol(),
      if (layoutId != null) 'layoutId': layoutId?.toJson(),
      if (layout != null) 'layout': layout?.toJsonForProtocol(),
      if (masterId != null) 'masterId': masterId?.toJson(),
      if (master != null) 'master': master?.toJsonForProtocol(),
      if (parentId != null) 'parentId': parentId?.toJson(),
      if (parent != null) 'parent': parent?.toJsonForProtocol(),
      'kind': kind.toJson(),
      if (name != null) 'name': name,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (rotation != null) 'rotation': rotation,
      'flipH': flipH,
      'flipV': flipV,
      'zKey': zKey,
      if (readingKey != null) 'readingKey': readingKey,
      'locked': locked,
      'hidden': hidden,
      if (placeholderType != null) 'placeholderType': placeholderType?.toJson(),
      if (placeholderOf != null) 'placeholderOf': placeholderOf?.toJson(),
      'matchKey': matchKey,
      if (text != null) 'text': text,
      if (textStyleJson != null) 'textStyleJson': textStyleJson,
      if (fillJson != null) 'fillJson': fillJson,
      if (strokeJson != null) 'strokeJson': strokeJson,
      if (effectsJson != null) 'effectsJson': effectsJson,
      if (opacity != null) 'opacity': opacity,
      if (dataJson != null) 'dataJson': dataJson,
      if (linkJson != null) 'linkJson': linkJson,
      if (altText != null) 'altText': altText,
      'decorative': decorative,
      'createdAt': createdAt.toJson(),
    };
  }

  static SlideElementInclude include({
    _i810rwvy.SlideInclude? slide,
    _i810rwvy.SlideLayoutInclude? layout,
    _i810rwvy.SlideMasterInclude? master,
    _i810rwvy.SlideElementInclude? parent,
  }) {
    return SlideElementInclude._(
      slide: slide,
      layout: layout,
      master: master,
      parent: parent,
    );
  }

  static SlideElementIncludeList includeList({
    _isd.WhereExpressionBuilder<SlideElementTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    SlideElementInclude? include,
  }) {
    return SlideElementIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _iss.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UndefinedSlideElement$slide extends _iss.UndefinedSentinel
    implements _i810rwvy.Slide {
  const _UndefinedSlideElement$slide();
}

class _UndefinedSlideElement$layout extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideLayout {
  const _UndefinedSlideElement$layout();
}

class _UndefinedSlideElement$master extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideMaster {
  const _UndefinedSlideElement$master();
}

class _UndefinedSlideElement$parent extends _iss.UndefinedSentinel
    implements _i810rwvy.SlideElement {
  const _UndefinedSlideElement$parent();
}

class _SlideElementImpl extends SlideElement {
  _SlideElementImpl({
    _iss.UuidValue? id,
    int? spaceId,
    _iss.UuidValue? slideId,
    _i810rwvy.Slide? slide,
    _iss.UuidValue? layoutId,
    _i810rwvy.SlideLayout? layout,
    _iss.UuidValue? masterId,
    _i810rwvy.SlideMaster? master,
    _iss.UuidValue? parentId,
    _i810rwvy.SlideElement? parent,
    required _i810rwvy.SlideElementKind kind,
    String? name,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    bool? flipH,
    bool? flipV,
    required String zKey,
    String? readingKey,
    bool? locked,
    bool? hidden,
    _i810rwvy.PlaceholderType? placeholderType,
    _iss.UuidValue? placeholderOf,
    required String matchKey,
    String? text,
    String? textStyleJson,
    String? fillJson,
    String? strokeJson,
    String? effectsJson,
    double? opacity,
    String? dataJson,
    String? linkJson,
    String? altText,
    bool? decorative,
    DateTime? createdAt,
  }) : super._(
         id: id,
         spaceId: spaceId,
         slideId: slideId,
         slide: slide,
         layoutId: layoutId,
         layout: layout,
         masterId: masterId,
         master: master,
         parentId: parentId,
         parent: parent,
         kind: kind,
         name: name,
         x: x,
         y: y,
         width: width,
         height: height,
         rotation: rotation,
         flipH: flipH,
         flipV: flipV,
         zKey: zKey,
         readingKey: readingKey,
         locked: locked,
         hidden: hidden,
         placeholderType: placeholderType,
         placeholderOf: placeholderOf,
         matchKey: matchKey,
         text: text,
         textStyleJson: textStyleJson,
         fillJson: fillJson,
         strokeJson: strokeJson,
         effectsJson: effectsJson,
         opacity: opacity,
         dataJson: dataJson,
         linkJson: linkJson,
         altText: altText,
         decorative: decorative,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [SlideElement]
  /// with some or all fields replaced by the given arguments.
  @_iss.useResult
  @override
  SlideElement copyWith({
    _iss.UuidValue? id,
    Object? spaceId = _Undefined,
    _iss.UuidValue? slideId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.Slide? slide = const _UndefinedSlideElement$slide(),
    _iss.UuidValue? layoutId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.SlideLayout? layout = const _UndefinedSlideElement$layout(),
    _iss.UuidValue? masterId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.SlideMaster? master = const _UndefinedSlideElement$master(),
    _iss.UuidValue? parentId = const _iss.$UndefinedUuidValue(),
    _i810rwvy.SlideElement? parent = const _UndefinedSlideElement$parent(),
    _i810rwvy.SlideElementKind? kind,
    Object? name = _Undefined,
    Object? x = _Undefined,
    Object? y = _Undefined,
    Object? width = _Undefined,
    Object? height = _Undefined,
    Object? rotation = _Undefined,
    bool? flipH,
    bool? flipV,
    String? zKey,
    Object? readingKey = _Undefined,
    bool? locked,
    bool? hidden,
    Object? placeholderType = _Undefined,
    _iss.UuidValue? placeholderOf = const _iss.$UndefinedUuidValue(),
    String? matchKey,
    Object? text = _Undefined,
    Object? textStyleJson = _Undefined,
    Object? fillJson = _Undefined,
    Object? strokeJson = _Undefined,
    Object? effectsJson = _Undefined,
    Object? opacity = _Undefined,
    Object? dataJson = _Undefined,
    Object? linkJson = _Undefined,
    Object? altText = _Undefined,
    bool? decorative,
    DateTime? createdAt,
  }) {
    return SlideElement(
      id: id ?? this.id,
      spaceId: spaceId is int? ? spaceId : this.spaceId,
      slideId: slideId is _iss.UndefinedSentinel ? this.slideId : slideId,
      slide: slide is _iss.UndefinedSentinel ? this.slide?.copyWith() : slide,
      layoutId: layoutId is _iss.UndefinedSentinel ? this.layoutId : layoutId,
      layout: layout is _iss.UndefinedSentinel
          ? this.layout?.copyWith()
          : layout,
      masterId: masterId is _iss.UndefinedSentinel ? this.masterId : masterId,
      master: master is _iss.UndefinedSentinel
          ? this.master?.copyWith()
          : master,
      parentId: parentId is _iss.UndefinedSentinel ? this.parentId : parentId,
      parent: parent is _iss.UndefinedSentinel
          ? this.parent?.copyWith()
          : parent,
      kind: kind ?? this.kind,
      name: name is String? ? name : this.name,
      x: x is double? ? x : this.x,
      y: y is double? ? y : this.y,
      width: width is double? ? width : this.width,
      height: height is double? ? height : this.height,
      rotation: rotation is double? ? rotation : this.rotation,
      flipH: flipH ?? this.flipH,
      flipV: flipV ?? this.flipV,
      zKey: zKey ?? this.zKey,
      readingKey: readingKey is String? ? readingKey : this.readingKey,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      placeholderType: placeholderType is _i810rwvy.PlaceholderType?
          ? placeholderType
          : this.placeholderType,
      placeholderOf: placeholderOf is _iss.UndefinedSentinel
          ? this.placeholderOf
          : placeholderOf,
      matchKey: matchKey ?? this.matchKey,
      text: text is String? ? text : this.text,
      textStyleJson: textStyleJson is String?
          ? textStyleJson
          : this.textStyleJson,
      fillJson: fillJson is String? ? fillJson : this.fillJson,
      strokeJson: strokeJson is String? ? strokeJson : this.strokeJson,
      effectsJson: effectsJson is String? ? effectsJson : this.effectsJson,
      opacity: opacity is double? ? opacity : this.opacity,
      dataJson: dataJson is String? ? dataJson : this.dataJson,
      linkJson: linkJson is String? ? linkJson : this.linkJson,
      altText: altText is String? ? altText : this.altText,
      decorative: decorative ?? this.decorative,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SlideElementUpdateTable extends _isd.UpdateTable<SlideElementTable> {
  SlideElementUpdateTable(super.table);

  _isd.ColumnValue<int, int> spaceId(int? value) =>
      _isd.ColumnValue(table.spaceId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> slideId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.slideId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> layoutId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.layoutId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> masterId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.masterId, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> parentId(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.parentId, value);

  _isd.ColumnValue<_i810rwvy.SlideElementKind, _i810rwvy.SlideElementKind> kind(
    _i810rwvy.SlideElementKind value,
  ) => _isd.ColumnValue(table.kind, value);

  _isd.ColumnValue<String, String> name(String? value) =>
      _isd.ColumnValue(table.name, value);

  _isd.ColumnValue<double, double> x(double? value) =>
      _isd.ColumnValue(table.x, value);

  _isd.ColumnValue<double, double> y(double? value) =>
      _isd.ColumnValue(table.y, value);

  _isd.ColumnValue<double, double> width(double? value) =>
      _isd.ColumnValue(table.width, value);

  _isd.ColumnValue<double, double> height(double? value) =>
      _isd.ColumnValue(table.height, value);

  _isd.ColumnValue<double, double> rotation(double? value) =>
      _isd.ColumnValue(table.rotation, value);

  _isd.ColumnValue<bool, bool> flipH(bool value) =>
      _isd.ColumnValue(table.flipH, value);

  _isd.ColumnValue<bool, bool> flipV(bool value) =>
      _isd.ColumnValue(table.flipV, value);

  _isd.ColumnValue<String, String> zKey(String value) =>
      _isd.ColumnValue(table.zKey, value);

  _isd.ColumnValue<String, String> readingKey(String? value) =>
      _isd.ColumnValue(table.readingKey, value);

  _isd.ColumnValue<bool, bool> locked(bool value) =>
      _isd.ColumnValue(table.locked, value);

  _isd.ColumnValue<bool, bool> hidden(bool value) =>
      _isd.ColumnValue(table.hidden, value);

  _isd.ColumnValue<_i810rwvy.PlaceholderType, _i810rwvy.PlaceholderType>
  placeholderType(_i810rwvy.PlaceholderType? value) =>
      _isd.ColumnValue(table.placeholderType, value);

  _isd.ColumnValue<_iss.UuidValue, _iss.UuidValue> placeholderOf(
    _iss.UuidValue? value,
  ) => _isd.ColumnValue(table.placeholderOf, value);

  _isd.ColumnValue<String, String> matchKey(String value) =>
      _isd.ColumnValue(table.matchKey, value);

  _isd.ColumnValue<String, String> text(String? value) =>
      _isd.ColumnValue(table.text, value);

  _isd.ColumnValue<String, String> textStyleJson(String? value) =>
      _isd.ColumnValue(table.textStyleJson, value);

  _isd.ColumnValue<String, String> fillJson(String? value) =>
      _isd.ColumnValue(table.fillJson, value);

  _isd.ColumnValue<String, String> strokeJson(String? value) =>
      _isd.ColumnValue(table.strokeJson, value);

  _isd.ColumnValue<String, String> effectsJson(String? value) =>
      _isd.ColumnValue(table.effectsJson, value);

  _isd.ColumnValue<double, double> opacity(double? value) =>
      _isd.ColumnValue(table.opacity, value);

  _isd.ColumnValue<String, String> dataJson(String? value) =>
      _isd.ColumnValue(table.dataJson, value);

  _isd.ColumnValue<String, String> linkJson(String? value) =>
      _isd.ColumnValue(table.linkJson, value);

  _isd.ColumnValue<String, String> altText(String? value) =>
      _isd.ColumnValue(table.altText, value);

  _isd.ColumnValue<bool, bool> decorative(bool value) =>
      _isd.ColumnValue(table.decorative, value);

  _isd.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _isd.ColumnValue(table.createdAt, value);
}

class SlideElementTable extends _isd.Table<_iss.UuidValue> {
  SlideElementTable({super.tableRelation}) : super(tableName: 'slide_element') {
    updateTable = SlideElementUpdateTable(this);
    spaceId = _isd.ColumnInt('spaceId', this);
    slideId = _isd.ColumnUuid('slideId', this);
    layoutId = _isd.ColumnUuid('layoutId', this);
    masterId = _isd.ColumnUuid('masterId', this);
    parentId = _isd.ColumnUuid('parentId', this);
    kind = _isd.ColumnEnum('kind', this, _isd.EnumSerialization.byName);
    name = _isd.ColumnString('name', this);
    x = _isd.ColumnDouble('x', this);
    y = _isd.ColumnDouble('y', this);
    width = _isd.ColumnDouble('width', this);
    height = _isd.ColumnDouble('height', this);
    rotation = _isd.ColumnDouble('rotation', this);
    flipH = _isd.ColumnBool('flipH', this, hasDefault: true);
    flipV = _isd.ColumnBool('flipV', this, hasDefault: true);
    zKey = _isd.ColumnString('zKey', this);
    readingKey = _isd.ColumnString('readingKey', this);
    locked = _isd.ColumnBool('locked', this, hasDefault: true);
    hidden = _isd.ColumnBool('hidden', this, hasDefault: true);
    placeholderType = _isd.ColumnEnum(
      'placeholderType',
      this,
      _isd.EnumSerialization.byName,
    );
    placeholderOf = _isd.ColumnUuid('placeholderOf', this);
    matchKey = _isd.ColumnString('matchKey', this);
    text = _isd.ColumnString('text', this);
    textStyleJson = _isd.ColumnString('textStyleJson', this);
    fillJson = _isd.ColumnString('fillJson', this);
    strokeJson = _isd.ColumnString('strokeJson', this);
    effectsJson = _isd.ColumnString('effectsJson', this);
    opacity = _isd.ColumnDouble('opacity', this);
    dataJson = _isd.ColumnString('dataJson', this);
    linkJson = _isd.ColumnString('linkJson', this);
    altText = _isd.ColumnString('altText', this);
    decorative = _isd.ColumnBool('decorative', this, hasDefault: true);
    createdAt = _isd.ColumnDateTime('createdAt', this);
  }

  late final SlideElementUpdateTable updateTable;

  /// The space owning this row. Maintained by the sync engine.
  late final _isd.ColumnInt spaceId;

  late final _isd.ColumnUuid slideId;

  _i810rwvy.SlideTable? _slide;

  late final _isd.ColumnUuid layoutId;

  _i810rwvy.SlideLayoutTable? _layout;

  late final _isd.ColumnUuid masterId;

  _i810rwvy.SlideMasterTable? _master;

  late final _isd.ColumnUuid parentId;

  /// Element group (kind group) this element belongs to. Deleting a group
  /// deletes its children.
  _i810rwvy.SlideElementTable? _parent;

  late final _isd.ColumnEnum<_i810rwvy.SlideElementKind> kind;

  /// Layers panel / animation pane label; null = generated ("Shape 3").
  late final _isd.ColumnString name;

  /// Frame (02 §2.2) in su; x/y top-left of the unrotated box. Nullable only
  /// on placeholder instances (null = inherit). Coupled columns (P4).
  late final _isd.ColumnDouble x;

  late final _isd.ColumnDouble y;

  late final _isd.ColumnDouble width;

  late final _isd.ColumnDouble height;

  /// Degrees clockwise about the center; null = 0 (placeholders: inherit).
  late final _isd.ColumnDouble rotation;

  late final _isd.ColumnBool flipH;

  late final _isd.ColumnBool flipV;

  /// Stacking order among siblings (same owner and parent).
  late final _isd.ColumnString zKey;

  /// Reading order override (03 §17); null = automatic.
  late final _isd.ColumnString readingKey;

  /// Not selectable by click/marquee, can't move (03 §8.2).
  late final _isd.ColumnBool locked;

  /// Not drawn (still in the Layers panel); hidden in present/PDF.
  late final _isd.ColumnBool hidden;

  /// On layouts/masters: defines a placeholder; on slides: an instance.
  late final _isd.ColumnEnum<_i810rwvy.PlaceholderType> placeholderType;

  /// Instance -> the layout (or master) placeholder it inherits from (plain UUID).
  late final _isd.ColumnUuid placeholderOf;

  /// Magic Move key (06 §8.2): 22-character key generated on create.
  late final _isd.ColumnString matchKey;

  /// Rich text Delta (02 §4) of text/shape/placeholder; null for code.
  late final _isd.ColumnString text;

  /// Box-level text properties (02 §5.1).
  late final _isd.ColumnString textStyleJson;

  /// Fill (02 §5.2); null = inherit/none per kind.
  late final _isd.ColumnString fillJson;

  /// Stroke (02 §5.3).
  late final _isd.ColumnString strokeJson;

  /// Shadow, glow, blur, reflection (02 §5.4).
  late final _isd.ColumnString effectsJson;

  /// 0..1; null = 1.
  late final _isd.ColumnDouble opacity;

  /// Kind-specific payload (02 §6), always with "v".
  late final _isd.ColumnString dataJson;

  /// Click action when presenting: {url} | {slideId} | {action} (03 §6.9).
  late final _isd.ColumnString linkJson;

  late final _isd.ColumnString altText;

  /// Excluded from alt-text checks and screen readers.
  late final _isd.ColumnBool decorative;

  late final _isd.ColumnDateTime createdAt;

  _i810rwvy.SlideTable get slide {
    if (_slide != null) return _slide!;
    _slide = _isd.createRelationTable(
      relationFieldName: 'slide',
      field: SlideElement.t.slideId,
      foreignField: _i810rwvy.Slide.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideTable(tableRelation: foreignTableRelation),
    );
    return _slide!;
  }

  _i810rwvy.SlideLayoutTable get layout {
    if (_layout != null) return _layout!;
    _layout = _isd.createRelationTable(
      relationFieldName: 'layout',
      field: SlideElement.t.layoutId,
      foreignField: _i810rwvy.SlideLayout.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideLayoutTable(tableRelation: foreignTableRelation),
    );
    return _layout!;
  }

  _i810rwvy.SlideMasterTable get master {
    if (_master != null) return _master!;
    _master = _isd.createRelationTable(
      relationFieldName: 'master',
      field: SlideElement.t.masterId,
      foreignField: _i810rwvy.SlideMaster.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideMasterTable(tableRelation: foreignTableRelation),
    );
    return _master!;
  }

  _i810rwvy.SlideElementTable get parent {
    if (_parent != null) return _parent!;
    _parent = _isd.createRelationTable(
      relationFieldName: 'parent',
      field: SlideElement.t.parentId,
      foreignField: _i810rwvy.SlideElement.t.id,
      tableRelation: tableRelation,
      createTable: (foreignTableRelation) =>
          _i810rwvy.SlideElementTable(tableRelation: foreignTableRelation),
    );
    return _parent!;
  }

  @override
  List<_isd.Column> get columns => [
    id,
    spaceId,
    slideId,
    layoutId,
    masterId,
    parentId,
    kind,
    name,
    x,
    y,
    width,
    height,
    rotation,
    flipH,
    flipV,
    zKey,
    readingKey,
    locked,
    hidden,
    placeholderType,
    placeholderOf,
    matchKey,
    text,
    textStyleJson,
    fillJson,
    strokeJson,
    effectsJson,
    opacity,
    dataJson,
    linkJson,
    altText,
    decorative,
    createdAt,
  ];

  @override
  _isd.Table? getRelationTable(String relationField) {
    if (relationField == 'slide') {
      return slide;
    }
    if (relationField == 'layout') {
      return layout;
    }
    if (relationField == 'master') {
      return master;
    }
    if (relationField == 'parent') {
      return parent;
    }
    return null;
  }
}

class SlideElementInclude extends _isd.IncludeObject {
  SlideElementInclude._({
    _i810rwvy.SlideInclude? slide,
    _i810rwvy.SlideLayoutInclude? layout,
    _i810rwvy.SlideMasterInclude? master,
    _i810rwvy.SlideElementInclude? parent,
  }) {
    _slide = slide;
    _layout = layout;
    _master = master;
    _parent = parent;
  }

  _i810rwvy.SlideInclude? _slide;

  _i810rwvy.SlideLayoutInclude? _layout;

  _i810rwvy.SlideMasterInclude? _master;

  _i810rwvy.SlideElementInclude? _parent;

  @override
  Map<String, _isd.Include?> get includes => {
    'slide': _slide,
    'layout': _layout,
    'master': _master,
    'parent': _parent,
  };

  @override
  _isd.Table<_iss.UuidValue> get table => SlideElement.t;
}

class SlideElementIncludeList extends _isd.IncludeList {
  SlideElementIncludeList._({
    _isd.WhereExpressionBuilder<SlideElementTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(SlideElement.t);
  }

  @override
  Map<String, _isd.Include?> get includes => include?.includes ?? {};

  @override
  _isd.Table<_iss.UuidValue> get table => SlideElement.t;
}

class SlideElementRepository {
  const SlideElementRepository._();

  final attachRow = const SlideElementAttachRowRepository._();

  final detachRow = const SlideElementDetachRowRepository._();

  /// Returns a list of [SlideElement]s matching the given query parameters.
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
  Future<List<SlideElement>> find(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideElementTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    _isd.Transaction? transaction,
    SlideElementInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<SlideElement>(
      where: where?.call(SlideElement.t),
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [SlideElement]s matching the given query parameters every time the
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
  /// to that set. Pass [Table] instances such as `SlideElement.t`.
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
  _ida.Stream<List<SlideElement>> watch(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideElementTable>? where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    SlideElementInclude? include,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_isd.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<SlideElement>(
      where: where?.call(SlideElement.t),
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      limit: limit,
      offset: offset,
      include: include,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [SlideElement] matching the given query parameters.
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
  Future<SlideElement?> findFirstRow(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideElementTable>? where,
    int? offset,
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    _isd.Transaction? transaction,
    SlideElementInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<SlideElement>(
      where: where?.call(SlideElement.t),
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      offset: offset,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [SlideElement] by its [id] or null if no such row exists.
  Future<SlideElement?> findById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    _isd.Transaction? transaction,
    SlideElementInclude? include,
    _isd.LockMode? lockMode,
    _isd.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<SlideElement>(
      id,
      transaction: transaction,
      include: include,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [SlideElement]s in the list and returns the inserted rows.
  ///
  /// The returned [SlideElement]s will have their `id` fields set.
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
  Future<List<SlideElement>> insert(
    _isd.DatabaseSession session,
    List<SlideElement> rows, {
    _isd.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<SlideElement>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [SlideElement] and returns the inserted row.
  ///
  /// The returned [SlideElement] will have its `id` field set.
  Future<SlideElement> insertRow(
    _isd.DatabaseSession session,
    SlideElement row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.insertRow<SlideElement>(row, transaction: transaction);
  }

  /// Upserts all [SlideElement]s in the list and returns the resulting rows.
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
  /// The returned [SlideElement]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideElement>> upsert(
    _isd.DatabaseSession session,
    List<SlideElement> rows, {
    required _isd.ColumnSelections<SlideElementTable> conflictColumns,
    _isd.ColumnSelections<SlideElementTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideElementTable>? updateWhere,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<SlideElement>(
      rows,
      conflictColumns: conflictColumns(SlideElement.t),
      updateColumns: updateColumns?.call(SlideElement.t),
      updateWhere: updateWhere?.call(SlideElement.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [SlideElement] and returns the resulting row.
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
  /// The returned [SlideElement] will have its `id` field set.
  Future<SlideElement?> upsertRow(
    _isd.DatabaseSession session,
    SlideElement row, {
    required _isd.ColumnSelections<SlideElementTable> conflictColumns,
    _isd.ColumnSelections<SlideElementTable>? updateColumns,
    _isd.WhereExpressionBuilder<SlideElementTable>? updateWhere,
    _isd.Transaction? transaction,
  }) async {
    return session.db.upsertRow<SlideElement>(
      row,
      conflictColumns: conflictColumns(SlideElement.t),
      updateColumns: updateColumns?.call(SlideElement.t),
      updateWhere: updateWhere?.call(SlideElement.t),
      transaction: transaction,
    );
  }

  /// Updates all [SlideElement]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideElement>> update(
    _isd.DatabaseSession session,
    List<SlideElement> rows, {
    _isd.ColumnSelections<SlideElementTable>? columns,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<SlideElement>(
      rows,
      columns: columns?.call(SlideElement.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [SlideElement]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<SlideElement> updateRow(
    _isd.DatabaseSession session,
    SlideElement row, {
    _isd.ColumnSelections<SlideElementTable>? columns,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateRow<SlideElement>(
      row,
      columns: columns?.call(SlideElement.t),
      transaction: transaction,
    );
  }

  /// Updates a single [SlideElement] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<SlideElement?> updateById(
    _isd.DatabaseSession session,
    _iss.UuidValue id, {
    required _isd.ColumnValueListBuilder<SlideElementUpdateTable> columnValues,
    _isd.Transaction? transaction,
  }) async {
    return session.db.updateById<SlideElement>(
      id,
      columnValues: columnValues(SlideElement.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [SlideElement]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideElement>> updateWhere(
    _isd.DatabaseSession session, {
    required _isd.ColumnValueListBuilder<SlideElementUpdateTable> columnValues,
    required _isd.WhereExpressionBuilder<SlideElementTable> where,
    int? limit,
    int? offset,
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<SlideElement>(
      columnValues: columnValues(SlideElement.t.updateTable),
      where: where(SlideElement.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [SlideElement]s in the list and returns the deleted rows.
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
  Future<List<SlideElement>> delete(
    _isd.DatabaseSession session,
    List<SlideElement> rows, {
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<SlideElement>(
      rows,
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [SlideElement].
  Future<SlideElement> deleteRow(
    _isd.DatabaseSession session,
    SlideElement row, {
    _isd.Transaction? transaction,
  }) async {
    return session.db.deleteRow<SlideElement>(row, transaction: transaction);
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<SlideElement>> deleteWhere(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideElementTable> where,
    _isd.OrderByBuilder<SlideElementTable>? orderBy,
    _isd.OrderByListBuilder<SlideElementTable>? orderByList,
    _isd.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<SlideElement>(
      where: where(SlideElement.t),
      orderBy: orderBy?.call(SlideElement.t),
      orderByList: orderByList?.call(SlideElement.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _isd.DatabaseSession session, {
    _isd.WhereExpressionBuilder<SlideElementTable>? where,
    int? limit,
    _isd.Transaction? transaction,
  }) async {
    return session.db.count<SlideElement>(
      where: where?.call(SlideElement.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [SlideElement] rows matching the [where] expression.
  Future<void> lockRows(
    _isd.DatabaseSession session, {
    required _isd.WhereExpressionBuilder<SlideElementTable> where,
    required _isd.LockMode lockMode,
    required _isd.Transaction transaction,
    _isd.LockBehavior lockBehavior = _isd.LockBehavior.wait,
  }) async {
    return session.db.lockRows<SlideElement>(
      where: where(SlideElement.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}

class SlideElementAttachRowRepository {
  const SlideElementAttachRowRepository._();

  /// Creates a relation between the given [SlideElement] and [Slide]
  /// by setting the [SlideElement]'s foreign key `slideId` to refer to the [Slide].
  Future<void> slide(
    _isd.DatabaseSession session,
    SlideElement slideElement,
    _i810rwvy.Slide slide, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }
    if (slide.id == null) {
      throw ArgumentError.notNull('slide.id');
    }

    var $slideElement = slideElement.copyWith(slideId: slide.id);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.slideId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SlideElement] and [SlideLayout]
  /// by setting the [SlideElement]'s foreign key `layoutId` to refer to the [SlideLayout].
  Future<void> layout(
    _isd.DatabaseSession session,
    SlideElement slideElement,
    _i810rwvy.SlideLayout layout, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }
    if (layout.id == null) {
      throw ArgumentError.notNull('layout.id');
    }

    var $slideElement = slideElement.copyWith(layoutId: layout.id);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.layoutId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SlideElement] and [SlideMaster]
  /// by setting the [SlideElement]'s foreign key `masterId` to refer to the [SlideMaster].
  Future<void> master(
    _isd.DatabaseSession session,
    SlideElement slideElement,
    _i810rwvy.SlideMaster master, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }
    if (master.id == null) {
      throw ArgumentError.notNull('master.id');
    }

    var $slideElement = slideElement.copyWith(masterId: master.id);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.masterId],
      transaction: transaction,
    );
  }

  /// Creates a relation between the given [SlideElement] and [SlideElement]
  /// by setting the [SlideElement]'s foreign key `parentId` to refer to the [SlideElement].
  Future<void> parent(
    _isd.DatabaseSession session,
    SlideElement slideElement,
    _i810rwvy.SlideElement parent, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }
    if (parent.id == null) {
      throw ArgumentError.notNull('parent.id');
    }

    var $slideElement = slideElement.copyWith(parentId: parent.id);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.parentId],
      transaction: transaction,
    );
  }
}

class SlideElementDetachRowRepository {
  const SlideElementDetachRowRepository._();

  /// Detaches the relation between this [SlideElement] and the [Slide] set in `slide`
  /// by setting the [SlideElement]'s foreign key `slideId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> slide(
    _isd.DatabaseSession session,
    SlideElement slideElement, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }

    var $slideElement = slideElement.copyWith(slideId: null);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.slideId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [SlideElement] and the [SlideLayout] set in `layout`
  /// by setting the [SlideElement]'s foreign key `layoutId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> layout(
    _isd.DatabaseSession session,
    SlideElement slideElement, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }

    var $slideElement = slideElement.copyWith(layoutId: null);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.layoutId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [SlideElement] and the [SlideMaster] set in `master`
  /// by setting the [SlideElement]'s foreign key `masterId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> master(
    _isd.DatabaseSession session,
    SlideElement slideElement, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }

    var $slideElement = slideElement.copyWith(masterId: null);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.masterId],
      transaction: transaction,
    );
  }

  /// Detaches the relation between this [SlideElement] and the [SlideElement] set in `parent`
  /// by setting the [SlideElement]'s foreign key `parentId` to `null`.
  ///
  /// This removes the association between the two models without deleting
  /// the related record.
  Future<void> parent(
    _isd.DatabaseSession session,
    SlideElement slideElement, {
    _isd.Transaction? transaction,
  }) async {
    if (slideElement.id == null) {
      throw ArgumentError.notNull('slideElement.id');
    }

    var $slideElement = slideElement.copyWith(parentId: null);
    await session.db.updateRow<SlideElement>(
      $slideElement,
      columns: [SlideElement.t.parentId],
      transaction: transaction,
    );
  }
}
