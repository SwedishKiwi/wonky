import 'package:wonky_sync_kit_flutter/wonky_sync_kit_flutter.dart'
    show SyncOfflineException, SyncSessionHost;

import 'slides_replica.dart';
import 'slides_writer.dart';

/// Thrown by [SlidesSessionHost] calls that need the server while offline.
typedef SlidesOfflineException = SyncOfflineException;

/// What a `SyncedDeckSession` needs from the per-user sync controller
/// (implemented by `SlidesSyncController`; tests use a fake on a temporary
/// replica): the shared kit's [SyncSessionHost] on the Slides replica and
/// writer.
typedef SlidesSessionHost = SyncSessionHost<SlidesReplica, SlidesWriter>;
