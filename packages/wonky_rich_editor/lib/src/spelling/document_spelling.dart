/// Spelling squiggles of a super_editor document, shared by Slides (canvas
/// text and speaker notes, Slides 03 §14) and [WonkyRichEditor] (the
/// suite's Markdown composer, specs/16 §7.3). The engine and the language
/// are the host's ([DocumentSpellChecker]); this package only knows
/// documents.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// The squiggle color of misspelled words (Slides' canvas token
/// `spellingError`, 03 A-03-7): the same red on light and dark.
const spellingErrorColor = Color(0xFFDC2626);

/// A misspelled word of one text, with UTF-16 offsets `[start, end)` in the
/// text's plain text.
@immutable
class SpellRange {
  const SpellRange(this.start, this.end, this.word);

  final int start;
  final int end;
  final String word;

  int get length => end - start;

  /// Whether [offset] is inside the word or at its end.
  bool covers(int offset) => offset >= start && offset <= end;

  @override
  bool operator ==(Object other) =>
      other is SpellRange &&
      other.start == start &&
      other.end == end &&
      other.word == word;

  @override
  int get hashCode => Object.hash(start, end, word);

  @override
  String toString() => 'SpellRange($word $start..$end)';
}

/// What [DocumentSpelling] checks with: the host's engine for its language,
/// personal dictionary and ignored words. Listeners are told when results
/// may have changed (dictionary loaded, a word ignored or added, the
/// setting switched).
abstract interface class DocumentSpellChecker implements Listenable {
  /// Whether misspellings are underlined at all (the user's setting).
  bool get underline;

  /// The misspelled words of [text] (plain text), skipping [skip] ranges.
  List<SpellRange> check(String text, {List<(int, int)> skip});
}

/// A [DocumentSpellChecker] that also serves the suggestions menu of a
/// misspelled word (replace, *Ignore*, *Add to dictionary*).
abstract interface class RichEditorSpellChecker
    implements DocumentSpellChecker {
  /// Up to [max] suggestions for [word], best first.
  List<String> suggestionsFor(String word, {int max});

  /// Stops flagging [word] (this session).
  void ignore(String word);

  /// Adds [word] to the personal dictionary; false when it is full.
  Future<bool> addToDictionary(String word);
}

/// Spelling squiggles of one super_editor [document] (Slides 03 §14).
///
/// Changed paragraphs are checked after the frame that changed them (they
/// are short); a misspelled word at the caret is not flagged while it is
/// being typed, and is once the caret leaves it (moving the caret into an
/// already flagged word keeps it flagged, for its context menu). Results go
/// to a [SpellingAndGrammarStyler] ([stylePhase]) — presentation only,
/// never in the document. With [DocumentSpellChecker.underline] off nothing
/// is underlined. Links and inline code are never checked.
class DocumentSpelling {
  DocumentSpelling({
    required this.document,
    required this.composer,
    required this.checker,
    this.checks,
  }) {
    document.addListener(_onDocument);
    composer.selectionNotifier.addListener(_onSelection);
    checker.addListener(_recheckAll);
    _recheckAll();
  }

  final MutableDocument document;
  final MutableDocumentComposer composer;
  final DocumentSpellChecker checker;

  /// Which text nodes are checked (null: all; the Markdown editor skips
  /// code and literal blocks).
  final bool Function(TextNode node)? checks;

  /// The underline layer (an extra style phase of the editor).
  final SpellingAndGrammarStyler styler = SpellingAndGrammarStyler(
    spellingErrorUnderlineStyle: const SquiggleUnderlineStyle(
      color: spellingErrorColor,
    ),
  );

  /// [styler] as the editor's extra style phase.
  SingleColumnLayoutStylePhase get stylePhase => styler;

  final Map<String, List<SpellRange>> _errors = {};
  final Set<String> _dirty = {};

  /// Paragraphs changed by typing (the word at the caret is held back).
  final Set<String> _typed = {};

  /// The word held back per paragraph (being typed).
  final Map<String, SpellRange> _held = {};
  bool _scheduled = false;
  bool _disposed = false;

  /// The misspelled words of node [nodeId] (node text offsets).
  List<SpellRange> errorsOf(String nodeId) => _errors[nodeId] ?? const [];

  /// The misspelled word at [position] (inside it or at its end), or null.
  SpellRange? errorAt(DocumentPosition position) {
    final p = position.nodePosition;
    if (p is! TextNodePosition) return null;
    for (final r in errorsOf(position.nodeId)) {
      if (r.covers(p.offset)) return r;
    }
    return null;
  }

  /// The misspelled word at the caret (collapsed selection), with its node.
  (String, SpellRange)? errorAtCaret() {
    final s = composer.selection;
    if (s == null) return null;
    final r = errorAt(s.extent);
    return r == null ? null : (s.extent.nodeId, r);
  }

  void _onDocument(DocumentChangeLog log) {
    for (final change in log.changes) {
      if (change is NodeRemovedEvent) {
        _dirty.remove(change.nodeId);
        _typed.remove(change.nodeId);
        _held.remove(change.nodeId);
        if (_errors.remove(change.nodeId) != null) {
          styler.clearErrorsForNode(change.nodeId);
        }
      } else if (change is NodeDocumentChange) {
        _dirty.add(change.nodeId);
        _typed.add(change.nodeId);
      }
    }
    _schedule();
  }

  void _onSelection() {
    final s = composer.selection;
    final node = s?.extent.nodeId;
    final p = s?.extent.nodePosition;
    final offset = p is TextNodePosition ? p.offset : null;
    // The caret left the word being typed: check it now.
    for (final MapEntry(key: id, value: r) in _held.entries) {
      if (id != node || offset == null || !r.covers(offset)) _dirty.add(id);
    }
    if (_dirty.isNotEmpty) _schedule();
  }

  void _recheckAll() {
    if (_disposed) return;
    for (final node in document) {
      _dirty.add(node.id);
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed || _dirty.isEmpty) return;
    _scheduled = true;
    final binding = SchedulerBinding.instance;
    binding.addPostFrameCallback((_) {
      _scheduled = false;
      checkNow();
    });
    binding.scheduleFrame();
  }

  /// Checks the changed paragraphs now (tests; normally after the frame).
  void checkNow() {
    if (_disposed) return;
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      _check(id, typed: _typed.remove(id));
    }
  }

  void _check(String nodeId, {bool typed = false}) {
    final node = document.getNodeById(nodeId);
    var found = const <SpellRange>[];
    _held.remove(nodeId);
    if (node is TextNode && (checks?.call(node) ?? true) && checker.underline) {
      final s = composer.selection;
      final caret =
          s != null &&
              s.isCollapsed &&
              s.extent.nodeId == nodeId &&
              s.extent.nodePosition is TextNodePosition
          ? (s.extent.nodePosition as TextNodePosition).offset
          : null;
      found = checker.check(
        node.text.toPlainText(includePlaceholders: false),
        skip: skipRangesOf(node.text),
      );
      if (typed && caret != null) {
        for (final r in found) {
          if (r.covers(caret)) _held[nodeId] = r;
        }
        final held = _held[nodeId];
        if (held != null) {
          found = [
            for (final r in found)
              if (r != held) r,
          ];
        }
      }
    }
    final previous = _errors[nodeId];
    if (found.isEmpty) {
      if (previous != null) {
        _errors.remove(nodeId);
        styler.clearErrorsForNode(nodeId);
      }
      return;
    }
    if (previous != null && listEquals(previous, found)) return;
    _errors[nodeId] = found;
    styler
      ..clearErrorsForNode(nodeId)
      ..addErrors(nodeId, {
        for (final r in found)
          TextError.spelling(
            nodeId: nodeId,
            range: TextRange(start: r.start, end: r.end),
            value: r.word,
          ),
      });
  }

  /// The ranges of [text] that are never checked: links and inline code.
  static List<(int, int)> skipRangesOf(AttributedText text) {
    if (text.length == 0) return const [];
    return [
      for (final span in text.getAttributionSpansInRange(
        attributionFilter: (a) => a == codeAttribution || a is LinkAttribution,
        range: SpanRange(0, text.length - 1),
      ))
        (span.start, span.end + 1),
    ];
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    document.removeListener(_onDocument);
    composer.selectionNotifier.removeListener(_onSelection);
    checker.removeListener(_recheckAll);
    styler.dispose();
  }
}
