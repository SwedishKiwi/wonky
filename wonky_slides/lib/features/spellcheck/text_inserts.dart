import 'package:wonky_app/emoji.dart';
import 'package:wonky_app/wonky_app.dart';

import '../editor_screen/deck_editor_controller.dart';
import '../text_editing/text_editing_host.dart';

/// The emoji picker's recents and skin tone of [s]' user (per-user store;
/// the `write.emoji.*` keys, so the recents are shared with Write).
EmojiPrefs slidesEmojiPrefs(ShellServices s) {
  final store = s.userStore;
  final cached = _prefs[store];
  if (cached != null) return cached;
  return _prefs[store] = EmojiPrefs(store);
}

final Expando<EmojiPrefs> _prefs = Expando('slidesEmojiPrefs');

/// Whether a text body is being edited on the canvas (where Insert ›
/// Emoji and Special characters type into the text, 03 §6.7, §14).
bool isEditingText(DeckEditorController ed) => textEditingOf(ed).isEditing;

/// Types [text] at the caret of the body being edited on the canvas
/// (replacing a selection, with the typing attributes) and writes it at
/// once — one "Typing" step, like typed characters (03 §15). Returns
/// whether a body was being edited.
bool insertIntoEditedText(DeckEditorController ed, String text) {
  final host = textEditingOf(ed);
  final c = host.active;
  if (c == null || text.isEmpty) return false;
  host.commit();
  c.insertText(text);
  c.commit();
  host.editorFocus.requestFocus();
  return true;
}
