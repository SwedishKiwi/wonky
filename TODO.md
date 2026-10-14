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

1. ☐ **Scripting UI — follow-ups** (Sheets 09 §23; the editor, runtime, triggers, macros
   and executions are built; `isolate_manager` is overridden to 6.x in `pubspec_overrides.yaml`
   so `re_editor` compiles to wasm — drop the override when re_editor allows 6.x): script API autocomplete/hover docs (`api_index.json`, 09 §14.4);
   conflict dialog *Compare*/*Merge* (only Overwrite/Discard) and `LocalScriptHistory`; unsaved
   drafts in `LocalViewState` (drafts live while the spreadsheet is open); presence in the
   script editor; squiggle underlines (gutter markers + Problems only); live log streaming
   while a run is in progress; persistent bytecode cache (`LocalBlobCache`) and the
   `LocalScriptExecutionLog` offline queue (in memory today); file drag-reorder in the rail
   (the command exists); *Help › Script API reference*; P2 sidebars/dialog DSL; per-user
   *Enable scripts* setting; "Loading…" muted-italic rendering of `#LOADING` in the grid;
   Mod+Alt+Shift+digit on web/mac layouts where Shift changes the logical key (verify live).
2. ☐ **Live verification leftovers** (the pass itself is done, see STATUS): picking real files
   (Import CSV/XLSX, image over cells) and the XLSX/PDF downloads, which the automation browser
   can't drive; a live look at the script editor and macros in the wasm build.
3. ☐ **Sync / data layer** (viewport-first loading, recovery export, IndexedDB warning + cell
   cap, weekly purge, offline-created badge, batched server writer and shared codec are done):
   formula cells that depend on rows still streaming in show partial values until their rows
   arrive (a `ComputedValueCache` or a "Loading…" marker would fix it; the cache is deferred:
   reopen cost is formula compilation, not evaluation — 150k formulas: model 2.1 s, first
   window 1.2 s, evaluation of the visible window a few ms); the local writer is slow for big
   writes (offline-sync engine inserts ~0.3 ms per cell, growing with the table: a 200k-cell
   paste/import writes in ~6 min); the server re-applies revived rows one `UPDATE` per row
   (redo of a 20k-cell revert ~45 s; deletes of rows/columns still run the FK projection); the
   OPFS/IndexedDB check is a browser-feature heuristic (the SQLite worker doesn't report its
   choice); recovery export is desktop only (web replicas are emptied, not moved aside).
4. ☐ **Editor** (LocalViewState, editing preferences, column autocomplete, formula preview,
   a11y semantics + announcer, context menu position, drag-copy cursor, `RangeInput` picking,
   dark-mode automatic text, sort undo selection are done): tile cache only if the release
   build misses the frame budget (VM test at 1M cells: median 12.6 ms, p95 20 ms in debug JIT);
   `RangeInput` picking in the filter views panel (it has no range field yet); the
   open side panel is restored only when no other panel is open.
5. ☐ **Formatting** (the rest is done, see STATUS): spreadsheet display language (P2: needs
   localized function names/booleans in the engine); Merriweather, Montserrat, Nunito,
   Source Sans 3 and Courier Prime (theme presets) are not bundled and render substituted
   (bundle their OFL TTFs into `assets/fonts/` + `CellFonts`/`SheetsPdfFonts`); spreadsheets
   created on the server (templates, no reserved space) ignore the Settings › Sheets defaults.
6. ☐ **Data tools** (the rest is done, see STATUS): view-only sort inside filter views (needs a
   row display permutation in the grid's axis mapping, 07 §4.4); a live check that slicers with
   *apply to pivot tables* filter pivots (`PivotOverlayService.slicerMask` reads the slicer
   JSON; both sides were built in parallel); `DataJobs` toasts have no percentage or cancel (the planner is synchronous).
7. ☐ **Data validation & protection**: dropdown chip colors come from the 10-pair palette
   (+ No color) instead of `WonkyColorPicker`; smart chips are People/Date/Dropdown only (no
   file/place chips), and a people chip is painted over the cell text (no rich-run rendering in
   the cell layer).
8. ☐ **Pivot tables**: incremental (delta) aggregation for decomposable aggregates (P2); the
   source snapshot of a big pivot is still taken on the UI thread (only the aggregation runs in
   the background).
9. ☐ **Charts, images, objects**: image paste from the OS clipboard, copy chart as PNG
   (`sheets.chart.copyAsImage` placeholder), PNG of copied objects; durable offline image
   uploads (retry in memory only), SVG rasterizing, animated GIFs, downscaling > 25 MP;
   chart editor per-point formatting, pie slices, waterfall subtotals, scorecard refs, error
   bars, trendline labels, MCP-describable panel; chart sheets don't disable grid commands /
   toolbar / formula bar; multi-select, remote object selections, running the core
   `AnchorMaintenance` when an anchor row/column is deleted, screen-reader data-table
   fallback, series-by-pattern setting; goldens, 50-charts scroll benchmark, raster cache for
   1M-point charts; default chart placement is anchored at the selection's top-right cell
   even inside frozen rows (objects there now extend over the scrolling panes).
10. ☐ **Import / export / print**: server import jobs (`SheetsImportJob`, progress and cancel for
    imports into an existing spreadsheet), chunked CSV planning (1M cells plan in one go, ~10 s,
    blocks the UI), desktop printing (`printing` plugin; desktop offers Export PDF),
    `exportPdf {darkTheme}`, JSON import/export (P2), Drive / Recent uploads tabs in the import
    dialog (P2), draggable page breaks, server PDF with the bundled fonts, imported XLSX images
    that fail to upload (offline) are lost, charts without an XLSX equivalent are listed in the
    export report instead of exported as images.
11. ☐ **Collaboration & history**: overwritten-offline-edits review (`sheets.conflicts.*`) and
    "your sort was replaced"; comments scope filter (This sheet / All sheets), moving anchors
    with cut/paste, offline comment queue, composer next to the cell; version history
    `sheets.history.toggleShowChanges` command, per-cell author colors, server-side diff for
    huge sheets, Download as… from a version, copy-comments/share options of Make a copy,
    `SheetsSnapshotIndex.changedRangesJson`; animated editing border, name flag on hover,
    typing preview (P2), cursors for headless MCP writes; server tests for capture timing and
    restore/revert; the version view renders no charts/images.
12. ☐ **MCP & AI**: assistant panel 1 px overflow at 400 px once a reply shows; highlighting
    headless MCP writes of other clients (needs ChangeLog actor kinds on the client); the
    assistant calling `ui.sheets.get_selection/select_range/highlight_range` in the requesting
    window (12 §6.2); `ui.sheets.describe_panel` / `set_panel_field` (P1); `screenshot_range`
    omits charts/images; Explore shows chart icons, not thumbnails; per-spreadsheet rate limit
    for mutating calls (60/min), `sync_version` in results, `group_dimension`, `AI()` cells
    (P2), cleanup suggestions (P2); suggest-mode previews live in memory on one instance; a
    live test with a real API key; the Explore panel has no title; the assistant's empty state
    says "this document" in Sheets.
13. ☐ **Scripting engine**: server job queue and worker role (`ScriptJob`, per-user concurrency,
    trigger coalescing); web has no SharedArrayBuffer worker or snapshot mode (alerts/prompts/
    fetch unavailable in the web inline runner); `api_index.json`, compile/analyze rate limits,
    failure notifications, custom-function fetch cache, chart/filter/protection/CF API members,
    P2 services. `dart_eval` pins the workspace to `analyzer` 8.x (porting it to analyzer 13 is
    ~93 compile errors in its compiler).
14. ☐ **Core**: chunked CSV planning (`IrToRowsPlanner`), re-anchoring CF/DV relative formulas on
    plain moves, charts without an Excel equivalent exported as images.
