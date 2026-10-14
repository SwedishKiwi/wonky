# Slides 12 · Implementation Plan

This plan turns the Slides specs into milestones and **work packages SL-1…SL-45** that parallel
coding agents execute in **waves**: each package is a few hours of agent work, owns its folders,
names the contracts it provides and consumes, and ends with acceptance tests. It follows the
Sheets plan ([Sheets 13](../wonky_sheets/13-implementation-plan.md)), the agent rules of
[Drive 05 §2](../wonky_drive/05-implementation-plan.md) and the decisions of the
[v2 review](../v2-review.md). **v2 is web only** (suite [01 A13](../01-architecture.md)): no
desktop-specific work is planned; desktop builds only have to compile.

Spec map: [01](01-overview.md) · [02](02-data-model.md) · [03](03-editor-canvas-and-objects.md) ·
[04](04-screens-menus-toolbar.md) · [05](05-themes-layouts-masters.md) ·
[06](06-animations-and-transitions.md) · [07](07-code-blocks.md) ·
[08](08-charts-from-sheets.md) · [09](09-collaboration-history.md) ·
[10](10-presenting-and-pdf.md) · [11](11-mcp-and-ai.md). Suite: [01](../01-architecture.md),
[08](../08-commands-and-undo.md), [12](../12-offline-and-sync.md), [14](../14-roadmap.md),
[15](../15-writing-tests.md).

---

## 1. Milestones

Suite milestones after the Sheets first iteration (D14): **M8** Drive + suite changes → **M9**
Slides MVP → **M10** Slides motion & content → **M11** Slides collaboration, MCP & AI.

| Milestone | Slides scope | Exit gate |
|-----------|--------------|-----------|
| **M8** Drive + suite changes (prerequisite, [Drive 05](../wonky_drive/05-implementation-plan.md)) | Unified Drive with `presentation` kind and `registerPresentation`; app homes filtered per kind; settings split; Report a bug; 50 MB quota; **shared packages extracted** (Drive 05 D-2 `wonky_code*`, D-3 `wonky_numfmt`/`wonky_charts*`, D-4 space kinds + OS-8, D-6 `wonky_sync_kit*`, D-7 `wonky_rich_text`/`wonky_fonts`/`wonky_spellcheck`); **SL-1**: `wonky_slides` skeleton boots in the shell at `/slides/` (dev port 8104) with its home | Sheets and Write green after the extractions (no behavior change); Slides home lists presentations; an empty deck route renders "Coming soon" |
| **M9** Slides MVP | Synced schema release **S-1** with every Slides table of 02 §3 + all synced additions from 03–11 known at M9; ids; `DeckModel`; planner + undo; sync (spaces, `slidesSync`, change-log consumer); canvas, selection, transforms, smart guides, align/distribute; text (super_editor overlay), shapes, lines/connectors, images, tables, icons; element groups, lock/hide/z-order; format painter; clipboard (within/across decks, Write/Sheets/OS); find & replace; navigator with **slide groups** (D11); grid view; speaker notes; inspector (Format + Slide tabs); menus/toolbar/context menus; themes (10 built-ins), layouts (16), placeholders, Themes panel, page setup; presence roster + **soft locks** + text hints; **present** (full screen, keyboard, slide picker with groups, **presenter view in this window**, **audience on another device or browser** via the presentation session — no second window, v2 review Q29); **PDF export** (slides, notes pages, skipped in/out, group bookmarks); thumbnails; templates (5 of 10) | Journeys J-S1…J-S4 (§7.6) pass on the web; command harness green; multi-client scenarios 09 §6.4 #1–17, 21–22, 26–29 pass; perf budgets of 03 §18 (web); PDF of the reference decks validated (§7.7) |
| **M10** Motion & content | Builds, animation pane (Inspector › Animate), transitions incl. 3D, **Magic Move**, timeline model, reduced motion (06); laser/pen/highlighter, loop/kiosk (10); code blocks, highlight steps, **type-in**, morph (07); Write exports on the shared tokenizer (Q25); **linked Sheets charts** with update/client-side auto-update (Q28)/unlink, native charts (P1), **3D charts** with animatable camera (08); PDF builds as pages; outline view; masters & layout editing + theme editor (05 §8); Layers panel; accessibility checker; templates 10 of 10 | Journeys J-S5…J-S7; timeline determinism tests (client ≡ server frames); 60 fps transitions on the reference machine in Chrome; scenarios #18–20, 23–25 |
| **M11** Collaboration, MCP & AI | Live pointers, follow mode, follow presenter, transform hints (09 §1–2); comments on slides/elements; version history (snapshots, per-slide diff, restore, copies); overwritten-text review; activity; phone remote, rehearse, same-browser fast path (10, P1 items); `slides.*` headless MCP tools + `ui.slides.*` (11); AI features (11) and the Drive assistant (P1); remaining P1 items (spelling, emoji, image adjustments, curved connectors) | Journeys J-S8…J-S10; all §7.3 scenarios; MCP integration suite; a11y checklist; no open P0/P1 bugs |

**Synced schema releases.** S-1 (M9, SL-2) contains every table and column defined in 02 and
the additions listed in 02 §14 at that time. Additions discovered later are batched into S-2
(start of M10, SL-24) and S-3 (start of M11, SL-37) at most; each release bumps
`syncTablesHash` for **all** apps (Sheets clients must update too, suite 01 §7), so releases are
coordinated with Sheets.

---

## 2. How the agents work

The rules of [Drive 05 §2](../wonky_drive/05-implementation-plan.md) apply unchanged: ≤ 5
agents at once on the 16 GB laptop, ≤ 2 concurrent server test runs, **one web-build token**
(named per wave in §4), one shared working tree, ownership by folder, one open migration at a
time, agents never start the server. Slides-specific additions:

- **Registration files**: SL-11 owns the command registration index
  (`wonky_slides/lib/commands/commands.dart`), `MenuSpec`, toolbar spec and the inspector/panel
  registries; other packages add one-line registrations and own their
  `commands/<area>_commands.dart`.
- **Synced schema**: only SL-2 (S-1), SL-24 (S-2) and SL-37 (S-3) change synced models; other
  packages queue their additions in 02 §14 and the next release picks them up.
- **Contract changes** after a contract package merged go through a small contract PR that the
  owners of the consuming packages review.
- **Ownership moves**: when a package is merged, its folders may be extended by later packages
  that name them under *Owns* (e.g. `features/present/` by SL-29).

---

## 3. Existing code to reuse

| Need | Start from |
|------|------------|
| Session per open file | `wonky_sheets/lib/features/model/{workbook_session,memory_workbook_session}.dart` → `DeckSession`/`MemoryDeckSession` (§5.3) |
| Replica, sync controller, writer, journal | `wonky_sync_kit_flutter` (extracted by Drive 05 D-6 from `wonky_sheets/lib/features/sync/`); `synced_workbook_session.dart` as the model for `SyncedDeckSession` |
| Planner, row changes, undo | `wonky_sync_kit` (`RowChange`, `MutationPlan`, `UndoInverter`); Sheets' `wonky_sheets_core/lib/src/mutations/{planner,plan_builder,operations,maintenance}.dart` as the pattern |
| Server spaces, sync, change log, headless | `wonky_server/lib/src/platform/spaces/` (D-4), `wonky_server/lib/src/sheets/{sync,changelog,headless,versions,exports}/` (`server_sheets_writer.dart`, `change_log_consumer.dart`, `headless_workbook*.dart`, `sheets_export_service.dart`) |
| Rich text | `wonky_rich_text` (D-7) and Write's super_editor integration in `wonky_write/lib/features/editor/` (mapper/applier/extractor) |
| Charts | `wonky_charts`, `wonky_charts_flutter`, `wonky_numfmt` (D-3); Sheets' chart insert/editor UI in `wonky_sheets/lib/features/charts/` as the UX reference |
| Code | `wonky_code`, `wonky_code_flutter` (D-2) |
| Shell, homes, comments, versions, presence, MCP bridge, assistant | `packages/wonky_app/lib/src/{drive,comments,versions,presence,mcp_bridge,assistant}/`; server `platform/{comments,versions,presence,mcp,ai}/` |
| Exports, print preview | Write `wonky_write_core/lib/src/export/pdf/`, `wonky_write/lib/features/print/`; Sheets `wonky_sheets/lib/features/print/` |

---

## 4. Work packages

### 4.1 Overview

| WP | Title | Milestone · wave | Depends on | Token |
|----|-------|------------------|-----------|-------|
| SL-1 | App skeleton, serving, home | M8 · Drive wave 4 | D-5, D-10 | (D-18 builds) |
| SL-2 | Synced schema S-1, ids, columns lint | M9 · 1 | D-6 | |
| SL-3 | Core contracts, `DeckSession`, test harness | M9 · 1 | SL-2 (types) | |
| SL-4 | Spike: super_editor text overlay | M9 · 1 | SL-1 | |
| SL-5 | Server: deck spaces, `slidesSync`, change-log consumer | M9 · 1 | SL-2, D-4 | |
| SL-6 | Themes core, layouts, built-in themes, fonts | M9 · 1 | D-7 | |
| SL-7 | Core model, resolvers, planner, maintenance | M9 · 2 | SL-3 | |
| SL-8 | Copier, clipboard codec, text schema, headless deck | M9 · 2 | SL-3, SL-5 | |
| SL-9 | Client sync, replica, `SyncedDeckSession`, offline creation | M9 · 2 | SL-3, SL-5 | |
| SL-10 | Scene, text layout, geometry, connectors, stage, thumbnails | M9 · 2 | SL-3, SL-6 | |
| SL-11 | Chrome: editor screen, menus, toolbar, inspector shell, home, settings | M9 · 2 | SL-1, SL-3 | ✓ |
| SL-12 | Canvas, selection, transforms, snapping | M9 · 3 | SL-7, SL-10 | |
| SL-13 | Text editing overlay and placeholders | M9 · 3 | SL-4, SL-10, SL-12 (API) | ✓ |
| SL-14 | Shapes, lines/connectors, icons, groups, z-order, format painter | M9 · 3 | SL-7, SL-10, SL-12 (API) | |
| SL-15 | Images and tables | M9 · 3 | SL-7, SL-10, SL-12 (API) | |
| SL-16 | Navigator, slide groups, grid view, notes | M9 · 3 | SL-7, SL-10, SL-11 | |
| SL-17 | Themes panel, layout apply, page setup | M9 · 4 | SL-6, SL-11, SL-12 | |
| SL-18 | Clipboard UI, cross-app paste, find & replace | M9 · 4 | SL-8, SL-13…SL-15 | |
| SL-19 | Present mode, presenter view, presentation session | M9 · 4 | SL-10, SL-11, SL-16 | ✓ |
| SL-20 | PDF export and print preview | M9 · 4 | SL-10 | |
| SL-21 | Presence, soft locks, text hints | M9 · 4 | SL-9, SL-13 | |
| SL-22 | Templates (5 of 10) | M9 · 5 | SL-6, SL-8 | |
| SL-23 | M9 integration and exit | M9 · 5 | all M9 | ✓ |
| SL-24 | Timeline core and builds model (+ schema S-2) | M10 · 1 | SL-7, SL-10 | |
| SL-25 | Transitions and Magic Move core | M10 · 1 | SL-10, SL-24 (API) | |
| SL-26 | Code core (`wonky_code` layout/type-in/morph, code element model) | M10 · 1 | D-2, SL-7 | |
| SL-27 | Chart link core, `wonky_charts` additions, server chart endpoint | M10 · 1 | D-3, SL-7 | |
| SL-28 | Masters, layout editing, theme editor | M10 · 1 | SL-17 | |
| SL-29 | Motion player and rendering; present with builds; present tools | M10 · 2 | SL-24, SL-25, SL-19 | ✓ |
| SL-30 | Animate tab, animation pane, transitions UI | M10 · 2 | SL-24, SL-25, SL-11 | |
| SL-31 | Code element UI | M10 · 2 | SL-26, SL-24 (API) | |
| SL-32 | Chart element UI, linked updates, 3D camera | M10 · 2 | SL-27, SL-24 (API) | |
| SL-33 | PDF builds as pages, print frame option, PNG export | M10 · 2 | SL-20, SL-24 | |
| SL-34 | Outline view, Layers panel, accessibility checker | M10 · 3 | SL-14, SL-16 | |
| SL-35 | Write exports on the shared tokenizer | M10 · 3 | SL-26 | |
| SL-36 | Templates 10 of 10, M10 integration and exit | M10 · 3 | all M10 | ✓ |
| SL-37 | Live collaboration (+ schema S-3) | M11 · 1 | SL-21 | |
| SL-38 | Comments on slides and elements | M11 · 1 | SL-12, SL-16 | |
| SL-39 | Version history, overwritten-text review, activity | M11 · 1 | SL-8, SL-9 | |
| SL-40 | MCP headless tools `slides.*` | M11 · 1 | SL-8, SL-20, SL-24…SL-27 | |
| SL-41 | Phone remote, rehearse timings, same-browser fast path | M11 · 1 | SL-19, SL-29 | ✓ |
| SL-42 | UI bridge `ui.slides.*` | M11 · 2 | SL-11, SL-40 | |
| SL-43 | AI in Slides (+ Drive assistant, P1) | M11 · 2 | SL-40 | |
| SL-44 | Remaining P1: spelling, emoji, image adjustments, curved connectors | M11 · 2 | D-7, SL-13…SL-15 | |
| SL-45 | M11 integration and exit | M11 · 2 | all M11 | ✓ |

Waves hold ≤ 5 packages; a later wave's package starts as soon as its dependencies are merged
(M9 wave 5 overlaps M10 wave 1). "(API)" means only that package's contract must be merged.
Critical path to M9: D-6 → SL-2 → SL-3 → SL-7/SL-10 → SL-12 → SL-13 → SL-18/SL-21 → SL-23.

```
M8   D-wave 1–3 extractions ──────────────────────────────── SL-1 skeleton (D-wave 4)
M9 1 SL-2 schema ─ SL-3 contracts      SL-4 spike   SL-5 server sync   SL-6 themes core
   2 SL-7 model/planner · SL-8 copier/headless · SL-9 client sync · SL-10 scene/stage · SL-11 chrome
   3 SL-12 canvas · SL-13 text · SL-14 shapes/lines/groups · SL-15 images/tables · SL-16 navigator
   4 SL-17 themes UI · SL-18 clipboard/find · SL-19 present · SL-20 PDF · SL-21 soft locks
   5 SL-22 templates · SL-23 M9 exit
M10 1 SL-24 timeline · SL-25 transitions · SL-26 code core · SL-27 chart core · SL-28 masters
    2 SL-29 player · SL-30 Animate UI · SL-31 code UI · SL-32 chart UI · SL-33 PDF builds
    3 SL-34 outline/layers/a11y · SL-35 Write export tokenizer · SL-36 M10 exit
M11 1 SL-37 live collab · SL-38 comments · SL-39 history · SL-40 MCP · SL-41 remote/rehearse
    2 SL-42 UI bridge · SL-43 AI · SL-44 P1 leftovers · SL-45 M11 exit
```

Paths below: `app/` = `wonky_slides/lib/`, `core/` = `packages/wonky_slides_core/lib/src/`,
`server/` = `wonky_server/lib/src/slides/`.

### 4.2 M8 (in Drive 05 wave 4)

**SL-1 · App skeleton, serving, home**
- Scope: `wonky_slides` workspace member, `main.dart`, `driver.dart`, minimal `SlidesAppConfig`
  (`app: slides`, `primaryKind: presentation`, `HomeScope.kind(presentation)`, deck route
  "Coming soon"); `webApps`/`FlutterRoute` `/slides/`, `flutter_apps` alias `slides` (8104,
  `auto_launch: false` while under construction), `flutter_build` entry, origins, web icons,
  AGENTS.md lines; `wonky_slides_core` package scaffold.
- Owns: `wonky_slides/` (scaffold), `packages/wonky_slides_core/` (scaffold), additive lines in
  `wonky_server/{pubspec.yaml,config/*.yaml,lib/server.dart}`, `AGENTS.md`.
- Acceptance: the Slides home lists presentations (none yet) with the left menu; `/slides/p/x`
  shows "Coming soon"; analyze/format clean; D-18 includes Slides in its release build check.

### 4.3 M9 wave 1 — contracts and foundations

**SL-2 · Synced schema S-1** (02 §3, §14)
- Scope: every `.spy.yaml` of 02 §3 + enums + the synced additions of 03–11 known now,
  `SlidesIds` (deterministic ids), table codec registration in `wonky_sync_kit`, server and client
  migrations, `syncTablesHash` bump coordinated with Sheets, columns lint test.
- Owns: `packages/wonky_sync_models/lib/src/models/slides/**`,
  `packages/wonky_sync_models/lib/src/ids/slides_ids.dart`, `wonky_server/migrations/`,
  `wonky_slides/test/sync/columns_lint_test.dart`.
- Provides: generated model types for everything else.
- Acceptance: generated code compiles; deterministic id tests; S-1 hash recorded in 02;
  Sheets suites green with the new hash.

**SL-3 · Core contracts, `DeckSession`, harness** (§5)
- Scope: records and `DeckModel` API, the sealed `SlidesOperation` set, `SlidesPlanContext`,
  `PlanException`; scene node types and `TextLayoutEngine`; `SlideTimeline` stub (zero steps,
  `printFrame` = edit frame); `ElementKindHandler` registry; server interfaces
  (`DeckChangeLogConsumer`, `HeadlessDeckProvider`, `SlidesPdfRenderer`); `DeckSession`,
  `DeckLoadState`, `MemoryDeckSession`; `CommandTestHarness` setup and fixture builders.
- Owns: `core/{model/api,ops,scene/nodes,motion/stub,interfaces}/`, `app/features/model/`,
  `wonky_slides/test/harness/`.
- Acceptance: contracts compile with fakes; a harness smoke test runs a no-op command
  execute → undo → redo on `MemoryDeckSession`.

**SL-4 · Spike: super_editor overlay** (03 §6.1, v2 review Q20) — timebox 1 day
- Scope: prototype an overlay editor over a rotated text box with `SlidesDeltaMapper`; measure
  enter-editing latency (< 50 ms) and line-break equality with static rendering.
- Owns: `app/features/text_editing/spike/` (deleted or promoted by SL-13).
- Acceptance: decision record appended to 03 §6.1 (confirm super_editor, or the documented
  fallback with numbers).

**SL-5 · Server: deck spaces, `slidesSync`, change-log consumer** (02 §9, 09)
- Scope: deck kind on `SpaceService` (D-4), `slidesSync.sync` with `onMergeSuccess` and the
  OS-8 filter (deck spaces + personal space), `SlidesEndpoint.{reserveSpaces, subscribe,
  ensureSubscribed, spaceStats}` (+ `revertChange`/`reapplyChange` stubs), membership mirrored
  from the ACL, title mirroring into the drive item, `DeckChangeLog` consumer skeleton with the
  plugin registry (§5.7), `ServerSlidesWriter` skeleton.
- Owns: `server/{spaces,sync,changelog,endpoints}/`.
- Acceptance: server tests — reserve/subscribe per role, a Sheets client never receives deck
  rows, consumer exactly-once across restarts, title mirroring.

**SL-6 · Themes core** (05 §2–§7)
- Scope: theme JSON schemas, validator, migrations, resolver; 16 built-in layouts; 10 built-in
  themes as JSON; slide sizes and scaling math; Slides display families registered in
  `wonky_fonts` (static TTF, OFL).
- Owns: `core/theme/**`, `packages/wonky_fonts/` (Slides families only).
- Acceptance: 05 §12 unit tests (validation, resolution, layout remap, size scaling); every
  built-in theme × layout resolves without warnings.

### 4.4 M9 wave 2 — model, sync, scene, chrome

**SL-7 · Core model and planner** (02 §10–§12)
- Scope: `DeckModel` ingestion and indexes, `SlideResolver`, `TextStyleResolver`,
  `SlidesMutationPlanner` with every op of 02 §12.1 (build/code/chart ops as stubs for M10),
  coupled-column groups for `UndoInverter`, maintenance rules (02 §10), limits.
- Owns: `core/{model,mutations,maintenance}/**`.
- Acceptance: execute → undo → redo equality for every op; seeded op-sequence property test
  (invariants of 02 §10 hold; undo of all returns to the start); incremental remote patch ≡
  full reload; ≥ 90 % line coverage.

**SL-8 · Copier, clipboard codec, text schema, headless deck**
- Scope: `DeckCopier` (id rewrite, reference remap, file re-homing plan), `SlidesClipboardCodec`,
  text schema validator/normalizer on `wonky_rich_text`, `HeadlessDeck` + `ServerSlidesWriter`
  (server write path for templates, copies, MCP), `drive.copy`/*Make a copy* for decks.
- Owns: `core/{copy,clipboard,text}/**`, `server/headless/**`.
- Acceptance: copier property test (no id collisions, every reference remapped); clipboard
  round trip; headless create → read → copy tests on the server.

**SL-9 · Client sync and sessions** (02 §9, suite 12)
- Scope: `SlidesSyncController` on `wonky_sync_kit_flutter`, replica `slides_<userId>.db` (web
  OPFS/IndexedDB), reserved-space pool, `SyncedDeckSession`, offline *New presentation* with
  the queued `drive.registerPresentation`, remote batches, recovery export (web: download of
  `rows.json` per unsynced deck), *Simulate offline*.
- Owns: `app/features/sync/**`, `app/features/model/synced_deck_session.dart`.
- Acceptance: harness — create a deck offline → reconnect → a collaborator sees it in Drive and
  opens it; roles mirror; two clients converge on random edits (smoke property run).

**SL-10 · Scene, text layout, geometry, stage** (03 §6.3, 06 §12.1)
- Scope: `SlideSceneBuilder`, `FlutterTextLayoutEngine` and the core `SlideTextLayout` (pdf
  metrics), auto-fit, `ShapeLibrary` geometry, connector routing, `SlideStage` (edit frame),
  thumbnails.
- Owns: `core/{scene,layout,text_layout,geometry,connectors}/**`, `app/features/stage/**`.
- Acceptance: goldens of every geometry and text style; overlay vs static line breaks equal
  (with SL-13's mapper fake); thumbnail ≤ 8 ms.

**SL-11 · Chrome** (04) — web-build token
- Scope: full `SlidesAppConfig` (routes, `editorRoutes` present/print, `createItem` offline,
  settings sections, `mcpUiTools` stub), editor screen layout, `MenuSpec` (04 §4) with every
  command id registered (unimplemented ones disabled with a reason), toolbar spec, inspector
  shell (tabs, section registry), dialogs host, status bar, keyboard scopes (03 §1.2), palette
  providers, home config + thumbnails, Slides settings sections.
- Owns: `app/{main.dart,driver.dart,config/**,commands/commands.dart}`,
  `app/features/{editor_screen,menus,toolbar,inspector,dialogs,home,settings}/**`.
- Acceptance: 04 AC-1, AC-2, AC-9 (describable dialogs), AC-10, AC-11, AC-12 at the chrome
  level; release build opens an (empty) deck from the home.

### 4.5 M9 wave 3 — editing

**SL-12 · Canvas** (03 §2–§5)
- Scope: zoom/fit/pan, selection model, marquee, handles, move/resize/rotate/nudge, `SnapEngine`
  (core), smart guides, align/distribute; rulers/guides P1.
- Owns: `app/features/{canvas,selection,snapping}/**`, `core/snapping/**`.
- Provides: selection and transform API for SL-13…SL-15 (merge the API first).
- Acceptance: 03 AC 1–3; drag perf budgets of 03 §18 (web).

**SL-13 · Text editing and placeholders** (03 §6.1–§6.2) — web-build token (IME checks)
- Scope: super_editor overlay, `SlidesDeltaMapper`, text commands, placeholders and prompts,
  live auto-fit, typing undo bursts.
- Owns: `app/features/{text_editing,elements/text}/**`.
- Acceptance: 03 AC 4–5; IME and RTL manual check in Chrome and Safari; line-break equality
  goldens.

**SL-14 · Shapes, lines, icons, groups, z-order, format painter** (03 §6.3–§6.5, §7–§9)
- Owns: `app/features/elements/{shape,line,icon,group}/**`, `app/features/format_painter/`.
- Acceptance: 03 AC 6 (shapes/lines/groups parts) and the z-order/lock/hide tests; every
  command execute → undo → redo.

**SL-15 · Images and tables** (03 §6.6–§6.7)
- Scope: every image insert path (upload with quota pre-check, Drive, URL via
  `files.fetchImage`), crop, mask, replace; tables (axes, cells, merge, styles).
- Owns: `app/features/elements/{image,table}/**`, server `platform/files` addition
  `files.fetchImage` (03 A-03-4).
- Acceptance: 03 AC 7; quota refusal shows the shared dialog; table op property test.

**SL-16 · Navigator, slide groups, grid view, notes** (04 §5, §8, §9)
- Owns: `app/features/{navigator,groups,grid_view,notes}/**`.
- Acceptance: 04 AC-3, AC-5, AC-8 (grid part); one-level groups only (Q22).

### 4.6 M9 wave 4 — themes UI, clipboard, presenting, PDF, soft locks

**SL-17 · Themes panel and page setup** (05 §7, §9)
- Owns: `app/features/themes/**`.
- Acceptance: 05 AC 1–8 (apply, import, appearance, scaling).

**SL-18 · Clipboard UI, cross-app paste, find & replace** (03 §12–§13)
- Scope: web Clipboard API + in-app store, paste mappers (Write, Sheets, HTML, plain text,
  images), paste options chip, cross-deck paste with `FileEndpoint.copyToItem` re-homing
  (03 A-03-3, quota-checked), find & replace.
- Owns: `app/features/{clipboard,find}/**`, `copyToItem` in `wonky_server/lib/src/platform/files/`.
- Acceptance: 03 AC 8–10; 04 AC-4 (groups across decks, online and offline).

**SL-19 · Present mode, presenter view, presentation session** (10 §1–§6) — web-build token
- Scope: present route, full screen with the full-window fallback, keymap scope `present`,
  navigation and clicker map, slide picker with groups, black/white, end screen; **presenter
  view in this window** (§5.1); `PresentationEndpoint` with the `audience` role, *Open on
  another device…* (link + QR), *Show audience view here* banner; no `window.open` anywhere
  (v2 review Q5/Q29).
- Owns: `app/features/present/**`, `server/present/**`.
- Acceptance: 10 AC 1–5 and 7; a second browser signed in as the same user follows navigation
  ≤ 300 ms p95 on a LAN; the single-window test of 10 §18.

**SL-20 · PDF export and print preview** (10 §11–§12)
- Scope: core PDF renderer (slides, notes pages, skipped in/out, group bookmarks, links, embedded
  subset fonts), client export (Flutter layout results), server export endpoint, print route;
  handouts P1.
- Owns: `core/export/pdf/**`, `app/features/print/**`, `server/exports/**`.
- Acceptance: 10 AC 12–14 for M9 options; client/server parity diff < 1 % on the corpus.

**SL-21 · Presence, soft locks, text hints** (09 §1.1, §2)
- Owns: `app/features/collab/**` (roster, locks, hints).
- Acceptance: 09 AC 1–3; scenarios 09 §6.4 for locks.

### 4.7 M9 wave 5 — exit

**SL-22 · Templates (5 of 10)** (04 §15)
- Owns: `server/templates/**` (decks as JSON fixtures applied by `ServerSlidesWriter`).
- Acceptance: each template opens offline after first sync; gallery screenshots generated.

**SL-23 · M9 integration and exit** — web-build token
- Scope: J-S1…J-S4, multi-client scenarios for M9, perf budgets, PDF validation corpus,
  AGENTS.md (`auto_launch: true` for `slides`), spec touch-ups.
- Owns: `wonky_slides/integration_test/`, `wonky_slides/test/harness/scenarios/`,
  `benchmark/slides/`.
- Acceptance: the M9 exit gate of §1.

### 4.8 M10 wave 1 — motion, code and chart cores

**SL-24 · Timeline core and builds model** (06 §2–§4, §9; schema S-2)
- Owns: `core/motion/{timeline,builds,effects}/**`, S-2 model additions.
- Acceptance: 06 timeline unit tests; determinism (same input → same frames, client ≡ server);
  print frame per Q24.

**SL-25 · Transitions and Magic Move core** (06 §7–§8)
- Owns: `core/motion/{transitions,magic_move}/**`.
- Acceptance: `MagicMoveMatcher` tests (shapes, text glyphs via `SequenceDiff`, code tokens,
  chart camera); plan budget ≤ 15 ms for the 06 §9.7 fixture.

**SL-26 · Code core** (07 §3–§6)
- Scope: `CodeLayout`, `MonoFontMetrics`, `CodeEditScript`, `TypingScript`, `TokenMorphPlan`,
  `HighlightSteps` in `wonky_code`; `CodeElementModel` and `CodeScene` in the core.
- Owns: `packages/wonky_code/lib/src/{layout,typing,morph,steps}/**`, `core/code/**`.
- Acceptance: 07 §16 unit tests; tokenizer budget of 07 §14.

**SL-27 · Chart link core and server** (08 §2.7, §3, §5, §13)
- Scope: the new `wonky_charts` APIs (reveal state, scene morph, `Chart3DView.lerp`, TTF text
  measurer, snapshot format), chart link data in the core, `SlidesChartEndpoint`
  (`resolveSnapshot`, status), Sheets clipboard payload addition (03 A-03-5).
- Owns: `packages/wonky_charts/lib/src/{reveal,morph,snapshot}/**`, `core/charts/**`,
  `server/charts/**`.
- Acceptance: 08 §20 core and server tests; snapshots contain only resolved series (08 §6).

**SL-28 · Masters, layout editing, theme editor** (05 §8)
- Owns: `app/features/masters/**`, `app/features/themes/editor/**`.
- Acceptance: 05 AC for master and theme editing; undo of every edit.

### 4.9 M10 wave 2 — motion and content UI

**SL-29 · Motion player and rendering** (06 §6, §12–§14; 10 §4, §9) — web-build token
- Scope: `SlidePlayer`, stage frames, transition rendering incl. 3D (`flutter_scene`), reduced
  motion, presenting with builds and transitions, laser/pen/highlighter, loop and kiosk.
- Owns: `app/features/{motion,transitions}/**`, `app/features/present/tools/**`.
- Acceptance: 06 AC; 10 AC 6, 8; 60 fps budget of 06 §14 in Chrome on the reference machine.

**SL-30 · Animate tab and animation pane** (06 §5, §7 UI)
- Owns: `app/features/builds/**`, the inspector's Animate section (`app/features/inspector/animate/`).
- Acceptance: 06 §18 UI criteria; `slides.panel.animate` opens the inspector tab (Q21).

**SL-31 · Code element UI** (07 §3, §7–§8)
- Owns: `app/features/elements/code/**`.
- Acceptance: 07 §15 criteria incl. type-in while presenting (J-S6 parts).

**SL-32 · Chart element UI** (08 §4–§10)
- Scope: insert linked chart, *Update*, client-side auto-update (Q28), unlink/relink, Linked
  objects panel, stale badge, chart builds, 3D camera; native charts (P1).
- Owns: `app/features/elements/chart/**`.
- Acceptance: 08 §19 criteria (J-S7 parts).

**SL-33 · PDF builds as pages, print frame option, PNG** (10 §11, §13)
- Owns: additions in `core/export/pdf/**`, `app/features/print/**`.
- Acceptance: page count = step count; *Show final animation state* (P1) option; PNG export P1.

### 4.10 M10 wave 3 — views, Write switch, exit

**SL-34 · Outline view, Layers panel, accessibility checker** (04 §10, 03 §8, §17)
- Owns: `app/features/{outline_view,layers,accessibility}/**`.
- Acceptance: 04 AC-8 (outline part); checker rules unit-tested.

**SL-35 · Write exports on the shared tokenizer** (07 §2.2, v2 review Q25)
- Owns: the code-highlighting call sites in `wonky_write_core/lib/src/export/**`.
- Acceptance: golden diff review of the Write export corpus (only token colors change); Write
  suites green.

**SL-36 · Templates 10 of 10, M10 integration and exit** — web-build token
- Owns: `server/templates/**`, integration tests and benchmarks for M10.
- Acceptance: the M10 exit gate of §1.

### 4.11 M11 wave 1 — collaboration, history, MCP, remote

**SL-37 · Live collaboration** (09 §1–§2; schema S-3)
- Scope: live pointers, follow mode, follow presenter (followers in the presentation session),
  transform hints.
- Owns: `app/features/collab/**` (extends SL-21), S-3 model additions.
- Acceptance: 09 AC 4–6.

**SL-38 · Comments on slides and elements** (09 §3)
- Owns: `app/features/comments/**`; `CommentAnchorKind` additions in `platform/comments`.
- Acceptance: J-S8; anchors survive cut/paste re-anchoring.

**SL-39 · Version history, overwritten-text review, activity** (09 §4–§6)
- Owns: `app/features/history/**`, `core/{snapshot,diff}/**`, `server/versions/**`.
- Acceptance: J-S9; restore is one undo step; `revertChange`/`reapplyChange` implemented.

**SL-40 · MCP headless tools** (11 §2–§4)
- Scope: `slides.*` tools, resources, prompts, `slides.export_pdf` with
  `refresh_linked_charts`; conditional: server-side chart auto-update index (08 §5.5) only if
  M10 telemetry shows stale decks.
- Owns: `wonky_core/lib/mcp/slides_tools.dart`, `server/mcp/**`, `core/markdown/**`.
- Acceptance: 11 §10 headless criteria; J-S10 headless part.

**SL-41 · Phone remote, rehearse, same-browser fast path** (10 §5.2, §6.4, §10) — web-build token
- Owns: `app/features/present/{remote,rehearse,broadcast}/**`, `server/present/**` (pairing).
- Acceptance: 10 AC 9, 11; the fast path keeps a pair running through a 10 s connection drop.

### 4.12 M11 wave 2 — UI bridge, AI, leftovers, exit

**SL-42 · UI bridge `ui.slides.*`** (11 §5)
- Owns: `wonky_core/lib/mcp/ui_slides_tools.dart`, `app/mcp/**`.
- Acceptance: J-S10 UI-bridge part; every dialog describable (04 AC-9).

**SL-43 · AI in Slides** (11 §6–§8; Drive assistant P1)
- Owns: `server/ai/**`, `app/features/{ai,assistant}/**`, `wonky_drive/lib/features/assistant/` (P1).
- Acceptance: 11 §10 AI criteria with a fake provider; prompt-injection corpus (§7.8).

**SL-44 · Remaining P1** (03 §14, emoji, image adjustments, curved connectors)
- Owns: `app/features/spellcheck/**`, additions in `app/features/elements/{image,line}/**`.
- Acceptance: spelling uses `wonky_spellcheck` + `wonky_app` glue; each item's spec criteria.

**SL-45 · M11 integration and exit** — web-build token
- Acceptance: the M11 exit gate of §1.

---

## 5. Contracts to stub first

Stubbed with fakes by SL-3 at the start of M9 (the shared kit already exists from Drive 05 D-6)
so the packages of §4 can start in parallel.
Names are binding unless changed via a contract PR.

### 5.1 Shared sync kit — pure Dart (extracted from Sheets)

```dart
/// packages/wonky_sync_kit/lib/rows.dart (pure Dart; v2 review Q23)
enum RowOp { insert, update, delete }
final class RowChange {               // = today's Sheets RowChange, moved
  final String table; final String rowId; final RowOp op;
  final Map<String, Object?> columnsBefore, columnsAfter;
  Set<String> get touchedColumns;
}
abstract interface class ChangeSummary { Map<String, Object?> toJson(); }
final class MutationPlan<S extends ChangeSummary> {
  final String label; final S summary; final List<RowChange> changes;
  final Map<String, Object?>? detail;
}
/// Columns that must be skipped together by undo (02 P4).
abstract interface class CoupledColumns { Set<String>? groupOf(String table, String column); }
abstract final class UndoInverter {
  static List<RowChange> invert(MutationPlan plan, CurrentRowReader current,
      {CoupledColumns? coupled, void Function(String table, String rowId, String column)? skipped});
}
abstract interface class SyncTxAdapter {   // client writer and server writer
  Future<void> apply(MutationPlan plan, {required String actorKind, required String sessionId});
}
```

Sheets keeps its cell-specific undo rule (Sheets 02 §7) as a table hook of the generic inverter.

### 5.2 Shared sync kit — client (`wonky_sync_kit_flutter`; extracted from `wonky_sheets/lib/features/sync/`)

```dart
abstract class SyncReplica {            // per user + app: open/close, spaces, reservations, dirty marks
  Future<void> open({required String fileName});   // 'slides_<userId>.db'
  Future<List<String>> reservedSpaces();
  Future<void> purgeSpace(String spaceId);
}
abstract class AppSyncController {      // guard → syncOnce → reservations → syncContinuously; backoff; pause when hidden
  ValueListenable<SyncStatus> get status;
  Stream<SpaceMerge> get merges;        // (spaceId, hlc) after onMergeSuccess
}
abstract class SyncWriter implements SyncTxAdapter { /* chunking, columnValues, change-log row */ }
abstract class ChangeJournal {          // U11 trigger journal per open space
  Future<List<JournaledRow>> since(String spaceId, int cursor);
}
```

### 5.3 `DeckSession` (app, `features/model/deck_session.dart`)

```dart
sealed class DeckLoadState { const DeckLoadState(); }
final class DeckLoading extends DeckLoadState { final double? progress; final String? message; … }
final class DeckReady extends DeckLoadState { const DeckReady(); }
final class DeckUnavailable extends DeckLoadState { final String reason; final bool offline; … }

/// One open deck: the in-memory DeckModel built from the replica and the write path
/// (02 §11–12). Mirrors Sheets' WorkbookSession.
abstract class DeckSession {
  String get deckId;                       // = space UUID = drive item UUID
  UuidValue get itemUuid;
  String get userId;
  DeckModel get model;
  ValueListenable<DeckLoadState> get loadState;
  ValueListenable<SyncStatus> get syncStatus;
  ValueListenable<Role> get role;
  bool get canEdit => role.value >= Role.editor;

  SlidesPlanContext planContext();
  /// Plans [op], applies it to [model] synchronously and persists it asynchronously
  /// (≤ 5,000 changes per transaction + DeckChangeLog). Throws PlanException. No undo
  /// recording: the editor controller pushes a `slides.rows` step with the returned plan.
  MutationPlan execute(SlidesOperation op, {String actorKind = 'user'});
  void applyChanges(List<RowChange> changes, {required String label, String actorKind = 'user'});
  Future<void> flush();
  Stream<DeckChangeBatch> get remoteBatches;
  /// Image bytes/URLs: local bytes for pending uploads, signed URLs otherwise (cached).
  SlideImageResolver get images;
  Future<void> dispose();
}
// Implementations: SyncedDeckSession (replica), MemoryDeckSession (tests, version views,
// previews, AI suggest mode).
```

### 5.4 Element renderer API

- `ElementKindHandler` (app, 03 §1.3) registry.
- Core scene (`wonky_slides_core/lib/src/scene/`):

```dart
sealed class SceneNode { String? get elementId; }
final class SGroup extends SceneNode { Matrix4 transform; double opacity; SClip? clip; List<SceneNode> children; }
final class SPath extends SceneNode { ScenePath path; SFill? fill; SStroke? stroke; SEffects? effects; }
final class SImage extends SceneNode { SlideImageRef image; Rect src; Rect dst; List<double>? colorMatrix; ScenePath? mask; }
final class SText extends SceneNode { TextLayoutResult layout; }        // positioned lines and runs
final class SChart extends SceneNode { ChartScene scene; }              // wonky_charts (08)
final class SCode extends SceneNode { CodeScene scene; }                // wonky_code (07)
final class SPrompt extends SceneNode { String text; Rect box; }        // editor only

abstract interface class TextLayoutEngine {
  TextLayoutResult layout(TextBody body, ResolvedTextStyles styles,
      {required double width, double scale = 1});
}
// Implementations: FlutterTextLayoutEngine (app, dart:ui Paragraph) and SlideTextLayout
// (core, pdf-package metrics; server/headless). Client PDF export passes the Flutter layout
// results to the PDF writer so client PDFs match the screen exactly (10).
```

### 5.5 Timeline API (owned by 06 §9)

`SlideTimelineCompiler.compile(SlideMotionInput) → SlideTimeline` (`initial`, `endOfStep`,
`frameAt`, `finalFrame`, `printFrame`), `TransitionCompiler` / `MagicMoveMatcher` →
`TransitionPlan`, `SlideFrame`/`ElementVisualState` consumed by `SlideStage`. M9 stub: every
slide compiles to zero steps; `printFrame` = edit frame.

### 5.6 Code and charts

- `CodeElementModel` (07): states, highlight steps, `CodeScene build(state, step, size)`, type-in
  plan from `wonky_core` diff (`SequenceDiff`).
- `ChartLinkService` (08): `link(spreadsheetItemUuid, chartObjectId) → snapshot`,
  `status(links) → {stale, sourceVersion}`, `update(elementId)`.

### 5.7 Server

```dart
abstract interface class DeckChangeLogConsumer {   // registered plugins: drive mirror, activity,
  String get id;                                   // orphaning, versions, agent cursors, headless cache
  Future<void> consume(Session session, UuidValue deckSpace, List<DeckChangeLogRow> rows);
}
abstract interface class HeadlessDeckProvider { Future<HeadlessDeck> open(UuidValue deckSpace); }
abstract interface class SlidesPdfRenderer {        // core; options per 10
  Stream<List<int>> render(DeckModel deck, SlidesPdfOptions options, FontProvider fonts, ImageProvider images);
}
```

---

## 6. Risks

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|-----------|--------|------------|-------|
| R1 | Extracting the shared sync kit destabilizes Sheets | Medium | High | Done in M8 (Drive 05 D-6) behind Sheets' full test + harness suites; pure moves, no behavior change | D-6 |
| R2 | One-replica-per-app downloads every space kind (02 §9.2) | Low (OS-8 in M8) | High | OS-8 space filter (Drive 05 D-4) before the first deck space; fallback: Slides active set limited to recently opened decks | D-4, SL-5 |
| R3 | Text LWW loses concurrent edits | Medium | Medium | Soft locks + live hints + overwritten-text review; recovery-offer metric; three-way merge ready as P2 (Q18) | SL-21, SL-39 |
| R4 | Editor overlay vs static text rendering mismatch (line breaks, auto-fit) | Medium | High | One `TextLayoutEngine` for static + overlay metrics; golden equality tests; spike SL-4 first | SL-4, SL-10, SL-13 |
| R5 | Screen vs server PDF layout differences (pdf metrics vs Flutter) | Medium | Medium | Client PDFs reuse Flutter layout results; server PDFs accept ≤ 1-line differences; tests flag diffs | SL-20 |
| R6 | Fonts: bundle size (display families) and PDF embedding | Medium | Medium | Deferred asset loading per family; subset in PDF; `wonky_fonts` assets cached by the browser across apps (same origin) | SL-6 |
| R7 | Lock-step synced schema releases span Sheets and Slides | Medium | Medium | Front-load S-1; batch S-2/S-3; recovery export | SL-2, SL-24, SL-37 |
| R8 | Motion performance on web (3D transitions, Magic Move of many text glyphs) | Medium | High | 06 budgets, prefetch plans, fallbacks under reduced motion, `flutter_scene` only where needed | SL-29 |
| R9 | Cross-deck paste of large groups (files, quota, offline) | Medium | Medium | Async re-homing queue, quota pre-check, placeholders while pending | SL-18 |
| R10 | Many parallel agents editing shared files; 16 GB laptop | Medium | Medium | Ownership table, registration indexes owned by SL-11, ≤ 5 agents, one web-build token (§2) | all |
| R11 | Laptop + projector without a second window is less convenient | High | Medium | Presenter view in this window + audience in a second browser or device via the session (one banner click); P1 same-browser fast path (SL-41); a presenting-only second window stays a possible later addition (10 §5.3) | SL-19, SL-41 |
| R12 | Linked chart data leakage/staleness | Low | Medium | Snapshot contains only resolved series; access-checked updates; stale badge; server auto-update only if needed (Q28) | SL-27, SL-32 |

---

## 7. Testing strategy

Follow suite [15](../15-writing-tests.md) (layout, naming, helpers, determinism, tags).

### 7.1 Unit (pure Dart)
`wonky_slides_core` ≥ 90 % line coverage on logic folders: ids, model ingestion, resolvers,
planner ops, inverter coupled columns, maintenance rules, copier/remapping, clipboard codec, text
schema, snapping, geometry, connectors, auto-fit, theme validation/resolution, layout remap,
size scaling, snapshot codec, diff, timeline (06), code diff/type-in (07), chart snapshot (08),
PDF structure (10).

### 7.2 Command tests
Every command: execute → undo → redo equality (model state + selection) headless on a
`MemoryDeckSession` via `CommandTestHarness` (`wonky_slides/test/harness/`), plus the
permission matrix per role (`forEachRole`).

### 7.3 Multi-client sync harness
As Sheets 13 §7.3: server (`serverpod_test` with the offline-sync engine) + N clients in isolates
with their own replicas, `DeckModel`s, writers and undo stacks.
- **Scripted**: every row of [09 §6.4](09-collaboration-history.md) and 06 §11 / 07 / 08
  concurrency tables.
- **Property**: random sequences (slide add/move/delete/duplicate, group create/move/ungroup/
  delete, element insert/move/resize/style/text/group/ungroup/delete, layout apply, theme apply,
  table axes/cells, builds, undo/redo) on 2–4 clients with random online/offline toggles.
  Invariants after full sync: replicas identical (canonical dump); 02 §10 invariants hold after
  maintenance; every slide reachable in the flattened order exactly once; no torn
  `groupId`/`sortKey` pairs; undo of client A never changes a column last written by B.
- Seeds recorded, failures shrink, nightly long runs.

### 7.4 Goldens
Built-in themes × layouts × appearances (thumbnail size), every shape geometry, text styles and
lists, tables, images (crop/mask/adjust), selection chrome and guides, navigator (groups
expanded/collapsed/skipped/colored, light/dark chrome), inspector sections, dialogs. CI Linux,
bundled fonts only.

### 7.5 Performance
Fixtures: 50, 200, 1,000-slide decks (40 elements/slide, images, tables). Metrics of 03 §18 and
06 §14; open from replica, cold sync, thumbnail generation, paste 50 slides across decks, PDF of
200 slides (web client, server). Nightly; > 10 % regression fails.

### 7.6 Integration (flutter_driver, via the serverpod MCP and the UI bridge)

| Journey | Steps |
|---------|-------|
| J-S1 | Create deck from template → edit title → add slides with layouts → group 3 slides (⌘G) → rename/color/collapse group → reorder by drag → present from start → presenter view with the audience in a second browser → exit |
| J-S2 | Insert image (upload), shape with text, connector between shapes, table; align/distribute; undo/redo everything |
| J-S3 | Two browsers (two users): soft lock + Edit anyway; group moved in one appears in the other; offline edit + reconnect |
| J-S4 | Copy a group from deck A, paste into deck B (keep source formatting); export PDF with notes pages |
| J-S5 | Builds by bullet + Magic Move between duplicated slides; preview; present through steps |
| J-S6 | Code block with 3 states, highlight steps, type-in while presenting |
| J-S7 | Insert linked chart from a spreadsheet; edit data in Sheets; *Update* in Slides; 3D camera build |
| J-S8 | Comment on an element with @mention; reply; resolve; deep link |
| J-S9 | Version history: view diff, restore, undo restore |
| J-S10 | MCP: create a deck headlessly, add slides/elements, export PDF; UI bridge: navigate and invoke commands |

### 7.7 PDF validation
Reference decks rendered to PDF (client and server); pages rasterized (pdfium/`pdftoppm` in CI) and
compared with the canvas goldens (tolerance); text extractable and in reading order; fonts
embedded; bookmarks = groups.

### 7.8 Security
Permission matrix for commands, endpoints and MCP tools per role; file re-homing checks
(`copyToItem` refuses files of items the caller can't read); image proxy SSRF matrix (suite 13);
linked-chart snapshots never leak spreadsheet data beyond the chart's resolved series; prompt
injection corpus for AI tools.

---

## 8. Decisions index (v2 review)

| # | Question | Where | Decision |
|---|----------|-------|----------|
| Q18 | Finer-grained concurrent text merging | 02 §4.5 | Soft lock + LWW in v1; three-way merge on receive as P2 |
| Q19 | Replica syncing every space kind | 02 §9.2 | Vendored OS-8 space filter per sync endpoint (M8, Drive 05 D-4) |
| Q20 | super_editor vs lighter rich-text editor | 03 §6.1 | super_editor overlay, confirmed by spike SL-4 |
| Q21 | Inspector docked vs side panel (Animate UI placement) | 04 §7.1 | Docked inspector hosting 06's Animate UI as a tab; `slides.panel.animate` is an alias |
| Q22 | Nested slide groups | 04 §5.12 | One level in v1; `parentId` reserved |
| Q23 | Shared package names | suite 01 §2.1 | `wonky_sync_kit` + `wonky_sync_kit_flutter`, `wonky_fonts`, `wonky_spellcheck` (+ glue in `wonky_app`) |
| Q24 | Print frame of animated slides | 06 §9.6 | Authored layout + completed content; *Show final animation state* option (P1) |
| Q25–Q26 | Write exports on TextMate; copy vs upstream split | 07 §2.2 | Switch in M10 (SL-35); copy the engine now (D-2) |
| Q27 | Number formats outside Sheets | 08 §2.5 | Extract `wonky_numfmt` (D-3) |
| Q28 | Linked chart auto-update | 08 §5.5 | Client-side in M10; server index in M11 only if needed |
| Q5/Q29/Q30 | Presenter view windows, desktop multi-window | 10 §5.2–§5.3 | Single window: presenter view here, audience on another device or browser; desktop multi-window deferred |

---

## 9. Definition of done (every work item)

- Code only in the owned folders; contracts unchanged or changed via an approved contract PR.
- Commands registered with stable ids (04 registry), args schema, titles, icons, shortcuts,
  menu/toolbar/context entries; execute/undo/redo tests; `ui.invoke_command` works.
- Synced writes name their columns (lint green); coupled columns written together; `DeckChangeLog`
  rows with correct `actorKind`, labels and summaries (deleted/revived lists).
- Web only: no desktop-specific code paths (suite 01 A13); no code opens a window or tab
  (suite 03 §1).
- Light and dark app chrome verified; slides render identically regardless of app theme; no
  overflow at 360 px for panels/dialogs.
- Keyboard operable; semantics labels; announcements where specified; reduced motion honored.
- Offline behavior as specified and covered by the harness when it touches synced data.
- MCP coverage where required (11), with integration tests.
- Unit, command, widget, golden and integration tests added; perf budgets measured where listed.
- Spec updated in the same change when behavior differs; `dart analyze` clean, `dart format`,
  dependency-rule check passes; `AGENTS.md` updated when apps/ports/driver entry points change
  (Slides: `wonky_slides/lib/driver.dart`, `flutter_apps` alias `slides`, web port 8104,
  release build `flutter build web --wasm --base-href /slides/ --output ../wonky_server/web/slides`).
