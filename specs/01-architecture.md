# 01 · Architecture and Repository Layout

## 1. Decision summary

| # | Decision | Rationale |
|---|----------|-----------|
| A1 | **One Serverpod server** (`wonky_server`) serves both apps, auth, drive, sharing, comments, MCP, AI, and both Flutter web builds. | One account system, one drive, one MCP endpoint, cross-app features (templates, search, sharing) without service-to-service calls. |
| A2 | **Two Flutter apps** (`wonky_write`, `wonky_sheets`) sharing packages (`packages/wonky_app` shell, `wonky_ui`, cores), both served by `wonky_server` on one origin (`/write/`, `/sheets/`) with one shared sign-in. | Smaller bundles, independent release cadence, clear ownership; shared shell keeps UX identical; same origin makes the session cookie shared. |
| A3 | **Pure-Dart "core" packages** for logic needed on both server and client (Markdown↔Delta, OT helpers, exporters, formula engine, number formats, XLSX/CSV mapping, tool schemas). | Headless MCP tools, server-side export/import, AI tools and version materialization need the same logic as the apps. |
| A4 | **Write: server-authoritative OT** over Quill Deltas on typed Serverpod streams; op log in Postgres. | Required by the brief; Delta has `compose/transform/invert/transformPosition`. |
| A5 | **Sheets: Serverpod offline-first sync** (`serverpod_offline_sync`, `database: sync`), one spreadsheet = one space; per-cell rows with deterministic ids; stable row/column ids; formulas stored with id-based references. | Offline-first requirement; field-level LWW merges; concurrent row/column insertion merges without rewriting cells or formulas. |
| A6 | **Everything is a command**; undo is per-user forward ops. | Undo-for-everything + MCP control (see 08). |
| A7 | **MCP hosted in the server** (`mcp_dart`, Streamable HTTP) + UI bridge relayed over a Serverpod stream. | Works identically for web and desktop clients. |
| A8 | **Dart scripting via `dart_eval`**: compile on the server, execute bytecode on server (triggers, scheduled jobs) and client (custom functions, macros) inside a sandbox worker. | Keeps the analyzer out of the web bundle; sandboxed by default. |
| A9 | State management: Flutter's layered architecture, `ChangeNotifier` controllers, `provider` for DI, `go_router`. | Official guidance, low ceremony. |

## 2. Repository layout

**Current state (starting point).**

The repository was created from the Serverpod project template and two `flutter create` apps:

| Folder | State | Fate |
|--------|-------|------|
| `wonky_server/` | Serverpod 4.1 server: email/password auth (`JwtConfigFromPasswords`, `ServerpodCloudEmailIdpConfig`), cloud storage, `AppConfigRoute`, `FlutterRoute` serving `web/app`, `flutter_build` script, greeting example endpoint | **Kept** — this is *the* server. Example endpoint/model removed in M0. |
| `wonky_client/` | Generated client | **Kept** (regenerated, never edited) |
| `wonky_flutter/` | Template Flutter app: client bootstrap (`client.dart`: server URL from `assets/config.json`, `FlutterAuthSessionManager`), `driver.dart`, sign-in screen | **Reference only** — its client/auth/driver setup is ported into `packages/wonky_app` and the two apps, then the folder is **deleted** in M0 |
| `wonky_write/`, `wonky_sheets/` | Fresh `flutter create` apps (counter demo), not yet in the pub workspace, own `pubspec.lock`, SDK `^3.13.4` | **Become the two apps** (M0: join the workspace, wire to the server) |
| `specs/` | These specs; app specs in `specs/wonky_write/` and `specs/wonky_sheets/` | — |

Root `pubspec.yaml` is a pub workspace (currently `wonky_client`, `wonky_server`, `wonky_flutter`).
`.mcp.json` points the `serverpod` MCP at `wonky_server`. CI (`.github/workflows`) runs analyze,
format and tests for `wonky_server` only, plus a Serverpod Cloud deploy workflow.

**Target layout.**

```
wonky/
├── pubspec.yaml                         # root Dart pub workspace listing every package below (+ dependency_overrides, §2.3)
├── .mcp.json                            # serverpod MCP → wonky_server; dart MCP
├── AGENTS.md                            # agent instructions (project summary, MCP usage, checklist)
├── specs/                               # suite-level specs (this folder)
│   ├── wonky_write/                     #   Write app specs
│   └── wonky_sheets/                    #   Sheets app specs
├── wonky_server/                        # THE Serverpod server (auth, drive, sharing, Write OT, Sheets sync, MCP, AI,
│                                        #   and the web server that serves both Flutter web builds — §2.4)
├── wonky_client/                        # generated Serverpod client (never edit)
├── wonky_write/                         # Flutter app: Wonky Write (super_editor integration, UI) — web + desktop
├── wonky_sheets/                        # Flutter app: Wonky Sheets (grid, UI, sync DB, script worker) — web + desktop
├── packages/
│   ├── wonky_core/                      # pure Dart: ids, roles, command/undo abstractions, MCP tool schemas, utils
│   ├── wonky_ui/                        # Flutter: theme + custom shad-style widgets (no server deps)
│   ├── wonky_app/                       # Flutter: shell (client bootstrap, auth, routing, drive, sharing, comments UI,
│   │                                    #          history UI, presence, settings, command system, MCP bridge, AI panel)
│   ├── wonky_sync_models/               # Serverpod *shared package*: `database: sync` models for Sheets + id helpers
│   ├── wonky_write_core/                # pure Dart: Delta schema, Markdown⇄Delta, OT helpers, exporters, theme model
│   ├── wonky_sheets_core/               # pure Dart: addressing, formula parser/evaluator/functions, number formats,
│   │                                    #   recalculation graph, xlsx/csv/ods mapping, sheet model helpers
│   ├── wonky_sheets_script/             # pure Dart: dart_eval bridge (Spreadsheet API), compiler & runtime wrappers
│   └── wonky_mcp_stdio/                 # tiny CLI: stdio ↔ Streamable HTTP proxy
└── third_party/                         # vendored (locally patched) copies of third-party packages — see §2.3
    ├── super_editor/                    #   (+ super_text_layout / attributed_text only if patches need them)
    ├── dart_quill_delta/                #   only if OT fixes are needed
    ├── serverpod_offline_sync/          #   + _client / _server as needed
    └── dart_eval/
```

Paths in the specs are **package-relative** (`wonky_sheets_core/lib/model/`,
`wonky_write/lib/features/editor/`, `wonky_server/lib/src/…`); packages under `packages/` are
referred to by package name.

**M0 migration steps:**

1. Add `wonky_write` and `wonky_sheets` to the root workspace (`resolution: workspace`, delete
   their `pubspec.lock`), align SDK constraints (`environment.sdk`/`flutter`) across all
   packages and the CI Flutter version (CI pins 3.44.4; the new apps were created with Dart
   3.13).
2. Scaffold `packages/*` (workspace members) and `third_party/` (§2.3).
3. Port `wonky_flutter/lib/client.dart` (server URL from `config.json`, connectivity monitor,
   `FlutterAuthSessionManager`) and the sign-in flow into `wonky_app`; add `lib/driver.dart`
   (flutter_driver entry, text entry emulation off) to both apps.
4. Server: replace the single `web/app` `FlutterRoute` with the two app routes and update
   `flutter_build` (§2.4); list both apps under `serverpod: flutter_apps:`; enable cookie auth
   (§2.5); add `shared_packages: [../packages/wonky_sync_models]` to `config/generator.yaml`;
   remove the greeting example (endpoint, model, test).
5. Delete `wonky_flutter/` and remove it from the workspace.
6. Extend CI (analyze/format/test) to every workspace package, add the dependency-rule check
   (§2.1).
7. Update `AGENTS.md` (app names, `driver.dart` locations, `flutter_apps` aliases).

### 2.1 Package dependency rules (enforced by a CI script)

```
wonky_core            → (pure Dart deps only)
wonky_write_core      → wonky_core, dart_quill_delta (9.x by default; see §2.2), markdown, html, pdf,
                        archive, xml, image, crypto, highlight (or re_highlight — spike decides)
wonky_sheets_core     → wonky_core, wonky_sync_models (model types only), petitparser, intl, timezone, archive, xml, csv,
                        excel_plus, pdf, image
wonky_sheets_script   → wonky_core, wonky_sheets_core, dart_eval, eval_annotation, native_synchronization
wonky_sync_models     → serverpod_database, serverpod_offline_sync, serverpod_serialization, uuid
wonky_server          → serverpod, serverpod_auth_idp_server, serverpod_offline_sync(_server), serverpod_cloud_storage,
                        wonky_core, wonky_write_core, wonky_sheets_core, wonky_sheets_script, wonky_sync_models, mcp_dart, http
wonky_client          → generated (+ serverpod_offline_sync_client, serverpod_database, wonky_sync_models)
wonky_ui              → flutter, shad
wonky_app             → wonky_ui, wonky_core, wonky_client, serverpod_flutter, serverpod_auth_idp_flutter, go_router, provider, mcp_dart
wonky_write           → wonky_app, wonky_ui, wonky_write_core, super_editor (vendored), super_clipboard, printing, file_saver,
                        file_picker
wonky_sheets          → wonky_app, wonky_ui, wonky_sheets_core, wonky_sheets_script, two_dimensional_scrollables (auxiliary
                        tables only), super_clipboard, re_editor, printing, file_saver, file_picker, path_provider
                        (charts: own pure-Dart engine in wonky_sheets_core — see Sheets 08)
```

Forbidden: any `*_core` importing Flutter; `wonky_ui` importing client/server code; Write
packages importing Sheets packages and vice versa; feature code importing generated server code.

### 2.2 Third-party version policy
- `super_editor`: **vendored** in `third_party/super_editor`, based on 0.3.0-dev.52 (pre-1.0,
  frequent breaking changes; several gaps we fix in place — patches SE-1…SE-5 in
  [Write 04 §2.2](wonky_write/04-editor.md)). Use its built-in Markdown/Quill
  serialization only where noted (deprecated `super_editor_markdown`/`super_editor_quill`
  packages must not be added).
- `dart_quill_delta`: 9.x on client and server (super_editor's constraint). Because
  super_editor is vendored we may relax that constraint and move to 10.x if useful — decided in
  M0; vendor `dart_quill_delta` itself only if OT fixes are needed (e.g. embed handling in
  `transform`/`invert`, `compose` performance on large documents).
- `serverpod_offline_sync*`: vendored in `third_party/serverpod_offline_sync` (as toptap does)
  for Serverpod 4.1 compatibility (`watch()`, web transaction deadlock fix) and our helpers
  (U11). Fixes are contributed upstream; overrides are removed when upstream catches up.
- `dart_eval`: vendored in `third_party/dart_eval` (patches DE-1…DE-3, Sheets 09).
- `sqlite3_web` pinned to a version compatible with `sqlite_async` (toptap pins 0.9.4).
- `shad` `^0.99.4`.

### 2.3 Vendored packages (local copies)

**Any third-party package may be copied into the repo and patched** when that is the cleanest
way to get a fix or a missing capability. Prefer fixing a library in place over building
fragile workarounds around it in app code; keep app-specific logic in our own packages.

Rules:
1. **Location & wiring**: `third_party/<package>/`, keeping the original package **name** (so
   transitive dependents resolve to it) and wired with `dependency_overrides: <package>: {path:
   third_party/<package>}` in the **workspace root `pubspec.yaml`** (pub workspaces only honor
   overrides at the root). Dependent packages keep a normal version constraint.
2. **Provenance**: copy from an exact released version or git commit; record it in
   `third_party/<package>/VENDORED.md` (source, version/commit, date, license). Keep the
   original `LICENSE`. Only permissive licenses (MIT, BSD, Apache-2.0); check before copying.
3. **Patch log**: every change is listed in `third_party/<package>/PATCHES.md` with an id
   (`SE-1`, `DE-2`, `OS-3`…), the reason, files touched, the spec that needs it, and upstream
   status (PR link / "not upstreamable"). Patches are small, focused and covered by tests;
   mark changed code with `// WONKY PATCH <id>` comments.
4. **Tests**: the package's own test suite plus tests for each patch run in CI.
5. **Upstream first**: open upstream PRs for general fixes; Serverpod-owned packages
   (`serverpod_offline_sync`, `shad`) are fixed upstream directly when possible and vendored
   only to unblock. Remove the copy when upstream contains everything we need.
6. **Upgrades**: re-copy the new upstream version, re-apply the patch log, run tests — never
   edit the vendored copy without a `PATCHES.md` entry.
7. **Ownership**: each vendored package is owned by one workstream (see the app plans); the
   package-dependency CI check (§2.1) treats `third_party/*` as external packages.

Current and candidate vendored packages:

| Package | Status | Why |
|---------|--------|-----|
| `super_editor` | Vendored (M0) | Quill serializer gaps, incremental Delta apply, richer change events, editable table cells, fixes found by our tests (Write 04 §2.2) |
| `serverpod_offline_sync` (+ `_client`, `_server`) | Vendored (M0) | Serverpod 4.1 compatibility, web deadlock fix, `changedRowsSince` (U11) and other upstream requirements while they land (suite 12 §4) |
| `dart_eval` | Vendored (M6, spikes earlier) | Source maps, interrupt hook, conformance fixes (Sheets 09) |
| `dart_quill_delta` | Candidate | Only if OT edge cases or performance require it |
| `excel_plus` | Candidate | Instead of growing the supplementary OOXML reader if gaps are small (Sheets 11 §5.1) |
| `docx_creator` | Candidate | If the M5 spike adopts it but finds gaps (Write 07) |
| `re_editor` | Candidate | Fallback if unmaintained (Sheets 09) |
| `mcp_dart` | Candidate | If a Relic-native Streamable HTTP transport is better added in the library (suite 09 §1) |
| `super_clipboard` | Candidate | Platform fixes for rich clipboard on web/desktop |

### 2.4 Building and serving the web apps

Both apps are served by **`wonky_server`'s web server** (Relic, port 8082 in development) from
one origin; there is no separate host app.

| Path | Served from | Notes |
|------|-------------|-------|
| `/write/…` | `web/write/` — `wonky_write` built with `--base-href /write/` | `FlutterRoute` (SPA fallback to `index.html`) |
| `/sheets/…` | `web/sheets/` — `wonky_sheets` built with `--base-href /sheets/` | `FlutterRoute` |
| `/write/assets/assets/config.json`, `/sheets/assets/assets/config.json` | `AppConfigRoute` | Replaces the bundled `assets/config.json` at runtime: `{apiUrl, apps: {write, sheets}}` (the API URL and the base URL of each app, for cross-app links) |
| `/` | redirect | To the last used app (`wonky_last_app` cookie set by the apps, default `/write/`) |
| `/mcp`, `/files/…`, `/invite/:token` | server routes | See 09, 05, 06 |
| anything else unbuilt | `web/pages/build_flutter_app.html` | Template fallback shown when an app's build folder is missing |

- **Build**: the `flutter_build` script in `wonky_server/pubspec.yaml` (`serverpod run
  flutter_build`, also run by the Serverpod Cloud pre-deploy hook) builds both apps into
  `wonky_server/web/write` and `wonky_server/web/sheets` (posix: `flutter build web --wasm
  --base-href /write/ --output ../wonky_server/web/write`; Windows: build + `xcopy`, as the
  template does). Build folders are git-ignored. WASM and cross-origin-isolation headers: see
  [13 §3](13-security-and-operations.md).
- **Development**: `serverpod start` launches both apps through `serverpod: flutter_apps:` in
  the server pubspec (aliases `write` and `sheets`, `path: ../wonky_write` / `../wonky_sheets`,
  `target: lib/driver.dart`, fixed `web-port`s so the origins are stable for
  `allowedOrigins` and cookie auth). In development each app runs from `flutter run` on its own
  port at the root path; the bundled `assets/config.json` lists those dev URLs. Production
  builds always come from the server's `web/` folders.
- **Routing**: `go_router` paths are relative to the base href (`/d/:uuid` is
  `/write/d/:uuid` in production). Cross-app navigation (open a spreadsheet from Write, etc.) is
  a same-tab full page load to `apps.<other>` + path from `config.json`.
- **Desktop**: Write and Sheets are separate desktop binaries built from the same apps (see
  [03 §6](03-app-shell-and-navigation.md)).

### 2.5 One sign-in across both apps

A user signs in once and stays signed in when switching between Write and Sheets.

- **Web**: both apps live on the same origin and use Serverpod's **cookie auth**:
  `authCookie` (httpOnly, `path: /`, `secure` in staging/production) plus `allowedOrigins`
  (the web server origin; in development also both `flutter run` origins) in
  `config/*.yaml`, and `client.cookieAuth = true` on web. The session cookie is therefore shared
  by `/write/` and `/sheets/` (and, in development, by both localhost ports — cookies are not
  port-isolated). Tokens never sit in JavaScript-readable storage.
- Signing out in either app revokes the session for both; the other app notices on its next
  request or auth-state check and shows the sign-in screen (03 §4 *Session expired* flow).
- **Desktop**: each binary keeps its tokens in secure storage. On macOS both apps share a
  keychain access group so one sign-in covers both (P1); elsewhere each desktop app signs in
  separately (P2: shared credential store).
- `wonky_app` owns the client bootstrap (`WonkyClient.initialize()`: server URL from
  `config.json`, `FlutterConnectivityMonitor`, `FlutterAuthSessionManager`, cookie auth on web),
  so both apps behave identically.

## 3. Server structure (`wonky_server/lib/`)

```
server.dart                    # Serverpod bootstrap, auth, web routes (both apps), MCP route, cloud storage, future calls
src/
  platform/
    users/                     # UserProfile, UserPreferences, UserEndpoint, AccessTokenEndpoint
    drive/                     # DriveItem, DriveItemUserState, DriveEndpoint, search, templates, trash purge
    sharing/                   # DriveItemPermission, ShareLink, SharingEndpoint, AccessService (role resolution + space membership mirroring)
    comments/                  # CommentThread, Comment, CommentEndpoint
    notifications/             # Notification, NotificationEndpoint, email digests
    presence/                  # PresenceEndpoint (ephemeral)
    versions/                  # ItemVersion, VersionEndpoint, VersionProvider registry, thinning job
    activity/                  # ActivityEvent
    files/                     # StoredFile (uploads: images, avatars, imports, exports), signed URLs
    mcp/                       # transport, auth, ToolExecutor, UiBridgeHub, UiBridgeEndpoint
    ai/                        # AnthropicClient, AssistantService, AssistantEndpoint
    feedback/                  # FeedbackEndpoint
  write/
    models/                    # Document, DocumentOp, DocumentSnapshot, WriteTheme, …
    ot/                        # DocumentSessionManager (in-memory per-doc state), OtService
    endpoints/                 # DocumentEndpoint (stream), WriteThemeEndpoint, WriteExportEndpoint
    versions/                  # WriteVersionProvider
    mcp/                       # write.* tools
  sheets/
    spaces/                    # SpaceReservation, subscription management (active set), membership mirroring
    endpoints/                 # SheetsEndpoint (online-only ops), SheetsSyncEndpoint (custom sync wrapper w/ onMergeSuccess)
    scripts/                   # compile service, server runtime pool, triggers, scheduled jobs, quotas
    changelog/                 # ChangeLog processing (activity, triggers, cell history, pruning)
    versions/                  # SheetsVersionProvider (snapshots to cloud storage)
    imports/                   # xlsx/csv/ods import pipeline (server-side for large files)
    mcp/                       # sheets.* tools
```

Endpoints are thin; business logic lives in services (`*_service.dart`) that are unit-testable
with `serverpod_test`.

## 4. Client structure (each Flutter app)

```
lib/
  main.dart                    # WonkyShell(config: WriteAppConfig()) / SheetsAppConfig
  driver.dart                  # flutter_driver entry for agents/E2E (ported from the template app in M0)
  config/                      # app config, routes, menus (MenuSpec), toolbar spec
  commands/                    # one file per command group; registered in commands.dart
  features/<feature>/          # ui/ (widgets), view_models/, data/ (repositories)
  mcp/                         # app-specific ui.* tools
  theme/                       # app-specific tokens (on top of wonky_ui)
```

Feature folders are the unit of parallel work: e.g. Write `features/editor`,
`features/theme_editor`, `features/export`, `features/outline`, `features/find_replace`,
`features/suggestions`, …; Sheets `features/grid`, `features/formula_bar`, `features/charts`,
`features/pivot`, `features/filters`, `features/scripts`, ….

## 5. Cross-cutting runtime flows

```
             ┌──────────── Flutter app (web/desktop) ─────────────┐
 User/MCP ──►│ Command ─► Controller ─► Repository ─┬─► Serverpod RPC/streams ─┐
             │    │                                  └─► Local store (SQLite)   │
             │    └─► UndoService                                               │
             └──────────────────────────────────────────────────────────────────┘
                                                                                ▼
             ┌──────────────────────── wonky_server ───────────────────────────┐
             │ Endpoints ─► Services ─► Postgres (platform + Write tables)       │
             │                       └► Offline-sync engine (Sheets spaces)      │
             │ MCP route ─► ToolExecutor ─► same Services  (+ UiBridgeHub ─► apps)│
             │ AssistantService ─► Anthropic Messages API ─► ToolExecutor        │
             │ session.messages (Redis when multi-instance): presence, doc ops,  │
             │   drive changes, comments, UI bridge                              │
             └───────────────────────────────────────────────────────────────────┘
```

## 6. Configuration

`config/*.yaml` additions live in one `wonky:` section (Serverpod ignores unknown keys; read by
`wonky_server/lib/src/platform/config/wonky_config.dart`, env overrides `WONKY_<SECTION>_<KEY>`):
`features: {ai, scripting, mcpUiBridge, experimentalCharts}`, `ai: {enabled, dailyTokenBudgetPerUser}`, `mcp: {enabled, port?,
allowedHosts, allowedOrigins}`, `sheets: {maxCellsPerSpreadsheet, maxActiveSpacesPerUser,
scriptTimeoutMs, scriptDailyQuotaMs}`, `write: {snapshotEveryNOps, maxDocumentChars}`,
`webApps: {write: {dir: web/write, path: /write/}, sheets: {dir: web/sheets, path: /sheets/}}`
(§2.4); the template's commented-out `authCookie` + `allowedOrigins` are enabled (§2.5).
Secrets in `passwords.yaml`: `anthropicApiKey`, `jwt…` (existing), email provider credentials.

Redis is **required** in staging/production (multiple server instances need global
`session.messages` for presence, Write op fan-out and UI bridge relays). Development runs
without Redis (local scope).

## 7. Protocol versioning

- `ProtocolInfo { serverVersion, minClientVersion, syncTablesHash }` returned by
  `meta.getInfo()`; clients check on connect (see shell spec for UX).
- Offline-sync schema changes are lock-step (the engine rejects clients with a different
  `syncTablesHash`). Rule: synced schema changes are batched into releases; clients that fail the
  hash check show a blocking "Update required" screen **after** exporting any pending local
  changes to a recovery file (see offline spec).
