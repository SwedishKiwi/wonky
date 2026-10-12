/// Deterministic zip packaging (07 §1.5: sorted entries, fixed timestamps).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One zip entry.
final class ZipEntry {
  /// Creates an entry from bytes.
  ZipEntry(this.path, this.bytes, {this.store = false});

  /// Creates a UTF-8 text entry.
  ZipEntry.text(this.path, String text, {this.store = false}) : bytes = Uint8List.fromList(utf8.encode(text));

  /// Path inside the archive (`/`-separated).
  final String path;

  /// Content.
  final Uint8List bytes;

  /// Store without compression (EPUB/ODT `mimetype`).
  final bool store;
}

/// Builds byte-identical zips for identical inputs.
abstract final class DeterministicZip {
  /// Default timestamp when no modification time is known.
  static final defaultTime = DateTime.utc(2000, 1, 1);

  /// Encodes [entries]. Entries listed in [first] keep that order at the
  /// start (e.g. `mimetype`); the rest are sorted by path when [sort].
  static Uint8List encode(
    List<ZipEntry> entries, {
    DateTime? modified,
    List<String> first = const [],
    bool sort = true,
  }) {
    final head = [
      for (final p in first) ...entries.where((e) => e.path == p),
    ];
    final rest = entries.where((e) => !first.contains(e.path)).toList();
    if (sort) rest.sort((a, b) => a.path.compareTo(b.path));
    final time = modified ?? defaultTime;
    // Zip has no time zone; use the UTC wall clock so output is identical
    // on every machine.
    final wall = DateTime(time.toUtc().year, time.toUtc().month, time.toUtc().day, time.toUtc().hour,
        time.toUtc().minute, time.toUtc().second);
    final archive = Archive();
    for (final e in [...head, ...rest]) {
      final f = e.store ? ArchiveFile.noCompress(e.path, e.bytes.length, e.bytes) : ArchiveFile.bytes(e.path, e.bytes);
      f.lastModTime = wall.millisecondsSinceEpoch ~/ 1000;
      archive.addFile(f);
    }
    return ZipEncoder().encodeBytes(archive, modified: wall);
  }

  /// Decodes a zip into path → bytes (for tests and importers).
  static Map<String, Uint8List> decode(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    return {
      for (final f in archive.files)
        if (f.isFile) f.name: Uint8List.fromList(f.content as List<int>),
    };
  }
}
