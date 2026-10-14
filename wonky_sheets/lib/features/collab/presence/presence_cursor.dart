import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One selected range of a [SheetsPresenceCursor] by ids (null bounds are
/// open: whole rows have no column ids, whole columns no row ids).
@immutable
class PresenceRange {
  const PresenceRange({this.r1, this.c1, this.r2, this.c2});

  final String? r1;
  final String? c1;
  final String? r2;
  final String? c2;

  Map<String, Object?> toJson() => {'r1': ?r1, 'c1': ?c1, 'r2': ?r2, 'c2': ?c2};

  static PresenceRange? fromJson(Object? j) {
    if (j is! Map) return null;
    String? s(String k) => j[k] is String ? j[k] as String : null;
    return PresenceRange(r1: s('r1'), c1: s('c1'), r2: s('r2'), c2: s('c2'));
  }

  @override
  bool operator ==(Object other) =>
      other is PresenceRange &&
      other.r1 == r1 &&
      other.c1 == c1 &&
      other.r2 == r2 &&
      other.c2 == c2;

  @override
  int get hashCode => Object.hash(r1, c1, r2, c2);
}

/// The top-left of a participant's viewport (sent only while followed,
/// Sheets 10 §1.5).
@immutable
class PresenceViewport {
  const PresenceViewport({
    required this.topRowId,
    required this.leftColId,
    this.zoom = 1,
  });

  final String topRowId;
  final String leftColId;
  final double zoom;

  Map<String, Object?> toJson() => {
    'topRowId': topRowId,
    'leftColId': leftColId,
    'zoom': zoom,
  };

  static PresenceViewport? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['topRowId'];
    final l = j['leftColId'];
    if (t is! String || l is! String) return null;
    final z = j['zoom'];
    return PresenceViewport(
      topRowId: t,
      leftColId: l,
      zoom: z is num ? z.toDouble() : 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PresenceViewport &&
      other.topRowId == topRowId &&
      other.leftColId == leftColId &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(topRowId, leftColId, zoom);
}

/// Sheets' `PresenceCursor` JSON (Sheets 10 §1.1): where a participant is
/// and what they select, by ids.
@immutable
class SheetsPresenceCursor {
  const SheetsPresenceCursor({
    this.route = 'grid',
    required this.sheetId,
    this.activeRowId,
    this.activeColId,
    this.ranges = const [],
    this.editing = false,
    this.objectId,
    this.viewport,
    this.following,
    this.file,
  });

  /// Max ranges sent.
  static const maxRanges = 20;

  /// grid | script | history | print.
  final String route;
  final String sheetId;
  final String? activeRowId;
  final String? activeColId;
  final List<PresenceRange> ranges;

  /// The cell editor is open on the active cell.
  final bool editing;

  /// Selected embedded object (charts/images).
  final String? objectId;
  final PresenceViewport? viewport;

  /// The session this participant follows ("Following you").
  final String? following;

  /// The script file open in the script editor (`route == 'script'`,
  /// Sheets 09 §14.3).
  final String? file;

  bool get hasActiveCell => activeRowId != null && activeColId != null;

  Map<String, Object?> toJson() => {
    'route': route,
    'sheetId': sheetId,
    if (hasActiveCell)
      'activeCell': {'rowId': activeRowId, 'colId': activeColId},
    if (ranges.isNotEmpty)
      'ranges': [for (final r in ranges.take(maxRanges)) r.toJson()],
    if (editing) 'editing': true,
    'objectId': ?objectId,
    if (viewport != null) 'viewport': viewport!.toJson(),
    'following': ?following,
    'file': ?file,
  };

  String encode() => jsonEncode(toJson());

  /// Parses cursor JSON; null when it isn't a Sheets cursor.
  static SheetsPresenceCursor? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final j = jsonDecode(json);
      if (j is! Map) return null;
      final sheetId = j['sheetId'];
      if (sheetId is! String) return null;
      final active = j['activeCell'];
      final rawRanges = j['ranges'];
      return SheetsPresenceCursor(
        route: j['route'] is String ? j['route'] as String : 'grid',
        sheetId: sheetId,
        activeRowId: active is Map && active['rowId'] is String
            ? active['rowId'] as String
            : null,
        activeColId: active is Map && active['colId'] is String
            ? active['colId'] as String
            : null,
        ranges: rawRanges is List
            ? [
                for (final r in rawRanges.take(maxRanges))
                  ?PresenceRange.fromJson(r),
              ]
            : const [],
        editing: j['editing'] == true,
        objectId: j['objectId'] is String ? j['objectId'] as String : null,
        viewport: PresenceViewport.fromJson(j['viewport']),
        following: j['following'] is String ? j['following'] as String : null,
        file: j['file'] is String ? j['file'] as String : null,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SheetsPresenceCursor &&
      other.route == route &&
      other.sheetId == sheetId &&
      other.activeRowId == activeRowId &&
      other.activeColId == activeColId &&
      listEquals(other.ranges, ranges) &&
      other.editing == editing &&
      other.objectId == objectId &&
      other.viewport == viewport &&
      other.following == following &&
      other.file == file;

  @override
  int get hashCode => Object.hash(
    route,
    sheetId,
    activeRowId,
    activeColId,
    Object.hashAll(ranges),
    editing,
    objectId,
    viewport,
    following,
    file,
  );
}
