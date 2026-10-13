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
import '../../platform/activity/activity_trend_point.dart' as _izj9nrjj;
import '../../platform/activity/activity_viewer.dart' as _iyqye5jf;

/// Tools › Activity dashboard (specs/07 §6).
abstract class ActivityDashboard
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ActivityDashboard._({
    required this.days,
    required this.canSeeViewers,
    required this.viewers,
    required this.hiddenViewers,
    required this.viewTrend,
    required this.commentTrend,
    required this.showMyViewHistory,
  });

  factory ActivityDashboard({
    required int days,
    required bool canSeeViewers,
    required List<_iyqye5jf.ActivityViewer> viewers,
    required int hiddenViewers,
    required List<_izj9nrjj.ActivityTrendPoint> viewTrend,
    required List<_izj9nrjj.ActivityTrendPoint> commentTrend,
    required bool showMyViewHistory,
  }) = _ActivityDashboardImpl;

  factory ActivityDashboard.fromJson(Map<String, dynamic> jsonSerialization) {
    return ActivityDashboard(
      days: jsonSerialization['days'] as int,
      canSeeViewers: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['canSeeViewers'],
      ),
      viewers: _i8pkqg1o.Protocol().deserialize<List<_iyqye5jf.ActivityViewer>>(
        jsonSerialization['viewers'],
      ),
      hiddenViewers: jsonSerialization['hiddenViewers'] as int,
      viewTrend: _i8pkqg1o.Protocol()
          .deserialize<List<_izj9nrjj.ActivityTrendPoint>>(
            jsonSerialization['viewTrend'],
          ),
      commentTrend: _i8pkqg1o.Protocol()
          .deserialize<List<_izj9nrjj.ActivityTrendPoint>>(
            jsonSerialization['commentTrend'],
          ),
      showMyViewHistory: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['showMyViewHistory'],
      ),
    );
  }

  /// Period length in days (the trends have one point per day, oldest first).
  int days;

  /// Viewers are listed for Editors and Owners only.
  bool canSeeViewers;

  /// People in the item's share set who opened it, most recent first. Empty
  /// unless [canSeeViewers]; people with "Show my view history" off are left out.
  List<_iyqye5jf.ActivityViewer> viewers;

  /// Viewers left out because they turned their view history off.
  int hiddenViewers;

  /// Unique viewers per day.
  List<_izj9nrjj.ActivityTrendPoint> viewTrend;

  /// Comments and replies per day.
  List<_izj9nrjj.ActivityTrendPoint> commentTrend;

  /// The caller's own "Show my view history" setting.
  bool showMyViewHistory;

  /// Returns a shallow copy of this [ActivityDashboard]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ActivityDashboard copyWith({
    int? days,
    bool? canSeeViewers,
    List<_iyqye5jf.ActivityViewer>? viewers,
    int? hiddenViewers,
    List<_izj9nrjj.ActivityTrendPoint>? viewTrend,
    List<_izj9nrjj.ActivityTrendPoint>? commentTrend,
    bool? showMyViewHistory,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ActivityDashboard',
      'days': days,
      'canSeeViewers': canSeeViewers,
      'viewers': viewers.toJson(valueToJson: (v) => v.toJson()),
      'hiddenViewers': hiddenViewers,
      'viewTrend': viewTrend.toJson(valueToJson: (v) => v.toJson()),
      'commentTrend': commentTrend.toJson(valueToJson: (v) => v.toJson()),
      'showMyViewHistory': showMyViewHistory,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ActivityDashboard',
      'days': days,
      'canSeeViewers': canSeeViewers,
      'viewers': viewers.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'hiddenViewers': hiddenViewers,
      'viewTrend': viewTrend.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'commentTrend': commentTrend.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
      'showMyViewHistory': showMyViewHistory,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _ActivityDashboardImpl extends ActivityDashboard {
  _ActivityDashboardImpl({
    required int days,
    required bool canSeeViewers,
    required List<_iyqye5jf.ActivityViewer> viewers,
    required int hiddenViewers,
    required List<_izj9nrjj.ActivityTrendPoint> viewTrend,
    required List<_izj9nrjj.ActivityTrendPoint> commentTrend,
    required bool showMyViewHistory,
  }) : super._(
         days: days,
         canSeeViewers: canSeeViewers,
         viewers: viewers,
         hiddenViewers: hiddenViewers,
         viewTrend: viewTrend,
         commentTrend: commentTrend,
         showMyViewHistory: showMyViewHistory,
       );

  /// Returns a shallow copy of this [ActivityDashboard]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ActivityDashboard copyWith({
    int? days,
    bool? canSeeViewers,
    List<_iyqye5jf.ActivityViewer>? viewers,
    int? hiddenViewers,
    List<_izj9nrjj.ActivityTrendPoint>? viewTrend,
    List<_izj9nrjj.ActivityTrendPoint>? commentTrend,
    bool? showMyViewHistory,
  }) {
    return ActivityDashboard(
      days: days ?? this.days,
      canSeeViewers: canSeeViewers ?? this.canSeeViewers,
      viewers: viewers ?? this.viewers.map((e0) => e0.copyWith()).toList(),
      hiddenViewers: hiddenViewers ?? this.hiddenViewers,
      viewTrend:
          viewTrend ?? this.viewTrend.map((e0) => e0.copyWith()).toList(),
      commentTrend:
          commentTrend ?? this.commentTrend.map((e0) => e0.copyWith()).toList(),
      showMyViewHistory: showMyViewHistory ?? this.showMyViewHistory,
    );
  }
}
