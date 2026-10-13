import 'package:flutter/foundation.dart';
import 'package:wonky_app/wonky_app.dart';

/// Storage for [EmojiPrefs]: the shell's per-user [LocalStore]
/// (`ShellServices.userStore`), or a `MemoryStore` in tests.
typedef EmojiPrefsStore = LocalStore;

/// Per-user emoji preferences (Write 04 §20.1): recently used emoji
/// (max [maxRecent], most recent first, de-duplicated) and the skin tone.
class EmojiPrefs extends ChangeNotifier {
  EmojiPrefs([this.store]);

  static const recentKey = 'write.emoji.recent';
  static const skinToneKey = 'write.emoji.skinTone';
  static const maxRecent = 24;

  /// Persistence; `null` keeps the preferences in memory only.
  final EmojiPrefsStore? store;

  List<String> _recent = const [];
  int _skinTone = 0;
  bool _loaded = false;

  bool get loaded => _loaded;

  /// Recently used emoji (exactly as inserted, including the skin tone).
  List<String> get recent => _recent;

  /// 0 = default, 1..5 = light..dark.
  int get skinTone => _skinTone;

  set skinTone(int tone) {
    final t = tone.clamp(0, 5);
    if (t == _skinTone) return;
    _skinTone = t;
    notifyListeners();
    store?.write(skinToneKey, t);
  }

  /// Reads the stored preferences; safe to call more than once.
  Future<void> load() async {
    final s = store;
    if (s != null) {
      final recent = await s.read(recentKey);
      final tone = await s.read(skinToneKey);
      if (recent is List) {
        final merged = <String>[
          ..._recent,
          for (final r in recent)
            if (r is String && r.isNotEmpty) r,
        ];
        _recent = List.unmodifiable(
          merged.toSet().take(maxRecent).toList(growable: false),
        );
      }
      if (tone is int && !_loaded) _skinTone = tone.clamp(0, 5);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Moves [char] to the front of [recent].
  void recordUse(String char) {
    if (char.isEmpty) return;
    _recent = List.unmodifiable(
      [char, ..._recent.where((c) => c != char)].take(maxRecent),
    );
    notifyListeners();
    store?.write(recentKey, _recent);
  }
}
