/// `DeckThemeValidator` (Slides 05 §2): migrate → parse/validate → clean
/// value per theme JSON column. Unknown keys are dropped with a warning.
library;

import 'dart:convert';

import '../json/json_util.dart';
import '../model/background.dart';
import '../model/deck_theme_data.dart';
import '../model/object_styles.dart';
import '../model/text_styles.dart';
import '../model/theme_colors.dart';
import '../model/theme_fonts.dart';
import 'migrations.dart';

/// The result of validating one column.
final class ThemeColumnResult {
  /// Creates a result.
  const ThemeColumnResult({
    required this.column,
    required this.value,
    required this.errors,
    required this.warnings,
  });

  /// The column.
  final DeckThemeColumn column;

  /// The typed value ([ThemeColors], [ThemeFonts], [ThemeTextStyles],
  /// [SlideBackground], [ThemeShapeStyles], [ThemeTableStyle],
  /// [ThemeCodeStyle], [ThemeChartStyle]); `null` when [errors] is not
  /// empty or the optional column is absent.
  final Object? value;

  /// Blocking issues.
  final List<ThemeIssue> errors;

  /// Repairs applied to [value].
  final List<ThemeIssue> warnings;

  /// Whether the value can be written.
  bool get isValid => errors.isEmpty;

  /// The cleaned JSON (what a writer stores), or `null`.
  JsonMap? get cleanedJson => switch (value) {
    final ThemeColors v => v.toJson(),
    final ThemeFonts v => v.toJson(),
    final ThemeTextStyles v => v.toJson(),
    final SlideBackground v => v.toJson(),
    final ThemeShapeStyles v => v.toJson(),
    final ThemeTableStyle v => v.toJson(),
    final ThemeCodeStyle v => v.toJson(),
    final ThemeChartStyle v => v.toJson(),
    _ => null,
  };
}

/// The result of validating a whole theme.
final class DeckThemeValidationResult {
  /// Creates a result.
  const DeckThemeValidationResult({
    required this.theme,
    required this.errors,
    required this.warnings,
  });

  /// The cleaned theme, or `null` when [errors] is not empty.
  final DeckThemeData? theme;

  /// Blocking issues.
  final List<ThemeIssue> errors;

  /// Repairs applied to [theme].
  final List<ThemeIssue> warnings;

  /// Whether the theme can be written.
  bool get isValid => errors.isEmpty;
}

/// Validates theme JSON from any source (rows, imports, templates, MCP).
final class DeckThemeValidator {
  /// Creates a validator.
  const DeckThemeValidator();

  /// Migrates and validates decoded [json] of [column]. `null` is valid for
  /// optional columns.
  ThemeColumnResult validateColumn(DeckThemeColumn column, Object? json) {
    final sink = IssueSink();
    if (json == null) {
      if (column.required) {
        sink.error(column.name, 'missing', '${column.name} is required.');
      }
      return _result(column, null, sink);
    }
    JsonMap migrated;
    try {
      migrated = DeckThemeMigrations.migrate(column, json);
    } on DeckThemeMigrationException catch (e) {
      sink.error(
        json is Map ? '${column.name}.v' : column.name,
        json is Map ? 'unsupported_version' : 'wrong_type',
        e.message,
      );
      return _result(column, null, sink);
    }
    final path = column.name;
    final Object? value = switch (column) {
      DeckThemeColumn.colorsJson => ThemeColors.fromJson(
        migrated,
        sink,
        path: path,
      ),
      DeckThemeColumn.fontsJson => ThemeFonts.fromJson(
        migrated,
        sink,
        path: path,
      ),
      DeckThemeColumn.textStylesJson => ThemeTextStyles.fromJson(
        migrated,
        sink,
        path: path,
        fallbackStyles: defaultThemeTextStyles,
      ),
      DeckThemeColumn.backgroundJson => SlideBackground.fromJson(
        migrated,
        sink,
        path: path,
      ),
      DeckThemeColumn.shapeStyleJson => ThemeShapeStyles.fromJson(
        migrated,
        sink,
        path: path,
      ),
      DeckThemeColumn.tableStyleJson => ThemeTableStyle.fromJson(
        migrated,
        sink,
        path: path,
      ),
      DeckThemeColumn.codeStyleJson => ThemeCodeStyle.fromJson(
        migrated,
        sink,
        path: path,
      ),
      DeckThemeColumn.chartStyleJson => ThemeChartStyle.fromJson(
        migrated,
        sink,
        path: path,
      ),
    };
    return _result(column, sink.hasErrors ? null : value, sink);
  }

  /// [validateColumn] for a stored JSON string (`null` = absent column).
  ThemeColumnResult validateColumnString(
    DeckThemeColumn column,
    String? source,
  ) {
    if (source == null) return validateColumn(column, null);
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      final sink = IssueSink()
        ..error(column.name, 'invalid_json', 'Invalid JSON: ${e.message}');
      return _result(column, null, sink);
    }
    return validateColumn(column, decoded);
  }

  /// Validates a whole theme given as `{name, sourceKey?, colorsJson, …}`
  /// where each JSON column is a decoded object or a JSON string (the
  /// shape of [DeckThemeData.toJson] and of [DeckThemeData.toColumns]).
  DeckThemeValidationResult validateTheme(Map<String, Object?> columns) {
    final errors = <ThemeIssue>[];
    final warnings = <ThemeIssue>[];
    final known = {
      'name',
      'sourceKey',
      for (final c in DeckThemeColumn.values) c.name,
    };
    for (final key in columns.keys) {
      if (!known.contains(key)) {
        warnings.add(
          ThemeIssue(
            ThemeIssueSeverity.warning,
            key,
            'unknown_key',
            'Unknown key "$key" was dropped.',
          ),
        );
      }
    }
    final name = columns['name'];
    if (name is! String || name.trim().isEmpty || name.length > 100) {
      errors.add(
        const ThemeIssue(
          ThemeIssueSeverity.error,
          'name',
          'invalid_name',
          'A theme needs a name of 1–100 characters.',
        ),
      );
    }
    final sourceKey = columns['sourceKey'];
    if (sourceKey != null && sourceKey is! String) {
      errors.add(
        const ThemeIssue(
          ThemeIssueSeverity.error,
          'sourceKey',
          'wrong_type',
          'Expected a string.',
        ),
      );
    }
    final values = <DeckThemeColumn, Object?>{};
    for (final c in DeckThemeColumn.values) {
      final raw = columns[c.name];
      final r = raw is String
          ? validateColumnString(c, raw)
          : validateColumn(c, raw);
      errors.addAll(r.errors);
      warnings.addAll(r.warnings);
      values[c] = r.value;
    }
    if (errors.isNotEmpty) {
      return DeckThemeValidationResult(
        theme: null,
        errors: List.unmodifiable(errors),
        warnings: List.unmodifiable(warnings),
      );
    }
    return DeckThemeValidationResult(
      theme: DeckThemeData(
        name: (name as String).trim(),
        sourceKey: sourceKey as String?,
        colors: values[DeckThemeColumn.colorsJson] as ThemeColors,
        fonts: values[DeckThemeColumn.fontsJson] as ThemeFonts,
        textStyles: values[DeckThemeColumn.textStylesJson] as ThemeTextStyles,
        background: values[DeckThemeColumn.backgroundJson] as SlideBackground,
        shapeStyles:
            values[DeckThemeColumn.shapeStyleJson] as ThemeShapeStyles?,
        tableStyle: values[DeckThemeColumn.tableStyleJson] as ThemeTableStyle?,
        codeStyle: values[DeckThemeColumn.codeStyleJson] as ThemeCodeStyle?,
        chartStyle: values[DeckThemeColumn.chartStyleJson] as ThemeChartStyle?,
      ),
      errors: const [],
      warnings: List.unmodifiable(warnings),
    );
  }

  ThemeColumnResult _result(
    DeckThemeColumn column,
    Object? value,
    IssueSink sink,
  ) => ThemeColumnResult(
    column: column,
    value: value,
    errors: List.unmodifiable(sink.errors),
    warnings: List.unmodifiable(sink.warnings),
  );
}

/// Parses a stored `DeckTheme` row (`name`, `sourceKey`, JSON column
/// strings) into [DeckThemeData]. Throws [FormatException] listing the
/// errors when the row is invalid.
DeckThemeData deckThemeFromColumns(Map<String, String?> columns) {
  final r = const DeckThemeValidator().validateTheme(columns);
  if (r.theme == null) {
    throw FormatException(
      'Invalid theme: ${r.errors.map((e) => '${e.path}: ${e.message}').join('; ')}',
    );
  }
  return r.theme!;
}
