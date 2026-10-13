# 03 · App Shell, Navigation and the Single-Window Model

The **app shell** (`packages/wonky_app`) is the shared frame both Flutter apps run inside:
bootstrapping, auth gate, routing, top-level layout, overlays (dialogs, toasts, command palette),
connectivity, presence plumbing, MCP UI bridge and settings. Each app provides a `WonkyAppConfig`
(name, logo — the product icon, [02 §5](02-design-system.md) — primary file kind, routes,
commands, menus, editor screen builder).

## 1. Single-window rule

- The app **never** opens a new browser tab/window or OS window: no `window.open`, no
  `url_launcher` with `_blank` for internal content, no multi-window desktop APIs.
- Opening a document replaces the current route in the same window. Switching between Write and
  Sheets is a same-window navigation (web: same tab, full page load to the other app's base
  path; desktop: see §6).
- External links (in documents, help) open in the system browser only after a confirm popover
  ("Open external link? example.com — Open / Copy link"). On desktop this launches the OS browser
  (that's an external app, not a Wonky window).
- Dialogs, pickers, previews (print preview, export preview, version compare) are in-app overlays
  or full-screen in-app routes with a back/close affordance.
- **Quick switcher** (`Mod+O`): dialog listing recent files of both kinds + search; Enter opens
  in the same window.
- **Back/forward**: browser history (web) and `Mod+[` / `Mod+]` (desktop) navigate between
  previously opened files and drive locations.
- Multi-tab browsing of the *same* app is allowed by the browser, but the app itself is designed
  as one window; two windows of the same user simply appear as two sessions (presence shows
  "You (2 tabs)").

## 2. Routing (`go_router`, URL-based for web)

| Route | Screen |
|-------|--------|
| `/signin`, `/signup`, `/signup/verify`, `/reset` | Auth (see 04) |
| `/` | Home (drive, filtered to app's kind) |
| `/drive/:folderUuid` | Folder |
| `/shared`, `/starred`, `/recent`, `/offline`, `/trash` | Drive views |
| `/search?q=…` | Search results |
| `/templates` | Template gallery |
| `/settings/:section` | Settings |
| Write: `/d/:uuid` (+ `?heading=…`, `?comment=…`, `?version=…`) | Document editor |
| Write: `/d/:uuid/history` | Version history (full-screen compare mode) |
| Write: `/d/:uuid/print` | Print/PDF preview |
| Write: `/themes` and `/themes/:themeUuid` (+ `?doc=<uuid>` to preview/apply to a document) | Theme library & theme editor |
| Sheets: `/s/:uuid` (+ `?sheet=<sheetId>&range=A1:B9`, `?comment=…`) | Spreadsheet editor |
| Sheets: `/s/:uuid/history` | Version history |
| Sheets: `/s/:uuid/print` | Print preview |
| Sheets: `/s/:uuid/script` | Script editor (full-screen) |
| `/invite/:token` | Share-link landing (request access / open) |

Auth guard redirects to `/signin?next=…`. Unknown/forbidden items show an in-app
**No access** page with *Request access* (sends a request to the owner) and *Switch account*.

Deployment: `wonky_server`'s web server serves both Flutter web builds from one origin:
`/write/…` → Write build, `/sheets/…` → Sheets build (each built with matching `--base-href`),
`/` redirects to the last used app. Routes above are relative to the app's base href. Cross-app
links use the app base URLs from `config.json`; the sign-in session is shared by both apps
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

**File** (shared core): New ▸ (Document, Spreadsheet, From template…), Open… (`Mod+O`), Import…,
Make a copy…, Share ▸ (Share with others, Copy link, Publish settings), Download ▸ (formats),
Rename, Move…, Add shortcut to Drive, Move to trash, Version history ▸ (Name current version,
See version history `Mod+Alt+Shift+H`), Make available offline (toggle), Details, app items
(Write: Language, Page setup / Sheets: Settings — locale, time zone, calculation), Print (`Mod+P`).

**Edit**: see [08-commands-and-undo.md](08-commands-and-undo.md) §3.5, plus app items.

**View** (shared core): Mode ▸ (Editing / Suggesting (Write) / Viewing), Zoom ▸, Panels ▸
(Outline, Comments, History, Assistant — Write replaces Comments with a top-level *Comments and
suggestions* toggle for its margin), App theme ▸ (System / Light / Dark).

**Tools**: Assistant, Explore (search drive), Preferences…, Keyboard shortcuts (`Mod+/`),
Accessibility settings.

**Help**: Keyboard shortcuts, app items (Write: Markdown guide; Sheets: Function list),
separator, Report a problem (in-app dialog → server `feedback` endpoint), What's new, About.
There is no in-app help center and no menu search (menu commands are found through the command
palette).

Only one menu is open at a time: opening a menubar menu, dropdown or context menu closes the
one that was open ([02 §4.2](02-design-system.md)).

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
- Cross-app switch on desktop: Write and Sheets are separate desktop binaries (built from
  `wonky_write` and `wonky_sheets`; sign-in sharing per [01 §2.5](01-architecture.md));
  "Open in Wonky Sheets" from Write launches/activates the Sheets app via a custom URL scheme
  (`wonkysheets://s/<uuid>`) — this is another app, consistent with the single-window rule —
  and falls back to the web URL if not installed.
- Window title = document title + " — Wonky Write"; dirty marker unused (always saved).
- File associations: `.md` (Write, imports), `.xlsx/.csv` (Sheets, imports).
- Window size/position persisted.

## 7. Connectivity service

`ConnectivityService` exposes `online` (server reachable via the Serverpod WebSocket,
heartbeat 15 s), `lastConnectedAt`, `reconnect()`. All sync layers listen to it. Streams
(document sessions, presence, drive watch, UI bridge) are re-established on reconnect by a
`StreamSupervisor` with backoff (1 s → 30 s, jitter).
