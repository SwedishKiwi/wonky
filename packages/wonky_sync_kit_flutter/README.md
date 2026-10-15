# wonky_sync_kit_flutter

Client half of the shared offline-sync kit of Wonky Work (Flutter), extracted from
`wonky_sheets/lib/features/sync` (specs/wonky_slides/12-implementation-plan.md §5.2,
specs/12-offline-and-sync.md §2.5–2.6, Drive 05 D-6). Table-agnostic: an app supplies its
`SyncTableSet`, its change-log row and its model ingestion.

| Area | API |
|------|-----|
| Replica | `SyncReplica` (`<app>_<userId>.db`: spaces, membership, reservations, dirty marks, space loading, purge), `ReplicaFiles`, `offlineStorageLimited`, `ReplicaRecoveryReader` / `RecoveredSpace` |
| Journal | `ChangeJournal`, `JournalChanges` (suite 12 U11) |
| Writer | `SyncWriter` (chunked `transactionForUser`, column-named updates, `bulkWrite` runs; hooks `writeChangeLog`, `summarize`, `columnsIfVisible`), `ChangeLogEntry` |
| Controller | `AppSyncController` (loop, backoff, visibility, reservations, `DeviceRowCap`, weekly purge, sessions), `SyncRemote` / `EndpointSyncRemote`, `SyncConnectivity`, `SyncSessionHost`, `HostedSpaceSession`, `SyncOfflineException`, `NoReservedSpaceException` |
| Sessions | `SpaceWriteQueue`, `JournalIngestion`, `SpaceOpening` |
| Shell | `ReplicaInstallation` (per-user lifecycle, *Clear local data*, recovery), `ReplicaOfflineProvider`, `ShellSyncConnectivity` |

Sheets binds it in `wonky_sheets/lib/features/sync/` (`SheetsReplica`, `SheetsWriter`,
`SheetsSyncController`, `SyncedWorkbookSession`, `SheetsData`).
