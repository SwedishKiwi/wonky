import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show SyncOfflineException, SyncSessionHost;

import 'sheets_replica.dart';
import 'sheets_writer.dart';

/// Thrown by [SheetsSessionHost] calls that need the server while offline.
typedef SheetsOfflineException = SyncOfflineException;

/// What a `SyncedWorkbookSession` needs from the per-user sync controller
/// (implemented by `SheetsSyncController`; tests use a fake on a temporary
/// replica): the shared kit's [SyncSessionHost] on the Sheets replica and
/// writer.
typedef SheetsSessionHost = SyncSessionHost<SheetsReplica, SheetsWriter>;
