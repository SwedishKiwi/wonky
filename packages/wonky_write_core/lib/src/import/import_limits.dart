/// Import size limits and import errors (07 §3.1).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../delta/delta_utils.dart';

/// Size limits applied by [WonkyImporters] (07 §3.1).
///
/// Client imports are limited to [clientMaxInputBytes] of input and
/// [clientMaxResultChars] of resulting document; larger files go to the
/// server, which allows [serverMaxInputBytes] / [serverMaxResultChars]
/// (`write.maxDocumentChars`).
final class ImportLimits {
  /// Creates custom limits.
  const ImportLimits({
    required this.maxInputBytes,
    required this.maxResultChars,
  });

  /// Client input limit: 5 MB.
  static const clientMaxInputBytes = 5 * 1024 * 1024;

  /// Client result limit: 200k characters.
  static const clientMaxResultChars = 200000;

  /// Server input limit: 50 MB.
  static const serverMaxInputBytes = 50 * 1024 * 1024;

  /// Server result limit: 2M characters (`write.maxDocumentChars`).
  static const serverMaxResultChars = 2000000;

  /// Limits for imports running in the apps.
  static const client = ImportLimits(
    maxInputBytes: clientMaxInputBytes,
    maxResultChars: clientMaxResultChars,
  );

  /// Limits for imports running on the server.
  static const server = ImportLimits(
    maxInputBytes: serverMaxInputBytes,
    maxResultChars: serverMaxResultChars,
  );

  /// No limits (tests, tools).
  static const unlimited = ImportLimits(
    maxInputBytes: 1 << 52,
    maxResultChars: 1 << 52,
  );

  /// Maximum input size in bytes.
  final int maxInputBytes;

  /// Maximum length of the resulting document delta.
  final int maxResultChars;

  /// Throws [ImportTooLargeException] when [byteLength] exceeds the input
  /// limit.
  void checkInput(int byteLength) {
    if (byteLength > maxInputBytes) {
      throw ImportTooLargeException(
        ImportLimitKind.inputBytes,
        actual: byteLength,
        limit: maxInputBytes,
      );
    }
  }

  /// Throws [ImportTooLargeException] when [document] is longer than the
  /// result limit.
  void checkResult(Delta document) {
    final length = DeltaUtils.documentLength(document);
    if (length > maxResultChars) {
      throw ImportTooLargeException(
        ImportLimitKind.resultChars,
        actual: length,
        limit: maxResultChars,
      );
    }
  }
}

/// Which limit an [ImportTooLargeException] refers to.
enum ImportLimitKind {
  /// The input file is too large.
  inputBytes,

  /// The resulting document is too long.
  resultChars,
}

/// The input or the resulting document exceeds the [ImportLimits]
/// (`ImportTooLarge`, 07 §3.1). Clients retry on the server; the server
/// reports it with a message suggesting splitting the file.
final class ImportTooLargeException implements Exception {
  /// Creates the exception.
  const ImportTooLargeException(
    this.kind, {
    required this.actual,
    required this.limit,
  });

  /// Which limit was exceeded.
  final ImportLimitKind kind;

  /// Actual size (bytes or characters).
  final int actual;

  /// The limit (bytes or characters).
  final int limit;

  /// User-facing message.
  String get message => switch (kind) {
    ImportLimitKind.inputBytes =>
      'The file is too large to import ($actual bytes, limit $limit). '
          'Try splitting it into smaller files.',
    ImportLimitKind.resultChars =>
      'The imported document is too long ($actual characters, limit '
          '$limit). Try splitting it into smaller files.',
  };

  @override
  String toString() => 'ImportTooLargeException: $message';
}

/// The bytes are clearly not in the expected format (e.g. a DOCX importer
/// given a file that is not a ZIP package). Malformed content in the right
/// format never throws; importers return a best-effort result with warnings.
final class ImportFormatException implements Exception {
  /// Creates the exception.
  const ImportFormatException(this.message);

  /// Description.
  final String message;

  @override
  String toString() => 'ImportFormatException: $message';
}
