import 'dart:typed_data';

/// The pixel size of an encoded image, read from its header without
/// decoding the pixels (Drive 02 §6.2: the preview refuses images above
/// 50 MP before decoding them).
///
/// Flutter's `ImageDescriptor.encoded` can't report the size on the web
/// (its `width`/`height` throw `UnsupportedError`), so the Drive preview
/// reads the header itself. Supports PNG, APNG, GIF, JPEG (baseline and
/// progressive; EXIF orientations 5–8 swap the sides), WebP (lossy,
/// lossless, extended), BMP and ICO. Returns null for other formats and for
/// truncated or malformed headers.
final class ImageDimensions {
  const ImageDimensions(this.width, this.height);

  final int width;
  final int height;

  /// Pixel count (`width × height`).
  int get pixels => width * height;

  /// Reads the size of the image in [bytes], or null.
  static ImageDimensions? read(Uint8List bytes) {
    try {
      return _png(bytes) ??
          _gif(bytes) ??
          _jpeg(bytes) ??
          _webp(bytes) ??
          _bmp(bytes) ??
          _ico(bytes);
    } on RangeError {
      return null;
    }
  }

  static bool _starts(Uint8List b, List<int> sig, [int at = 0]) {
    if (b.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[at + i] != sig[i]) return false;
    }
    return true;
  }

  static int _u16be(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
  static int _u16le(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
  static int _u24le(Uint8List b, int i) =>
      b[i] | (b[i + 1] << 8) | (b[i + 2] << 16);
  static int _u32be(Uint8List b, int i) =>
      (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];
  static int _i32le(Uint8List b, int i) =>
      ByteData.sublistView(b, i, i + 4).getInt32(0, Endian.little);

  static ImageDimensions? _valid(int w, int h) =>
      w > 0 && h > 0 ? ImageDimensions(w, h) : null;

  static ImageDimensions? _png(Uint8List b) {
    const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (!_starts(b, sig) || !_starts(b, 'IHDR'.codeUnits, 12)) return null;
    return _valid(_u32be(b, 16), _u32be(b, 20));
  }

  static ImageDimensions? _gif(Uint8List b) {
    if (!_starts(b, 'GIF87a'.codeUnits) && !_starts(b, 'GIF89a'.codeUnits)) {
      return null;
    }
    return _valid(_u16le(b, 6), _u16le(b, 8));
  }

  static ImageDimensions? _jpeg(Uint8List b) {
    if (!_starts(b, const [0xFF, 0xD8])) return null;
    var orientation = 1;
    var i = 2;
    while (i + 4 <= b.length) {
      if (b[i] != 0xFF) return null;
      final marker = b[i + 1];
      if (marker == 0xFF) {
        i++; // fill byte
        continue;
      }
      if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      final len = _u16be(b, i + 2);
      if (len < 2) return null;
      if (marker == 0xE1) {
        orientation = _exifOrientation(b, i + 4, len - 2) ?? orientation;
      }
      final sof =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (sof) {
        final h = _u16be(b, i + 5);
        final w = _u16be(b, i + 7);
        return orientation >= 5 && orientation <= 8
            ? _valid(h, w)
            : _valid(w, h);
      }
      if (marker == 0xD9 || marker == 0xDA) return null; // no frame header
      i += 2 + len;
    }
    return null;
  }

  /// The EXIF orientation tag (0x0112) of an APP1 segment, or null.
  static int? _exifOrientation(Uint8List b, int start, int length) {
    if (!_starts(b, 'Exif'.codeUnits, start)) return null;
    final tiff = start + 6;
    if (tiff + 8 > b.length) return null;
    final little = b[tiff] == 0x49; // "II"
    int u16(int i) => little ? _u16le(b, i) : _u16be(b, i);
    int u32(int i) => little
        ? b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)
        : _u32be(b, i);
    final ifd = tiff + u32(tiff + 4);
    if (ifd + 2 > b.length) return null;
    final count = u16(ifd);
    for (var n = 0; n < count; n++) {
      final e = ifd + 2 + n * 12;
      if (e + 12 > b.length) return null;
      if (u16(e) == 0x0112) return u16(e + 8);
    }
    return null;
  }

  static ImageDimensions? _webp(Uint8List b) {
    if (!_starts(b, 'RIFF'.codeUnits) || !_starts(b, 'WEBP'.codeUnits, 8)) {
      return null;
    }
    if (_starts(b, 'VP8 '.codeUnits, 12)) {
      // Lossy: frame tag (3 bytes), start code 9D 01 2A, 14-bit sizes.
      if (!_starts(b, const [0x9D, 0x01, 0x2A], 23)) return null;
      return _valid(_u16le(b, 26) & 0x3FFF, _u16le(b, 28) & 0x3FFF);
    }
    if (_starts(b, 'VP8L'.codeUnits, 12)) {
      if (b[20] != 0x2F) return null;
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      return _valid((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
    }
    if (_starts(b, 'VP8X'.codeUnits, 12)) {
      return _valid(_u24le(b, 24) + 1, _u24le(b, 27) + 1);
    }
    return null;
  }

  static ImageDimensions? _bmp(Uint8List b) {
    if (!_starts(b, 'BM'.codeUnits) || b.length < 26) return null;
    final header = _u32le(b, 14);
    if (header == 12) return _valid(_u16le(b, 18), _u16le(b, 20));
    return _valid(_i32le(b, 18).abs(), _i32le(b, 22).abs());
  }

  static int _u32le(Uint8List b, int i) =>
      b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

  static ImageDimensions? _ico(Uint8List b) {
    if (!_starts(b, const [0, 0, 1, 0]) || b.length < 22) return null;
    if (_u16le(b, 4) == 0) return null;
    // The first directory entry; 0 means 256.
    final w = b[6] == 0 ? 256 : b[6];
    final h = b[7] == 0 ? 256 : b[7];
    return ImageDimensions(w, h);
  }

  @override
  bool operator ==(Object other) =>
      other is ImageDimensions &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => '${width}x$height';
}
