# 12 · Offline, Sync and Local Storage

| App | Online sync | Offline strategy | Local store |
|-----|-------------|------------------|-------------|
| Write | Server-authoritative OT over a Serverpod stream (Quill Delta) | Local op queue + snapshot cache; rebase (transform) on reconnect | SQLite (`sqlite_async`, same infra as Sheets) — `write_cache_<userId>.db` |
| Sheets | `serverpod_offline_sync` CRDT replication | Native: local SQLite is the primary store | `sheets_<userId>.db` (synced tables + local-only tables) |
| Shell | RPC + `drive.watch` stream | Cached drive listing + queued drive ops | `shell_<userId>.db` (small) |

All local databases are **per user** (file name includes the user's UUID). Signing out keeps them
(encrypted at rest on desktop via OS file protection; on web relies on origin storage);
*Settings › Offline & storage › Clear local data* deletes them (desktop) or clears them (web — DB
deletion is unsupported on web, so tables are truncated and the engine re-syncs).

Web storage: `sqlite_async` with `sqlite3.wasm` + `db_worker.js` in `web/` (versions must match
the `sqlite_async` version). `WebSqlite.connectToRecommended` picks **OPFS** when available,
else IndexedDB (which keeps the whole DB in memory). Large spreadsheets require OPFS; on the
IndexedDB fallback, offline availability is limited (configurable, default 200k cells total) and
the UI shows "Offline storage is limited in this browser". Build web with `--wasm` (as toptap).

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
| `LocalPendingUpload` | `fileUuid` (client-generated UUIDv7), `itemUuid`, `bytes` (blob), `mimeType`, `fileName`, `createdAt`, `attempts`, `lastError` — shared by both apps (images in documents, images over cells, imports) |

Consistency: every write stores one consistent capture of the sync state in one transaction — the
server ops since the last write (or a new snapshot) plus the outbox rows that changed. Outbox ops
are always expressed against `headRevision`, so a reload restores exactly `server document +
outbox`. A failed write makes the next one a full rewrite.

**Uploads and the files service.** `FileEndpoint` (server `platform/files`) accepts a
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
  says "Offline — changes saved on this device"; the shell shows the offline banner.
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
  unsynced local changes (from engine metadata) and calls `SheetsEndpoint.ensureSubscribed(spaces)`
  so a revoked-but-dirty space is re-granted before syncing (prevents stranded edits).
- After eviction, rows stay on disk hidden by the engine; the client runs a local purge of
  hidden spaces' rows weekly (custom maintenance using the engine's space metadata) — tracked as
  an upstream requirement (see §4).

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
`client.createSyncSession(path, persistentUserId: userUuid)` → `syncOnce` → `syncContinuously`
(through a **custom sync endpoint** `sheetsSync.sync` wrapping `session.offlineSync.sync` so the
server gets `onMergeSuccess` for change-log processing) → on stream end, reconnect with backoff.
Sync runs while the app is visible; on web `visibilitychange` hidden → pause after 30 s.
On open failure the DB is deleted and re-synced (it's a replica), **unless** it has unsynced
changes, in which case the user is offered a recovery export first.

## 3. Shell (drive)
Drive listing cache + `PendingDriveOp` queue (rename, move, star, trash, registerSpreadsheet,
createDocument) replayed in order on reconnect. Both are per user (`u.<userUuid>.` keys) in the
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
| U1 | Client-selectable space subscriptions (partial sync) per device | Server-managed active set via membership |
| U2 | Local eviction/purge of a space's rows + metadata | Weekly local purge job |
| U3 | Streaming/bounded outbound capture and inbound merge (no whole-cycle buffering) | Limit cells per spreadsheet (§5) |
| U4 | HLC-indexed change capture (avoid scanning all metadata each cycle) | — (server CPU budget monitored) |
| U5 | Bootstrapping a new replica from a server snapshot (bulk download) | Initial sync via engine (slow for big sheets) |
| U6 | Server push / adaptive cycle (sub-second propagation) | Ephemeral commit hints over presence |
| U7 | Per-change server hooks (row-level) | Synced `ChangeLog` table + `onMergeSuccess` |
| U8 | Cross-space transactions | Ordered single-space transactions |
| U9 | Server-side write validation/rejection | Client-side guards; protected ranges advisory |
| U10 | Rolling schema evolution (additive columns without lock-step) | Batched synced-schema releases |
| U11 | Client API: rows changed in a space since an HLC (`changedRowsSince`) for incremental in-memory models | Small helper in the vendored patch; fallback to viewport-scoped `watch()` |

## 5. Scale limits (staged)

| Stage | Max cells / spreadsheet | Gate to raise |
|-------|-------------------------|---------------|
| M3 (first Sheets release) | 1,000,000 | Perf suite: 1M-cell import, cold sync < 60 s on desktop, < 120 s web/OPFS |
| After U3+U5 | 5,000,000 | Same suite at 5M |
| After U1–U5 | 10,000,000 (Google Sheets parity) | Same suite at 10M |

Limits are server config (`sheets.maxCellsPerSpreadsheet`) and enforced by the client (cell
counters in `SheetStats`) and by server-side imports/MCP writes.
