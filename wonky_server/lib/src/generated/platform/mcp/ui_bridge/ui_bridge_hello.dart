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

/// App → server, first message: registers the window in the hub.
abstract class UiBridgeHello extends _i26f4ubs.UiBridgeMessage
    implements _is.SerializableModel, _is.ProtocolSerialization {
  UiBridgeHello._({
    required this.app,
    required this.deviceLabel,
    required this.platform,
    this.route,
    this.openItemUuid,
    this.title,
    required this.focused,
    required this.tools,
  });

  factory UiBridgeHello({
    required String app,
    required String deviceLabel,
    required String platform,
    String? route,
    String? openItemUuid,
    String? title,
    required bool focused,
    required List<String> tools,
  }) = _UiBridgeHelloImpl;

  factory UiBridgeHello.fromJson(Map<String, dynamic> jsonSerialization) {
    return UiBridgeHello(
      app: jsonSerialization['app'] as String,
      deviceLabel: jsonSerialization['deviceLabel'] as String,
      platform: jsonSerialization['platform'] as String,
      route: jsonSerialization['route'] as String?,
      openItemUuid: jsonSerialization['openItemUuid'] as String?,
      title: jsonSerialization['title'] as String?,
      focused: _is.BoolJsonExtension.fromJson(jsonSerialization['focused']),
      tools: _il4umwa0.Protocol().deserialize<List<String>>(
        jsonSerialization['tools'],
      ),
    );
  }

  /// `write` or `sheets`.
  String app;

  /// e.g. "Chrome on macOS".
  String deviceLabel;

  /// `web`, `macos`, `windows`, `linux`.
  String platform;

  String? route;

  String? openItemUuid;

  String? title;

  bool focused;

  /// Ids of the `ui.*` tools this window implements.
  List<String> tools;

  /// Returns a shallow copy of this [UiBridgeHello]
  /// with some or all fields replaced by the given arguments.
  @override
  @_is.useResult
  UiBridgeHello copyWith({
    String? app,
    String? deviceLabel,
    String? platform,
    String? route,
    String? openItemUuid,
    String? title,
    bool? focused,
    List<String>? tools,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'UiBridgeHello',
      'app': app,
      'deviceLabel': deviceLabel,
      'platform': platform,
      if (route != null) 'route': route,
      if (openItemUuid != null) 'openItemUuid': openItemUuid,
      if (title != null) 'title': title,
      'focused': focused,
      'tools': tools.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'UiBridgeHello',
      'app': app,
      'deviceLabel': deviceLabel,
      'platform': platform,
      if (route != null) 'route': route,
      if (openItemUuid != null) 'openItemUuid': openItemUuid,
      if (title != null) 'title': title,
      'focused': focused,
      'tools': tools.toJson(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _UiBridgeHelloImpl extends UiBridgeHello {
  _UiBridgeHelloImpl({
    required String app,
    required String deviceLabel,
    required String platform,
    String? route,
    String? openItemUuid,
    String? title,
    required bool focused,
    required List<String> tools,
  }) : super._(
         app: app,
         deviceLabel: deviceLabel,
         platform: platform,
         route: route,
         openItemUuid: openItemUuid,
         title: title,
         focused: focused,
         tools: tools,
       );

  /// Returns a shallow copy of this [UiBridgeHello]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  UiBridgeHello copyWith({
    String? app,
    String? deviceLabel,
    String? platform,
    Object? route = _Undefined,
    Object? openItemUuid = _Undefined,
    Object? title = _Undefined,
    bool? focused,
    List<String>? tools,
  }) {
    return UiBridgeHello(
      app: app ?? this.app,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      platform: platform ?? this.platform,
      route: route is String? ? route : this.route,
      openItemUuid: openItemUuid is String? ? openItemUuid : this.openItemUuid,
      title: title is String? ? title : this.title,
      focused: focused ?? this.focused,
      tools: tools ?? this.tools.map((e0) => e0).toList(),
    );
  }
}
