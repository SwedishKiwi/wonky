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
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:wonky_client/src/protocol/protocol.dart' as _i8pkqg1o;
import '../../../platform/ai/models/ai_apply_mode.dart' as _iinkwvx0;

/// Volatile context of a chat message (Write 09 §5.6).
abstract class AssistantContextHints
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AssistantContextHints._({
    this.documentSessionId,
    required this.applyMode,
    this.revision,
    this.selectionStart,
    this.selectionLength,
    this.selectionText,
    this.caretHeadingPath,
    bool? includeComments,
    this.localTime,
    this.sheetsActiveSheet,
    this.sheetsSelection,
    this.sheetsActiveCell,
    this.sheetsVisibleRange,
    this.slidesCurrentSlide,
    this.slidesSelectedSlides,
    this.slidesSelectedElements,
    this.uiTools,
  }) : includeComments = includeComments ?? false;

  factory AssistantContextHints({
    String? documentSessionId,
    required _iinkwvx0.AiApplyMode applyMode,
    int? revision,
    int? selectionStart,
    int? selectionLength,
    String? selectionText,
    String? caretHeadingPath,
    bool? includeComments,
    String? localTime,
    String? sheetsActiveSheet,
    List<String>? sheetsSelection,
    String? sheetsActiveCell,
    String? sheetsVisibleRange,
    String? slidesCurrentSlide,
    List<String>? slidesSelectedSlides,
    List<String>? slidesSelectedElements,
    List<String>? uiTools,
  }) = _AssistantContextHintsImpl;

  factory AssistantContextHints.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return AssistantContextHints(
      documentSessionId: jsonSerialization['documentSessionId'] as String?,
      applyMode: _iinkwvx0.AiApplyMode.fromJson(
        (jsonSerialization['applyMode'] as String),
      ),
      revision: jsonSerialization['revision'] as int?,
      selectionStart: jsonSerialization['selectionStart'] as int?,
      selectionLength: jsonSerialization['selectionLength'] as int?,
      selectionText: jsonSerialization['selectionText'] as String?,
      caretHeadingPath: jsonSerialization['caretHeadingPath'] as String?,
      includeComments: jsonSerialization['includeComments'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(
              jsonSerialization['includeComments'],
            ),
      localTime: jsonSerialization['localTime'] as String?,
      sheetsActiveSheet: jsonSerialization['sheetsActiveSheet'] as String?,
      sheetsSelection: jsonSerialization['sheetsSelection'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<String>>(
              jsonSerialization['sheetsSelection'],
            ),
      sheetsActiveCell: jsonSerialization['sheetsActiveCell'] as String?,
      sheetsVisibleRange: jsonSerialization['sheetsVisibleRange'] as String?,
      slidesCurrentSlide: jsonSerialization['slidesCurrentSlide'] as String?,
      slidesSelectedSlides: jsonSerialization['slidesSelectedSlides'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<String>>(
              jsonSerialization['slidesSelectedSlides'],
            ),
      slidesSelectedElements:
          jsonSerialization['slidesSelectedElements'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<String>>(
              jsonSerialization['slidesSelectedElements'],
            ),
      uiTools: jsonSerialization['uiTools'] == null
          ? null
          : _i8pkqg1o.Protocol().deserialize<List<String>>(
              jsonSerialization['uiTools'],
            ),
    );
  }

  /// The client's document stream session (`DocInit.sessionId`): ops of
  /// the run carry it as `onBehalfOfSessionId` (one undo step there).
  String? documentSessionId;

  _iinkwvx0.AiApplyMode applyMode;

  /// Selection in Delta offsets of [revision] plus its plain text.
  int? revision;

  int? selectionStart;

  int? selectionLength;

  String? selectionText;

  /// Heading path of the caret ("Plan › Budget").
  String? caretHeadingPath;

  /// Include open comments (quick prompt "Address comments").
  bool includeComments;

  /// The user's local date/time ("2026-10-13 14:05 Europe/Stockholm").
  String? localTime;

  /// Sheets (12 §6.1): the active sheet, the selected A1 ranges, the
  /// active cell and the visible range of the requesting window.
  String? sheetsActiveSheet;

  List<String>? sheetsSelection;

  String? sheetsActiveCell;

  String? sheetsVisibleRange;

  /// Slides (11 §6.2): the current slide, the selected slides and the
  /// selected elements of the requesting window.
  String? slidesCurrentSlide;

  List<String>? slidesSelectedSlides;

  List<String>? slidesSelectedElements;

  /// `ui.*` tools the requesting window runs for the assistant (Sheets
  /// 12 §6.2: get_selection, select_range, highlight_range); null = none.
  List<String>? uiTools;

  /// Returns a shallow copy of this [AssistantContextHints]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AssistantContextHints copyWith({
    String? documentSessionId,
    _iinkwvx0.AiApplyMode? applyMode,
    int? revision,
    int? selectionStart,
    int? selectionLength,
    String? selectionText,
    String? caretHeadingPath,
    bool? includeComments,
    String? localTime,
    String? sheetsActiveSheet,
    List<String>? sheetsSelection = const _isc.$UndefinedList<String>(),
    String? sheetsActiveCell,
    String? sheetsVisibleRange,
    String? slidesCurrentSlide,
    List<String>? slidesSelectedSlides = const _isc.$UndefinedList<String>(),
    List<String>? slidesSelectedElements = const _isc.$UndefinedList<String>(),
    List<String>? uiTools = const _isc.$UndefinedList<String>(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AssistantContextHints',
      if (documentSessionId != null) 'documentSessionId': documentSessionId,
      'applyMode': applyMode.toJson(),
      if (revision != null) 'revision': revision,
      if (selectionStart != null) 'selectionStart': selectionStart,
      if (selectionLength != null) 'selectionLength': selectionLength,
      if (selectionText != null) 'selectionText': selectionText,
      if (caretHeadingPath != null) 'caretHeadingPath': caretHeadingPath,
      'includeComments': includeComments,
      if (localTime != null) 'localTime': localTime,
      if (sheetsActiveSheet != null) 'sheetsActiveSheet': sheetsActiveSheet,
      if (sheetsSelection != null) 'sheetsSelection': sheetsSelection?.toJson(),
      if (sheetsActiveCell != null) 'sheetsActiveCell': sheetsActiveCell,
      if (sheetsVisibleRange != null) 'sheetsVisibleRange': sheetsVisibleRange,
      if (slidesCurrentSlide != null) 'slidesCurrentSlide': slidesCurrentSlide,
      if (slidesSelectedSlides != null)
        'slidesSelectedSlides': slidesSelectedSlides?.toJson(),
      if (slidesSelectedElements != null)
        'slidesSelectedElements': slidesSelectedElements?.toJson(),
      if (uiTools != null) 'uiTools': uiTools?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AssistantContextHints',
      if (documentSessionId != null) 'documentSessionId': documentSessionId,
      'applyMode': applyMode.toJson(),
      if (revision != null) 'revision': revision,
      if (selectionStart != null) 'selectionStart': selectionStart,
      if (selectionLength != null) 'selectionLength': selectionLength,
      if (selectionText != null) 'selectionText': selectionText,
      if (caretHeadingPath != null) 'caretHeadingPath': caretHeadingPath,
      'includeComments': includeComments,
      if (localTime != null) 'localTime': localTime,
      if (sheetsActiveSheet != null) 'sheetsActiveSheet': sheetsActiveSheet,
      if (sheetsSelection != null) 'sheetsSelection': sheetsSelection?.toJson(),
      if (sheetsActiveCell != null) 'sheetsActiveCell': sheetsActiveCell,
      if (sheetsVisibleRange != null) 'sheetsVisibleRange': sheetsVisibleRange,
      if (slidesCurrentSlide != null) 'slidesCurrentSlide': slidesCurrentSlide,
      if (slidesSelectedSlides != null)
        'slidesSelectedSlides': slidesSelectedSlides?.toJson(),
      if (slidesSelectedElements != null)
        'slidesSelectedElements': slidesSelectedElements?.toJson(),
      if (uiTools != null) 'uiTools': uiTools?.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AssistantContextHintsImpl extends AssistantContextHints {
  _AssistantContextHintsImpl({
    String? documentSessionId,
    required _iinkwvx0.AiApplyMode applyMode,
    int? revision,
    int? selectionStart,
    int? selectionLength,
    String? selectionText,
    String? caretHeadingPath,
    bool? includeComments,
    String? localTime,
    String? sheetsActiveSheet,
    List<String>? sheetsSelection,
    String? sheetsActiveCell,
    String? sheetsVisibleRange,
    String? slidesCurrentSlide,
    List<String>? slidesSelectedSlides,
    List<String>? slidesSelectedElements,
    List<String>? uiTools,
  }) : super._(
         documentSessionId: documentSessionId,
         applyMode: applyMode,
         revision: revision,
         selectionStart: selectionStart,
         selectionLength: selectionLength,
         selectionText: selectionText,
         caretHeadingPath: caretHeadingPath,
         includeComments: includeComments,
         localTime: localTime,
         sheetsActiveSheet: sheetsActiveSheet,
         sheetsSelection: sheetsSelection,
         sheetsActiveCell: sheetsActiveCell,
         sheetsVisibleRange: sheetsVisibleRange,
         slidesCurrentSlide: slidesCurrentSlide,
         slidesSelectedSlides: slidesSelectedSlides,
         slidesSelectedElements: slidesSelectedElements,
         uiTools: uiTools,
       );

  /// Returns a shallow copy of this [AssistantContextHints]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AssistantContextHints copyWith({
    Object? documentSessionId = _Undefined,
    _iinkwvx0.AiApplyMode? applyMode,
    Object? revision = _Undefined,
    Object? selectionStart = _Undefined,
    Object? selectionLength = _Undefined,
    Object? selectionText = _Undefined,
    Object? caretHeadingPath = _Undefined,
    bool? includeComments,
    Object? localTime = _Undefined,
    Object? sheetsActiveSheet = _Undefined,
    List<String>? sheetsSelection = const _isc.$UndefinedList<String>(),
    Object? sheetsActiveCell = _Undefined,
    Object? sheetsVisibleRange = _Undefined,
    Object? slidesCurrentSlide = _Undefined,
    List<String>? slidesSelectedSlides = const _isc.$UndefinedList<String>(),
    List<String>? slidesSelectedElements = const _isc.$UndefinedList<String>(),
    List<String>? uiTools = const _isc.$UndefinedList<String>(),
  }) {
    return AssistantContextHints(
      documentSessionId: documentSessionId is String?
          ? documentSessionId
          : this.documentSessionId,
      applyMode: applyMode ?? this.applyMode,
      revision: revision is int? ? revision : this.revision,
      selectionStart: selectionStart is int?
          ? selectionStart
          : this.selectionStart,
      selectionLength: selectionLength is int?
          ? selectionLength
          : this.selectionLength,
      selectionText: selectionText is String?
          ? selectionText
          : this.selectionText,
      caretHeadingPath: caretHeadingPath is String?
          ? caretHeadingPath
          : this.caretHeadingPath,
      includeComments: includeComments ?? this.includeComments,
      localTime: localTime is String? ? localTime : this.localTime,
      sheetsActiveSheet: sheetsActiveSheet is String?
          ? sheetsActiveSheet
          : this.sheetsActiveSheet,
      sheetsSelection: sheetsSelection is _isc.UndefinedSentinel
          ? this.sheetsSelection?.map((e0) => e0).toList()
          : sheetsSelection,
      sheetsActiveCell: sheetsActiveCell is String?
          ? sheetsActiveCell
          : this.sheetsActiveCell,
      sheetsVisibleRange: sheetsVisibleRange is String?
          ? sheetsVisibleRange
          : this.sheetsVisibleRange,
      slidesCurrentSlide: slidesCurrentSlide is String?
          ? slidesCurrentSlide
          : this.slidesCurrentSlide,
      slidesSelectedSlides: slidesSelectedSlides is _isc.UndefinedSentinel
          ? this.slidesSelectedSlides?.map((e0) => e0).toList()
          : slidesSelectedSlides,
      slidesSelectedElements: slidesSelectedElements is _isc.UndefinedSentinel
          ? this.slidesSelectedElements?.map((e0) => e0).toList()
          : slidesSelectedElements,
      uiTools: uiTools is _isc.UndefinedSentinel
          ? this.uiTools?.map((e0) => e0).toList()
          : uiTools,
    );
  }
}
