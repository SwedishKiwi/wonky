/// The synced schema of Wonky Slides (Slides 02 §3, release S-1): table and
/// column names, the table set of the shared sync kit and the undo table
/// hooks (coupled columns, P4). The generated models and the deterministic
/// ids (`SlidesIds`) are in `wonky_sync_models`.
library;

export 'src/schema/slides_schema.dart';
export 'src/schema/slides_table_set.dart';
export 'src/schema/slides_undo_hooks.dart';
