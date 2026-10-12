import 'package:super_editor/super_editor.dart';

import '../mapping/delta_node_codec.dart';
import '../mapping/wonky_schema.dart';

/// Factories for embed nodes that carry their Wonky embed value
/// (Write 02 §1.3), so that they serialize to the right embed.
abstract final class EmbedNodes {
  /// A divider (`{"divider": {"id"}}`).
  static HorizontalRuleNode divider(String id) => HorizontalRuleNode(
    id: id,
    metadata: {
      WonkyNodeMetadata.embed: {
        DeltaKeys.dividerEmbed: {'id': id},
      },
    },
  );

  /// An image (`{"image": {"id", "src", "alt", "title"?}}`).
  static ImageNode image({
    required String id,
    required String src,
    String alt = '',
    String? title,
  }) => ImageNode(
    id: id,
    imageUrl: src,
    altText: alt,
    metadata: {
      WonkyNodeMetadata.embed: {
        DeltaKeys.imageEmbed: {
          'id': id,
          'src': src,
          'alt': alt,
          'title': ?title,
        },
      },
    },
  );

  /// A table (`{"table": {"id", "align", "rows"}}`).
  static TableBlockNode table({
    required String id,
    required List<String?> align,
    required List<List<String>> rows,
  }) {
    final value = <String, dynamic>{'id': id, 'align': align, 'rows': rows};
    return TableBlockNode(
      id: id,
      cells: WonkyDeltaParser.tableCellsFromEmbed(value),
      metadata: {
        WonkyNodeMetadata.embed: {DeltaKeys.tableEmbed: value},
      },
    );
  }

  /// The embed id stored in an embed node's value, or the node id.
  static String embedIdOf(DocumentNode node) {
    final value = WonkyDeltaSerializer.embedValueOf(node);
    final inner = value == null || value.isEmpty ? null : value.values.first;
    final id = inner is Map ? inner['id'] : null;
    return id is String ? id : node.id;
  }

  /// The embed type (`image`, `divider`, `table`) of an embed node.
  static String? embedTypeOf(DocumentNode node) {
    final value = WonkyDeltaSerializer.embedValueOf(node);
    return value == null || value.isEmpty ? null : value.keys.first;
  }

  /// The inner embed value (`{"id", …}`) of an embed node.
  static Map<String, dynamic>? embedDataOf(DocumentNode node) {
    final value = WonkyDeltaSerializer.embedValueOf(node);
    final inner = value == null || value.isEmpty ? null : value.values.first;
    return inner is Map ? inner.cast<String, dynamic>() : null;
  }
}
