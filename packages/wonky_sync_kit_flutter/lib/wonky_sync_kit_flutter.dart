/// Shared offline-sync client of Wonky Work (extracted from Wonky Sheets;
/// Slides 12 §5.2, suite 12 §2.5–2.6, Drive 05 D-6): the per-user replica,
/// the change journal, the writer, the sync controller with its lifecycle,
/// the building blocks of synced file sessions, recovery reads and storage
/// detection. The pure half (row changes, plans, undo) is `wonky_sync_kit`.
library;

export 'src/controller/app_sync_controller.dart';
export 'src/controller/sync_remote.dart';
export 'src/controller/sync_session_host.dart';
export 'src/install/replica_installation.dart';
export 'src/journal/change_journal.dart';
export 'src/replica/replica_files.dart';
export 'src/replica/replica_recovery.dart';
export 'src/replica/storage_mode.dart';
export 'src/replica/sync_replica.dart';
export 'src/session/journal_ingestion.dart';
export 'src/session/space_opening.dart';
export 'src/session/space_write_queue.dart';
export 'src/writer/sync_writer.dart';
