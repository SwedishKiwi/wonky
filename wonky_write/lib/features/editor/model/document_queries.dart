import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';

import '../applier/delta_applier.dart';
import '../mapping/delta_node_codec.dart';
import '../mapping/document_mirror.dart';
import '../mapping/wonky_schema.dart';

/// One block (node) of the document with its Delta position.
class BlockRef {
  const BlockRef({
    required this.index,
    required this.node,
    required this.start,
    required this.length,
  });

  final int index;
  final DocumentNode node;

  /// Delta offset of the block's first character.
  final int start;

  /// Delta length including the line end(s).
  final int length;

  String get id => node.id;

  /// Delta offset of the block's final line end `"\n"`.
  int get lineEnd => start + length - 1;

  bool get isText => node is TextNode;

  bool get isEmbed => !isText;

  bool get isCode => isCodeBlockNode(node);

  /// The block attributes of the block's line end.
  Map<String, dynamic>? get blockAttributes =>
      WonkyDeltaSerializer.blockAttributesOf(node);

  @override
  String toString() =>
      'BlockRef($index ${node.runtimeType} $id @$start+$length)';
}

/// Read-only queries over the document mirror used by commands.
extension DocumentQueries on DocumentMirror {
  BlockRef blockAt(int index) {
    final entry = entryAt(index);
    return BlockRef(
      index: index,
      node: entry.node,
      start: startOfIndex(index),
      length: entry.length,
    );
  }

  BlockRef? blockOf(String nodeId) {
    final index = indexOfNode(nodeId);
    return index < 0 ? null : blockAt(index);
  }

  /// The block containing Delta [offset].
  BlockRef blockAtOffset(int offset) => blockAt(indexAtOffset(offset));

  /// Blocks touched by `[start, end]` (a collapsed range touches one block).
  List<BlockRef> blocksIn(int start, int end) {
    if (nodeCount == 0) return const [];
    final first = indexAtOffset(start);
    final last = indexAtOffset(end > start ? end - 1 : end);
    return [for (var i = first; i <= last; i += 1) blockAt(i)];
  }

  /// Blocks touched by [selection].
  List<BlockRef> blocksInSelection(DeltaSelection selection) =>
      blocksIn(selection.start, selection.end);

  /// Plain text of `[start, end)` (embeds as U+FFFC, line ends as `\n`).
  String textOf(int start, int end) {
    final buffer = StringBuffer();
    for (final op in slice(start, end).operations) {
      final data = op.data;
      buffer.write(data is String ? data : '￼');
    }
    return buffer.toString();
  }
}

/// Builds formatting changes over ranges, skipping ineligible characters.
abstract final class FormatChanges {
  /// A change that sets [attributes] (values `null` remove) on every
  /// character of `[start, end)` for which [eligible] returns true.
  ///
  /// [eligible] receives the base op piece (text or embed with its attributes)
  /// and the block it belongs to.
  static Delta format(
    DocumentMirror mirror,
    int start,
    int end,
    Map<String, dynamic> attributes, {
    required bool Function(Operation piece, BlockRef block) eligible,
  }) {
    final change = Delta()..retain(start);
    if (end <= start) return Delta();
    for (final block in mirror.blocksIn(start, end)) {
      final from = start > block.start ? start : block.start;
      final to = end < block.start + block.length
          ? end
          : block.start + block.length;
      if (to <= from) continue;
      var offset = block.start;
      for (final op in mirror.entryAt(block.index).delta.operations) {
        final opStart = offset;
        final opEnd = offset + op.length!;
        offset = opEnd;
        final s = opStart > from ? opStart : from;
        final e = opEnd < to ? opEnd : to;
        if (e <= s) continue;
        final data = op.data;
        if (data is! String) {
          final piece = Operation.insert(data, op.attributes);
          change.retain(
            1,
            eligible(piece, block) && _changes(op.attributes, attributes)
                ? attributes
                : null,
          );
          continue;
        }
        // Split at line ends so that text and "\n" are judged separately.
        final text = data.substring(s - opStart, e - opStart);
        var runStart = 0;
        for (var i = 0; i <= text.length; i += 1) {
          final atEnd = i == text.length;
          if (!atEnd && text.codeUnitAt(i) != 10) continue;
          if (i > runStart) {
            final piece = Operation.insert(
              text.substring(runStart, i),
              op.attributes,
            );
            change.retain(
              i - runStart,
              eligible(piece, block) && _changes(op.attributes, attributes)
                  ? attributes
                  : null,
            );
          }
          if (!atEnd) {
            final piece = Operation.insert('\n', op.attributes);
            change.retain(
              1,
              eligible(piece, block) && _changes(op.attributes, attributes)
                  ? attributes
                  : null,
            );
          }
          runStart = i + 1;
        }
      }
    }
    change.trim();
    return change;
  }

  static bool _changes(
    Map<String, dynamic>? current,
    Map<String, dynamic> attributes,
  ) {
    for (final entry in attributes.entries) {
      final value = current?[entry.key];
      if (value != entry.value) return true;
    }
    return false;
  }

  /// Whether a piece is ordinary text (not an embed and not a line end).
  static bool isInlineText(Operation piece) {
    final data = piece.data;
    return data is String && data != '\n' && !data.contains('\n');
  }
}
