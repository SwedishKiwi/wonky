/// Registry of the built-in themes (06 §9, §5.1).
library;

import 'package:uuid/uuid.dart';

import '../model/write_theme_data.dart';
import 'academic_apa.dart';
import 'classic_serif.dart';
import 'manuscript.dart';
import 'minimal_mono.dart';
import 'modern_sans.dart';
import 'newsletter.dart';
import 'technical.dart';
import 'wonky_default.dart';

/// A built-in theme.
final class BuiltinTheme {
  BuiltinTheme._(this.key, this.json);

  /// Stable key (`wonky-default`, `classic-serif`, …).
  final String key;

  /// Theme JSON.
  final Map<String, Object?> json;

  /// Stable UUID: UUIDv5 (URL namespace) of `wonky-theme:<key>`.
  late final String uuid = const Uuid().v5(
    Namespace.url.value,
    'wonky-theme:$key',
  );

  /// Parsed theme.
  late final WriteThemeData theme = WriteThemeData.fromJson(json);

  /// Display name.
  String get name => theme.name;
}

/// The 8 built-in themes.
abstract final class BuiltinThemes {
  /// Key of *Wonky Default* (fallback for users without a default).
  static const defaultKey = 'wonky-default';

  /// All built-ins in menu order.
  static final List<BuiltinTheme> all = List.unmodifiable([
    BuiltinTheme._('wonky-default', wonkyDefaultThemeJson),
    BuiltinTheme._('classic-serif', classicSerifThemeJson),
    BuiltinTheme._('modern-sans', modernSansThemeJson),
    BuiltinTheme._('academic-apa', academicApaThemeJson),
    BuiltinTheme._('technical', technicalThemeJson),
    BuiltinTheme._('manuscript', manuscriptThemeJson),
    BuiltinTheme._('minimal-mono', minimalMonoThemeJson),
    BuiltinTheme._('newsletter', newsletterThemeJson),
  ]);

  /// *Wonky Default*.
  static BuiltinTheme get wonkyDefault => all.first;

  /// By key.
  static BuiltinTheme? byKey(String key) =>
      all.where((t) => t.key == key).firstOrNull;

  /// By UUID.
  static BuiltinTheme? byUuid(String uuid) =>
      all.where((t) => t.uuid == uuid).firstOrNull;
}
