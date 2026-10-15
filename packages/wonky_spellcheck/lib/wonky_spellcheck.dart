/// Pure-Dart, Hunspell-compatible spell checking shared by the Wonky Work
/// apps (Write 04 §28.2, Slides 03 §14): dictionary parsing (also
/// incremental), checking, suggestions and tokenization. Usable on the
/// server, desktop and web. The Flutter glue (`SpellEngine`, dictionary
/// loading, spelling dialogs) is in `package:wonky_app/spellcheck.dart`.
library;

export 'src/hunspell.dart'
    show HunspellDictionary, HunspellDictionaryLoader, SpellChecker;
export 'src/tokenizer.dart' show SpellToken, SpellTokenizer;
export 'src/shipped_dictionaries.dart';
