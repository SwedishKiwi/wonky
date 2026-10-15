import 'package:clock/clock.dart';
import 'package:wonky_client/wonky_client.dart' show UuidValue;
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_slides_core/interfaces.dart' show SlideImageResolver;
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart' show SlidesTables;
import 'package:wonky_slides_core/templates.dart' show SlidesTemplate;
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show AppSyncController, DeviceRowCap, SyncConnectivity;

import '../model/synced_deck_session.dart';
import 'slides_replica.dart';
import 'slides_writer.dart';

export 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show NoReservedSpaceException;

/// Connection state for the controller (the shell's `ConnectivityService`
/// in the app, a plain notifier in tests).
typedef SlidesConnectivity = SyncConnectivity;

/// The signed-in user's Slides sync (Slides 02 §9, suite 12 §2.5): the
/// shared kit's [AppSyncController] on the replica `slides_<userId>.db` and
/// the custom `slidesSync.sync` endpoint, hosting the open
/// [SyncedDeckSession]s.
///
/// The kit runs the loop (pending-change guard → `syncOnce` → reservation
/// refill to a pool of [reservationTarget] = 3 deck spaces →
/// `syncContinuously`, backoff, *Simulate offline*, pause when hidden, the
/// weekly purge of hidden decks). Slides adds offline deck creation
/// ([createLocalPresentation], 02 §9.3), session opening ([openSession]) and
/// the element cap of browsers without OPFS ([elementCap]).
class SlidesSyncController
    extends AppSyncController<SlidesReplica, SlidesWriter, SyncedDeckSession> {
  SlidesSyncController({
    required super.replica,
    required super.remote,
    required super.connectivity,
    required this.planner,
    super.sessionId,
    super.reservationTarget,
    super.hiddenGrace,
    this.elementCap,
    super.lastOpened,
    super.maintenanceStore,
    super.random,
  }) : super(
         writer: SlidesWriter(replica),
         name: 'slides',
         rowCap: elementCap == null
             ? null
             : DeviceRowCap(
                 table: SlidesTables.slideElement,
                 maxRows: elementCap,
               ),
       );

  /// The planner of every deck write (SL-7's `SlidesPlanner` in the app).
  final SlidesMutationPlanner planner;

  /// Max elements kept on this device (the IndexedDB fallback of the web,
  /// suite 12 intro; null = unlimited). Above it, the decks opened least
  /// recently leave the active set (`enforceRowCap`).
  final int? elementCap;

  /// Creates a deck in a usable reserved space (works offline): plans
  /// `CreateDeck` (deck row = space id, the copy of built-in theme
  /// [themeKey] with its masters, layouts and their elements, one slide
  /// with layout `title` and its placeholder instances) and writes it in
  /// one transaction with the "Create presentation" `DeckChangeLog` row.
  /// With a built-in [template] (SL-22) the deck is the template's (built
  /// by the same planner, so a template works offline too). Returns the
  /// space (= deck id = drive item uuid). Throws
  /// `NoReservedSpaceException` without a usable reservation. Registering
  /// it in the drive is the caller's job (`drive.registerPresentation`).
  Future<UuidValue> createLocalPresentation({
    required String title,
    String themeKey = 'wonky',
    SlidesTemplate? template,
  }) => createInReservedSpace((space) async {
    final now = clock.now().toUtc();
    if (template != null) {
      final deck = template.build(
        deckId: space.uuid,
        userId: replica.userUuid.uuid,
        now: now,
        title: title,
      );
      await writer.write(
        spaceId: space,
        changes: deck.inserts,
        label: 'Create presentation',
        actorKind: 'user',
        sessionId: sessionId,
      );
      return;
    }
    final plan = planner.plan(
      CreateDeck(deckId: space.uuid, title: title, themeKey: themeKey),
      DeckModel(deckId: space.uuid),
      SlidesPlanContext(userId: replica.userUuid.uuid, now: now, isOwner: true),
    );
    await writer.write(
      spaceId: space,
      changes: plan.changes,
      plan: plan,
      label: plan.label,
      actorKind: 'user',
      sessionId: sessionId,
    );
  });

  /// Opens a session on the deck [spaceUuid] (see [SyncedDeckSession.open]).
  SyncedDeckSession openSession({
    required UuidValue itemUuid,
    required UuidValue spaceUuid,
    Role role = Role.viewer,
    SlideImageResolver? images,
    SyncedDeckStrings strings = const SyncedDeckStrings(),
  }) => registerSession(
    SyncedDeckSession.open(
      this,
      itemUuid: itemUuid,
      spaceUuid: spaceUuid,
      planner: planner,
      role: role,
      images: images,
      strings: strings,
    ),
  );
}
