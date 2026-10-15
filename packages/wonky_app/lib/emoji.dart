/// The emoji picker shared by the apps (Write 04 §20.1, v2 review Q23): the
/// bundled emoji table ([EmojiCatalog], package asset
/// `assets/emoji/emoji.json`), per-user recents and skin tone
/// ([EmojiPrefs]), the picker widget, its dialog/popover and the inline
/// `:shortcode` suggestion list.
library;

export 'src/emoji/emoji_catalog.dart';
export 'src/emoji/emoji_picker.dart';
export 'src/emoji/emoji_prefs.dart';
