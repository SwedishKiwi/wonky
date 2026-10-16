import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_rich_editor/wonky_rich_editor.dart';

import '../core/preferences_controller.dart';
import 'dictionaries.dart';
import 'personal_dictionary.dart';
import 'spell_engine.dart';

/// The spell checker of the shell's Markdown composer (specs/16 §7.3): the
/// suite's Hunspell engine for the user's language, the synced personal
/// dictionary ([PersonalDictionary], shared with Write and Slides) and the
/// words ignored in this session (shared by every composer of the user).
///
/// Follows the user's spelling settings like Write (04 §28.2): off when
/// *Check spelling* is off (`writeDefaults.spellcheck`), ALL-CAPS words
/// skipped unless *Ignore words in UPPERCASE* is off
/// (`writeDefaults.spellcheckIgnoreUppercase`). The language is the
/// device's (browser) locale — the board, comments and prompts have no
/// document language. The dictionary loads on first need, only while
/// spelling is on.
class ShellSpelling extends ChangeNotifier implements RichEditorSpellChecker {
  ShellSpelling(this.prefs) {
    prefs.addListener(_onPrefs);
    _settings = _signature();
  }

  final PreferencesController prefs;

  /// The dictionaries (tests: `CommandTestHarness` installs an empty set,
  /// spelling tests their own engines).
  static SpellDictionaries? debugDictionaries;

  /// The language (tests: no device locale).
  @visibleForTesting
  static String? debugLocale;

  /// Ignored words per user session (the prefs controller is per session).
  static final Expando<Set<String>> _ignoredBy = Expando('shellSpelling');

  Set<String> get _ignored => _ignoredBy[prefs] ??= <String>{};

  SpellEngine? _engine;
  String? _language;
  int _generation = 0;
  bool _disposed = false;
  final Map<String, bool> _words = {};
  late String _settings;
  Completer<void>? _loaded;

  /// The language checked (BCP 47): the device locale.
  String get language =>
      debugLocale ?? PlatformDispatcher.instance.locale.toLanguageTag();

  @override
  bool get underline => prefs.writeDefaults['spellcheck'] as bool? ?? true;

  bool get _skipAllCaps =>
      prefs.writeDefaults['spellcheckIgnoreUppercase'] as bool? ?? true;

  /// Whether a dictionary is loaded.
  bool get isReady => _engine != null;

  /// Completes once the dictionary has loaded or failed to (tests).
  Future<void> whenSettled() {
    _sync();
    return _loaded?.future ?? Future.value();
  }

  String _signature() => [
    underline,
    _skipAllCaps,
    ...PersonalDictionary.wordsOf(prefs),
  ].join('\u0000');

  void _onPrefs() {
    final s = _signature();
    if (s == _settings) return;
    _settings = s;
    _words.clear();
    _engine?.setPersonalWords(PersonalDictionary.wordsOf(prefs));
    notifyListeners();
  }

  void _sync() {
    if (_disposed || !underline) return;
    final lang = language;
    if (lang == _language) return;
    _language = lang;
    final generation = ++_generation;
    _engine = null;
    _words.clear();
    final done = _loaded = Completer<void>();
    final dictionaries = debugDictionaries ?? SpellDictionaries.instance;
    unawaited(
      dictionaries.engineFor(lang).then((engine) {
        if (generation != _generation || _disposed) return;
        _engine = engine?..setPersonalWords(PersonalDictionary.wordsOf(prefs));
        if (!done.isCompleted) done.complete();
        notifyListeners();
      }),
    );
  }

  @override
  List<SpellRange> check(String text, {List<(int, int)> skip = const []}) {
    if (!underline) return const [];
    _sync();
    final engine = _engine;
    if (engine == null || text.isEmpty) return const [];
    final out = <SpellRange>[];
    for (final w in engine.words(
      text,
      skipRanges: skip,
      skipAllCaps: _skipAllCaps,
    )) {
      if (_ignored.contains(w.word)) continue;
      final key = w.followedByPeriod ? '${w.word}.' : w.word;
      final ok = _words[key] ??= engine.check(
        w.word,
        followedByPeriod: w.followedByPeriod,
      );
      if (_words.length > 20000) _words.clear();
      if (!ok) out.add(SpellRange(w.start, w.end, w.word));
    }
    return out;
  }

  @override
  List<String> suggestionsFor(String word, {int max = 5}) {
    _sync();
    return _engine?.suggest(word, max: max) ?? const [];
  }

  @override
  void ignore(String word) {
    if (!_ignored.add(word)) return;
    notifyListeners();
  }

  @override
  Future<bool> addToDictionary(String word) =>
      PersonalDictionary.add(prefs, word);

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    prefs.removeListener(_onPrefs);
    super.dispose();
  }
}
