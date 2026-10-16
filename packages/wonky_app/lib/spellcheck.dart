/// Spell checking glue shared by the apps (Write 04 §28.2, Slides 03 §14,
/// v2 review Q23): the [SpellEngine] an editor checks with, the bundled
/// dictionaries loaded on first need ([SpellDictionaries], package assets of
/// `wonky_spellcheck`), the Check spelling / Personal dictionary dialogs
/// over an app's [SpellingSession], the shell's checker of the Markdown
/// composer ([ShellSpelling]) and the super_editor glue of
/// `wonky_rich_editor` ([DocumentSpelling] squiggles, the suggestions menu
/// [spellingMenuEntries]) that Slides uses too.
library;

export 'package:wonky_rich_editor/wonky_rich_editor.dart'
    show
        DocumentSpellChecker,
        DocumentSpelling,
        RichEditorSpellChecker,
        SpellRange,
        SpellingMenuLabels,
        spellingErrorColor,
        spellingMenuEntries;

export 'src/spellcheck/dictionaries.dart';
export 'src/spellcheck/hunspell_engine.dart' show createHunspellEngine;
export 'src/spellcheck/personal_dictionary.dart';
export 'src/spellcheck/shell_spelling.dart';
export 'src/spellcheck/spell_engine.dart';
export 'src/spellcheck/spelling_dialogs.dart';
