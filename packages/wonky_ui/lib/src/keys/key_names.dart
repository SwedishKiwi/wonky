import 'package:flutter/services.dart';

/// Canonical key names shared with `wonky_core`'s `KeyBinding` (`A`, `7`,
/// `/`, `Enter`, `ArrowUp`, `F2` …), mapped to and from Flutter logical keys.
abstract final class WonkyKeyNames {
  static final Map<LogicalKeyboardKey, String> _named = {
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.numpadEnter: 'Enter',
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.insert: 'Insert',
    LogicalKeyboardKey.arrowUp: 'ArrowUp',
    LogicalKeyboardKey.arrowDown: 'ArrowDown',
    LogicalKeyboardKey.arrowLeft: 'ArrowLeft',
    LogicalKeyboardKey.arrowRight: 'ArrowRight',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.f1: 'F1',
    LogicalKeyboardKey.f2: 'F2',
    LogicalKeyboardKey.f3: 'F3',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f6: 'F6',
    LogicalKeyboardKey.f7: 'F7',
    LogicalKeyboardKey.f8: 'F8',
    LogicalKeyboardKey.f9: 'F9',
    LogicalKeyboardKey.f10: 'F10',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };

  static final Map<String, LogicalKeyboardKey> _byName = {
    for (final e in _named.entries)
      if (e.key != LogicalKeyboardKey.numpadEnter) e.value: e.key,
  };

  static final Map<String, LogicalKeyboardKey> _printable = {
    for (final k in [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
      LogicalKeyboardKey.keyG,
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyI,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyM,
      LogicalKeyboardKey.keyN,
      LogicalKeyboardKey.keyO,
      LogicalKeyboardKey.keyP,
      LogicalKeyboardKey.keyQ,
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyT,
      LogicalKeyboardKey.keyU,
      LogicalKeyboardKey.keyV,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyX,
      LogicalKeyboardKey.keyY,
      LogicalKeyboardKey.keyZ,
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
      LogicalKeyboardKey.slash,
      LogicalKeyboardKey.backslash,
      LogicalKeyboardKey.period,
      LogicalKeyboardKey.comma,
      LogicalKeyboardKey.semicolon,
      LogicalKeyboardKey.quote,
      LogicalKeyboardKey.bracketLeft,
      LogicalKeyboardKey.bracketRight,
      LogicalKeyboardKey.minus,
      LogicalKeyboardKey.equal,
      LogicalKeyboardKey.backquote,
    ])
      k.keyLabel.toUpperCase(): k,
  };

  /// Modifier keys (never a chord's main key).
  static final Set<LogicalKeyboardKey> modifiers = {
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.fn,
  };

  /// The canonical name of [key], or null for unsupported keys.
  static String? nameOf(LogicalKeyboardKey key) {
    if (modifiers.contains(key)) return null;
    final named = _named[key];
    if (named != null) return named;
    final label = key.keyLabel;
    if (label.length == 1) {
      final up = label.toUpperCase();
      if (_printable.containsKey(up)) return up;
    }
    return null;
  }

  /// The logical key for a canonical [name] (null when unknown).
  static LogicalKeyboardKey? keyOf(String name) =>
      _byName[name] ?? _printable[name.toUpperCase()];
}

/// A chord captured by `KeyboardShortcutRecorder` (concrete modifiers).
class RecordedChord {
  const RecordedChord({
    required this.key,
    this.control = false,
    this.meta = false,
    this.alt = false,
    this.shift = false,
  });

  /// Canonical key name (see [WonkyKeyNames]).
  final String key;
  final bool control;
  final bool meta;
  final bool alt;
  final bool shift;

  @override
  bool operator ==(Object other) =>
      other is RecordedChord &&
      other.key == key &&
      other.control == control &&
      other.meta == meta &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(key, control, meta, alt, shift);

  @override
  String toString() => [
    if (control) 'Ctrl',
    if (meta) 'Meta',
    if (alt) 'Alt',
    if (shift) 'Shift',
    key,
  ].join('+');
}
