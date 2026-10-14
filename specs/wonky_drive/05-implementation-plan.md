# Drive 05 · Implementation Plan

This plan builds Wonky Drive and the suite changes that come with it in milestone **M8 · Drive
+ suite changes** (suite [14 §2](../14-roadmap.md)): the unified drive with app homes, file
uploads and previews, the 50 MB quota, the settings split, the *Report a bug* button, and the
extraction of the shared code and chart packages that Slides needs in M10. Workstreams are
named **WS-D\***; each owns folders so they can run in parallel (suite 14 §1).

## 1. How Drive is built

- **New Flutter app `wonky_drive/`** (web + desktop), a pub workspace member like the other apps:
  `lib/main.dart` (`WonkyShell(config: DriveAppConfig())`), `lib/driver.dart` (flutter_driver
  entry, text entry emulation off), `lib/config/drive_app_config.dart`,
  `lib/features/{uploads,preview,storage,settings}/`, `lib/commands/`, `lib/mcp/`, `lib/l10n/`.
  Served at `/drive/` (`--base-href /drive/`), dev alias `drive` on web-port **8100** under
  `serverpod: flutter_apps:` (suite 01 §2.4).
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

## 2. Workstreams

| ID | Workstream | Owns | Depends on |
|----|------------|------|-----------|
| WS-D1 | **Server: kinds, files, uploads, downloads** — `DriveItemKind.presentation/file`, `FileCategory`, `FileUploadState`, DriveItem columns, `createFileUpload`/`completeFileUpload`/`cancelFileUpload`/`fileUploadStatus`/`fileContentUrl`/`updateFileMeta`/`convertFile`, `FileTypeSniffer`, `/files/d/…` download route, preview/thumbnail FutureCall, `drive.expireUploads`, `kindMask` maintenance, search filters by kinds/categories | `wonky_server/lib/src/platform/{drive,files}`, `wonky_core/lib/files/` | — |
| WS-D2 | **Server: storage quota** — `UserStorage`, `StorageReservation`, `StorageService`, `quotaExceeded`, enforcement hooks in every path of 03 §7.2, size estimators (documents in OT service, `SheetsSizeEstimator`), reconcile + backfill FutureCalls, `storageChanged` drive events, `NotificationKind.storage` | `wonky_server/lib/src/platform/storage/` (new); small hooks in `write/ot`, `sheets/changelog`, `platform/{sharing,files,drive}` | WS-D1 (models) |
| WS-D3 | **Shell v2** — `WonkyAppKind {drive, write, sheets, slides}`, `HomeScope`, app homes filtered to their kind, `HomeSidebar` (app links, nav, bottom section), folder route `/f/:uuid` (+ redirect), `/new` and `/import` route contracts, *Open in Wonky Drive*, `StorageMeter`/`StorageBanner`/`QuotaExceededDialog`/`QuotaErrorPresenter`, account menu changes, header *Report a bug* button, `shell.help.reportBug`, `shell.settings.openApp` | `packages/wonky_app/lib/src/{drive,shell,storage,routing,branding}` | WS-D1/D2 contracts |
| WS-D4 | **Settings split** — settings frame with app group + Wonky Works group, `/settings/app[/:section]`, re-homed sections (suite 04 §4.1 table), `WonkyAppConfig.appSettingsSections`, redirects of old section ids, `UserPreferences.driveDefaults`/`slidesDefaults`, Settings › Wonky Works › Storage | `packages/wonky_app/lib/src/settings/`, server `platform/users` (preferences columns) | WS-D3 |
| WS-D5 | **Drive app scaffold & serving** — `wonky_drive` package, workspace + CI matrix, `flutter_build` (4 apps), `webApps`/`AppConfigRoute` (`apps: {drive, write, sheets, slides}`), root redirect `/` → `/drive/`, `flutter_apps` alias `drive` (8100), `allowedOrigins` for the new dev ports, platform icons, macOS target + `wonkydrive://` (P1), AGENTS.md | `wonky_drive/` (scaffold), `wonky_server/{pubspec.yaml,lib/server.dart,lib/src/web}`, `.github/workflows`, `AGENTS.md` | — |
| WS-D6 | **Drive UI** — upload queue + panel + drop overlay + options dialog, offline queue (`LocalPendingUpload` v2 columns), file previews (image, PDF, text/code, CSV P1), *Open with*, downloads, Storage page, Drive settings section, Drive commands and keymap | `wonky_drive/lib/features/**`, `wonky_drive/lib/commands/` | WS-D1, WS-D3, WS-D5; `wonky_code_flutter` (WS-D9) for text previews (fallback: plain text until it lands) |
| WS-D7 | **Write & Sheets adaptations** — home configs (scope, nav, template strips), app settings sections (moved from the shell), *Import file…* label, `/new` and `/import?file=` routes, help menu *Report a bug*, title-row bug button placement, quota error handling on image inserts and imports | `wonky_write/lib/config`, `…/features/{home,settings,import}`, same in `wonky_sheets` | WS-D3, WS-D4 |
| WS-D8 | **MCP & AI for Drive** — `drive.upload_file`, `drive.create_upload`/`drive.complete_upload`, `drive.download_file`, `drive.convert_file`, `drive.get_storage`, `kinds` filters, `storage` in results, `quota_exceeded` mapping; `ui.drive.*` (P1); Drive assistant panel (P1) | `wonky_core/lib/mcp/drive_tools.dart`, `wonky_server/lib/src/platform/mcp/`, `wonky_drive/lib/mcp/` | WS-D1, WS-D2 |
| WS-D9 | **Shared package extraction (no behavior change)** — `wonky_code` + `wonky_code_flutter` from Write's highlighting (Write 04 §15.5), `wonky_charts` + `wonky_charts_flutter` from the Sheets chart engine (Sheets 08 §24); dependency rules + `tool/check_dependencies.dart` (suite 01 §2.1) | `packages/wonky_code*`, `packages/wonky_charts*`, moves out of `wonky_write`, `wonky_write_core`, `wonky_sheets_core`, `wonky_sheets` | — (parallel; must finish before M10) |

## 3. Contracts to stub first (week 1)

1. Models: enum values (`DriveItemKind`, `StoredFileKind`, `FileCategory`, `FileUploadState`,
   `WonkyErrorCode.quotaExceeded`, `DriveChangeKind.storageChanged`, `NotificationKind.storage`),
   DriveItem columns, `UserStorage`, `StorageReservation`, extended `StorageUsage`,
   `FileUploadRequest`/`FileUploadStart`/`FileUploadProgress` — one migration.
2. Endpoint signatures with stubs: 02 §3.3, `drive.checkRoom`, `drive.listByStorage`,
   `drive.storageUsage` (extended).
3. Shell: `WonkyAppKind` (4 values), `HomeScope`, `HomeNavSpec`, `WonkyAppConfig.homeScope`,
   `homeNav`, `appSettingsSections`, `newItemRoute`, `importRoute`; `StorageController`
   (`ValueListenable<StorageUsage?>`) with a fake; `FakeStorage` in `package:wonky_app/testing.dart`.
4. `wonky_core/lib/files/file_types.dart` (categories, convertible types, text extensions,
   language mapping) with tests.
5. **Protocol**: bump `minClientVersion` — old web clients can't deserialize the new
   `DriveItemKind` values (byName enums throw on unknown names), so they must reload (suite 03
   §4 *version mismatch*, suite 01 §7).

## 4. Order (M8)

```
week 1   contracts (§3) · spikes S-D1…S-D3 · WS-D5 scaffold (Drive app boots at /drive/)
week 2-3 WS-D1 server files ── WS-D2 quota service + enforcement ── WS-D3 shell v2 (homes, left menu)
         WS-D9 extraction (parallel, independent)
week 4-5 WS-D6 uploads + previews + storage page ── WS-D4 settings split ── WS-D7 Write/Sheets
         WS-D8 MCP tools
week 6   backfill dry run on a production copy · E2E journeys (§6) · polish · docs (AGENTS.md, specs)
```

Critical path: WS-D1 → WS-D2 → WS-D6 (quota in the upload flow). The shell refactor (WS-D3)
touches the most shared files: it lands early behind a compatibility layer
(`homeScope` defaults to today's behavior until the Write/Sheets configs switch in WS-D7).

## 5. Spikes (timeboxed)

| ID | Question | Timebox | Exit |
|----|----------|---------|------|
| S-D1 | PDF rendering under cross-origin isolation: `printing` raster with self-hosted pdf.js vs `pdfrx` (PDFium WASM) — bundle size, speed on a 100-page PDF, memory | 2 d | Chosen library + `web/` assets recipe in 02 §6.3 |
| S-D2 | Web upload plumbing: large blobs (50 MB) in OPFS via `sqlite_async`, folder drops (`webkitGetAsEntry`), XHR progress through Serverpod's `FileUploader` on web | 2 d | Confirmed limits in 02 §4.1, folder upload in or out of M8 |
| S-D3 | Cost of `SheetsSizeEstimator` (`pg_column_size` over a 1M-cell space) and of the backfill on a production-sized copy | 1 d | Cadence in 03 §2 confirmed or an incremental estimate chosen |

## 6. Acceptance tests (M8 exit)

E2E journeys (web + macOS, `integration_test` via the `dart` MCP flutter_driver, suite 11 §1.1):

| # | Journey |
|---|---------|
| J-D1 | Sign in at `/` → lands on `/drive/`; the left menu shows the four apps, the meter "x MB of 50 MB used" |
| J-D2 | Upload 3 files by drag-and-drop into a new folder; preview the image, the PDF and a `.dart` file in light and dark; download one |
| J-D3 | Upload until the quota is full: the pre-check dialog, the server refusal on a forced upload, the over-quota banner in Drive and in the Write home; empty trash → banner disappears live |
| J-D4 | *Open with Wonky Sheets* on a CSV → spreadsheet opens in Sheets; Back returns to Drive |
| J-D5 | Write home lists only documents and the folders that contain documents; *Open in Wonky Drive* shows the same folder with all kinds |
| J-D6 | Settings split: *Write settings* from the left menu shows the Write sections; *Wonky Works settings* from the account menu shows Account…About; old `/settings/write` redirects |
| J-D7 | *Report a bug* in the Sheets editor header and Help menu shows the confirm popover and opens the GitHub issues page externally |
| J-D8 | Offline: drop 2 files → "Waiting for connection"; reconnect → both upload |
| J-D9 | MCP: `drive.upload_file` (text), `drive.get_storage`, `drive.download_file`, `drive.convert_file` → document; a too-large upload returns `quota_exceeded` |
| J-D10 | Ownership transfer of a large spreadsheet to a nearly full user is refused; after they free space, it succeeds |

Server tests: every endpoint of 02/03 for each role (`forEachRole`, suite 15), enforcement table
03 §7.2 row by row, reservation races (parallel uploads in one test with `Future.wait`),
reconcile property test (03 AC-D3.7), backfill idempotency, sniffer vectors (≥ 40 sample files
in `test/fixtures/files/`, including spoofed extensions and polyglots). Widget tests and
goldens (light/dark) for `HomeSidebar`, `StorageMeter`, `StorageBanner`, the quota dialog
variants, `UploadPanel` states, each viewer and the Storage page. Every new command gets the
execute→undo→redo test where undoable (suite 08 §4).

## 7. Definition of done (Drive additions)

Suite DoD (14 §1) plus: every byte-adding path has a quota test; every viewer is tested with a
malformed file (truncated PNG, broken PDF, binary named `.txt`) and shows the error state, not a
crash; the left menu and settings split are verified in all four apps; `AGENTS.md` lists the
Drive app, its `driver.dart` and the `drive` alias.

## 8. Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| PDF rendering on web under COEP (pdf.js from a CDN is blocked) | No PDF previews | S-D1; self-host the worker; fallback "Download to view" |
| Large blobs in web local storage (IndexedDB fallback keeps the DB in memory) | Memory pressure, lost queued uploads | 5 MB cap for persisted blobs without OPFS; volatile rows with a clear message (02 §4.1) |
| Size estimates for big spreadsheets are expensive or jumpy | DB load, confusing meters | S-D3; throttled estimator; incremental fallback; reconcile |
| Existing users above 50 MB after the backfill | Support load, frustration | Non-destructive over-quota state, clear notification and Storage page; decision on grace (03 §9) |
| Four web builds in `flutter_build` (deploy pre-hook time, CI minutes) | Slower deploys | Build apps in parallel in the script; cache Flutter; consider building only changed apps in CI |
| Old cached web clients and new enum values | Crashes on drive lists | `minClientVersion` bump (§3) |
| Shell refactor collides with Slides M9 work | Merge conflicts in `wonky_app` | WS-D3 lands first in M8; Slides starts on the scope-aware shell |
| Upload abuse (bandwidth, storage filling across many accounts) | Cost | Quota, per-user pending-upload cap, rate limits (suite 13 §6) |
