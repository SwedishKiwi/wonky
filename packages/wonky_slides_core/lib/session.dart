/// The deck session write path of Wonky Slides (specs/wonky_slides/12 §5.3,
/// 02 §12): the `DeckWritePath` mixin shared by the app's `DeckSession`
/// implementations and server sessions, the pure-Dart `MemoryDeck`, and
/// the `slides.rows` undo domain (`SlidesRowsUndoEntry`,
/// `SlidesRowsUndoHandler`).
///
/// Pure Dart.
library;

export 'src/session/deck_write_path.dart';
export 'src/session/memory_deck.dart';
export 'src/session/slides_undo.dart';
