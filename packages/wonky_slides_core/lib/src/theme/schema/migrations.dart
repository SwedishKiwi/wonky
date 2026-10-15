/// `DeckThemeMigrations` (Slides 05 §2): step-by-step upgrades of the
/// `"v"` version of each theme JSON column (as Write 06 §2.7).
library;

import '../json/json_util.dart';
import '../model/deck_theme_data.dart';

/// The current version of every theme JSON column.
const int currentThemeColumnVersion = 1;

/// Thrown when a theme column cannot be migrated.
final class DeckThemeMigrationException implements Exception {
  /// Creates the exception.
  const DeckThemeMigrationException(this.column, this.message, this.version);

  /// The column.
  final DeckThemeColumn column;

  /// Explanation.
  final String message;

  /// The offending `"v"` value.
  final Object? version;

  @override
  String toString() => 'DeckThemeMigrationException(${column.name}): $message';
}

/// A migration step of one column from version `n` to `n + 1`.
typedef DeckThemeMigrationStep = JsonMap Function(JsonMap json);

/// Upgrades theme JSON columns to [currentThemeColumnVersion]. Readers
/// migrate lazily (rows keep their stored version until rewritten); imports,
/// templates and MCP migrate before validation.
abstract final class DeckThemeMigrations {
  /// Steps per column, keyed by the version they upgrade *from*. v1 is the
  /// first version; add `column: {1: (json) => …}` when a column moves to
  /// v2 (and bump [currentThemeColumnVersion] for that column).
  static final Map<DeckThemeColumn, Map<int, DeckThemeMigrationStep>> steps =
      {};

  /// Whether [json] of [column] is older than current.
  static bool needsMigration(DeckThemeColumn column, JsonMap json) {
    final v = json['v'];
    return v is int && v < currentThemeColumnVersion;
  }

  /// A migrated deep copy of [json] with `"v"` set to the current version. A
  /// missing `"v"` is treated as version 1.
  ///
  /// Throws [DeckThemeMigrationException] for non-objects and for
  /// non-integer, unknown or newer versions.
  static JsonMap migrate(DeckThemeColumn column, Object? json) {
    if (json is! Map) {
      throw DeckThemeMigrationException(
        column,
        '${column.name} must be a JSON object.',
        null,
      );
    }
    var out = deepCopyJson(json) as JsonMap;
    final raw = out['v'] ?? 1;
    if (raw is! num || raw != raw.roundToDouble()) {
      throw DeckThemeMigrationException(column, '"v" must be an integer.', raw);
    }
    var version = raw.toInt();
    if (version < 1 || version > currentThemeColumnVersion) {
      throw DeckThemeMigrationException(
        column,
        'Version $version of ${column.name} is not supported '
        '(current: $currentThemeColumnVersion). Update Wonky Slides.',
        raw,
      );
    }
    while (version < currentThemeColumnVersion) {
      final step = steps[column]?[version];
      if (step == null) {
        throw DeckThemeMigrationException(
          column,
          'No migration of ${column.name} from version $version.',
          raw,
        );
      }
      out = step(out);
      version++;
    }
    out['v'] = currentThemeColumnVersion;
    return out;
  }
}
