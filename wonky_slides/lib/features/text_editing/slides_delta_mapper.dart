import 'package:super_editor/super_editor.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta, Operation;
import 'package:wonky_slides_core/model.dart' show SlidesText;
import 'package:wonky_slides_core/scene.dart' show TextBody;

/// Node metadata key of the Slides block attributes a super_editor node
/// doesn't model itself (`style`, `align`, `listStyle`, `listStart`,
/// `lineHeight`, `spaceBefore`, `spaceAfter`, `dir`; 02 §4.1).
const slidesBlockMetadataKey = 'slidesBlock';

/// The character super_editor stores for a soft line break inside a node
/// (Shift+Enter); the Delta stores U+2028 (02 §4.1).
const _nodeSoftBreak = '\n';
const _deltaSoftBreak = ' ';

/// An inline attribute of the Slides text schema that carries a value
/// (`font`, `weight`, `size`, `color`, `highlight`, `caps`,
/// `letterSpacing`). Spans with equal key and value merge; different values
/// of one key never overlap.
class SlidesValueAttribution implements Attribution {
  const SlidesValueAttribution(this.key, this.value);

  /// The Delta attribute key.
  final String key;

  /// The Delta attribute value (as stored).
  final Object value;

  @override
  String get id => 'slides.$key';

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) =>
      other is SlidesValueAttribution &&
      other.key == key &&
      other.value == value;

  @override
  int get hashCode => Object.hash(key, value);

  @override
  String toString() => '[SlidesValueAttribution $key=$value]';
}

/// Converts Slides text bodies (Wonky Slides Text Schema v1, 02 §4.1)
/// to super_editor documents and back, 1:1 per paragraph (03 §6.1):
///
/// - a paragraph is a [ParagraphNode], a [ListItemNode] (`list: bullet` /
///   `ordered`) or a [TaskNode] (`list: check` / `unchecked`); `indent` is
///   the node's indent; the other block attributes ride in the node
///   metadata under [slidesBlockMetadataKey];
/// - boolean inline attributes map to super_editor's own attributions
///   (`bold`, `italics`, `underline`, `strikethrough`, `code`, super/sub
///   script), `link` to [LinkAttribution] and every valued attribute to a
///   [SlidesValueAttribution];
/// - soft breaks are U+2028 in the Delta and `"\n"` inside a node.
///
/// Node `i` is paragraph `i` of the body, which the overlay's styler relies
/// on to take each paragraph's styles from the shared `TextParagraphs`
/// model.
class SlidesDeltaMapper {
  const SlidesDeltaMapper();

  /// The nodes of [body] (always at least one paragraph).
  List<DocumentNode> nodesFromBody(
    TextBody body, {
    String Function()? newNodeId,
  }) {
    final ids = newNodeId ?? Editor.createNodeId;
    final nodes = <DocumentNode>[];
    var runs = <(String, Map<String, Object?>)>[];
    for (final op in body.ops) {
      final insert = op['insert'];
      if (insert is! String) continue;
      final attrs = op['attributes'] is Map
          ? (op['attributes'] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      var from = 0;
      while (from <= insert.length) {
        final nl = insert.indexOf('\n', from);
        if (nl < 0) {
          if (from < insert.length) runs.add((insert.substring(from), attrs));
          break;
        }
        if (nl > from) runs.add((insert.substring(from, nl), attrs));
        nodes.add(_node(ids(), runs, attrs));
        runs = [];
        from = nl + 1;
      }
    }
    if (runs.isNotEmpty || nodes.isEmpty) {
      nodes.add(_node(ids(), runs, const {}));
    }
    return nodes;
  }

  /// A document of [body].
  MutableDocument documentFromBody(
    TextBody body, {
    String Function()? newNodeId,
  }) => MutableDocument(nodes: nodesFromBody(body, newNodeId: newNodeId));

  /// The Delta ops of [document] (not normalized; one paragraph per text
  /// node, other nodes are skipped).
  TextBody bodyOf(Document document) {
    final ops = <Map<String, Object?>>[];
    for (final node in document) {
      if (node is! TextNode) continue;
      final text = node.text;
      final plain = text.toPlainText(includePlaceholders: false);
      if (plain.isNotEmpty) {
        for (final span in text.spans.collapseSpans(
          contentLength: plain.length,
        )) {
          final inline = inlineOf(span.attributions);
          ops.add({
            'insert': plain
                .substring(span.start, span.end + 1)
                .replaceAll(_nodeSoftBreak, _deltaSoftBreak),
            if (inline.isNotEmpty) 'attributes': inline,
          });
        }
      }
      final block = blockAttributesOf(node);
      ops.add({'insert': '\n', if (block.isNotEmpty) 'attributes': block});
    }
    if (ops.isEmpty) ops.add({'insert': '\n'});
    return TextBody(ops);
  }

  /// The canonical (normalized) Delta of [document].
  Delta deltaOf(Document document) =>
      SlidesText.normalize(Delta.fromJson(bodyOf(document).ops));

  /// The stored JSON of [document] (normalized, 02 §4.1).
  String jsonOf(Document document) => SlidesText.encode(deltaOf(document));

  /// The block attributes (on `"\n"`) of [node].
  Map<String, Object?> blockAttributesOf(DocumentNode node) {
    final out = <String, Object?>{};
    final meta = node.getMetadataValue(slidesBlockMetadataKey);
    if (meta is Map) {
      for (final e in meta.entries) {
        if (e.value != null) out[e.key as String] = e.value;
      }
    }
    switch (node) {
      case ListItemNode():
        out['list'] = node.type == ListItemType.ordered ? 'ordered' : 'bullet';
        if (node.indent > 0) out['indent'] = node.indent;
      case TaskNode():
        out['list'] = node.isComplete ? 'check' : 'unchecked';
        if (node.indent > 0) out['indent'] = node.indent;
      case ParagraphNode():
        if (node.indent > 0) out['indent'] = node.indent;
    }
    return out;
  }

  DocumentNode _node(
    String id,
    List<(String, Map<String, Object?>)> runs,
    Map<String, Object?> block,
  ) {
    final text = AttributedText(
      runs.map((r) => r.$1).join().replaceAll(_deltaSoftBreak, _nodeSoftBreak),
    );
    var at = 0;
    for (final (t, inline) in runs) {
      if (t.isEmpty) continue;
      for (final a in attributionsOf(inline)) {
        text.addAttribution(a, SpanRange(at, at + t.length - 1));
      }
      at += t.length;
    }
    final indent = ((block['indent'] as num?)?.toInt() ?? 0).clamp(0, 8);
    final rest = <String, Object?>{
      for (final e in block.entries)
        if (e.key != 'list' && e.key != 'indent' && e.value != null)
          e.key: e.value,
    };
    final metadata = <String, dynamic>{
      if (rest.isNotEmpty) slidesBlockMetadataKey: rest,
    };
    switch (block['list']) {
      case 'bullet' || 'ordered':
        return ListItemNode(
          id: id,
          itemType: block['list'] == 'ordered'
              ? ListItemType.ordered
              : ListItemType.unordered,
          text: text,
          indent: indent,
          metadata: metadata,
        );
      case 'check' || 'unchecked':
        return TaskNode(
          id: id,
          text: text,
          isComplete: block['list'] == 'check',
          indent: indent,
          metadata: metadata,
        );
      default:
        return ParagraphNode(
          id: id,
          text: text,
          indent: indent,
          metadata: metadata,
        );
    }
  }

  /// The super_editor attributions of Delta [inline] attributes.
  static Iterable<Attribution> attributionsOf(
    Map<String, Object?> inline,
  ) sync* {
    for (final e in inline.entries) {
      final v = e.value;
      if (v == null) continue;
      switch (e.key) {
        case 'bold':
          yield boldAttribution;
        case 'italic':
          yield italicsAttribution;
        case 'underline':
          yield underlineAttribution;
        case 'strike':
          yield strikethroughAttribution;
        case 'code':
          yield codeAttribution;
        case 'script':
          yield v == 'sub' ? subscriptAttribution : superscriptAttribution;
        case 'link':
          yield LinkAttribution(v as String);
        default:
          yield SlidesValueAttribution(e.key, v);
      }
    }
  }

  /// The Delta inline attributes of super_editor [attributions] (content
  /// attributions only).
  static Map<String, Object?> inlineOf(Set<Attribution> attributions) {
    final out = <String, Object?>{};
    for (final a in attributions) {
      if (a == boldAttribution) {
        out['bold'] = true;
      } else if (a == italicsAttribution) {
        out['italic'] = true;
      } else if (a == underlineAttribution) {
        out['underline'] = true;
      } else if (a == strikethroughAttribution) {
        out['strike'] = true;
      } else if (a == codeAttribution) {
        out['code'] = true;
      } else if (a == superscriptAttribution) {
        out['script'] = 'super';
      } else if (a == subscriptAttribution) {
        out['script'] = 'sub';
      } else if (a is LinkAttribution) {
        out['link'] = a.plainTextUri;
      } else if (a is SlidesValueAttribution) {
        out[a.key] = a.value;
      }
      // Other attributions (spelling, composing, comments) aren't content.
    }
    return out;
  }
}

/// Compares two Delta bodies by content (attribute order doesn't matter).
bool sameDelta(Delta a, Delta b) {
  final x = a.operations, y = b.operations;
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (!_sameOp(x[i], y[i])) return false;
  }
  return true;
}

bool _sameOp(Operation a, Operation b) {
  if (a.key != b.key || a.data != b.data || a.length != b.length) {
    return false;
  }
  final p = a.attributes ?? const {}, q = b.attributes ?? const {};
  if (p.length != q.length) return false;
  for (final e in p.entries) {
    if (q[e.key] != e.value) return false;
  }
  return true;
}
