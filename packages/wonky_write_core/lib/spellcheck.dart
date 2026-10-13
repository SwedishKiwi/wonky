/// Pure-Dart, Hunspell-compatible spell checking for Wonky Write
/// (Write 04 §28.2): dictionary parsing (also incremental), checking,
/// suggestions and tokenization. Usable on the server, desktop and web.
library;

export 'src/spellcheck/hunspell.dart'
    show HunspellDictionary, HunspellDictionaryLoader, SpellChecker;
export 'src/spellcheck/tokenizer.dart' show SpellToken, SpellTokenizer;
