import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:wonky_app/spellcheck.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/find.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/ops.dart'
    show CellText, ElementText, NotesText, TextTarget;

import '../editor_screen/deck_editor_controller.dart';
import '../settings/slides_user_defaults.dart';

export 'package:wonky_app/spellcheck.dart' show SpellRange;

/// A misspelled word somewhere in the deck: a range of one text body
/// (element text, table cell or speaker notes; 03 §14).
@immutable
class SlidesSpellingIssue {
  const SlidesSpellingIssue({
    required this.slideId,
    required this.target,
    required this.start,
    required this.end,
    required this.word,
  });

  /// The slide the body is on (notes: their slide).
  final String slideId;

  /// The body: `ElementText`, `CellText` or `NotesText`.
  final TextTarget target;
  final int start;
  final int end;
  final String word;

  int get length => end - start;

  /// A key unique per body.
  String get bodyKey => DeckFind.bodyKey(target);

  /// The arguments of `slides.spelling.replace` that address this word.
  Map<String, Object?> targetArgs() => SlidesSpelling.argsOf(target);

  /// The agent view (MCP, `slides.spelling.check`).
  Map<String, Object?> toJson({List<String>? suggestions}) => {
    'slideId': slideId,
    ...targetArgs(),
    'start': start,
    'length': length,
    'word': word,
    'suggestions': ?suggestions,
  };

  @override
  bool operator ==(Object other) =>
      other is SlidesSpellingIssue &&
      other.bodyKey == bodyKey &&
      other.start == start &&
      other.word == word;

  @override
  int get hashCode => Object.hash(bodyKey, start, word);

  @override
  String toString() => 'SlidesSpellingIssue($bodyKey $word@$start)';
}

/// Where the spell checker stands.
enum SlidesSpellingState {
  /// The dictionary loads (on first need, 8 ms parse slices per frame).
  loading,

  /// Checking works.
  ready,

  /// No bundled dictionary fits the presentation language.
  noDictionary,
}

/// Spell checking of one open deck (Slides 03 §14): the suite's Hunspell
/// engine (`package:wonky_spellcheck` through the `wonky_app` glue) for the
/// **presentation language** (`Deck.language`, else the user's default
/// language for presentations, else the device locale), the user's synced
/// personal dictionary ([PersonalDictionary], shared with Write) and the
/// words ignored in this session.
///
/// Configuration is read lazily on every query (no listeners on the
/// long-lived shell services); listeners are told when results may have
/// changed (dictionary loaded, a word ignored or added) — the canvas
/// squiggles, the text overlay, the notes editor and the outline repaint.
///
/// Skipped like Write (04 §28.2): links and inline code, URLs, e-mail
/// addresses, words with digits, CamelCase, ALL-CAPS words and words under
/// two letters; the word at the caret while typing.
class SlidesSpelling extends ChangeNotifier implements DocumentSpellChecker {
  SlidesSpelling._(this.editor);

  /// The spelling of [editor] (created on first use).
  static SlidesSpelling of(DeckEditorController editor) =>
      _all[editor] ??= SlidesSpelling._(editor);

  /// The spelling of [editor] if it was used.
  static SlidesSpelling? maybeOf(DeckEditorController editor) => _all[editor];

  static final Expando<SlidesSpelling> _all = Expando('slidesSpelling');

  /// The dictionaries (tests install engines on their own instance).
  @visibleForTesting
  static SpellDictionaries? debugDictionaries;

  /// The language (tests: no device locale).
  @visibleForTesting
  static String? debugLocale;

  final DeckEditorController editor;

  SpellEngine? _engine;
  SlidesSpellingState _state = SlidesSpellingState.loading;
  String? _language;
  int _generation = 0;
  List<String> _personal = const [];
  final Set<String> _ignored = {};
  final Map<String, bool> _words = {};
  final LinkedHashMap<String, List<SpellRange>> _bodies = LinkedHashMap();
  int _revision = 0;
  bool _disposed = false;
  Completer<void>? _loaded;

  /// Bumps whenever results may have changed (painters compare it).
  int get revision {
    _sync();
    return _revision;
  }

  /// Whether misspellings are underlined (Tools › Spelling › Underline
  /// errors, `slidesDefaults.underlineSpelling`, default on).
  @override
  bool get underline => SlidesUserDefaults.of(
    editor.services,
  ).flag(SlidesUserDefaults.keyUnderlineSpelling);

  /// The presentation language (BCP 47): `Deck.language`, else the user's
  /// stored default for presentations, else the device locale.
  String get language {
    final deck = editor.model.deck?.language;
    if (deck != null && deck.isNotEmpty) return deck;
    final stored = editor
        .services
        .prefs
        .slidesDefaults[SlidesUserDefaults.keyDefaultLanguage];
    if (stored is String && stored.isNotEmpty) return stored;
    return debugLocale ?? PlatformDispatcher.instance.locale.toLanguageTag();
  }

  /// The state of the dictionary of [language].
  SlidesSpellingState get state {
    _sync();
    return _state;
  }

  /// Whether checking works now.
  bool get isReady => state == SlidesSpellingState.ready;

  /// The dictionary in use ("en-US"), or null.
  String? get dictionaryTag => _engine?.tag;

  /// Words ignored in this session (*Ignore*, *Ignore all*).
  Set<String> get ignoredWords => Set.unmodifiable(_ignored);

  /// The personal dictionary words.
  List<String> get personalWords =>
      PersonalDictionary.wordsOf(editor.services.prefs);

  /// Completes once the dictionary of [language] has loaded (or failed to)
  /// — at most after [timeout].
  Future<void> whenSettled({Duration timeout = const Duration(seconds: 15)}) {
    _sync();
    final c = _loaded;
    if (_state != SlidesSpellingState.loading || c == null) {
      return Future.value();
    }
    return c.future.timeout(timeout, onTimeout: () {});
  }

  void _sync() {
    if (_disposed) return;
    final lang = language;
    if (lang != _language) {
      _language = lang;
      _load(lang);
    }
    final words = personalWords;
    if (!listEquals(words, _personal)) {
      _personal = words;
      _engine?.setPersonalWords(words);
      _invalidate();
    }
  }

  void _load(String lang) {
    final generation = ++_generation;
    _engine = null;
    _state = SlidesSpellingState.loading;
    final done = _loaded = Completer<void>();
    _invalidate();
    final dictionaries = debugDictionaries ?? SpellDictionaries.instance;
    unawaited(
      dictionaries.engineFor(lang).then((engine) {
        if (generation != _generation || _disposed) return;
        if (engine == null) {
          _state = SlidesSpellingState.noDictionary;
        } else {
          _engine = engine..setPersonalWords(_personal);
          _state = SlidesSpellingState.ready;
        }
        _invalidate();
        if (!done.isCompleted) done.complete();
        notifyListeners();
      }),
    );
  }

  void _invalidate() {
    _revision++;
    _words.clear();
    _bodies.clear();
  }

  /// Tells listeners to repaint (the underline setting changed).
  void refresh() {
    _sync();
    _revision++;
    if (!_disposed) notifyListeners();
  }

  /// The misspelled words of [text] (plain text), skipping [skip] ranges
  /// and the word around [caret] (being typed).
  @override
  List<SpellRange> check(
    String text, {
    List<(int, int)> skip = const [],
    int? caret,
  }) {
    _sync();
    final engine = _engine;
    if (engine == null || text.isEmpty) return const [];
    final out = <SpellRange>[];
    for (final w in engine.words(text, skipRanges: skip)) {
      if (caret != null && caret >= w.start && caret <= w.end) continue;
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

  /// The misspelled words of a stored body (Delta JSON; offsets in its
  /// plain text), skipping links and inline code; cached per body.
  List<SpellRange> checkBody(String? json, {int? caret}) {
    if (json == null || json.isEmpty) return const [];
    _sync();
    if (_engine == null) return const [];
    if (caret != null) {
      return check(
        DeckFind.plainOf(json),
        skip: skipRangesOf(json),
        caret: caret,
      );
    }
    final hit = _bodies.remove(json);
    if (hit != null) return _bodies[json] = hit;
    final r = check(DeckFind.plainOf(json), skip: skipRangesOf(json));
    _bodies[json] = r;
    while (_bodies.length > 400) {
      _bodies.remove(_bodies.keys.first);
    }
    return r;
  }

  /// The plain-text ranges of [json] that are never checked: links and
  /// inline code.
  static List<(int, int)> skipRangesOf(String json) {
    final Delta d;
    try {
      d = SlidesText.parse(json);
    } on FormatException {
      return const [];
    }
    final out = <(int, int)>[];
    var at = 0;
    for (final op in d.operations) {
      final len = op.length ?? 0;
      final a = op.attributes;
      if (a != null && (a['link'] != null || a['code'] == true)) {
        out.add((at, at + len));
      }
      at += len;
    }
    return out;
  }

  /// Every misspelled word of the deck in presentation order: slide
  /// elements in reading order (groups expanded, table cells row by row),
  /// then the slide's speaker notes (the bodies of find and replace, 03
  /// §13 — skipped slides included).
  List<SlidesSpellingIssue> deckIssues() {
    _sync();
    if (_engine == null) return const [];
    final out = <SlidesSpellingIssue>[];
    for (final (slideId, target, json) in DeckFind.bodies(
      editor.model,
      const DeckFindOptions(),
    )) {
      for (final r in checkBody(json)) {
        out.add(
          SlidesSpellingIssue(
            slideId: slideId,
            target: target,
            start: r.start,
            end: r.end,
            word: r.word,
          ),
        );
      }
    }
    return out;
  }

  /// Up to [max] suggestions for [word], best first.
  List<String> suggestionsFor(String word, {int max = 5}) {
    _sync();
    return _engine?.suggest(word, max: max) ?? const [];
  }

  /// Whether [word] is spelled correctly (null without a dictionary).
  bool? isCorrect(String word) {
    _sync();
    final e = _engine;
    if (e == null) return null;
    return _ignored.contains(word) || e.check(word);
  }

  /// Stops flagging [word] in this session (*Ignore*, *Ignore all*).
  void ignore(String word) {
    if (!_ignored.add(word)) return;
    _invalidate();
    notifyListeners();
  }

  /// Adds [word] to the personal dictionary (synced, shared with Write);
  /// false when the dictionary is full.
  Future<bool> addToDictionary(String word) async {
    final ok = await PersonalDictionary.add(editor.services.prefs, word);
    if (!ok || _disposed) return ok;
    _sync();
    _invalidate();
    notifyListeners();
    return true;
  }

  /// Removes [word] from the personal dictionary.
  Future<void> removeFromDictionary(String word) async {
    await PersonalDictionary.remove(editor.services.prefs, word);
    if (_disposed) return;
    _sync();
    notifyListeners();
  }

  /// The `slides.spelling.replace` arguments of body [t].
  static Map<String, Object?> argsOf(TextTarget t) => switch (t) {
    ElementText(:final elementId) => {'elementId': elementId},
    CellText(:final elementId, :final rowId, :final columnId) => {
      'elementId': elementId,
      'rowId': rowId,
      'columnId': columnId,
    },
    NotesText(:final slideId) => {'notesSlideId': slideId},
  };

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_all[editor] == this) _all[editor] = null;
    super.dispose();
  }
}
