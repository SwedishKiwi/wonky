import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show EndpointSyncRemote, SyncRemote;

/// The server calls of the Sheets data layer (suite 12 §2): the custom sync
/// endpoint and the space endpoints. Production uses [ClientSheetsRemote];
/// tests use fakes.
typedef SheetsRemote = SyncRemote;

/// [SheetsRemote] on the generated client: `sheetsSync.sync` (so the server
/// runs `onMergeSuccess` → change-log consumption) and the `sheets` space
/// endpoints.
class ClientSheetsRemote extends EndpointSyncRemote {
  ClientSheetsRemote(this.client)
    : super(
        sync: ({required changes, required once}) =>
            client.sheetsSync.sync(changes: changes, once: once),
        reserveSpaces: client.sheets.reserveSpaces,
        subscribe: client.sheets.subscribe,
        spaceStats: client.sheets.spaceStats,
        ensureSubscribed: client.sheets.ensureSubscribed,
        unsubscribe: client.sheets.unsubscribe,
      );

  final Client client;
}
