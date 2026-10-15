/// Version history of decks (Slides 09 §4): the snapshot codec
/// (`SlidesSnapshotCodec`, gzip NDJSON shared by server and client), the
/// version change index (`SlidesVersionChanges`, author attribution), the
/// deck diff (`DeckDiff`: slides, elements, groups, theme), the inline
/// text diff (`TextDiff`) and the row changes of a restore
/// (`SlidesRestoreChanges`).
library;

export 'src/diff/deck_diff.dart';
export 'src/diff/restore_changes.dart';
export 'src/diff/text_diff.dart';
export 'src/snapshot/slides_snapshot.dart';
export 'src/snapshot/version_changes.dart';
