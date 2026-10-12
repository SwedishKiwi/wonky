/// Text search over the plain text of a document (09 §2.1 `write.search`,
/// find & replace).
library;

import '../delta/delta_utils.dart';
import '../delta/document.dart';
import '../derived/outline.dart';
import 'address.dart';

/// A search query.
final class FindSpec {
  /// Creates a query.
  const FindSpec(
    this.query, {
    this.regex = false,
    this.matchCase = false,
    this.wholeWord = false,
  });

  /// Literal text, or a pattern when [regex].
  final String query;

  /// Interpret [query] as a Dart `RegExp` (unicode).
  final bool regex;

  /// Case-sensitive matching.
  final bool matchCase;

  /// Only matches delimited by non-word characters.
  final bool wholeWord;

  /// The compiled pattern. Throws [AddressException] (`invalid_args`) for
  /// an invalid regex or empty query.
  RegExp compile() {
    if (query.isEmpty) {
      throw const AddressException(AddressErrorCode.invalidArgs, 'Empty query');
    }
    try {
      return RegExp(
        regex ? query : RegExp.escape(query),
        caseSensitive: matchCase,
        unicode: true,
        multiLine: true,
      );
    } on FormatException catch (e) {
      throw AddressException(
        AddressErrorCode.invalidArgs,
        'Invalid regex: ${e.message}',
      );
    }
  }
}

/// One search match.
final class SearchMatch {
  /// Creates a match.
  const SearchMatch({
    required this.start,
    required this.length,
    required this.text,
    required this.occurrence,
    required this.contextBefore,
    required this.contextAfter,
    required this.blockIndex,
    required this.headingPath,
    required this.groups,
  });

  /// Start offset.
  final int start;

  /// Length.
  final int length;

  /// Matched text.
  final String text;

  /// 1-based index of this exact text among all its occurrences in the
  /// document (usable for quote addressing).
  final int occurrence;

  /// Context before.
  final String contextBefore;

  /// Context after.
  final String contextAfter;

  /// Index in the blocks map.
  final int blockIndex;

  /// Texts of the enclosing headings (outermost first).
  final List<String> headingPath;

  /// Regex capture groups (index 0 = whole match).
  final List<String?> groups;

  /// JSON form (MCP).
  Map<String, dynamic> toJson() => {
    'start': start,
    'length': length,
    'text': text,
    'occurrence': occurrence,
    'context_before': contextBefore,
    'context_after': contextAfter,
    'block_index': blockIndex,
    'heading_path': headingPath,
  };
}

/// Result of [TextSearch.search].
final class SearchResult {
  /// Creates a result.
  const SearchResult(this.total, this.matches, {required this.truncated});

  /// Total number of matches.
  final int total;

  /// Returned matches (at most the limit).
  final List<SearchMatch> matches;

  /// Whether [total] exceeds the returned matches.
  final bool truncated;
}

/// Searches documents.
final class TextSearch {
  /// Creates a searcher over [doc].
  TextSearch(this.doc);

  /// The document.
  final WonkyDocument doc;

  static final _word = RegExp(r'[\p{L}\p{N}\p{M}_]', unicode: true);

  /// Finds matches of [spec] inside [scope] (whole document by default).
  /// Matches never span a line end or an embed.
  SearchResult search(
    FindSpec spec, {
    ResolvedRange? scope,
    int limit = 100,
    int contextChars = 40,
  }) {
    final pattern = spec.compile();
    final text = doc.text;
    final from = scope?.start ?? 0;
    final to = scope?.end ?? text.length;
    final all = <RegExpMatch>[];
    for (final m in pattern.allMatches(text, from)) {
      if (m.end > to) break;
      if (m.end == m.start) continue;
      final s = text.substring(m.start, m.end);
      if (s.contains('\n') || s.contains(embedChar)) continue;
      if (spec.wholeWord) {
        final before = m.start > 0 ? text[m.start - 1] : ' ';
        final after = m.end < text.length ? text[m.end] : ' ';
        if (_word.hasMatch(before) || _word.hasMatch(after)) continue;
      }
      all.add(m);
    }
    final blocks = DocumentBlocks.of(doc);
    final outline = const OutlineExtractor().outlineOf(doc);
    final occurrenceCache = <String, List<int>>{};
    final matches = <SearchMatch>[];
    for (final m in all.take(limit)) {
      final s = text.substring(m.start, m.end);
      final positions = occurrenceCache.putIfAbsent(s, () {
        final list = <int>[];
        var i = text.indexOf(s);
        while (i >= 0) {
          list.add(i);
          i = text.indexOf(s, i + 1);
        }
        return list;
      });
      matches.add(
        SearchMatch(
          start: m.start,
          length: m.end - m.start,
          text: s,
          occurrence: positions.indexOf(m.start) + 1,
          contextBefore: text.substring(
            (m.start - contextChars).clamp(0, text.length),
            m.start,
          ),
          contextAfter: text.substring(
            m.end,
            (m.end + contextChars).clamp(0, text.length),
          ),
          blockIndex: _blockIndex(blocks, m.start),
          headingPath: headingPath(outline, m.start),
          groups: [for (var g = 0; g <= m.groupCount; g++) m.group(g)],
        ),
      );
    }
    return SearchResult(
      all.length,
      matches,
      truncated: all.length > matches.length,
    );
  }

  static int _blockIndex(List<DocumentBlockInfo> blocks, int offset) {
    var lo = 0;
    var hi = blocks.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (blocks[mid].start <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// Texts of the headings enclosing [offset] (outermost first).
  static List<String> headingPath(List<OutlineEntry> outline, int offset) {
    final stack = <OutlineEntry>[];
    for (final e in outline) {
      if (e.deltaOffset > offset) break;
      while (stack.isNotEmpty && stack.last.level >= e.level) {
        stack.removeLast();
      }
      stack.add(e);
    }
    return [for (final e in stack) e.text];
  }
}
