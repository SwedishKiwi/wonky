# 12 · Offline, Sync and Local Storage

| App | Online sync | Offline strategy | Local store |
|-----|-------------|------------------|-------------|
| Write | Server-authoritative OT over a Serverpod stream (Quill Delta) | Local op queue + snapshot cache; rebase (transform) on reconnect | SQLite (`sqlite_async`, same infra as Sheets) — `write_cache_<userId>.db` |
| Sheets | `serverpod_offline_sync` CRDT replication | Native: local SQLite is the primary store | `sheets_<userId>.db` (synced tables + local-only tables) |
| Slides (v2) | `serverpod_offline_sync` CRDT replication (one deck = one space) | Native, like Sheets (§2.6) | `slides_<userId>.db` |
| Shell (all homes, incl. Drive) | RPC + `drive.watch` stream | Cached drive listing + queued drive ops + (v2) cached storage usage | device key-value store (§3) |
| Drive uploads (v2) | `drive.createFileUpload` / storage upload / `completeFileUpload` | Persistent upload queue, started when online | `LocalPendingUpload` in the Drive app's local DB (`drive_<userId>.db`, §1.1) |

All local databases are **per user** (file name includes the user's UUID). Signing out keeps them
(encrypted at rest on desktop via OS file protection; on web relies on origin storage);
*Settings › Offline & storage › Clear local data* deletes them (desktop) or clears them (web — DB
deletion is unsupported on web, so tables are truncated and the engine re-syncs).

Web storage: `sqlite_async` with `sqlite3.wasm` + `db_worker.js` in `web/` (versions must match
the `sqlite_async` version). `WebSqlite.connectToRecommended` picks **OPFS** when available,
else IndexedDB (which keeps the whole DB in memory). Large spreadsheets require OPFS; on the
IndexedDB fallback, offline availability is limited (configurable, default 200k cells total) and
the UI shows "Offline storage is limited in this browser". Build web with `--wasm` (as toptap).

> **As built (Sheets).** The worker doesn't report which storage it chose, so the app checks
> the same prerequisites (`storage_mode_web.dart`: secure context, `FileSystemFileHandle`, a
> working `navigator.storage.getDirectory()`). Without them, Settings › Offline & storage shows
> the warning (`OfflineUsage.warnings`), a toast says it once per user and device, and
> `SheetsSyncController.cellCap` (200,000) applies after each sync: the spreadsheets opened
> least recently on this device (from `LocalViewState` times) that are not open, have no
> unsynced writes and aren't the personal space leave the active set (`sheets.unsubscribe`;
> owners keep their spreadsheets, they are asked once per run) and are purged locally.

---

## 1. Write (documents)

### 1.1 Local cache tables (`database: client` style local tables, not synced)

Implemented with raw SQL on `sqlite_async` (`wonky_write/lib/features/offline/write_local_store.dart`,
migrations in `writeCacheMigrations`); the shared opener is `LocalDatabases.open` in `wonky_app`
(`core/local_database.dart`).

| Table | Fields |
|-------|--------|
| `LocalDocument` | `documentUuid`, `itemUuid`, `title`, `itemJson` (drive item, for offline open), `snapshotDelta` (JSON), `snapshotRevision`, `headRevision`, `metaJson`, `role`, `themeId`, `updatedAt`, `lastOpenedAt`, `pinned`, `sizeBytes` |
| `LocalDocumentOp` | `documentUuid`, `revision`, `deltaJson` — server ops after the snapshot (an op log, so a remote op costs a small insert instead of a snapshot rewrite; folded into the snapshot every 200 ops, after a resync and when the document closes) |
| `LocalPendingOp` | `documentUuid`, `seq` (local monotonically increasing), `baseRevision`, `deltaJson`, `clientOpId` (UUIDv7), `createdAt`, `kind` (content kinds / `meta`), `inflight` (may have been sent; resent with the same id) |
| `LocalUndoStack` | `documentUuid`, `stackJson` (serialized undo/redo stacks, best-effort), `docHash` (SHA-256 of the local document the stacks apply to; restored only onto an identical document) |
| `LocalPendingUpload` | `fileUuid` (client-generated UUIDv7), `itemUuid`, `bytes` (blob), `mimeType`, `fileName`, `createdAt`, `attempts`, `lastError` — shared by all apps (images in documents, images over cells, (v2) images on slides, imports); (v2) also `purpose` (`attachment` / `driveFile`), `parentUuid`, `sizeBytes`, `lastModified`, `sourcePath` (desktop: upload from the original path), `state`, `receivedBytes` (resume), `volatile` (web without OPFS, > 5 MB) — [Drive 02 §4.1](wonky_drive/02-files-uploads-previews.md). The Drive app keeps its queue in `drive_<userId>.db` (opened with `LocalDatabases.open`, same migrations helper) |

Consistency: every write stores one consistent capture of the sync state in one transaction — the
server ops since the last write (or a new snapshot) plus the outbox rows that changed. Outbox ops
are always expressed against `headRevision`, so a reload restores exactly `server document +
outbox`. A failed write makes the next one a full rewrite.

**Uploads and the files service.** (v2) Every upload is checked against the storage quota of
the user it is charged to (the item owner for images, the uploader for Drive files); a queued
upload refused for quota stays queued as failed with *Retry* / *Manage storage*
([Drive 03 §6.3](wonky_drive/03-storage-quota.md)). `FileEndpoint` (server `platform/files`) accepts a
**client-supplied `fileUuid`** and is idempotent on it: `createUpload(fileUuid, itemUuid,
fileName, mimeType, size)` → upload description; `completeUpload(fileUuid)`;
`getUrl(fileUuid)` → `{status: pending|ready|failed, url?}` (signed, 15 min). Content may
reference `wonky-file://<fileUuid>` before the bytes arrive; clients render a placeholder while
`status == pending` (uploader's own client renders from local bytes). Uploads are retried from
`LocalPendingUpload` with backoff when online.

### 1.2 Behavior
- Opening a document: render from `LocalDocument` immediately if present (stale-while-
  revalidate), then connect the stream; server sends ops since `snapshotRevision` (or a fresh
  snapshot if too old). The cached drive item is revalidated in the background. A document that
  is not on the device cannot be opened offline ("This document isn't available offline"; it
  re-opens by itself when the connection returns).
- Every local change is written to `LocalPendingOp` **before** sending (durable outbox): the
  controller only sends an op once the write that contains it completed.
- Offline: editing continues; pending ops accumulate (composed into one op per 2 s of typing to
  bound the queue). Remote cursors disappear; presence shows "Offline". The status indicator
  says "Offline" (its tooltip and details dialog: "Offline — changes saved on this device"); the
  shell shows the offline banner.
- Reconnect: client sends pending ops with their `baseRevision`; server transforms them against
  ops since that revision (bounded: if `baseRevision` is older than the server's retained op
  log — 30 days — the server rejects with `RebaseTooOld`, and the client offers *Save my offline
  changes as a copy* which creates a new document from the local state). The copy is created
  like an offline document (client UUIDs) with the local state as its first pending op, so it
  works offline too and keeps every attribute.
- Documents that are not open but have an outbox (edited offline, then closed) are synced in
  the background by a headless sync session when the connection returns.
- Metadata changes (theme, page setup, language, front matter) made offline are queued as
  `LocalPendingOp` rows of kind `meta` and replayed with the same `clientOpId` after connecting.
- Documents become available offline when opened in the last 14 days (max 50) or **pinned**
  (*File › Make available offline*; pinned documents are downloaded with `document.getInfo` +
  `getSnapshot` when pinned and whenever the app comes online). Documents with local changes are
  never evicted. Drive list shows offline badges (pinned: check; recently opened: muted check;
  pinned but not downloaded yet: download arrow) and, while offline, dims files that are not on
  the device (tooltip "This file isn't available offline"; opening shows the same toast).
- New documents can be created offline: client generates `documentUuid` (UUIDv7) and
  `itemUuid`, stores a pending `createDocument` intent; the server endpoint is idempotent on
  these UUIDs. The document opens at once from an empty local copy (revision 0, which is what the
  server creates) and connects once the queued creation went through. Creations from a template
  or with initial content need the server and open when back online.
- Images inserted offline are stored in `LocalPendingUpload` before uploading, render from the
  local bytes (also after a reload) and upload with backoff (2 s → 10 min) when online.
- The signed-in user's profile is kept on the device so the app can start offline with the
  user's local data.
- *Settings › Offline & storage* shows files on the device, pinned files, pending changes,
  pending uploads and storage used, *Clear local data*, and the developer switch *Simulate
  offline* (`ConnectivityService.forceOffline`, the test hook of suite 15 §9: streams are dropped
  and every repository call fails like a network error; also the command
  `write.offline.simulate` for the UI bridge; remembered across reloads).

Details of the OT protocol are in [Write 03 · Sync protocol](wonky_write/03-sync-protocol.md).

## 2. Sheets (spreadsheets)

### 2.1 Engine facts that shape the design (serverpod_offline_sync 0.0.9)
- A **space** is the unit of replication; rows never change space; ids are global (UUID); FKs
  must stay inside a space; unique indexes must include `spaceId` and a releasable column;
  synced ↔ non-synced relations are forbidden (use plain `UuidValue`).
- Field-level last-writer-wins by HLC; **every update must name its columns** (otherwise all
  fields are recorded as touched and concurrent edits are clobbered). A repository lint test
  (as in toptap) fails the build on any synced-table update without `columnValues`.
- Deletes are tombstones; re-inserting the same id revives the row.
- Two inserts of the same id (deterministic cell ids created on two devices) merge **per
  column**: a column an insert leaves null is not authored by it (vendored patch OS-4; upstream
  merges such inserts as whole rows, newest wins).
- Roles: `readOnly` / `readWrite`. Membership managed only on the server.
- **A client syncs every space it is a member of** (no partial/lazy sync, no local eviction API).
- Continuous sync is a ~1.2 s lockstep loop → remote propagation ≈ 0.2–2.5 s.
- No per-change server hooks; only per-space `onMergeSuccess(spaceUuid, hlc)` in a custom sync
  endpoint.
- One space per transaction.
- Schema changes are lock-step via `syncTablesHash`.

### 2.2 Spaces
- **One spreadsheet = one space**; `Spreadsheet.id == space UUID` (toptap pattern D1).
- New spreadsheets offline: each device keeps a **pool of 3 reserved spaces**
  (`SheetsEndpoint.reserveSpaces(count)` → `spaces.createFor(me)`), stored in a local
  `ReservedSpace` client table. A reservation is usable after the next sync delivers membership.
  After creating the `Spreadsheet` row, the client calls `drive.registerSpreadsheet(spaceUuid,
  …)` (queued if offline; idempotent).
- **A spreadsheet's drive item UUID is its space UUID** (every creation path: registration,
  `drive.createSpreadsheet`, templates, imports, copies). A spreadsheet created offline therefore
  opens at `/s/<space>` at once and keeps that URL after the queued registration.
- Client-only tables (`ReservedSpace`, `SheetsDirtySpace`, `SheetsRowJournal`,
  `SheetsJournalSpace`) are `database: client` models of the server project
  (`wonky_server/lib/src/sheets/models/`). Owning at least one client table is what makes the
  generator emit `Client.createSyncSession` and the client migrations
  (`wonky_client/lib/migrations/`); the shared `database: sync` models are merged into that
  schema.
- The user's **personal space** (UUID = user id; implicit in the engine — always `readWrite`,
  no creation step needed) holds per-user synced data that is not tied to
  a spreadsheet (e.g. custom number formats library, recent colors) — small.

### 2.3 Active set ("subscriptions") — working around "sync all spaces"
Because clients sync every member space, membership doubles as subscription. The server
maintains an **active set** per user:

```yaml
class: SpaceSubscription          # server-only (database: server)
table: space_subscription
fields:
  userId: int
  spreadsheetItemId: int
  spaceUuid: UuidValue
  reason: SubscriptionReason      # open, pinned, recent, mcp, script
  lastUsedAt: DateTime
  pinned: bool
```

- Opening a spreadsheet calls `SheetsEndpoint.subscribe(itemUuid)` → server grants membership
  (role mirrored from ACL) if not yet granted; the client waits for the next sync cycle to
  deliver the space (progress UI: "Downloading spreadsheet… 42%" based on row counts from
  `SheetsEndpoint.spaceStats`).
- Active set limit: `sheets.maxActiveSpacesPerUser` (default 30). LRU eviction runs daily
  server-side and **never** evicts pinned spaces or spaces used in the last 30 days.
- **Pending-change guard**: before each sync session starts, the client lists spaces with
  unsynced local changes and calls `SheetsEndpoint.ensureSubscribed(spaces)` so a
  revoked-but-dirty space is re-granted before syncing (prevents stranded edits). The engine
  metadata can't tell "not yet acknowledged by the server" offline, so the writer marks the space
  in the local `SheetsDirtySpace` table on every write; the marks are cleared after a complete
  `syncOnce` for spaces that are still members (marks newer than the cycle's start stay).
- After eviction, rows stay on disk hidden by the engine; the client runs a local purge of
  hidden spaces' rows weekly (custom maintenance using the engine's space metadata) — tracked as
  an upstream requirement (see §4). **As built:** `SheetsSyncController.runMaintenance` after a
  sync, at most every 7 days (time in the user store): spaces with rows but no membership of
  the user, no dirty mark, not open → `SheetsReplica.purgeSpace` deletes their data rows,
  `crdt_data_rows` (cascading field metadata) and `offline_sync_space_nodes` (the checkpoints).
  Offline-sync patch **OS-5** makes a space without local rows ask for everything in its
  handshake (also the device's own earlier changes), so a re-granted purged space downloads
  completely.
- **Bulk local writes (as built, patch OS-7):** `OfflineSyncDatabase.bulkWrite` writes many rows
  of one table in a few set-based statements (inserts from one JSON parameter, batched updates
  and revives) when no foreign-key/unique projection can change, with the same CRDT records as
  the per-row calls; Sheets' `SheetsWriter` and the server's `SheetsBulkWriter` use it.

### 2.4 Live feel on top of the CRDT loop
- Local writes are visible instantly (local DB + watch).
- For collaborators, cell commits are additionally broadcast as **ephemeral hints** over the
  presence stream (`CellCommitHint {sheetId, rowId, colId, input, hlcMillis}`); receivers render
  the hinted value (italic-less, same style) until the synced row arrives or 5 s elapse. The
  CRDT row is always the source of truth.
- Watches must be **viewport-scoped** (query by sheet + visible row id ranges) because watch
  re-runs the whole query on any metadata change.

### 2.5 Sync lifecycle (client)
`SheetsSyncController`: after sign-in → open `sheets_<userId>.db` via
`client.createSyncSession(path, persistentUserId: userUuid)` → pending-change guard →
`syncOnce` → reservation refill → `syncContinuously` (through a **custom sync endpoint**
`sheetsSync.sync` wrapping `session.offlineSync.sync` so the server gets `onMergeSuccess` for
change-log processing; the client plugs it in as
`OfflineSyncClient((changes, once) => client.sheetsSync.sync(...))`) → on stream end, reconnect
(1 s after a normal end, backoff 1 s → 30 s with jitter after errors). Going offline
(`ConnectivityService`, incl. *Simulate offline*) cancels the stream; coming back wakes the loop.
Sync runs while the app is visible; when the app is hidden (web `visibilitychange`, desktop
lifecycle, via `AppLifecycleListener`) sync pauses after 30 s.
On open failure the DB is moved aside (desktop: `sheets_<userId>.db.broken-<ms>`, kept for
recovery) and a fresh replica re-syncs. **Recovery export** (desktop, `replica_recovery*.dart`):
before moving it aside, the file is read read-only with plain SQLite; the spreadsheets with a
`SheetsDirtySpace` mark (local writes not known to be synced) are read with their visible rows
(`crdt_data_rows.visibility`), and a toast offers **Download unsynced changes**: a ZIP with one
XLSX per spreadsheet (core exporters) and `rows.json` (the raw rows, lossless). On the web the
replica is emptied instead (no file to read). *Clear local data* deletes the file (desktop) or empties every table
(web) and re-syncs.

Implementation (`wonky_sheets/lib/features/sync/`): `SheetsReplica` (the database, spaces,
reservations, dirty marks, space loading), `SheetsChangeJournal` (U11 below), `SheetsWriter`
(`RowChange`s → chunked `transactionForUser`, `columnValues`, `ChangeLog`), `RemotePatch`
(replica rows → model changes), `SyncedWorkbookSession` (the editor's `WorkbookSession`),
`SheetsSyncController` (loop, reservations, sessions) and `SheetsData` (install at sign-in,
`openWorkbookSession`, `createSpreadsheet`). The generic table codec (table name + column map ⇄
generated ORM class, typed ORM calls) is `package:wonky_sync_models/tables.dart`.

### 2.6 Slides (v2)

Slides uses the same engine and the same patterns as Sheets ([Slides 02 §9](wonky_slides/02-data-model.md)):
one deck = one space (`Deck.id` = space UUID = drive item UUID), a per-user replica
`slides_<userId>.db`, a pool of reserved spaces for offline creation
(`drive.registerPresentation`, queued in `PendingDriveOp`), a custom sync endpoint
`slidesSync.sync` (for `onMergeSuccess` → the deck change log), subscriptions as membership, the
pending-change guard, U11-style change journal, recovery export, and the `slides.rows` undo
domain. The generic client pieces (replica, sync controller, writer, journal, undo inverter)
are extracted from `wonky_sheets` into a shared package (`wonky_sync_kit`, 01 §2) so both apps
run the same code.

**Every space kind in every replica.** Because a client syncs every space it is a member of
(§2.1), the Sheets replica would also download decks and the Slides replica spreadsheets once
decks are spaces. The server tables `SpaceSubscription` and `SpaceReservation` gain
`kind: SpaceKind { spreadsheet, deck }` (active set limits per kind), and the recommended fix is
the vendored patch **OS-8** — a per-endpoint space filter
(`offlineSync.sync(…, spaceFilter: …)`, `sheetsSync` passes spreadsheet spaces + the personal
space, `slidesSync` deck spaces + the personal space). It is a first step towards U1. The
options and the interim behavior are the **Open question** of
[Slides 02 §9.2](wonky_slides/02-data-model.md). Drive opens no replica.

## 3. Shell (drive)
Drive listing cache + `PendingDriveOp` queue (rename, move, star, trash, registerSpreadsheet,
(v2) registerPresentation, createDocument) replayed in order on reconnect. (v2) The cache also
keeps the last `StorageUsage` (meter offline). Each app caches the items of its home's kind;
the Drive app caches the last 500 items of any kind plus all pinned items. Drive's upload queue
is in its own local DB (§1.1), not in the key-value store, because it holds file bytes. Both are per user (`u.<userUuid>.` keys) in the
device key-value store (`shared_preferences`; the data is small and needs no queries, so the
shell does not use a separate `shell_<userId>.db`). A queued `createDocument` whose folder is gone
by the time it replays is created in My Drive instead.

## 4. Upstream requirements for `serverpod_offline_sync`

The following are needed to reach the 10M-cell target and better UX. The module is
**vendored** (`third_party/serverpod_offline_sync`, suite [01 §2.3](01-architecture.md)), so
each requirement can be implemented **in our copy first** (as patches `OS-n` in its
`PATCHES.md`) and contributed upstream, rather than waiting for an upstream release. The app is
designed so that each workaround below can be removed independently once the corresponding
patch exists. Priority for in-house patches: U11 (M0), U7 and U6 (M3), U1/U2 (M4–M5), U3/U5
(before raising the cell limit), the rest as needed.

| # | Requirement | Workaround until then |
|---|-------------|----------------------|
| U1 | Client-selectable space subscriptions (partial sync) per device | Server-managed active set via membership; (v2) patch OS-8 filters spaces per sync endpoint (spreadsheets vs decks, §2.6) |
| U2 | Local eviction/purge of a space's rows + metadata | Weekly local purge job |
| U3 | Streaming/bounded outbound capture and inbound merge (no whole-cycle buffering) | Limit cells per spreadsheet (§5) |
| U4 | HLC-indexed change capture (avoid scanning all metadata each cycle) | — (server CPU budget monitored) |
| U5 | Bootstrapping a new replica from a server snapshot (bulk download) | Initial sync via engine (slow for big sheets) |
| U6 | Server push / adaptive cycle (sub-second propagation) | Ephemeral commit hints over presence |
| U7 | Per-change server hooks (row-level) | Synced `ChangeLog` table + `onMergeSuccess` |
| U8 | Cross-space transactions | Ordered single-space transactions |
| U9 | Server-side write validation/rejection | Client-side guards; protected ranges advisory |
| U10 | Rolling schema evolution (additive columns without lock-step) | Batched synced-schema releases |
| U11 | Client API: rows changed in a space since an HLC (`changedRowsSince`) for incremental in-memory models | **Done app-side** (no engine patch): merged changes keep their author's HLC, so a late offline edit has an *old* HLC and "since HLC h" misses it. Instead SQLite triggers on the synced tables and on `crdt_data_rows` (visibility: deletes, revivals, FK projection) append `(space, table, row)` to the local `sheets_row_journal`, whose integer id is a local change sequence; only spaces open on the device (`sheets_journal_space`) are journaled. Sessions re-read the journaled rows after each merge (`SheetsChangeJournal`, `RemotePatch`). |

## 5. Scale limits (staged)

| Stage | Max cells / spreadsheet | Gate to raise |
|-------|-------------------------|---------------|
| M3 (first Sheets release) | 1,000,000 | Perf suite: 1M-cell import, cold sync < 60 s on desktop, < 120 s web/OPFS |
| After U3+U5 | 5,000,000 | Same suite at 5M |
| After U1–U5 | 10,000,000 (Google Sheets parity) | Same suite at 10M |

Limits are server config (`sheets.maxCellsPerSpreadsheet`) and enforced by the client (cell
counters in `SheetStats`) and by server-side imports/MCP writes.
