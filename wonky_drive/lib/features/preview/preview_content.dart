import 'dart:convert';
import 'dart:typed_data';

import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart';

/// The viewer a file is shown with (Drive 02 §6).
enum PreviewViewer {
  /// JPEG, PNG, GIF, WebP, BMP (§6.2).
  image,

  /// Text and code in `CodeView` (§6.4); also HTML, SVG and XML as source.
  text,

  /// CSV/TSV with the *Table* / *Text* toggle (§6.4, P1).
  csv,

  /// Icon, metadata and *Download* (§6.7); also PDFs (no PDF previews in
  /// v2, §6.3).
  unsupported,
}

/// Limits of the preview (Drive 02 §6, suite 11 §2).
abstract final class PreviewLimits {
  /// Originals above this use the server preview image (§6.1, §6.2).
  static const imageOriginalBytes = 4 * 1024 * 1024;

  /// Images above this many pixels are never decoded on the client.
  static const imageMaxPixels = 50 * 1000 * 1000;

  /// Text shown in the text viewer (§6.4).
  static const textBytes = 1024 * 1024;

  /// Rows of the CSV table (§6.4).
  static const csvRows = 1000;

  /// Largest file a preview downloads (the upload limit, suite 13 §6).
  static const maxBytes = 50 * 1024 * 1024;

  /// The in-memory byte cache for prev/next browsing (§6.1).
  static const cacheBytes = 100 * 1024 * 1024;
}

/// Viewer, language and *Open with* target of a file item.
class PreviewType {
  const PreviewType._({
    required this.viewer,
    required this.mimeType,
    required this.category,
    required this.extension,
    this.language,
    this.convertTarget,
  });

  /// Decides how [item] is previewed. Active content (HTML, SVG, XML,
  /// scripts) is never rendered: it is shown as source text or not at all
  /// (Drive 02 §5); the effective (sniffed) MIME type decides, the name only
  /// picks the highlighting language.
  factory PreviewType.of(DriveItemView item) {
    final mime = FileTypes.essence(item.mimeType ?? FileTypes.octetStream);
    final ext = FileTypes.extensionOf(item.name);
    final category =
        item.fileCategory ??
        FileCategory.values.byName(
          FileTypes.categoryOf(mime, fileName: item.name).name,
        );
    final isText = FileTypes.isTextMimeType(mime);
    final PreviewViewer viewer;
    if (FileTypes.isActive(mime)) {
      viewer = isText ? PreviewViewer.text : PreviewViewer.unsupported;
    } else if (_csvMimeTypes.contains(mime) ||
        (isText && (ext == 'csv' || ext == 'tsv'))) {
      viewer = PreviewViewer.csv;
    } else if (category == FileCategory.image) {
      viewer = FileTypes.isRenderableImage(mime)
          ? PreviewViewer.image
          : PreviewViewer.unsupported;
    } else if (category == FileCategory.text && isText) {
      viewer = PreviewViewer.text;
    } else {
      viewer = PreviewViewer.unsupported;
    }
    final convert = FileTypes.convertTargetOf(item.name);
    final convertible =
        convert != null &&
        (isText ||
            category == FileCategory.document ||
            category == FileCategory.spreadsheet);
    return PreviewType._(
      viewer: viewer,
      mimeType: mime,
      category: category,
      extension: ext,
      language: viewer == PreviewViewer.text
          ? FileTypes.languageOf(item.name) ?? _languageByMime[mime]
          : null,
      convertTarget: convertible ? convert : null,
    );
  }

  final PreviewViewer viewer;
  final String mimeType;
  final FileCategory category;

  /// Lower-case extension ('' when none).
  final String extension;

  /// Highlighting language (shared ids), null = plain text.
  final String? language;

  /// The app *Open with* offers (Drive 02 §7.1), null when not convertible.
  final ConvertTarget? convertTarget;

  /// Whether the viewer needs the file's bytes.
  bool get needsBytes => viewer != PreviewViewer.unsupported;

  static const _csvMimeTypes = {'text/csv', 'text/tab-separated-values'};

  static const _languageByMime = {
    'text/html': 'html',
    'application/xhtml+xml': 'html',
    'application/json': 'json',
    'text/javascript': 'javascript',
    'application/javascript': 'javascript',
    'text/css': 'css',
    'text/markdown': 'markdown',
    'application/yaml': 'yaml',
    'application/x-yaml': 'yaml',
    'application/sql': 'sql',
  };
}

/// Decoded text of a text file (Drive 02 §6.4).
class TextPreview {
  const TextPreview({
    required this.text,
    required this.truncated,
    required this.latin1,
    required this.lineCount,
  });

  final String text;

  /// Only the first [PreviewLimits.textBytes] are shown.
  final bool truncated;

  /// Not UTF-8/UTF-16: decoded as Latin-1 ("Shown as Latin-1").
  final bool latin1;

  /// Lines of [text].
  final int lineCount;

  /// Decodes [bytes]: UTF-16 with a BOM, else UTF-8 (a BOM is dropped),
  /// else Latin-1. Returns null for binary data (NUL bytes or more than 1 %
  /// control characters outside UTF-16), which the viewer shows as an error
  /// state instead of garbage.
  static TextPreview? decode(Uint8List bytes, {int? limit}) {
    final max = limit ?? PreviewLimits.textBytes;
    final truncated = bytes.length > max;
    var data = truncated ? Uint8List.sublistView(bytes, 0, max) : bytes;
    String text;
    var latin1 = false;
    if (data.length >= 2 &&
        ((data[0] == 0xff && data[1] == 0xfe) ||
            (data[0] == 0xfe && data[1] == 0xff))) {
      text = _utf16(data, littleEndian: data[0] == 0xff);
    } else {
      if (_looksBinary(data)) return null;
      if (data.length >= 3 &&
          data[0] == 0xef &&
          data[1] == 0xbb &&
          data[2] == 0xbf) {
        data = Uint8List.sublistView(data, 3);
      }
      try {
        text = utf8.decode(data);
      } on FormatException {
        // A cut in the middle of a multi-byte character is still UTF-8.
        final cut = truncated ? _trimPartialUtf8(data) : null;
        if (cut != null) {
          try {
            text = utf8.decode(cut);
          } on FormatException {
            text = latin1Codec.decode(data);
            latin1 = true;
          }
        } else {
          text = latin1Codec.decode(data);
          latin1 = true;
        }
      }
    }
    return TextPreview(
      text: text,
      truncated: truncated,
      latin1: latin1,
      lineCount: _lines(text),
    );
  }

  static const latin1Codec = Latin1Codec();

  static String _utf16(Uint8List data, {required bool littleEndian}) {
    final units = <int>[];
    for (var i = 2; i + 1 < data.length; i += 2) {
      units.add(
        littleEndian
            ? data[i] | (data[i + 1] << 8)
            : (data[i] << 8) | data[i + 1],
      );
    }
    return String.fromCharCodes(units);
  }

  /// NUL bytes, or more than 1 % control bytes (other than tab, CR, LF,
  /// FF, ESC) in the first 64 KB (Drive 02 §5 step 2).
  static bool _looksBinary(Uint8List data) {
    final n = data.length < 65536 ? data.length : 65536;
    var control = 0;
    for (var i = 0; i < n; i++) {
      final b = data[i];
      if (b == 0) return true;
      if (b < 0x20 && b != 9 && b != 10 && b != 13 && b != 12 && b != 27) {
        control++;
      }
    }
    return n > 0 && control * 100 > n;
  }

  /// [data] without an incomplete UTF-8 sequence at its end, or null when
  /// the end is not a cut sequence.
  static Uint8List? _trimPartialUtf8(Uint8List data) {
    for (var back = 1; back <= 3 && back <= data.length; back++) {
      final b = data[data.length - back];
      if (b & 0xc0 == 0x80) continue; // continuation byte
      if (b & 0xc0 == 0xc0) {
        return Uint8List.sublistView(data, 0, data.length - back);
      }
      return null;
    }
    return null;
  }

  static int _lines(String text) {
    if (text.isEmpty) return 0;
    var n = 1;
    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c == 0x0a) {
        n++;
      } else if (c == 0x0d &&
          (i + 1 >= text.length || text.codeUnitAt(i + 1) != 0x0a)) {
        n++;
      }
    }
    if (text.endsWith('\n') || text.endsWith('\r')) n--;
    return n;
  }
}
