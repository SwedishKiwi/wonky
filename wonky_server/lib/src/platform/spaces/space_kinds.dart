import 'package:serverpod/serverpod.dart';

import '../common/models.dart';

/// Space kinds (suite 12 §2.6, Slides 02 §9.2): which drive item a space
/// holds, and how the server knows a space's kind.
///
/// A space's kind is recorded when it is born and never changes:
/// - the drive item whose `contentRef` is the space (spreadsheet →
///   [SpaceKind.spreadsheet], presentation → [SpaceKind.deck]) — it wins;
/// - before registration, its [SpaceReservation] (`kind`, set by the
///   endpoint that reserved it, or by `SpaceService.createSpace` for spaces
///   the server creates).
///
/// Spaces with neither (v1 spaces the server created for a spreadsheet
/// before its drive item, nothing else) count as [unrecordedKind].
abstract final class SpaceKinds {
  /// The kind of a space without a drive item or reservation. Spreadsheets
  /// predate kinds, so unrecorded spaces stay with Sheets (as in v1); a deck
  /// space is always recorded from birth.
  static const unrecordedKind = SpaceKind.spreadsheet;

  /// The space kind of a drive item kind, null for items without a space.
  static SpaceKind? ofItemKind(DriveItemKind kind) => switch (kind) {
    DriveItemKind.spreadsheet => SpaceKind.spreadsheet,
    DriveItemKind.presentation => SpaceKind.deck,
    _ => null,
  };

  /// The drive item kind holding a space of [kind].
  static DriveItemKind itemKindOf(SpaceKind kind) => switch (kind) {
    SpaceKind.spreadsheet => DriveItemKind.spreadsheet,
    SpaceKind.deck => DriveItemKind.presentation,
  };

  /// The space kind of [item], null when it has no space.
  static SpaceKind? ofItem(DriveItem item) =>
      item.contentRef == null ? null : ofItemKind(item.kind);

  /// The user-facing noun of [kind] for messages.
  static String nounOf(SpaceKind kind) => switch (kind) {
    SpaceKind.spreadsheet => 'spreadsheet',
    SpaceKind.deck => 'presentation',
  };

  /// The recorded kinds of [spaces] by UUID string; spaces without a drive
  /// item or reservation are missing.
  static Future<Map<String, SpaceKind>> recorded(
    Session session,
    Iterable<UuidValue> spaces, {
    Transaction? transaction,
  }) async {
    final set = spaces.toSet();
    if (set.isEmpty) return const {};
    final out = <String, SpaceKind>{};
    final reservations = await SpaceReservation.db.find(
      session,
      where: (t) => t.spaceUuid.inSet(set),
      transaction: transaction,
    );
    for (final r in reservations) {
      out[r.spaceUuid.uuid] = r.kind;
    }
    final items = await DriveItem.db.find(
      session,
      where: (t) =>
          t.contentRef.inSet(set) &
          t.kind.inSet({DriveItemKind.spreadsheet, DriveItemKind.presentation}),
      transaction: transaction,
    );
    // Drive items win over reservations.
    for (final item in items) {
      out[item.contentRef!.uuid] = ofItemKind(item.kind)!;
    }
    return out;
  }

  /// The kind of [space] ([unrecordedKind] when nothing records it).
  static Future<SpaceKind> of(
    Session session,
    UuidValue space, {
    Transaction? transaction,
  }) async =>
      (await recorded(session, [
        space,
      ], transaction: transaction))[space.uuid] ??
      unrecordedKind;
}

/// The space filter of one sync stream (offline-sync patch OS-8): keeps the
/// member spaces of [kind]. The engine always keeps the personal space.
///
/// Kinds never change, so decisions are cached for the stream's lifetime;
/// only spaces seen for the first time cost a lookup (two indexed queries
/// per batch of new memberships). Unrecorded spaces are looked up again in
/// the next cycle, so a space registered later is classified then.
class SpaceKindFilter {
  SpaceKindFilter(this._session, this.kind);

  final Session _session;

  /// The kind this stream syncs.
  final SpaceKind kind;

  final Map<String, SpaceKind> _known = {};

  /// Number of lookups so far (tests).
  int lookups = 0;

  /// The `spaceFilter` callback of `OfflineSyncEngine.sync`.
  Future<Iterable<UuidValue>> call(List<UuidValue> spaces) async {
    final unknown = [
      for (final s in spaces)
        if (!_known.containsKey(s.uuid)) s,
    ];
    if (unknown.isNotEmpty) {
      lookups++;
      _known.addAll(await SpaceKinds.recorded(_session, unknown));
    }
    return [
      for (final s in spaces)
        if ((_known[s.uuid] ?? SpaceKinds.unrecordedKind) == kind) s,
    ];
  }
}
