/// Spell checking glue shared by the apps (Write 04 §28.2, Slides 03 §14,
/// v2 review Q23): the [SpellEngine] an editor checks with, the bundled
/// dictionaries loaded on first need ([SpellDictionaries], package assets of
/// `wonky_spellcheck`), and the Check spelling / Personal dictionary dialogs
/// over an app's [SpellingSession].
library;

export 'src/spellcheck/dictionaries.dart';
export 'src/spellcheck/hunspell_engine.dart' show createHunspellEngine;
export 'src/spellcheck/spell_engine.dart';
export 'src/spellcheck/spelling_dialogs.dart';
