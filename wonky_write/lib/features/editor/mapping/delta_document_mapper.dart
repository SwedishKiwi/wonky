import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:super_editor/super_editor.dart';

import 'delta_node_codec.dart';

/// Converts whole documents between the Wonky Delta (canonical content) and a
/// super_editor [MutableDocument] (Write 02 §4).
///
/// Document → Delta uses super_editor's `toQuillDeltas` (patch SE-1) with the
/// Wonky node serializer; Delta → document builds nodes directly (one pass,
/// no editor round trips) so that large documents open quickly.
class DeltaDocumentMapper {
  const DeltaDocumentMapper({
    this.serializer = const WonkyDeltaSerializer(),
    this.parser = const WonkyDeltaParser(),
  });

  final WonkyDeltaSerializer serializer;
  final WonkyDeltaParser parser;

  /// Builds the nodes of [delta] (a document Delta that ends with `"\n"`).
  ///
  /// An empty Delta yields one empty paragraph.
  List<DocumentNode> nodesFromDelta(
    Delta delta, {
    String Function()? newNodeId,
  }) {
    final nodes = parser.parse(
      delta,
      newNodeId: newNodeId ?? Editor.createNodeId,
    );
    if (nodes.isEmpty) {
      return [
        ParagraphNode(
          id: (newNodeId ?? Editor.createNodeId)(),
          text: AttributedText(''),
        ),
      ];
    }
    return nodes;
  }

  /// Builds a [MutableDocument] from [delta].
  MutableDocument documentFromDelta(
    Delta delta, {
    String Function()? newNodeId,
  }) => MutableDocument(nodes: nodesFromDelta(delta, newNodeId: newNodeId));

  /// Serializes [document] to a canonical Wonky Delta.
  Delta deltaFromDocument(MutableDocument document) => document.toQuillDeltas(
    serializers: [serializer],
    omitTrailingEmptyParagraph: false,
  );

  /// Serializes a list of nodes (e.g. a selection fragment) to a Delta.
  Delta deltaFromNodes(Iterable<DocumentNode> nodes) {
    final delta = Delta();
    for (final node in nodes) {
      for (final op in serializer.serializeNode(node).operations) {
        delta.push(op);
      }
    }
    return delta;
  }
}
