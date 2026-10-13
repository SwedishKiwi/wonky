# 11 · Quality: Testing, Performance, Accessibility, Internationalization

## 1. Testing strategy

This section defines *what* is tested at which level. *How* to write the tests (layout,
naming, helpers, determinism, running them) is in [15 · Writing tests](15-writing-tests.md).

| Level | Tooling | Scope | Where |
|-------|---------|-------|-------|
| Unit | `test` / `flutter_test` | Pure logic: Delta schema, Markdown codec, OT helpers, formula parser/evaluator/functions, number formats, fractional index, ids, undo handlers, command arg parsing | `*_core/test`, app `test/` |
| Property / fuzz | `test` + seeded random generators (`glados`-style custom generators) | OT convergence (Write), Markdown round-trip, offline merge convergence (Sheets, multiple simulated clients in **separate isolates** — `serverpod_database` has a process-wide encoder), undo invariants, formula codec A1⇄stored | `*_core/test/property`, server `test/property` |
| Server | `serverpod_test` (`withServerpod`, embedded Postgres via `config/test.yaml` `database.dataPath`; no Docker) | Endpoints, services, stream endpoints, MCP route, permissions, sync endpoint wrapper, version providers, scripting compile service | `wonky_server/test/{unit,integration}` |
| Widget | `flutter_test` | Every `wonky_ui` widget (light + dark), dialogs, panels, menus generated from `MenuSpec` | package `test/` |
| Golden | `flutter_test` goldens (+ `alchemist`-style multi-theme matrix) | Editor rendering per Write theme (light/dark), grid rendering (formats, borders, merges, CF), charts, PDF page renders | app `test/goldens` |
| Integration / E2E | `flutter_driver` via the `dart` MCP + `serverpod` MCP (`spawn_flutter_app`, `get_flutter_app_dtd`), `integration_test` | Critical user journeys (below), multi-client collaboration (two app instances), offline/online transitions | app `integration_test/` |
| Export validation | CI containers: LibreOffice headless (DOCX/ODT/XLSX/ODS open + convert), `epubcheck`, PDF text extraction | Export fidelity | CI |
| Performance | Benchmarks (`benchmark_harness`), Flutter `--profile` traces, custom perf suite | Budgets in §2 | `benchmark/` |

**Contract tests**: every command has an execute→undo→redo test (see 08 §4). Every MCP tool
has an integration test through `/mcp`. Every endpoint has permission tests for each role.

### 1.1 Critical user journeys (E2E, run on web + macOS in CI)
1. Sign up → verify → create document → type with formatting → reload → content persists.
2. Two users co-edit the same paragraph; cursors visible; converge; each undoes only own edits.
3. Go offline, edit document and spreadsheet, go online → changes sync, no data loss.
4. Create spreadsheet, enter data + formulas, sort, filter, chart → reload offline → identical.
5. Share with commenter; commenter comments and suggests; owner accepts suggestion.
6. Restore a previous version in both apps; undo the restore.
7. Export document to PDF/DOCX and spreadsheet to XLSX/PDF; import them back.
8. MCP: create doc via `drive.create_document`, edit via `write.insert_markdown`, control UI via
   `ui.invoke_command`; Sheets via `sheets.set_values` + `ui.sheets.select_range`.
9. Theme editor: create theme, apply, verify editor + PDF reflect it in light & dark.
10. Script: custom function used in a formula; onEdit trigger; time-driven trigger runs on server.

## 2. Performance budgets (summary; details in app specs)

| Area | Budget |
|------|--------|
| App cold start (web, cached assets) | < 2.5 s to interactive home; desktop < 1.5 s |
| Open document (cached) | < 300 ms first paint |
| Write keystroke latency | < 16 ms p95 (100-page doc) |
| Write remote op visible | < 250 ms p95 same region |
| Sheets open 1M cells | < 3 s to first viewport paint (background load continues) |
| Grid scroll | 60 fps at 1M cells (desktop), ≥ 45 fps web |
| Cell commit (local) | < 16 ms; recalculation of 100k dependents < 1 s native, < 2 s web |
| Sheets remote change visible | < 300 ms via commit hint; < 3 s via sync |
| Memory | Web tab < 1.5 GB at 1M cells; desktop < 2 GB |
| Bundle size (web, per app, compressed) | < 6 MB initial (deferred loading for exporters, charts, script runtime, theme editor) |

Use Flutter deferred imports (`deferred as`) for heavy, rarely used features on web: exporters,
importers, theme editor, chart editor, pivot editor, script editor + runtime, AI panel.

## 3. Accessibility (WCAG 2.2 AA target)
- Keyboard: every action reachable by keyboard; visible focus; no traps (Esc always exits
  overlays); skip-to-content shortcut in shell.
- Screen readers: Flutter `Semantics` on all controls; editor exposes document text (super_editor
  semantics) and announces formatting changes; grid announces "B4, 42, formula =SUM(…), bold"
  on navigation and range sizes on selection change; live regions for sync status, remote
  joins, errors.
- Contrast ≥ 4.5:1 text, ≥ 3:1 UI components in both themes; theme editor and CF warn on low
  contrast.
- Respect OS reduce-motion, text scaling (chrome scales to 200% without overlap; document zoom
  separate), high contrast (Windows) where available.
- Settings › Accessibility: screen-reader optimizations (e.g. disable remote cursor flags,
  verbose announcements), always show keyboard focus.

## 4. Internationalization
- `flutter_localizations` + `intl` ARB files in `wonky_app/lib/l10n` (shared strings) and per app
  (`wonky_write/lib/l10n`, `wonky_sheets/lib/l10n`); shad's own
  `GlobalShadLocalizations` for component strings.
- v1 ships English; all strings externalized from day one; pseudo-locale (`en_XA`) build for
  testing truncation/RTL (`ar_XB`).
- Pseudo-locale: `dart run tool/pseudo_locale.dart <x_en.arb> <x_en_XA.arb>` regenerates an
  `en_XA` ARB (accented letters, ~35% padding, `[…]` brackets; ICU placeholders, plural/select
  and `#` kept; `--self-test` checks the transform) — rerun it after adding keys. Build or run
  any app with `--dart-define=WONKY_LOCALE=en_XA` (or any supported tag, e.g. `en`) to force the
  shell's locale; shad, Flutter's `Global*Localizations` and untranslated keys fall back to `en`.
- RTL: shell mirrors; Write supports RTL paragraphs (super_editor RTL support); Sheets has
  per-sheet RTL.
- Locale-aware formatting of dates/numbers in UI; Sheets uses the spreadsheet locale for cell
  parsing/formatting independent of UI language.

## 5. Observability
- Server: Serverpod session logs (structured), slow-query logging, per-endpoint metrics, OT
  metrics (ops/s, transform time, rejections), sync metrics (cycle time, batch sizes,
  violations from `offline_sync_integrity_violations`), MCP/AI usage and errors.
- Client: error reporting endpoint (`feedback.reportError` with stack, app/build version,
  route, anonymized state), performance marks (open time, frame drops) sampled.
- Health: Serverpod health endpoints (`/livez`, `/readyz`) with custom indicators (DB, Redis,
  Anthropic reachability (non-critical), storage).

## 6. Code quality rules
- `dart analyze` clean (strict-casts, strict-inference, strict-raw-types), `dart format`.
- No business logic in widgets; no direct client calls from widgets.
- Generated code never edited (see AGENTS.md).
- Vendored packages in `third_party/` are changed only with a `PATCHES.md` entry and tests
  (01 §2.3); their own test suites run in CI.
- Synced-table update lint test (columns named) — fails CI.
- Package dependency rule check script (01-architecture §2.1) — fails CI.
- Every public API in `*_core` packages documented.
