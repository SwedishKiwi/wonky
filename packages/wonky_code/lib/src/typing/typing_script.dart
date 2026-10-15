import 'dart:math' as math;

import '../code_tokenizer.dart';
import '../layout/code_columns.dart';
import 'code_edit_script.dart';
import 'typing_random.dart';
import 'typing_settings.dart';

/// Kind of a [TypingEvent].
enum TypingEventKind {
  /// The caret appears at [TypingEvent.start] (fades in over 150 ms).
  caretShow,

  /// The caret glides to [TypingEvent.start] over [TypingEvent.durationMs].
  caretTo,

  /// `[start, end)` gets selected; the selection grows over the duration.
  select,

  /// `[start, end)` is removed (one backspace, or the selection at once).
  delete,

  /// [TypingEvent.text] is typed at [TypingEvent.start] (one keystroke).
  insert,

  /// [TypingEvent.text] appears at [TypingEvent.start] as a paste (fades in
  /// over the duration; the caret jumps to its end).
  paste,

  /// The end: the caret is hidden, the text is the target state.
  end,
}

/// One event of a [TypingScript]. Offsets refer to the text **as it is when
/// the event happens** (after all earlier events).
final class TypingEvent {
  /// Creates an event.
  const TypingEvent(
    this.atMs,
    this.kind, {
    this.start = 0,
    this.end = 0,
    this.text = '',
    this.durationMs = 0,
  });

  /// When it happens (ms from the start of the transition).
  final int atMs;
  final TypingEventKind kind;
  final int start;
  final int end;
  final String text;
  final int durationMs;

  /// Whether it changes the text.
  bool get changesText =>
      kind == TypingEventKind.delete ||
      kind == TypingEventKind.insert ||
      kind == TypingEventKind.paste;

  @override
  bool operator ==(Object other) =>
      other is TypingEvent &&
      other.atMs == atMs &&
      other.kind == kind &&
      other.start == start &&
      other.end == end &&
      other.text == text &&
      other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(atMs, kind, start, end, text, durationMs);

  @override
  String toString() =>
      'TypingEvent($atMs ${kind.name} $start-$end "$text" ${durationMs}ms)';
}

/// Text being pasted, fading in.
final class TypingFade {
  const TypingFade(this.start, this.end, this.opacity);

  /// Offsets in the frame's text.
  final int start;
  final int end;

  /// 0..1.
  final double opacity;
}

/// What a code element shows at one moment of a typing transition.
final class TypingFrame {
  const TypingFrame({
    required this.text,
    required this.caret,
    this.caretFrom,
    this.caretGlide = 1,
    this.caretOpacity = 0,
    this.selectionStart,
    this.selectionEnd,
    this.fades = const [],
    this.done = false,
  });

  /// The current text.
  final String text;

  /// Caret offset (the glide target while gliding).
  final int caret;

  /// Where a running glide started (offset in [text]), or null.
  final int? caretFrom;

  /// Eased glide progress 0..1 (1 = at [caret]).
  final double caretGlide;

  /// 0..1 (fades in at the start, 0 after the end).
  final double caretOpacity;

  /// The (growing) selection, or null.
  final int? selectionStart;
  final int? selectionEnd;

  /// Pastes fading in.
  final List<TypingFade> fades;

  /// Whether the transition is over.
  final bool done;
}

/// The type-in animation from one code state to the next (Slides 07 §5.3):
/// a pure function of (from text, to text, settings, seed). The events are
/// scheduled in milliseconds; [stateAt] gives the frame at any moment, in
/// O(log n + 50) from a snapshot index (text and caret every 50 events).
final class TypingScript {
  TypingScript._(
    this.from,
    this.to,
    this.events,
    this.durationMs,
    this.textCompleteMs,
    this.scale,
    this._snapshots,
  );

  /// Caret fade-in at the start (ms).
  static const caretFadeMs = 150;

  /// The caret stays this long after the last keystroke (ms).
  static const caretHideMs = 600;

  /// Selection growth before a select-delete (ms, scaled).
  static const selectGrowMs = 200;

  /// Paste fade-in (ms).
  static const pasteFadeMs = 250;

  /// Shortest keystroke delay before scaling (ms).
  static const minKeystrokeMs = 15;

  /// Builds the script. [seed] is [typingSeed] of (element, target state);
  /// [script] may be passed when already computed (else it is computed with
  /// [language] / [tokenizer]).
  static TypingScript build(
    String from,
    String to, {
    TypingSettings settings = TypingSettings.defaults,
    int seed = 0,
    String language = '',
    CodeTokenizer? tokenizer,
    CodeEditScript? script,
  }) {
    final s =
        script ??
        CodeEditScript.compute(
          from,
          to,
          language: language,
          tokenizer: tokenizer,
        );
    final natural = _Simulation(from, s, settings, seed, 1, null).run();
    if (natural.duration <= settings.maxDurationMs || natural.scalable <= 0) {
      return natural.toScript(from, to, 1);
    }
    final fixed = natural.duration - natural.scalable;
    var factor = (settings.maxDurationMs - fixed) / natural.scalable;
    if (factor >= 0.1) {
      return _Simulation(
        from,
        s,
        settings,
        seed,
        factor,
        null,
      ).run().toScript(from, to, factor);
    }
    factor = 0.1;
    return _Simulation(
      from,
      s,
      settings,
      seed,
      factor,
      settings.maxDurationMs,
    ).run().toScript(from, to, factor);
  }

  /// The old text.
  final String from;

  /// The new text (the text at [durationMs]).
  final String to;

  /// Events in time order.
  final List<TypingEvent> events;

  /// Total duration incl. the caret's linger (ms).
  final int durationMs;

  /// When the text reaches [to] (ms).
  final int textCompleteMs;

  /// The factor delays were scaled by to fit `maxDurationMs` (1 = natural).
  final double scale;

  final List<_Snapshot> _snapshots;

  /// The text after all events (== [to]).
  String get finalText => to;

  /// The frame at [ms] (clamped to `[0, durationMs]`).
  TypingFrame stateAt(num ms) {
    final t = ms.clamp(0, durationMs).toDouble();
    if (t >= durationMs) {
      return TypingFrame(text: to, caret: _snapshots.last.caret, done: true);
    }
    // Last event at or before t.
    var lo = 0, hi = events.length - 1, last = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (events[mid].atMs <= t) {
        last = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // Nearest snapshot at or before last.
    var si = 0;
    var slo = 0, shi = _snapshots.length - 1;
    while (slo <= shi) {
      final mid = (slo + shi) >> 1;
      if (_snapshots[mid].after <= last) {
        si = mid;
        slo = mid + 1;
      } else {
        shi = mid - 1;
      }
    }
    final snap = _snapshots[si];
    var text = snap.text;
    var caret = snap.caret;
    int? selStart = snap.selStart, selEnd = snap.selEnd;
    TypingEvent? glide, select, paste, show;
    for (var k = snap.after + 1; k <= last; k++) {
      final e = events[k];
      switch (e.kind) {
        case TypingEventKind.caretShow:
          caret = e.start;
          show = e;
        case TypingEventKind.caretTo:
          glide = e;
          caret = e.start;
          selStart = selEnd = null;
        case TypingEventKind.select:
          select = e;
          selStart = e.start;
          selEnd = e.end;
          caret = e.end;
        case TypingEventKind.delete:
          text = text.substring(0, e.start) + text.substring(e.end);
          caret = e.start;
          selStart = selEnd = null;
          paste = null;
        case TypingEventKind.insert:
          text = text.substring(0, e.start) + e.text + text.substring(e.start);
          caret = e.start + e.text.length;
          selStart = selEnd = null;
          paste = null;
        case TypingEventKind.paste:
          text = text.substring(0, e.start) + e.text + text.substring(e.start);
          caret = e.start + e.text.length;
          selStart = selEnd = null;
          paste = e;
        case TypingEventKind.end:
          break;
      }
    }
    // Glides, growth and fades are only visible while they run; the
    // snapshot can't hold them because they end within 50 events at most
    // when the events are close — so look back for a running one.
    glide ??= _running(last, TypingEventKind.caretTo, t);
    select ??= _running(last, TypingEventKind.select, t);
    paste ??= _running(last, TypingEventKind.paste, t);
    show ??= _running(last, TypingEventKind.caretShow, t);

    int? caretFrom;
    var glideT = 1.0;
    if (glide != null &&
        t < glide.atMs + glide.durationMs &&
        glide.durationMs > 0) {
      caretFrom = glide.end;
      glideT = _easeInOut((t - glide.atMs) / glide.durationMs);
    }
    if (select != null &&
        selStart != null &&
        t < select.atMs + select.durationMs &&
        select.durationMs > 0) {
      final p = (t - select.atMs) / select.durationMs;
      selEnd = select.start + ((select.end - select.start) * p).round();
    }
    final fades = <TypingFade>[];
    if (paste != null &&
        t < paste.atMs + paste.durationMs &&
        paste.durationMs > 0) {
      fades.add(
        TypingFade(
          paste.start,
          paste.start + paste.text.length,
          ((t - paste.atMs) / paste.durationMs).clamp(0.0, 1.0),
        ),
      );
    }
    var opacity = 0.0;
    final firstShow =
        events.isEmpty || events.first.kind != TypingEventKind.caretShow
        ? null
        : events.first;
    if (firstShow != null && t >= firstShow.atMs) {
      opacity = ((t - firstShow.atMs) / caretFadeMs).clamp(0.0, 1.0);
    }
    return TypingFrame(
      text: text,
      caret: caret,
      caretFrom: caretFrom,
      caretGlide: glideT,
      caretOpacity: opacity,
      selectionStart: selStart,
      selectionEnd: selEnd,
      fades: fades,
    );
  }

  /// The latest event of [kind] at or before [last] still running at [t]
  /// (only the event just before a text change can be).
  TypingEvent? _running(int last, TypingEventKind kind, double t) {
    for (var k = last; k >= 0 && k > last - 4; k--) {
      final e = events[k];
      if (e.kind == kind) {
        return t < e.atMs + e.durationMs ? e : null;
      }
    }
    return null;
  }

  /// The text at [ms].
  String textAt(num ms) => stateAt(ms).text;

  /// Number of keystrokes (insert + delete events).
  int get keystrokes => events
      .where(
        (e) =>
            e.kind == TypingEventKind.insert ||
            e.kind == TypingEventKind.delete,
      )
      .length;

  static double _easeInOut(double x) {
    final t = x.clamp(0.0, 1.0);
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }
}

final class _Snapshot {
  const _Snapshot(
    this.after,
    this.text,
    this.caret,
    this.selStart,
    this.selEnd,
  );

  /// Index of the last event applied (−1 = before any).
  final int after;
  final String text;
  final int caret;
  final int? selStart;
  final int? selEnd;
}

final class _Result {
  _Result(
    this.events,
    this.duration,
    this.scalable,
    this.textDone,
    this.snapshots,
  );

  final List<TypingEvent> events;
  final int duration;

  /// Part of [duration] that scales (keystrokes, pauses, selection growth).
  final double scalable;
  final int textDone;
  final List<_Snapshot> snapshots;

  TypingScript toScript(String from, String to, double scale) =>
      TypingScript._(from, to, events, duration, textDone, scale, snapshots);
}

/// A gap buffer of UTF-16 code units (keystrokes near the caret are O(1)).
final class _GapBuffer {
  _GapBuffer(String text)
    : _buf = List<int>.filled(text.length + 64, 0),
      _gapStart = text.length,
      _gapEnd = text.length + 64 {
    for (var i = 0; i < text.length; i++) {
      _buf[i] = text.codeUnitAt(i);
    }
  }

  List<int> _buf;
  int _gapStart;
  int _gapEnd;

  int get length => _buf.length - (_gapEnd - _gapStart);

  void _moveGap(int pos) {
    if (pos < _gapStart) {
      final n = _gapStart - pos;
      _buf.setRange(_gapEnd - n, _gapEnd, _buf, pos);
      _gapStart -= n;
      _gapEnd -= n;
    } else if (pos > _gapStart) {
      final n = pos - _gapStart;
      _buf.setRange(_gapStart, _gapStart + n, _buf, _gapEnd);
      _gapStart += n;
      _gapEnd += n;
    }
  }

  void insert(int pos, String s) {
    _moveGap(pos);
    if (_gapEnd - _gapStart < s.length) {
      final grow = math.max(s.length, _buf.length) + 64;
      final next = List<int>.filled(_buf.length + grow, 0);
      next.setRange(0, _gapStart, _buf);
      final tail = _buf.length - _gapEnd;
      next.setRange(next.length - tail, next.length, _buf, _gapEnd);
      _gapEnd = next.length - tail;
      _buf = next;
    }
    for (var i = 0; i < s.length; i++) {
      _buf[_gapStart++] = s.codeUnitAt(i);
    }
  }

  void delete(int start, int end) {
    _moveGap(start);
    _gapEnd += end - start;
  }

  String substring(int start, int end) {
    final b = StringBuffer();
    for (var i = start; i < end; i++) {
      b.writeCharCode(_buf[i < _gapStart ? i : i + (_gapEnd - _gapStart)]);
    }
    return b.toString();
  }

  @override
  String toString() =>
      String.fromCharCodes(_buf, 0, _gapStart) +
      String.fromCharCodes(_buf, _gapEnd);
}

final class _Simulation {
  _Simulation(
    this.from,
    this.script,
    this.settings,
    int seed,
    this.factor,
    this.deadline,
  ) : random = TypingRandom(seed),
      buffer = _GapBuffer(from);

  final String from;
  final CodeEditScript script;
  final TypingSettings settings;
  final TypingRandom random;
  final double factor;

  /// With the minimum factor: insertions that would end after this become
  /// pastes.
  final int? deadline;
  final _GapBuffer buffer;

  final events = <TypingEvent>[];
  final snapshots = <_Snapshot>[];
  double t = 0;
  double scalable = 0;
  int caret = 0;
  int? selStart, selEnd;

  static const _punctuation = {';', ',', '.', ')', '}', ']'};

  void _emit(TypingEvent e) {
    events.add(e);
    if (events.length % 50 == 0) {
      snapshots.add(
        _Snapshot(
          events.length - 1,
          buffer.toString(),
          caret,
          selStart,
          selEnd,
        ),
      );
    }
  }

  /// Waits [ms] of scalable time.
  void _wait(double ms) {
    final d = ms * factor;
    t += d;
    scalable += d;
  }

  /// A jittered keystroke delay around [base] ms.
  double _keystroke(double base) {
    final u = random.nextDouble();
    final d = base * (1 + settings.jitter * (2 * u - 1));
    return math.max(TypingScript.minKeystrokeMs.toDouble(), d);
  }

  _Result run() {
    snapshots.add(_Snapshot(-1, from, 0, null, null));
    final edits = settings.order == TypingOrder.reverse
        ? script.edits.reversed.toList()
        : script.edits;
    var shift = 0;
    // Pending pause after a newline / punctuation (added to the next delay).
    var extra = 0.0;
    for (var k = 0; k < edits.length; k++) {
      final edit = edits[k];
      // Offset of the edit in the current text: in document order every
      // earlier edit shifted it; in reverse order none did.
      final start = edit.oldStart + shift;
      final end = edit.oldEnd + shift;
      final deleted = end - start;
      final graphemes = deleted == 0
          ? 0
          : CodeColumns.boundaries(buffer.substring(start, end)).length - 1;
      final backspace =
          deleted > 0 &&
          (settings.deleteMode == TypingDeleteMode.backspace ||
              (settings.deleteMode == TypingDeleteMode.auto &&
                  graphemes <= settings.backspaceMax));
      final target = backspace ? end : start;
      if (k == 0) {
        _wait(settings.pauses.beforeStart.toDouble());
        caret = target;
        _emit(
          TypingEvent(
            t.round(),
            TypingEventKind.caretShow,
            start: target,
            durationMs: TypingScript.caretFadeMs,
          ),
        );
      } else {
        final glide = settings.caretGlideMs;
        final previous = caret;
        caret = target;
        selStart = selEnd = null;
        _emit(
          TypingEvent(
            t.round(),
            TypingEventKind.caretTo,
            start: target,
            end: previous,
            durationMs: glide,
          ),
        );
        t += glide;
        _wait(settings.pauses.betweenEdits.toDouble());
      }
      extra = 0;
      // Delete part.
      if (deleted > 0) {
        if (backspace) {
          final text = buffer.substring(start, end);
          final bounds = CodeColumns.boundaries(text);
          for (var g = bounds.length - 1; g > 0; g--) {
            _wait(_keystroke(1000 / settings.deleteCps));
            final s = start + bounds[g - 1], e = start + bounds[g];
            buffer.delete(s, e);
            caret = s;
            _emit(
              TypingEvent(t.round(), TypingEventKind.delete, start: s, end: e),
            );
          }
        } else {
          selStart = start;
          selEnd = end;
          caret = end;
          _emit(
            TypingEvent(
              t.round(),
              TypingEventKind.select,
              start: start,
              end: end,
              durationMs: (TypingScript.selectGrowMs * factor).round(),
            ),
          );
          _wait(TypingScript.selectGrowMs.toDouble());
          _wait(_keystroke(1000 / settings.cps));
          buffer.delete(start, end);
          caret = start;
          selStart = selEnd = null;
          _emit(
            TypingEvent(
              t.round(),
              TypingEventKind.delete,
              start: start,
              end: end,
            ),
          );
        }
      }
      // Insert part.
      final text = edit.newText;
      if (text.isNotEmpty) {
        final lines = '\n'.allMatches(text).length + 1;
        var asPaste = lines >= settings.pasteLines;
        if (!asPaste && deadline != null) {
          final estimate = text.length * (1000 / settings.cps) * factor;
          asPaste = t + estimate > deadline!;
        }
        if (asPaste) {
          _wait(_keystroke(1000 / settings.cps));
          buffer.insert(start, text);
          caret = start + text.length;
          _emit(
            TypingEvent(
              t.round(),
              TypingEventKind.paste,
              start: start,
              text: text,
              durationMs: TypingScript.pasteFadeMs,
            ),
          );
          t += TypingScript.pasteFadeMs;
        } else {
          var p = start;
          var i = 0;
          while (i < text.length) {
            var j = CodeColumns.nextBoundary(text, i);
            if (settings.autoIndent && text.codeUnitAt(i) == 0x0A) {
              while (j < text.length &&
                  (text.codeUnitAt(j) == 0x20 || text.codeUnitAt(j) == 0x09)) {
                j++;
              }
            }
            final chunk = text.substring(i, j);
            _wait(_keystroke(1000 / settings.cps) + extra);
            extra = 0;
            buffer.insert(p, chunk);
            caret = p + chunk.length;
            _emit(
              TypingEvent(
                t.round(),
                TypingEventKind.insert,
                start: p,
                text: chunk,
              ),
            );
            p += chunk.length;
            if (chunk.startsWith('\n')) {
              extra = settings.pauses.lineEnd.toDouble();
            } else if (_punctuation.contains(chunk)) {
              extra = settings.pauses.punctuation.toDouble();
            }
            i = j;
          }
        }
      }
      if (settings.order == TypingOrder.document) shift += edit.delta;
    }
    final textDone = t.round();
    final duration = edits.isEmpty ? 0 : textDone + TypingScript.caretHideMs;
    events.add(TypingEvent(duration, TypingEventKind.end, start: caret));
    snapshots.add(
      _Snapshot(events.length - 1, buffer.toString(), caret, null, null),
    );
    return _Result(events, duration, scalable, textDone, snapshots);
  }
}
