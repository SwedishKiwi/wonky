/// The in-memory deck model of Wonky Slides (specs/wonky_slides/02 §11):
/// typed records per synced table, `DeckModel` (single ingestion path
/// `applyChanges`, parent indexes, flattened slide order), the read
/// interface `DeckReader`, change events/batches, the derived indexes
/// (`DeckIndexes`: `SlideOrder`, `ElementTree`, `ThemeIndex`,
/// `PlaceholderIndex`, `TableIndex`), the resolvers (`SlideResolver` →
/// `ResolvedSlide`/`ResolvedElement`, `TextStyleResolver`), frame geometry
/// and the Slides text schema (`SlidesText`).
///
/// Pure Dart (client, server, MCP).
library;

export 'src/model/api/deck_model.dart';
export 'src/model/api/deck_reader.dart';
export 'src/model/api/events.dart';
export 'src/model/api/kinds.dart';
export 'src/model/api/records.dart';
export 'src/model/api/resolved.dart';
export 'src/model/geometry/frame_math.dart';
export 'src/model/index/deck_indexes.dart';
export 'src/model/index/element_tree.dart';
export 'src/model/index/placeholder_index.dart';
export 'src/model/index/slide_order.dart';
export 'src/model/index/table_index.dart';
export 'src/model/index/theme_index.dart';
export 'src/model/resolve/slide_resolver.dart';
export 'src/model/resolve/text_style_resolver.dart';
export 'src/model/text/slides_text.dart';
