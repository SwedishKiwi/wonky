import '../common/errors.dart';

/// Display names and download headers of uploaded files (Drive 02 §5.1,
/// suite 13 §6).
abstract final class FileNames {
  /// Control characters and the bidi overrides/isolates U+202A–U+202E,
  /// U+2066–U+2069 (so `invoice<U+202E>fdp.exe` can't pose as a PDF), plus
  /// the zero-width/BOM characters that hide extensions.
  static final _strip = RegExp(
    r'[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069\u200e\u200f\u061c\ufeff]',
  );

  /// The display name of an uploaded file: trimmed, control and bidi
  /// characters removed, `/` and `\` replaced by `_`, 1–255 characters.
  /// Throws `invalidArgument`.
  static String sanitize(String name) {
    final cleaned = name
        .replaceAll(_strip, '')
        .replaceAll(RegExp(r'[/\\]'), '_')
        .trim();
    if (cleaned.isEmpty) throw Errors.invalid('The file name cannot be empty.');
    if (cleaned.length > 255) {
      throw Errors.invalid('The file name can have at most 255 characters.');
    }
    if (cleaned == '.' || cleaned == '..') {
      throw Errors.invalid('This file name is not allowed.');
    }
    return cleaned;
  }

  /// An ASCII-only version of [name] for storage paths and the plain
  /// `filename=` parameter (non-ASCII → `_`, quotes and separators
  /// removed; at most 120 characters, keeping the extension).
  static String ascii(String name) {
    final base = name.split(RegExp(r'[\\/]')).last.trim();
    final cleaned = base.replaceAll(RegExp(r'[^A-Za-z0-9._ ()-]'), '_');
    final short = cleaned.length > 120
        ? cleaned.substring(cleaned.length - 120)
        : cleaned;
    return short.isEmpty ? 'file' : short;
  }

  /// `name (1).ext`, `name (2).ext` … for "Keep both" (Drive 02 §3.2).
  static String numbered(String name, int n) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '$name ($n)';
    return '${name.substring(0, dot)} ($n)${name.substring(dot)}';
  }

  /// The name without its extension (*Open with* names the new item after
  /// the file, Drive 02 §7.2).
  static String withoutExtension(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  /// `attachment; filename="<ascii>"; filename*=UTF-8''<encoded>`
  /// (RFC 6266 / 5987; suite 13 §6).
  static String contentDisposition(String name) {
    final encoded = Uri.encodeComponent(
      name,
    ).replaceAll("'", '%27').replaceAll('(', '%28').replaceAll(')', '%29');
    return 'attachment; filename="${ascii(name)}"; '
        "filename*=UTF-8''$encoded";
  }
}
