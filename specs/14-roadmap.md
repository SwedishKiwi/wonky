# 14 · Roadmap, Milestones and Parallel Workstreams

This is the suite-level plan. App-level breakdowns:
[Write implementation plan](wonky_write/10-implementation-plan.md),
[Sheets implementation plan](wonky_sheets/13-implementation-plan.md).

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

App workstreams: see the two app plans (WS-W*, WS-S*).

## 4. Dependency graph (simplified)

```
WS-0 ─┬─ WS-1 ─┬─ WS-3 ─┬─ WS-4 ─ WS-5 ─┬─ WS-6 ─ WS-8
      │        │        │               ├─ WS-9
      └─ WS-2 ─┘        ├─ WS-7         └─ WS-10 ─ WS-11
                        └─ (Write WS-W*, Sheets WS-S* start after WS-3 contracts exist)
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
