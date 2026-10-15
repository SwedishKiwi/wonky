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
- Offline-sync patch OS-9: the background projection rebuild after a synced-schema change holds the server-wide CRDT node lock (the one every tracked write takes) for one space's projection at a time, so a release that changes a *Sheets* table would pause server writes for each big spreadsheet's rebuild (seconds); reads of a still-pending space serve its previous projection. Fine for the Slides releases S-2/S-3 (decks are small); a per-space lock would remove the pause (suite 12 §4).
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

- **M8 integration (D-18 follow-ups):** the web E2E runner (chromedriver + `flutter drive`,
  steps in specs/15 §9) and the J-D1…J-D10 `integration_test` journeys
  (`wonky_drive/integration_test/`) — the journeys were checked by hand in the release builds.
  Grid cards show a category icon, not the thumbnail of Drive 04 §10 (image previews,
  app thumbnails: `thumbnailFileId` is never displayed). `HEAD /files/d/…`
  answers without `content-type` and with `content-length: 0`. *Offline & device data* in
  Drive doesn't count queued uploads under *Changes waiting to sync*. Sheets'
  `decodeImageSize` (`features/images/image_service.dart`, unused) relies on
  `ImageDescriptor.encoded`, which has no size on the web — remove it or use
  `ImageDimensions`. Browser checks: the dev server's live-reload script (`/__dev/version`)
  reloads the release pages after every server reload, so long manual checks get reset while
  other agents edit server files.
- **Server files (D-8 follow-ups, Drive 02):** *Replace* / upload new version (P2, §9:
  `UploadConflictMode.replace` answers `unavailable`); chunked resumable uploads (P1, §4.3:
  `chunked` is ignored, the `PUT /files/upload` route answers 501 for `Content-Range` and takes
  only the URL token, not the session); multi-file ZIP downloads (P1, §8); per-instance
  download volume limit (2 GB/day, suite 13 §6) is not counted yet; HEIC/TIFF server previews
  (not rendered today); `drive.copy` of presentations waits for Slides (`DeckCopier`).
- **File previews (D-14 follow-ups, Drive 02 §6, Drive 04 §6):** (no PDF previews in v2 —
  user decision, Drive 02 §6.3.) Measure the image budget of suite 11 §2 in the release build
  (image ≤ 4 MB < 500 ms; only the text budget is measured, on the VM). Prev/next uses the
  file's folder, not the list the preview was opened from (search, starred, recent — the home
  should hand its visible list to the preview). P1: find in file (`Mod+F`),
  P2: audio player card (shown as the file
  card today). Desktop downloads (`PlatformFileDownloader` returns false off the web, A13). The
  TextMate engine is superlinear on big inputs (≈ 0.7 s / 100 K chars, ≈ 19 s / 500 K on the VM);
  the preview uses highlight.js beyond 50 K chars and highlights the first 250 K only — fix the
  engine (line-wise parsing) with `tokenizeLine` in M10.
- **Uploads (D-13 follow-ups, Drive 02 §3–4, Drive 04 §4):** checked live by D-18 (uploads,
  previews after upload, *Download*, pre-check dialog, offline queue → reconnect); a real OS
  drop still can't be automated (`webkitGetAsEntry()` is null for synthetic `DataTransfer`s).
  The upload panel is mounted by `WonkyAppConfig.wrap`, above the navigator, so it stays
  clickable over modal dialogs and, below `md`, covers the drawer's bottom section (settings,
  *Report a bug*, meter) — move it into the navigator overlay (a shell hook) or make it inert
  while a dialog or the drawer is open. Rows of files without a browser MIME type (e.g.
  `.dart`) show the generic file glyph in the panel (the list shows the code glyph after
  upload). P1: folder
  picker (`drive.upload.folder`, `webkitdirectory`), paste of files, OS drops on tree nodes and
  breadcrumbs, empty dropped folders, a progress ring in uploading list rows (they say
  "Uploading…"). `desktop_drop` (web) drops a whole drop when one item has no
  file entry (e.g. a dragged link). D-11's *Not enough storage for all files* dialog lays its three
  buttons out in one row above 640 px; with the test font they overflow the 464 px dialog
  (the D-13 widget test runs it at 360 px) — check with real fonts and long translations.
- **Storage page, Drive settings, commands (D-17 follow-ups, Drive 03 §6.4, Drive 04 §7–9,
  §13):** checked in the release build by D-18 (Storage page light/dark, live `storageChanged`
  banner updates, *Empty trash*); not checked: `drive.listByStorage` paging past 50 rows. The table sorts by counted size
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
  doesn't preselect the default format (as in v1). The `/settings/sheets` hand-over from
  Write and the `/settings/write` redirect were checked in the browser (D-18); the
  *Settings of other apps* links were not clicked.
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
- **Storage quota (D-9 follow-ups, Drive 03 §11):** (spreadsheets now use a compact content
  estimate — user decision, Drive 03 §11; existing sizes are corrected by the nightly
  reconcile.) Repeat the backfill dry run on a production copy before the first v2 deploy
  (also time the nightly spreadsheet re-estimate there). Slides' `SlidesSizeEstimator` still
  sums `pg_column_size`: a new empty deck costs ~18 KB (theme, master, layouts) — switch it to
  a content estimate like Sheets' (`SpaceSizeEstimator.rowBytes`/`baseBytes`) if that
  matters. The weekly orphan-image cleanup that subtracts
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
  CI (specs/15 §7). (Meter, banners and the *Out of storage* dialog were checked in the
  browser by D-18.)
- **Write & Sheets adaptations (D-16 follow-ups):** D-18 checked `/sheets/import` (CSV →
  spreadsheet in the file's folder, browser Back → Drive), the flipped homes and the Write
  image pre-check in the browser; not yet: *Open with* → `/write/import`, *Cancel* going back
  to Drive (`history.back`) and File › New ▸ *Presentation* (Slides `/new`). Write's
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
  through `/mcp` with a live Drive window is still open (needs a developer token in the
  browser profile; not done in D-18). The
  Drive assistant (P1: drive-scoped threads, the restricted tool list of suite 10 §3.1 — the
  current `AssistantToolset` binds `uuid` to the open file, so it needs a drive variant — the
  folder/selection context builder and `drive.ai.askAboutItem`) is planned with M11. Resource
  subscriptions for `wonky://file/<uuid>` / `wonky://drive/storage` follow the suite-wide
  subscription work. `wonky://file` lists the 50 most recently modified files only.

## Wonky Slides — later (M10/M11)

M9 (Slides MVP) closed with SL-23 on 2026-10-15: Slides **only shows what works**. Everything
below is planned in [specs/wonky_slides/12-implementation-plan.md](specs/wonky_slides/12-implementation-plan.md)
§4.8–§4.12 and not built (or built only in the core). Per-package leftovers of the built work
packages are in "Wonky Slides — open items" below (cross-referenced here, not repeated).

**How hidden features come back.** `wonky_slides/lib/config/slides_features.dart` has one
`SlidesFeature` value per hidden area (with its work package) and `SlidesFeatures.enabled`
(empty for M9). While a feature is off its commands — real ones and the disabled
`placeholder_commands.dart` entries — are not registered (so menus, toolbar, context menus,
palette, shortcuts and MCP `ui.*` don't offer them; menus and context menus are pruned with
`SlidesFeatures.prune`), the shell's comments/versions/assistant commands are left out
(`WonkyAppConfig.hidesShellCommand`), the inspector drops Format sections without a builder
and the Animate tab, the status bar/View menu drop the outline and masters modes, settings of
hidden features are neither shown nor advertised (`offersDefaultsKey`), and Sheets chart pastes
are refused with a toast. A work package turns its feature on by adding it to
`SlidesFeatures.enabled`, registering real commands (its placeholders then drop out), giving its
inspector sections a builder, and updating `test/config/menu_registry_test.dart` (golden ids)
and the tests that assert the hidden state (`chrome_commands_test`, `deck_editor_screen_test`,
`slides_settings_test`, `clipboard_commands_test`). Remove a `SlidesFeature` value once its
feature ships.

**Already in place:** the timeline core (SL-24; present mode compiles every slide with
`SlideMotionInput.fromDeck` + `CompileOptions(reducedMotion:)` but builds/transitions aren't
animated yet, frames are settled), the code core (SL-26; code elements from templates or MCP
render statically through `CodeElementLayout`), chart elements render a static placeholder,
`OutlineViewShell` (read-only) and `MastersModeShell` (`features/editor_screen/
view_mode_shells.dart`), the `slidesDefaults` keys for animations/code/charts/spelling, the
history child-route placeholder (`DeckRoutePlaceholder`, not routed while hidden), schema S-1/S-2
with every Slides table.

- **SL-25 · Transitions and Magic Move core** (06 §7–§8; deps SL-10, SL-24 ✓) —
  `TransitionCompiler`/`TransitionPlan` beyond `cut` (`motion/stub/transition_stub.dart`),
  `MagicMoveMatcher` (shapes, text glyphs, code tokens, chart camera), plan budget ≤ 15 ms.
- **SL-27 · Chart link core and server** (08 §2.7, §3, §5, §13; deps D-3, SL-7) — `wonky_charts`
  reveal/morph/snapshot APIs, chart link data in the core, `SlidesChartEndpoint`, the Sheets
  clipboard payload addition. Feature `charts` (with SL-32).
- **SL-28 · Masters, layout editing, theme editor** (05 §8; dep SL-17) — master mode, layout
  editing, *Edit theme…*, *Insert placeholder*. Feature `masters` (`slides.theme.edit`,
  `slides.layout.insertPlaceholder`, View › Edit masters, Inspector *Edit layout*).
- **SL-29 · Motion player and rendering** (06 §6, §12–§14; 10 §4, §9; deps SL-24 ✓, SL-25,
  SL-19 ✓) — `SlidePlayer`, transition rendering incl. 3D, reduced motion in the player,
  presenting with running builds, loop/kiosk timers. Laser, pen and ephemeral ink are already
  built (SL-19). Feature `animations` (with SL-30).
- **SL-30 · Animate tab, animation pane, transitions UI** (06 §5, §7 UI; deps SL-24 ✓, SL-25,
  SL-11 ✓) — Inspector › Animate (Transition/Build/Order), `slides.animate.*`,
  `slides.magicMove.*`, *Duplicate for Magic Move*, toolbar *Animate*/*Transition*, the
  Animations settings group. Feature `animations`.
- **SL-31 · Code element UI** (07 §3, §7–§8; deps SL-26 ✓, SL-24 ✓) — insert code block, code
  editing, highlight steps, states, type-in while presenting, the Code settings group; the
  renderers must draw the SL-26 `CodeScene` fields (see "Code core leftovers"). Feature
  `codeBlocks`.
- **SL-32 · Chart element UI** (08 §4–§10; deps SL-27, SL-24 ✓) — insert linked/native charts,
  *Update*, client-side auto-update, unlink, Linked objects panel, Sheets chart paste (now
  refused), chart builds, 3D camera, the Charts settings group. Feature `charts`.
- **SL-33 · PDF builds as pages, print frame, PNG export** (10 §11, §13; deps SL-20 ✓,
  SL-24 ✓) — *Print each build stage* (hidden), PNG / PNG ZIP (Markdown P2) downloads.
  Features `printBuilds`, `imageExports`.
- **SL-34 · Outline view, Layers panel, accessibility checker** (04 §10, 03 §8, §17; deps
  SL-14 ✓, SL-16 ✓) — editable outline (the read-only shell exists), Layers panel,
  accessibility checker. Features `outlineView`, `layers`, `accessibilityChecker`.
- **SL-35 · Write exports on the shared tokenizer** (07 §2.2, Q25; dep SL-26 ✓) — Write's
  export code highlighting through `wonky_code`.
- **SL-36 · Templates 10 of 10, M10 integration and exit** (04 §15; all M10) — Quarterly review,
  Tech talk, Product launch, Portfolio, …; the M10 exit gate (J-S5…J-S7).
- **SL-37 · Live collaboration + schema S-3** (09 §1–§2; dep SL-21 ✓) — live pointers, follow
  mode, follow presenter, transform hints (see "Collaboration leftovers").
- **SL-38 · Comments on slides and elements** (09 §3; deps SL-12 ✓, SL-16 ✓) — comment pins,
  panel, anchors. Feature `comments` (shell comment commands, title-row comments button and
  panel, *Comment* toolbar button, View › Show › Comment pins).
- **SL-39 · Version history, overwritten-text review, activity** (09 §4–§6; deps SL-8 ✓,
  SL-9 ✓) — File › Version history, the `history` route and panel. Feature `versionHistory`.
- **SL-40 · MCP headless tools `slides.*`** (11 §2–§4; deps SL-8 ✓, SL-20 ✓, SL-24…SL-27) —
  also `drive.create_presentation` and `drive.export` of decks (see Drive MCP note above).
- **SL-41 · Phone remote, rehearse, same-browser fast path** (10 §5.2, §6.4, §10; deps
  SL-19 ✓, SL-29). Feature `remoteAndRehearse` (*Rehearse*, *Use phone as remote*).
- **SL-42 · UI bridge `ui.slides.*`** (11 §5; deps SL-11 ✓, SL-40) — `mcpUiTools` is empty;
  context-menu trees for `ui.get_menu_tree`.
- **SL-43 · AI in Slides (+ Drive assistant, P1)** (11 §6–§8; dep SL-40). Feature `assistant`
  (Extensions › AI, the shell assistant panel).
- **SL-44 · Remaining P1: spelling, emoji, image adjustments, curved connectors** (03 §14;
  deps D-7, SL-13…SL-15 ✓) — spelling, presentation language, special characters. (Emoji
  insert, image adjustments and curved connectors already exist; see their leftovers.)
  Feature `spelling`.
- **SL-45 · M11 integration and exit** (all M11) — J-S8…J-S10, the MCP suite, a11y checklist.
- **Other hidden items without a work package:** *Import slides…* (04 §13.9, P1, feature
  `importSlides`), snap to grid (03 §5.3, P2, `snapGrid`), Slides notification settings
  (suite 07, `notificationSettings`), editor preferences that do nothing yet — units, scroll
  changes slides, smart quotes, autoformat lists (04 §13.16, SL-13 leftovers,
  `editorPreferences`).
- **Browser findings of SL-23 to look at:** with Flutter semantics enabled (the
  `flt-semantics-placeholder` click), double-clicking a text element on the canvas doesn't
  open the text editor (no IME textarea; works without semantics) — check canvas text editing
  with a screen reader on (03 §17); the editor still loads comment threads
  (`comment/listThreads`) although comments are hidden — skip it while
  `SlidesFeature.comments` is off.
- **M9 exit items not verified by SL-23** (see the M9 checklist in `specs/14-roadmap.md` §2.1):
  the automated journeys (`wonky_slides/integration_test/` — no chromedriver), the scripted
  multi-client scenarios of 09 §6.4 with `serverpod_test` isolates (12 §7.3), the offline merge
  fuzzer for decks, the perf budgets of 03 §18 on the web, the PDF fidelity corpus with
  `pdftoppm`, and the browser walkthrough (see SL-23 in the Slides STATUS).

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
- **Collaboration leftovers (SL-21, 09 §2.5):** `structure` hints (1 s navigator shimmer after
  slide/group changes) and live pointers (09 §1.4, P1, with SL-37); text hints send the full body
  only (no Delta `diff` + `baseHash` for bodies over 4 KB; over 16 KB nothing is sent) and only
  for element bodies (table cells and notes are claimed but not hinted); the Present button's
  live dot while someone presents; the 300 ms fade of released soft-lock outlines; outline-view
  caret bars (SL-34); server `SlidesAgentCursors` for headless writes (09 §1.1).
- **Date placeholder (P2, 05 §4):** the built-in masters have no `date` placeholder yet.
- **Built-in prompts are English** (`Click to add title`, …) and stored in the copied layout
  rows; localize them when a built-in is copied into a deck (planner `ThemeCopy`), or render prompts of built-in
  part keys from the app's ARB strings (not done in SL-13).
- **Chrome leftovers (SL-11, Slides 04 §19):**
  - The canvas, navigator, notes pane, grid and outline views are shells on the static
    `SlidePreview` (`features/editor_screen/slide_preview.dart`): SL-12 swaps the canvas body
    in `canvas_region.dart` for SL-10's `SlideStage` + selection, SL-34 the outline shell;
    delete `SlidePreview` once nothing uses it. (Navigator, notes and grid: done, SL-16.)
  - (Placeholders: since SL-23 the remaining placeholder commands
    (`commands/placeholder_commands.dart`, each names its WP) and the inspector sections without
    a `builder` are hidden, not shown disabled — "Wonky Slides — later (M10/M11)" above.)
  - Home thumbnails (04 §15: first non-skipped slide rendered after an editing session,
    `drive.setThumbnail`) need SL-10's renderer and the files upload — not built.
  - 04 §16 at 1,200–1,440 px: collapsing the docked inspector to a 44 px tab strip while a side
    panel is open; the narrow navigator drawer should open from the title row (needs a left
    app slot in `EditorScaffold`).
  - Keyboard: menu mnemonics (Alt+letter, 04 §4.11) come from the shell menubar.
  - `mcpUiTools` is empty and `ui.get_menu_tree {menu: 'context.<id>'}` isn't supported yet
    (`slidesContextMenus` is ready for it) — SL-42.
  - The browser check of SL-11 stopped at the home: the running dev server had no `slides`
    endpoint (stale `serverpod start`); open a deck from the home in the next release check.
- **Navigator, groups, grid, notes leftovers (SL-16, Slides 04 §5, §8, §9):**
  - Slide-row badges: open comment count (SL-38), presence dots on rows and collapsed headers
    (SL-21), builds ⚡ and transition glyphs (P1, SL-30).
  - Speaker notes soft lock ("Anna is editing these notes", 02 §4.4) — SL-21. (Find & replace
    in notes: done, SL-18.)
  - (Cross-deck re-homing of uploaded files, the web Clipboard API representation and the
    paste options chip: done, SL-18.)
  - P1 drops: canvas elements onto a slide row (03 §4.1), OS image files onto/between rows.
  - The dragged group header is dimmed during a drag (04 §5.10 says "collapses visually");
    rows are `Semantics` buttons with `expanded`/`selected` and full labels, not tree items
    (no tree role in this Flutter version).
  - (Pasting Slides payloads copied in another browser tab: done, SL-18 — the payload travels
    embedded in the clipboard HTML.)
- **Contract stubs of SL-3 to replace:** (`HarnessDeckDocument` gave way to SL-11's
  `DeckDocumentController` + `DeckEditorController` in `DeckHarness`.) `CodeScene` (filled by SL-26) and the timeline stub
  (`motion.dart`, replaced by SL-24) were minimal on purpose. The in-memory
  `LwwSyncRelay` is a skeleton; SL-9 added the replica-level harness
  (`wonky_slides/test/sync/support/`: replicas, in-process sync peer, devices).
  (`SlidesPlanner` is now the default of `DeckHarness` and `MemoryDeckSession.blank`;
  `FakeSlidesPlanner` stays for session contract tests.)
- **Core model and planner leftovers (SL-7):** the Slides text schema is `SlidesText`
  (`wonky_slides_core/model.dart`, `lib/src/model/text/`) — SL-8 adds the
  `SlidesDeltaValidator`/`SlidesDeltaNormalizer` names (02 §4.1) on top of it in `core/text/`
  (done, SL-8). Paste (`PasteSlides`/`PasteElements`, 03 §12.2 payload) keeps
  `wonky-file://` sources as they are: the client calls `SlidesClipboardCodec.rehomeFiles` for
  cross-deck pastes and queues `file.copyToItem` (done, SL-18's `SlidesRehomeQueue`). Auto-fit scales and connector routes are
  derived by SL-10's scene layer (on `SlideScene`, not on `ResolvedElement`). The order index treats
  every slide group as top-level (nested groups are P2, 02 §3.4). Maintenance must be
  *scheduled*: `SyncedDeckSession` runs `DeckMaintenance.repairOp(model)` after merges
  (debounced 1 s, SL-9) and the headless deck before every server write (SL-8, not recorded). Build, code-state
  and chart-link operations are planned at row level with basic validation; effect catalogs,
  `optionsJson`/annotation schemas and chart behavior are validated by SL-24/SL-26/SL-27. Undo
  labels of plans are English (as Sheets'); localize with the shell's undo labels if needed.
  The server's `DeckFactory` plans `CreateDeck` with `SlidesPlanner` (SL-8).
- **Images and tables leftovers (SL-15, Slides 03 §6.5–§6.6, §6.12):**
  - No persistent image cache yet (Sheets has `SheetsImageBlobCache`): an image uploaded from
    this device is downloaded again after a reload, and offline after a reload only images
    still in the upload queue render. Add a per-user blob cache under `features/uploads/`.
  - Adjustment sliders write on release without a live preview (03 §6.5.5); the URL dialog
    has no preview (04 §13.2); animated GIFs draw their first frame on the canvas; downscaled
    > 40 MP images are re-encoded as PNG (not JPEG q 0.9); SVG originals are not kept (P2).
  - Mask: the mask shape's adjust handles (`maskAdjust`) aren't on the canvas; crop mode shows
    the rectangular crop box, not the mask outline.
  - Tables: merging keeps the covered cells' text hidden instead of concatenating it (Google
    concatenates); Up/Down at text edges use paragraphs, not visual lines; typing into a
    selected cell appends (Google replaces the content); `setBorders {edges: none}` clears
    the cell borders but not the table style's (use *Style: None*); dragging a row border
    sets the row's minimum height only. (Cell copy/cut/paste and pasting TSV/Sheets ranges
    into cells: done, SL-18.)
  - The Drive picker lists recently opened image files plus search (no folder browsing);
    (pasting OS images with `shell.edit.paste`: done, SL-18); drag & drop and clipboard
    images are web only (desktop disabled, suite 01 A13).
  - Table cell soft locks (two people typing in one cell) follow SL-21's text locks — cells
    are not claimed yet.
- **Client sync leftovers (SL-9):** `SyncedDeckSession.images` stays the in-memory
  `MemorySlideImageResolver` (SL-15's `SlidesImageService` resolves uploads, the queue and signed
  URLs for every renderer and falls back to it); the recovery export
  of a broken replica is desktop only (on the web the kit can't read the replica behind the
  SQLite worker — as Sheets) and is one JSON file of rows; the property
  and convergence runs use an in-process sync peer (no OS-8 filter, no change-log consumer) —
  the full multi-client harness with `serverpod_test` and isolates (12 §7.3) remains for the
  scripted scenarios of 09 §6.4.
- **Server deck sync leftovers (SL-5):** `DeckChangeLog` rows are never pruned (Sheets prunes
  `ChangeLog` after 30 days in a daily job; add `DeckChangeLogProcessor.pruneOld` + receipts
  cleanup to the maintenance jobs with SL-39, which reads the log for versions);
  (SL-8 built `slides.revertChange`/`reapplyChange`, deck copies and templates from
  presentation items, and the headless cache listening on `slides:merged:<space>`); consumer
  plugins still to add: comment orphaning (SL-38), version snapshots index (SL-39), agent
  cursors (SL-40); `slidesSync` merges reuse the `SheetsMergedSignal` model on the
  `slides:merged:<space>` channel.
- **Scene and stage leftovers (SL-10):** the core `SlideTextLayout` defaults to
  `ApproxTextMeasurer`; SL-20 added `TtfTextMeasurer` (`package:wonky_slides_core/pdf.dart`,
  real TTF metrics, used by PDF exports) — headless previews/MCP layouts (SL-40) should load
  a `TtfFaceSet` too; the core engine lays out `justify` as `left`,
  right-aligns RTL paragraphs without bidi reordering and renders small caps as all caps; the
  Flutter engine scales super/subscripts but doesn't shift their baseline (`dart:ui` has no
  baseline offset — use a placeholder span or font features). (Lucide icons: done in SL-14 —
  `LucideIconSource` is every `SlideRenderer`'s default.) Charts draw a placeholder
  until SL-27/SL-32 provide a `ChartSceneSource`; code uses `BasicCodeLayout` until SL-26's
  `CodeElementModel` (highlight steps, window chrome, `palette: auto` by background). The
  stage has no motion yet: part runs, typewriter clips, `drawProgress`, shader masks/dissolve
  and per-element compositing while animating are SL-29's (06 §12.1); off-slide content at
  40 % is used by SL-12's canvas (`SlideStage.offSlideOpacity`). Shadow spread is
  approximated by scaling the silhouette. Golden masters (every geometry and text style,
  15 §7) still have to be generated on CI Linux; SL-10 tests paint patterns per kind in light
  and dark instead. (SL-12 wires `SlideRenderer` per open deck through
  `SlideCanvasController`, over the session's `SlideImageResolver`.)
- **Canvas leftovers (SL-12, Slides 03 §5.7):** P1/P2 canvas items not built: Alt distance
  labels (§5.2), dropping elements on a navigator thumbnail (§4.1), smart-duplicate offset
  (§11), *Scale text* for multi-selection resize (§4.2), Mod+arrow 1-px nudges (§4.4, P2),
  double-click a guide → position input and layout guides (§5.6), snap to grid (P2,
  `slides.view.toggleSnapGrid` stays a placeholder), `slides.select.sameKind` (P2). (Text-box resize
  rules, type-to-edit and text activation: done in SL-13.) SL-15 adds crop/table activation. Element handlers' `extraHandles`/`snapPoints` aren't
  consulted yet (the canvas draws shape adjust handles and line endpoints itself — move them
  into SL-14's handlers). Live previews are transforms: text scales visually during a resize
  and glued connectors follow only on drop (draw connector routes live from the preview
  frames). Duplicating (Edit › Duplicate, Alt-drag) is limited to top-level elements (pasting
  children of scaled groups needs child-space-aware `PasteElements`). Scrollbars are
  indicators, not draggable. Remote transform hints (09 §2.4, SL-37). The canvas shows the
  slide in the editor's zoom steps (SL-11: 25…400 %; 03 §2.2 also lists 10/33/67 %).
  Check pointer gestures, pinch zoom and cursors by hand in Chrome and Safari (web build).
- **Text editing leftovers (SL-13, Slides 03 §6.2.1):** check IME composition, dead keys,
  emoji picker and RTL by hand in Chrome and Safari (web build, SL-23 — only simulated in
  widget tests). Not built: autoformat while typing (`- `, `* `, `1. `, `[ ] `, `--`, smart
  quotes), the overflow `+` badge (P1), following links with Mod+click while editing, task
  markers clickable in the overlay, the soft-lock popover/claims (SL-21 implements
  `TextEditLocks`), overwritten-text review (SL-37+), localized prompts of built-in
  placeholders (render from ARB strings), *Scale text* on multi-resize. `Localizations` gives
  the overlay's paragraphs a locale the static engine doesn't set (CJK fallback could differ);
  caps transforms that change the length (ß → SS) show the source text while editing; the
  checklist glyphs ☑/☐ are missing from the bundled fonts. The menu/toolbar Undo is disabled
  while the only change is unwritten typing (≤ 300 ms; the shell enables Undo from the stack).
  Text inside tables (cells) is SL-15's; a default-list paragraph turned off is stored as
  `listStyle: none`.
- **Copier, clipboard, headless deck leftovers (SL-8):** MCP must map the `being_edited`
  `WonkyException(conflict, details.code = being_edited)` to its error code and expose `force`
  (SL-40); (the clipboard UI and HTML paste: done, SL-18); *Make a copy* with comments passes the copier's
  id map as anchor map — check it once slide comments exist (SL-38); version copies use
  `DeckCopies`/`DeckCopier` (SL-39); a deck copy whose image copy fails (file gone or
  unreadable) keeps the new reference (missing image) and logs a warning; deck change records
  reuse Sheets' `ServerChangeRecord` table (rename `spreadsheetUuid` → `spaceUuid` when a
  migration touches it anyway); `DeckChangeLog` pruning (30 days, as Sheets) belongs to SL-39.
- **PDF export and print preview leftovers (SL-20, Slides 10 §11–§13):** builds as pages
  only print the stub timeline's single step until SL-24/SL-33 (the *Print each build stage*
  box is disabled); element shadows print as offset silhouettes (no rasterized soft shadow,
  P1); text shadows, emoji bitmaps (P1) and Lucide icons (the PDF warns `icon_unavailable`)
  are not drawn — the client export can embed the font asset
  `packages/lucide_icons_flutter/assets/build_font/LucideVariable-w<100…600>.ttf` with
  `LucideGlyphs.codePoint`/`fontFamilyFor` (`package:wonky_slides_core/icons.dart`, SL-14);
  the server needs a copy of those TTFs (ISC license) in its assets; charts and code use whatever `ChartSceneSource`/
  `CodeSceneSource` the caller passes (server: placeholders/basic code until SL-27/SL-26);
  group opacity multiplies into each primitive (no transparency groups), gradient stop alpha
  is averaged. Client exports run on the main isolate in cooperative chunks without the
  progress toast / *Cancel* for > 1 s and without the > 80 pages → server switch (10 §11.4);
  the preview's *More options…* dialog is not built (every §11.1 option is in the settings
  column) and regenerating the PDF does not keep the viewer's page (the browser viewer's page
  isn't readable). Server: `revision` (older versions) and PNG/PNG ZIP are refused as
  unavailable (P1); the result cache is in memory per instance. Client/server raster parity
  (`pdftoppm` diff < 1 %, 10 §18) needs poppler in CI — the line-break parity test covers the
  text layout. Check the in-app viewer and the print dialog in Chrome, Firefox and Safari
  (web build). The editor's own layout overflows by 20 px at 360 × 720 (seen under the print
  route in tests; SL-11).
- **Shapes, lines, icons, groups, format painter leftovers (SL-14, Slides 03 §6.3–§6.7,
  §7, §9):** elbow connectors have no per-segment midpoint handles (`waypoints` are kept and
  routed, but not editable on the canvas) and connector routes still update only on drop
  (SL-12 note above); element handlers' `extraHandles`/`snapPoints` are still unused (the
  canvas draws adjust handles and line endpoints itself). Not built: the quick-style row with
  live swatches (the toolbar/menu list the eight styles by name), gradient/image fill editors
  in the inspector (the commands accept any `fillJson`), layer blur and reflection controls
  (`slides.format.effects {blur}` exists, no UI), *Format › Effects* presets, the icon picker's
  filled variants (`fillJson` draws a background), custom-shape point editing (P2) and SVG
  paste (see SL-18 leftovers). The format painter paints whole elements: text selection → text selection
  painting (03 §9 row 2) needs SL-13's editor, table cells SL-15's cell model. Icon-picker
  categories come from name keywords (Lucide's tag data isn't shipped with the font package);
  aliases and a synonym list cover search. Check in a release web build that the weighted
  Lucide fonts (`Lucide200…600`) keep every glyph (they aren't referenced by `const IconData`,
  so icon tree shaking should leave them whole) and the crosshair tools by hand in Chrome and
  Safari.
- **Clipboard, find & replace leftovers (SL-18, Slides 03 §12–§13, 04 §13.12):**
  - Not checked in a browser (no web build in SL-18): the async Clipboard API read/write of
    `text/html` + `image/png` in Chrome, Safari (paste prompt, user-gesture rules) and
    Firefox, Mod+V reaching the app (not the browser's native paste into the IME textarea),
    and cross-app paste Write ↔ Slides ↔ Sheets in one browser.
  - Not written on copy: `image/png` of copied elements/slides (03 §12.1; render the selection
    from the canvas scene at 2×) and the `text/markdown` marker (Write pastes the HTML). Slides
    → Write/Sheets carries text, lists and tables, not images (Write would need its own
    re-homing).
  - Paste: SVG text → rasterized image (03 §12.5) is not built (pasted as text); `https://`
    images in pasted HTML keep their URL (drawn through the image proxy, not re-hosted as
    uploads); fonts/sizes of foreign HTML are dropped (no px→su conversion); speaker notes keep
    super_editor's plain-text paste (no rich paste into notes); *Keep source formatting* is not
    offered for cross-deck **element** pastes (would need the source theme in the payload to
    bake `theme:` colors); the slides chip sits at the canvas corner, not at the pasted range.
  - Re-homing: a copy refused for storage shows the out-of-storage badge (Retry/Remove)
    instead of removing the image; jobs that fail 12 times wait for the next app start;
    copies of an undone paste still run (their files become orphans collected by the server).
  - Find: code text (P1 `includeCode`), group titles (P1) and master/layout text (master
    editing, SL-28) are not searched; notes matches open the notes pane but aren't highlighted
    there; highlights split runs proportionally per character (approximate for proportional
    fonts); MCP `slides.*` find tools are SL-40's (the UI commands take the query and options).
- **Templates leftovers (SL-22, Slides 04 §15):** five of the ten templates are built (Pitch
  deck, Project kickoff, Weekly update, Lesson, Workshop agenda); Quarterly review (linked
  chart placeholders), Tech talk (code type-in), Product launch and Portfolio (images) come
  with SL-36. Templates use shapes only — add Lucide icons now that `LucideIconSource` is every client
  renderer's default (SL-14); PDF/server rendering of icons is still open (see SL-20). Template content is English (like
  Write/Sheets built-ins). Templates write `list` on every bullet paragraph (since SL-13 the
  engines also apply a box's `defaults.list`, so typed paragraphs of body placeholders are
  bulleted too).
  The default table style's header (`accent1` fill, `bg1` text) is 4.47:1 on *Wonky* light —
  templates use 36 su bold header text (large text); consider a darker header fill in the
  theme (SL-17/SL-28). Local (offline) creation from a template has no quota pre-check (the
  server measures the size after registration, like a blank deck). Gallery screenshots are
  contact sheets from a widget test (`WONKY_TEMPLATE_PNG_DIR`), not browser screenshots.
- **Themes panel, layouts, page setup leftovers (SL-17, Slides 05 §4, §7, §9):** *Import
  theme from a presentation…* reads the source deck on the server (`slidesThemes.list`), so it
  needs a connection even when that deck is on the device (05 §9 allows on-device decks: read
  the replica when `SlidesReplica.hasDeck`); the chooser for decks with several themes is a
  select with names and usage, not previews. Inspector › Slide › Background edits solid colors
  only (gradient and image backgrounds render, editors not built — share them with SL-14's fill
  editors). The menubar's and context menus' *Apply layout ▸* list layout names (MCP-readable);
  thumbnails are in the toolbar's *Layout ▾* gallery and Inspector › Slide › Layout. Page setup
  writes one plan: decks over 5,000 row changes need the chunked write with progress of 02
  §12.2 (one undo step). Not built (P2): *View › Preview in dark appearance*, *Update to the
  latest version* of a built-in copy, a personal theme library; *Edit theme…* and master mode
  are SL-28's. The theme ⋮ menu offers *Edit theme…* as SL-28's disabled placeholder. Check the
  panel, the galleries and the page setup dialog in a release web build (no web build in
  SL-17).
- **Synced additions after S-2 (SL-37):** S-2 (SL-24) shipped only `BuildTrigger.onElementClick`
  (reserved; no table change). Queue new synced fields/tables in Slides 02 §14 and ship them in
  S-3; each bumps `SyncSchemaRelease` (`wonky_sync_models`) and the record in 02 §14.1 — the
  server and Sheets guard tests (tables) and `wonky_sync_models` `test/tables/
  sync_schema_release_test.dart` (enum values) fail until both are updated.
- **Timeline leftovers (SL-24, Slides 06 §9.8):** (present mode compiles with
  `SlideMotionInput.fromDeck` and `CompileOptions(reducedMotion:)` since SL-23 — no `scene`
  is passed, so text part boxes come from the resolved slide only); SL-29's player and the stage must
  render the new frame fields (clips, dissolve, part runs, chart reveal, code view, color
  overrides, highlights). Code durations are estimates until SL-26's `TypingScript`
  (`MotionCodeState` should then carry the derived type-in length); chart shapes come from the
  snapshot JSON (`gz:` compressed snapshots are not read — pass `chartShapeOf` from SL-27/32).
  Not in the core: the blur budget fallback and frame-budget degradation (SL-29), `line`
  delivery with layout (compiles as paragraph), interactive `onElementClick` triggers (P2),
  builds on group children / layout elements (P2), `Deck.defaultsJson.build` quick-add memory
  (the pane writes it, SL-30). The VM ≡ dart2wasm determinism run (06 §19) needs a web test
  run (no web build in SL-24); frames are compared as rounded JSON.
- **Code core leftovers (SL-26, Slides 07):**
  - Renderers: the stage painter (`wonky_slides/lib/features/stage/scene_painter.dart`) and the
    PDF painter (`slide_pdf_painter.dart`) still draw only the M9 `CodeScene` fields (runs flowed
    from `codeLeft`, numbers at the code font size, one background box). The SL-26 fields —
    grid columns, line opacity/blur, `bars` (highlight bars/boxes, selections, gutter markers),
    `caret`, `callouts` (bubble text layout), morph `glyphs`/`gutter`, crossfade `underlay`,
    caption/`box`, tab/window chrome with `titleBackground` and the language badge, `border`,
    `gutterFontSize`, the overflow badge from `hiddenRows`, `ligatures` — are for SL-31
    (screen, `CodeView` painter) and SL-33 (PDF builds as pages).
  - Timeline wiring (SL-24/SL-31): `MotionCodeState.stepsOf` drops empty steps, but 07 §4.1
    keeps them ("show all" steps) — use `HighlightSteps.count`; `codeState`/`codeType` build
    durations should come from `CodeElementModel.transitionDurationMs` /
    `typeInDurationMs` (type mode is derived, 07 §5.3) instead of estimates; frames map
    `CodeViewState` → `CodeSceneComposer.buildTransition(from:, to:, ms:)` /
    `build(state, step:, fromStep:, stepMix:)`.
  - Incremental tokenization (07 §5.4: `tokenizeLine`/`LineState`, ≤ 1 ms per keystroke for 300
    lines) is not built: type-in frames re-tokenize the whole intermediate text (≈ 5 ms for 300
    lines of Dart on the VM; the `CachedCodeTokenizer` LRU serves repeated frames). The TextMate
    engine could restart from top-level resume points (positions where the scope stack is
    empty) and stop once a resume point matches the previous parse.
  - Tokenizer budget (07 §14: 1,000 lines of Dart ≤ 15 ms desktop): SH-6 brought it from ≈ 56
    to ≈ 17–20 ms on the VM on a loaded laptop (`dart test -P slow` in `wonky_code`); the rest
    is mostly regex search, led by the Dart grammar's function-call rule, which backtracks
    inside every identifier. Measure on the web (≤ 30 ms) once a web test run is allowed.
  - Not built (outside SL-26): `UnifiedDiff` and `WalkthroughBuilder` (07 §10.2, with SL-40/43),
    `CodeLanguages.detect` (P1), cross-slide code morph wiring (07 §5.7, SL-25 uses
    `TokenMorphPlan.build` with both elements' layouts), sound (P2).
  - Simplifications: scroll-follow while typing is a stateless function of the caret (no
    spring; the renderer may smooth it); `focus: zoom` scales so the range fills 60 % of the
    viewport without the 24 su edge fade; the `auto` palette uses the slide's solid
    background color (gradients/images count as `bg1`). (`string_scanner` was removed from
    `wonky_code`'s dependencies in SL-23.)
- **Presenting leftovers (SL-19, Slides 10 §1–§9):**
  - Browser checks not done (no web build in SL-19; D-18 held the token): full screen +
    refusal hint, F5/Shift+F5 capture and a Logitech-style clicker, Esc/F11 leaving full
    screen ends present mode, presenter view + audience in a second browser (Chrome, Firefox,
    Safari) and on a phone, the ≤ 300 ms p95 follow latency on a LAN (10 AC 2, AC 4), the
    one-time extended-display hint. The running dev server needs a restart (or a hot reload
    that picked up the new `presentation` endpoint) before the audience view can join.
  - Kiosk (`mode: kiosk`, `?kiosk=1`) timers, auto-advance, idle restart and the 2 s Esc hold
    (10 §9, P0 M10) — SL-29; `loop` and `endBehavior` work.
  - Running builds: navigation already walks timeline steps and *Next* finishes a running
    step, but frames are the settled `endOfStep` frames; the player, transitions,
    `advanceDuringBuild: skip` animation and follower seek within a step come with SL-29.
  - Pre-flight (10 §1.2: fonts, first images, "3 images aren't available offline" with
    *Present anyway*) — not built; fonts load on demand through the renderer.
  - Presence state `presenting` ("Anna is presenting", A-10-7) needs a `PresenceState` value
    (shared model) — SL-21. Followers (`?view=follow`, P1) are accepted by the server but have
    no UI; phone remote and pairing keys, rehearse timings, same-browser `BroadcastChannel`
    fast path, *Freeze audience* — SL-41 (P1). Captions P2.
  - *This presentation* settings UI (10 §3) on the Presenting settings page — the command
    `slides.deck.setPresentSettings {patch}` exists (undoable); the page section doesn't.
  - Screen readers: the presented slide is one labeled image; exposing its content in reading
    order and announcing builds (10 §16, 06 §17) is open.
  - The presenter view's notes don't auto-scroll per step (P2) and have no `Mod+↑/↓` scroll
    binding; the 3D chart `camera` message (P1) is not relayed.
