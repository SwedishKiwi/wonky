// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// This file is taken from DevTools and should be kept in-sync with any changes
// that affect the resulting tokens.
//
// https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/screens/debugger/span_parser.dart
//
// Wonky Work: copied from the vendored syntax_highlight 0.5.0
// (lib/src/span_parser.dart, BSD-3-Clause) with its `WONKY PATCH` changes;
// provenance and patch history in THIRD_PARTY.md (Slides 07 §2.1, v2 review
// Q26). Pure Dart: no Flutter.

// ignore_for_file: public_member_api_docs, prefer_initializing_formals, use_super_parameters

import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';

const _neverMatchingRegexStr = r'^(?!x)x';

// WONKY PATCH SH-2: TextMate grammars use Oniguruma's inline `(?i)` flag,
// which Dart's RegExp rejects or (inside a group) silently never matches, so
// e.g. no SQL keyword was highlighted. A leading `(?i)` becomes
// `caseSensitive: false`.
RegExp _regExp(String source) {
  const caseInsensitive = '(?i)';
  if (source.startsWith(caseInsensitive)) {
    return RegExp(
      source.substring(caseInsensitive.length),
      multiLine: true,
      caseSensitive: false,
    );
  }
  return RegExp(source, multiLine: true);
}

//TODO(jacobr): cleanup.
// ignore: avoid_classes_with_only_static_members
abstract class SpanParser {
  /// Takes a TextMate [Grammar] and a [String] and outputs a list of
  /// [ScopeSpan]s corresponding to the parsed input.
  static List<ScopeSpan> parse(Grammar grammar, String src) {
    final scopeStack = ScopeStack();
    final scanner = LineScanner(src);
    final top = grammar._topLevelList;
    while (!scanner.isDone) {
      // WONKY PATCH SH-6: jump to the next position where the top level can
      // match instead of trying every rule at every character.
      final next = _nextCandidate(grammar, top, scanner);
      if (next < 0) {
        scanner.position = src.length;
        break;
      }
      if (next > scanner.position) scanner.position = next;
      final foundMatch = grammar.topLevelMatcher.scan(
        grammar,
        scanner,
        scopeStack,
      );
      if (!foundMatch && !scanner.isDone) {
        // Found no match, move forward by a character and try again.
        scanner.readChar();
      }
    }
    scopeStack.popAll(scanner.location);
    _releaseSearchState();
    return scopeStack.spans;
  }
}

/// A representation of a TextMate grammar used to create [ScopeSpan]s
/// representing scopes within a body of text.
///
/// References used:
///   - Grammar specification:
///       https://macromates.com/manual/en/language_grammars#language_grammars
///   - Helpful blog post which clears up ambiguities in the spec:
///       https://www.apeth.com/nonblog/stories/textmatebundle.html
///
class Grammar {
  factory Grammar.fromJson(Map<String, Object?> json) {
    return Grammar._(
      name: json['name'] as String,
      scopeName: json['scopeName'] as String,
      topLevelMatcher: GrammarMatcher.parse(json),
      repository: Repository.build(json),
    );
  }

  Grammar._({
    this.name,
    this.scopeName,
    required this.topLevelMatcher,
    required this.repository,
  });

  final String? name;

  final String? scopeName;

  final GrammarMatcher topLevelMatcher;

  // WONKY PATCH SH-6: a stable list for the next-match search caches.
  late final List<GrammarMatcher> _topLevelList = [topLevelMatcher];

  final Repository repository;

  @override
  String toString() {
    return const JsonEncoder.withIndent('  ').convert({
      'name': name,
      'scopeName': scopeName,
      'topLevelMatcher': topLevelMatcher.toJson(),
      'repository': repository.toJson(),
    });
  }
}

/// A representation of a span of text which has `scope` applied to it.
class ScopeSpan {
  ScopeSpan({
    required this.scopes,
    required ScopeStackLocation startLocation,
    required ScopeStackLocation endLocation,
  }) : _startLocation = startLocation,
       _endLocation = endLocation;

  ScopeStackLocation get startLocation => _startLocation;
  ScopeStackLocation get endLocation => _endLocation;
  int get start => _startLocation.position;
  int get end => _endLocation.position;
  int get length => end - start;

  final ScopeStackLocation _startLocation;
  ScopeStackLocation _endLocation;

  /// The one-based line number.
  int get line => startLocation.line + 1;

  /// The one-based column number.
  int get column => startLocation.column + 1;

  final List<String> scopes;

  bool contains(int token) => (start <= token) && (token < end);

  /// Splits the current [ScopeSpan] into multiple spans separated by [cond].
  /// This is useful for post-processing the results from a rule with a while
  /// condition as formatting should not be applied to the characters that
  /// match the while condition.
  List<ScopeSpan> split(LineScanner scanner, RegExp cond) {
    final splitSpans = <ScopeSpan>[];

    // Create a temporary scanner, copying [0, end] to ensure that line/column
    // information is consistent with the original scanner.
    final splitScanner = LineScanner(
      scanner.substring(0, end),
      position: start,
      prefixOf: scanner,
    );

    // Start with a copy of the original span
    ScopeSpan current = ScopeSpan(
      scopes: scopes.toList(),
      startLocation: startLocation,
      endLocation: endLocation,
    );

    while (!splitScanner.isDone) {
      if (splitScanner.matches(cond)) {
        // Update the end position for this span as it's been fully processed.
        current._endLocation = splitScanner.location;
        splitSpans.add(current);

        // Move the scanner position past the matched condition.
        splitScanner.scan(cond);

        // Create a new span based on the current position.
        current = ScopeSpan(
          scopes: scopes.toList(),
          startLocation: splitScanner.location,
          // Will be updated later.
          endLocation: ScopeStackLocation.zero,
        );
      } else {
        // Move scanner position forward.
        splitScanner.readChar();
      }
    }
    // Finish processing the last span, which will always have the same end
    // position as the span we're splitting.
    current._endLocation = endLocation;
    splitSpans.add(current);

    return splitSpans;
  }

  @override
  String toString() {
    return '[$start, $end, $line:$column (len: $length)] = $scopes';
  }
}

/// A top-level repository of rules that can be referenced within other rules
/// using the 'includes' keyword.
class Repository {
  Repository.build(Map<String, Object?> grammarJson) {
    final repositoryJson = (grammarJson['repository'] as Map<String, Object?>?)
        ?.cast<String, Map<String, Object?>>();
    if (repositoryJson == null) {
      return;
    }
    for (final subRepo in repositoryJson.keys) {
      matchers[subRepo] = GrammarMatcher.parse(repositoryJson[subRepo]!);
    }
  }

  final matchers = <String?, GrammarMatcher>{};

  Map<String, Object?> toJson() {
    return {
      for (final entry in matchers.entries)
        if (entry.key != null) entry.key!: entry.value.toJson(),
    };
  }
}

abstract class GrammarMatcher {
  factory GrammarMatcher.parse(Map<String, Object?> json) {
    if (_IncludeMatcher.isType(json)) {
      return _IncludeMatcher(json['include'] as String);
    } else if (_SimpleMatcher.isType(json)) {
      try {
        return _SimpleMatcher(json);
      } catch (e) {
        return _SimpleMatcher({'match': _neverMatchingRegexStr});
      }
    } else if (_MultilineMatcher.isType(json)) {
      try {
        return _MultilineMatcher(json);
      } catch (e) {
        return _MultilineMatcher({'begin': _neverMatchingRegexStr});
      }
    } else if (_PatternMatcher.isType(json)) {
      return _PatternMatcher(json);
    }
    throw StateError('Unknown matcher type: $json');
  }

  GrammarMatcher._(Map<String, Object?> json) : name = json['name'] as String?;

  final String? name;

  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack);

  void _applyCapture(
    Grammar grammar,
    LineScanner scanner,
    ScopeStack scopeStack,
    Map<String, Object?>? captures,
    ScopeStackLocation location,
  ) {
    final lastMatch = scanner.lastMatch!;
    final start = lastMatch.start;
    final end = lastMatch.end;
    final matchStartLocation = location;
    if (captures != null) {
      final match = scanner.substring(start, end);
      // WONKY PATCH SH-7: capture offsets from the group structure (they were
      // `match.indexOf(captureText)`, so `function f` scoped the `f` of
      // `function` as the function name).
      final offsets = _CaptureOffsets.of(lastMatch, match);
      for (int i = 0; i <= lastMatch.groupCount; ++i) {
        // Skip if we don't have a scope or nested patterns for this capture.
        if (!captures.containsKey(i.toString())) continue;

        final captureText = lastMatch.group(i);
        if (captureText == null || captureText.isEmpty) continue;

        final located = offsets == null ? -1 : offsets[i];
        final startOffset = located >= 0 ? located : match.indexOf(captureText);
        final capture = captures[i.toString()] as Map<String, Object?>;
        final captureStartLocation = matchStartLocation.offset(startOffset);
        final captureEndLocation = captureStartLocation.offset(
          captureText.length,
        );
        final captureName = capture['name'] as String?;

        scopeStack.push(captureName, captureStartLocation);

        // Handle nested pattern matchers.
        if (capture.containsKey('patterns')) {
          final captureScanner = LineScanner(
            scanner.substring(0, captureEndLocation.position),
            position: captureStartLocation.position,
            prefixOf: scanner,
          );
          // WONKY PATCH SH-6: capture patterns are parsed once (they were
          // re-parsed, i.e. their regexes recompiled, on every match).
          (_captureMatchers[capture] ??= GrammarMatcher.parse(
            capture,
          )).scan(grammar, captureScanner, scopeStack);
        }

        scopeStack.pop(captureName, captureEndLocation);
      }
    }
  }

  Map<String, Object?> toJson();
}

/// A simple matcher which matches a single line.
class _SimpleMatcher extends GrammarMatcher {
  _SimpleMatcher(Map<String, Object?> json)
    : match = _regExp(json['match'] as String),
      captures = (json['captures'] as Map<String, Object?>?)
          ?.cast<String, Map<String, Object?>>(),
      super._(json);

  static bool isType(Map<String, Object?> json) {
    return json.containsKey('match');
  }

  final RegExp match;

  final Map<String, Object?>? captures;

  @override
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    // WONKY PATCH SH-6: a memoized search proves most rules can't match here.
    if (_cannotMatchAt(match, scanner)) return false;
    final location = scanner.location;
    if (scanner.scan(match)) {
      scopeStack.push(name, location);
      _applyCapture(grammar, scanner, scopeStack, captures, location);
      scopeStack.pop(name, scanner.location);
      return true;
    }
    return false;
  }

  @override
  Map<String, Object?> toJson() {
    return {
      if (name != null) 'name': name,
      'match': match.pattern,
      if (captures != null) 'captures': captures,
    };
  }
}

class _MultilineMatcher extends GrammarMatcher {
  _MultilineMatcher(Map<String, Object?> json)
    : begin = _regExp(json['begin'] as String),
      beginCaptures = json['beginCaptures'] as Map<String, Object?>?,
      contentName = json['contentName'] as String?,
      end = json['end'] == null ? null : _regExp(json['end'] as String),
      endCaptures = json['endCaptures'] as Map<String, Object?>?,
      captures = json['captures'] as Map<String, Object?>?,
      whileCond = json['while'] == null
          ? null
          : _regExp(json['while'] as String),
      patterns = (json['patterns'] as List<Object?>?)
          ?.cast<Map<String, Object?>>()
          .map((e) => GrammarMatcher.parse(e))
          .toList()
          .cast<GrammarMatcher>(),
      super._(json);

  static bool isType(Map<String, Object?> json) {
    return json.containsKey('begin') &&
        (json.containsKey('end') || json.containsKey('while'));
  }

  /// A regular expression which defines the beginning match of this rule. This
  /// property is required and must be defined along with either `end` or
  /// `while`.
  final RegExp begin;

  /// A set of scopes to apply to groups captured by `begin`. `captures` should
  /// be null if this property is provided.
  final Map<String, Object?>? beginCaptures;

  /// The scope that applies to the content between the matches found by
  /// `begin` and `end`.
  final String? contentName;

  /// A regular expression which defines the match signaling the end of the
  /// rule application. This property is mutually exclusive with the `while`
  /// property.
  final RegExp? end;

  /// A set of scopes to apply to groups captured by `begin`. `captures` should
  /// be null if this property is provided.
  final Map<String, Object?>? endCaptures;

  /// A regular expression corresponding with the `while` property used to
  /// determine if the next line should have the current rule applied. If
  /// `patterns` is provided, the contents of a line that satisfy this regular
  /// expression will be processed against the provided patterns.
  ///
  /// This expression is applied to every line **after** the first line matched
  /// by `begin`. If this expression fails after the line matched by `begin`,
  /// the overall rule does not fail and the resulting [ScopeSpan]s will consist
  /// of matches found in the first line.
  ///
  /// This property is mutually exclusive with the `end` property.
  final RegExp? whileCond;

  /// A set of scopes to apply to groups captured by `begin` and `end`.
  /// Providing this property is the equivalent of setting `beginCaptures` and
  /// `endCaptures` to the same value. `beginCaptures` and `endCaptures` should
  /// be null if this property is provided.
  final Map<String, Object?>? captures;

  final List<GrammarMatcher>? patterns;

  void _scanBegin(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    final location = scanner.location;
    if (!scanner.scan(begin)) {
      // This shouldn't happen since we've already checked that `begin` matches
      // the beginning of the string.
      throw StateError('Expected ${begin.pattern} to match.');
    }
    _processCaptureHelper(
      grammar,
      scanner,
      scopeStack,
      beginCaptures,
      location,
    );
  }

  void _scanToEndOfLine(
    Grammar grammar,
    LineScanner scanner,
    ScopeStack scopeStack,
  ) {
    while (!scanner.isDone) {
      if (String.fromCharCode(scanner.peekChar()!) == '\n') {
        scanner.readChar();
        break;
      }
      bool foundMatch = false;
      for (final pattern in patterns ?? <GrammarMatcher>[]) {
        if (pattern.scan(grammar, scanner, scopeStack)) {
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch) {
        scanner.readChar();
      }
    }
  }

  void _scanUpToEndMatch(
    Grammar grammar,
    LineScanner scanner,
    ScopeStack scopeStack,
  ) {
    final candidates = patterns ?? const <GrammarMatcher>[];
    while (!scanner.isDone && end != null && !scanner.matches(end!)) {
      // WONKY PATCH SH-6: jump to the earliest position where the end or a
      // pattern can match (the end wins ties: it is checked first).
      final pos = scanner.position;
      final e = _nextMatch(end!, scanner, pos);
      final p = _nextCandidate(grammar, candidates, scanner);
      final target = e < 0 ? p : (p < 0 ? e : (e < p ? e : p));
      if (target < 0) {
        scanner.position = scanner.string.length;
        break;
      }
      if (target > pos) {
        scanner.position = target;
        continue;
      }
      bool foundMatch = false;
      for (final pattern in patterns ?? <GrammarMatcher>[]) {
        if (pattern.scan(grammar, scanner, scopeStack)) {
          foundMatch = true;
          break;
        }
      }
      if (!foundMatch) {
        // Move forward by a character, try again.
        scanner.readChar();
      }
    }
  }

  void _scanEnd(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    final location = scanner.location;
    if (end != null && !scanner.scan(end!)) {
      return;
    }
    _processCaptureHelper(grammar, scanner, scopeStack, endCaptures, location);
  }

  void _processCaptureHelper(
    Grammar grammar,
    LineScanner scanner,
    ScopeStack scopeStack,
    Map<String, Object?>? customCaptures,
    ScopeStackLocation location,
  ) {
    if (contentName == null || (customCaptures ?? captures) != null) {
      _applyCapture(
        grammar,
        scanner,
        scopeStack,
        customCaptures ?? captures,
        location,
      );
    }
  }

  @override
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    // WONKY PATCH SH-6: a memoized search proves most rules can't match here.
    if (_cannotMatchAt(begin, scanner) || !scanner.matches(begin)) {
      return false;
    }

    scopeStack.push(name, scanner.location);
    _scanBegin(grammar, scanner, scopeStack);
    if (end != null) {
      scopeStack.push(contentName, scanner.location);
      _scanUpToEndMatch(grammar, scanner, scopeStack);
      scopeStack.pop(contentName, scanner.location);
      _scanEnd(grammar, scanner, scopeStack);
    } else if (whileCond != null) {
      // Find the range of the string that is matched by the while condition.
      final start = scanner.position;
      _skipLine(scanner);
      while (!scanner.isDone && whileCond != null && scanner.scan(whileCond!)) {
        _skipLine(scanner);
      }
      final end = scanner.position;

      // Create a temporary scanner to ensure that rules that don't find an
      // end match don't try and match all the way to the end of the file.
      final contentScanner = LineScanner(
        scanner.substring(0, end),
        position: start,
        prefixOf: scanner,
      );

      // Capture a marker for where the contents start, used later to split
      // spans.
      final whileContentBeginMarker = scopeStack.marker();

      _scanToEndOfLine(grammar, contentScanner, scopeStack);

      // Process each line until the `while` condition fails.
      while (!contentScanner.isDone &&
          whileCond != null &&
          contentScanner.scan(whileCond!)) {
        _scanToEndOfLine(grammar, contentScanner, scopeStack);
      }

      // Now, split any spans produced whileContentBeginMarker by `whileCond`.
      scopeStack.splitFromMarker(scanner, whileContentBeginMarker, whileCond!);
    } else {
      throw StateError(
        "One of 'end' or 'while' must be provided for rule: $name",
      );
    }
    scopeStack.pop(name, scanner.location);
    return true;
  }

  // WONKY PATCH SH-6: compiled once.
  static final _lineRegExp = RegExp('.*\n');

  void _skipLine(LineScanner scanner) {
    scanner.scan(_lineRegExp);
  }

  @override
  Map<String, Object?> toJson() {
    return {
      if (name != null) 'name': name,
      'begin': begin.pattern,
      if (beginCaptures != null) 'beginCaptures': beginCaptures,
      if (end != null) 'end': end!.pattern,
      if (endCaptures != null) 'endCaptures': endCaptures,
      if (whileCond != null) 'while': whileCond!.pattern,
      if (patterns != null)
        'patterns': patterns!.map((e) => e.toJson()).toList(),
    };
  }
}

class _PatternMatcher extends GrammarMatcher {
  _PatternMatcher(Map<String, Object?> json)
    : patterns = (json['patterns'] as List<Object?>?)
          ?.cast<Map<String, Object?>>()
          .map((e) => GrammarMatcher.parse(e))
          .toList()
          .cast<GrammarMatcher>(),
      super._(json);

  static bool isType(Map<String, Object?> json) {
    return json.containsKey('patterns');
  }

  final List<GrammarMatcher>? patterns;

  @override
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    // Try each rule in the include and return after the first successful match.
    for (final pattern in patterns!) {
      if (pattern.scan(grammar, scanner, scopeStack)) {
        return true;
      }
    }
    return false;
  }

  @override
  Map<String, Object?> toJson() {
    return {
      if (name != null) 'name': name,
      if (patterns != null)
        'patterns': patterns!.map((e) => e.toJson()).toList(),
    };
  }
}

/// A [GrammarMatcher] that corresponds to an `include` rule referenced in a
/// `patterns` array. Allows for executing rules defined within a
/// [Repository].
class _IncludeMatcher extends GrammarMatcher {
  _IncludeMatcher(String include) : include = include.substring(1), super._({});

  final String include;

  static bool isType(Map<String, Object?> json) {
    return json.containsKey('include');
  }

  @override
  bool scan(Grammar grammar, LineScanner scanner, ScopeStack scopeStack) {
    final matcher = grammar.repository.matchers[include];
    if (matcher == null) {
      throw StateError('Could not find $include in the repository.');
    }
    return matcher.scan(grammar, scanner, scopeStack);
  }

  @override
  Map<String, Object?> toJson() {
    return {'include': include};
  }
}

/// Tracks the current scope stack, producing [ScopeSpan]s as the contents
/// change.
class ScopeStack {
  ScopeStack();

  final stack = Queue<ScopeStackItem>();
  final spans = <ScopeSpan>[];

  /// Location where the next produced span should begin.
  ScopeStackLocation _nextLocation = ScopeStackLocation.zero;

  /// Adds a scope for a given region.
  ///
  /// This method is the same as calling [push] and then [pop] with the same
  /// args.
  void add(
    String? scope, {
    required ScopeStackLocation start,
    required ScopeStackLocation end,
  }) {
    push(scope, start);
    pop(scope, end);
  }

  /// Pushes a new scope onto the stack starting at [start].
  void push(String? scope, ScopeStackLocation location) {
    if (scope == null) return;

    // If the stack is empty, seed the position which is used for the start
    // of the next produced token.
    if (stack.isEmpty) {
      _nextLocation = location;
    }

    // Whenever we push a new item, produce a span for the region between the
    // last started scope and the new current position.
    if (location.position > _nextLocation.position) {
      final scopes = stack.map((item) => item.scope).toSet();
      _produceSpan(scopes, end: location);
    }

    // Add this new scope to the stack, but don't produce its token yet. We will
    // do that when the next item is pushed (in which case we'll fill the gap),
    // or when this item is popped (in which case we'll produce a span for that
    // full region).
    stack.add(ScopeStackItem(scope, location));
  }

  /// Pops the last scope off the stack, producing a token if necessary up until
  /// [end].
  void pop(String? scope, ScopeStackLocation end) {
    if (scope == null) return;
    assert(stack.isNotEmpty);

    final scopes = stack.map((item) => item.scope).toSet();
    final last = stack.removeLast();
    assert(last.scope == scope);
    assert(last.location.position <= end.position);

    _produceSpan(scopes, end: end);
  }

  void popAll(ScopeStackLocation location) {
    while (stack.isNotEmpty) {
      pop(stack.last.scope, location);
    }
  }

  /// Captures a marker to identify spans produced before/after this call.
  ScopeStackMarker marker() {
    return ScopeStackMarker(spanIndex: spans.length, location: _nextLocation);
  }

  /// Splits all spans created since [begin] by [condition].
  ///
  /// This is used to handle multiline spans that use begin/end such as
  /// capturing triple-backtick code blocks that would have captured the leading
  /// '/// ', which should not be included.
  void splitFromMarker(
    LineScanner scanner,
    ScopeStackMarker begin,
    RegExp condition,
  ) {
    // Remove the spans to be split. We will push new spans after splitting.
    final spansToSplit = spans.sublist(begin.spanIndex);
    if (spansToSplit.isEmpty) return;
    spans.removeRange(begin.spanIndex, spans.length);

    // Also rewind the last positions to the start place.
    _nextLocation = begin.location;

    // Add the split spans individually.
    for (final span in spansToSplit.expand(
      (spanToSplit) => spanToSplit.split(scanner, condition),
    )) {
      // To handler spans with multiple scopes, we need to push each scope, and
      // then pop each scope. We cannot use `add`.
      for (final scope in span.scopes) {
        push(scope, span.startLocation);
      }
      for (final scope in span.scopes.reversed) {
        pop(scope, span.endLocation);
      }
    }
  }

  void _produceSpan(Set<String> scopes, {required ScopeStackLocation end}) {
    // Don't produce zero-width spans.
    if (end.position == _nextLocation.position) return;

    // If the new span starts at the same place that the previous one ends and
    // has the same scopes, we can replace the previous one with a single new
    // larger span.
    final newScopes = scopes.toList();
    final lastSpan = spans.lastOrNull;
    if (lastSpan != null &&
        lastSpan.endLocation.position == _nextLocation.position &&
        lastSpan.scopes.equals(newScopes)) {
      final span = ScopeSpan(
        scopes: newScopes,
        startLocation: lastSpan.startLocation,
        endLocation: end,
      );
      // Replace the last span with this one.
      spans.last = span;
    } else {
      final span = ScopeSpan(
        scopes: newScopes,
        startLocation: _nextLocation,
        endLocation: end,
      );
      spans.add(span);
    }
    _nextLocation = end;
  }
}

/// An item pushed onto the scope stack, consisting of a [String] scope and a
/// location.
class ScopeStackItem {
  ScopeStackItem(this.scope, this.location);

  final String scope;
  final ScopeStackLocation location;
}

/// A marker tracking a position in the list of produced tokens.
///
/// Used for back-tracking when handling nested multiline tokens.
class ScopeStackMarker {
  ScopeStackMarker({required this.spanIndex, required this.location});

  final int spanIndex;
  final ScopeStackLocation location;
}

/// A location (including offset, line, column) in the code parsed for scopes.
class ScopeStackLocation {
  const ScopeStackLocation({
    required this.position,
    required this.line,
    required this.column,
  });

  static const zero = ScopeStackLocation(position: 0, line: 0, column: 0);

  /// 0-based offset in content.
  final int position;

  /// 0-based line number of [position].
  final int line;

  /// 0-based column number of [position].
  final int column;

  /// Returns a location offset by [offset] characters.
  ///
  /// This method does not handle line wrapping so should only be used where it
  /// is known that the offset does not wrap across a line boundary.
  ScopeStackLocation offset(int offset) {
    return ScopeStackLocation(
      position: position + offset,
      line: line,
      column: column + offset,
    );
  }
}

extension LineScannerExtension on LineScanner {
  // WONKY PATCH SH-6: line and column are computed on demand.
  ScopeStackLocation get location => _ScannerLocation(this, position);
}

// WONKY PATCH SH-6: a location whose line/column are looked up when read
// (the tokenizer only reads positions).
class _ScannerLocation extends ScopeStackLocation {
  _ScannerLocation(this._scanner, int position)
    : super(position: position, line: 0, column: 0);

  final LineScanner _scanner;

  @override
  int get line => _scanner._lineOf(position);

  @override
  int get column => _scanner._columnOf(position);
}

// WONKY PATCH SH-7: Dart's `Match` has no group offsets, and the engine
// placed each capture at the first occurrence of its text in the match, so
// a capture whose text also occurs earlier (`function f`, `def f`, `func f`)
// was scoped at the wrong place — overlapping tokens, wrong colors. Groups are
// numbered by their opening parenthesis, so a group starts at or after its
// parent group and after the end of its previous matched sibling, and ends
// within its parent: each capture is searched from there. Still a search
// (the text could repeat inside an uncaptured gap, or a quantified group
// holds its last iteration), and groups outside the match (lookarounds) keep
// the old fallback.
final class _CaptureOffsets {
  /// The parent group of every group of a pattern (`[0]` is the match,
  /// `-1`); empty when the source could not be read reliably.
  static final _parents = Expando<List<int>>();

  /// Start offsets of every group of [match] within [text] (the matched
  /// substring), `-1` when unknown; `null` when the pattern can't be read.
  static List<int>? of(Match match, String text) {
    final pattern = match.pattern;
    if (pattern is! RegExp) return null;
    final parents = _parents[pattern] ??= _parse(pattern.pattern) ?? const [];
    final count = match.groupCount;
    if (parents.length != count + 1) return null;
    final starts = List<int>.filled(count + 1, -1);
    final ends = List<int>.filled(count + 1, -1);
    final childEnd = List<int>.filled(count + 1, -1);
    starts[0] = 0;
    ends[0] = text.length;
    for (var i = 1; i <= count; i++) {
      final group = match.group(i);
      final parent = parents[i];
      if (group == null || starts[parent] < 0) continue;
      final from = childEnd[parent] > starts[parent]
          ? childEnd[parent]
          : starts[parent];
      var at = text.indexOf(group, from);
      if (at < 0 || at + group.length > ends[parent]) {
        at = text.indexOf(group, starts[parent]);
        if (at < 0 || at + group.length > ends[parent]) continue;
      }
      starts[i] = at;
      ends[i] = at + group.length;
      childEnd[parent] = ends[i];
    }
    return starts;
  }

  /// Parent groups of a JavaScript-syntax regex [source] (Dart `RegExp`,
  /// non-unicode): escapes, character classes, non-capturing groups and
  /// lookarounds are skipped; `(?<name>` captures.
  static List<int>? _parse(String source) {
    final parents = <int>[-1];
    final open = <int>[0]; // enclosing groups; -1 = not capturing
    var inClass = false;
    for (var i = 0; i < source.length; i++) {
      final c = source.codeUnitAt(i);
      if (c == 0x5C) {
        i++; // escaped character
      } else if (inClass) {
        if (c == 0x5D) inClass = false;
      } else if (c == 0x5B) {
        inClass = true;
      } else if (c == 0x28) {
        var capturing = true;
        if (i + 1 < source.length && source.codeUnitAt(i + 1) == 0x3F) {
          capturing =
              i + 3 < source.length &&
              source.codeUnitAt(i + 2) == 0x3C &&
              source.codeUnitAt(i + 3) != 0x3D &&
              source.codeUnitAt(i + 3) != 0x21;
        }
        if (capturing) {
          parents.add(open.lastWhere((g) => g >= 0));
          open.add(parents.length - 1);
        } else {
          open.add(-1);
        }
      } else if (c == 0x29) {
        if (open.length == 1) return null; // unbalanced
        open.removeLast();
      }
    }
    return open.length == 1 ? parents : null;
  }
}

// WONKY PATCH SH-6: the engine's own scanner instead of `string_scanner`'s
// `LineScanner`, which counts newlines (with a regex over a substring) on
// every position change and from the start of the string whenever a scanner
// is created at a position — a third of the parse time. Line and column are
// computed on demand from a newline index shared with the scanners created
// over a prefix of this one's string. Same semantics: `\n` and a lone `\r`
// end a line; positions are UTF-16 offsets.
class LineScanner {
  LineScanner(this.string, {int position = 0, LineScanner? prefixOf})
    : _position = position,
      _newlines = prefixOf?._newlines;

  /// The scanned string.
  final String string;

  int _position;
  Match? _lastMatch;
  int _lastMatchPosition = -1;
  List<int>? _newlines;

  int get position => _position;

  set position(int value) {
    if (value < 0 || value > string.length) {
      throw ArgumentError('Invalid position $value');
    }
    _position = value;
  }

  bool get isDone => _position == string.length;

  /// The last successful [scan]/[matches] match at the current position.
  Match? get lastMatch => _lastMatchPosition == _position ? _lastMatch : null;

  int readChar() {
    if (isDone) throw StateError('No more input');
    return string.codeUnitAt(_position++);
  }

  int? peekChar([int offset = 0]) {
    final i = _position + offset;
    return i < 0 || i >= string.length ? null : string.codeUnitAt(i);
  }

  bool matches(Pattern pattern) {
    _lastMatch = pattern.matchAsPrefix(string, _position);
    _lastMatchPosition = _position;
    return _lastMatch != null;
  }

  bool scan(Pattern pattern) {
    if (!matches(pattern)) return false;
    _position = _lastMatch!.end;
    _lastMatchPosition = _position;
    return true;
  }

  String substring(int start, [int? end]) => string.substring(start, end);

  /// 0-based line of the position.
  int get line => _lineOf(_position);

  /// 0-based column of the position (UTF-16 units since the line start).
  int get column => _columnOf(_position);

  int _columnOf(int pos) {
    final l = _lineOf(pos);
    return l == 0 ? pos : pos - (_index[l - 1] + 1);
  }

  /// Offsets of the line-ending characters (`\n`, lone `\r`) of the
  /// string — of a longer one when shared with a parent scanner (only
  /// offsets before the position are ever used, and the string is a prefix).
  List<int> get _index {
    final cached = _newlines;
    if (cached != null) return cached;
    final out = <int>[];
    for (var i = 0; i < string.length; i++) {
      final c = string.codeUnitAt(i);
      if (c == 0x0A ||
          (c == 0x0D &&
              (i + 1 >= string.length || string.codeUnitAt(i + 1) != 0x0A))) {
        out.add(i);
      }
    }
    return _newlines = out;
  }

  /// Number of line endings before [pos].
  int _lineOf(int pos) {
    final index = _index;
    var lo = 0, hi = index.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (index[mid] < pos) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

// ---------------------------------------------------------------------------
// WONKY PATCH SH-6: next-match search (performance, Slides 07 §14).
//
// The engine tries every rule at every character and advances one character
// when none matches. A rule list can only match at the leftmost position
// where one of its leaf regexes (simple `match`, multi-line `begin`, through
// `patterns` and `include`s) matches, so the loops jump there first. A
// leftmost search from `from` finds exactly the first position `q >= from`
// where `matchAsPrefix(q)` succeeds, so the produced spans are unchanged.
//
// Search results are memoized per scanner (= per source string) and regex:
// "the leftmost match at or after `from` is `at`" stays true for every later
// `from'` in `[from, at]`. Per rule list, a min-heap of the leaves' next
// match positions answers "where can this list match next" without visiting
// every leaf (a scanner only moves forward; a backward query rebuilds).

final _captureMatchers = Expando<GrammarMatcher>('captureMatchers');

final _leafCache = Expando<List<RegExp>>('leafRegExps');

final _states = Expando<_SearchState>('searchStates');

LineScanner? _lastScanner;
_SearchState? _lastState;

/// The search state of [scanner] (the last one is kept at hand: Expando
/// lookups are comparatively slow).
_SearchState _stateOf(LineScanner scanner) {
  if (identical(scanner, _lastScanner)) return _lastState!;
  final state = _states[scanner] ??= _SearchState();
  _lastScanner = scanner;
  _lastState = state;
  return state;
}

/// Forgets the last scanner (no reference to a parsed text is kept).
void _releaseSearchState() {
  _lastScanner = null;
  _lastState = null;
}

final class _SearchState {
  final memo = Map<RegExp, _SearchMemo>.identity();
  final heaps = Map<List<RegExp>, _LeafHeap>.identity();
}

final class _SearchMemo {
  _SearchMemo(this.from, this.at);

  final int from;

  /// Leftmost match start at or after [from], or -1 for none.
  final int at;
}

/// Leftmost start of a match of [re] at or after [from] in the scanner's
/// string, or -1.
int _nextMatch(RegExp re, LineScanner scanner, int from) {
  final memo = _stateOf(scanner).memo;
  final m = memo[re];
  if (m != null && m.from <= from && (m.at < 0 || from <= m.at)) return m.at;
  final it = re.allMatches(scanner.string, from).iterator;
  final at = it.moveNext() ? it.current.start : -1;
  memo[re] = _SearchMemo(from, at);
  return at;
}

/// Whether a memoized search shows that [re] has no match starting at the
/// scanner's position.
bool _cannotMatchAt(RegExp re, LineScanner scanner) {
  final m = _stateOf(scanner).memo[re];
  if (m == null) return false;
  final pos = scanner.position;
  return m.from <= pos && (m.at < 0 || m.at > pos);
}

/// A min-heap of the next match positions of a leaf list (leaves without a
/// further match are dropped).
final class _LeafHeap {
  _LeafHeap(this.leaves);

  final List<RegExp> leaves;
  final _at = <int>[];
  final _leaf = <int>[];
  int _from = -1;

  int next(LineScanner scanner, int from) {
    if (from < _from || _from < 0) {
      _at.clear();
      _leaf.clear();
      for (var i = 0; i < leaves.length; i++) {
        final at = _nextMatch(leaves[i], scanner, from);
        if (at >= 0) _push(at, i);
      }
    } else {
      while (_at.isNotEmpty && _at[0] < from) {
        final i = _leaf[0];
        _pop();
        final at = _nextMatch(leaves[i], scanner, from);
        if (at >= 0) _push(at, i);
      }
    }
    _from = from;
    return _at.isEmpty ? -1 : _at[0];
  }

  void _push(int at, int leaf) {
    _at.add(at);
    _leaf.add(leaf);
    var i = _at.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (_at[parent] <= _at[i]) break;
      _swap(i, parent);
      i = parent;
    }
  }

  void _pop() {
    final last = _at.length - 1;
    _swap(0, last);
    _at.removeLast();
    _leaf.removeLast();
    var i = 0;
    final n = _at.length;
    while (true) {
      final l = 2 * i + 1, r = l + 1;
      var m = i;
      if (l < n && _at[l] < _at[m]) m = l;
      if (r < n && _at[r] < _at[m]) m = r;
      if (m == i) break;
      _swap(i, m);
      i = m;
    }
  }

  void _swap(int a, int b) {
    final t = _at[a];
    _at[a] = _at[b];
    _at[b] = t;
    final u = _leaf[a];
    _leaf[a] = _leaf[b];
    _leaf[b] = u;
  }
}

/// The leftmost position at or after the scanner's position where one of
/// [matchers] can match, -1 for none, or the current position when a rule
/// can't be analyzed (unknown include: the scan reports it as before).
int _nextCandidate(
  Grammar grammar,
  List<GrammarMatcher> matchers,
  LineScanner scanner,
) {
  final leaves = _listLeaves(grammar, matchers);
  final from = scanner.position;
  if (leaves == null) return from;
  if (leaves.isEmpty) return -1;
  final state = _stateOf(scanner);
  final heap = state.heaps[leaves] ??= _LeafHeap(leaves);
  return heap.next(scanner, from);
}

final _listLeafCache = Expando<List<RegExp>>('listLeafRegExps');
final _unanalyzable = Expando<bool>('unanalyzable');

/// The leaves of all [matchers] (cached per list), null when one can't be
/// analyzed.
List<RegExp>? _listLeaves(Grammar grammar, List<GrammarMatcher> matchers) {
  if (_unanalyzable[matchers] == true) return null;
  final cached = _listLeafCache[matchers];
  if (cached != null) return cached;
  final out = <RegExp>[];
  final ids = Set<RegExp>.identity();
  for (final m in matchers) {
    final leaves = _leaves(grammar, m);
    if (leaves == null) {
      _unanalyzable[matchers] = true;
      return null;
    }
    for (final r in leaves) {
      if (ids.add(r)) out.add(r);
    }
  }
  return _listLeafCache[matchers] = out;
}

/// The regexes [m] starts with (null when an include is unresolved).
List<RegExp>? _leaves(Grammar grammar, GrammarMatcher m) {
  final cached = _leafCache[m];
  if (cached != null) return cached;
  final out = <RegExp>[];
  final seen = Set<GrammarMatcher>.identity();
  bool walk(GrammarMatcher x) {
    if (!seen.add(x)) return true;
    switch (x) {
      case _SimpleMatcher():
        out.add(x.match);
      case _MultilineMatcher():
        out.add(x.begin);
      case _PatternMatcher():
        for (final p in x.patterns ?? const <GrammarMatcher>[]) {
          if (!walk(p)) return false;
        }
      case _IncludeMatcher():
        final target = grammar.repository.matchers[x.include];
        if (target == null) return false;
        return walk(target);
      default:
        return false;
    }
    return true;
  }

  if (!walk(m)) return null;
  // Identical regex objects only need one search.
  final unique = <RegExp>[];
  final ids = Set<RegExp>.identity();
  for (final r in out) {
    if (ids.add(r)) unique.add(r);
  }
  return _leafCache[m] = unique;
}
