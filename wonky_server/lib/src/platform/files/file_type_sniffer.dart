import 'dart:convert';
import 'dart:typed_data';

import 'package:mime/mime.dart' as mime;
import 'package:wonky_core/files.dart';

/// The result of [FileTypeSniffer.sniff].
class SniffResult {
  const SniffResult(this.mimeType, {this.encoding});

  /// The effective MIME type (essence, lower case).
  final String mimeType;

  /// Text only: `utf-8`, `utf-16le`, `utf-16be` or `latin1` (bytes that
  /// are not UTF-8 but look like text, shown as Latin-1, Drive 02 §6.4).
  final String? encoding;

  bool get isText => encoding != null;

  /// The category with the extension of [fileName] as tie-breaker
  /// (Drive 02 §1.2).
  FileTypeCategory categoryFor(String fileName) =>
      FileTypes.categoryOf(mimeType, fileName: fileName);

  @override
  String toString() => 'SniffResult($mimeType, $encoding)';
}

/// Server-side type detection of uploaded bytes (Drive 02 §5, suite 13 §6).
///
/// 1. **Binary signatures** (our own table, then the `mime` package's magic
///    numbers) — ZIP containers are refined to DOCX/XLSX/PPTX (part names),
///    ODF (`mimetype` entry), EPUB, JAR and iWork.
/// 2. **Text check** — no NUL bytes; valid UTF-8 (or UTF-16 with BOM), or
///    Latin-1 with few control characters. The text type comes from the
///    content for active markup (HTML, SVG, XML: never trusted from the
///    name) and otherwise from the extension (`text/markdown`, `text/csv`,
///    source code …), else `text/plain`.
/// 3. Otherwise `application/octet-stream`.
///
/// The declared type and the extension never override a binary signature;
/// the extension only names the text type and the member of a container
/// family (OLE2 `doc`/`xls`/`ppt`, iWork).
abstract final class FileTypeSniffer {
  /// Bytes read from the start of the object (Drive 02 §5).
  static const sampleSize = 4096;

  /// Bytes from the end of the object searched for a ZIP central directory.
  static const tailSize = 64 * 1024;

  static const _docx =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  static const _xlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const _pptx =
      'application/vnd.openxmlformats-officedocument.presentationml.presentation';

  /// Sniffs [bytes] (the whole object or at least its first [sampleSize]
  /// bytes; [tail] = the last [tailSize] bytes when [bytes] is only the
  /// head of a larger object).
  static SniffResult sniff(
    Uint8List bytes, {
    String fileName = '',
    Uint8List? tail,
  }) {
    final head = bytes.length > sampleSize
        ? Uint8List.sublistView(bytes, 0, sampleSize)
        : bytes;
    final ext = FileTypes.extensionOf(fileName);
    // A UTF-16 byte order mark looks like an MPEG frame sync: text first.
    if (_at(head, 0, [0xFF, 0xFE]) || _at(head, 0, [0xFE, 0xFF])) {
      final utf16 = _text(head, ext, complete: bytes.length <= sampleSize);
      if (utf16 != null) return utf16;
    }
    final binary = _signature(head, ext, bytes, tail);
    if (binary != null) return SniffResult(binary);
    final text = _text(head, ext, complete: bytes.length <= sampleSize);
    if (text != null) return text;
    return const SniffResult(FileTypes.octetStream);
  }

  // ------------------------------------------------------------ signatures

  static bool _at(Uint8List b, int offset, List<int> sig) {
    if (b.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  static bool _ascii(Uint8List b, int offset, String s) =>
      _at(b, offset, s.codeUnits);

  static int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
  static int _u32(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static String? _signature(
    Uint8List b,
    String ext,
    Uint8List whole,
    Uint8List? tail,
  ) {
    if (b.isEmpty) return null;
    if (_ascii(b, 0, '%PDF-')) return 'application/pdf';
    if (_at(b, 0, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'image/png';
    }
    if (_at(b, 0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (_ascii(b, 0, 'GIF87a') || _ascii(b, 0, 'GIF89a')) return 'image/gif';
    if (_ascii(b, 0, 'RIFF') && b.length >= 12) {
      if (_ascii(b, 8, 'WEBP')) return 'image/webp';
      if (_ascii(b, 8, 'WAVE')) return 'audio/wav';
      if (_ascii(b, 8, 'AVI ')) return 'video/x-msvideo';
    }
    // BMP: "BM" + four reserved zero bytes at 6.
    if (_ascii(b, 0, 'BM') && _at(b, 6, [0, 0, 0, 0]) && b.length >= 26) {
      return 'image/bmp';
    }
    if (_at(b, 0, [0x49, 0x49, 0x2A, 0x00]) ||
        _at(b, 0, [0x4D, 0x4D, 0x00, 0x2A])) {
      return 'image/tiff';
    }
    // ICO: reserved 0, type 1, 1–255 images.
    if (_at(b, 0, [0, 0, 1, 0]) && b.length >= 6 && b[5] == 0 && b[4] > 0) {
      return 'image/vnd.microsoft.icon';
    }
    if (b.length >= 12 && _ascii(b, 4, 'ftyp')) return _ftyp(b);
    if (_ascii(b, 0, 'ID3') || _isMp3Frame(b)) return 'audio/mpeg';
    if (_ascii(b, 0, 'OggS')) return 'audio/ogg';
    if (_ascii(b, 0, 'fLaC')) return 'audio/flac';
    if (_at(b, 0, [0x1A, 0x45, 0xDF, 0xA3])) {
      return _contains(b, 'webm'.codeUnits) ? 'video/webm' : 'video/x-matroska';
    }
    if (_at(b, 0, [0x50, 0x4B, 0x03, 0x04]) ||
        _at(b, 0, [0x50, 0x4B, 0x05, 0x06])) {
      return _zip(b, ext, whole, tail);
    }
    if (_at(b, 0, [0x1F, 0x8B])) return 'application/gzip';
    if (_at(b, 0, [0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) {
      return 'application/x-7z-compressed';
    }
    if (_ascii(b, 0, 'Rar!\x1A\x07')) return 'application/vnd.rar';
    if (_ascii(b, 257, 'ustar')) return 'application/x-tar';
    if (_at(b, 0, [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])) {
      // OLE2 compound file: the legacy Office family by extension.
      return switch (ext) {
        'doc' => 'application/msword',
        'xls' => 'application/vnd.ms-excel',
        'ppt' => 'application/vnd.ms-powerpoint',
        _ => 'application/x-ole-storage',
      };
    }
    if (_ascii(b, 0, r'{\rtf')) return 'application/rtf';
    if (_ascii(b, 0, 'SQLite format 3\x00')) return 'application/vnd.sqlite3';
    if (_at(b, 0, [0x00, 0x61, 0x73, 0x6D])) return 'application/wasm';
    if (_at(b, 0, [0x7F, 0x45, 0x4C, 0x46])) return 'application/x-executable';
    if (_ascii(b, 0, 'MZ')) return 'application/x-msdownload';
    if (_at(b, 0, [0xCA, 0xFE, 0xBA, 0xBE]) ||
        _at(b, 0, [0xCF, 0xFA, 0xED, 0xFE]) ||
        _at(b, 0, [0xCE, 0xFA, 0xED, 0xFE])) {
      return 'application/x-mach-binary';
    }
    if (_ascii(b, 0, 'wOFF')) return 'font/woff';
    if (_ascii(b, 0, 'wOF2')) return 'font/woff2';
    if (_ascii(b, 0, 'OTTO')) return 'font/otf';
    if (_ascii(b, 0, '%!PS')) return 'application/postscript';
    // The `mime` package's magic numbers for anything else binary.
    final byPackage = mime.lookupMimeType('', headerBytes: b);
    if (byPackage != null && !FileTypes.isTextMimeType(byPackage)) {
      return byPackage;
    }
    return null;
  }

  static String _ftyp(Uint8List b) {
    final brand = String.fromCharCodes(b.sublist(8, 12)).toLowerCase();
    const heic = {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis'};
    if (heic.contains(brand)) return 'image/heic';
    if (brand == 'mif1' || brand == 'msf1') return 'image/heif';
    if (brand == 'avif' || brand == 'avis') return 'image/avif';
    if (brand.startsWith('m4a') || brand == 'm4b ' || brand == 'f4a ') {
      return 'audio/mp4';
    }
    if (brand == 'qt  ') return 'video/quicktime';
    if (brand.startsWith('3g')) return 'video/3gpp';
    return 'video/mp4';
  }

  /// An MPEG audio frame header (sync word, layer, bitrate, sample rate).
  static bool _isMp3Frame(Uint8List b) {
    if (b.length < 4 || b[0] != 0xFF || (b[1] & 0xE0) != 0xE0) return false;
    final version = (b[1] >> 3) & 0x03;
    final layer = (b[1] >> 1) & 0x03;
    final bitrate = (b[2] >> 4) & 0x0F;
    final rate = (b[2] >> 2) & 0x03;
    return version != 1 &&
        layer != 0 &&
        bitrate != 0 &&
        bitrate != 0x0F &&
        rate != 3;
  }

  static bool _contains(Uint8List b, List<int> needle) {
    outer:
    for (var i = 0; i + needle.length <= b.length; i++) {
      for (var j = 0; j < needle.length; j++) {
        if (b[i + j] != needle[j]) continue outer;
      }
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------------ ZIP

  static String _zip(
    Uint8List head,
    String ext,
    Uint8List whole,
    Uint8List? tail,
  ) {
    final names = <String>[];
    String? odfType;
    // Local file headers in the head.
    var o = 0;
    while (o + 30 <= head.length && _at(head, o, [0x50, 0x4B, 0x03, 0x04])) {
      final flags = _u16(head, o + 6);
      final method = _u16(head, o + 8);
      final compSize = _u32(head, o + 18);
      final nameLen = _u16(head, o + 26);
      final extraLen = _u16(head, o + 28);
      final nameEnd = o + 30 + nameLen;
      if (nameEnd > head.length) break;
      final name = latin1.decode(head.sublist(o + 30, nameEnd));
      names.add(name);
      final dataStart = nameEnd + extraLen;
      if (name == 'mimetype' &&
          method == 0 &&
          compSize > 0 &&
          compSize < 200 &&
          dataStart + compSize <= head.length) {
        odfType = latin1
            .decode(head.sublist(dataStart, dataStart + compSize))
            .trim();
      }
      if (flags & 0x08 != 0) break; // sizes follow the data
      o = dataStart + compSize;
    }
    // Central directory entries (end of the object).
    final end = tail ?? whole;
    for (var i = 0; i + 46 <= end.length; i++) {
      if (!_at(end, i, [0x50, 0x4B, 0x01, 0x02])) continue;
      final nameLen = _u16(end, i + 28);
      if (i + 46 + nameLen > end.length) break;
      names.add(latin1.decode(end.sublist(i + 46, i + 46 + nameLen)));
    }
    if (odfType != null && odfType.startsWith('application/')) return odfType;
    bool any(String prefix) => names.any((n) => n.startsWith(prefix));
    final ooxml = names.contains('[Content_Types].xml');
    if (any('word/') && (ooxml || names.length > 1)) return _docx;
    if (any('xl/') && (ooxml || names.length > 1)) return _xlsx;
    if (any('ppt/') && (ooxml || names.length > 1)) return _pptx;
    if (names.contains('META-INF/container.xml') &&
        names.contains('mimetype')) {
      return 'application/epub+zip';
    }
    if (any('Index/Document.iwa') || names.contains('Index.zip')) {
      return switch (ext) {
        'pages' => 'application/vnd.apple.pages',
        'numbers' => 'application/vnd.apple.numbers',
        'key' => 'application/vnd.apple.keynote',
        _ => 'application/zip',
      };
    }
    if (names.contains('META-INF/MANIFEST.MF')) {
      return 'application/java-archive';
    }
    return 'application/zip';
  }

  // ----------------------------------------------------------------- text

  static SniffResult? _text(Uint8List b, String ext, {required bool complete}) {
    String? encoding;
    String? decoded;
    if (_at(b, 0, [0xEF, 0xBB, 0xBF])) {
      decoded = _utf8(b.sublist(3), complete: complete);
      if (decoded == null) return null;
      encoding = 'utf-8';
    } else if (_at(b, 0, [0xFF, 0xFE]) || _at(b, 0, [0xFE, 0xFF])) {
      final le = b[0] == 0xFF;
      final units = <int>[];
      for (var i = 2; i + 1 < b.length; i += 2) {
        units.add(le ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
      }
      if (units.contains(0)) return null;
      decoded = String.fromCharCodes(units);
      encoding = le ? 'utf-16le' : 'utf-16be';
    } else {
      if (b.contains(0)) return null;
      decoded = _utf8(b, complete: complete);
      if (decoded != null) {
        encoding = 'utf-8';
      } else {
        // Not UTF-8: Latin-1 text if control characters are rare.
        var controls = 0;
        for (final c in b) {
          if (c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D && c != 0x0C) {
            controls++;
          } else if (c == 0x7F) {
            controls++;
          }
        }
        if (controls * 100 > b.length) return null;
        decoded = latin1.decode(b);
        encoding = 'latin1';
      }
    }
    if (encoding == 'utf-8' && _controlRatioTooHigh(decoded)) return null;
    return SniffResult(_textType(decoded, ext), encoding: encoding);
  }

  /// Decodes UTF-8, tolerating a multi-byte sequence cut at the end of an
  /// incomplete sample. Null when invalid.
  static String? _utf8(Uint8List b, {required bool complete}) {
    var end = b.length;
    if (!complete) {
      // Drop a trailing partial sequence (at most 3 bytes).
      var i = end - 1;
      var back = 0;
      while (i >= 0 && back < 3 && (b[i] & 0xC0) == 0x80) {
        i--;
        back++;
      }
      if (i >= 0 && b[i] >= 0xC0) {
        final need = b[i] >= 0xF0
            ? 4
            : b[i] >= 0xE0
            ? 3
            : 2;
        if (end - i < need) end = i;
      }
    }
    try {
      return const Utf8Decoder().convert(b, 0, end);
    } on FormatException {
      return null;
    }
  }

  static bool _controlRatioTooHigh(String s) {
    if (s.isEmpty) return false;
    var controls = 0;
    for (final c in s.codeUnits) {
      if ((c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D && c != 0x0C) ||
          c == 0x7F) {
        controls++;
      }
    }
    return controls * 100 > s.length;
  }

  static final _htmlMarker = RegExp(
    r'<\s*(!doctype\s+html|html[\s>]|head[\s>]|body[\s>]|script[\s>]|iframe[\s>]|object[\s>]|embed[\s>])',
    caseSensitive: false,
  );

  static String _textType(String text, String ext) {
    final start = text.trimLeft().toLowerCase();
    final probe = start.length > 1024 ? start.substring(0, 1024) : start;
    // Active markup is detected from the content, never trusted from the
    // name: an HTML page named photo.jpg is text/html (AC-D2.4).
    if (probe.startsWith('<svg') ||
        (probe.startsWith('<?xml') || probe.startsWith('<!doctype svg')) &&
            probe.contains('<svg')) {
      return 'image/svg+xml';
    }
    if (_htmlMarker.hasMatch(probe)) return 'text/html';
    if (probe.startsWith('<?xml')) {
      final byExt = FileTypes.mimeTypesByExtension[ext];
      return byExt != null && byExt.endsWith('xml') ? byExt : 'text/xml';
    }
    final byExt = FileTypes.mimeTypesByExtension[ext];
    if (byExt != null && FileTypes.isTextMimeType(byExt)) {
      // Markup types are only taken from the content (above).
      if (byExt == 'image/svg+xml' || byExt == 'text/xml') return 'text/plain';
      return byExt;
    }
    return 'text/plain';
  }
}
