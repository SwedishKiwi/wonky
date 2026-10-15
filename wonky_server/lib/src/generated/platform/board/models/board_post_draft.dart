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
import '../../../platform/board/models/board_post_kind.dart' as _i76aj3nz;

/// Client payload of `board.createPost`.
abstract class BoardPostDraft
    implements _is.SerializableModel, _is.ProtocolSerialization {
  BoardPostDraft._({
    required this.kind,
    required this.title,
    required this.body,
    this.contextJson,
    required this.appHint,
    this.screenshotFileUuid,
  });

  factory BoardPostDraft({
    required _i76aj3nz.BoardPostKind kind,
    required String title,
    required String body,
    String? contextJson,
    required String appHint,
    _is.UuidValue? screenshotFileUuid,
  }) = _BoardPostDraftImpl;

  factory BoardPostDraft.fromJson(Map<String, dynamic> jsonSerialization) {
    return BoardPostDraft(
      kind: _i76aj3nz.BoardPostKind.fromJson(
        (jsonSerialization['kind'] as String),
      ),
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String,
      contextJson: jsonSerialization['contextJson'] as String?,
      appHint: jsonSerialization['appHint'] as String,
      screenshotFileUuid: jsonSerialization['screenshotFileUuid'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(
              jsonSerialization['screenshotFileUuid'],
            ),
    );
  }

  _i76aj3nz.BoardPostKind kind;

  String title;

  String body;

  String? contextJson;

  String appHint;

  _is.UuidValue? screenshotFileUuid;

  /// Returns a shallow copy of this [BoardPostDraft]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  BoardPostDraft copyWith({
    _i76aj3nz.BoardPostKind? kind,
    String? title,
    String? body,
    String? contextJson,
    String? appHint,
    _is.UuidValue? screenshotFileUuid = const _is.$UndefinedUuidValue(),
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BoardPostDraft',
      'kind': kind.toJson(),
      'title': title,
      'body': body,
      if (contextJson != null) 'contextJson': contextJson,
      'appHint': appHint,
      if (screenshotFileUuid != null)
        'screenshotFileUuid': screenshotFileUuid?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'BoardPostDraft',
      'kind': kind.toJson(),
      'title': title,
      'body': body,
      if (contextJson != null) 'contextJson': contextJson,
      'appHint': appHint,
      if (screenshotFileUuid != null)
        'screenshotFileUuid': screenshotFileUuid?.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _BoardPostDraftImpl extends BoardPostDraft {
  _BoardPostDraftImpl({
    required _i76aj3nz.BoardPostKind kind,
    required String title,
    required String body,
    String? contextJson,
    required String appHint,
    _is.UuidValue? screenshotFileUuid,
  }) : super._(
         kind: kind,
         title: title,
         body: body,
         contextJson: contextJson,
         appHint: appHint,
         screenshotFileUuid: screenshotFileUuid,
       );

  /// Returns a shallow copy of this [BoardPostDraft]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  BoardPostDraft copyWith({
    _i76aj3nz.BoardPostKind? kind,
    String? title,
    String? body,
    Object? contextJson = _Undefined,
    String? appHint,
    _is.UuidValue? screenshotFileUuid = const _is.$UndefinedUuidValue(),
  }) {
    return BoardPostDraft(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body ?? this.body,
      contextJson: contextJson is String? ? contextJson : this.contextJson,
      appHint: appHint ?? this.appHint,
      screenshotFileUuid: screenshotFileUuid is _is.UndefinedSentinel
          ? this.screenshotFileUuid
          : screenshotFileUuid,
    );
  }
}
