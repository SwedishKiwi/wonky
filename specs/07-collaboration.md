# 07 · Collaboration: Presence, Comments, Mentions, Notifications, Version History

This spec defines the **shared** collaboration framework. App specs define how each feature
anchors to content (text ranges vs. cells) and how versions are captured.

## 1. Presence

### 1.1 Protocol
Presence is **ephemeral** (never stored in Postgres). It runs over a Serverpod streaming method:

```
PresenceEndpoint.join(String itemUuid, Stream<PresenceUpdate> updates) → Stream<PresenceEvent>
```

- Client sends `PresenceUpdate { state: active|idle|away, cursor: PresenceCursor?, viewport: … }`
  on change (throttled to 10/s; cursor updates coalesced).
- Server keeps a per-item roster in memory and broadcasts via `session.messages` channel
  `presence:<itemUuid>` (global scope with Redis when running multiple instances; local
  otherwise). Each server instance relays relevant events to its connected clients.
- `PresenceEvent` variants (sealed base model): `Roster(List<Participant>)` (on join),
  `Joined(Participant)`, `Left(sessionId)`, `Updated(sessionId, cursor, state)`.
- `Participant { sessionId, userId, displayName, avatarUrl, colorIndex, role, actorKind
  (user|mcp|ai), state }`. The same user in two tabs appears as two sessions, grouped in UI.
- Idle after 60 s without input, away when the tab/window is hidden. Sessions are dropped 30 s
  after the stream dies.
- **MCP/AI presence**: when an agent edits headlessly, the server injects a transient
  participant (`actorKind: mcp`, name "Claude via MCP (Anna)") so humans see agent activity.

`PresenceCursor` is app-specific JSON:
- Write: **not sent here** — Write cursors travel on the document stream (`CursorUpdate` /
  `RemoteCursor`, Write 03 §1) because they must be ordered with ops; the presence stream only
  carries the roster/state for Write.
- Sheets: `{sheetId, activeCell: {rowId, colId}, ranges: [{r1,c1,r2,c2 as ids}], editing: bool}`.

### 1.2 UI
- `PresenceAvatarStack` in header; follow mode: click an avatar → scroll to their cursor; long-
  press/⋮ → *Follow* (viewport tracks theirs until you scroll).
- Remote cursors/selections drawn with presence colors; name flag on hover or recent activity.
- Join/leave toasts are **off** by default (setting), screen-reader announcements on.

## 2. Comments

### 2.1 Model (server, Postgres; shared by both apps)

```yaml
class: CommentThread
table: comment_thread
fields:
  uuid: UuidValue, defaultPersist=random_v7
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  anchorKind: CommentAnchorKind     # enum: textRange (Write), cell (Sheets), range (Sheets), document
  anchorJson: String                # app-specific anchor (see app specs)
  quotedText: String?               # snapshot of anchored text/cell value at creation
  status: CommentStatus             # enum: open, resolved, orphaned (anchor deleted)
  createdById: int
  createdAt: DateTime
  resolvedById: int?
  resolvedAt: DateTime?
  assigneeId: int?                  # "assign to" via @mention + checkbox
  statusBeforeOrphan: CommentStatus?  # restored if the anchor comes back (undo/revive)
  orphanReasonJson: String?         # e.g. {"kind":"rowDeleted","rowId":…}
indexes:
  comment_thread_item_idx: { fields: itemId, status }
  comment_thread_uuid_idx: { fields: uuid, unique: true }

class: Comment
table: comment
fields:
  threadId: int, relation(parent=comment_thread, onDelete=Cascade)
  authorId: int
  authorKind: ActorKind
  body: String                      # Markdown (inline subset: bold, italic, code, links, mentions)
  mentions: List<int>
  reactions: String                 # JSON {emoji: [userId]}
  createdAt: DateTime
  editedAt: DateTime?
  deletedAt: DateTime?              # soft delete → "Comment deleted"
  systemEvent: CommentSystemEvent?  # enum: resolved, reopened, assigned, suggestionAccepted,
                                    #   suggestionRejected, suggestionWithdrawn,
                                    #   suggestionSuperseded, suggestionReopened
```

### 2.2 Endpoints — `CommentEndpoint` (`comment`)
`listThreads(itemUuid, filter)`, `createThread(threadUuid, itemUuid, anchor, body, mentions,
assigneeId?)` (client-supplied `threadUuid`, idempotent — enables offline creation via a queued
call),
`reply(threadUuid, body, mentions)`, `edit(commentId, body)`, `delete(commentId)`,
`resolve(threadUuid)`, `reopen(threadUuid)`, `react(commentId, emoji)`,
`watch(itemUuid) → Stream<CommentEvent>` (live updates), `updateAnchor(threadUuid, anchor)`
(used by Sheets when cell ids change; Write anchors live in the Delta, see Write spec).

Role rules: Commenter+ can create/reply/react/resolve; authors edit/delete their own comments;
Editors+ can delete any thread. Viewers see comments only if the owner allows it (share setting).

### 2.3 UI (shared widgets in `wonky_app`, anchoring per app)
- **Margin threads** (Write) / **cell indicator** triangle (Sheets) for anchors.
- **Comment card**: avatar, name, relative time, body (Markdown), reactions, ⋮ (Edit, Delete,
  Link to comment, Mark unread), reply box, *Resolve* ✓ button. Active thread expands and
  aligns next to its anchor.
- **New comment**: `Mod+Alt+M` with selection → composer card with mention autocomplete (`@`),
  *Assign to* checkbox when a mention exists, *Comment*/*Cancel*.
- **Comments panel** (side panel): filters (All / Open / Resolved / For you), search, sort
  (position / date); each thread links to its anchor; resolved threads collapsed.
- Notification bell? No — notifications are in the account menu and email (see §4).
- All comment actions are commands (`shell.comments.*`) and undoable (create → delete, etc.).

## 3. Mentions
- `@` triggers user autocomplete: users with access first, then other users matching email
  (shows "Will be given access?" prompt: *Share & mention* (as Commenter/Viewer) or *Mention
  without sharing*).
- Mentioning in a comment notifies the user; in Write documents, `@` in body text inserts a
  **link** to the user (rendered as a chip; exported as Markdown link `[@Name](mailto:…)`).

## 4. Notifications

```yaml
class: UserNotification     # named so it does not clash with Flutter's Notification
table: notification
fields:
  userId: int, relation(parent=user_profile, onDelete=Cascade)
  kind: NotificationKind   # mention, reply, assigned, shared, accessRequest, suggestion, scriptFailure
  itemId: int?
  payload: String          # JSON
  createdAt: DateTime
  readAt: DateTime?
```

- In-app: account menu shows unread count; **Notifications popover** list with mark-all-read.
- Live via `NotificationEndpoint.watch()` stream.
- Email (optional via settings): sent through the Serverpod email provider used for auth,
  batched digest every 15 min (FutureCall).

## 5. Version history (shared framework)

Each app implements a `VersionProvider` (server) that can **capture**, **materialize** and
**restore** a version. Shared models:

```yaml
class: ItemVersion
table: item_version
fields:
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  kind: VersionKind          # auto, named, restorePoint (created automatically before a restore)
  name: String?
  createdAt: DateTime
  authors: List<int>         # users who contributed since previous version
  storageKind: VersionStorage # writeRevision | snapshotFile
  revision: int?             # Write: op-log revision this version represents
  snapshotFileId: UuidValue? # Sheets: compressed snapshot in cloud storage
  sizeBytes: int
indexes:
  item_version_item_idx: { fields: itemId, createdAt }
```

Capture policy (both apps): an `auto` version after ≥ 5 min of inactivity following edits, at
most one per 30 min of continuous editing, plus on explicit "Name current version". Auto versions
are thinned over time (keep all for 7 days, then hourly for 30 days, then daily). Named
versions are never thinned.

Access: **Editors and Owners** can view version history, name versions and restore;
Commenters/Viewers cannot (as in Google Docs). *Make a copy* from a version requires Editor+.

UI (full-screen route `/…/history`):
- Left: read-only rendering of the selected version with **changes highlighted** (Write:
  insertions/deletions colored per author; Sheets: changed cells outlined per author) and a
  "Show changes" toggle.
- Right panel: versions list grouped by date (expandable groups of auto versions), each with
  name/time/author avatars; ⋮ → *Name this version*, *Restore this version*, *Make a copy*,
  *Download as…*. Filter *Only named versions*.
- Top bar: back arrow ("Back to editing"), current version title, *Restore this version* button.
- Restore creates a `restorePoint` of the current state, then applies the version as a normal
  forward edit (collaborators see it live; it is one undo step for the restoring user).

## 6. Activity dashboard
*Tools › Activity dashboard* dialog: viewers list (who opened, when — only for Editors+ and only
for users in the same org/share set), view trend chart, comment trend, privacy setting toggle
"Show my view history".
