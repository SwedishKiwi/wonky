# 14 · Roadmap, Milestones and Parallel Workstreams

This is the suite-level plan. App-level breakdowns:
[Write implementation plan](wonky_write/10-implementation-plan.md),
[Sheets implementation plan](wonky_sheets/13-implementation-plan.md),
(v2) [Drive implementation plan](wonky_drive/05-implementation-plan.md),
[Slides implementation plan](wonky_slides/12-implementation-plan.md).

**Status (v2 planning, 2026-10):** M0–M7 delivered the first iteration of Write (complete) and
Sheets (complete for its first iteration, `wonky_sheets/STATUS.md`; deferred work in
`TODO.md`). The second iteration adds Wonky Drive, Wonky Slides and suite changes in
milestones **M8–M11** (§2.1).

## 1. Principles
- **Contract first**: each workstream starts by committing its public Dart interfaces (and
  Serverpod models/endpoint signatures) with stub implementations, so dependent workstreams can
  proceed in parallel.
- **Vertical slices**: every milestone ends with working, demoable software on web and macOS.
- **Ownership by folder/package** (see 01 §2–§4) to minimize merge conflicts; shared files
  (`server.dart`, command registration lists, `MenuSpec` trees, route tables) are edited only
  via small additive registrations.
- **Definition of done** (every task): analyzer clean, formatted, tests (unit + command
  undo/redo + MCP tool where relevant), light/dark verified, keyboard operable, strings
  externalized, docs/spec updated if behavior changed.

## 2. Milestones

| Milestone | Goal | Exit criteria |
|-----------|------|---------------|
| **M0 · Foundations** | Restructure repo (01 §2 M0 steps): `wonky_write`/`wonky_sheets` join the workspace and are wired to `wonky_server` (client bootstrap ported from the template `wonky_flutter`, which is then deleted), `packages/*` scaffolded; root workspace; CI (analyze, format, test, dependency-rule check, sync-update lint); `wonky_ui` theme + first custom widgets; command registry + undo service skeleton; MCP route spike (`mcp_dart` behind Relic); `third_party/` vendoring set up (§2.3 of 01: root overrides, `VENDORED.md`/`PATCHES.md`, CI running vendored tests) with `super_editor` and `serverpod_offline_sync` copied in; offline-sync module wired (`generator.yaml`: `shared_packages: [../wonky_sync_models]`, module `serverpod_offline_sync` nickname `offline_sync`, `experimental_features: databaseSync: true`; vendored patch if needed); web builds for both apps served by `wonky_server` at `/write/` and `/sheets/` with shared cookie sign-in (01 §2.4–§2.5). | Both apps boot (web + macOS), sign in works and carries over between the two apps, `/mcp` answers `tools/list`, sync session opens with an empty space. |
| **M1 · Shell & Drive** | Auth screens, settings (appearance, keyboard, developer tokens), drive (home, folders, recent, starred, trash, search, templates skeleton), sharing dialog + ACL, presence roster, notifications basics, command palette, quick switcher, offline drive cache. | Journeys 1 (partially) and drive CRUD; drive MCP tools pass. |
| **M2 · Write MVP** | Delta schema + Markdown codec; editor integration (mapper, applier, extractor); OT server + client; offline outbox; collaborative undo; core formatting/blocks; menus/toolbar/status bar; Markdown import/export; default theme rendering. | Journeys 1–3 (Write parts). OT fuzzer green. |
| **M3 · Sheets MVP** | Sync models + writer + active-set subscriptions + reserved spaces; WorkbookModel; grid rendering & editing; clipboard & fill; formula engine with ~150 P0 functions; basic formatting & number formats; undo; CSV import/export; 1M-cell perf gate. | Journeys 3–4 (Sheets parts); offline merge fuzzer green; perf gate passed. |
| **M4 · Collaboration** | Comments (both apps), suggestions (Write), remote cursors (both), version history (both), cell edit history, activity dashboard (UI later removed; server kept, 07 §6), share/role changes live, access requests, email notifications. | Journeys 2, 5, 6. |
| **M5 · Depth** | Write: themes + theme editor, tables editor, images, find/replace, outline, page setup, PDF/HTML/DOCX/ODT/RTF/EPUB/TXT export, print preview. Sheets: full formatting, CF, DV, filters/filter views/slicers, pivots, charts, named/protected ranges, data tools, XLSX/ODS/PDF/HTML export & XLSX/ODS import, print. Functions to ~400. | Journeys 7, 9; export validation CI green. |
| **M6 · Agents & Automation** | Complete MCP tool catalogs (headless + UI bridge) for both apps; AI assistant panels & inline AI; Sheets scripting (compile service, runtimes, bridge, editor, triggers, macros). | Journeys 8, 10; MCP integration suite green. |
| **M7 · Polish & Scale** | Accessibility audit, i18n readiness (pseudo-locales), performance tuning, bundle splitting, error reporting, security review, raise Sheets cell limits as upstream U1–U5 land, desktop packaging (macOS/Windows/Linux). | All budgets in 11 §2 met; a11y checklist complete. |

### 2.1 Second iteration (v2)

| Milestone | Goal | Exit criteria |
|-----------|------|---------------|
| **M8 · Drive + suite changes** | `wonky_drive` app at `/drive/` (root redirect), unified drive with kinds `presentation` (model only) and `file`, uploads (queue, offline), MIME sniffing, previews (image, PDF, text/code), *Open with*, downloads; **50 MB quota** (accounting, enforcement on every byte-adding path, meters, banners, dialogs, Storage page, backfill); app homes filtered to their kind with the left menu (app links, settings, *Report a bug*, storage meter); **settings split** (Wonky Works vs app settings); *Report a bug* in every editor; shared-package extraction `wonky_code*`, `wonky_charts*` (no behavior change). [Drive 05](wonky_drive/05-implementation-plan.md) | Journeys 11–13 (11 §1.1); quota enforcement table (Drive 03 §7.2) fully tested; backfill dry run on a production copy; Write/Sheets goldens unchanged after the extractions. |
| **M9 · Slides MVP** | Slides data model + sync (one deck = one space, space-kind filter OS-8, shared sync kit), editor canvas and core objects (text, shapes, lines, images, tables, groups), themes/layouts/masters, slide navigator with **slide groups**, outline/grid views, speaker notes, presenting (incl. the presenter view decision, 03 §1), PDF export, app home + settings, offline creation. | Journey 14 (without builds/code/charts); offline merge fuzzer for decks green; PDF fidelity suite. |
| **M10 · Slides motion & content** | Builds and the animation pane, transitions incl. Magic Move, code blocks with line highlighting and type-in/morph (`wonky_code`), linked Sheets charts incl. 3D and camera animation (`wonky_charts`), native charts (P1). | Journey 14 complete; 60 fps budgets of Slides 01 met on the reference machines. |
| **M11 · Slides collaboration, MCP & AI** | Presence, soft locks, comments on slides/elements, version history, activity; `slides.*` headless and `ui.slides.*` tools; assistant in Slides (generate decks, notes, alt text, code walkthroughs) and in Drive (P1). | Journey 15; MCP integration suite for `slides.*` green. |

The M9–M11 breakdown is in [Slides 12](wonky_slides/12-implementation-plan.md). M8 must land
the shell changes (scope-aware homes, settings split, `WonkyAppKind` with four apps) before
Slides UI work starts in M9, and the `wonky_code*`/`wonky_charts*` extractions before M10.

## 3. Workstreams (suite-level, shared)

| ID | Workstream | Owns | Depends on | Milestone |
|----|------------|------|-----------|-----------|
| WS-0 | Repo restructure, CI, workspace, web build/serving (`flutter_build`, app routes), cookie auth config | root, CI scripts, `wonky_server/pubspec.yaml`, `wonky_server/lib/server.dart` (web routes) | — | M0 |
| WS-1 | `wonky_core`: ids, roles, command & undo abstractions, MCP tool schema types | `packages/wonky_core` | — | M0 |
| WS-2 | `wonky_ui`: theme, tokens, custom widgets (02 §4) | `packages/wonky_ui` | — | M0–M1 |
| WS-3 | Shell: routing, layout, overlays, connectivity, command registry/dispatcher, keymap, palette, undo service | `wonky_app/lib/{shell,commands,undo}` | WS-1, WS-2 | M0–M1 |
| WS-4 | Auth & accounts & settings | server `platform/users`, `wonky_app/lib/auth`, `…/settings` | WS-3 | M1 |
| WS-5 | Drive (server + UI) | server `platform/drive`, `wonky_app/lib/drive` | WS-4 | M1 |
| WS-6 | Sharing & AccessService (+ space membership mirroring hook) | server `platform/sharing`, `wonky_app/lib/sharing` | WS-5 | M1, M4 |
| WS-7 | Presence & notifications | server `platform/{presence,notifications}`, `wonky_app/lib/{presence,notifications}` | WS-3 | M1, M4 |
| WS-8 | Comments framework (server + shared UI) | server `platform/comments`, `wonky_app/lib/comments` | WS-6 | M4 |
| WS-9 | Versions framework | server `platform/versions`, `wonky_app/lib/versions` | WS-5 | M4 |
| WS-10 | MCP platform: route, auth tokens, ToolExecutor, UI bridge hub + client bridge, shared tools (drive/comments/versions/changes) | server `platform/mcp`, `wonky_app/lib/mcp_bridge`, `wonky_mcp_stdio` | WS-1, WS-5 | M0 spike, M6 |
| WS-11 | AI platform: Anthropic client, assistant service/endpoint, shared panel | server `platform/ai`, `wonky_app/lib/assistant` | WS-10 | M6 |
| WS-12 | Files/uploads/signed URLs | server `platform/files` | WS-4 | M1 |
| WS-13 | Quality infra: test helpers of 15 (`pumpWonky`, `CommandTestHarness`, `TestUsers`, `forEachRole`, seeded generators, golden script), harnesses, multi-client simulators, perf suite, golden matrix | `tool/`, `benchmark/`, `lib/testing.dart` + `test/support/` of each package | WS-0 | M0 → ongoing |
| WS-14 (v2) | Drive app, files, uploads, previews (Drive WS-D1, WS-D5, WS-D6, WS-D8) | `wonky_drive/`, server `platform/{drive,files}` | WS-5, WS-12 | M8 |
| WS-15 (v2) | Storage quota (Drive WS-D2) | server `platform/storage` + hooks | WS-14 | M8 |
| WS-16 (v2) | Shell v2: scope-aware homes, left menu, `WonkyAppKind` ×4, storage UI, *Report a bug* (Drive WS-D3, WS-D7) | `wonky_app/lib/src/{drive,shell,storage,routing}`, app home configs | WS-3, WS-5 | M8 |
| WS-17 (v2) | Settings split (Drive WS-D4) | `wonky_app/lib/src/settings`, app settings sections | WS-16 | M8 |
| WS-18 (v2) | Shared packages: `wonky_code*`, `wonky_charts*` (Drive WS-D9), dependency rules | `packages/wonky_code*`, `packages/wonky_charts*`, `tool/check_dependencies.dart` | — | M8 (before M10) |
| WS-19 (v2) | Shared sync kit + OS-8 space filter + space kinds | `packages/wonky_sync_kit`, `third_party/serverpod_offline_sync`, server `sheets/spaces` | — | M9 (Slides 12) |

App workstreams: see the app plans (WS-W*, WS-S*, (v2) WS-D*, Slides 12).

## 4. Dependency graph (simplified)

```
WS-0 ─┬─ WS-1 ─┬─ WS-3 ─┬─ WS-4 ─ WS-5 ─┬─ WS-6 ─ WS-8
      │        │        │               ├─ WS-9
      └─ WS-2 ─┘        ├─ WS-7         └─ WS-10 ─ WS-11
                        └─ (Write WS-W*, Sheets WS-S* start after WS-3 contracts exist)

(v2)  WS-14 ─ WS-15            WS-16 ─ WS-17            WS-18 ─────────────┐
        └──────── M8 exit ─────────┴──────── M8 exit         WS-19 ─ Slides M9 ─ M10 ─ M11
```

## 5. Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| `serverpod_offline_sync` maturity (0.0.x, experimental) and scale limits | Sheets data loss/perf | Vendored patch, extensive fuzzing, staged cell limits, upstream requirements U1–U11 (12 §4) — the team can contribute upstream |
| super_editor pre-1.0 API churn; gaps (tables read-only, no incremental Quill apply) | Write delays | Vendored copy (01 §2.3) with focused patches SE-1…SE-5; our mapper/applier/extractor layer isolates the rest of the app; upgrade only deliberately |
| Web SQLite (OPFS availability, IndexedDB memory) | Large offline sheets on some browsers | Detect storage mode, limit offline size, warn |
| `dart_eval` performance and language coverage; web worker complexity | Scripting UX | Server-side compile; documented language subset; generous timeouts; P1 features gated |
| Formula compatibility | User trust | Differential tests vs LibreOffice; golden vectors |
| MCP spec evolution | Integration breakage | `mcp_dart` protocol profiles; integration tests per profile |
| Scope (Google Docs + Sheets parity) | Schedule | P0/P1/P2 priorities in app overviews; milestones deliver usable slices |
| (v2) Sync engine syncs every member space (decks + spreadsheets in both replicas) | Slides/Sheets download each other's data | OS-8 space filter patch, space kinds (12 §2.6) |
| (v2) Existing users above the new 50 MB quota | Frustration, support | Non-destructive over-quota state, clear Storage page, one-time notice (Drive 03 §9) |
| (v2) Shell refactor for four apps collides with app work | Merge conflicts | WS-16 lands first in M8 behind a compatibility default (Drive 05 §4) |
| (v2) Four web builds | Deploy time, CI minutes | Parallel builds in `flutter_build`; only changed apps rebuilt in CI (01 §2.4) |
