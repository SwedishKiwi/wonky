# Wonky Slides — Specifications

Collaborative, offline-first presentation app (the best of Keynote, PowerPoint, Google Slides,
Pitch, Figma Slides and reveal.js) on Serverpod's offline-first sync (`serverpod_offline_sync`,
one deck = one space, like Wonky Sheets), with slide groups, themes/masters/layouts, cinematic
builds and Magic Move, code blocks with type-in, linked (and 3D) charts from Wonky Sheets,
presenting and PDF export. Read the [suite specs](../README.md) first — especially
[12 · Offline & sync](../12-offline-and-sync.md) — and [Sheets 02](../wonky_sheets/02-data-model.md),
whose sync design Slides mirrors.

## Reading order

1. [01 · Overview](01-overview.md) — scope, features and priorities, non-goals, concurrency
   semantics, packages.
2. [02 · Data model](02-data-model.md) — **authoritative** storage model.
3. [04 · Screens, menus & toolbar](04-screens-menus-toolbar.md) — layout, slide navigator and
   groups, canonical command ids.
4. [03 · Editor canvas & objects](03-editor-canvas-and-objects.md) — then the feature spec you
   build (05–11).
5. [12 · Implementation plan](12-implementation-plan.md) — workstreams, contracts, milestones.

## File map

| # | Spec | Summary |
|---|------|---------|
| 01 | [Overview](01-overview.md) | Vision, personas, features by area (P0/P1/P2), non-goals (no PPTX/Keynote, no video), limits, user-facing concurrency, roles, packages, glossary |
| 02 | [Data model](02-data-model.md) | **Canonical** synced schema: `Deck`, themes/masters/layouts, `Slide`, `SlideGroup`, `SlideElement` (+ per-kind JSON), tables, `SlideBuild`, `CodeState`, `ChartLink`, `DeckChangeLog`; ids, ordering, rich text + soft lock, in-memory model, planner, writer, `slides.rows` undo, invariants, limits |
| 03 | [Editor canvas & objects](03-editor-canvas-and-objects.md) | Canvas, selection, transforms, smart guides, every element kind, groups, lock/z-order, format painter, keyboard, clipboard (decks, Write, Sheets, OS), find/replace, spelling, accessibility, performance |
| 04 | [Screens, menus & toolbar](04-screens-menus-toolbar.md) | Screens, editor layout, **slide navigator & slide groups**, inspector, notes, grid/outline views, complete menubar (**canonical menu command registry**), toolbar, context menus, panels, dialogs, status bar, home |
| 05 | [Themes, layouts & masters](05-themes-layouts-masters.md) | Theme JSON, light/dark appearance, fonts, 16 layouts, placeholders, 10 built-in themes, master editing, apply/import themes, slide sizes |
| 06 | [Animations & transitions](06-animations-and-transitions.md) | Builds, effect catalog, triggers, animation pane, transitions, Magic Move, timeline model, reduced motion |
| 07 | [Code blocks](07-code-blocks.md) | Code elements, highlighting, line-highlight steps, code states, type-in and morph |
| 08 | [Charts from Sheets](08-charts-from-sheets.md) | Linked Sheets charts, update detection, deck styling, 3D charts and camera, native charts |
| 09 | [Collaboration & history](09-collaboration-history.md) | Presence, soft locks, hints, follow mode, comments, version history, activity, offline conflict scenarios |
| 10 | [Presenting & PDF](10-presenting-and-pdf.md) | Present mode, presenter view, remote, rehearse, PDF/PNG export, print |
| 11 | [MCP & AI](11-mcp-and-ai.md) | Headless `slides.*` tools, `ui.slides.*` bridge, AI features |
| 12 | [Implementation plan](12-implementation-plan.md) | Milestones M9–M11, workstreams WS-SL0…SL18, contracts, dependency graph, testing, risks, open questions index |

Authority order when specs disagree: suite specs → 02 (data model) → 04 (command ids) → feature
specs. Fix the disagreement in the same change that finds it.
