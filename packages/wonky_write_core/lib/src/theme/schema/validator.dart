/// `WriteThemeValidator`: migrate → schema check → semantic checks (06 §2.7).
library;

import 'dart:convert';

import '../model/json_util.dart';
import '../model/properties.dart';
import '../model/theme_parser.dart';
import '../model/write_theme_data.dart';
import 'migrations.dart';

/// Result of [WriteThemeValidator.validate].
final class ThemeValidationResult {
  /// Creates a result.
  const ThemeValidationResult({
    required this.theme,
    required this.errors,
    required this.warnings,
  });

  /// The cleaned theme (unknown properties dropped, unknown fonts replaced
  /// by the role default, weights snapped), or `null` when [errors] is not
  /// empty.
  final WriteThemeData? theme;

  /// Blocking issues: wrong types, out-of-bounds lengths, incomplete
  /// palettes, `fromLevel > toLevel`, wrong bullet/numbering counts, …
  final List<ThemeIssue> errors;

  /// Non-blocking issues describing the cleaning applied to [theme].
  final List<ThemeIssue> warnings;

  /// Whether the theme can be saved / imported.
  bool get isValid => errors.isEmpty;

  /// MCP `validation_failed` details: `[{path, message, code}]`.
  List<JsonMap> get errorDetails => [
    for (final e in errors) {'path': e.path, 'message': e.message, 'code': e.code},
  ];

  /// Warnings as JSON for MCP results.
  List<JsonMap> get warningDetails => [
    for (final w in warnings)
      {'path': w.path, 'message': w.message, 'code': w.code},
  ];
}

/// Validates theme JSON from any source (imports, MCP, endpoints).
final class WriteThemeValidator {
  /// Creates a validator.
  const WriteThemeValidator();

  /// Migrates and validates decoded [json].
  ThemeValidationResult validate(Object? json) {
    JsonMap migrated;
    try {
      migrated = ThemeMigrations.migrate(json);
    } on ThemeMigrationException catch (e) {
      return ThemeValidationResult(
        theme: null,
        errors: [
          ThemeIssue(
            ThemeIssueSeverity.error,
            json is Map ? 'schemaVersion' : '',
            json is Map ? 'unsupported_version' : 'wrong_type',
            e.message,
          ),
        ],
        warnings: const [],
      );
    }
    final r = parseThemeJson(migrated);
    return ThemeValidationResult(
      theme: r.theme,
      errors: List.unmodifiable(r.errors),
      warnings: List.unmodifiable(r.warnings),
    );
  }

  /// Decodes and validates JSON text; syntax errors are reported as an
  /// `invalid_json` error.
  ThemeValidationResult validateString(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      return ThemeValidationResult(
        theme: null,
        errors: [
          ThemeIssue(
            ThemeIssueSeverity.error,
            '',
            'invalid_json',
            'Invalid JSON: ${e.message}',
          ),
        ],
        warnings: const [],
      );
    }
    return validate(decoded);
  }
}
