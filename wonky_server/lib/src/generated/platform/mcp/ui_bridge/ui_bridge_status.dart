/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

part of 'ui_bridge_message.dart';

/// App → server: the window's route, open item or focus changed.
abstract class UiBridgeStatus extends _i26f4ubs.UiBridgeMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UiBridgeStatus._({
    this.route,
    this.openItemUuid,
    this.title,
    required this.focused,
  });

  factory UiBridgeStatus({
    String? route,
    String? openItemUuid,
    String? title,
    required bool focused,
  }) = _UiBridgeStatusImpl;

  factory UiBridgeStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeStatus(
      route: jsonSerialization['route'] as String?,
      openItemUuid: jsonSerialization['openItemUuid'] as String?,
      title: jsonSerialization['title'] as String?,
      focused: _is.BoolJsonExtension.fromJson(jsonSerialization['focused']),
    );
  }

  String? route;

  String? openItemUuid;

  String? title;

  bool focused;

  /// Returns a shallow copy of this [UiBridgeStatus]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  UiBridgeStatus copyWith({
    String? route,
    String? openItemUuid,
    String? title,
    bool? focused,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeStatus',
      if (route != null) 'route': route,
      if (openItemUuid != null) 'openItemUuid': openItemUuid,
      if (title != null) 'title': title,
      'focused': focused,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeStatus',
      if (route != null) 'route': route,
      if (openItemUuid != null) 'openItemUuid': openItemUuid,
      if (title != null) 'title': title,
      'focused': focused,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UiBridgeStatusImpl extends UiBridgeStatus {
  _UiBridgeStatusImpl({
    String? route,
    String? openItemUuid,
    String? title,
    required bool focused,
  }) : super._(
         route: route,
         openItemUuid: openItemUuid,
         title: title,
         focused: focused,
       );

  /// Returns a shallow copy of this [UiBridgeStatus]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UiBridgeStatus copyWith({
    Object? route = _Undefined,
    Object? openItemUuid = _Undefined,
    Object? title = _Undefined,
    bool? focused,
  }) {
    return UiBridgeStatus(
      route: route is String? ? route : this.route,
      openItemUuid: openItemUuid is String? ? openItemUuid : this.openItemUuid,
      title: title is String? ? title : this.title,
      focused: focused ?? this.focused,
    );
  }
}
