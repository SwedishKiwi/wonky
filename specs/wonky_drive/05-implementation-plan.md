# Drive 05 · Implementation Plan

This plan builds Wonky Drive and the suite changes that come with it in milestone **M8 · Drive
+ suite changes** (suite [14 §2.1](../14-roadmap.md)): the unified drive with app homes, file
uploads and previews, the 50 MB quota, the settings split, the *Report a bug* button, and the
**shared-package extractions** that Slides needs (code, charts, number formats, sync kit, rich
text, fonts, spellcheck, the OS-8 space filter). The work is cut into **work packages D-1…D-18**
(§4) that parallel coding agents execute in **waves** (§2): each package is a few hours of agent
work, owns its folders, names the contracts it provides and consumes, and ends with acceptance
tests. The decisions of the [v2 review](../v2-review.md) are binding; v2 is **web only** (suite
[01 A13](../01-architecture.md)).

## 1. How Drive is built

- **New Flutter app `wonky_drive/`**, a pub workspace member like the other apps:
  `lib/main.dart` (`WonkyShell(config: DriveAppConfig())`), `lib/driver.dart` (flutter_driver
  entry, text entry emulation off), `lib/config/drive_app_config.dart`,
  `lib/features/{uploads,preview,storage,settings}/`, `lib/commands/`, `lib/mcp/`, `lib/l10n/`.
  Served at `/drive/` (`--base-href /drive/`), dev alias `drive` on web-port **8100** under
  `serverpod: flutter_apps:` (suite 01 §2.4). **Web only**: the `flutter create` desktop folders
  may exist so the package compiles everywhere, but no desktop feature (URL scheme, `desktop_drop`,
  packaging) is built.
- The site root `/` redirects to **Wonky Write's home** (`/write/`, v2 review Q2); Drive is
  reached from the left menu of every home.
- **Most UI is the shell's drive**, which already exists in `packages/wonky_app/lib/src/drive/`
  (home screen, list/grid, sidebar, details panel, dialogs, template gallery, drive controller)
  and today is shown filtered per app. v2 makes the shell drive **scope-aware**:
  `WonkyAppConfig.homeScope` (`HomeScope.kind(DriveItemKind)` for Write/Sheets/Slides,
  `HomeScope.all` for Drive) decides the kinds listed, the New menu, the left-menu navigation,
  the folder rule (suite 05 §3.2) and which features are on (tree, drag moves, file uploads).
  Drive adds only what the other homes don't have: the upload queue and panel, previews, the
  Storage page and Drive settings.
- `DriveAppConfig`: `app = WonkyAppKind.drive`, `appName = 'Wonky Drive'`, `primaryKind = null`
  (no editor of its own), `itemPath(uuid) = '/file/$uuid'`, `buildEditor` → `FilePreviewScreen`,
  `routes` → `/storage`, `homeScope = HomeScope.all`, `appSettingsSections` → Drive settings,
  `importHandler` → `DriveUploadHandler` (uploads files instead of importing),
  `mcpUiTools` → `ui.drive.*`.
- Drive opens no sync session (no Sheets/Slides replica, no Write document cache): it only uses
  the shell's drive cache and the upload queue store (suite 12 §3).

## 2. How the agents work

These rules apply to M8 and to the Slides milestones (Slides 12 §2 repeats only the deltas).

- **Machine budget**: the developer laptop has 16 GB of RAM. At most **5 agents** run at once,
  and at most **2** of them run the server test suite at the same time (each `dart test` in
  `wonky_server` starts its own embedded PostgreSQL). **Only one agent holds the web-build
  token** at a time: it is the only one that runs `flutter build web` / opens the release build
  at `http://localhost:8082/<app>/` (AGENTS.md); every other agent verifies with
  `dart test` / `flutter test` (widget tests and goldens) and `dart analyze`. The token holder
  per wave is named in §4.
- **Waves**: a wave is a set of ≤ 5 work packages whose dependencies are merged. A package of
  the next wave may start as soon as its own dependencies are merged and an agent slot is free,
  so waves overlap; the wave number is the earliest start, not a barrier.
- **Isolation**: all packages share the one working tree that `serverpod start` watches (code
  generation and hot reload see every change); folder ownership keeps agents apart and the
  orchestrator commits when a package's acceptance tests pass. Contract packages land first.
- **Ownership**: a package edits only its **owned folders**. Shared registration files
  (`wonky_server/lib/server.dart`, `config/*.yaml`, command registration indexes, `MenuSpec`
  trees, route tables, `pubspec.yaml` dependency lists, `tool/check_dependencies.dart` rules)
  get small additive edits only; conflicts there are resolved by the later merger.
- **Migrations**: one open migration at a time. A package that changes `.spy.yaml` table models
  rebases on `main`, runs `create_migration` (serverpod MCP; or the CLI fallback of AGENTS.md
  when no server runs) and merges promptly. Model changes that are known up front are batched
  into the contract package D-1.
- **Server**: agents never start the server (AGENTS.md). Packages whose acceptance needs a
  running server end with a note to the user to start `serverpod start`; the web-build token
  holder then runs the browser checks.
- **Done** = the package's acceptance tests, the suite DoD (14 §1) and §7 below; the spec is
  updated in the same change when the implementation differs.

## 3. Existing code to reuse

| Need | Start from |
|------|------------|
| Drive UI, homes, dialogs | `packages/wonky_app/lib/src/drive/` (`home_screen.dart`, `item_list.dart`, `drive_sidebar.dart`, `drive_controller.dart`, `details_panel.dart`, `template_gallery.dart`, `top_bar.dart`, `dialogs/`) |
| App identity, config | `packages/wonky_app/lib/src/bootstrap/app_urls.dart` (`WonkyAppKind {write, sheets}` with `other` → four values), `packages/wonky_app/lib/src/config/wonky_app_config.dart` (`ImportHandler`) |
| Settings | `packages/wonky_app/lib/src/settings/` (`settings_screen.dart`, `sections/`) |
| Root redirect, config.json | `wonky_server/lib/src/web/routes/{root_redirect_route.dart, app_config_route.dart}` |
| Files, uploads | `wonky_server/lib/src/platform/files/` (`file_service.dart`, `file_endpoint.dart`, `StoredFile`), `platform/drive/` (`drive_service.dart`, `import_service.dart`, `storage_usage.spy.yaml`) |
| Feedback (kept registered) | `wonky_server/lib/src/platform/feedback/` |
| Code highlighting | `wonky_write/lib/features/editor/styles/code_highlighter.dart`, `…/editor/model/code_languages.dart`, `wonky_write_core/lib/src/highlight/`, `third_party/syntax_highlight` |
| Charts | `wonky_sheets_core/lib/src/charts/` (`spec`, `data`, `layout`, `render`, `scene`, `three_d`, …), `wonky_sheets/lib/features/{charts,charts3d}/`, number formats in `wonky_sheets_core/lib/src/format/` |
| Sync kit | `wonky_sheets_core/lib/src/mutations/row_change.dart` (`RowChange`, `UndoInverter`), `wonky_sheets/lib/features/sync/` (`sheets_replica.dart`, `sheets_sync_controller.dart`, `sheets_writer.dart`, `change_journal.dart`, `remote_patch.dart`, `replica_recovery*.dart`, `storage_mode*.dart`), the session pattern `wonky_sheets/lib/features/model/{workbook_session,memory_workbook_session}.dart` |
| Spaces, OS patches | `wonky_server/lib/src/sheets/{spaces,sync,changelog}/`, `wonky_server/lib/src/sheets/models/space_reservation.spy.yaml`, `third_party/serverpod_offline_sync` (`PATCHES.md`) |
| Rich text, fonts, spelling, emoji | `wonky_write_core/lib/src/{delta,fonts,spellcheck}/`, `wonky_write/lib/features/{spellcheck,emoji}/` |

## 4. Work packages

### 4.1 Overview

| WP | Title | Wave | Depends on | Web-build token |
|----|-------|------|-----------|-----------------|
| D-1 | M8 contracts (server models, endpoint stubs, shell interfaces) | 1 | — | |
| D-2 | Extract `wonky_code` + `wonky_code_flutter` | 1 | — | |
| D-3 | Extract `wonky_numfmt` + `wonky_charts` + `wonky_charts_flutter` | 1 | — | |
| D-4 | Space kinds + offline-sync patch OS-8 | 1 | D-1 | |
| D-5 | Drive app scaffold, serving, root redirect, CI | 1 | D-1 (shell enum) | ✓ |
| D-6 | Extract `wonky_sync_kit` + `wonky_sync_kit_flutter` | 2 | — (after D-3 merged, both touch Sheets) | |
| D-7 | Extract `wonky_rich_text`, `wonky_fonts`, `wonky_spellcheck`; emoji/spelling glue → `wonky_app` | 2 | — (after D-2 merged, both touch Write) | |
| D-8 | Server: files, uploads, downloads, sniffing, previews, `kindMask` | 2 | D-1 | |
| D-9 | Server: storage quota service and enforcement | 2 | D-1 | |
| D-10 | Shell v2: scope-aware homes, left menu, routes, *Report a bug* | 2 | D-1 | ✓ |
| D-11 | Shell storage UI (meter, banner, dialog, error presenter) | 3 | D-1, D-10 | |
| D-12 | Settings split | 3 | D-10 | |
| D-13 | Drive: upload queue, upload panel, drops, downloads, *Open with* | 3 | D-5, D-8, D-10 | ✓ |
| D-14 | Drive: file previews | 3 | D-2, D-5, D-8 | |
| D-15 | MCP & AI for Drive (server tools) | 3 | D-8, D-9 | |
| D-16 | Write & Sheets adaptations | 4 | D-10, D-11, D-12 | |
| D-17 | Drive: Storage page, Drive settings, commands and keymap | 4 | D-11, D-12, D-13 | |
| D-18 | M8 integration: backfill dry run, E2E journeys, docs | 4 | all | ✓ |

Slides 12's **SL-1** (Slides app skeleton) runs in wave 4 next to D-16…D-18 (it needs D-5 and
D-10). Critical path: D-1 → D-8/D-9 → D-13 → D-17 → D-18 (quota in the upload flow). The shell
refactor (D-10) touches the most shared files: it lands early behind a compatibility default
(`homeScope` keeps today's behavior until D-16 switches the Write/Sheets configs).

```
wave 1   D-1 contracts ─┬─ D-4 OS-8          D-2 code ─────┐      D-3 charts ──┐
                        └─ D-5 scaffold                     │                   │
wave 2   D-8 files ── D-9 quota ── D-10 shell homes   D-7 rich text/fonts/spell  D-6 sync kit
wave 3   D-11 storage UI · D-12 settings · D-13 uploads · D-14 previews · D-15 MCP
wave 4   D-16 Write/Sheets · D-17 Storage page · D-18 integration · (Slides SL-1)
```

### 4.2 Wave 1 — contracts, extractions, serving

**D-1 · M8 contracts**
- Scope: every model change of M8 in **one migration**: `DriveItemKind.presentation/file`,
  `StoredFileKind.driveFile/preview`, `FileCategory`, `FileUploadState`, the new `DriveItem`
  columns (Drive 02 §1.1, incl. `kindMask`, `attachmentBytes`), `UserStorage`,
  `StorageReservation`, extended `StorageUsage`, `FileUploadRequest`/`FileUploadStart`/
  `FileUploadProgress`, `WonkyErrorCode.quotaExceeded`, `DriveChangeKind.storageChanged`,
  `NotificationKind.storage`, `SpaceKind {spreadsheet, deck}` + `kind` on `SpaceReservation`/
  `SpaceSubscription`, `UserPreferences.driveDefaults`/`slidesDefaults`. Endpoint signatures with
  stub bodies (Drive 02 §3.3, `drive.checkRoom`, `drive.listByStorage`, `drive.storageUsage`,
  `drive.registerPresentation`). `StorageService` interface (Drive 03 §4.2) with a pass-through
  implementation. Bump `minClientVersion` (old web clients can't read the new enum values,
  suite 01 §7). `wonky_core/lib/files/file_types.dart` (categories, convertible types, text
  extensions, language mapping). Shell: `WonkyAppKind {drive, write, sheets, slides}` (drop
  `other`), `AppUrls.apps` with four entries, `HomeScope`, `HomeNavSpec`,
  `WonkyAppConfig.{homeScope, homeNav, appSettingsSections, newItemRoute, importRoute}` with
  defaults that keep today's behavior, `StorageController` (`ValueListenable<StorageUsage?>`)
  and `FakeStorage` in `package:wonky_app/testing.dart`.
- Owns: `wonky_server/lib/src/platform/{drive,files,users,notifications,common}/**/*.spy.yaml`,
  `wonky_server/lib/src/sheets/models/` (space kind), new `wonky_server/lib/src/platform/storage/`
  (models + interface only), endpoint stub methods, `wonky_server/migrations/`,
  `wonky_core/lib/files/`, `packages/wonky_app/lib/src/{bootstrap,config}/`,
  `packages/wonky_app/lib/testing.dart`.
- Provides: every M8 model and endpoint signature, `StorageService`, `HomeScope`,
  `WonkyAppKind`, `StorageController`/`FakeStorage`, `file_types.dart`.
- Acceptance: generation and `dart analyze` clean; the migration applies to a copy of the
  development database; server, Write and Sheets test suites green (no behavior change);
  `file_types_test.dart` covers every category and the extension → language table; a test
  deserializes every new enum value through the client.

**D-2 · Extract `wonky_code` + `wonky_code_flutter`** (Slides 07 §2.1, Write 04 §15.5)
- Scope: `CodeLanguages`, `SyntaxToken`, `ScopeClassifier`, palettes (`SyntaxPalette`,
  `BuiltInPalettes`), `HighlightJsTokenizer`, the **copied TextMate engine** with embedded
  grammars (`TextMateTokenizer`, v2 review Q26), `DefaultCodeTokenizer` facade, `CodeView` and
  `CodeTextStyler` in `wonky_code_flutter`; `SequenceDiff` generalized in `wonky_core`; Write's
  editor switched to the shared tokenizer (same colors); Write's **exports keep highlight.js**
  until M10 (Q17/Q25); `third_party/syntax_highlight` and its `pubspec_overrides.yaml` entry
  deleted; dependency rows of suite 01 §2.1 in `tool/check_dependencies.dart`.
- Owns: `packages/wonky_code/`, `packages/wonky_code_flutter/`,
  `wonky_write/lib/features/editor/{styles/code_highlighter.dart,model/code_languages.dart}`,
  `wonky_write_core/lib/src/{highlight,theme/model/syntax_token.dart}` (re-exports),
  `wonky_core/lib/src/diff/`, `third_party/syntax_highlight/`.
- Provides: `CodeTokenizer`, `CodeLanguages`, `SyntaxPalette`, `CodeView` (for D-14 and Slides).
- Acceptance: Write 04 AC-15.1/15.2; Write editor and export goldens unchanged; the vendored
  patch tests run as `wonky_code/test/textmate/` (every grammar highlights its sample and every
  prefix); `dart run tool/check_dependencies.dart` passes.

**D-3 · Extract `wonky_numfmt` + `wonky_charts` + `wonky_charts_flutter`** (Slides 08 §2,
v2 review Q27)
- Scope: migration order of Slides 08 §2.9 steps 1–4 (number formats, engine, Flutter
  painter and 3D GPU backend, tests with their code); Sheets core re-exports what Sheets
  imports; `flutter_scene`/`vector_math` move out of `wonky_sheets`' direct dependencies. The
  new APIs of 08 §2.7 are **not** in scope (SL-27, M10).
- Owns: `packages/wonky_numfmt/`, `packages/wonky_charts/`, `packages/wonky_charts_flutter/`,
  `wonky_sheets_core/lib/src/{charts,format/number_format}/`,
  `wonky_sheets/lib/features/{charts/render,charts3d}/`.
- Provides: `ChartSpec`/`ChartData`/scene/renderers, `ChartPainter`, number-format engine.
- Acceptance: all Sheets core and app tests green; chart scene JSON goldens byte-identical;
  Sheets chart goldens (2D and 3D) unchanged; dependency check passes.

**D-4 · Space kinds + OS-8** (suite 12 §2.6, Slides 02 §9.2, v2 review Q19)
- Scope: vendored patch **OS-8** — `offlineSync.sync(…, spaceFilter:)` — with tests and a
  `PATCHES.md` entry; Sheets' `spaces/` service generalized to `platform/spaces/`
  (`SpaceService` with `SpaceKind`, reservations and subscriptions per kind, active-set limits
  per kind); `sheetsSync` passes spreadsheet spaces + the personal space.
- Owns: `third_party/serverpod_offline_sync/`, `wonky_server/lib/src/sheets/spaces/` →
  `wonky_server/lib/src/platform/spaces/`, `wonky_server/lib/src/sheets/sync/` (filter call).
- Consumes: D-1 (`SpaceKind` columns). Provides: `SpaceService` for Slides (SL-5).
- Acceptance: vendored suite + patch tests green; a server test creates a `deck` space for a
  member and asserts the Sheets replica never receives its rows; Sheets sync harness and offline
  merge fuzzer green.

**D-5 · Drive app scaffold, serving, root redirect, CI** — web-build token
- Scope: `wonky_drive` package (§1; `DriveAppConfig` with an empty Storage route), workspace
  member, CI matrix rows; `flutter_build` builds every existing app folder in parallel
  (`drive`, `write`, `sheets`, later `slides`); `webApps` + `FlutterRoute` for `/drive/`;
  `AppConfigRoute` serves `apps: {drive, write, sheets, slides}`; **`RootRedirectRoute` always
  → `/write/`** (cookie ignored); `flutter_apps` alias `drive` (8100); `allowedOrigins` and the
  bundled dev `config.json` with all four origins; web icons and favicon; AGENTS.md (app list,
  `driver.dart`, alias, release build command for `/drive/`).
- Owns: `wonky_drive/` (scaffold: `pubspec.yaml`, `lib/{main,driver}.dart`, `lib/config/`,
  `web/`), `wonky_server/{pubspec.yaml,config/*.yaml}`, `wonky_server/lib/src/web/`,
  web-route registration in `wonky_server/lib/server.dart`, root `pubspec.yaml` (workspace),
  `.github/workflows/`, `AGENTS.md`.
- Consumes: D-1 (`WonkyAppKind.drive`; start with the server/CI part until it lands).
- Acceptance: server test — `GET /` answers `302 /write/` with and without a `wonky_last_app`
  cookie; `/drive/` serves the Drive build with the SPA fallback; `config.json` lists four apps;
  the release web build of Drive boots, shares the sign-in with `/write/` and shows the (still
  unscoped) home.

### 4.3 Wave 2 — services, shell, remaining extractions

**D-6 · Extract `wonky_sync_kit` + `wonky_sync_kit_flutter`** (Slides 12 §5.1–5.2)
- Scope: pure `RowChange`, `RowOp`, `ChangeSummary`, `MutationPlan`, `CoupledColumns`,
  `UndoInverter`, `SyncTxAdapter` (Sheets' cell-specific undo rule becomes a table hook);
  Flutter `SyncReplica`, `AppSyncController`, `SyncWriter`, `ChangeJournal`, recovery export
  plumbing and storage-mode detection; Sheets switched to them (its `WorkbookSession` and
  `SyncedWorkbookSession` keep their API).
- Owns: `packages/wonky_sync_kit/`, `packages/wonky_sync_kit_flutter/`,
  `wonky_sheets_core/lib/src/mutations/row_change.dart`, `wonky_sheets/lib/features/sync/`,
  `wonky_sheets/lib/features/model/sheets_undo.dart`.
- Provides: the contracts of Slides 12 §5.1–5.2 under those names.
- Acceptance: Sheets core/app suites, the multi-client sync harness and the offline merge
  fuzzer green; dependency check (pure half Flutter-free) passes.

**D-7 · Extract `wonky_rich_text`, `wonky_fonts`, `wonky_spellcheck`** (v2 review Q4, Q23)
- Scope: Delta inline schema/attribute keys, normalizer and the Markdown inline codec pieces
  Slides needs → `wonky_rich_text` (re-exported by `wonky_write_core`); the font registry and
  bundled TTFs → `wonky_fonts` (Slides 05 §3.1 manifest API; Slides display families are added
  by SL-6); the Hunspell engine → `wonky_spellcheck`; `SpellEngine`, dictionary loading,
  spelling dialogs and the emoji picker → `wonky_app` (`lib/src/{spellcheck,emoji}/`).
- Owns: `packages/{wonky_rich_text,wonky_fonts,wonky_spellcheck}/`,
  `wonky_write_core/lib/src/{delta,fonts,spellcheck}/` (moves + re-exports),
  `wonky_write/lib/features/{spellcheck,emoji}/`, `packages/wonky_app/lib/src/{spellcheck,emoji}/`.
- Acceptance: Write core/app suites and goldens green; Write spellcheck and emoji widget tests
  pass from their new homes; dependency check passes.

**D-8 · Server: files, uploads, downloads, sniffing, previews** (Drive 02)
- Scope: `createFileUpload`/`completeFileUpload`/`cancelFileUpload`/`fileUploadStatus`,
  `fileContentUrl`, `updateFileMeta`, `convertFile`; `FileTypeSniffer`; `GET /files/d/…`
  downloads and `PUT /files/upload/:fileUuid` token uploads (suite 13 §6 headers); preview and
  thumbnail FutureCall; `drive.expireUploads`; `kindMask` maintenance + nightly recompute +
  `filter.foldersContaining`; search filters by kinds/categories; `drive.registerPresentation`
  (idempotent, for Slides). Uploads call `StorageService.reserve/commit/release`.
- Owns: `wonky_server/lib/src/platform/{drive,files}/` (code), `test/fixtures/files/`.
- Acceptance: every endpoint of Drive 02 per role (`forEachRole`); ≥ 40 sniffer vectors incl.
  spoofed extensions and polyglots; download headers; `kindMask` property test (random
  create/move/trash/restore/delete sequences ≡ full recompute); upload expiry.

**D-9 · Server: storage quota service and enforcement** (Drive 03) — starts with spike S-D3
- Scope: `StorageService` implementation, reservations, `quotaExceeded`; enforcement hooks in
  every path of Drive 03 §7.2 except the upload endpoints (D-8) — copies, transfers, imports,
  image uploads in Write/Sheets, version restore copies; size estimators (documents in the OT
  service, `SheetsSizeEstimator`, the Slides estimator interface); reconcile and backfill
  FutureCalls; `storageChanged` drive events; `NotificationKind.storage` notice; no grace period
  (Q15); restores from trash never blocked (Q16).
- Owns: `wonky_server/lib/src/platform/storage/`; one-line hooks in `write/ot`,
  `sheets/changelog`, `platform/{sharing,drive}`.
- Acceptance: Drive 03 §7.2 table row by row; parallel reservation race (`Future.wait`); AC-D3.2,
  D3.4–D3.7 server parts; reconcile property test; backfill idempotent and resumable.

**D-10 · Shell v2: homes, left menu, routes, *Report a bug*** — web-build token
- Scope: `HomeScope` in `DriveHomeScreen`/`DriveController` (kind filter, folder rule via
  `foldersContaining`, New menu, features per scope); `HomeSidebar` (apps section, `homeNav`,
  bottom section with a slot for the storage meter); routes `/f/:uuid` (+ redirect of
  `/drive/:uuid`), `/my-files`/`/my-drive`, the `/new` and `/import` route contracts; *Open in
  Wonky Drive*; account menu *Open ▸* four apps; editor title-row *Report a bug* button,
  `shell.help.reportBug` with the new-issue URL builder (no user content, Q8) and
  `.github/ISSUE_TEMPLATE/bug_report.yml`; Help menu: *Report a bug* replaces *Report a
  problem* (`shell.help.feedback` stays registered, Q6).
- Owns: `packages/wonky_app/lib/src/{drive,shell,routing,branding,menus}/`,
  `.github/ISSUE_TEMPLATE/`.
- Provides: scope-aware homes for D-13, D-16 and Slides SL-11.
- Acceptance: widget tests and light/dark goldens of `HomeSidebar` and a scoped home; the URL
  builder test (fields, 2,000-character fallback, no ids/emails); existing shell tests green
  with the compatibility default; in the release build, Write's home lists all kinds as before
  until D-16.

### 4.4 Wave 3 — user-facing features

**D-11 · Shell storage UI** (Drive 03 §6)
- Scope: `StorageController` implementation on `drive.storageUsage` + `storageChanged` events
  (offline: last cached value), `StorageMeter`, `StorageBanner` (≥ 90 %, over quota),
  `QuotaExceededDialog` variants (self / owner), `QuotaErrorPresenter` for `quotaExceeded` errors
  from any call; meter in the left menu slot.
- Owns: `packages/wonky_app/lib/src/storage/`.
- Acceptance: widget tests + light/dark goldens of meter, banner and every dialog variant;
  banner disappears live on a fake `storageChanged`.

**D-12 · Settings split** (suite 04 §4)
- Scope: settings frame with the app group and the Wonky Work group; `/settings/:section` and
  `/settings/app[/:section]`; re-homed sections per suite 04 §4.1 (Keyboard shortcuts in Wonky
  Work settings with *Shared*/*<App>* groups, Q10); `appSettingsSections` hosting; redirects of
  old section ids; Settings › Wonky Work › Storage; moving Write's and Sheets' sections from the
  shell into their apps (`lib/features/settings/`); `UserPreferences` columns.
- Owns: `packages/wonky_app/lib/src/settings/`, `wonky_write/lib/features/settings/`,
  `wonky_sheets/lib/features/settings/`, `wonky_server/lib/src/platform/users/` (code).
- Acceptance: J-D6 as a widget test per app; old `/settings/write` redirects; every setting
  command still invocable via `ui.invoke_command`.

**D-13 · Drive: uploads, drops, downloads, *Open with*** — web-build token; starts with spike
S-D2
- Scope: upload queue (`LocalPendingUpload` v2 columns, OPFS/IndexedDB limits of Drive 02
  §4.1, offline queueing), upload panel, drop overlay (web drop events only), options dialog
  for name conflicts, client pre-check (`checkRoom`), whole-file retries (Q12; no chunking),
  downloads via hidden anchor, *Open with* → `/import?file=` of the target app.
- Owns: `wonky_drive/lib/features/uploads/`, `wonky_drive/lib/commands/upload_commands.dart`,
  upload store in `packages/wonky_app/lib/src/data/` (additive).
- Acceptance: J-D2 (upload parts), J-D3 (pre-check dialog, forced-upload refusal), J-D8 in the
  release build; `UploadPanel` state goldens; queue survives a reload (OPFS).

**D-14 · Drive: file previews** — starts with spike S-D1
- Scope: `FilePreviewScreen` (`/file/:uuid`), image viewer, PDF viewer (S-D1 library,
  self-hosted worker), text/code viewer on `CodeView` (D-2), CSV table (P1), "everything else"
  card, error states for malformed files.
- Owns: `wonky_drive/lib/features/preview/`.
- Acceptance: each viewer tested with a valid and a malformed fixture (truncated PNG, broken
  PDF, binary named `.txt`) → error state, not a crash; light/dark goldens; preview budgets of
  suite 11 §2 measured on the fixtures.

**D-15 · MCP & AI for Drive** (Drive 01 §3, suite 09)
- Scope: `drive.upload_file`, `drive.create_upload`/`drive.complete_upload`,
  `drive.download_file`, `drive.convert_file`, `drive.get_storage`, `kinds` filters, `storage`
  in results, `quota_exceeded` mapping; `ui.drive.*` definitions (P1).
- Owns: `wonky_core/lib/mcp/drive_tools.dart`, `wonky_server/lib/src/platform/mcp/drive_tool_handlers.dart`,
  `wonky_drive/lib/mcp/`.
- Acceptance: J-D9 as an MCP integration test through `/mcp`; tool schemas validated.

### 4.5 Wave 4 — adaptations and integration

**D-16 · Write & Sheets adaptations**
- Scope: Write/Sheets home configs (`HomeScope.kind`, `homeNav`, template strips), *Import
  file…* label, `/new` and `/import?file=` routes, Help menu and title-row *Report a bug*,
  quota error handling on image inserts and imports (`QuotaErrorPresenter`), storage banner in
  editors.
- Owns: `wonky_write/lib/{config,features/{import,images}}/`, `wonky_sheets/lib/{config,features/{import,images,import_export}}/`.
- Acceptance: J-D5, J-D7; Write and Sheets suites green; an image insert over quota shows the
  owner dialog (AC-D3.3, widget level).

**D-17 · Drive: Storage page, settings, commands**
- Scope: Storage page (`/storage`: breakdown, largest items, trash, versions, *Free up space*),
  Drive settings section (*Convert uploads* default off, Q13), Drive command set and keymap,
  `ui.drive.*` handlers (P1).
- Owns: `wonky_drive/lib/features/{storage,settings}/`, `wonky_drive/lib/commands/` (except
  uploads), `wonky_drive/lib/mcp/` (UI handlers).
- Acceptance: Storage page goldens light/dark; every Drive command passes execute → undo → redo
  where undoable; J-D10 server part green.

**D-18 · M8 integration** — web-build token
- Scope: backfill dry run on a production copy (S-D3 numbers recorded in Drive 03 §2),
  a web E2E runner (`flutter drive` + chromedriver against the release builds; today's
  `e2e.yml` runs on macOS only, TODO.md), E2E journeys §6 on the web, AGENTS.md and spec
  touch-ups, the M8 exit checklist of suite 14 §2.1.
- Owns: `wonky_drive/integration_test/`, `wonky_write/integration_test/` and
  `wonky_sheets/integration_test/` (new v2 journeys only), `AGENTS.md`, `specs/`.
- Acceptance: J-D1…J-D10 pass; M8 exit criteria met.

## 5. Spikes (timeboxed, inside their package)

| ID | In | Question | Timebox | Exit |
|----|----|----------|---------|------|
| S-D1 | D-14 | PDF rendering under cross-origin isolation: `printing` raster with self-hosted pdf.js vs `pdfrx` (PDFium WASM) — bundle size, speed on a 100-page PDF, memory | 4 h | Chosen library + `web/` assets recipe in 02 §6.3 |
| S-D2 | D-13 | Web upload plumbing: large blobs (50 MB) in OPFS via `sqlite_async`, folder drops (`webkitGetAsEntry`), XHR progress through Serverpod's `FileUploader` on web | 4 h | Confirmed limits in 02 §4.1, folder upload in or out of M8 |
| S-D3 | D-9 | Cost of `SheetsSizeEstimator` (`pg_column_size` over a 1M-cell space) and of the backfill on a production-sized copy | 2 h | Cadence in 03 §2 confirmed or an incremental estimate chosen |

## 6. Acceptance tests (M8 exit)

E2E journeys on the **web** release builds (`integration_test` via the `dart` MCP
flutter_driver, suite 11 §1.1):

| # | Journey |
|---|---------|
| J-D1 | Sign in at `/` → lands on Wonky Write's home (`/write/`); the left menu shows the four apps and the meter "x MB of 50 MB used"; *Wonky Drive* opens `/drive/` |
| J-D2 | Upload 3 files by drag-and-drop into a new folder; preview the image, the PDF and a `.dart` file in light and dark; download one |
| J-D3 | Upload until the quota is full: the pre-check dialog, the server refusal on a forced upload, the over-quota banner in Drive and in the Write home; empty trash → banner disappears live |
| J-D4 | *Open with Wonky Sheets* on a CSV → spreadsheet opens in Sheets; Back returns to Drive |
| J-D5 | Write home lists only documents and the folders that contain documents; *Open in Wonky Drive* shows the same folder with all kinds |
| J-D6 | Settings split: *Write settings* from the left menu shows the Write sections; *Wonky Work settings* from the account menu shows Account…About; old `/settings/write` redirects |
| J-D7 | *Report a bug* in the Sheets editor header and Help menu shows the confirm popover and opens the prefilled GitHub new-issue page externally |
| J-D8 | Offline: drop 2 files → "Waiting for connection"; reconnect → both upload |
| J-D9 | MCP: `drive.upload_file` (text), `drive.get_storage`, `drive.download_file`, `drive.convert_file` → document; a too-large upload returns `quota_exceeded` |
| J-D10 | Ownership transfer of a large spreadsheet to a nearly full user is refused; after they free space, it succeeds |

Server tests: every endpoint of 02/03 for each role (`forEachRole`, suite 15), enforcement table
03 §7.2 row by row, reservation races, reconcile property test (03 AC-D3.7), backfill
idempotency, sniffer vectors. Widget tests and goldens (light/dark) for `HomeSidebar`,
`StorageMeter`, `StorageBanner`, the quota dialog variants, `UploadPanel` states, each viewer and
the Storage page. Every new command gets the execute→undo→redo test where undoable (suite 08 §4).
The extractions (D-2, D-3, D-6, D-7) are accepted only with the Write and Sheets suites and
goldens unchanged.

## 7. Definition of done (Drive additions)

Suite DoD (14 §1) plus: every byte-adding path has a quota test; every viewer is tested with a
malformed file and shows the error state, not a crash; the left menu and settings split are
verified in all apps that exist at the time (Drive, Write, Sheets; Slides with SL-1); no
desktop-only code paths are added (suite 01 A13); `AGENTS.md` lists the Drive app, its
`driver.dart`, the `drive` alias and the release build command.

## 8. Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| PDF rendering on web under COEP (pdf.js from a CDN is blocked) | No PDF previews | S-D1; self-host the worker; fallback "Download to view" |
| Large blobs in web local storage (IndexedDB fallback keeps the DB in memory) | Memory pressure, lost queued uploads | 5 MB cap for persisted blobs without OPFS; volatile rows with a clear message (02 §4.1) |
| Size estimates for big spreadsheets are expensive or jumpy | DB load, confusing meters | S-D3; throttled estimator; incremental fallback; reconcile |
| Existing users above 50 MB after the backfill | Support load, frustration | Non-destructive over-quota state, clear notification and Storage page; no grace (Q15) |
| Four web builds in `flutter_build` (deploy pre-hook time, CI minutes) | Slower deploys | Build apps in parallel in the script; cache Flutter; build only changed apps in CI |
| Old cached web clients and new enum values | Crashes on drive lists | `minClientVersion` bump (D-1) |
| Extractions destabilize Write/Sheets | Regressions | Pure moves with re-exports; existing suites and goldens are the acceptance gate (D-2, D-3, D-6, D-7) |
| Shell refactor collides with Slides work | Merge conflicts in `wonky_app` | D-10 lands in wave 2 behind a compatibility default; Slides UI starts on the scope-aware shell |
| Parallel agents exhaust the 16 GB laptop | Swapping, flaky tests | ≤ 5 agents, ≤ 2 server test runs, one web-build token (§2) |
| Upload abuse (bandwidth, storage filling across many accounts) | Cost | Quota, per-user pending-upload cap, rate limits (suite 13 §6) |
