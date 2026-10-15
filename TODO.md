# Wonky Work — TODO

The first iteration delivers **Wonky Write** (sign-in, drive, sharing, a real-time
collaborative editor, comments, suggestions, history, themes, import and export) and
**Wonky Sheets** (offline-first synced spreadsheets: grid, formulas, formatting,
conditional formatting, data tools, validation, protection, pivots, charts, import/export/print,
collaboration and history, MCP and AI). The specs in `specs/` remain the source of truth.
This file lists what is not done yet; the Sheets state per area is in
[specs/wonky_sheets/STATUS.md](specs/wonky_sheets/STATUS.md).

Status legend: ☐ open · ◐ in progress · ☑ done (done items are removed once they are
committed and verified).

## Wonky Write — deferred features (in planned order)

1. ☑ **Theme editor UI** (Write 06 §10): `/themes/:uuid?doc=` with a live preview (sample or the document, light/dark, pages/pageless, zoom), a catalog-driven inspector for every theme property, contrast warnings with *Fix*, dark derivation and overrides, duplicate/rename/delete/restore, revisions, conflict dialog, *Apply to document* and *Set as my default*; all `write.theme.*` commands, undoable. Still open: hover-outlining of matching blocks in the preview.
2. ☑ **Import/export formats** (Write 07): DOCX, ODT, RTF and EPUB exporters plus DOCX, ODT and RTF importers in `wonky_write_core`. Exporting and re-importing our own files gives back the same document for all 8 themes, except that RTF brings heading numbers back as text. Server `writeExport.export` covers all 10 formats, with bundled fonts in `web/fonts` and images read from storage; `drive.import` and `convertForInsert` accept HTML, DOCX, ODT and RTF. In the app, File › Download lists every format, and File › Import / Insert from file accept them; the import banner shows on first open. Still open:
   - the server export cache and the isolate pool; large documents still export on the client;
   - SVG images in DOCX/ODT/RTF/EPUB (rendered as placeholders);
   - comments in DOCX/ODT exports and embedded DOCX fonts (both P2);
   - LibreOffice and epubcheck validation in CI.
3. ☑ **MCP** (suite 09, Write 09) — `/mcp` Streamable HTTP route on the web server (custom
   `mcp_dart` transport; MCP 2026-07-28 stateless + initialize-era sessions), PAT bearer auth
   with scopes, host/origin checks and rate limits; `ToolExecutor` with `drive.*`, `write.*`
   (23 tools), `comments.*`, `versions.*`, `changes.revert`, resources and prompts; UI bridge
   (`uiBridge.connect` + `UiBridgeHub`, client bridge with shared `ui.*` and `ui.write.*`
   tools, control pill with Stop); `wonky_mcp_stdio`; Settings › Developer (tokens with
   scopes/expiry, connection snippets, bridge status). Remaining:
   - resource subscriptions (`notifications/resources/updated`) and MCP 2026
     `subscriptions/listen`; OAuth 2.1;
   - `write.compare_versions`, `write.get_theme`, `write.create_theme`/`update_theme`
     (with the theme editor), the `write.search` regex timeout;
   - the UI-bridge hub is per server instance (no cross-instance relay yet);
   - `ui.write.get_layout_info` does not report the visible Delta range yet.

4. ☑ **AI assistant** (suite 10, Write 09 §5): server `AnthropicClient` (HTTP + SSE, retries with backoff/`retry-after`, refusal fallbacks, beta features that degrade on a 400) and agent loop (`assistant` endpoint: chat stream, threads, stop, destructive-change confirmation, inline rewrite/continue/summarize/outline/explain, proofread with the strict `report_issues` tool; tools generated from the MCP registry and bound to the open document; prompt caching; daily token budget, 2 concurrent requests, `AiUsage`); one run = one undo step "AI: …" on the requesting client (`onBehalfOfSessionId`/`groupId`); the shared `AssistantPanel` (threads, streaming Markdown, tool chips with Show/Undo, context chips, Stop, quick prompts, Edit/Suggest, privacy notice, "AI isn't configured" state); inline AI (selection ✨ menu, `/ai`, Mod+J prompt, preview with Replace/Insert below/Try again/Refine/Discard and a word diff, continue writing, AI suggestions with `via: ai`); Tools › Summarize document / Generate outline / Proofread document; Settings › AI (enable, quality, usage, clear history). Enable it with `anthropicApiKey` in `config/passwords.yaml`. Still open:
   - the `ui.write.get_ai_preview` UI-bridge tool, and `write.compare_versions` / `write.get_theme` for the assistant (they don't exist as MCP tools yet);
   - a live check against the real API (no key in development); the run and concurrency registry is per server instance;
   - continue writing shows its ghost text in a card at the caret, not inline in the text layout.
5. ☑ **Offline persistence** (suite 12 §1): per-user `write_cache_<userId>.db` on `sqlite_async`
   (web: `sqlite3.wasm` + `db_worker.js` in `wonky_write/web/`, OPFS or IndexedDB; desktop: a
   file) with `LocalDocument` (+ server op log), the durable `LocalPendingOp` outbox (written
   before sending, 2 s chunks, resent with the same `clientOpId`, `RebaseTooOld` → "Save my
   offline changes as a copy"), `LocalUndoStack` and `LocalPendingUpload`. Documents open from
   the device first (stale-while-revalidate), can be created offline, and stay available when
   opened in the last 14 days (max 50) or made available offline (downloaded, drive badges,
   unavailable items dimmed). Closed documents with an outbox sync in the background; metadata
   changes are queued; the profile is cached for offline starts; the drive cache and queue are
   per user. Settings › Offline & storage shows usage, *Clear local data* and *Simulate offline*
   (`write.offline.simulate`, the `ConnectivityService.forceOffline` test hook). Still open:
   - the offline theme cache (documents opened offline use the default theme when their theme
     was never loaded) and offline comments;
   - "Offline storage is limited in this browser" for the IndexedDB fallback;
   - deleting the database file on desktop (tables are truncated, as on the web).

6. ☑ **Spellcheck** (Write 04 §28): pure-Dart Hunspell checker in `wonky_write_core` (`package:wonky_write_core/spellcheck.dart`: affixes, flags, compounding, REP/MAP/KEY/TRY + n-gram suggestions, tokenizer with the skip rules); bundled en-US, en-GB, fr-FR, es-ES, nl-NL, sv-SE, da-DK dictionaries (open licenses, `assets/dictionaries/LICENSES.md`), loaded on first need and parsed in 8 ms frame slices; red wavy underlines, context-menu suggestions, Ignore, Add to dictionary (synced personal dictionary), Tools › Spelling (Check spelling… dialog with Change / Change all, Next error ⌘', Underline errors, Ignore UPPERCASE, Personal dictionary…), per-document language. Still open:
   - de-DE, it-IT, nb-NO (GPL-only upstream) and pt-BR, pl-PL (size) dictionaries; licenses in About;
   - a Web Worker / isolate for checking very large documents.
7. ☑ **Editor extras:** SE-4 in-place table cell editing (click a cell, Tab/Enter navigation, Markdown source per cell, one "Edit cell" step per commit); drag and drop (SE-6 selection move/copy, block drag via the handle with drop line and auto-scroll, web OS drops of images, documents and text/HTML); emoji picker (Insert › Emoji, `/emoji`, `:` trigger) and special characters dialog; image lightbox (focus mode and typewriter scrolling were built and later removed). Still open:
   - OS drag and drop in native desktop builds (needs a drop plugin);
   - the emoji picker in wonky_ui for comment reactions; self-hosted fallback fonts (`fontFallbackBaseUrl`);
   - table cells: caret inside cells in the document itself (cells are edited through a per-cell field).
8. ☑ **Notifications** (07 §4, §6): pluggable `EmailSender` (Resend HTTP API with the passwords `resendApiKey` + `emailFrom`, otherwise logged), mention/assignment emails right away (`NotificationEmailFutureCall`), the 15-minute digest for the other kinds (or one email each with `digest: false`), honoring Settings › Notifications (mentions, replies, shares, access requests, suggestions, digest); notifications popover (grouping, excerpts, All/Unread, paging, settings link, keyboard); activity dashboard server side (`ActivityEndpoint`: viewers for Editors+ from the share set, view and comment trend charts, "Show my view history"; the dashboard dialog was removed from the UI, 07 §6); paged activity feed in the details panel. Still open:
   - localized emails (server emails are English);
   - undo for *Mark all as read*;
   - deep links from emails to the comment thread.
9. ◐ **Quality**:
   - ☑ CI runs analyze, format and tests for every workspace package (+ vendored `super_editor`/`attributed_text` suites) and `tool/check_dependencies.dart` (01 §2.1); open violation: `wonky_sheets_core` imports `vector_math` without declaring it; Sheets packages still have analyzer infos and unformatted files, so the analyze/format jobs fail until they are cleaned up;
   - ☑ i18n: wonky_app and wonky_write strings in ARB (`write_en.arb`, `wonky_app_en.arb`), `en_XA` pseudo-locale (`tool/pseudo_locale.dart`, `--dart-define=WONKY_LOCALE=en_XA`); the menubar overflows at 1024 px under en_XA; `ar_XB` (RTL) is not generated yet;
   - ☑ accessibility: labeled icon buttons, `textContrastGuideline` + `labeledTapTargetGuideline` in the screen-level tests (home, settings, Write screen, notifications);
   - ◐ E2E journeys in `wonky_write/integration_test` (macOS; nightly `e2e.yml`): 1, 2, 5, 6 and 8 (MCP drive/write tools; `ui.invoke_command` not yet) pass locally; web needs `flutter drive` + chromedriver; journeys 3, 4, 7, 9, 10 are open;
   - ☐ golden tests on CI (masters must be regenerated on Linux; the light destructive color changed);
   - ☐ a performance suite.
10. ☐ **Deployment** (deferred to a later iteration; the release build served at `/write/` already loads and works in development):
    - verify production builds served by the server at `/write/` and `/sheets/` (`serverpod run flutter_build`), with WASM and cross-origin-isolation headers;
    - the sign-in is shared on the single origin; in development the two `flutter run` origins (8101 and 8102) don't share it.
11. ☐ **Desktop** (deferred to a later iteration; v2 is web only, `specs/01-architecture.md` A13 — the desktop targets must keep compiling) (macOS first): packaging, native menubar, keychain sharing between apps, four binaries with `wonkydrive://` / `wonkywrite://` / `wonkysheets://` / `wonkyslides://` URL schemes, OS drag and drop in native builds, desktop printing extras, Slides presenting in native full screen (`window_manager`).
12. ☐ **Multi-window presenting** (deferred, v2 review Q5/Q29/Q30): a presenting-only second window for Slides' audience view — Window Management API on the web, Flutter multi-window (fallback `desktop_multi_window`) on desktop — reusing the presentation-session messages (`specs/wonky_slides/10-presenting-and-pdf.md` §5.3). v2 presents in one window with the audience on another device or browser.
13. ☐ **v2** (Drive, Slides, suite changes): specified and planned as work packages — `specs/14-roadmap.md` §2.1–§2.2, `specs/wonky_drive/05-implementation-plan.md` (D-1…D-18), `specs/wonky_slides/12-implementation-plan.md` (SL-1…SL-45); decisions in `specs/v2-review.md`.

## Known issues

- Version restore uses the shell's server-side restore; undoing it restores the restore point (Write 08 §4.5).
- When a role is downgraded while editing, pending ops that are no longer allowed are discarded through a resync, not converted into suggestions.
- Recurring server jobs are re-registered on every server start under fixed identifiers.
- Search uses no full-text GIN index yet.
- shad tooltips and popovers swallow Esc; the toolbar works around this with `ToolbarEscapeScope`.
- PDF exports (client and server) cover Latin, Greek and Cyrillic with the bundled TTFs; CJK, Arabic and emoji fall back to placeholders until the fallback fonts are added.

## Wonky Sheets — open items

Everything below is deferred; the app works without it. Areas are in rough priority order.

1. ☐ **Scripting UI — follow-ups** (Sheets 09 §23; autocomplete/hover docs, squiggles,
   Compare/Merge + local history, drafts, presence, live logs, persistent bytecode cache and
   execution queue, drag-reorder, *Help › Script API reference*, UI DSL sidebars/dialogs,
   *Enable scripts*, "Loading…" cells and the macro digit shortcuts are done; the editor, save,
   run, live logs, a custom function and an onOpen menu were checked live in the wasm build):
   `isolate_manager` is overridden to 6.x in `pubspec_overrides.yaml` so `re_editor` compiles
   to wasm — drop the override when re_editor allows 6.x; Tab does not accept a completion
   (re_editor binds only Enter), no signature help while typing arguments; `UiImage` of the UI
   DSL; a live look at completion popups, hover, sidebars and Mod+Alt+Shift+1 (item 2). The
   script editor's code font (GeistMono, synthesized italic for comments) intermittently drew
   wrong or missing glyphs in the wasm build (`///` as boxes, `=`/`<`/`-` gone, "@custom©nction"),
   gone after a reload — an engine-level issue, not reproduced on demand.
2. ☐ **Live verification leftovers** (phase 4 pass, see STATUS; the browser pane was hidden for
   the last part, so these were not reached): dark mode and ~400 px for the phase-4 features;
   slicers filtering a pivot; DV chip colors, smart chips and file chips; the bundled fonts in
   cells and print/PDF; display language (Function language: de); macro record + replay; script
   sidebars/dialogs and *Enable scripts*; two-tab presence, comments scope filter, offline
   comment queue, conflict review, version history author colors/download/copy; Explore panel,
   assistant empty state, AI not configured; import dialog tabs, print page-break dragging and
   the dark PDF option; scrolling a 50k-cell sheet. Not drivable in the automation browser:
   picking real files (Import CSV/XLSX, image over cells), XLSX/PDF downloads and pasting an
   image (the pane denies clipboard reads; the app now says so instead of "The clipboard is
   empty"). Also seen, not fixed: the menubar is clipped at 800 px when a script adds a menu
   (Help and the custom menu's popup go off-screen; the strip should scroll or overflow), and
   submenus opened from a menu at the right edge cover their parent instead of flipping left
   (shad's anchor only falls back vertically); a filter-view sort of 25k rows blocks the page
   for ~10 s; the open-spreadsheet skeleton still shows document lines.
3. ☐ **Sync / data layer** (viewport-first loading, recovery export, IndexedDB warning + cell
   cap, weekly purge, offline-created badge, batched server writer, shared codec, set-based
   engine writes (patch OS-7), save progress and `#LOADING` for formulas over streaming rows are
   done): *low priority — large-sheet performance is deferred:* a 1M-cell import still takes ~2 min locally (commits of random-UUID index pages:
   bigger transactions or sequential cell ids would help); deleting rows/columns on the server
   still runs the full FK projection (~8 s per 500 rows at 50k cells; skipping it when every
   child is user-tombstoned needs a convergence proof); the OPFS/IndexedDB check is a
   browser-feature heuristic (the SQLite worker doesn't report its choice); recovery export is
   desktop only (web replicas are emptied, not moved aside).
4. ☐ **Editor** (LocalViewState, editing preferences, column autocomplete, formula preview,
   a11y semantics + announcer, context menu position, drag-copy cursor, `RangeInput` picking
   (also in the filter views panel), dark-mode automatic text, sort undo selection, side panel
   restore precedence are done): *low priority — large-sheet performance is deferred:* tile cache only if the release build misses the frame budget —
   decided by measurement: the VM test at 1M cells shows median 12.6–16 ms, p95 20–25 ms in
   debug JIT on a loaded machine (`test/features/grid/grid_performance_test.dart`); a release
   profile of the web build decides.
5. ☑ **Formatting** (phase 4): display language, server-created spreadsheet defaults and the
   theme preset fonts (Merriweather, Montserrat, Nunito, Source Sans 3 bundled; the mono presets
   use JetBrains Mono instead of Courier Prime) — see STATUS.
6. ☐ **Data tools** (the rest is done, see STATUS; view-only sort in filter views and `DataJobs`
   progress + cancel done in phase 4; a sorted filter view and the progress toast were checked
   live on 25k rows): a live check that slicers with *apply to pivot tables* filter pivots
   (`PivotOverlayService.slicerMask` reads the slicer JSON; both sides were built in parallel);
   *Cancel* of a running job (a 25k-row sort finishes in ~1 s, too fast to cancel by hand).
7. ☑ **Data validation & protection** (phase 4): chip colors via `WonkyColorPicker`, file chips,
   chips as rich runs in the cell layer — see STATUS. No place chips (optional).
8. ☑ **Pivot tables** (phase 4): incremental (delta) refresh for decomposable aggregates and the
   big-source snapshot in slices — see STATUS.
9. ☐ **Charts, images, objects** (phase 4 done, see STATUS): golden masters of
   `wonky_sheets/test/goldens/charts` must be generated on CI Linux (no masters committed); the
   GPU vs software comparison (`wonky_sheets/integration_test/chart3d_backends_test.dart`) needs
   a Flutter GPU device and was not run, and the GPU backend is still verified on the web only
   (live: GPU path active, orbit, Alt+Shift+arrows, hover, undo, all 3D types);
   image clipboard (paste, copy as PNG) on Windows/Linux desktop (web and macOS only); remote
   object outlines show a collaborator's primary selected object only; 3D trendlines are not
   drawn on horizontal 3D bars; ODS import doesn't read charts; image paste in the release
   build (the automation browser denies clipboard reads).
10. ☐ **Import / export / print** (*low priority — large-file performance is deferred*): server import jobs run in the instance that queued them (no
    worker pool); the parsed IR of a file is still held in memory whole (planning and writing
    are chunked, `IrToRowsPlanner.planChunked`).
11. ☐ **Collaboration & history** (conflict review + "your sort was replaced", comments scope
    filter, cut/paste anchor moves, offline comment queue, inline composer, show-changes command,
    per-cell author colors, server-side diff, version downloads, copy comments/sharing,
    `changedRangesJson`, objects in the version view, marching/hover flags, typing preview,
    agent cursors and the server version tests are done, see STATUS): partial-range sorts don't
    move comment anchors; PDF and server-side downloads of a version; *Your sort was replaced*
    finds the winner by the "Sort…" change label; the server-injected agent cursor and the app's
    external-write flash (item 12) may both show for the same MCP write; a live two-window check
    of the new presence/comment/conflict UI.
12. ☐ **MCP & AI** (rest): a live test with a real API key (no `anthropicApiKey` in
    `config/passwords.yaml`); `AI()` values are not persisted in a client `ComputedValueCache`
    (offline shows `#LOADING`) and `sheets.ai.refreshAiCells {ranges}` refreshes every call;
    `#AI_ERROR!` is shown as `#N/A` with the reason; `ui.sheets.describe_panel` cannot set
    selects/segmented controls (only text, checkbox, switch, buttons); PNG pixel-diff fixtures.
13. ☐ **Scripting engine** (job queue + worker role, rate limits, coalescing, failure
    notifications, fetch cache, chart/filter/protection/CF members, Lock/Cache services and
    `runLive` log streaming are done, 09 §23): web SharedArrayBuffer worker / snapshot mode
    (decision in 09 §8.2.1: not isolated yet — next step COOP same-origin + COEP
    credentialless on `/sheets/`, Safari stays inline); limits, locks and caches are per
    instance (Redis for several workers); `DriveApp`; `dart_eval` pins the workspace to
    `analyzer` 8.x (assessed: 93 errors in dart_eval + 15 in wonky_sheets_script against
    analyzer 13.3; needs a lockfile bump in a quiet window, 09 §23).
14. ☑ **Core**: chunked planning (`IrToRowsPlanner.planChunked`), CF/DV ranges and formulas
    on moves (06 §15.3) and charts without an Excel equivalent as XLSX pictures are done. Left:
    a cut with hidden rows (several blocks) moves a CF rule's formula with the first block's
    offset only.

## Wonky Drive — open items

- **Server files (D-8 follow-ups, Drive 02):** *Replace* / upload new version (P2, §9:
  `UploadConflictMode.replace` answers `unavailable`); chunked resumable uploads (P1, §4.3:
  `chunked` is ignored, the `PUT /files/upload` route answers 501 for `Content-Range` and takes
  only the URL token, not the session); multi-file ZIP downloads (P1, §8); per-instance
  download volume limit (2 GB/day, suite 13 §6) is not counted yet; HEIC/TIFF server previews
  (not rendered today); `drive.copy` of presentations waits for Slides (`DeckCopier`).
- **File previews (D-14 follow-ups, Drive 02 §6, Drive 04 §6):** pdf.js is **not in the repo
  yet** — run `wonky_drive/tool/fetch_pdfjs.sh` (downloads `pdfjs-dist@6.2.108` from npm into
  `wonky_drive/web/pdfjs/`) and commit the result; until then PDFs show "PDF previews aren't
  available here" with *Download*. Then measure the browser budgets of suite 11 §2 in the release
  build (first PDF page < 1 s for 100 pages, image ≤ 4 MB < 500 ms; only the text budget is
  measured, on the VM). Prev/next uses the file's folder, not the list the preview was opened
  from (search, starred, recent — the home should hand its visible list to the preview). P1:
  PDF thumbnail strip and first-page thumbnails (`drive.setThumbnail`), find in file (`Mod+F`),
  P2: audio player card (shown as the file
  card today). Desktop downloads (`PlatformFileDownloader` returns false off the web, A13). The
  TextMate engine is superlinear on big inputs (≈ 0.7 s / 100 K chars, ≈ 19 s / 500 K on the VM);
  the preview uses highlight.js beyond 50 K chars and highlights the first 250 K only — fix the
  engine (line-wise parsing) with `tokenizeLine` in M10.
- **Uploads (D-13 follow-ups, Drive 02 §3–4, Drive 04 §4):** the live check of the
  server-dependent parts is still open: the running dev server (`serverpod start` since 23:30)
  kept serving D-1's `createFileUpload` stub even after `hot_restart` (the watcher's incremental
  compiler never picked up the D-8/D-9 files — its analysis reported `drive_presentations.dart`
  as missing) — restart `serverpod start`, then check in the release build: XHR upload progress,
  preview after upload, *Download* (hidden anchor), the forced-upload refusal (J-D3) and an
  offline drop that uploads on reconnect (J-D8; an OS drop can't be simulated by automation —
  `webkitGetAsEntry()` is null for synthetic `DataTransfer`s). The upload panel is mounted by
  `WonkyAppConfig.wrap`, above the navigator, so it stays clickable over modal dialogs — move it
  into the navigator overlay (a shell hook) or make it inert while a dialog is open. P1: folder
  picker (`drive.upload.folder`, `webkitdirectory`), paste of files, OS drops on tree nodes and
  breadcrumbs, empty dropped folders, a progress ring in uploading list rows (they say
  "Uploading…"). `desktop_drop` (web) drops a whole drop when one item has no
  file entry (e.g. a dragged link). D-11's *Not enough storage for all files* dialog lays its three
  buttons out in one row above 640 px; with the test font they overflow the 464 px dialog
  (the D-13 widget test runs it at 360 px) — check with real fonts and long translations.
- **Storage page, Drive settings, commands (D-17 follow-ups, Drive 03 §6.4, Drive 04 §7–9,
  §13):** not checked in a browser (no web-build token; D-18): the Storage page in the release
  build, live `storageChanged` updates from the real server, *Empty trash* / *Delete forever*
  against the server, `drive.listByStorage` paging past 50 rows. The table sorts by counted size
  only (`drive.listByStorage` has no other order; the mockup's *Sort ▾* is not built). The
  *Free up space* counts read at most 200 rows per card ("More than 200 files"). *Duplicate
  files* (P1) and *Old file versions* (P2) cards are not built. The home's layout button and
  sort menu (shell) call `DriveController` directly; the `drive.view.*` commands wrap the same
  methods. `ui.drive.select_items` selects and focuses but does not scroll the home list to the
  row (the Storage table neither). *Convert uploads* converts after the upload completes
  (`drive.convertFile`, then the uploaded file is trashed and deleted forever) instead of a
  server-side import of an `importSource` upload (02 §7.3): it needs room for both copies for a
  moment, and after a reload the batch's undo trashes the deleted original instead of the
  converted item. *Confirm before moving items into shared folders* (P1) is not a setting yet
  (the confirm itself is P1). The list's *File size* column (shell `item_list.dart`) still shows
  `sizeBytes`, not `countedBytes` (03 §2).
- **Drive app scaffold (D-5 follow-ups):** the Drive web icons (`wonky_drive/web/icons/Icon-512.png`)
  are upscaled from the 256 px product icon (`icons/drive.webp`); replace them with renders of a
  512/1024 px master. The `slides`
  `flutter_apps` alias (8104) is added by SL-1 when `wonky_slides/` exists.
- **Shell v2 (D-10 follow-ups, suite 03 §3.3–3.4):** the server's `AppConfigRoute` doesn't
  serve `help.bugReportUrl` yet (`wonky.help.bugReportUrl`; the apps fall back to
  `https://github.com/serverpod/wonky/issues`). The drawer (below `md`) keeps the theme it opened with when the app
  theme changes while it is open (shad sheets capture the theme), and Esc doesn't close it after
  a menu inside it was closed with Esc (focus leaves the sheet). Drive's template gallery shows
  all templates by category (one *Blank* per kind), not the kind tabs of Drive 04 §1. The
  *Report a bug* footer link on the auth screens has no widget test.
- **Settings split (D-12 follow-ups, suite 04 §4):** *Sign-in & security* lacks the Google
  account link status / *Link Google account* (needs a server call listing the user's identity
  providers) and *Sign out of all devices* (P2). *Offline & device data* shows only the current
  app's device data, not the summary row per other app on this device. Write's *Page & export* defaults are stored but not yet
  applied: new documents ignore the default layout / saved page setup and the export dialog
  doesn't preselect the default format (as in v1). Not verified in a browser (no web-build
  token): the cross-app *Settings of other apps* links and the `/settings/sheets` handoff in
  Write are covered by widget tests with the fake cross-app navigator only.
- **Shared chart packages (D-3 follow-ups, SL-27 in M10, Slides 08 §2.7, §2.10):** `ChartData`
  JSON, `ChartSnapshot`, `ChartRevealState`, `ChartSceneMorph`, `Chart3DView.lerp`, `ChartTable`
  + the generic recommender split, `TtfTextMeasurer`, a pluggable range-ref validator for
  `ChartSpecSchema` (Slides: no ranges), deck-theme `background`/`text` in `ChartThemeSource`;
  move `ChartView` (generic part), the data table dialog, `ChartTypeIcon` and the Customize-tab
  `ChartStyleEditor` from `wonky_sheets` into `wonky_charts_flutter`. The workbook-based layout,
  3D and describer tests stay in `wonky_sheets_core`; port some to `ChartData` fixtures in
  `wonky_charts/test`. Sheets chart golden PNGs (`wonky_sheets/test/goldens/charts`) have no
  committed masters, so those six golden tests fail locally until masters are generated.
- **Shared code packages (D-2 follow-ups, M10 with Slides code elements, Slides 07):**
  `CodeTokenizer.tokenizeLine` (incremental line state for type-in/editing), `CodeLayout` +
  `MonoFontMetrics`, the grid-exact `CodeView` mode driven by `CodeViewState` (title tab,
  callouts, dimming, caret), `CodeEditorField` (re_editor) and `CodePaletteResolver`;
  `CodeLanguages.detect` (P1). Write switches its exports **and** its editor to
  `DefaultCodeTokenizer` in M10 (Q25; the editor then also highlights the highlight.js
  languages, and its language picker can offer `CodeLanguages.pickerLanguages`).
- **TextMate tokenizer speed:** the copied engine needs ~140 ms (VM, JIT) for 1,000 lines of Dart;
  Slides 07 §14 budgets 15 ms desktop / 30 ms web. Same engine and speed as Write's editor before
  the extraction (Write tokenizes blocks over 20k chars after a debounce); optimize (regex
  caching, line-state incremental parsing) with `tokenizeLine` in M10.
- **Shared sync kit (D-6 follow-ups, Slides 12 §5.1–5.2):** the server writers
  (`ServerSheetsWriter`, `SheetsBulkWriter`; Slides' `ServerSlidesWriter`) don't implement
  `SyncTxAdapter` yet (server code untouched by the extraction). The local bookkeeping tables
  keep their Sheets names (`sheets_row_journal`, `sheets_journal_space`, `sheets_dirty_space`,
  trigger prefix `sheets_journal`) and are shared by every app's replica file; rename them to
  `sync_*` with a client migration when convenient (renaming the triggers needs dropping the old
  ones). `ReplicaInstallation`/`ReplicaOfflineProvider` (shell glue) have no widget test of
  their own (covered through Sheets' `open_workbook_session_test`); *Clear local data* on the
  web now empties the tables in one transaction with deferred foreign keys.
- **Shared rich text, fonts, spelling, emoji (D-7 follow-ups):** Sheets still bundles its own
  copy of the 40 TTFs (`wonky_sheets/assets/fonts/`, `CellFonts`, `print_fonts.dart`) and the
  server its mirror (`wonky_server/web/fonts/`, `FileSystemFontProvider`); switch both to the
  `wonky_fonts` package (`BundledFonts`) and drop the copies (Sheets needs the dependency in
  suite 01 §2.1). The shared Flutter `AssetFontRegistry` + `BundledAssetFontProvider`
  (`package:wonky_app/fonts.dart`, SL-6) exist; Write (`WriteFonts`/`AssetFontProvider`) and
  Sheets still use their own loaders — switch them when convenient. The moved spelling dialogs and emoji
  picker still have hard-coded English strings and `write.`-prefixed widget keys (unchanged from
  Write); move the strings to the `wonky_app` ARB files and give Slides its own key prefix when
  SL-44 uses them. `EmojiPrefs` keeps its `write.emoji.*` store keys (recents shared by the apps).
- **Storage quota (D-9 follow-ups, Drive 03 §11):** a Sheets cell row costs ~125 bytes in the
  `SheetsSizeEstimator` (S-D3), so 50 MB holds ~400k cells while `maxCellsPerSpreadsheet` is 1M:
  decide whether to discount the estimate (e.g. count only non-null columns) or accept that
  big spreadsheets put users over quota. The weekly orphan-image cleanup that subtracts
  unreferenced images (03 §2) doesn't exist; images stored by a failed MCP `write.insert_image`
  mutation or a cancelled import stay charged until then. Spreadsheet imports check only the
  source size before work (the real size is the estimate after creation). No admin tool for
  `quotaBytesOverride` (P2).
- **Shell storage UI (D-11 follow-ups, Drive 03 §6.3–6.5):** not built yet: the *From
  template* tooltip "Not enough storage" with disabled templates (`TemplateView.sizeBytes`), the
  copy dialog's disabled *OK* "Not enough storage (needs 6.1 MB)" (the copy command pre-checks
  and shows the dialog instead), the details panel's "Counts against Anna Berg's storage", and the
  upload panel's "Not uploaded — you're out of storage" rows (D-13). Ownership-transfer
  dialogs use the presenter's generic mapping (`reason: transfer`); the share dialog's own
  error display was not switched to it. Golden masters of the meter/banner/dialogs are made on
  CI (specs/15 §7). Not verified in a browser (no web-build token).
- **Write & Sheets adaptations (D-16 follow-ups):** not verified in a browser (no web-build
  token): *Open with* → `/write/import`, `/sheets/import` and Cancel going back to Drive
  (`history.back`), the flipped homes and File › New ▸ *Presentation* (Slides `/new`). Write's
  `/import` has no options dialog (Write imports have none; the server pipeline's defaults
  apply). Sheets' `/import` loads the whole file into the browser for the dialog's preview
  (large files are slow to analyze there; the conversion itself runs on the server). Images
  refused on quota: background (queue) refusals show only the placeholder, not the *Out of
  storage* dialog; Sheets in-cell `IMAGE()` images show no "Not uploaded" state; the refusal is
  not persisted, so after a reload the queue tries once more (and is refused again). Write's
  *Page & export* defaults (D-12 follow-up) are still not applied to new documents (needs the
  page setup written at creation, also for offline-created documents).
- **MCP & AI for Drive (D-15 follow-ups, suite 09 §4–§6, suite 10 §3.1):**
  `drive.create_presentation` is not registered — it needs the headless deck
  (`HeadlessDeck`/`ServerSlidesWriter`, Slides SL-8/SL-40); the `slides:read`/`slides:edit`
  token scopes are accepted and offered (off by default) but no tool uses them yet.
  `drive.export` of presentations answers `unsupported` until SL-40. The `ui.drive.*`
  window handlers (D-17, `wonky_drive/lib/mcp/`) are tested in the window only; a relay test
  through `/mcp` with a live Drive window is part of D-18's browser checks. The
  Drive assistant (P1: drive-scoped threads, the restricted tool list of suite 10 §3.1 — the
  current `AssistantToolset` binds `uuid` to the open file, so it needs a drive variant — the
  folder/selection context builder and `drive.ai.askAboutItem`) is planned with M11. Resource
  subscriptions for `wonky://file/<uuid>` / `wonky://drive/storage` follow the suite-wide
  subscription work. `wonky://file` lists the 50 most recently modified files only.

## Wonky Slides — open items

Status per work package: [specs/wonky_slides/STATUS.md](specs/wonky_slides/STATUS.md).

- **Display fonts (SL-6, Slides 05 §3.2, §6):** only the 10 families of `wonky_fonts` are
  bundled, so the built-in themes ship with substitutes (Open Sans, EB Garamond, Lato, Roboto,
  Nunito, Montserrat, Merriweather, Source Sans 3, JetBrains Mono, Roboto Mono). Bundle static
  TTF instances (OFL) of Inter, Work Sans, IBM Plex Sans/Mono, Source Serif 4 and the display
  families (Instrument Serif, Space Grotesk, Sora, Manrope, Bricolage Grotesque, Fraunces;
  P1: Bebas Neue, DM Serif Display) into `packages/wonky_fonts/fonts/` (+ manifest, licenses,
  mirror in `wonky_server/web/fonts/`, `SlidesFonts` categories), then move the built-ins to the
  designed fonts with a version bump (`builtin:<key>@2`).
- **Date placeholder (P2, 05 §4):** the built-in masters have no `date` placeholder yet.
- **Built-in prompts are English** (`Click to add title`, …) and stored in the copied layout
  rows; localize them when the copier (SL-8) copies a built-in, or render prompts of built-in
  part keys from the app's ARB strings (SL-13).
- **Skeleton leftovers (SL-1 → SL-11):** `/p/:uuid` is `DeckPlaceholderScreen` until SL-11's
  `DeckEditorScreen` (it should open the deck with `openDeckSession` and show its
  `DeckLoadState`; creating presentations works since SL-9); `flutter_apps: slides` has
  `auto_launch: false` until Slides is usable (flip it in `wonky_server/pubspec.yaml`). The shell's empty home copy ("Welcome to your
  drive" / "Create a document or open one shared with you.") and illustration are the same for
  every app home — make them kind-aware (presentations) in `wonky_app` `home_screen.dart`.
- **Contract stubs of SL-3 to replace:** `HarnessDeckDocument` (`wonky_slides/test/harness/`)
  gives way to SL-11's `DeckDocumentController`. `CodeScene` and the timeline stub
  (`motion.dart`) are minimal on purpose — SL-26 and SL-24 extend them. The in-memory
  `LwwSyncRelay` is a skeleton; SL-9 added the replica-level harness
  (`wonky_slides/test/sync/support/`: replicas, in-process sync peer, devices).
  (`SlidesPlanner` is now the default of `DeckHarness` and `MemoryDeckSession.blank`;
  `FakeSlidesPlanner` stays for session contract tests.)
- **Core model and planner leftovers (SL-7):** the Slides text schema is `SlidesText`
  (`wonky_slides_core/model.dart`, `lib/src/model/text/`) — SL-8 adds the
  `SlidesDeltaValidator`/`SlidesDeltaNormalizer` names (02 §4.1) on top of it in `core/text/`
  or moves it there. Paste (`PasteSlides`/`PasteElements`, 03 §12.2 payload) keeps
  `wonky-file://` sources as they are: re-homing files into the target deck
  (`FileEndpoint.copyToItem`, quota) is SL-8/SL-18's. Auto-fit scales and connector routes are
  derived by SL-10's scene layer (on `SlideScene`, not on `ResolvedElement`). The order index treats
  every slide group as top-level (nested groups are P2, 02 §3.4). Maintenance must be
  *scheduled*: `SyncedDeckSession` runs `DeckMaintenance.repairOp(model)` after merges
  (debounced 1 s, SL-9); still to do before headless writes in `ServerSlidesWriter` (SL-8),
  executed with label "Repair presentation" and don't push it on the undo stack. Build, code-state
  and chart-link operations are planned at row level with basic validation; effect catalogs,
  `optionsJson`/annotation schemas and chart behavior are validated by SL-24/SL-26/SL-27. Undo
  labels of plans are English (as Sheets'); localize with the shell's undo labels if needed.
  The server's `DeckFactory` (SL-5) can now plan `CreateDeck` with `SlidesPlanner` instead of
  the testing `DeckBuilder`.
- **Client sync leftovers (SL-9):** `SyncedDeckSession.images` is the in-memory
  `MemorySlideImageResolver` until SL-15 resolves uploads and signed URLs; the recovery export
  of a broken replica is desktop only (on the web the kit can't read the replica behind the
  SQLite worker — as Sheets) and is one JSON file of rows; the property
  and convergence runs use an in-process sync peer (no OS-8 filter, no change-log consumer) —
  the full multi-client harness with `serverpod_test` and isolates (12 §7.3) remains for the
  scripted scenarios of 09 §6.4.
- **Server deck sync leftovers (SL-5):** `DeckChangeLog` rows are never pruned (Sheets prunes
  `ChangeLog` after 30 days in a daily job; add `DeckChangeLogProcessor.pruneOld` + receipts
  cleanup to the maintenance jobs with SL-39, which reads the log for versions);
  `slides.revertChange`/`reapplyChange` throw `unavailable` until `ServerSlidesWriter` records
  `ServerChangeRecord`s (SL-8/SL-40); `drive.createPresentation` refuses `templateUuid` and
  `drive.copy` of presentations is not deck-aware until the `DeckCopier` (SL-8/SL-22);
  `DeckFactory` takes its rows from the core's `DeckBuilder` (testing library) until SL-7's
  planner plans `CreateDeck`; consumer plugins still to add: comment orphaning (SL-38),
  version snapshots index (SL-39), agent cursors (SL-40), headless cache (SL-8/SL-40);
  `slidesSync` merges reuse the `SheetsMergedSignal` model on the `slides:merged:<space>`
  channel (no listener yet).
- **Scene and stage leftovers (SL-10):** the core `SlideTextLayout` measures with
  `ApproxTextMeasurer` until SL-20 adds a `SlideTextMeasurer` on the `pdf` package's TTF
  metrics (server PDFs, headless previews); the core engine lays out `justify` as `left`,
  right-aligns RTL paragraphs without bidi reordering and renders small caps as all caps; the
  Flutter engine scales super/subscripts but doesn't shift their baseline (`dart:ui` has no
  baseline offset — use a placeholder span or font features). `SlideIconSource` needs the
  Lucide name → glyph map of the icon font (SL-14's icon picker); charts draw a placeholder
  until SL-27/SL-32 provide a `ChartSceneSource`; code uses `BasicCodeLayout` until SL-26's
  `CodeElementModel` (highlight steps, window chrome, `palette: auto` by background). The
  stage has no motion yet: part runs, typewriter clips, `drawProgress`, shader masks/dissolve
  and per-element compositing while animating are SL-29's (06 §12.1); off-slide content at
  40 % is available (`SlideStage.offSlideOpacity`) for SL-12's canvas. Shadow spread is
  approximated by scaling the silhouette. Golden masters (every geometry and text style,
  15 §7) still have to be generated on CI Linux; SL-10 tests paint patterns per kind in light
  and dark instead. `SlideRenderer` isn't wired into an editor yet (SL-11/SL-12 create it per
  open deck with the session's `SlideImageResolver`).
- **Synced additions after S-1 (SL-24, SL-37):** queue new synced fields/tables in Slides 02 §14
  and ship them in S-2/S-3; each bumps `SyncSchemaRelease` (`wonky_sync_models`) and the record
  in 02 §14.1 — the server and Sheets guard tests fail until both are updated.
