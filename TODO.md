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
11. ☐ **Desktop** packaging (deferred to a later iteration) (macOS first): native menubar, keychain sharing between apps, `wonkysheets://` / `wonkywrite://` URL schemes.

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
