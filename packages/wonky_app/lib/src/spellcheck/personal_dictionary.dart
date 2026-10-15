import '../core/preferences_controller.dart';

/// The user's personal spelling dictionary, synced with the user's
/// preferences and shared by the apps (Write 04 §28.2, Slides 03 §14): a
/// word added in one app is never flagged in any document. Stored as
/// `UserPreferences.writeDefaults.personalDictionary` (Write's key since
/// M1; Slides reads and writes the same list, SL-44).
abstract final class PersonalDictionary {
  /// The `writeDefaults` key of the word list.
  static const key = 'personalDictionary';

  /// The most words kept.
  static const maxWords = 10000;

  /// The words of [prefs]' user.
  static List<String> wordsOf(PreferencesController prefs) {
    final raw = prefs.writeDefaults[key];
    if (raw is! List) return const [];
    return [
      for (final w in raw)
        if (w is String && w.isNotEmpty) w,
    ];
  }

  /// Adds [word]; false when the dictionary is full ([maxWords]). Adding a
  /// word that is already there succeeds without a write.
  static Future<bool> add(PreferencesController prefs, String word) async {
    final words = wordsOf(prefs);
    if (words.contains(word)) return true;
    if (words.length >= maxWords) return false;
    await prefs.setWriteDefault(key, [...words, word]);
    return true;
  }

  /// Removes [word].
  static Future<void> remove(PreferencesController prefs, String word) async {
    final words = wordsOf(prefs);
    if (!words.contains(word)) return;
    await prefs.setWriteDefault(key, [
      for (final w in words)
        if (w != word) w,
    ]);
  }
}
