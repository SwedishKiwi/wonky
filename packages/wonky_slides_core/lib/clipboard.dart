/// The Slides clipboard (03 §12): the `application/x-wonky-slides` payload
/// codec (copy, sanitize, plain text/Markdown, file re-homing) and the
/// mappers of foreign content (plain text, Write rich text, grids/TSV,
/// Sheets objects, images) to `PasteElements` payloads.
library;

export 'src/clipboard/slides_clipboard_codec.dart';
export 'src/clipboard/slides_paste_mappers.dart';
