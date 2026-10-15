/// How a code state arrives from the previous one (Slides 07 §5.1).
enum CodeTransitionMode {
  /// Typed with a caret (default).
  type,

  /// Tokens glide to their new positions.
  morph,

  /// Crossfade (200 ms).
  instant;

  /// Parses a JSON value (unknown → null).
  static CodeTransitionMode? fromName(Object? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// How deletions are animated (Slides 07 §5.3).
enum TypingDeleteMode {
  /// Backspace short deletions, select + delete long ones.
  auto,

  /// Always backspace.
  backspace,

  /// Always select, then delete at once.
  select;

  static TypingDeleteMode? fromName(Object? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// The order the edits are visited in.
enum TypingOrder {
  /// Top to bottom.
  document,

  /// Bottom to top.
  reverse;

  static TypingOrder? fromName(Object? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Caret shape while typing.
enum TypingCaret {
  bar,
  block,
  underline;

  static TypingCaret? fromName(Object? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// Pauses of the typing simulation (ms).
final class TypingPauses {
  /// Creates pauses.
  const TypingPauses({
    this.lineEnd = 160,
    this.punctuation = 60,
    this.betweenEdits = 300,
    this.beforeStart = 200,
  });

  /// After a typed newline.
  final int lineEnd;

  /// After `; , . ) } ]`.
  final int punctuation;

  /// Between two edits (not before the first).
  final int betweenEdits;

  /// Before the caret appears.
  final int beforeStart;

  Map<String, Object?> toJson() => {
    'lineEnd': lineEnd,
    'punctuation': punctuation,
    'betweenEdits': betweenEdits,
    'beforeStart': beforeStart,
  };

  /// [json] over [base] (missing or invalid keys keep [base]'s values).
  static TypingPauses fromJson(
    Object? json, [
    TypingPauses base = const TypingPauses(),
  ]) {
    if (json is! Map) return base;
    int pick(String key, int fallback) => _int(json[key], 0, 10000) ?? fallback;
    return TypingPauses(
      lineEnd: pick('lineEnd', base.lineEnd),
      punctuation: pick('punctuation', base.punctuation),
      betweenEdits: pick('betweenEdits', base.betweenEdits),
      beforeStart: pick('beforeStart', base.beforeStart),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TypingPauses &&
      other.lineEnd == lineEnd &&
      other.punctuation == punctuation &&
      other.betweenEdits == betweenEdits &&
      other.beforeStart == beforeStart;

  @override
  int get hashCode =>
      Object.hash(lineEnd, punctuation, betweenEdits, beforeStart);
}

/// Typing settings (Slides 07 §5.3): `CodeState.transitionJson` overrides
/// the element's `dataJson.typing` defaults.
final class TypingSettings {
  /// Creates settings (the 07 §5.3 defaults).
  const TypingSettings({
    this.mode = CodeTransitionMode.type,
    this.cps = 28,
    this.deleteMode = TypingDeleteMode.auto,
    this.backspaceMax = 12,
    this.deleteCps = 60,
    this.jitter = 0.35,
    this.pauses = const TypingPauses(),
    this.caretGlideMs = 180,
    this.order = TypingOrder.document,
    this.pasteLines = 12,
    this.autoIndent = true,
    this.maxDurationMs = 10000,
    this.scrollFollow = true,
    this.highlightOnArrive = true,
    this.caret = TypingCaret.bar,
    this.sound = false,
    this.morphDurationMs = 800,
    this.morphStaggerMs = 0,
    this.crossSlideMode = CodeTransitionMode.morph,
  });

  /// The defaults.
  static const defaults = TypingSettings();

  final CodeTransitionMode mode;

  /// Typed graphemes per second (5–200).
  final double cps;
  final TypingDeleteMode deleteMode;

  /// `auto`: deletions up to this many graphemes are backspaced.
  final int backspaceMax;

  /// Backspaces per second.
  final double deleteCps;

  /// 0–1: per-keystroke delay varies ± jitter × base (seeded).
  final double jitter;
  final TypingPauses pauses;

  /// Caret glide to the next edit (0 = jump).
  final int caretGlideMs;
  final TypingOrder order;

  /// Insertions with at least this many lines appear as a paste.
  final int pasteLines;

  /// New lines get their leading whitespace in the newline's keystroke.
  final bool autoIndent;

  /// Longer natural durations are sped up to fit.
  final int maxDurationMs;

  /// The viewport follows the caret (07 §5.5; applied by the renderer).
  final bool scrollFollow;

  /// The target state's step 1 is applied at the end (renderer/timeline).
  final bool highlightOnArrive;
  final TypingCaret caret;

  /// P2: key clicks in present mode.
  final bool sound;

  /// Morph mode duration (07 §5.6, default 800 ms).
  final int morphDurationMs;

  /// Morph stagger per line (ms).
  final int morphStaggerMs;

  /// Element default for Magic Move between slides (07 §5.7).
  final CodeTransitionMode crossSlideMode;

  /// The JSON form (07 §5.3 keys; morph keys `morphMs`, `stagger`).
  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'cps': _num(cps),
    'deleteMode': deleteMode.name,
    'backspaceMax': backspaceMax,
    'deleteCps': _num(deleteCps),
    'jitter': _num(jitter),
    'pauses': pauses.toJson(),
    'caretGlideMs': caretGlideMs,
    'order': order.name,
    'pasteLines': pasteLines,
    'autoIndent': autoIndent,
    'maxDurationMs': maxDurationMs,
    'scrollFollow': scrollFollow,
    'highlightOnArrive': highlightOnArrive,
    'caret': caret.name,
    'sound': sound,
    'morphMs': morphDurationMs,
    'stagger': morphStaggerMs,
    'crossSlideMode': crossSlideMode.name,
  };

  /// [json] over [base]: present, valid keys override; invalid values are
  /// ignored (clamped where a range is defined).
  static TypingSettings fromJson(
    Object? json, [
    TypingSettings base = defaults,
  ]) {
    if (json is! Map) return base;
    return TypingSettings(
      mode: CodeTransitionMode.fromName(json['mode']) ?? base.mode,
      cps: _double(json['cps'], 5, 200) ?? base.cps,
      deleteMode:
          TypingDeleteMode.fromName(json['deleteMode']) ?? base.deleteMode,
      backspaceMax: _int(json['backspaceMax'], 0, 10000) ?? base.backspaceMax,
      deleteCps: _double(json['deleteCps'], 5, 400) ?? base.deleteCps,
      jitter: _double(json['jitter'], 0, 1) ?? base.jitter,
      pauses: TypingPauses.fromJson(json['pauses'], base.pauses),
      caretGlideMs: _int(json['caretGlideMs'], 0, 5000) ?? base.caretGlideMs,
      order: TypingOrder.fromName(json['order']) ?? base.order,
      pasteLines: _int(json['pasteLines'], 1, 100000) ?? base.pasteLines,
      autoIndent: _bool(json['autoIndent']) ?? base.autoIndent,
      maxDurationMs:
          _int(json['maxDurationMs'], 200, 600000) ?? base.maxDurationMs,
      scrollFollow: _bool(json['scrollFollow']) ?? base.scrollFollow,
      highlightOnArrive:
          _bool(json['highlightOnArrive']) ?? base.highlightOnArrive,
      caret: TypingCaret.fromName(json['caret']) ?? base.caret,
      sound: _bool(json['sound']) ?? base.sound,
      morphDurationMs: _int(json['morphMs'], 0, 60000) ?? base.morphDurationMs,
      morphStaggerMs: _int(json['stagger'], 0, 5000) ?? base.morphStaggerMs,
      crossSlideMode:
          CodeTransitionMode.fromName(json['crossSlideMode']) ??
          base.crossSlideMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TypingSettings &&
      other.mode == mode &&
      other.cps == cps &&
      other.deleteMode == deleteMode &&
      other.backspaceMax == backspaceMax &&
      other.deleteCps == deleteCps &&
      other.jitter == jitter &&
      other.pauses == pauses &&
      other.caretGlideMs == caretGlideMs &&
      other.order == order &&
      other.pasteLines == pasteLines &&
      other.autoIndent == autoIndent &&
      other.maxDurationMs == maxDurationMs &&
      other.scrollFollow == scrollFollow &&
      other.highlightOnArrive == highlightOnArrive &&
      other.caret == caret &&
      other.sound == sound &&
      other.morphDurationMs == morphDurationMs &&
      other.morphStaggerMs == morphStaggerMs &&
      other.crossSlideMode == crossSlideMode;

  @override
  int get hashCode => Object.hashAll([
    mode,
    cps,
    deleteMode,
    backspaceMax,
    deleteCps,
    jitter,
    pauses,
    caretGlideMs,
    order,
    pasteLines,
    autoIndent,
    maxDurationMs,
    scrollFollow,
    highlightOnArrive,
    caret,
    sound,
    morphDurationMs,
    morphStaggerMs,
    crossSlideMode,
  ]);
}

Object _num(double v) => v == v.roundToDouble() ? v.toInt() : v;

double? _double(Object? v, double min, double max) =>
    v is num && v.isFinite ? v.toDouble().clamp(min, max) : null;

int? _int(Object? v, int min, int max) =>
    v is num && v.isFinite ? v.round().clamp(min, max) : null;

bool? _bool(Object? v) => v is bool ? v : null;
