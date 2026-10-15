# wonky_slides_core

Pure-Dart core of Wonky Slides (no Flutter; `specs/01-architecture.md` §2.1). Runs in the app,
on the server and in MCP tools.

| Library | Content | Spec |
|---------|---------|------|
| `package:wonky_slides_core/themes.dart` | Theme JSON model and codecs (`DeckThemeData`), validator, migrations, JSON schemas, `DeckThemeResolver` / `ResolvedTheme`, contrast checks, bundled font resolution, slide sizes and scaling, the 16 built-in layouts, placeholder inheritance, layout remapping, the 10 built-in themes (`BuiltInThemes`) | `specs/wonky_slides/05-themes-layouts-masters.md` |
| `package:wonky_slides_core/schema.dart` | Table/column names (`SlidesTables`, `…Cols`), `SlidesTableSet`, undo table hooks (`SlidesUndoHooks`) | `specs/wonky_slides/02-data-model.md` §3, §12.2 |
| `package:wonky_slides_core/model.dart` | Records per table (`DeckRec`, `SlideRec`, `SlideElementRec`, …), `DeckReader`, `DeckModel` (`applyChanges`, parent indexes, flattened slide order), change events/batches; derived indexes `DeckIndexes` (`model.indexes`: `SlideOrder`, `ElementTree`, `ThemeIndex`, `PlaceholderIndex`, `TableIndex`, builds by element, per-slide revisions); `SlideResolver` → `ResolvedSlide` / `ResolvedElement`, `TextStyleResolver`; frame geometry (`ElementFrame`, `GroupSpace`); the Slides text schema (`SlidesText`) | 02 §4, §11, 12 §5.3 |
| `package:wonky_slides_core/ops.dart` | The sealed `SlidesOperation` family, `Patch<T>`, `SlidesPlanContext`, `SlidesLimits`, `PlanException`, `SlidesChangeSummary` / `SlidesPlan`, the `SlidesMutationPlanner` interface | 02 §12–§13 |
| `package:wonky_slides_core/planner.dart` | `SlidesPlanner` (every operation of 02 §12.1 + `CreateDeck`), `PlanBuilder` (one coalesced change per row, coupled columns), `OrderKeys`, `ThemeCopy` (deterministic theme copies) | 02 §10–§13, 05 §5.4, §7, §9 |
| `package:wonky_slides_core/maintenance.dart` | `DeckMaintenance` (`detect` the violations of 02 §10, `repairOp` → deterministic `RepairDeck`) | 02 §10 |
| `package:wonky_slides_core/session.dart` | `DeckWritePath` (execute/apply/persist write path of every session), `MemoryDeck`, the `slides.rows` undo entry and handler | 12 §5.3 |
| `package:wonky_slides_core/scene.dart` | Scene nodes (`GroupNode`, `PathNode`, `ImageNode`, `TextNode`, `ChartNode`, `CodeNode`, `PromptNode`), `SlideScene`, `SceneContext`, the `TextLayoutEngine` contract, `CodeScene` | 03 §1, 12 §5.4 |
| `package:wonky_slides_core/motion.dart` | Timeline API (M9 stub: zero steps, edit frame) | 06 §9, 12 §5.5 |
| `package:wonky_slides_core/interfaces.dart` | `SlideImageResolver`, `SlidesPdfRenderer` + options/resources/result, server contracts (`DeckChangeLogConsumer<C>`, `HeadlessDeck`, `HeadlessDeckProvider<C>`) | 10 §11, 12 §5.7 |
| `package:wonky_slides_core/testing.dart` | Tests only: `DeckBuilder`, `themePackageRows`, `FakeSlidesPlanner` (session contract tests), `LwwSyncRelay` | 12 §7 |

Other areas (copier, clipboard codec, scene builder, PDF, …) are added by later work packages of
`specs/wonky_slides/12-implementation-plan.md`; `lib/wonky_slides_core.dart` re-exports the
area barrels.

Tests: `dart test` in this folder.
