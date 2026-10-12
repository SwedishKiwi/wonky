import 'dart:io';
import 'dart:math';

import 'package:dart_quill_delta/dart_quill_delta.dart';

/// Seeds for property tests: `WONKY_SEED` (single seed) or a fixed list
/// (specs/15-writing-tests.md §8).
List<int> propertySeeds() {
  final env = Platform.environment['WONKY_SEED'];
  if (env != null && int.tryParse(env) != null) {
    return [int.parse(env)];
  }
  return const [1, 2, 3, 42, 1337, 20261012];
}

/// Runs per seed: `WONKY_PROPERTY_RUNS` (default [fallback]).
int propertyRuns([int fallback = 40]) => int.tryParse(Platform.environment['WONKY_PROPERTY_RUNS'] ?? '') ?? fallback;

/// Generates random, valid Wonky Delta documents (Write 02 §1).
class DeltaGen {
  DeltaGen(this.random);

  final Random random;
  int _ids = 0;

  static const _words = ['lorem', 'ipsum', 'dolor', 'sit', 'amet', 'wonky', 'write', 'über', '日本語', '😀', 'a'];
  static const _langs = ['', 'dart', 'python', 'js'];

  String nextId(String prefix) => '$prefix-${_ids++}-${random.nextInt(1 << 30)}';

  bool chance(double p) => random.nextDouble() < p;

  T pick<T>(List<T> values) => values[random.nextInt(values.length)];

  String words([int max = 6]) {
    final count = 1 + random.nextInt(max);
    return List.generate(count, (_) => pick(_words)).join(' ');
  }

  Map<String, dynamic>? inlineAttributes({bool allowCode = true}) {
    if (chance(0.45)) return null;
    final attributes = <String, dynamic>{};
    if (allowCode && chance(0.15)) {
      attributes['code'] = true;
    } else {
      if (chance(0.4)) attributes['bold'] = true;
      if (chance(0.3)) attributes['italic'] = true;
      if (chance(0.2)) attributes['strike'] = true;
    }
    if (chance(0.15)) attributes['link'] = 'https://example.com/${random.nextInt(5)}';
    if (chance(0.1)) attributes['cmt_t${random.nextInt(3)}'] = true;
    if (chance(0.08)) {
      attributes['sug_s${random.nextInt(3)}'] = {'t': pick(['ins', 'del']), 'by': 'u1', 'at': 1000 + random.nextInt(3)};
    }
    return attributes.isEmpty ? null : attributes;
  }

  Map<String, dynamic>? overlays() {
    if (chance(0.8)) return null;
    return {
      if (chance(0.6)) 'cmt_t${random.nextInt(3)}': true,
      if (chance(0.5)) 'sug_s${random.nextInt(3)}': {'t': 'fmt', 'by': 'u2', 'at': 5, 'before': <String, dynamic>{}},
    };
  }

  void _text(Delta delta, {bool allowCode = true, bool allowSoftBreak = true}) {
    final runs = 1 + random.nextInt(4);
    for (var i = 0; i < runs; i += 1) {
      var text = words();
      if (allowSoftBreak && chance(0.1)) text = '$text ${words(2)}';
      if (i > 0) text = ' $text';
      if (chance(0.1)) {
        // A mention chip.
        delta.insert('@Anna Berg', {'mention': 'user-1', 'link': 'mailto:anna@example.com'});
        continue;
      }
      delta.insert(text, inlineAttributes(allowCode: allowCode));
    }
  }

  Map<String, dynamic> _embed() {
    switch (random.nextInt(3)) {
      case 0:
        return {
          'image': {
            'id': nextId('img'),
            'src': 'wonky-file://${nextId('file')}',
            'alt': chance(0.5) ? words(2) : '',
            if (chance(0.3)) 'title': words(1),
          },
        };
      case 1:
        return {
          'divider': {'id': nextId('hr')},
        };
      default:
        final cols = 1 + random.nextInt(3);
        final rows = 1 + random.nextInt(3);
        return {
          'table': {
            'id': nextId('tbl'),
            'align': List.generate(cols, (_) => pick<String?>([null, 'left', 'center', 'right'])),
            'rows': List.generate(rows, (r) => List.generate(cols, (c) => chance(0.3) ? '**${words(1)}**' : words(2))),
          },
        };
    }
  }

  /// A random valid document with up to [maxLines] lines.
  Delta document({int maxLines = 12}) {
    final delta = Delta();
    final lineCount = 1 + random.nextInt(maxLines);
    var previousListIndent = -1;
    for (var i = 0; i < lineCount; i += 1) {
      final kind = random.nextInt(10);
      switch (kind) {
        case 0:
          // Embed (must be preceded by a line end or document start: always
          // true because every line ends with "\n").
          delta.insert(_embed(), chance(0.2) ? {'cmt_t1': true} : null);
          delta.insert('\n', overlays());
          previousListIndent = -1;
        case 1:
          // Code block of 1-3 lines.
          final lang = pick(_langs);
          final lines = 1 + random.nextInt(3);
          for (var l = 0; l < lines; l += 1) {
            if (chance(0.85)) delta.insert(chance(0.5) ? '  ${words(3)}' : words(3), chance(0.1) ? {'cmt_t2': true} : null);
            delta.insert('\n', {'code-block': lang, ...?overlays()});
          }
          previousListIndent = -1;
        case 2 || 3:
          final listKind = pick(['bullet', 'ordered', 'checked', 'unchecked']);
          final maxIndent = previousListIndent + 1;
          final indent = maxIndent <= 0 ? 0 : random.nextInt(min(maxIndent, 8) + 1);
          if (chance(0.9)) _text(delta);
          delta.insert('\n', {'list': listKind, if (indent > 0) 'indent': indent, ...?overlays()});
          previousListIndent = indent;
        case 4:
          if (chance(0.95)) _text(delta);
          delta.insert('\n', {'header': 1 + random.nextInt(6), ...?overlays()});
          previousListIndent = -1;
        case 5:
          if (chance(0.95)) _text(delta);
          delta.insert('\n', {'blockquote': true, ...?overlays()});
          previousListIndent = -1;
        default:
          if (chance(0.9)) _text(delta);
          delta.insert('\n', overlays());
          previousListIndent = -1;
      }
    }
    return delta;
  }
}

/// Generates random change Deltas against a document that keep it valid.
class ChangeGen {
  ChangeGen(this.gen);

  final DeltaGen gen;

  Random get random => gen.random;

  /// Splits [document] into lines: (start, length, isEmbed, isCode).
  List<(int, int, bool, bool)> _lines(Delta document) {
    final lines = <(int, int, bool, bool)>[];
    var offset = 0;
    var lineStart = 0;
    var isEmbed = false;
    for (final op in document.operations) {
      final data = op.data;
      if (data is! String) {
        isEmbed = true;
        offset += 1;
        continue;
      }
      for (var i = 0; i < data.length; i += 1) {
        offset += 1;
        if (data.codeUnitAt(i) == 10) {
          lines.add((lineStart, offset - lineStart, isEmbed, op.attributes?['code-block'] != null));
          lineStart = offset;
          isEmbed = false;
        }
      }
    }
    return lines;
  }

  bool _isLowSurrogate(Delta document, int offset) {
    final text = _plain(document);
    if (offset <= 0 || offset >= text.length) return false;
    final unit = text.codeUnitAt(offset);
    return unit >= 0xDC00 && unit <= 0xDFFF;
  }

  String _plain(Delta document) =>
      document.operations.map((op) => op.data is String ? op.data as String : '\u0000').join();

  int _safeOffset(Delta document, int offset) => _isLowSurrogate(document, offset) ? offset - 1 : offset;

  /// A random change against [document].
  Delta change(Delta document) {
    final lines = _lines(document);
    final textLines = [for (final l in lines) if (!l.$3) l];
    final change = Delta();
    if (textLines.isEmpty) {
      // Only embeds: add a text line at the start.
      return change..insert('${gen.words(2)}\n');
    }
    switch (random.nextInt(8)) {
      case 0 || 1:
        // Insert text inside a text line.
        final line = gen.pick(textLines);
        final at = _safeOffset(document, line.$1 + random.nextInt(line.$2));
        change
          ..retain(at)
          ..insert(gen.chance(0.5) ? gen.words(2) : 'x', line.$4 ? null : gen.inlineAttributes());
      case 2:
        // Delete inside a text line (not the line end).
        final line = gen.pick(textLines);
        if (line.$2 <= 1) return change;
        final from = _safeOffset(document, line.$1 + random.nextInt(line.$2 - 1));
        final to = _safeOffset(document, from + 1 + random.nextInt(line.$1 + line.$2 - 1 - from));
        if (to <= from) return change;
        change
          ..retain(from)
          ..delete(to - from);
      case 3:
        // Join a text line with the next text line (delete the line end).
        final candidates = [
          for (var i = 0; i + 1 < lines.length; i += 1)
            if (!lines[i].$3 && !lines[i + 1].$3) i,
        ];
        if (candidates.isEmpty) return change;
        final i = gen.pick(candidates);
        change
          ..retain(lines[i].$1 + lines[i].$2 - 1)
          ..delete(1);
      case 4:
        // Format a text range inside a line.
        final line = gen.pick(textLines);
        if (line.$2 <= 1 || line.$4) return change;
        final from = _safeOffset(document, line.$1 + random.nextInt(line.$2 - 1));
        final length = 1 + random.nextInt(line.$1 + line.$2 - 1 - from);
        final key = gen.pick(['bold', 'italic', 'strike', 'cmt_t9']);
        change
          ..retain(from)
          ..retain(length, {key: gen.chance(0.7) ? true : null});
      case 5:
        // Change a text line's block type.
        final line = gen.pick(textLines);
        final attributes = gen.pick<Map<String, dynamic>>([
          {'header': 2, 'list': null, 'indent': null, 'blockquote': null, 'code-block': null},
          {'list': 'bullet', 'header': null, 'blockquote': null, 'code-block': null},
          {'list': 'unchecked', 'header': null, 'blockquote': null, 'code-block': null},
          {'blockquote': true, 'header': null, 'list': null, 'indent': null, 'code-block': null},
          {'code-block': 'dart', 'header': null, 'list': null, 'indent': null, 'blockquote': null},
          {'header': null, 'list': null, 'indent': null, 'blockquote': null, 'code-block': null},
        ]);
        if (attributes['code-block'] != null && _hasInlineAttributes(document, line.$1, line.$2 - 1)) {
          return change;
        }
        change
          ..retain(line.$1 + line.$2 - 1)
          ..retain(1, attributes);
      case 6:
        // Split a text line.
        final line = gen.pick(textLines);
        final at = _safeOffset(document, line.$1 + random.nextInt(line.$2));
        change
          ..retain(at)
          ..insert('\n', line.$4 ? {'code-block': 'dart'} : null);
      default:
        // Insert an embed line at a line start.
        final line = gen.pick(lines);
        final previous = lines.indexOf(line) - 1;
        // Keep code blocks intact: never insert between two lines of one block.
        if (line.$4 && previous >= 0 && lines[previous].$4) return change;
        change
          ..retain(line.$1)
          ..insert({
            'divider': {'id': gen.nextId('hr')},
          })
          ..insert('\n');
    }
    return change;
  }

  bool _hasInlineAttributes(Delta document, int from, int length) {
    final slice = document.slice(from, from + length);
    return slice.operations.any((op) => op.attributes != null && op.attributes!.keys.any((k) => !k.startsWith('cmt_')));
  }
}
