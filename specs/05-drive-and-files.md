# 05 · Wonky Drive — Files, Folders, Home Screen

Wonky Drive is the shared file system for both apps. It is implemented once in
`packages/wonky_app` (UI) and `wonky_server/lib/src/platform/drive/` (server). Each app
shows the same drive, **filtered by default to its own file type** (Write home shows documents,
Sheets home shows spreadsheets), with a toggle to show everything. Opening an item of the
*other* type navigates to the other app's URL (same origin when deployed together; see
architecture spec). This is a full-page navigation **within the same browser tab/window** —
never a new window.

## 1. Data model (server, Postgres — not synced)

```yaml
# drive_item.spy.yaml
class: DriveItem
table: drive_item
fields:
  uuid: UuidValue, defaultPersist=random_v7   # public id used in URLs: /d/<uuid>, /s/<uuid>
  kind: DriveItemKind                          # enum: folder, document, spreadsheet
  name: String
  ownerId: int, relation(parent=user_profile, onDelete=Restrict)
  parentId: int?, relation(parent=drive_item, onDelete=SetNull)   # null = owner's root
  description: String?
  # For documents: document_id; for spreadsheets: the offline-sync space UUID (= Spreadsheet.id)
  contentRef: UuidValue?
  thumbnailFileId: UuidValue?
  sizeBytes: int, default=0
  createdAt: DateTime
  createdById: int
  modifiedAt: DateTime                         # last content modification (any user)
  modifiedById: int?
  trashedAt: DateTime?
  trashedById: int?
  templateOf: TemplateCategory?                # non-null = this item is a template in the gallery
indexes:
  drive_item_uuid_idx: { fields: uuid, unique: true }
  drive_item_parent_idx: { fields: parentId }
  drive_item_owner_idx: { fields: ownerId, trashedAt }
  drive_item_content_idx: { fields: contentRef }
```

```yaml
# drive_item_user_state.spy.yaml — per-user view state
class: DriveItemUserState
table: drive_item_user_state
fields:
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  starred: bool, default=false
  lastOpenedAt: DateTime?
  lastEditedAt: DateTime?
  pinnedOffline: bool, default=false          # keep available offline
  shortcutParentId: int?                      # "Add shortcut to My Drive" for shared items
indexes:
  drive_item_user_state_idx: { fields: itemId, userId, unique: true }
  drive_item_user_recent_idx: { fields: userId, lastOpenedAt }
```

Sharing tables (`DriveItemPermission`, `ShareLink`) are defined in
[06-sharing-and-permissions.md](06-sharing-and-permissions.md).

Full-text search uses Postgres `to_tsvector('simple', …)`/prefix `to_tsquery` computed at query
time (plus `ILIKE` on the name) over `name`, `description` and an extracted `searchText` field
updated asynchronously (document plain text, throttled; spreadsheet sheet names + first 10k cell
values), restricted to items the caller can access. A GIN index via a hand-written migration step
is a later optimization (it must then also be added to `definition.sql`).

## 2. Endpoints — `DriveEndpoint` (`drive`)

| Method | Description |
|--------|-------------|
| `list(folderUuid?, filter, sort, cursor, limit)` | Children of a folder or a virtual view. `filter`: `kind` set, `ownedByMe`, `sharedWithMe`, `starred`, `recent`, `trash`. Returns `DriveItemView` (item + effective role + user state + owner summary). |
| `get(uuid)` | Single item view (404 if no access). |
| `path(uuid)` | Breadcrumb ancestors visible to the user. |
| `search(query, filters, cursor)` | Full-text + filters (type, owner, modified range, shared). |
| `createFolder(parentUuid?, name)` | |
| `createDocument(parentUuid?, name, templateUuid?, initialMarkdown?)` | Creates `DriveItem` + `Document` (see Write data model). |
| `registerSpreadsheet(spaceUuid, parentUuid?, name)` | Called after a spreadsheet was created locally in a reserved sync space (works offline-first; idempotent). |
| `createSpreadsheet(parentUuid?, name, templateUuid?)` | Online convenience used by MCP/headless; creates space + rows server-side. |
| `rename(uuid, name)` · `move(uuids, newParentUuid?)` · `copy(uuid, newName, parentUuid?, copyComments, copySharing)` | |
| `setStarred(uuid, starred)` · `setPinnedOffline(uuid, pinned)` | |
| `trash(uuids)` · `restore(uuids)` · `deletePermanently(uuids)` · `emptyTrash()` | Trash auto-purges after 30 days (FutureCall `drive.purgeTrash`, daily). |
| `watch()` | **Stream** of `DriveChange` events for items visible to the user (created/renamed/moved/trashed/shared/modified) so lists update live. |
| `listTemplates(kind)` | Template gallery: `TemplateView`s of the built-in templates (compiled into the server, stable UUIDv5 ids `wonky-template:<key>`) plus items published with `setTemplate(uuid, category)`. A `TemplateView` carries `themeKey` (the built-in Write theme a document template creates its document with) and `previewStyle` (`TemplatePreviewStyle`: `paper`/`text`/`heading`/`accent` colors for light and dark, `banner`, `centeredHeadings`, `uppercaseHeadings`, `fontCategory` serif/sans/mono; null = neutral page) for the card's miniature page (§3.1). |
| `import(uploadId, kind, options: DriveImportOptions)` | Server-side import pipeline (see each app's import spec) returning the new item. |
| `storageUsage()` | Bytes used by owned items. |
| `setThumbnail(uuid, uploadedFileUuid)` | Clients render thumbnails (first page / visible grid area, light theme, 400×300 PNG) at most every 10 min while editing and upload them; Editors+ only. |

Server rules:
- Moving into a folder requires Editor on the target folder and Owner/Editor on the item.
- Cycles are rejected (`DriveException.cycle`).
- Names: 1–255 chars, trimmed, no `/`; duplicates allowed (like Google Drive).
- Trashing a folder trashes descendants (same `trashedAt`); restore restores them together.

## 3. Home screen (each app)

Single-window page at `/` (Write) or `/` (Sheets) — layout:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [≡] [◆] Write    [ 🔍 Search in Drive…                        ]  [◐] [🔔] [👤] │  ← TopBar
├───────────────┬──────────────────────────────────────────────────────────────┤
│ + New         │  Start a new document                                         │
│               │  [Blank] [Meeting notes] [Project brief] [Letter] [More ▸]    │ ← Template strip
│ ▸ Home        │──────────────────────────────────────────────────────────────│
│ ▸ My Drive    │  Recent ▾   Owned by anyone ▾   Type: Documents ▾   [▦|☰] [⇅] │ ← Filter bar
│ ▸ Shared      │                                                               │
│ ▸ Starred     │  Name                 Owner      Last modified     ⋮          │
│ ▸ Offline     │  📄 Q3 planning       me         10:42             ⋮          │
│ ▸ Trash       │  📄 Notes             Anna B.    Yesterday         ⋮          │
│               │  …                                                            │
│ Storage 12 MB │                                                               │
└───────────────┴──────────────────────────────────────────────────────────────┘
```

### 3.1 Components
- **TopBar** (shared `WonkyTopBar`): hamburger (collapses sidebar), app logo (the product icon,
  suite 02 §5) + short name ("Write" / "Sheets"; click → home), drive search field (while the
  sidebar is open it starts where the page content starts — sidebar 256 px + the 20 px content
  inset, `WonkyTopBar.contentStart` — so it lines up with "Start a new document" / "Home") with
  suggestions dropdown (recent
  searches, matching items with their kind icons, "Search for '…'" row, filter chips: type,
  owner, modified), app theme toggle (light/dark/system cycle), notifications, account avatar
  menu (name, email, Settings, switch app → *Open Wonky Sheets/Write* with that product's icon,
  Sign out). There is no help button (Help lives in the editor's Help menu; there is no help
  center).
- **Sidebar** (`DriveSidebar`): *New* button (12 px left of the +; dropdown: New document / New
  spreadsheet / New folder / Upload file… / From template…), nav
  items (Home, My Drive, Shared with me, Starred, Offline,
  Trash), collapsible folder tree under My Drive (lazy-loaded, drag-and-drop target), storage
  usage footer (no separator above it).
- **Template strip**: collapsible ("Hide templates"), 20 px horizontal padding (matching the list
  header), horizontal list of `TemplateCard`s; *More*
  opens the template gallery page (`/templates`) with categories (Personal, Work, Education,
  Project management, Finance for Sheets…). A card draws a **miniature page** in the template's
  `previewStyle` (paper, text, heading and accent colors for the current app theme; accent
  banner, centered or uppercase headings, serif/sans/mono character), clipped to the card (no
  scroll view, so no scrollbar on hover). Each built-in document template creates its document
  with its own built-in Write theme and sample content: Meeting notes → *modern-sans* (banner),
  Project brief → *technical*, Letter → *classic-serif* (centered letterhead), Weekly report →
  *newsletter* (accent headings), Lecture notes → *academic-apa* (centered), To-do list →
  *minimal-mono*, Recipe → *wonky-default* (banner), Story draft → *manuscript* (centered
  uppercase). Spreadsheet templates have an accent color for their card.
- **Filter bar**: view selector (Recent/Last opened by me/Last modified by me/Last modified),
  owner filter, type filter (Documents, Spreadsheets, Folders, All), grid/list toggle, sort menu
  (Name, Last modified, Last opened by me, Size; asc/desc), folders-on-top toggle.
- **Item list** (`DriveItemList`, list mode): columns Name (kind icon, name, shared badge, star,
  offline badge), Owner (avatar+name / "me"), Last modified (relative), File size, row ⋮ menu.
  Grid mode: `DriveItemCard` with thumbnail preview, name, kind icon, ⋮ menu. Kind icons are
  `DriveKindIcon` (suite 02 §5: plain glyphs in the kind colors), also on the drag chip.
  Virtualized, infinite scroll, sticky "Today / Yesterday / Earlier this week / Earlier"
  group headers in Recent view.
- **Selection**: click selects, Mod/Shift-click multi-select, rubber-band selection in grid view,
  Mod+A selects all; a **selection action bar** replaces the filter bar (Share, Move, Copy,
  Download/Export, Star, Rename (single), Trash, Clear). Its ⋮ menu holds the remaining item
  actions only — it does not repeat the bar's icon actions (`itemMenuEntries(exclude:)`).
- **Context menu** (right-click / ⋮): Open, Share,
  Copy link, Rename, Move to…, Add shortcut, Star/Unstar, Make available offline, Make a copy,
  Download as ▸ (formats), Version history, Details, Move to trash. In Trash: Restore, Delete
  forever.
- **Details panel** (toggle `i`): right side panel (`WonkySplitView` with `rail: false`: a close
  button, no icon rail; suite 02 §4.5) with thumbnail (or the kind icon), type, owner, location,
  sharing summary, created/modified/opened, description (editable), activity feed (who did
  what, from server activity log).
- **Drag and drop**: items onto folders (sidebar tree or list) moves them (undoable); files
  from the OS onto the list uploads/imports (`.md/.txt/.html/.docx/.odt/.rtf` → Write;
  `.xlsx/.xls/.ods/.csv/.tsv` → Sheets) with an upload progress toast list (bottom-right).
- **Empty states**: illustrated (light/dark variants) per view ("No starred files yet").

### 3.2 Dialogs
- **Rename** (`ShadDialog` with input, Enter to save).
- **Move to…**: folder browser with breadcrumb, create-new-folder inline, disabled targets where
  user lacks permission.
- **Make a copy**: name, folder, checkboxes "Copy comments", "Share with the same people".
- **Delete forever**: confirm with count.
- **Upload/import options**: for CSV (delimiter, encoding, header row, convert numbers/dates),
  for XLSX (import all sheets / selected sheets), for DOCX (mapping notice: "Formatting not
  supported in Markdown will be removed").

### 3.3 Keyboard
`/` focus search · `Enter` open · `F2`/`N` rename · `Del` trash · `S` star · `Mod+Alt+N` new
(app's default type) · `Shift+F` new folder · arrows navigate · `.` share · `i` details.
All via commands (`shell.drive.*`).

## 4. Offline behavior

- The drive list is cached locally (last 500 items + all pinned) for offline browsing. Offline,
  "New spreadsheet" works (reserved space; registered later). "New document" works offline
  (client generates `documentId` UUIDv7; registration queued; see offline spec).
- Items not available offline are dimmed with a tooltip when offline.
- Pending drive operations (rename/move/star/trash) are queued and replayed in order; conflicts
  resolve server-side by "last write wins" per field with a toast if the item no longer exists.

## 5. Activity log (shared)

```yaml
class: ActivityEvent
table: activity_event
fields:
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  actorId: int?
  actorKind: ActorKind        # enum: user, mcp, ai, script, system
  type: ActivityType          # enum: created, renamed, moved, edited, commented, shared,
                              #   unshared, restoredVersion, trashed, restored, exported
  summary: String             # JSON payload for rendering
  at: DateTime
indexes:
  activity_item_idx: { fields: itemId, at }
```

Edits are aggregated: at most one `edited` event per (user, item) per 10-minute window.
