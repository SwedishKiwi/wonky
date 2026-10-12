import 'package:serverpod/serverpod.dart';

/// Stable UUIDs of the built-in Write themes: UUIDv5 over the URL namespace
/// of `wonky-theme:<key>` (Write 06 §5.1).
abstract final class BuiltinThemeIds {
  static UuidValue forKey(String key) =>
      const Uuid().v5obj(Namespace.url.value, 'wonky-theme:$key');

  /// *Wonky Default*, the fallback of every user's default theme.
  static final UuidValue wonkyDefault = forKey('wonky-default');
}
