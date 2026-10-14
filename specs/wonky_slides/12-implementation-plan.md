# Slides 12 · Implementation Plan

This plan turns the Slides specs into milestones and **parallel workstreams** that engineers and
AI coding agents can build with minimal interference: folder ownership, contracts to stub first,
milestones **M9–M11** (decision D14), the dependency graph, the testing strategy, risks and the
definition of done. It follows the Sheets plan ([Sheets 13](../wonky_sheets/13-implementation-plan.md))
and reuses its infrastructure wherever possible.

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
| **M8** Drive + suite changes (prerequisite, suite/Drive specs) | Unified Drive with `presentation` kind and `registerPresentation`; app homes filtered per kind; settings split (`/settings`, `/settings/app`); Report a bug; 50 MB quota; **shared packages extracted** (shared sync kit §4.1–4.2, `wonky_charts`/`wonky_charts_flutter`, `wonky_code`, `wonky_fonts`, spell engine + emoji picker); `wonky_slides` app skeleton boots in the shell at `/slides/` (dev port 8104) with its home; `serverpod: flutter_apps: slides`; `flutter_build` builds `web/slides` | Sheets and Write green after the extractions (no behavior change); Slides home lists presentations; empty deck route renders "Coming soon" |
| **M9** Slides MVP | **Synced schema release S-1 with every Slides table** of 02 §3 + all synced additions from 03–11 known at M9 (front-loaded to avoid lock-step changes later, as Sheets did in M0); ids; `DeckModel`; planner + undo; sync (reserved spaces, `slidesSync`, change log consumer, OS-8 space filter or fallback); canvas, selection, transforms, smart guides, align/distribute; text (super_editor overlay), shapes, lines/connectors, images, tables, icons; element groups, lock/hide/z-order; format painter; clipboard (within/across decks, Write/Sheets/OS); find & replace; navigator with **slide groups** complete (D11); grid view; speaker notes; inspector (Format + Slide tabs); menus/toolbar/context menus; themes (10 built-ins), layouts (16), placeholders, Themes panel, page setup; presence roster + **soft locks** + text hints; **present** (full screen, keyboard, slide picker with groups, basic presenter view per 10's decision); **PDF export** (slides, notes pages, skipped in/out, group bookmarks); thumbnails; templates (5 of 10) | Journeys J-S1…J-S4 (§6.6) pass on web + macOS; command harness green; multi-client scenarios 09 §6.4 #1–17, 21–22, 26–29 pass; perf budgets of 03 §18; PDF of the reference decks validated (§6.7) |
| **M10** Motion & content | Builds, animation pane (Inspector › Animate), transitions incl. 3D, **Magic Move**, timeline model, reduced motion (06); code blocks, highlight steps, **type-in**, morph (07); **linked Sheets charts** with update/auto-update/unlink, native charts (P1), **3D charts** with animatable camera (08); PDF builds as pages; outline view; masters & layout editing + theme editor (05 §8); Layers panel; accessibility checker | Journeys J-S5…J-S7; timeline determinism tests (client ≡ server frames); 60 fps transitions on reference hardware; scenarios #18–20, 23–25 |
| **M11** Collaboration, MCP & AI | Live pointers, follow mode, follow presenter, transform hints (09 §1–2); comments on slides/elements; version history (snapshots, per-slide diff, restore, copies); overwritten-text review; activity; presenter remote & rehearse (10, P1 items); `slides.*` headless MCP tools + `ui.slides.*` (11); AI features (11); remaining P1 items (spelling, emoji, image adjustments, curved connectors) | Journeys J-S8…J-S10; all §6.4 scenarios; MCP integration suite; a11y checklist; no open P0/P1 bugs |

**Synced schema releases.** S-1 (M9) contains every table and column defined in 02 and the
additions listed in 02 §14 at that time. Additions discovered later are batched into S-2 (start
of M10) and S-3 (start of M11) at most; each release bumps `syncTablesHash` for **all** apps
(Sheets clients must update too, suite 01 §7), so releases are coordinated with Sheets.

---

## 2. Workstreams

| WS | Name | Milestone(s) | Depends on (contracts) | Owned folders |
|----|------|--------------|------------------------|---------------|
| WS-SL0 | Shared extractions (with the suite agent) | M8 | — | shared sync kit packages (§4.1–4.2), `packages/wonky_charts*`, `packages/wonky_code`, `packages/wonky_fonts`, spell/emoji moves; Sheets/Write call sites |
| WS-SL1 | Synced models, ids, lint | M9 (S-1) | SL0 | `packages/wonky_sync_models/lib/src/models/slides/**`, `…/ids/slides_ids.dart`, `wonky_slides/test/sync/columns_lint_test.dart` |
| WS-SL2 | Sync & spaces (client + server) | M9 | SL0, SL1 | `wonky_slides/lib/features/sync/**`, `wonky_server/lib/src/slides/{spaces,sync,changelog}/**` (consumer skeleton + plugin API), offline-sync patch OS-8 in `third_party/serverpod_offline_sync/**` |
| WS-SL3 | Core model, planner, undo, maintenance, copier, clipboard codec | M9 | SL1 | `wonky_slides_core/lib/src/{model,mutations,maintenance,copy,clipboard,ids}/**`, `wonky_slides/lib/features/model/**` |
| WS-SL4 | Scene, text layout, geometry, connectors, stage | M9 | SL3 | `wonky_slides_core/lib/src/{scene,layout,text,geometry,connectors}/**`, `wonky_slides/lib/features/stage/**` (shared with SL12) |
| WS-SL5 | Canvas, selection, transforms, snapping | M9 | SL3, SL4 | `wonky_slides/lib/features/{canvas,selection,snapping}/**` |
| WS-SL6 | Element kinds and text editing | M9 | SL4, SL5 | `wonky_slides/lib/features/{elements/**,text_editing,layers}/**` |
| WS-SL7 | Navigator, groups, grid view, notes, outline view | M9 (outline M10) | SL3, SL4 | `wonky_slides/lib/features/{navigator,groups,grid_view,notes,outline_view}/**` |
| WS-SL8 | Chrome: app config, menus, toolbar, inspector shell, dialogs, home, settings sections | M8–M11 | suite shell | `wonky_slides/lib/{main.dart,driver.dart,config/**,commands/commands.dart}`, `wonky_slides/lib/features/{editor_screen,menus,toolbar,inspector,dialogs,home}/**` |
| WS-SL9 | Themes, layouts, masters, fonts | M9 (editing M10) | SL3, SL4 | `wonky_slides_core/lib/src/theme/**`, `wonky_slides/lib/features/{themes,masters}/**` |
| WS-SL10 | Clipboard UI, cross-app paste, find & replace, spelling, accessibility | M9 (spelling/checker M10–M11) | SL3, SL6 | `wonky_slides/lib/features/{clipboard,find,spellcheck,accessibility}/**` |
| WS-SL11 | Present & PDF ([10](10-presenting-and-pdf.md)) | M9 basic, M10 builds, M11 remote/rehearse | SL4, SL12 (timeline) | `wonky_slides/lib/features/{present,print}/**`, `wonky_slides_core/lib/src/pdf/**`, server `slides/exports/**` |
| WS-SL12 | Motion ([06](06-animations-and-transitions.md)) | M10 (timeline skeleton M9) | SL4 | `wonky_slides_core/lib/src/motion/**`, `wonky_slides/lib/features/{motion,builds,transitions}/**` |
| WS-SL13 | Code blocks ([07](07-code-blocks.md)) | M10 | SL0 (`wonky_code`), SL6, SL12 | `wonky_slides_core/lib/src/code/**`, `wonky_slides/lib/features/elements/code/**` |
| WS-SL14 | Charts from Sheets ([08](08-charts-from-sheets.md)) | M10 | SL0 (`wonky_charts`), SL6, SL12 | `wonky_slides_core/lib/src/charts/**`, `wonky_slides/lib/features/elements/chart/**`, server `slides/charts/**` |
| WS-SL15 | Collaboration & history ([09](09-collaboration-history.md)) | M9 (soft locks, hints), M11 | SL2, SL3, SL5 | `wonky_slides/lib/features/{collab,comments,history}/**`, `wonky_slides_core/lib/src/{snapshot,diff}/**`, server `slides/versions/**` |
| WS-SL16 | MCP ([11](11-mcp-and-ai.md)) | M11 (headless skeleton M9 for tests) | SL3, SL4, SL11 | server `slides/{headless,mcp}/**`, `wonky_core/lib/mcp/slides_tools.dart`, `wonky_slides/lib/mcp/**` |
| WS-SL17 | AI ([11](11-mcp-and-ai.md)) | M11 | SL16 | server `platform/ai/prompts/slides_*.dart`, `slides/ai/**`, `wonky_slides/lib/features/{ai,assistant}/**` |
| WS-SL18 | Templates & built-in content | M9–M10 | SL9 | `wonky_server/lib/src/slides/templates/**` (template decks as JSON fixtures) |

Rules for parallel work (as Sheets 13 §2): a workstream edits only its owned folders; contract
changes go through a contract PR reviewed by affected owners; each workstream owns its
`commands/<area>_commands.dart`; SL8 owns the registration index, `MenuSpec`, toolbar spec and
panel registry (others submit one-line additions); synced-schema changes only in the S-n releases.

---

## 3. Workstream details (deliverables and acceptance)

### WS-SL0 · Shared extractions (M8)
- **Shared sync kit** (§4.1–4.2) extracted from `wonky_sheets_core/lib/src/mutations/row_change.dart`
  and `wonky_sheets/lib/features/sync/` — Sheets switched to it with no behavior change (its full
  test suite + sync harness green).
- **Space kinds** on the server: `SpaceReservation`/`SpaceSubscription` gain `kind`; Sheets'
  `spaces/` service generalized to `platform/spaces/`; OS-8 space filter patch (02 §9.2) or the
  documented fallback.
- `wonky_charts`/`wonky_charts_flutter`, `wonky_code`, `wonky_fonts`, spell engine and emoji
  picker moves (D7; 03 §20; 05 §3.1) with dependency rules updated in suite 01 §2.1 and
  `tool/check_dependencies.dart`.
- **Acceptance**: `dart run tool/check_dependencies.dart` passes with the new rules; Sheets
  (4,800+ core tests, app tests, server sync tests) and Write suites green.

### WS-SL1 · Synced models (M9)
- All `.spy.yaml` of 02 §3 + enums, `SlidesIds`, table codec registration in the shared kit;
  migrations via `create_migration` (server) and client migrations; columns lint test.
- **Acceptance**: generated code compiles; deterministic id tests; S-1 schema hash recorded.

### WS-SL2 · Sync & spaces (M9)
- `SlidesSyncController` (shared kit instance), replica `slides_<userId>.db` (desktop + web
  OPFS/IndexedDB), reserved-space pool, `slidesSync.sync` custom endpoint with `onMergeSuccess`,
  `SlidesEndpoint.{reserveSpaces, subscribe, ensureSubscribed, spaceStats, revertChange,
  reapplyChange}`, `drive.registerPresentation`, title mirroring, `DeckChangeLog` consumer
  skeleton with the `DeckChangeLogConsumer` plugin API (§4.7), recovery export (desktop: ZIP of
  `rows.json` per unsynced deck — no PPTX, by design), *Simulate offline* support.
- **Acceptance**: harness — create a deck offline → reconnect → collaborator sees it in Drive and
  opens it; membership mirrors roles; consumer exactly-once across restarts.

### WS-SL3 · Core (M9)
- Records, `DeckModel` with indexes, `SlideResolver`, `TextStyleResolver`,
  `SlidesMutationPlanner` with every op of 02 §12.1 (builds/code/chart ops as stubs filled by
  SL12–14), `UndoInverter` coupled-column groups, maintenance (02 §10), `DeckCopier`,
  `SlidesClipboardCodec`, text schema validator/normalizer, limits.
- **Acceptance**: execute → undo → redo equality for every op; seeded op-sequence property test
  (random ops on random decks, invariants of 02 §10 hold, undo of all returns to the start);
  incremental remote patch ≡ full reload.

### WS-SL4 · Scene and layout (M9)
- `SlideSceneBuilder`, `SceneNode` types, `TextLayoutEngine` with the Flutter implementation
  (app) and the core `SlideTextLayout` (pdf metrics, server), auto-fit, shape geometry library
  (03 §6.3), connector routing, `SlideStage` (shared with SL12: edit frame, thumbnails).
- **Acceptance**: goldens of every geometry and text style; editor-overlay vs static text line
  breaks equal; thumbnail ≤ 8 ms.

### WS-SL5 · Canvas (M9)
- 03 §2–5: zoom/fit/pan, selection model, marquee, handles, move/resize/rotate/nudge, smart guides
  and snapping (`SnapEngine` in core), align/distribute, rulers/guides (P1).
- **Acceptance**: 03 AC 1–3; perf budgets for drags.

### WS-SL6 · Element kinds (M9)
- Text editing overlay (super_editor + `SlidesDeltaMapper`), placeholders, shapes, lines and
  connectors, images (all insert paths, crop, mask, replace; adjustments P1), tables, icons
  (emoji P1), element groups, lock/hide, Layers panel (P1), format painter.
- **Spike first (week 1 of M9)**: super_editor overlay vs. lightweight editor (03 §6.1 open
  question) — measure enter-editing latency and line-break equality; decision record.
- **Acceptance**: 03 AC 4–7.

### WS-SL7 · Navigator & views (M9)
- 04 §5 complete (groups D11), grid view (§9), notes pane (§8); outline view (§10) in M10.
- **Acceptance**: 04 AC-3…AC-5, AC-8.

### WS-SL8 · Chrome (M8–M11)
- `SlidesAppConfig` (`WonkyAppConfig`: `app: slides`, `primaryKind: presentation`, routes,
  `editorRoutes` present/print, `createItem` offline via reserved spaces, settings sections,
  `mcpUiTools`), `driver.dart`, `MenuSpec` (04 §4), toolbar spec (04 §6), inspector shell with
  tabs and section registry (04 §7), dialogs (04 §13), home config + thumbnails (04 §15), status
  bar, keyboard scopes (03 §1.2), palette providers (Go to slide/group).
- **Acceptance**: 04 AC-1, AC-2, AC-6, AC-7, AC-9…AC-12.

### WS-SL9 · Themes (M9, editing M10)
- Theme schemas/validator/migrations/resolver, 10 built-in themes × 16 layouts as JSON, font
  registrations, Themes panel, apply/import/appearance, page setup scaling; master mode + theme
  editor in M10.
- **Acceptance**: 05 AC 1–8.

### WS-SL10 · Clipboard, find, spelling, a11y (M9–M11)
- 03 §12–14, §17: system clipboard integration (web Clipboard API, desktop `super_clipboard`),
  paste mappers (Write, Sheets, HTML, plain text, images), paste options chip, file re-homing via
  `FileEndpoint.copyToItem`; find & replace; spelling (P1); alt text, reading order, semantics,
  accessibility checker (P1).
- **Acceptance**: 03 AC 8–11.

### WS-SL11 · Present & PDF ([10](10-presenting-and-pdf.md))
- Per 10. M9: present mode without builds (transitions as cuts), slide picker with groups,
  presenter view per 10's resolution of the audience-window question, PDF (slides, notes pages,
  bookmarks). M10: builds/transitions while presenting, builds as PDF pages. M11: remote,
  rehearse.
- **Acceptance**: per 10.

### WS-SL12–SL14 · Motion, code, charts
- Per [06](06-animations-and-transitions.md) §18–19, [07](07-code-blocks.md),
  [08](08-charts-from-sheets.md). A timeline **skeleton** (`SlideTimeline` with only the edit
  frame and step 0) lands in M9 so presenting and PDF code paths exist from the start.

### WS-SL15 · Collaboration & history
- M9: presence roster, cursor JSON, soft locks (claims, race rule, popover, enforcement), text
  hints. M11: everything else of 09.
- **Acceptance**: 09 AC 1–6.

### WS-SL16–SL17 · MCP and AI
- Per [11](11-mcp-and-ai.md). A headless `HeadlessDeck` (core model + server writer) exists from
  M9 for server tests and templates.

### WS-SL18 · Templates
- 10 template decks (04 §15) built on the built-in themes, stored as JSON fixtures applied by
  `ServerSlidesWriter` into new spaces; screenshots for the gallery generated in CI.

---

## 4. Contracts to stub first

Stubbed with fakes at the start of M9 (shared kit in M8) so workstreams can start in parallel.
Names are binding unless changed via a contract PR.

### 4.1 Shared sync kit — pure Dart (extracted from Sheets)

```dart
/// packages/<shared sync kit>/lib/rows.dart (pure Dart; name decided by the suite agent,
/// proposal: `packages/wonky_sync_kit`)
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

### 4.2 Shared sync kit — client (Flutter; extracted from `wonky_sheets/lib/features/sync/`)

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

### 4.3 `DeckSession` (app, `features/model/deck_session.dart`)

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

### 4.4 Element renderer API

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

### 4.5 Timeline API (owned by 06 §9)

`SlideTimelineCompiler.compile(SlideMotionInput) → SlideTimeline` (`initial`, `endOfStep`,
`frameAt`, `finalFrame`, `printFrame`), `TransitionCompiler` / `MagicMoveMatcher` →
`TransitionPlan`, `SlideFrame`/`ElementVisualState` consumed by `SlideStage`. M9 stub: every
slide compiles to zero steps; `printFrame` = edit frame.

### 4.6 Code and charts

- `CodeElementModel` (07): states, highlight steps, `CodeScene build(state, step, size)`, type-in
  plan from `wonky_core` diff (`SequenceDiff`).
- `ChartLinkService` (08): `link(spreadsheetItemUuid, chartObjectId) → snapshot`,
  `status(links) → {stale, sourceVersion}`, `update(elementId)`.

### 4.7 Server

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

## 5. Dependency graph

```
                 ┌─────────┐
                 │ SL0 (M8)│ shared sync kit · charts · code · fonts · spell/emoji
                 └────┬────┘
          ┌───────────┼──────────────────────────┐
          ▼           ▼                          ▼
      ┌──────┐    ┌──────┐                   ┌──────┐
      │ SL1  │───►│ SL3  │ core model/planner │ SL8  │ chrome (needs suite shell)
      │models│    └──┬───┘                   └──────┘
      └──┬───┘       │
         ▼           ▼
      ┌──────┐    ┌──────┐
      │ SL2  │    │ SL4  │ scene · text layout · stage
      │ sync │    └┬──┬──┘
      └──┬───┘     │  └───────────────┬──────────────┐
         │         ▼                  ▼              ▼
         │      ┌──────┐          ┌──────┐       ┌──────┐
         │      │ SL5  │ canvas   │ SL7  │ nav   │ SL9  │ themes
         │      └──┬───┘          └──────┘       └──────┘
         │         ▼
         │      ┌──────┐   ┌──────┐
         │      │ SL6  │──►│ SL10 │ clipboard · find · a11y
         │      │kinds │   └──────┘
         │      └──┬───┘
         │         ├────────────┬─────────────┐
         │         ▼            ▼             ▼
         │      ┌──────┐    ┌──────┐      ┌──────┐
         │      │ SL12 │───►│ SL13 │      │ SL14 │ charts
         │      │motion│    │ code │      └──────┘
         │      └──┬───┘    └──────┘
         │         ▼
         │      ┌──────┐
         │      │ SL11 │ present · PDF
         │      └──────┘
         ▼
      ┌──────┐   ┌──────┐   ┌──────┐
      │ SL15 │   │ SL16 │──►│ SL17 │
      │collab│   │ MCP  │   │  AI  │
      └──────┘   └──────┘   └──────┘
```

Critical path to M9: SL0 (sync kit) → SL1 → SL3 → SL4 → SL5 → SL6, with SL2, SL7, SL8, SL9 in
parallel once SL3/SL4 contracts exist.

---

## 6. Testing strategy

Follow suite [15](../15-writing-tests.md) (layout, naming, helpers, determinism, tags).

### 6.1 Unit (pure Dart)
`wonky_slides_core` ≥ 90 % line coverage on logic folders: ids, model ingestion, resolvers,
planner ops, inverter coupled columns, maintenance rules, copier/remapping, clipboard codec, text
schema, snapping, geometry, connectors, auto-fit, theme validation/resolution, layout remap,
size scaling, snapshot codec, diff, timeline (06), code diff/type-in (07), chart snapshot (08),
PDF structure (10).

### 6.2 Command tests
Every command: execute → undo → redo equality (model state + selection) headless on a
`MemoryDeckSession` via `CommandTestHarness` (`wonky_slides/test/harness/`), plus the
permission matrix per role (`forEachRole`).

### 6.3 Multi-client sync harness
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

### 6.4 Goldens
Built-in themes × layouts × appearances (thumbnail size), every shape geometry, text styles and
lists, tables, images (crop/mask/adjust), selection chrome and guides, navigator (groups
expanded/collapsed/skipped/colored, light/dark chrome), inspector sections, dialogs. CI Linux,
bundled fonts only.

### 6.5 Performance
Fixtures: 50, 200, 1,000-slide decks (40 elements/slide, images, tables). Metrics of 03 §18 and
06 §14; open from replica, cold sync, thumbnail generation, paste 50 slides across decks, PDF of
200 slides (client desktop/web, server). Nightly; > 10 % regression fails.

### 6.6 Integration (flutter_driver, via the serverpod MCP and the UI bridge)

| Journey | Steps |
|---------|-------|
| J-S1 | Create deck from template → edit title → add slides with layouts → group 3 slides (⌘G) → rename/color/collapse group → reorder by drag → present from start → exit |
| J-S2 | Insert image (upload), shape with text, connector between shapes, table; align/distribute; undo/redo everything |
| J-S3 | Two windows: soft lock + Edit anyway; group moved in one window appears in the other; offline edit + reconnect |
| J-S4 | Copy a group from deck A, paste into deck B (keep source formatting); export PDF with notes pages |
| J-S5 | Builds by bullet + Magic Move between duplicated slides; preview; present through steps |
| J-S6 | Code block with 3 states, highlight steps, type-in while presenting |
| J-S7 | Insert linked chart from a spreadsheet; edit data in Sheets; *Update* in Slides; 3D camera build |
| J-S8 | Comment on an element with @mention; reply; resolve; deep link |
| J-S9 | Version history: view diff, restore, undo restore |
| J-S10 | MCP: create a deck headlessly, add slides/elements, export PDF; UI bridge: navigate and invoke commands |

### 6.7 PDF validation
Reference decks rendered to PDF (client and server); pages rasterized (pdfium/`pdftoppm` in CI) and
compared with the canvas goldens (tolerance); text extractable and in reading order; fonts
embedded; bookmarks = groups.

### 6.8 Security
Permission matrix for commands, endpoints and MCP tools per role; file re-homing checks
(`copyToItem` refuses files of items the caller can't read); image proxy SSRF matrix (suite 13);
linked-chart snapshots never leak spreadsheet data beyond the chart's resolved series; prompt
injection corpus for AI tools.

---

## 7. Risks

| # | Risk | Likelihood | Impact | Mitigation | Owner |
|---|------|-----------|--------|------------|-------|
| R1 | Extracting the shared sync kit destabilizes Sheets | Medium | High | Extraction in M8 behind Sheets' full test + harness suites; no behavior changes; feature flags not needed (pure moves) | SL0 |
| R2 | One-replica-per-app downloads every space kind (02 §9.2) | High | High | OS-8 space filter patch; fallback limits Slides active set; measure | SL2 |
| R3 | Text LWW loses concurrent edits | Medium | Medium | Soft locks + live hints + overwritten-text review; metric of recovery offers; option D (three-way merge) ready as P2 | SL15 |
| R4 | Editor overlay vs static text rendering mismatch (line breaks, auto-fit) | Medium | High | One `TextLayoutEngine` for static + overlay metrics; golden equality tests; spike in week 1 | SL4/SL6 |
| R5 | Screen vs server PDF layout differences (pdf metrics vs Flutter) | Medium | Medium | Client PDFs reuse Flutter layout results; server PDFs accept ≤ 1-line differences; tests flag diffs | SL11 |
| R6 | Fonts: bundle size (display families) and PDF embedding | Medium | Medium | Deferred asset loading per family; subset in PDF; `wonky_fonts` shared assets cached by the browser across apps (same origin) | SL9 |
| R7 | Lock-step synced schema releases now span Sheets and Slides | Medium | Medium | Front-load S-1; batch S-2/S-3; recovery export | SL1 |
| R8 | Motion performance on web (3D transitions, Magic Move of many text glyphs) | Medium | High | 06 budgets, prefetch plans, fallbacks under reduced motion, `flutter_scene` only where needed | SL12 |
| R9 | Cross-deck paste of large groups (files, quota, offline) | Medium | Medium | Async re-homing queue, quota pre-check, placeholders while pending | SL10 |
| R10 | Many parallel agents editing shared files | Medium | Medium | Ownership table, registration indexes owned by SL8, CI dependency checks | all |
| R11 | Presenter view needs a second window (single-window rule) | High | Medium | Open question resolved in 10; fallback "presenter + remote device" works within the rule | SL11 |
| R12 | Linked chart data leakage/staleness | Low | Medium | Snapshot contains only resolved series; access-checked updates; stale badge | SL14 |

---

## 8. Open questions index (for review)

| # | Question | Where | Recommendation |
|---|----------|-------|----------------|
| OQ-1 | Finer-grained concurrent text merging | 02 §4.5 | Soft lock + LWW in v1; three-way merge on receive as P2 |
| OQ-2 | Replica syncing every space kind | 02 §9.2 | Vendored OS-8 space filter per sync endpoint |
| OQ-3 | super_editor vs lighter rich-text editor | 03 §6.1 | super_editor overlay, decided by the week-1 spike |
| OQ-4 | Inspector docked vs side panel (Animate UI placement) | 04 §7.1 | Docked inspector hosting 06's Animate UI as a tab; `slides.panel.animate` is an alias |
| OQ-5 | Nested slide groups | 04 §5.12 | One level in v1; `parentId` reserved |
| OQ-6 | Shared package names/locations (sync kit, fonts, spell engine) | §4.1, 05 §3.1, 03 §20 | `wonky_sync_kit` (pure) + Flutter client part, `wonky_fonts`, spell engine in a shared package — suite agent decides |
| OQ-7 | Print frame of animated slides | 06 §9.6 | Authored layout + completed content; *Show final state* option |
| OQ-8 | Presenter view window | 10 (D12) | Decided in 10 |

---

## 9. Definition of done (every work item)

- Code only in the owned folders; contracts unchanged or changed via an approved contract PR.
- Commands registered with stable ids (04 registry), args schema, titles, icons, shortcuts,
  menu/toolbar/context entries; execute/undo/redo tests; `ui.invoke_command` works.
- Synced writes name their columns (lint green); coupled columns written together; `DeckChangeLog`
  rows with correct `actorKind`, labels and summaries (deleted/revived lists).
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
