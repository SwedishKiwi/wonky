/// Text encoding detection for imports (07 §3.3): UTF-8 (BOM stripped),
/// UTF-16 LE/BE (by BOM or byte pattern), invalid UTF-8 → Windows-1252.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'code_page_tables.dart';
import 'import_api.dart';

/// Encodings recognized by [ImportTextDecoder].
enum ImportTextEncoding {
  /// UTF-8 (with or without BOM).
  utf8,

  /// UTF-16 little endian.
  utf16le,

  /// UTF-16 big endian.
  utf16be,

  /// A single-byte Windows/DOS code page (see [DecodedText.codePage]).
  singleByte,
}

/// A single-byte code page (Windows 1250–1258, 874, DOS 437 and 850).
final class CodePage {
  const CodePage._(this.number, this._upper);

  /// The code page number (e.g. 1252).
  final int number;

  final List<int> _upper;

  /// The table for [number], or `null` when not built in.
  static CodePage? forNumber(int number) {
    final table = codePageUpperHalves[number];
    return table == null ? null : CodePage._(number, table);
  }

  /// Windows-1252 (Western European), the fallback for invalid UTF-8.
  static final windows1252 = CodePage._(1252, codePageUpperHalves[1252]!);

  /// Built-in code page numbers.
  static Iterable<int> get supported => codePageUpperHalves.keys;

  /// The code point for byte [b] (0xFFFD when undefined).
  int decodeByte(int b) => b < 0x80 ? b : _upper[(b & 0xFF) - 0x80];

  /// Decodes [bytes].
  String decode(List<int> bytes) {
    final units = Uint16List(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      units[i] = decodeByte(bytes[i]);
    }
    return String.fromCharCodes(units);
  }

  /// The code page for an RTF/Windows `fcharset` value, or `null` (symbol
  /// fonts, unsupported East Asian charsets).
  static int? numberForCharset(int charset) => switch (charset) {
    0 || 1 => 1252,
    161 => 1253,
    162 => 1254,
    163 => 1258,
    177 => 1255,
    178 => 1256,
    186 => 1257,
    204 => 1251,
    222 => 874,
    238 => 1250,
    254 => 437,
    255 => 850,
    _ => null,
  };

  /// The code page for an HTML/MIME charset label, or `null`.
  static int? numberForLabel(String label) {
    final l = label.trim().toLowerCase();
    if (l == 'iso-8859-1' ||
        l == 'latin1' ||
        l == 'us-ascii' ||
        l == 'ascii' ||
        l == 'iso8859-1' ||
        l == 'l1' ||
        l == 'cp1252') {
      return 1252; // WHATWG: these labels mean windows-1252.
    }
    final m = RegExp(r'^(?:windows-|cp|x-cp)(\d{3,4})$').firstMatch(l);
    if (m != null) {
      final n = int.parse(m.group(1)!);
      return codePageUpperHalves.containsKey(n) ? n : null;
    }
    if (l == 'ibm437') return 437;
    if (l == 'ibm850') return 850;
    if (l == 'iso-8859-2') return 1250;
    if (l == 'iso-8859-9') return 1254;
    if (l == 'tis-620' || l == 'iso-8859-11') return 874;
    return null;
  }
}

/// Text decoded from import bytes.
final class DecodedText {
  /// Creates a decoded text.
  const DecodedText(
    this.text,
    this.encoding, {
    this.codePage,
    this.hadBom = false,
    this.guessed = false,
  });

  /// The text (BOM removed; line endings unchanged).
  final String text;

  /// The encoding used.
  final ImportTextEncoding encoding;

  /// The code page for [ImportTextEncoding.singleByte].
  final int? codePage;

  /// Whether a byte order mark was present.
  final bool hadBom;

  /// Whether the encoding was guessed (invalid UTF-8 decoded as
  /// Windows-1252).
  final bool guessed;

  /// The [ImportWarningKind.encodingGuessed] warning, when [guessed].
  ImportWarning? get warning => guessed
      ? const ImportWarning(
          ImportWarningKind.encodingGuessed,
          'The file is not valid UTF-8; it was read as Windows-1252 '
          '(Western European). Some characters may be wrong.',
        )
      : null;
}

/// Decodes import bytes into text.
abstract final class ImportTextDecoder {
  /// Decodes [bytes]:
  ///
  /// 1. A BOM selects UTF-8, UTF-16 LE or UTF-16 BE (and is stripped).
  /// 2. Without BOM, a [declaredCharset] (e.g. HTML `<meta charset>`) is
  ///    honored when known.
  /// 3. Text with a NUL byte in most odd (even) positions is UTF-16 LE (BE).
  /// 4. Valid UTF-8 is UTF-8; anything else is Windows-1252 (guessed).
  static DecodedText decode(Uint8List bytes, {String? declaredCharset}) {
    final n = bytes.length;
    if (n >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return DecodedText(
        utf8.decode(bytes.sublist(3), allowMalformed: true),
        ImportTextEncoding.utf8,
        hadBom: true,
      );
    }
    if (n >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return DecodedText(
        decodeUtf16(bytes, 2, littleEndian: true),
        ImportTextEncoding.utf16le,
        hadBom: true,
      );
    }
    if (n >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return DecodedText(
        decodeUtf16(bytes, 2, littleEndian: false),
        ImportTextEncoding.utf16be,
        hadBom: true,
      );
    }
    if (declaredCharset != null) {
      final label = declaredCharset.trim().toLowerCase();
      if (label == 'utf-8' || label == 'utf8') {
        return _utf8OrFallback(bytes);
      }
      final cp = CodePage.numberForLabel(label);
      if (cp != null) {
        return DecodedText(
          CodePage.forNumber(cp)!.decode(bytes),
          ImportTextEncoding.singleByte,
          codePage: cp,
        );
      }
    }
    final utf16 = _sniffUtf16(bytes);
    if (utf16 != null) {
      return DecodedText(
        decodeUtf16(bytes, 0, littleEndian: utf16),
        utf16 ? ImportTextEncoding.utf16le : ImportTextEncoding.utf16be,
      );
    }
    return _utf8OrFallback(bytes);
  }

  static DecodedText _utf8OrFallback(Uint8List bytes) {
    try {
      return DecodedText(utf8.decode(bytes), ImportTextEncoding.utf8);
    } on FormatException {
      return DecodedText(
        CodePage.windows1252.decode(bytes),
        ImportTextEncoding.singleByte,
        codePage: 1252,
        guessed: true,
      );
    }
  }

  /// Decodes Windows-1252 [bytes].
  static String decodeWindows1252(List<int> bytes) =>
      CodePage.windows1252.decode(bytes);

  /// Decodes UTF-16 code units from [bytes] starting at [start] (an odd
  /// trailing byte is ignored).
  static String decodeUtf16(
    Uint8List bytes,
    int start, {
    required bool littleEndian,
  }) {
    final count = (bytes.length - start) ~/ 2;
    final units = Uint16List(count);
    for (var i = 0; i < count; i++) {
      final a = bytes[start + 2 * i];
      final b = bytes[start + 2 * i + 1];
      units[i] = littleEndian ? (b << 8) | a : (a << 8) | b;
    }
    return String.fromCharCodes(units);
  }

  /// `true` = UTF-16 LE, `false` = BE, `null` = not UTF-16.
  static bool? _sniffUtf16(Uint8List bytes) {
    final sample = bytes.length < 4096 ? bytes.length : 4096;
    if (sample < 4) return null;
    var evenZeros = 0;
    var oddZeros = 0;
    final pairs = sample ~/ 2;
    for (var i = 0; i < pairs; i++) {
      if (bytes[2 * i] == 0) evenZeros++;
      if (bytes[2 * i + 1] == 0) oddZeros++;
    }
    if (oddZeros > pairs * 0.4 && evenZeros < pairs * 0.05) return true;
    if (evenZeros > pairs * 0.4 && oddZeros < pairs * 0.05) return false;
    return null;
  }

  /// CRLF and CR → LF.
  static String normalizeLineEndings(String s) =>
      s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
