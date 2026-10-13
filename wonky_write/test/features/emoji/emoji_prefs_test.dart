import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_write/features/emoji/emoji_prefs.dart';

void main() {
  group('Given emoji prefs on an empty store', () {
    late MemoryStore store;
    late EmojiPrefs prefs;
    setUp(() async {
      store = MemoryStore();
      prefs = EmojiPrefs(store);
      await prefs.load();
    });

    test('when recording uses then the most recent comes first, '
        'de-duplicated', () {
      prefs
        ..recordUse('😀')
        ..recordUse('👍')
        ..recordUse('😀');

      expect(prefs.recent, ['😀', '👍']);
    });

    test('when recording more than 24 then the oldest are dropped', () {
      for (var i = 0; i < 30; i++) {
        prefs.recordUse(String.fromCharCode(0x1F600 + i));
      }

      expect(prefs.recent, hasLength(24));
      expect(prefs.recent.first, String.fromCharCode(0x1F600 + 29));
    });

    test('when recording and setting the tone then a new instance loads '
        'them', () async {
      prefs
        ..recordUse('👋🏽')
        ..skinTone = 3;

      final again = EmojiPrefs(store);
      await again.load();

      expect(again.recent, ['👋🏽']);
      expect(again.skinTone, 3);
    });

    test('when setting an out-of-range tone then it is clamped', () {
      prefs.skinTone = 9;

      expect(prefs.skinTone, 5);
    });
  });
}
