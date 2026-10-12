/// Line-structured, read-only view of a document Delta.
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import 'attributes.dart';
import 'delta_utils.dart';
import 'embeds.dart';

/// A text or embed segment of a line (never contains the line-end `"\n"`).
final class LineSegment {
  /// Creates a segment.
  const LineSegment({required this.start, required this.data, this.attributes});

  /// Absolute Delta offset of the segment.
  final int start;

  /// `String` text or the embed `insert` value (`Map`).
  final Object data;

  /// Attributes of the segment (`null` = none).
  final Map<String, dynamic>? attributes;

  /// Whether this is an embed.
  bool get isEmbed => data is! String;

  /// Text of the segment ([embedChar] for embeds).
  String get text => data is String ? data as String : embedChar;

  /// Delta length (embeds count 1).
  int get length => data is String ? (data as String).length : 1;

  /// Absolute end offset (exclusive).
  int get end => start + length;
}

/// One line of a document: content segments plus the line-end `"\n"`.
final class DocumentLine {
  /// Creates a line.
  DocumentLine({
    required this.index,
    required this.start,
    required this.segments,
    required this.attributes,
    this.hasNewline = true,
  });

  /// 0-based line index.
  final int index;

  /// Absolute Delta offset of the first character.
  final int start;

  /// Content segments (no `"\n"`).
  final List<LineSegment> segments;

  /// Attributes of the line-end `"\n"` (block + overlay), never null.
  final Map<String, dynamic> attributes;

  /// `false` only for a trailing fragment of an invalid document that does
  /// not end with `"\n"`.
  final bool hasNewline;

  /// Length of the content (without the `"\n"`).
  late final int contentLength = segments.fold(0, (n, s) => n + s.length);

  /// Delta length including the line end.
  int get length => contentLength + (hasNewline ? 1 : 0);

  /// Absolute offset of the line-end `"\n"`.
  int get newlineOffset => start + contentLength;

  /// Absolute end offset (exclusive, after the `"\n"`).
  int get end => start + length;

  /// Content text (embeds as [embedChar]).
  late final String text = segments.map((s) => s.text).join();

  /// Block format from the line-end attributes.
  late final BlockFormat format = BlockFormat.fromAttributes(attributes);

  /// Block attributes of the line end (no overlays).
  Map<String, dynamic> get blockAttributes => Attributes.block(attributes);

  /// The embed when this line is an embed line (exactly one embed segment).
  late final WonkyEmbed? embed = segments.length == 1 && segments.first.isEmbed
      ? WonkyEmbed.tryParse(segments.first.data)
      : null;

  /// Whether the line holds exactly one embed segment (valid or not).
  bool get isEmbedLine => segments.length == 1 && segments.first.isEmbed;

  /// Whether the content is empty.
  bool get isEmpty => segments.isEmpty;

  /// Whether absolute offset [offset] lies within this line (including the
  /// line end).
  bool contains(int offset) => offset >= start && offset < end;

  @override
  String toString() => 'DocumentLine($index @$start "$text" $attributes)';
}

/// A parsed, line-structured view of a document Delta (inserts only).
///
/// Construction is O(ops); lookups by offset are O(log lines).
final class WonkyDocument {
  /// Parses [delta]. Non-insert ops throw an [ArgumentError].
  WonkyDocument(this.delta) {
    final lines = <DocumentLine>[];
    var segments = <LineSegment>[];
    var lineStart = 0;
    var offset = 0;
    for (final op in delta.operations) {
      if (!op.isInsert) {
        throw ArgumentError.value(delta, 'delta', 'not a document delta');
      }
      final data = op.data;
      final attrs = Attributes.orNull(op.attributes);
      if (data is String) {
        var from = 0;
        while (from < data.length) {
          final nl = data.indexOf('\n', from);
          if (nl < 0) {
            segments.add(
              LineSegment(
                start: offset + from,
                data: data.substring(from),
                attributes: attrs,
              ),
            );
            break;
          }
          if (nl > from) {
            segments.add(
              LineSegment(
                start: offset + from,
                data: data.substring(from, nl),
                attributes: attrs,
              ),
            );
          }
          lines.add(
            DocumentLine(
              index: lines.length,
              start: lineStart,
              segments: segments,
              attributes: attrs ?? const {},
            ),
          );
          segments = <LineSegment>[];
          lineStart = offset + nl + 1;
          from = nl + 1;
        }
        offset += data.length;
      } else if (data != null) {
        segments.add(LineSegment(start: offset, data: data, attributes: attrs));
        offset += 1;
      }
    }
    if (segments.isNotEmpty) {
      lines.add(
        DocumentLine(
          index: lines.length,
          start: lineStart,
          segments: segments,
          attributes: const {},
          hasNewline: false,
        ),
      );
    }
    this.lines = List.unmodifiable(lines);
    length = offset;
  }

  /// Parses a Delta JSON list.
  factory WonkyDocument.fromJson(List<dynamic> json) =>
      WonkyDocument(Delta.fromJson(json));

  /// The underlying document delta.
  final Delta delta;

  /// All lines in order.
  late final List<DocumentLine> lines;

  /// Total Delta length (including the final `"\n"`).
  late final int length;

  /// Addressing plain text: embeds as [embedChar], soft breaks kept, offsets
  /// equal Delta offsets.
  late final String text = DeltaUtils.text(delta);

  /// Index of the line containing [offset] (an offset equal to [length]
  /// maps to the last line).
  int lineIndexAt(int offset) {
    if (lines.isEmpty) return 0;
    var lo = 0;
    var hi = lines.length - 1;
    if (offset >= lines.last.start) return hi;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lines[mid].start <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// The line containing [offset].
  DocumentLine lineAt(int offset) => lines[lineIndexAt(offset)];

  /// Lines intersecting `[start, start + length)` (a collapsed range returns
  /// the line containing [start]).
  List<DocumentLine> linesInRange(int start, int length) {
    if (lines.isEmpty) return const [];
    final first = lineIndexAt(start);
    final last = length <= 0 ? first : lineIndexAt(start + length - 1);
    return lines.sublist(first, last + 1);
  }

  /// Attributes of the character at [offset], or `null` when out of range.
  Map<String, dynamic>? attributesAt(int offset) {
    if (offset < 0 || offset >= length) return null;
    final line = lineAt(offset);
    if (offset == line.newlineOffset) return line.attributes;
    for (final s in line.segments) {
      if (offset >= s.start && offset < s.end) return s.attributes ?? const {};
    }
    return null;
  }

  /// The document slice `[start, start + length)` as a document delta.
  Delta slice(int start, int length) => delta.slice(start, start + length);

  /// All embeds with their absolute offsets, in document order.
  Iterable<(int offset, WonkyEmbed embed)> get embeds sync* {
    for (final line in lines) {
      for (final s in line.segments) {
        if (!s.isEmbed) continue;
        final e = WonkyEmbed.tryParse(s.data);
        if (e != null) yield (s.start, e);
      }
    }
  }
}
