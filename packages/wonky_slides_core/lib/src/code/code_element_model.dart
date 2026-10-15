/// The code element model (Slides 07 §3–§6, 12 §5.6): the element's
/// settings and its ordered states, with highlight steps, arrival settings,
/// callouts, typing scripts and morph plans.
library;

import 'dart:convert';

import 'package:wonky_code/wonky_code.dart';

import '../model/api/deck_reader.dart';
import '../model/api/records.dart';
import '../theme/json/json_util.dart';
import 'code_annotations.dart';
import 'code_element_data.dart';

/// One state of a code element (a `CodeState` row, 07 §3.2).
final class CodeStateModel {
  /// Creates a state.
  CodeStateModel({
    required this.id,
    required String code,
    required this.language,
    this.title,
    this.label,
    this.highlight,
    this.arrival = TypingSettings.defaults,
    this.annotations = CodeAnnotations.empty,
    this.startLine = 1,
  }) : code = code.replaceAll('\r\n', '\n') {
    lineCount = '\n'.allMatches(this.code).length + 1;
    steps = HighlightSteps.parse(
      highlight,
      lineCount: lineCount,
      startLine: startLine,
    );
  }

  /// From a `CodeState` record of an element with [data].
  factory CodeStateModel.fromRecord(CodeStateRec rec, CodeElementData data) {
    final language = rec.language;
    return CodeStateModel(
      id: rec.id,
      code: rec.code,
      language: language == null
          ? data.language
          : CodeLanguages.normalize(language),
      title: rec.title ?? data.title,
      label: rec.label,
      highlight: rec.highlight,
      arrival: TypingSettings.fromJson(
        _decode(rec.transitionJson),
        data.typing,
      ),
      annotations: CodeAnnotations.fromJson(_decode(rec.annotationsJson)),
      startLine: data.startLine,
    );
  }

  /// Row id (seeds the typing script into this state).
  final String id;

  /// The code (`\n` line breaks).
  final String code;

  /// Effective language (the state's override or the element's).
  final String language;

  /// Effective title (override or the element's), or null.
  final String? title;

  /// State-strip label.
  final String? label;

  /// The raw highlight-step string.
  final String? highlight;

  /// Parsed steps (with issues for the inspector).
  late final HighlightStepsResult steps;

  /// How the code arrives at this state (the state's `transitionJson` over
  /// the element's `typing`).
  final TypingSettings arrival;

  /// Callouts per step.
  final CodeAnnotations annotations;

  /// Displayed number of the first line (for `@` steps).
  final int startLine;

  /// Number of physical lines.
  late final int lineCount;

  /// Number of highlight steps.
  int get stepCount => steps.length;
}

/// A code element: its settings and states (07 §3), with the derived
/// animation data — typing scripts (§5.3), morph plans (§5.6) and
/// transition durations — cached per model. Build one per element revision
/// (`CodeElementModel.fromDeck`); scenes are composed by
/// `CodeSceneComposer` / `CodeElementLayout`.
final class CodeElementModel {
  /// Creates a model; [states] must not be empty (an element has ≥ 1 state;
  /// an empty list is treated as one empty state).
  CodeElementModel({
    required this.elementId,
    required this.data,
    required List<CodeStateModel> states,
    CodeTokenizer? tokenizer,
  }) : states = states.isEmpty
           ? [CodeStateModel(id: '', code: '', language: data.language)]
           : List.unmodifiable(states),
       tokenizer = tokenizer ?? CachedCodeTokenizer.shared;

  /// The model of element [elementId] with [dataJson] and its [records] in
  /// order.
  factory CodeElementModel.fromRecords(
    String elementId,
    Object? dataJson,
    List<CodeStateRec> records, {
    CodeTokenizer? tokenizer,
  }) {
    final data = CodeElementData.fromJson(dataJson);
    return CodeElementModel(
      elementId: elementId,
      data: data,
      states: [for (final r in records) CodeStateModel.fromRecord(r, data)],
      tokenizer: tokenizer,
    );
  }

  /// The model of [elementId] in [deck] ([dataJson] = the element's
  /// decoded `dataJson`).
  factory CodeElementModel.fromDeck(
    DeckReader deck,
    String elementId,
    JsonMap? dataJson, {
    CodeTokenizer? tokenizer,
  }) => CodeElementModel.fromRecords(
    elementId,
    dataJson,
    deck.codeStatesOf(elementId),
    tokenizer: tokenizer,
  );

  /// The element id (seeds the typing scripts).
  final String elementId;

  /// The element settings.
  final CodeElementData data;

  /// The states in order (≥ 1).
  final List<CodeStateModel> states;

  /// Tokenizer of every derived structure (default: the shared cache over
  /// `DefaultCodeTokenizer`).
  final CodeTokenizer tokenizer;

  final _typing = <(int, int), TypingScript>{};
  final _morph = <Object, TokenMorphPlan>{};

  /// Crossfade duration of `instant` and reduced motion (07 §5.1, §5.9).
  static const instantMs = 200;

  /// Number of states.
  int get stateCount => states.length;

  /// State [index] (clamped).
  CodeStateModel state(int index) => states[index.clamp(0, states.length - 1)];

  /// Tokens of [state] (empty for plain text).
  List<CodeToken> tokensOf(int state) {
    final s = this.state(state);
    return tokensFor(s.code, s.language);
  }

  /// Tokens of [code] in [language].
  List<CodeToken> tokensFor(String code, String language) =>
      language.isEmpty || !tokenizer.supports(language)
      ? const []
      : tokenizer.tokenize(code, language);

  /// The highlight step [step] (0-based) of [state], or null.
  HighlightStep? stepOf(int state, int? step) =>
      step == null ? null : this.state(state).steps[step];

  /// The step shown when [state] has just arrived (`highlightOnArrive`:
  /// step 1 if the state has steps), or null.
  int? arrivalStep(int state) {
    final s = this.state(state);
    return s.arrival.highlightOnArrive && s.stepCount > 0 ? 0 : null;
  }

  /// The mode of a change from [from] to [to] (07 §5.1, §6): the target
  /// state's arrival mode, [override] (a build's `mode`) when given, `instant`
  /// for backward jumps without an override and with [reducedMotion].
  CodeTransitionMode modeOf(
    int from,
    int to, {
    CodeTransitionMode? override,
    bool reducedMotion = false,
  }) {
    if (reducedMotion) return CodeTransitionMode.instant;
    if (override != null) return override;
    if (to < from) return CodeTransitionMode.instant;
    return state(to).arrival.mode;
  }

  /// The typing script from state [from] (−1 = empty: the `codeType`
  /// in-build) to state [to], cached.
  TypingScript typingScript(int from, int to) {
    final key = (from, to.clamp(0, states.length - 1));
    return _typing[key] ??= () {
      final target = state(to);
      final source = from < 0 ? '' : state(from).code;
      final settings = from < 0 ? state(0).arrival : target.arrival;
      return TypingScript.build(
        source,
        target.code,
        settings: settings,
        seed: typingSeed(elementId, target.id),
        script: CodeEditScript.compute(
          source,
          target.code,
          fromTokens: tokensFor(source, target.language),
          toTokens: tokensFor(target.code, target.language),
        ),
      );
    }();
  }

  /// The morph plan from [from] to [to] with the given layouts (cached per
  /// layout geometry).
  TokenMorphPlan morphPlan(
    int from,
    int to,
    CodeLayout fromLayout,
    CodeLayout toLayout,
  ) {
    final key = (
      from,
      to,
      fromLayout.options.fontSize,
      toLayout.options.fontSize,
      fromLayout.options.wrapColumns,
      toLayout.options.wrapColumns,
    );
    return _morph[key] ??= () {
      final a = state(from), b = state(to);
      return TokenMorphPlan.build(
        a.code,
        b.code,
        fromTokens: tokensFor(a.code, a.language),
        toTokens: tokensFor(b.code, b.language),
        fromLayout: fromLayout,
        toLayout: toLayout,
        durationMs: b.arrival.morphDurationMs,
        staggerMs: b.arrival.morphStaggerMs,
      );
    }();
  }

  /// Duration of the change from [from] to [to] (ms; 07 §5.3: derived in
  /// `type` mode, the build's own duration is ignored).
  int transitionDurationMs(
    int from,
    int to, {
    CodeTransitionMode? override,
    bool reducedMotion = false,
  }) {
    final mode = modeOf(
      from,
      to,
      override: override,
      reducedMotion: reducedMotion,
    );
    return switch (mode) {
      CodeTransitionMode.instant => instantMs,
      CodeTransitionMode.type => typingScript(from, to).durationMs,
      CodeTransitionMode.morph => () {
        final target = state(to).arrival;
        final rows = state(from).lineCount > state(to).lineCount
            ? state(from).lineCount
            : state(to).lineCount;
        return target.morphDurationMs +
            target.morphStaggerMs * (rows - 1).clamp(0, 1 << 20);
      }(),
    };
  }

  /// Duration of the `codeType` in-build (type state 1 from empty).
  int typeInDurationMs({bool reducedMotion = false}) =>
      reducedMotion ? instantMs : typingScript(-1, 0).durationMs;

  /// The state-strip line counts of [state] against the previous state
  /// ("+3 −1 vs. state 1"), or null for the first.
  CodeDiffStats? diffStats(int state) {
    if (state <= 0 || state >= states.length) return null;
    return CodeEditScript.compute(
      states[state - 1].code,
      states[state].code,
    ).stats;
  }

  /// Every state's code (auto size across states).
  List<String> get codes => [for (final s in states) s.code];

  /// Accessibility label (07 §13): "Code block, Dart, 24 lines, title
  /// lib/main.dart".
  String semanticsLabel(int state) {
    final s = this.state(state);
    final lang = s.language.isEmpty
        ? 'Plain text'
        : CodeLanguages.displayName(s.language);
    final lines = '${s.lineCount} ${s.lineCount == 1 ? 'line' : 'lines'}';
    return [
      'Code block',
      lang,
      lines,
      if (s.title != null) 'title ${s.title}',
    ].join(', ');
  }
}

Object? _decode(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    return jsonDecode(json);
  } on FormatException {
    return null;
  }
}
