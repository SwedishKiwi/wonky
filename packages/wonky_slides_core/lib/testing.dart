/// Test support of Wonky Slides (specs/15-writing-tests.md, Slides 12 §7):
/// deck fixtures (`DeckBuilder`, `themePackageRows`), a small
/// `FakeSlidesPlanner` for contract tests of sessions (the production
/// planner is `SlidesPlanner`, `package:wonky_slides_core/planner.dart`), and
/// an in-memory multi-client relay (`LwwSyncRelay`).
///
/// For tests only; never import from production code.
library;

export 'src/planner/theme_copy.dart'
    show SlidesRow, ThemeCopyIds, elementDefaults;
export 'src/testing/deck_builder.dart';
export 'src/testing/fake_planner.dart';
export 'src/testing/sync_relay.dart';
