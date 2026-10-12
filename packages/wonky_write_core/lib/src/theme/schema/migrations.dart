/// Step-by-step upgrades of older theme `schemaVersion`s (06 §2.7).
library;

import '../model/json_util.dart';
import '../model/write_theme_data.dart';

/// Thrown when theme JSON cannot be migrated to the current schema.
final class ThemeMigrationException implements Exception {
  /// Creates the exception.
  const ThemeMigrationException(this.message, this.version);

  /// Explanation.
  final String message;

  /// The offending `schemaVersion` value.
  final Object? version;

  @override
  String toString() => 'ThemeMigrationException: $message';
}

/// A migration step from schema version `n` to `n + 1`.
typedef ThemeMigrationStep = JsonMap Function(JsonMap json);

/// Upgrades theme JSON to [currentThemeSchemaVersion].
///
/// The server stores only the latest schema version and migrates rows
/// lazily on read; imports migrate before validation.
abstract final class ThemeMigrations {
  /// Steps keyed by the version they upgrade *from*. Schema v1 is the first
  /// version, so there are no steps yet; add `n: (json) => …` when bumping
  /// [currentThemeSchemaVersion] to `n + 1`.
  static final Map<int, ThemeMigrationStep> steps = {};

  /// Whether [json] needs migration (its version is older than current).
  static bool needsMigration(JsonMap json) {
    final v = json['schemaVersion'];
    return v is int && v < currentThemeSchemaVersion;
  }

  /// Returns a migrated deep copy of [json] with `schemaVersion` set to
  /// [currentThemeSchemaVersion]. A missing `schemaVersion` is treated as
  /// version 1 (the first schema).
  ///
  /// Throws [ThemeMigrationException] for non-objects, non-integer or
  /// unknown/newer versions.
  static JsonMap migrate(Object? json) {
    if (json is! Map) {
      throw const ThemeMigrationException('A theme must be a JSON object.', null);
    }
    var out = deepCopyJson(json) as JsonMap;
    final raw = out['schemaVersion'] ?? 1;
    if (raw is! num || raw != raw.roundToDouble()) {
      throw ThemeMigrationException('schemaVersion must be an integer.', raw);
    }
    var version = raw.toInt();
    if (version > currentThemeSchemaVersion) {
      throw ThemeMigrationException(
        'Theme schema version $version is newer than supported '
        '($currentThemeSchemaVersion). Update Wonky Write.',
        raw,
      );
    }
    while (version < currentThemeSchemaVersion) {
      final step = steps[version];
      if (step == null) {
        throw ThemeMigrationException(
          'No migration from theme schema version $version.',
          raw,
        );
      }
      out = step(out);
      version++;
      out['schemaVersion'] = version;
    }
    out['schemaVersion'] = currentThemeSchemaVersion;
    return out;
  }
}
