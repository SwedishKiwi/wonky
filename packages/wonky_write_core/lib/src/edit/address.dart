/// Position and range addressing for headless edits (09 §1.1–§1.3).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../delta/delta_utils.dart';
import '../delta/document.dart';
import '../derived/outline.dart';

/// Error codes of address resolution (09 §1.3).
abstract final class AddressErrorCode {
  /// Schema violation of the address.
  static const invalidArgs = 'invalid_args';

  /// Offset outside `[0, doc_length)` or inside a surrogate pair.
  static const invalidOffset = 'invalid_offset';

  /// Range ends after the final line end.
  static const rangeOutOfBounds = 'range_out_of_bounds';

  /// Quote not found.
  static const quoteNotFound = 'quote_not_found';

  /// Quote found several times and no occurrence given.
  static const quoteAmbiguous = 'quote_ambiguous';

  /// Heading not found.
  static const headingNotFound = 'heading_not_found';

  /// Heading matched several times and no occurrence given.
  static const headingAmbiguous = 'heading_ambiguous';

  /// Referenced object (table, suggestion, …) does not exist.
  static const notFound = 'not_found';

  /// The result would violate the schema.
  static const validationFailed = 'validation_failed';

  /// The result exceeds the maximum document length or input limits.
  static const tooLarge = 'too_large';
}

/// Thrown when an address cannot be resolved.
final class AddressException implements Exception {
  /// Creates the exception.
  const AddressException(this.code, this.message, {this.details});

  /// One of [AddressErrorCode].
  final String code;

  /// Human-readable message.
  final String message;

  /// Structured details (e.g. `count` and `matches` for ambiguity).
  final Map<String, dynamic>? details;

  /// MCP error payload `{code, message, details}`.
  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'details': ?details,
  };

  @override
  String toString() => 'AddressException($code: $message)';
}

/// A resolved range of Delta offsets.
final class ResolvedRange {
  /// Creates a range.
  const ResolvedRange(this.start, this.length);

  /// Start offset.
  final int start;

  /// Length.
  final int length;

  /// End offset (exclusive).
  int get end => start + length;

  /// JSON form.
  Map<String, dynamic> toJson() => {'start': start, 'length': length};

  @override
  bool operator ==(Object other) =>
      other is ResolvedRange && other.start == start && other.length == length;

  @override
  int get hashCode => Object.hash(start, length);

  @override
  String toString() => 'ResolvedRange($start, $length)';
}

/// A heading reference: by text (case-insensitive, trimmed) with optional
/// level and occurrence, or by outline index.
final class HeadingRef {
  /// By text.
  const HeadingRef.text(String this.text, {this.level, this.occurrence})
    : index = null;

  /// By 0-based outline index.
  const HeadingRef.index(int this.index)
    : text = null,
      level = null,
      occurrence = null;

  /// Heading text.
  final String? text;

  /// Level filter.
  final int? level;

  /// 1-based occurrence among matches.
  final int? occurrence;

  /// Outline index.
  final int? index;

  /// Parses `{heading, level?, occurrence?}` / `{heading_index}`.
  static HeadingRef fromJson(Map<String, dynamic> json) {
    final idx = json['heading_index'];
    if (idx is int) return HeadingRef.index(idx);
    final h = json['heading'];
    if (h is! String || h.trim().isEmpty) {
      throw const AddressException(
        AddressErrorCode.invalidArgs,
        '"heading" or "heading_index" required',
      );
    }
    return HeadingRef.text(
      h,
      level: _optInt(json, 'level'),
      occurrence: _optInt(json, 'occurrence'),
    );
  }
}

int? _optInt(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is int) return v;
  throw AddressException(
    AddressErrorCode.invalidArgs,
    '"$key" must be an integer',
  );
}

int _reqInt(Map<String, dynamic> json, String key) {
  final v = _optInt(json, key);
  if (v == null) {
    throw AddressException(AddressErrorCode.invalidArgs, '"$key" is required');
  }
  return v;
}

String _reqQuote(Map<String, dynamic> json) {
  final q = json['quote'];
  if (q is! String || q.isEmpty || q.length > 2000) {
    throw const AddressException(
      AddressErrorCode.invalidArgs,
      '"quote" must be 1–2000 characters',
    );
  }
  return q;
}

/// Where to insert (09 §1.2 `Position`).
sealed class PositionAddress {
  const PositionAddress();

  /// Parses the MCP JSON form.
  static PositionAddress fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'start' => const StartPosition(),
      'end' => const EndPosition(),
      'offset' => OffsetPosition(_reqInt(json, 'offset')),
      'before_quote' => QuotePosition(
        _reqQuote(json),
        occurrence: _optInt(json, 'occurrence'),
        after: false,
      ),
      'after_quote' => QuotePosition(
        _reqQuote(json),
        occurrence: _optInt(json, 'occurrence'),
        after: true,
      ),
      'before_heading' => HeadingPosition(
        HeadingRef.fromJson(json),
        HeadingAnchor.before,
      ),
      'after_heading' => HeadingPosition(
        HeadingRef.fromJson(json),
        HeadingAnchor.after,
      ),
      'end_of_section' => HeadingPosition(
        HeadingRef.fromJson(json),
        HeadingAnchor.endOfSection,
      ),
      'replace_heading_section' => ReplaceSectionPosition(
        HeadingRef.fromJson(json),
        includeHeading: json['include_heading'] == true,
      ),
      _ => throw AddressException(
        AddressErrorCode.invalidArgs,
        'Unknown position type "${json['type']}"',
      ),
    };
  }
}

/// Document start.
final class StartPosition extends PositionAddress {
  /// Creates the position.
  const StartPosition();
}

/// Document end (end of the last line).
final class EndPosition extends PositionAddress {
  /// Creates the position.
  const EndPosition();
}

/// A Delta offset.
final class OffsetPosition extends PositionAddress {
  /// Creates the position.
  const OffsetPosition(this.offset);

  /// Offset.
  final int offset;
}

/// Before or after a quote.
final class QuotePosition extends PositionAddress {
  /// Creates the position.
  const QuotePosition(this.quote, {this.occurrence, required this.after});

  /// Quote text.
  final String quote;

  /// 1-based occurrence.
  final int? occurrence;

  /// After (true) or before the quote.
  final bool after;
}

/// Anchor relative to a heading.
enum HeadingAnchor {
  /// The heading line start.
  before,

  /// Right after the heading line.
  after,

  /// Before the next heading of the same or a higher level.
  endOfSection,
}

/// A position relative to a heading.
final class HeadingPosition extends PositionAddress {
  /// Creates the position.
  const HeadingPosition(this.heading, this.anchor);

  /// Heading.
  final HeadingRef heading;

  /// Anchor.
  final HeadingAnchor anchor;
}

/// Replace a heading section (body, plus the heading when [includeHeading]).
final class ReplaceSectionPosition extends PositionAddress {
  /// Creates the position.
  const ReplaceSectionPosition(this.heading, {this.includeHeading = false});

  /// Heading.
  final HeadingRef heading;

  /// Whether the heading line is replaced too.
  final bool includeHeading;
}

/// What to read or change (09 §1.2 `Range`).
sealed class RangeAddress {
  const RangeAddress();

  /// Parses the MCP JSON form.
  static RangeAddress fromJson(Map<String, dynamic> json) {
    return switch (json['type']) {
      'offsets' => OffsetsRange(
        _reqInt(json, 'start'),
        _reqInt(json, 'length'),
      ),
      'quote' => QuoteRange(
        _reqQuote(json),
        occurrence: _optInt(json, 'occurrence'),
      ),
      'heading_section' => HeadingSectionRange(
        HeadingRef.fromJson(json),
        includeHeading: json['include_heading'] != false,
      ),
      'block' => BlockRange(
        _reqInt(json, 'block_index'),
        count: _optInt(json, 'count') ?? 1,
      ),
      'all' => const AllRange(),
      _ => throw AddressException(
        AddressErrorCode.invalidArgs,
        'Unknown range type "${json['type']}"',
      ),
    };
  }
}

/// Explicit offsets.
final class OffsetsRange extends RangeAddress {
  /// Creates the range.
  const OffsetsRange(this.start, this.length);

  /// Start.
  final int start;

  /// Length.
  final int length;
}

/// A quote.
final class QuoteRange extends RangeAddress {
  /// Creates the range.
  const QuoteRange(this.quote, {this.occurrence});

  /// Quote text.
  final String quote;

  /// 1-based occurrence.
  final int? occurrence;
}

/// A heading section.
final class HeadingSectionRange extends RangeAddress {
  /// Creates the range.
  const HeadingSectionRange(this.heading, {this.includeHeading = true});

  /// Heading.
  final HeadingRef heading;

  /// Whether the heading line is included.
  final bool includeHeading;
}

/// Whole blocks of the blocks map ([DocumentBlocks]).
final class BlockRange extends RangeAddress {
  /// Creates the range.
  const BlockRange(this.blockIndex, {this.count = 1});

  /// First block index.
  final int blockIndex;

  /// Number of blocks.
  final int count;
}

/// The whole document.
final class AllRange extends RangeAddress {
  /// Creates the range.
  const AllRange();
}

/// One quote match.
final class QuoteMatch {
  /// Creates a match.
  const QuoteMatch(
    this.start,
    this.length,
    this.contextBefore,
    this.contextAfter,
  );

  /// Start offset.
  final int start;

  /// Length.
  final int length;

  /// Up to 40 characters before.
  final String contextBefore;

  /// Up to 40 characters after.
  final String contextAfter;

  /// JSON form.
  Map<String, dynamic> toJson() => {
    'start': start,
    'length': length,
    'context_before': contextBefore,
    'context_after': contextAfter,
  };
}

/// A block of the blocks map: a line, or a run of quote lines / code lines
/// (same grouping as the IR and the Markdown export).
final class DocumentBlockInfo {
  /// Creates block info.
  const DocumentBlockInfo({
    required this.index,
    required this.type,
    required this.start,
    required this.length,
    required this.firstLine,
    required this.lineCount,
  });

  /// 0-based block index.
  final int index;

  /// `paragraph`, `heading`, `bullet`, `ordered`, `task`, `quote`, `code`,
  /// `image`, `divider`, `table`.
  final String type;

  /// Delta start.
  final int start;

  /// Delta length (including line ends).
  final int length;

  /// First line index.
  final int firstLine;

  /// Number of lines.
  final int lineCount;
}

/// Computes the blocks map of a document.
abstract final class DocumentBlocks {
  /// Blocks of [doc] in order.
  static List<DocumentBlockInfo> of(WonkyDocument doc) {
    final blocks = <DocumentBlockInfo>[];
    final lines = doc.lines;
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final type = typeOf(line);
      var j = i + 1;
      if (type == 'quote' || type == 'code') {
        while (j < lines.length &&
            typeOf(lines[j]) == type &&
            (type != 'code' ||
                lines[j].format.language == line.format.language)) {
          j++;
        }
      }
      blocks.add(
        DocumentBlockInfo(
          index: blocks.length,
          type: type,
          start: line.start,
          length: lines[j - 1].end - line.start,
          firstLine: i,
          lineCount: j - i,
        ),
      );
      i = j;
    }
    return blocks;
  }

  /// Block type name of a line.
  static String typeOf(DocumentLine line) {
    if (line.isEmbedLine) {
      final t = line.embed?.type ?? 'paragraph';
      return t;
    }
    return switch (line.format.type.name) {
      'quote' => 'quote',
      'code' => 'code',
      'heading' => 'heading',
      'bullet' => 'bullet',
      'ordered' => 'ordered',
      'task' => 'task',
      _ => 'paragraph',
    };
  }
}

/// Resolves addresses against a document (head at execution time).
final class AddressResolver {
  /// Creates a resolver for [document].
  AddressResolver(Delta document) : doc = WonkyDocument(document);

  /// Creates a resolver for a parsed document.
  AddressResolver.of(this.doc);

  /// The document.
  final WonkyDocument doc;

  late final List<OutlineEntry> _outline = const OutlineExtractor().outlineOf(
    doc,
  );

  /// Validates an insertion offset (`[0, doc_length)`, not inside a
  /// surrogate pair).
  int checkOffset(int offset) {
    if (offset < 0 || offset >= doc.length) {
      throw AddressException(
        AddressErrorCode.invalidOffset,
        'Offset $offset outside [0, ${doc.length})',
        details: {'doc_length': doc.length},
      );
    }
    if (DeltaUtils.isInsideSurrogatePair(doc.text, offset)) {
      throw AddressException(
        AddressErrorCode.invalidOffset,
        'Offset $offset is inside a surrogate pair',
      );
    }
    return offset;
  }

  /// Validates a range: within the document, not splitting surrogate pairs.
  ResolvedRange checkRange(int start, int length) {
    if (length < 0) {
      throw const AddressException(
        AddressErrorCode.invalidArgs,
        'Negative length',
      );
    }
    checkOffset(start);
    if (start + length > doc.length) {
      throw AddressException(
        AddressErrorCode.rangeOutOfBounds,
        'Range ends after the final line end',
        details: {'doc_length': doc.length},
      );
    }
    if (start + length < doc.length &&
        DeltaUtils.isInsideSurrogatePair(doc.text, start + length)) {
      throw const AddressException(
        AddressErrorCode.invalidOffset,
        'Range end is inside a surrogate pair',
      );
    }
    return ResolvedRange(start, length);
  }

  /// All matches of [quote] (exact, case-sensitive) in the plain text.
  List<QuoteMatch> findQuote(String quote) {
    final text = doc.text;
    final matches = <QuoteMatch>[];
    var from = 0;
    while (true) {
      final i = text.indexOf(quote, from);
      if (i < 0) break;
      matches.add(
        QuoteMatch(
          i,
          quote.length,
          text.substring(i - 40 < 0 ? 0 : i - 40, i),
          text.substring(
            i + quote.length,
            (i + quote.length + 40).clamp(0, text.length),
          ),
        ),
      );
      from = i + 1;
    }
    return matches;
  }

  /// Resolves a quote with optional occurrence.
  ResolvedRange resolveQuote(String quote, int? occurrence) {
    final matches = findQuote(quote);
    if (matches.isEmpty) {
      throw AddressException(
        AddressErrorCode.quoteNotFound,
        'Quote not found',
        details: {'quote': quote},
      );
    }
    if (occurrence == null) {
      if (matches.length > 1) {
        throw AddressException(
          AddressErrorCode.quoteAmbiguous,
          'Quote occurs ${matches.length} times; pass "occurrence"',
          details: {
            'count': matches.length,
            'matches': [for (final m in matches.take(5)) m.toJson()],
          },
        );
      }
      return ResolvedRange(matches.first.start, quote.length);
    }
    if (occurrence < 1 || occurrence > matches.length) {
      throw AddressException(
        AddressErrorCode.quoteNotFound,
        'Occurrence $occurrence not found (${matches.length} matches)',
        details: {'count': matches.length},
      );
    }
    return ResolvedRange(matches[occurrence - 1].start, quote.length);
  }

  /// Resolves a heading reference to its outline entry.
  OutlineEntry resolveHeading(HeadingRef ref) {
    if (ref.index != null) {
      if (ref.index! < 0 || ref.index! >= _outline.length) {
        throw AddressException(
          AddressErrorCode.headingNotFound,
          'Heading index ${ref.index} out of range',
          details: {'count': _outline.length},
        );
      }
      return _outline[ref.index!];
    }
    final wanted = ref.text!.trim().toLowerCase();
    final matches = [
      for (final e in _outline)
        if (e.text.toLowerCase() == wanted &&
            (ref.level == null || e.level == ref.level))
          e,
    ];
    if (matches.isEmpty) {
      throw AddressException(
        AddressErrorCode.headingNotFound,
        'Heading "${ref.text}" not found',
      );
    }
    if (ref.occurrence == null) {
      if (matches.length > 1) {
        throw AddressException(
          AddressErrorCode.headingAmbiguous,
          'Heading "${ref.text}" occurs ${matches.length} times',
          details: {
            'count': matches.length,
            'matches': [
              for (final m in matches.take(5))
                {
                  'index': m.index,
                  'level': m.level,
                  'delta_start': m.deltaOffset,
                },
            ],
          },
        );
      }
      return matches.single;
    }
    if (ref.occurrence! < 1 || ref.occurrence! > matches.length) {
      throw AddressException(
        AddressErrorCode.headingNotFound,
        'Occurrence ${ref.occurrence} not found',
      );
    }
    return matches[ref.occurrence! - 1];
  }

  /// Resolves a range address.
  ResolvedRange resolveRange(RangeAddress address) {
    switch (address) {
      case OffsetsRange(:final start, :final length):
        return checkRange(start, length);
      case QuoteRange(:final quote, :final occurrence):
        return resolveQuote(quote, occurrence);
      case HeadingSectionRange(:final heading, :final includeHeading):
        final h = resolveHeading(heading);
        if (includeHeading) {
          return ResolvedRange(h.sectionStart, h.sectionLength);
        }
        final headingLine = doc.lines[h.lineIndex];
        return ResolvedRange(
          headingLine.end,
          h.sectionStart + h.sectionLength - headingLine.end,
        );
      case BlockRange(:final blockIndex, :final count):
        final blocks = DocumentBlocks.of(doc);
        if (blockIndex < 0 || count < 1 || blockIndex + count > blocks.length) {
          throw AddressException(
            AddressErrorCode.rangeOutOfBounds,
            'Blocks $blockIndex..${blockIndex + count - 1} out of range',
            details: {'block_count': blocks.length},
          );
        }
        final first = blocks[blockIndex];
        final last = blocks[blockIndex + count - 1];
        return ResolvedRange(
          first.start,
          last.start + last.length - first.start,
        );
      case AllRange():
        return ResolvedRange(0, doc.length);
    }
  }

  /// Resolves a position address to an insertion offset. For
  /// [ReplaceSectionPosition] use [resolveReplaceSection].
  int resolvePosition(PositionAddress address) {
    switch (address) {
      case StartPosition():
        return 0;
      case EndPosition():
        return doc.length - 1;
      case OffsetPosition(:final offset):
        return checkOffset(offset);
      case QuotePosition(:final quote, :final occurrence, :final after):
        final r = resolveQuote(quote, occurrence);
        return after ? r.end : r.start;
      case HeadingPosition(:final heading, :final anchor):
        final h = resolveHeading(heading);
        return switch (anchor) {
          HeadingAnchor.before => h.sectionStart,
          HeadingAnchor.after => doc.lines[h.lineIndex].end.clamp(
            0,
            doc.length - 1,
          ),
          HeadingAnchor.endOfSection =>
            (h.sectionStart + h.sectionLength).clamp(0, doc.length - 1),
        };
      case ReplaceSectionPosition():
        return resolveReplaceSection(address).start;
    }
  }

  /// The range replaced by a [ReplaceSectionPosition].
  ResolvedRange resolveReplaceSection(ReplaceSectionPosition p) => resolveRange(
    HeadingSectionRange(p.heading, includeHeading: p.includeHeading),
  );
}
