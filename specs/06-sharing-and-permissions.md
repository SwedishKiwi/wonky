# 06 · Sharing and Permissions

## 1. Roles

| Role | Read | Comment | Suggest (Write) | Edit content | Share | Manage (rename, move, trash, version restore) | Transfer ownership / delete forever |
|------|------|---------|-----------------|--------------|-------|-----------------------------------------------|--------------------------------------|
| **Owner** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Editor** | ✓ | ✓ | ✓ | ✓ | ✓ (unless owner disabled "Editors can share") | ✓ | — |
| **Commenter** | ✓ | ✓ | ✓ | — | — | — | — |
| **Viewer** | ✓ | — (can see comments if allowed) | — | — | — | — | — |

`enum Role { viewer, commenter, editor, owner }` (ordered; comparisons with `>=`) lives in
`wonky_core`.

Additional per-item settings (Owner only, in Share dialog ⚙):
- *Editors can change permissions and share* (default on).
- *Viewers and commenters can see the option to download, print and copy* (default on).
- *Viewers can see comments* (default off).

## 2. Data model (server)

```yaml
class: DriveItemPermission
table: drive_item_permission
fields:
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  userId: int?, relation(parent=user_profile, onDelete=Cascade)   # null when pending invite
  invitedEmail: String?            # for users without an account yet; converted on sign-up
  role: Role
  inheritedFromId: int?            # folder item the grant was inherited from (null = direct)
  grantedById: int
  grantedAt: DateTime
  expiresAt: DateTime?             # optional expiring access (Editors+ can set for others)
indexes:
  perm_item_user_idx: { fields: itemId, userId, inheritedFromId, unique: true }
  perm_user_idx: { fields: userId }

class: ShareLink
table: share_link
fields:
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  token: String                    # 22-char random url-safe
  role: Role?                      # null = link sharing off ("Restricted")
  createdById: int
  createdAt: DateTime
indexes:
  share_link_item_idx: { fields: itemId, unique: true }
  share_link_token_idx: { fields: token, unique: true }

class: AccessRequest
table: access_request
fields:
  itemId: int, relation(parent=drive_item, onDelete=Cascade)
  requesterId: int
  requestedRole: Role
  message: String?
  createdAt: DateTime
  handledAt: DateTime?
  outcome: AccessRequestOutcome?   # approved, denied
```

Plus item settings columns on `DriveItem`: `editorsCanShare: bool`, `nonEditorsCanExport: bool`,
`viewersSeeComments: bool`.

### 2.1 Folder inheritance
Sharing a folder grants the role on every descendant (materialized `DriveItemPermission` rows with
`inheritedFromId`), maintained by `AccessService` on share/unshare/move. Effective role =
max(direct grants, inherited grants, link role if the user has opened via link, owner).
Moving an item out of a shared folder removes inherited grants from that folder.

### 2.2 Link sharing
"Anyone with the link" + role. When a signed-in user opens `/d/<uuid>` (or `/invite/<token>`)
and the item has link sharing, the server records a `DriveItemUserState` (so it appears in
"Shared with me" after first open) and treats them as having the link role. Anonymous (signed
out) access is **not** supported in v1 — users must sign in.

## 3. Enforcement

- **Single source of truth**: `AccessService.effectiveRole(session, userId, itemId)` (cached per
  session; invalidated via `session.messages` channel `acl:<itemId>`).
- **Write**: every document endpoint/stream checks role on connect and on every submitted op
  (ops are validated by kind: commenters may only submit `comment`-attribute or
  suggestion-attribute ops — see Write sync spec). When a role changes, the server pushes a
  `RoleChanged` event on the document stream; downgrade to viewer closes the editing channel.
- **Sheets**: offline-sync membership enforces read/write at the sync layer.
  `AccessService` **mirrors** effective roles into the space membership of the spreadsheet's
  space (`session.offlineSync.spaces.grant/revoke`), combined with the active-set subscription
  policy (see [12-offline-and-sync.md](12-offline-and-sync.md) §3.3):
  | Effective role | Space role |
  |----------------|------------|
  | Owner, Editor | `readWrite` |
  | Commenter, Viewer | `readOnly` |
  Comments for Sheets live in Postgres (comment endpoints), not in the space, so Commenters
  don't need write access to the space.
- **Protected ranges/sheets (Sheets)** are an *advisory* layer enforced in the client and in
  server-side writes (MCP/scripts): the sync engine cannot reject individual writes, so a
  modified client could bypass them. This limitation is documented in the UI ("Protection
  prevents accidental edits by collaborators").
- **MCP / AI / scripts** go through the same `AccessService`.

## 4. Endpoints — `SharingEndpoint` (`sharing`)

`getSharing(itemUuid)` → owner, permissions (with user summaries), link, settings, pending
requests; `share(itemUuid, emails, role, notify, message, expiresAt?)`;
`updateRole(itemUuid, userId, role)`; `remove(itemUuid, userId)`;
`transferOwnership(itemUuid, newOwnerUserId)` (new owner must accept → notification; previous
owner becomes Editor); `setLink(itemUuid, role?)`; `rotateLink(itemUuid)`;
`updateSettings(itemUuid, settings)`; `requestAccess(itemUuid, role, message)`;
`handleAccessRequest(requestId, approve, role?)`; `resolveInvite(token)` → item uuid + role.

Sharing changes are **not undoable**; destructive ones (remove, transfer) confirm.

## 5. Share dialog (shared UI, `wonky_app`)

```
┌ Share "Q3 planning" ─────────────────────────────────── ⚙  ? ┐
│ [ Add people by name or email…                    ] [Editor ▾]│
│ ── People with access ─────────────────────────────────────── │
│ (A) Anna Berg (you)        anna@…                      Owner  │
│ (B) Bo Chen                bo@…                     [Editor ▾]│
│ (C) carl@… (pending)                                [Viewer ▾]│
│ ── General access ─────────────────────────────────────────── │
│ 🔒 [Restricted ▾]  Only people with access can open            │
│    (or 🌐 Anyone with the link [Viewer ▾])                     │
│ [🔗 Copy link]                                         [Done] │
└───────────────────────────────────────────────────────────────┘
```

- Adding people expands to a composer: chips for each recipient (autocomplete from
  `user.searchUsers`), role select, *Notify people* checkbox, message textarea, *Send*.
- Role dropdown per person: Viewer, Commenter, Editor, separator, *Transfer ownership*,
  *Add expiration*, *Remove access*.
- ⚙ opens settings sub-page (the three owner settings).
- Pending **access requests** banner at top with Approve/Deny.
- Keyboard: Esc closes; Enter in the composer sends.
- MCP: `drive.share`, `drive.unshare`, `drive.set_link_sharing`; UI bridge can drive the dialog
  via its `WonkyDialogSpec`.
