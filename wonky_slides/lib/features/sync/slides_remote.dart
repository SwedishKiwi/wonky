import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show EndpointSyncRemote, SyncRemote;

/// The server calls of the Slides data layer (Slides 02 §9, suite 12 §2):
/// the custom sync endpoint and the deck space endpoints. Production uses
/// [ClientSlidesRemote]; tests use fakes.
typedef SlidesRemote = SyncRemote;

/// [SlidesRemote] on the generated client: `slidesSync.sync` (so the server
/// runs `onMergeSuccess` → `DeckChangeLog` consumption, and its OS-8 space
/// filter only syncs deck spaces) and the `slides` space endpoints. Every
/// call honours *Simulate offline* (`EndpointSyncRemote`).
class ClientSlidesRemote extends EndpointSyncRemote {
  ClientSlidesRemote(this.client)
    : super(
        sync: ({required changes, required once}) =>
            client.slidesSync.sync(changes: changes, once: once),
        reserveSpaces: client.slides.reserveSpaces,
        subscribe: client.slides.subscribe,
        spaceStats: client.slides.spaceStats,
        ensureSubscribed: client.slides.ensureSubscribed,
        unsubscribe: client.slides.unsubscribe,
      );

  final Client client;
}
