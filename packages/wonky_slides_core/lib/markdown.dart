/// Markdown for Wonky Slides (specs/wonky_slides/11 §3.2–§3.3): text bodies
/// as Markdown (`SlidesMarkdownCodec`, the MCP `TextInput`) and the deck
/// outline (`DeckOutlineCodec`: `slides.add_slides_from_markdown`, the
/// `wonky://deck/<uuid>` resource, `drive.export` `md`).
///
/// Pure Dart (client, server, MCP, AI).
library;

export 'src/markdown/deck_outline_codec.dart';
export 'src/markdown/slides_markdown_codec.dart';
