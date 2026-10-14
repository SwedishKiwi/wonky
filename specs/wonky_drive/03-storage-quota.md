# Drive 03 · Storage Quota (50 MB per user)

Every user has **50 MB** of storage. This spec defines what counts, how usage is accounted on
the server, where the quota is enforced (every byte-adding path), the errors, the UI that shows
it everywhere (meters, banners, dialogs, the Storage page), ownership transfer, trash, and the
backfill for existing users. It is authoritative for anything that counts or blocks storage
(other specs link here).

## 1. Rules at a glance

| Rule | Value |
|------|-------|
| Quota | `wonky.drive.quotaBytesPerUser` (default 52,428,800 = 50 × 1024 × 1024), shown as "50 MB" |
| Who pays | The **owner** of a drive item, for the item's content and the images stored in it — no matter who added them |
| What counts | Content of documents, spreadsheets and presentations (server estimate), uploaded files, images/attachments stored in items, trashed items until purged (§2) |
| What doesn't | Version-history snapshots, thumbnails and previews, exports, import sources, avatars, script bytecode, server caches, local device data |
| Blocked when it doesn't fit | Uploads, image inserts, imports and conversions, copies, creation from non-empty templates, ownership transfer to the user (§7) |
| Never blocked | Editing existing content (typing, cells, slides, formatting), creating blank items, offline sync, version restore, restore from trash, deleting anything |
| Over quota | Possible (content growth, backfill, estimates): a banner everywhere and every blocked path refuses until usage is back under the quota (§6.2) |
| Max single upload | min(available bytes, `wonky.files.maxFileUploadBytes` = 50 MB) |

## 2. What counts

| Source | Counted | Charged to | Measured as | Updated |
|--------|---------|------------|-------------|---------|
| Document content | ✓ | item owner | UTF-8 length of the current Delta JSON (snapshot + ops since, i.e. the document as it is now; the op log is history and is not counted) | With the throttled search-text update of the OT service (≤ every 10 s while edited) and on import/copy/restore |
| Spreadsheet content | ✓ | item owner | `SheetsSizeEstimator`: `sum(pg_column_size(row))` over the space's live rows of every Sheets synced table | By the change-log consumer, at most every 5 min per space (trailing), and after server imports, copies, version restores |
| Presentation content | ✓ | item owner | Same estimator over the Slides synced tables (Slides 02) | Same cadence (Slides change log) |
| Uploaded file (`file` kind) | ✓ | item owner (the uploader) | Exact stored size | At `completeFileUpload` (reserved at `createFileUpload`, §5) |
| Images / attachments in documents, over cells, on slides (`StoredFile.kind == image`) | ✓ | owner of the item they belong to | Exact stored size, summed in `DriveItem.attachmentBytes` | At upload completion (+), when the weekly orphan cleanup deletes an unreferenced image (−) |
| Previous versions of uploaded files (P2) | ✓ (Open question, 02 §9) | item owner | Exact | At replace / version delete |
| Trashed items | ✓ until permanently deleted (30 days) | item owner | As above, shown as *Trash* | — |
| Imported originals kept for reference | — (none are kept today; if a "keep original" option is added it counts as a `file`) | | | |
| Version-history snapshots and op logs | ✗ | | | |
| Thumbnails, file previews (`thumbnail`, `preview`) | ✗ | | | |
| Exports and import sources (expire after 24 h) | ✗ | | | |
| Avatars, script bytecode, assistant history, comments | ✗ | | | |
| Folders | ✗ (0 bytes) | | | |
| Built-in templates | ✗ (not owned by a user); copies made from them count for their owner | | | |

The **counted size of an item** is `DriveItem.sizeBytes + DriveItem.attachmentBytes`. It is
what the list's *File size* column, the details panel and the Storage page show, so the numbers
always add up to the meter.

Estimates are deliberately simple and stable: the same content always gives the same number,
and the numbers only change when content changes. They are labeled "about" nowhere — users see
one number per item.

## 3. Configuration and the usage view

```yaml
# config/<runMode>.yaml (v2)
wonky:
  drive:
    quotaBytesPerUser: 52428800      # WONKY_DRIVE_QUOTA_BYTES_PER_USER
    warnAtPercent: 90                # banner threshold
    maxPendingUploadsPerUser: 100
  files:
    maxFileUploadBytes: 52428800     # cap for one uploaded file (≤ quota)
    maxImageUploadBytes: 20971520    # existing
    maxImportUploadBytes: 104857600  # existing (import sources are temporary)
    uploadsPerHour: 200              # rate limits, suite 13 §6
    uploadBytesPerDay: 524288000
```

A per-user override (`UserStorage.quotaBytesOverride`) exists for operators (set through the
database or a server-admin MCP tool later, P2); there is no UI to buy or request more.

`StorageUsage` (existing model, extended, v2) is returned by `drive.storageUsage()`, pushed on
the `drive.watch` stream as `DriveChange(kind: storageChanged, storage: …)` whenever the
caller's counters change (debounced 1 s), included in the result of every byte-adding endpoint
that returns a view (e.g. `FileUploadStart.storage`), and cached in the shell for offline
display.

```yaml
class: StorageUsage
fields:
  quotaBytes: int
  bytesUsed: int                # counted usage incl. trash (existing field, new meaning: §2 only)
  reservedBytes: int            # pending uploads (§5)
  availableBytes: int           # max(0, quotaBytes - bytesUsed - reservedBytes)
  overQuota: bool               # bytesUsed > quotaBytes
  documentsBytes: int           # non-trashed, incl. their attachments
  spreadsheetsBytes: int
  presentationsBytes: int
  filesBytes: int
  trashBytes: int               # all trashed items
  documents: int                # counts (existing)
  spreadsheets: int
  presentations: int
  files: int
  folders: int
  maxFileUploadBytes: int       # min(availableBytes, config cap)
  calculating: bool             # backfill for this user not finished yet (§9)
```

**Display.** Bytes are shown with binary units labeled KB/MB (as `formatBytes` does today):
one decimal below 100 ("12.3 MB"), none above; "0 bytes", "820 KB". The quota is always "50 MB".
The meter text is "12.3 MB of 50 MB used".

## 4. Accounting model (server)

### 4.1 Tables

```yaml
# platform/storage/user_storage.spy.yaml (new)
### Storage counters of a user (Drive 03). Maintained transactionally by StorageService;
### reconciled nightly from the source rows.
class: UserStorage
table: user_storage
fields:
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  usedBytes: int, default=0          # Σ counted size of owned items (incl. trash)
  reservedBytes: int, default=0      # Σ open reservations
  documentsBytes: int, default=0
  spreadsheetsBytes: int, default=0
  presentationsBytes: int, default=0
  filesBytes: int, default=0
  trashBytes: int, default=0
  quotaBytesOverride: int?           # null = config default
  overQuotaSince: DateTime?          # set/cleared when usedBytes crosses the quota
  reconciledAt: DateTime?            # null until the first reconcile/backfill (§9)
  updatedAt: DateTime
indexes:
  user_storage_user_idx: { fields: userId, unique: true }

# platform/storage/storage_reservation.spy.yaml (new)
### Quota held for an upload that has not completed (Drive 03 §5).
class: StorageReservation
table: storage_reservation
fields:
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  fileUuid: UuidValue                # the StoredFile being uploaded
  itemId: int?, relation(parent=drive_item, onDelete=Cascade)
  bytes: int
  createdAt: DateTime
  expiresAt: DateTime                # createdAt + 24 h
indexes:
  storage_reservation_file_idx: { fields: fileUuid, unique: true }
  storage_reservation_user_idx: { fields: userId }
```

`DriveItem` gets `attachmentBytes` (02 §1.1); `sizeBytes` keeps its column with the meaning
of §2 (content estimate, or the file size for files).

### 4.2 `StorageService` (`wonky_server/lib/src/platform/storage/`)

The only code that changes `user_storage`. Every source change calls it **in the same
database transaction** as the change itself:

| Method | Called by |
|--------|-----------|
| `reserve(session, userId, fileUuid, itemId?, bytes)` → throws `quotaExceeded` | `drive.createFileUpload`, `file.createUpload(kind: image)` |
| `commitReservation(session, fileUuid, actualBytes)` (reserved → used; the item's `sizeBytes`/`attachmentBytes` updated) | `drive.completeFileUpload`, `file.completeUpload` |
| `releaseReservation(session, fileUuid)` | cancel, failure, expiry |
| `checkRoom(session, userId, bytes)` → throws `quotaExceeded` | copies, imports, conversions, template creations, ownership transfer |
| `setItemSize(session, item, sizeBytes)` / `addAttachment(item, ±bytes)` (never throw) | OT size update, `SheetsSizeEstimator`, Slides estimator, orphan cleanup |
| `onTrash(items)`, `onRestore(items)` (move bytes between kind counters and `trashBytes`) | `drive.trash` / `restore` / purge |
| `onDelete(items)` (subtract) | delete forever, trash purge, account deletion |
| `onOwnerChange(item, fromUserId, toUserId)` | ownership transfer (§7.3) |
| `usage(session, userId)` → `StorageUsage` | endpoints, MCP |

Concurrency: the room check and the reservation are one conditional statement, so parallel
uploads can't overshoot:

```sql
UPDATE user_storage
   SET "reservedBytes" = "reservedBytes" + @n, "updatedAt" = now()
 WHERE "userId" = @u
   AND "usedBytes" + "reservedBytes" + @n <= @quota
RETURNING "usedBytes", "reservedBytes";
-- no row → quotaExceeded
```

`checkRoom` takes `SELECT … FOR UPDATE` on the user's row for the rest of the transaction.
Content growth (`setItemSize`) adds unconditionally (`usedBytes = usedBytes + delta`), then sets
or clears `overQuotaSince` and posts `storageChanged` to the owner's drive channel (after
commit).

### 4.3 Reconciliation

`StorageReconcileFutureCall` (nightly, per user in batches of 200; also on demand after a
backfill or by an operator) recomputes every counter from the sources (`drive_item` sizes by
owner, kind and trash state; open reservations; expired reservations are deleted first),
writes the corrected row and logs `storage.drift {userId, field, before, after}` when a counter
was off by more than 1 % or 64 KB. A test asserts that after any sequence of service calls the
reconciled row equals the maintained one.

## 5. Reservations

- `reserve` happens **before** bytes are uploaded (declared size), so a 40 MB upload can't
  start when 30 MB are free. A user can have at most `maxPendingUploadsPerUser` (100) open
  reservations (`limitExceeded` "Too many uploads at once. Wait for some to finish.").
- `commitReservation` uses the **actual** size from storage; if it is larger than reserved and
  no longer fits, the upload fails (`quotaExceeded`) and the bytes are deleted.
- Expired reservations (24 h) are released by `drive.expireUploads` (02 §2).
- `availableBytes` subtracts reservations, so the meter shows uploads in flight as used.

## 6. UI

### 6.1 Storage meter (`StorageMeter`, `wonky_app/lib/src/storage/`)

- In the **bottom section of every home's left menu** (Drive, Write, Sheets, Slides; suite 03
  §3.3), in Settings › Wonky Works › Storage, and at the top of Drive's Storage page (large).
- A 4 px `ShadProgress`-style bar + "12.3 MB of 50 MB used". Color: `primary` below
  `warnAtPercent`, `warning` token from 90 %, `destructive` at ≥ 100 % ("50.4 MB of 50 MB used —
  over quota"). While `calculating`: indeterminate bar + "Calculating storage…".
- Click (or Enter) runs `shell.storage.open` → Drive's Storage page (same tab; cross-app from
  the other homes). Tooltip: "Storage is shared by Wonky Drive, Write, Sheets and Slides."
- Offline: last known value with "(offline)" in the tooltip.

### 6.2 Banners (`StorageBanner`)

Shown below the top bar in homes and below the editor header in editors (one line, `warning` or
`destructive` tinted, with a close ×):

| State | Text | Action | Dismissal |
|-------|------|--------|-----------|
| ≥ 90 % | "You've used 46.1 MB of your 50 MB storage." | *Manage storage* | per device for 7 days |
| Over quota | "You're out of storage. You can keep editing, but you can't upload files, add images, import, or make copies until you free up space." | *Manage storage* | homes: not dismissible; editors: once per day per device |

Editors show the banner only for items the user **owns** (an editor of Anna's document isn't
told about their own quota, but gets the dialog of §6.3 if Anna is full).

### 6.3 *Out of storage* dialog (`QuotaExceededDialog`)

Shown when a byte-adding action is refused (server error `quotaExceeded`, §7.1) or the client
pre-check fails. `ShadDialog.alert`, built with `WonkyDialogSpec` (MCP-operable):

| Variant | Title | Body | Buttons |
|---------|-------|------|---------|
| Own quota | "You're out of storage" | "This needs 12.4 MB, but you have 3.1 MB left of your 50 MB. Free up space in Wonky Drive by deleting files you no longer need and emptying the trash." | **Manage storage** · Close |
| Owner's quota (editor adds an image to someone else's item) | "Anna Berg is out of storage" | "Images added to this document count against the owner's storage. Ask Anna Berg to free up space, or add the image to a document you own." | Close |
| Batch upload | "Not enough storage for all files" | "These 5 files need 62.0 MB, but you have 18.5 MB left. Upload the files that fit, or free up space first." | **Upload the files that fit** · Manage storage · Cancel |
| Ownership transfer (requester) | "Bo Chen doesn't have enough storage" | "Bo Chen needs 8.2 MB free to take ownership of "Q3 deck". Ask them to free up space first." | Close |
| Ownership transfer (new owner accepting) | "You don't have enough storage" | "Taking ownership of "Q3 deck" needs 8.2 MB, but you have 2.0 MB left." | **Manage storage** · Close |
| File too large | "This file is too large" | "Files can be at most 50 MB." (or "…at most 18.5 MB right now, because that's how much storage you have left.") | Close |

Image inserts that fail **after** being placed (uploaded in the background, e.g. offline)
leave the image as a placeholder "Not uploaded — out of storage" with *Retry* and *Remove*
(Write 04 §17, Sheets 08 §10, Slides 03).

### 6.4 Storage page (`/drive/storage`, Drive app)

```
┌ Storage ────────────────────────────────────────────────────────────────────────┐
│ 46.1 MB of 50 MB used                                         [Empty trash]      │
│ ███████████████████████████████████████████████░░░░░  92 %                       │
│ ■ Documents 4.2 MB  ■ Spreadsheets 9.8 MB  ■ Presentations 6.0 MB  ■ Files 18.0 MB│
│ ■ Trash 8.1 MB      □ Free 3.9 MB                                                 │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Free up space                                                                     │
│ ┌──────────────────────┐ ┌──────────────────────────┐ ┌────────────────────────┐ │
│ │ Empty trash           │ │ Large files               │ │ Not opened in 6 months │ │
│ │ Frees 8.1 MB          │ │ 6 files over 1 MB         │ │ 14 files · 7.4 MB      │ │
│ │ [Empty trash]         │ │ [Review]                  │ │ [Review]               │ │
│ └──────────────────────┘ └──────────────────────────┘ └────────────────────────┘ │
├──────────────────────────────────────────────────────────────────────────────────┤
│ Items using storage                       Type: All ▾        Sort: Size ▾        │
│ Name                     Kind          Location        Last opened   Storage  ⋮  │
│ 🎵 interview.m4a         Audio         My Drive        3 months ago  18.0 MB  ⋮  │
│ 📊 Sales 2025            Spreadsheet   Finance         Yesterday      6.1 MB  ⋮  │
│ 🗑 old-scan.pdf (trash)  PDF           Trash           —              4.0 MB  ⋮  │
│ …                                                                                 │
│ What counts? Documents, spreadsheets, presentations, uploaded files and images in │
│ your files, including the trash. Version history, thumbnails and exports don't.   │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- **Usage bar** (stacked, colors `chart1–5` + muted for free; legend with values; screen
  readers get "Documents 4.2 MB, …" as one label). Over quota: the bar is full in `destructive`
  with "over by 0.4 MB".
- **Free up space** cards (shown when relevant): *Empty trash* (if `trashBytes > 0`; confirm
  "Permanently delete 23 items in the trash? This frees 8.1 MB and can't be undone." → 
  `shell.drive.emptyTrash`); *Large files* (owned, ≥ 1 MB; filters the table); *Not opened in 6
  months* (owned, ≥ 256 KB, `lastOpenedAt` older than 180 days or never; filters the table);
  *Duplicate files* (P1: same name + size + MIME); *Old file versions* (P2).
- **Items using storage**: owned items (incl. trashed) sorted by counted size desc, paged 50,
  from `drive.listByStorage(filter, cursor)`; type filter (All, Documents, Spreadsheets,
  Presentations, Files, Trash); multi-select with *Move to trash*, *Delete forever* (trashed
  items only), *Download*; row ⋮ = the normal item menu. Opening a row opens the item.
- The page updates live from `storageChanged` events.

### 6.5 Elsewhere

- **Details panel** (all homes): "Storage used: 6.1 MB" with "Counts against Anna Berg's
  storage" when the viewer isn't the owner; for folders: nothing.
- **List/grid**: the *File size* column shows the counted size; folders "—".
- **Settings › Wonky Works › Storage** (`/settings/storage`, suite 04 §4): meter, breakdown,
  "What counts" text, *Manage storage in Wonky Drive* (→ `/drive/storage`).
- **Upload panel** rows that fail on quota: "Not uploaded — you're out of storage" + *Manage
  storage*.
- **New ▸ From template** on a full account: templates show a tooltip "Not enough storage"
  and are disabled when the template's size doesn't fit (`TemplateView.sizeBytes`, v2).
- **Copy / Make a copy** dialogs: disabled *OK* with "Not enough storage (needs 6.1 MB)".

### 6.6 MCP and AI

`drive.get_storage` returns `StorageUsage` as JSON; every byte-adding tool's result carries
`storage: {used_bytes, quota_bytes, available_bytes}`; refusals are `quota_exceeded` errors
with the details of §7.1 (suite 09 §4). The assistant explains the error to the user and never
deletes or empties the trash to make room on its own (destructive-confirmation rule, suite 10).

## 7. Enforcement

### 7.1 Error

New `WonkyErrorCode.quotaExceeded` (`wonky_server/lib/src/platform/common/`) with
`detailsJson`:

```json
{ "neededBytes": 12998246, "availableBytes": 3250585, "quotaBytes": 52428800,
  "chargedUserId": 42, "chargedUserName": "Anna Berg", "isCaller": false,
  "reason": "upload" }
```

`reason` ∈ `upload`, `image`, `import`, `convert`, `copy`, `template`, `transfer`,
`restoreVersionCopy`. Message: "Not enough storage: this needs 12.4 MB, 3.1 MB is available."
The client maps it to the dialog variants of §6.3 (`QuotaErrorPresenter`, `wonky_app`).

### 7.2 Enforcement points by endpoint

| Path (endpoint / tool) | Bytes checked | Charged to | Behavior |
|------------------------|---------------|------------|----------|
| `drive.createFileUpload` (Drive uploads), MCP `drive.upload_file` / `drive.create_upload` | declared file size | uploader | `reserve`; refuse |
| `file.createUpload(kind: image)` — images in Write, over cells (Sheets), on slides, image-by-URL copies stored by the server | image size | **owner of `itemUuid`** | `reserve` on the owner; refuse (owner variant if caller ≠ owner) |
| `file.createUpload(kind: importSource)` | — (temporary, 24 h) | — | size cap only |
| `drive.import` (server import pipeline), `drive.convertFile`, MCP `drive.import`/`drive.convert_file` | source file size before work; real content size after | importer | `checkRoom` twice; refuse; no item is created on refusal |
| Client-side imports (Write documents, Sheets ≤ 5 MB XLSX/CSV, app import routes of 02 §7.2) | file size | importer | client pre-check against `availableBytes` + `drive.checkRoom(bytes)` RPC before creating; offline imports are not blocked (content arrives through sync) |
| `drive.copy`, *Make a copy* in editors, MCP `drive.copy` | counted size of the source (content + attachments) | the copier (new owner) | `checkRoom`; refuse |
| `versions` *Make a copy* of a version | version content size | caller | `checkRoom`; refuse |
| `drive.createDocument/createSpreadsheet/createPresentation` with `templateUuid` or initial content; MCP `drive.create_*` with content | template/content size | creator | `checkRoom`; refuse. Blank items: 0 bytes, always allowed |
| `drive.registerSpreadsheet` / `registerPresentation` (offline-first creations) | 0 | owner | never refused (content arrives via sync) |
| `sharing.transferOwnership` (request and accept) | counted size of the item | new owner | `checkRoom` at request (pre-check) and at accept; refuse |
| `drive.restore` (from trash) | 0 (trash already counts) | — | never refused |
| `versions.restore` | content change = an edit | owner | never refused |
| Write OT ops, Sheets/Slides sync, text edits through MCP/AI/scripts | growth via size estimates | owner | **never refused**; may lead to over quota |
| `drive.setThumbnail`, previews, exports, avatars | not counted | — | existing size caps only |

`drive.checkRoom(int bytes, UuidValue? itemUuid)` (new, cheap, read-only) lets clients
pre-check paths where the bytes don't go through an upload (client-side imports, large pastes
of images in a batch); it never reserves.

### 7.3 Ownership transfer

- `sharing.transferOwnership(itemUuid, newOwnerUserId)` checks the new owner's room for the
  item's counted size and refuses up front ("Bo Chen doesn't have enough storage").
- Acceptance (the new owner) runs the check again inside the transfer transaction; on success
  `onOwnerChange` moves the counted size between the two users' counters and re-charges the
  item's images (`attachmentBytes` move with the item). Transferring a folder transfers only
  the folder (0 bytes); its children keep their owners (suite 06 §4).
- Deleting an account with *transfer files* first runs the same checks per item and lists the
  items that didn't fit (they stay with the deleted user's choice: delete or skip).

### 7.4 Trash

- Trashing moves an item's bytes from its kind counter to `trashBytes`; usage doesn't change.
- Restoring moves them back; never blocked.
- *Delete forever*, *Empty trash* and the 30-day purge subtract the bytes in the same
  transaction as the row delete; the meter updates through `storageChanged`.
- The Storage page and the over-quota banner both point at *Empty trash* first when trash is
  ≥ 10 % of usage.

## 8. Edge cases

- **Editors adding images to someone else's item** charge the owner (§2). The over-quota
  owner variant of the dialog explains it; the editor's own quota is unaffected.
- **Shared folders**: items created or uploaded into someone else's folder belong to (and are
  charged to) their creator, as today; moving an item doesn't change its owner.
- **Offline growth**: spreadsheets and presentations grow through sync and documents through
  the OT queue; none of it can be refused. Images queued offline are refused on upload (§6.3)
  and stay as placeholders.
- **Estimate jumps**: a spreadsheet's estimate is refreshed at most every 5 minutes; usage may
  briefly lag. Byte-adding checks always use the stored counters (no on-demand estimation in
  the request path).
- **Account deletion** removes the user's items (and `user_storage` by cascade).
- **Templates published by users** (`setTemplate`) count for their owner like any item; copies
  count for the copier.

## 9. Migration and backfill for existing users

1. **Schema migration** (one Serverpod migration, M8): `user_storage`, `storage_reservation`,
   the new `DriveItem` columns (02 §1.1), `StoredFileKind`/`DriveItemKind`/`FileCategory`
   enum values. All additive; no data rewritten in `migration.sql`.
2. **Backfill** (`StorageBackfillFutureCall`, scheduled once at server start when
   `user_storage` has no rows or the stored backfill version is older; idempotent, resumable,
   100 items per batch, under a cluster advisory lock, suite 13 §4):
   - documents: recompute `sizeBytes` from the current content (§2);
   - spreadsheets (and presentations): run `SheetsSizeEstimator` per space;
   - `attachmentBytes`: sum of ready `image` StoredFiles per `itemId`;
   - then a full reconcile (§4.3) per user, setting `reconciledAt`.
   While a user's row has `reconciledAt == null`, `StorageUsage.calculating` is true, the meter
   shows "Calculating storage…" and enforcement **fails open** (uploads are allowed; the
   reconcile catches up). Expected duration: minutes (the backfill reads each space once).
3. **Users over 50 MB after the backfill** keep all their data. They get the over-quota
   banner and one in-app notification (`NotificationKind.storage`, new): "Wonky Works now
   includes 50 MB of storage per person. You're using 73.2 MB — you can keep editing, but free
   up space to upload or copy files again. [Manage storage]". No email.
4. **Release note**: `StorageUsage.bytesUsed` changes meaning (it previously added every
   `StoredFile` the user uploaded, including thumbnails and version snapshots).

**Open question (for review):** grace for existing users who are over the quota after the
backfill (e.g. quota = their usage rounded up, for 90 days)? *Recommendation:* no — the
over-quota state is non-destructive and blocks only new bytes; a temporary higher quota adds a
second rule users must understand.

**Open question (for review):** D3 lists "restore of trashed items" as an enforcement point,
but trashed items already count, so a restore adds no bytes. *Recommendation:* never block
restores from trash (§7.2); block only paths that add bytes.

## 10. Acceptance criteria

- **AC-D3.1** With 49 MB used, uploading a 2 MB file fails before any byte is sent; the dialog
  shows "needs 2.0 MB … 1.0 MB left"; the meter shows the warning color (98 %).
- **AC-D3.2** Two parallel 30 MB uploads with 50 MB free: exactly one succeeds; the other fails
  with `quotaExceeded`; `reservedBytes` returns to 0.
- **AC-D3.3** An editor inserting a 3 MB image into a document whose owner has 1 MB left gets
  the *owner* dialog; the owner's usage is unchanged.
- **AC-D3.4** Trashing an 8 MB file moves 8 MB to *Trash* (usage unchanged); *Empty trash*
  frees it; the meter in the open Write home updates within 2 s.
- **AC-D3.5** Over quota, typing in a document, editing cells and slides keeps working; *Make
  a copy* and image inserts are refused; deleting enough files clears the banner live.
- **AC-D3.6** Transfer of a 10 MB spreadsheet to a user with 5 MB left is refused at request
  time; after they free space, acceptance succeeds and both meters update.
- **AC-D3.7** Reconcile after a randomized sequence of 1,000 service calls (property test)
  produces the same counters as the incremental maintenance.
- **AC-D3.8** Backfill on a copy of production data completes, sets `reconciledAt` for every
  user and leaves the server responsive (no request blocked > 1 s by it).
