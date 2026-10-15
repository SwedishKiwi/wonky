import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/maintenance.dart';
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/planner.dart';

import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../../platform/sharing/access_service.dart';
import '../../platform/spaces/space_service.dart';
import '../sync/server_slides_writer.dart';
import 'deck_text_claims.dart';
import 'headless_deck_cache.dart';

/// The server's request context of the headless contracts
/// (`HeadlessDeckProvider<C>`, Slides 12 §5.7): the session and the acting
/// user (MCP token, AI assistant, server job).
class HeadlessDeckContext {
  const HeadlessDeckContext(this.session, this.actor);

  final Session session;
  final Actor actor;
}

/// The result of [ServerHeadlessDeck.write] (11 §2.2).
class HeadlessDeckWrite {
  HeadlessDeckWrite({
    required this.plan,
    required this.changeId,
    required this.syncVersion,
    required this.repaired,
  });

  final SlidesPlan plan;

  /// `change_id` for `changes.revert` (24 h); null when nothing changed.
  final UuidValue? changeId;

  /// `sync_version`: the last `DeckChangeLog` row id.
  final UuidValue? syncVersion;

  /// Whether a maintenance plan ("Repair presentation") ran first.
  final bool repaired;
}

/// A deck opened on the server for one caller (Slides 11 §2.1): reads come
/// from the cached [DeckModel] ([HeadlessDeckCache]); writes plan with the
/// shared `SlidesPlanner`, run the deck's maintenance first (02 §10, not
/// recorded), refuse bodies other users are editing (`being_edited`)
/// unless forced, and go through [ServerSlidesWriter.applyRecorded] (one
/// transaction per ≤ 5,000 changes + `DeckChangeLog`, `ServerChangeRecord`
/// for revert), written through to the cache. Mutations on one deck are
/// serialized per instance.
class ServerHeadlessDeck implements HeadlessDeck {
  ServerHeadlessDeck(this.context, this.item, this.role, this._entry);

  final HeadlessDeckContext context;

  /// The deck's drive item.
  final DriveItem item;

  /// The caller's role when opened.
  final Role role;

  CachedDeck _entry;

  /// The deck space (= item uuid).
  UuidValue get space => item.contentRef!;

  @override
  DeckModel get model => _entry.model;

  @override
  Future<SlidesPlan> execute(
    SlidesOperation op, {
    String actorKind = 'mcp',
  }) async => (await write(op, actorKind: actorKind)).plan;

  /// Plans and writes [op] (see the class comment). [force] writes bodies
  /// others are editing. [label] overrides the plan's label.
  Future<HeadlessDeckWrite> write(
    SlidesOperation op, {
    String? actorKind,
    bool force = false,
    String? label,
  }) {
    final session = context.session;
    final actor = context.actor.copyWith(
      kind: ActorKind.values.asNameMap()[actorKind] ?? context.actor.kind,
    );
    return HeadlessDeckCache.withWriteLock(space, () async {
      await AccessService.requireRole(session, actor, item, Role.editor);
      _entry = await HeadlessDeckCache.open(session, space);
      var repaired = false;
      final repair = DeckMaintenance.repairOp(model);
      if (repair != null) {
        final fix = const SlidesPlanner().plan(repair, model, _context(actor));
        if (fix.changes.isNotEmpty) {
          // Not part of the change record (11 §2.1).
          await SpaceService.ensureWriter(session, actor, item);
          await ServerSlidesWriter.apply(
            session,
            actor: actor.copyWith(kind: ActorKind.user),
            deckSpace: space,
            changes: fix.changes,
            label: DeckMaintenance.label,
          );
          repaired = true;
        }
      }
      final plan = const SlidesPlanner().plan(op, model, _context(actor));
      if (!force) {
        await DeckTextClaims.watch(session, item.uuid);
        final hits = DeckTextClaims.conflicts(
          item.uuid,
          plan.changes,
          actingUser: actor.authUserId,
        );
        if (hits.isNotEmpty) throw beingEdited(hits);
      }
      if (plan.changes.isEmpty) {
        return HeadlessDeckWrite(
          plan: plan,
          changeId: null,
          syncVersion: null,
          repaired: repaired,
        );
      }
      final written = await ServerSlidesWriter.applyRecorded(
        session,
        actor: actor,
        item: item,
        changes: plan.changes,
        label: label ?? plan.label,
        detailJson: plan.detailJson,
      );
      return HeadlessDeckWrite(
        plan: plan,
        changeId: written.changeId,
        syncVersion: written.syncVersion,
        repaired: repaired,
      );
    });
  }

  SlidesPlanContext _context(Actor actor) => SlidesPlanContext(
    userId: actor.authUserId.uuid,
    now: clock.now().toUtc(),
    isOwner: item.ownerId == actor.userId,
  );

  /// The `being_edited` error (11 §2.3): code `conflict` with details
  /// `{"code": "being_edited", "targets": [...]}` (the MCP layer maps it).
  static WonkyException beingEdited(List<DeckTextClaim> claims) {
    final names = {for (final c in claims) c.displayName}.join(', ');
    return WonkyException(
      code: WonkyErrorCode.conflict,
      message:
          '$names ${claims.length == 1 ? 'is' : 'are'} editing this text. '
          'Pass force to write anyway.',
      detailsJson: jsonEncode({
        'code': beingEditedCode,
        'targets': [for (final c in claims) c.toJson()],
      }),
    );
  }

  /// `details.code` of [beingEdited].
  static const beingEditedCode = 'being_edited';
}

/// Opens headless decks (Slides 12 §5.7, 11 §2.1) by deck id (= space =
/// item uuid) for the context's user: Viewer+ reads, Editor+ writes.
class SlidesHeadlessProvider
    implements HeadlessDeckProvider<HeadlessDeckContext> {
  const SlidesHeadlessProvider();

  @override
  Future<ServerHeadlessDeck> open(
    HeadlessDeckContext context,
    String deckId,
  ) async {
    final space = UuidValue.withValidation(deckId);
    final item = await DriveItem.db.findFirstRow(
      context.session,
      where: (t) =>
          t.contentRef.equals(space) &
          t.kind.equals(DriveItemKind.presentation),
    );
    if (item == null) {
      throw Errors.notFound('Presentation');
    }
    final role = await AccessService.requireRole(
      context.session,
      context.actor,
      item,
      Role.viewer,
    );
    final entry = await HeadlessDeckCache.open(context.session, space);
    return ServerHeadlessDeck(context, item, role, entry);
  }
}
