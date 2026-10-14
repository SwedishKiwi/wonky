# 03 · App Shell, Navigation and the Single-Window Model

The **app shell** (`packages/wonky_app`) is the shared frame every Flutter app runs inside
(v2: Drive, Write, Sheets, Slides): bootstrapping, auth gate, routing, top-level layout, homes
and their left menu, overlays (dialogs, toasts, command palette), connectivity, presence
plumbing, MCP UI bridge, storage meter and settings. Each app provides a `WonkyAppConfig`
(name, logo — the product icon, [02 §5](02-design-system.md) — primary file kind, routes,
commands, menus, editor screen builder; (v2) `homeScope`, `homeNav`, `appSettingsSections`,
`newItemRoute`/`importRoute` — §3.3, 04 §4).

## 1. Single-window rule

- The app **never** opens a new browser tab/window or OS window: no `window.open`, no
  `url_launcher` with `_blank` for internal content, no multi-window desktop APIs.
- Opening a document replaces the current route in the same window. Switching between the
  apps (Drive, Write, Sheets, Slides — the left menu of every home, §3.3, and the account menu)
  is a same-window navigation (web: same tab, full page load to the other app's base path;
  desktop: see §6).
- External links (in documents, help, *Report a bug* §3.4) open in the system browser only
  after a confirm popover ("Open external link? example.com — Open / Copy link"). On desktop
  this launches the OS browser (that's an external app, not a Wonky window); on web it is a new
  browser tab (`url_launcher` with `_blank`, external content only).
- **Exception: Sign in with Google** (web, [04 §1.6](04-auth-and-accounts.md)) runs Google's
  consent page in a short-lived, named OAuth popup that closes itself after `/auth/callback`
  hands the result back. It is Google's page, not Wonky content.
- **(v2) Exception under review: presenting in Slides.** The presenter view needs the audience
  view on a second screen. See the Open question at the end of this section.
- Dialogs, pickers, previews (print preview, export preview, version compare, (v2) Drive file
  previews) are in-app overlays or full-screen in-app routes with a back/close affordance.
- **Quick switcher** (`Mod+O`): dialog listing recent files of every kind (v2: incl.
  presentations and uploaded files) + search; Enter opens in the same window (other kinds
  navigate to their app; files open Drive's preview).
- **Back/forward**: browser history (web) and `Mod+[` / `Mod+]` (desktop) navigate between
  previously opened files and drive locations.
- Multi-tab browsing of the *same* app is allowed by the browser, but the app itself is designed
  as one window; two windows of the same user simply appear as two sessions (presence shows
  "You (2 tabs)").

**Open question (for review) (v2, D12): a second window for presenting.** Slides' presenter
view (current/next slide, notes, timer) belongs on the laptop while the audience sees the slide
on the projector. Options:

| Option | How | Trade-offs |
|--------|-----|-----------|
| **A. Presenting-only exception** *(recommended)* | *Present with presenter view* opens the **audience view** in a second window: web via the Window Management API (`getScreenDetails()` + `window.open` placed fullscreen on the other screen; falls back to a normal popup the user drags), desktop via a second OS window. The window shows only `/slides/p/:uuid/present?role=audience`, is driven by the presenter window (BroadcastChannel on web, in-process on desktop) and closes when presenting ends. Nothing else may open a window. | Matches Keynote/PowerPoint/Google Slides; needs a popup permission on web; a narrow, well-tested exception. |
| B. Second device | Presenter view on this screen; the audience view runs on another device (or a second browser signed in to the same deck) joined to a **presentation session** synced over the presence stream. | Keeps the single-window rule absolute; awkward for the common laptop + projector case. |

Either way the phone-as-remote (P1) uses the presentation session of option B. The exact
behavior is specified in [Slides 10](wonky_slides/10-presenting-and-pdf.md).

## 2. Routing (`go_router`, URL-based for web)

| Route | Screen |
|-------|--------|
| `/signin`, `/signup`, `/signup/verify`, `/reset` | Auth (see 04) |
| `/` | Home (app homes: Recent of the app's kind + template strip; Drive: Home, all kinds) — (v2) §3.3 |
| `/f/:folderUuid` | Folder (v2; the former `/drive/:folderUuid` redirects) |
| `/my-files` (app homes) · `/my-drive` (Drive) | Root of the user's drive (v2 names; `/my-drive` also redirects to `/my-files` in app homes) |
| `/shared`, `/starred`, `/recent`, `/offline` (app homes), `/trash` | Drive views |
| `/search?q=…` | Search results |
| `/templates` | Template gallery |
| `/new?folder=&template=` (Write, Sheets, Slides; v2) | Creates an item of the app's kind (offline-first where supported) and replaces the route with its editor; used by Drive's *New* menu and *From template* |
| `/import?file=<fileItemUuid>` (Write, Sheets; v2) | Imports an uploaded Drive file with the app's import dialog (Drive 02 §7.2) |
| `/settings/:section` | Wonky Works settings (suite sections, 04 §4) — (v2) |
| `/settings/app`, `/settings/app/:section` | The current app's settings (04 §4) — (v2) |
| Write: `/d/:uuid` (+ `?heading=…`, `?comment=…`, `?version=…`) | Document editor |
| Write: `/d/:uuid/history` | Version history (full-screen compare mode) |
| Write: `/d/:uuid/print` | Print/PDF preview |
| Write: `/themes` and `/themes/:themeUuid` (+ `?doc=<uuid>` to preview/apply to a document) | Theme library & theme editor |
| Sheets: `/s/:uuid` (+ `?sheet=<sheetId>&range=A1:B9`, `?comment=…`) | Spreadsheet editor |
| Sheets: `/s/:uuid/history` | Version history |
| Sheets: `/s/:uuid/print` | Print preview |
| Sheets: `/s/:uuid/script` | Script editor (full-screen) |
| Slides (v2): `/p/:uuid` (+ `?slide=`, `?comment=`) · `/p/:uuid/present` · `/p/:uuid/print` · `/p/:uuid/history` | Deck editor · presenting · PDF/print preview · version history ([Slides 04](wonky_slides/04-screens-menus-toolbar.md)) |
| Drive (v2): `/file/:uuid` · `/storage` | File preview · Storage page ([Drive 04](wonky_drive/04-screens-menus.md)) |
| `/invite/:token` | Share-link landing (request access / open) |

Auth guard redirects to `/signin?next=…`. Unknown/forbidden items show an in-app
**No access** page with *Request access* (sends a request to the owner) and *Switch account*.

Deployment: `wonky_server`'s web server serves the Flutter web builds from one origin:
`/drive/…`, `/write/…`, `/sheets/…`, `/slides/…` (each built with matching `--base-href`);
(v2) `/` redirects to `/drive/`. Routes above are relative to the app's base href. Cross-app
links use the app base URLs from `config.json`; the sign-in session is shared by all apps
(see [01 §2.4–§2.5](01-architecture.md)).

## 3. Shell layout

```
┌───────────────────────────────────────────────────────────────────────────┐
│ Editor header (app-specific: title row, menubar, toolbar)  or  WonkyTopBar │
├───────────────────────────────────────────────────────────────────────────┤
│                                                     │                     │
│                 Main content (route)                │  Side panel host    │
│                                                     │  (WonkySplitView;   │
│                                                     │  icon rail when     │
│                                                     │  collapsed)         │
├───────────────────────────────────────────────────────────────────────────┤
│ StatusBar (editor screens only, optional — only the app's items)          │
└───────────────────────────────────────────────────────────────────────────┘
 Overlays: dialogs · command palette · toasts (bottom-right) · offline banner (top) ·
           MCP control indicator (bottom-left pill when an agent is driving the UI)
```

### 3.1 Editor header (shared structure, app-specific content)

Row 1 (title row, 48 px):
- App icon (the product icon, click → Home; with unsaved-offline badge if relevant).
- `DocumentTitleField`.
- Star toggle, *Move* (folder icon → Move dialog), `SyncStatusIndicator`.
- Spacer.
- `PresenceAvatarStack`.
- (v2) **Report a bug** — ghost icon button (Lucide `bug`, 32 px, tooltip "Report a bug",
  `shell.help.reportBug`, §3.4), muted foreground; hidden below `sm` width (still in Help).
- Comments button (shows/hides the comments, `shell.comments.togglePanel`; badge with open
  count). Comments show through the app's `CommentsHost` when it sets one
  (`ShellServices.commentsHost`; Write: the margin next to the page), otherwise in the comments
  side panel.
- **Share** button (primary; lock/globe icon by link state).
- Account avatar menu.

There are no History or Assistant buttons in the title row: those panels (and the app's other
panels) are opened from the side panel host's icon rail at the right edge
([02 §4.5](02-design-system.md)), or by their commands and shortcuts (View › Panels). Rail order:
the app's panels first, then History (only for roles that can view history). File › Details
opens the details panel (not in the rail).

Row 2: `WonkyMenubar` (File, Edit, View, Insert, Format, …app menus…, Tools, Extensions (Sheets:
Scripts), Help). Row 3: `WonkyToolbar` in a rounded container (margin 8 px left/right, 6 px above,
8 px below). Everything is always shown: there is no compact mode, full screen or View › Show
submenu. The status bar below the content is optional (`EditorScaffold.showStatusBar`) and
contains only what the app passes; the sync status is in the title row and the app theme in
View › App theme.

### 3.2 Shared menus (each app extends)

**File** (shared core): New ▸ (Document, Spreadsheet, Presentation (v2), From template…), Open… (`Mod+O`), Import…,
Make a copy…, Share ▸ (Share with others, Copy link, Publish settings), Download ▸ (formats),
Rename, Move…, Add shortcut to Drive, Move to trash, Version history ▸ (Name current version,
See version history `Mod+Alt+Shift+H`), Make available offline (toggle), Details, app items
(Write: Language, Page setup / Sheets: Settings — locale, time zone, calculation), Print (`Mod+P`).

**Edit**: see [08-commands-and-undo.md](08-commands-and-undo.md) §3.5, plus app items.

**View** (shared core): Mode ▸ (Editing / Suggesting (Write) / Viewing), Zoom ▸, Panels ▸
(Outline, Comments, History, Assistant — Write replaces Comments with a top-level *Comments and
suggestions* toggle for its margin), App theme ▸ (System / Light / Dark).

**Tools**: Assistant, Explore (search drive), (v2) *<App> settings…*
(`shell.settings.openApp`, `Mod+,` on desktop) and *Wonky Works settings…*
(`shell.settings.open`), Keyboard shortcuts (`Mod+/`), Accessibility settings.

**Help**: Keyboard shortcuts, app items (Write: Markdown guide; Sheets: Function list; Slides:
see Slides 04), separator, (v2) **Report a bug** (`shell.help.reportBug`, §3.4), What's new,
About. There is no in-app help center and no menu search (menu commands are found through the
command palette).

**Open question (for review) (v2):** keep *Report a problem* (`shell.help.feedback`, the in-app
dialog that posts to the server's `feedback` endpoint) next to *Report a bug*?
*Recommendation:* replace it in the Help menu with *Report a bug* (one obvious way to report);
keep `shell.help.feedback` registered (palette, MCP) and keep the error boundary's *Copy error
details*, which users can paste into the GitHub issue.

Only one menu is open at a time: opening a menubar menu, dropdown or context menu closes the
one that was open ([02 §4.2](02-design-system.md)).

### 3.3 Homes and the left menu (v2)

Every app has a **home** (its documents view) built from the shell's drive UI
(`DriveHomeScreen`, `packages/wonky_app/lib/src/drive/`), configured by
`WonkyAppConfig.homeScope`:

| | Wonky Drive (`HomeScope.all`) | App homes — Write, Sheets, Slides (`HomeScope.kind(k)`) |
|-|------------------------------|-----------------------------------------------------------|
| Items listed | every kind | only kind `k` (documents / spreadsheets / presentations), plus folders that contain `k` (suite 05 §3.2) |
| Top bar | Drive logo + "Drive", search across all kinds | app logo + short name, search filtered to `k` with a "Search all of Wonky Drive" row |
| New | folder, document, spreadsheet, presentation, file upload, template | `k` and *From template* |
| Template strip | — | yes (app's templates) |
| Folder management | tree, drag moves, new folder | none — **Open in Wonky Drive** (ghost button with the Drive icon in the header row, opens the same folder in Drive); the per-item *Move to…* dialog stays |
| Upload | arbitrary files (Drive 02) | *Import file…* of the app's convertible types |
| Type filter chip | yes (incl. file subtypes) | — |

The **left menu** (`HomeSidebar`, Drive 04 §2) is the same widget in every home:

1. **App section** — Wonky Drive, Wonky Write, Wonky Sheets, Wonky Slides with their product
   icons; the current app highlighted; the others switch apps in the same tab
   (`shell.account.switchApp {app}`).
2. **+ New** and the app's navigation (`WonkyAppConfig.homeNav`): app homes — *Recent* (`/`),
   *My files*, *Shared with me*, *Starred*, *Offline* (on-device availability, as today),
   *Trash*; Drive — Home, My Drive (+ folder tree), Shared with me, Recent, Starred, Trash,
   Storage.
3. **Bottom section** — *<App> settings* (`shell.settings.openApp`), *Wonky Works settings*
   (`shell.settings.open`), *Report a bug* (`shell.help.reportBug`), and the storage meter
   ("12.3 MB of 50 MB used", [Drive 03 §6.1](wonky_drive/03-storage-quota.md)).

The account menu (avatar) in homes and editors lists: name and email, *<App> settings*, *Wonky
Works settings*, *Open ▸* Wonky Drive / Write / Sheets / Slides (product icons; replaces the
former single "Open Wonky Sheets/Write" item), *Sign out*.

**Open question (for review) (v2, D2):** which folders appear in an app home? *Recommendation:*
only folders that contain — recursively, ignoring trashed items — at least one item of the
app's kind (maintained as `DriveItem.kindMask`, suite 05 §3.2); empty folders and folders with
only other kinds are hidden, so an app home never shows dead ends. Alternative: always show all
folders (simpler, but a Slides user sees every Sheets-only folder).

### 3.4 Report a bug (v2)

- Command **`shell.help.reportBug`** (`requiredRole: viewer`, not undoable, available signed
  out too: the sign-in screens show it as a footer link). Entry points: Help menu in every
  editor, the editor title-row icon button (§3.1), the bottom section of every home's left
  menu (§3.3), the command palette, MCP `ui.invoke_command`.
- It opens `wonky.help.bugReportUrl` (default `https://github.com/serverpod/wonky/issues`) as
  an **external link** with the confirm popover of §1: "Open external link? github.com — Issues
  on GitHub are public: don't include private content. [Open] [Copy link]".

**Open question (for review) (v2, D5):** link to the issue list, or to a *new issue* with a
prefilled body? *Recommendation:* a new-issue deep link
(`…/issues/new?template=bug_report.yml&app=write&version=2.0.3&platform=web&browser=Chrome%20131`)
with an issue form in the repository (`.github/ISSUE_TEMPLATE/bug_report.yml`, fields *app*,
*version*, *platform*, *browser/OS*, *what happened*, *steps*), prefilled with **no user
content, ids, emails or URLs of documents** — only the app, build version, platform and browser
family. Fallback to the issue list when the URL would exceed 2,000 characters.

## 4. Global overlays and states

- **Offline banner**: thin top bar "You're offline. Changes are saved on this device and will
  sync when you're back online." with *Retry* (`shell.offlineBanner.retry`, a small ghost
  button tinted with the banner's own colors). Edits remain enabled for offline-capable content.
- **Reconnecting** indicator in `SyncStatusIndicator` with exponential backoff timer.
- **Version mismatch**: if the server's protocol version is newer than the client's
  (`/version` check on connect), show a non-blocking toast "A new version is available —
  Reload"; block only if incompatible.
- **Read-only/permission change**: if your role is downgraded while editing, show a toast and
  switch mode live; pending local changes that are no longer allowed are discarded with a
  notice (and saved as a local "Unsaved changes" export offered for download).
- **Global error boundary**: unexpected exceptions show a recoverable "Something went wrong"
  card with *Reload document* and *Copy error details*; errors are reported to the server log.
- **MCP control pill**: when an MCP client invokes UI-bridge tools, a pill "🤖 Agent is
  controlling this window — Stop" appears; *Stop* disconnects the bridge for this session
  (see [09-mcp.md](09-mcp.md)).
- **(v2) Storage banner and dialog**: at ≥ 90 % of the quota and when over quota, a banner under
  the top bar/editor header; refused byte-adding actions show the *Out of storage* dialog
  ([Drive 03 §6.2–6.3](wonky_drive/03-storage-quota.md)).

## 5. State management and DI

- Follow Flutter's recommended layered architecture (UI → ViewModel/Controller → Repository →
  Service). Controllers are `ChangeNotifier`s; widgets use `ListenableBuilder` /
  `ValueListenableBuilder`. DI via `provider` (`Provider`, `ChangeNotifierProvider`) at shell
  and screen level.
- Repositories wrap the generated Serverpod client and local stores; UI never calls the client
  directly.
- Long-lived services (Connectivity, Presence, UndoService, CommandRegistry, KeymapService,
  McpBridge, Preferences) are created in `WonkyShell` and provided at the top.

## 6. Desktop specifics (macOS first, Windows/Linux supported)

- One OS window. Native menubar on macOS mirrors `WonkyMenubar` via `PlatformMenuBar` (generated
  from the same `MenuSpec`); in-window menubar hidden on macOS when native menus are active
  (setting).
- Cross-app switch on desktop: each app is a separate desktop binary (built from
  `wonky_drive`, `wonky_write`, `wonky_sheets`, `wonky_slides`; sign-in sharing per
  [01 §2.5](01-architecture.md)); the left menu's app links and "Open in …" launch/activate the
  other app via its custom URL scheme (`wonkydrive://f/<uuid>`, `wonkywrite://d/<uuid>`,
  `wonkysheets://s/<uuid>`, `wonkyslides://p/<uuid>`) — this is another app, consistent with the
  single-window rule — and fall back to the web URL if not installed.
- **Open question (for review) (v2):** one desktop binary "Wonky Work" containing all four apps
  (in-window switching) instead of four binaries? *Recommendation:* keep four binaries for v2
  (the web build structure maps 1:1, and a combined binary would also combine the four bundles);
  revisit when desktop packaging (M7 scope) is done.
- Window title = document title + " — Wonky Write"; dirty marker unused (always saved).
- File associations: `.md` (Write, imports), `.xlsx/.csv` (Sheets, imports); (v2) none for
  Drive or Slides (Slides has no import formats).
- Window size/position persisted.

## 7. Connectivity service

`ConnectivityService` exposes `online` (server reachable via the Serverpod WebSocket,
heartbeat 15 s), `lastConnectedAt`, `reconnect()`. All sync layers listen to it. Streams
(document sessions, presence, drive watch, UI bridge) are re-established on reconnect by a
`StreamSupervisor` with backoff (1 s → 30 s, jitter).
