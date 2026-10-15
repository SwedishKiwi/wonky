import 'dart:convert';

import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import '../text_editing/text_editing_host.dart' show TextLockTarget;

/// A soft-lock claim: the `editing` field of the Slides presence cursor
/// (Slides 02 §4.4, 09 §2.1; read by the server's `DeckTextClaims`).
@immutable
class EditingClaim {
  const EditingClaim({
    required this.kind,
    this.slideId,
    this.elementId,
    this.cellId,
    this.rowId,
    this.columnId,
    required this.since,
    this.forced = false,
  });

  /// The claim of [target] (cell ids from `SlidesIds.tableCellId`).
  factory EditingClaim.of(
    TextLockTarget target, {
    String? slideId,
    String? cellId,
    required int since,
    bool forced = false,
  }) => EditingClaim(
    kind: target.kind,
    slideId: target.slideId ?? slideId,
    elementId: target.elementId,
    cellId: cellId,
    rowId: target.rowId,
    columnId: target.columnId,
    since: since,
    forced: forced,
  );

  /// `text`, `notes`, `tableCell` (`code`, `codeState`, `groupTitle` come
  /// with their editors).
  final String kind;
  final String? slideId;
  final String? elementId;

  /// The `slide_table_cell` row id (server soft-lock check).
  final String? cellId;

  /// The cell's table row and column ids (the client maps cells by them).
  final String? rowId;
  final String? columnId;

  /// Claim start (sender clock, ms since epoch).
  final int since;

  /// Entered with *Edit anyway* / *Keep editing*.
  final bool forced;

  /// The body as a lock target, or null for kinds this client doesn't edit.
  TextLockTarget? get target => switch (kind) {
    'text' when elementId != null => TextLockTarget.element(elementId!),
    'tableCell' when elementId != null && rowId != null && columnId != null =>
      TextLockTarget.cell(elementId!, rowId!, columnId!),
    'notes' when slideId != null => TextLockTarget.notes(slideId!),
    _ => null,
  };

  EditingClaim copyWith({int? since, bool? forced}) => EditingClaim(
    kind: kind,
    slideId: slideId,
    elementId: elementId,
    cellId: cellId,
    rowId: rowId,
    columnId: columnId,
    since: since ?? this.since,
    forced: forced ?? this.forced,
  );

  Map<String, Object?> toJson() => {
    'kind': kind,
    'slideId': slideId,
    'elementId': elementId,
    'cellId': cellId,
    if (rowId != null) 'rowId': rowId,
    if (columnId != null) 'columnId': columnId,
    'stateId': null,
    'since': since,
    'forced': forced,
  };

  static EditingClaim? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = j['kind'];
    final since = j['since'];
    if (kind is! String || since is! num) return null;
    String? s(String k) => j[k] is String ? j[k] as String : null;
    return EditingClaim(
      kind: kind,
      slideId: s('slideId'),
      elementId: s('elementId'),
      cellId: s('cellId'),
      rowId: s('rowId'),
      columnId: s('columnId'),
      since: since.toInt(),
      forced: j['forced'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EditingClaim &&
      other.kind == kind &&
      other.slideId == slideId &&
      other.elementId == elementId &&
      other.cellId == cellId &&
      other.rowId == rowId &&
      other.columnId == columnId &&
      other.since == since &&
      other.forced == forced;

  @override
  int get hashCode => Object.hash(
    kind,
    slideId,
    elementId,
    cellId,
    rowId,
    columnId,
    since,
    forced,
  );
}

/// The canvas view of a followed participant (09 §1.5): sent only while
/// someone follows.
@immutable
class DeckViewport {
  const DeckViewport({
    required this.slideId,
    this.zoom,
    required this.cx,
    required this.cy,
  });

  final String slideId;

  /// The zoom, or null for *Fit*.
  final double? zoom;

  /// The slide point (su) at the center of the canvas.
  final double cx;
  final double cy;

  Map<String, Object?> toJson() => {
    'slideId': slideId,
    'zoom': zoom,
    'cx': _round(cx),
    'cy': _round(cy),
  };

  static DeckViewport? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['slideId'], x = j['cx'], y = j['cy'], z = j['zoom'];
    if (s is! String || x is! num || y is! num) return null;
    return DeckViewport(
      slideId: s,
      zoom: z is num ? z.toDouble() : null,
      cx: x.toDouble(),
      cy: y.toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeckViewport &&
      other.slideId == slideId &&
      other.zoom == zoom &&
      other.cx == cx &&
      other.cy == cy;

  @override
  int get hashCode => Object.hash(slideId, zoom, cx, cy);
}

/// Where a presenting participant is (09 §1.6, 10).
@immutable
class PresentingState {
  const PresentingState({
    this.presentationId,
    required this.slideId,
    this.step = 0,
  });

  /// The presentation session (audience views follow it), or null when
  /// presenting without a session.
  final String? presentationId;
  final String slideId;
  final int step;

  Map<String, Object?> toJson() => {
    'presentationId': presentationId,
    'slideId': slideId,
    'step': step,
  };

  static PresentingState? fromJson(Object? j) {
    if (j is! Map) return null;
    final s = j['slideId'];
    if (s is! String) return null;
    final step = j['step'];
    final p = j['presentationId'];
    return PresentingState(
      presentationId: p is String ? p : null,
      slideId: s,
      step: step is num ? step.toInt() : 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PresentingState &&
      other.presentationId == presentationId &&
      other.slideId == slideId &&
      other.step == step;

  @override
  int get hashCode => Object.hash(presentationId, slideId, step);
}

/// The Slides `PresenceCursor` JSON (Slides 09 §1.1, A-09-1): route, view
/// mode, current slide, selected elements, navigator selection, the
/// soft-lock claim, the live transform flag, the viewport (only while
/// followed), presenting and whom this window follows.
@immutable
class SlidesPresenceCursor {
  const SlidesPresenceCursor({
    this.route = 'editor',
    this.viewMode = 'normal',
    this.slideId,
    this.surfaceId,
    this.selection = const [],
    this.navSlides = const [],
    this.navGroups = const [],
    this.editing,
    this.pointer,
    this.transform = false,
    this.viewport,
    this.presenting,
    this.following,
  });

  /// At most this many selected ids are sent.
  static const maxSelection = 50;

  /// `editor`, `present`, `history`, `print`.
  final String route;

  /// `normal`, `grid`, `outline`, `masters`.
  final String viewMode;
  final String? slideId;

  /// In masters mode, the layout or master being edited (09 §1.1: the
  /// canvas surface; [selection] and [pointer] are on it). Null otherwise.
  final String? surfaceId;

  /// Selected element ids of [slideId] (of [surfaceId] in masters mode).
  final List<String> selection;

  /// The navigator selection (slides and groups).
  final List<String> navSlides;
  final List<String> navGroups;
  final EditingClaim? editing;

  /// The mouse pointer on [slideId] in slide units (09 §1.4, P1), or null
  /// when the pointer is off the slide or the window is not focused.
  final Offset? pointer;

  /// Whether a drag is live (frames travel as hints, 09 §2.4).
  final bool transform;
  final DeckViewport? viewport;
  final PresentingState? presenting;

  /// The presence session this window follows (the followed user sees "Bo
  /// is following you").
  final String? following;

  /// Whether the participant presents.
  bool get isPresenting => presenting != null || route == 'present';

  String encode() => jsonEncode({
    'app': 'slides',
    'route': route,
    'viewMode': viewMode,
    'slideId': slideId,
    if (surfaceId != null) 'surfaceId': surfaceId,
    'selection': selection.take(maxSelection).toList(),
    'navSelection': {'slides': navSlides, 'groups': navGroups},
    'editing': editing?.toJson(),
    'pointer': pointer == null
        ? null
        : {'x': _whole(pointer!.dx), 'y': _whole(pointer!.dy)},
    'transform': transform ? true : null,
    'viewport': viewport?.toJson(),
    'presenting': presenting?.toJson(),
    if (following != null) 'following': following,
  });

  /// Parses a Slides cursor; null for other apps' cursors and bad JSON.
  static SlidesPresenceCursor? tryParse(String? json) {
    if (json == null) return null;
    Object? j;
    try {
      j = jsonDecode(json);
    } on FormatException {
      return null;
    }
    if (j is! Map || j['app'] != 'slides') return null;
    List<String> ids(Object? v) => v is List
        ? [
            for (final x in v.take(maxSelection))
              if (x is String) x,
          ]
        : const [];
    final nav = j['navSelection'];
    final route = j['route'];
    final mode = j['viewMode'];
    final slide = j['slideId'];
    final surface = j['surfaceId'];
    final following = j['following'];
    final pointer = j['pointer'];
    final px = pointer is Map ? pointer['x'] : null;
    final py = pointer is Map ? pointer['y'] : null;
    return SlidesPresenceCursor(
      route: route is String ? route : 'editor',
      viewMode: mode is String ? mode : 'normal',
      slideId: slide is String ? slide : null,
      surfaceId: surface is String ? surface : null,
      selection: ids(j['selection']),
      navSlides: nav is Map ? ids(nav['slides']) : const [],
      navGroups: nav is Map ? ids(nav['groups']) : const [],
      editing: EditingClaim.fromJson(j['editing']),
      pointer: px is num && py is num
          ? Offset(px.toDouble(), py.toDouble())
          : null,
      transform: j['transform'] == true,
      viewport: DeckViewport.fromJson(j['viewport']),
      presenting: PresentingState.fromJson(j['presenting']),
      following: following is String ? following : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SlidesPresenceCursor && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

double _round(double v) => (v * 10).roundToDouble() / 10;

double _whole(double v) => v.roundToDouble();
