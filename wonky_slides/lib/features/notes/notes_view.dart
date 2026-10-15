import 'package:flutter/widgets.dart';
import 'package:wonky_rich_text/wonky_rich_text.dart' show Delta;
import 'package:wonky_slides_core/model.dart' show SlidesText;

/// One paragraph of speaker notes for the read-only view.
class NotesParagraph {
  const NotesParagraph(this.spans, {this.list, this.indent = 0});

  final List<InlineSpan> spans;

  /// `bullet` / `ordered` (02 §4.3 notes subset).
  final String? list;
  final int indent;
}

/// Splits speaker notes (Delta JSON, the notes subset of 02 §4.3) into
/// styled paragraphs: bold, italic, underline, strike, links and
/// highlights inline; bullet and numbered lists with indent per paragraph.
List<NotesParagraph> notesParagraphs(
  String? json, {
  required TextStyle base,
  required Color linkColor,
}) {
  Delta delta;
  try {
    delta = SlidesText.normalize(SlidesText.parse(json), notes: true);
  } on FormatException {
    return [
      NotesParagraph([TextSpan(text: SlidesText.plainText(json))]),
    ];
  }
  final out = <NotesParagraph>[];
  var spans = <InlineSpan>[];
  TextStyle styleOf(Map<String, dynamic>? a) {
    if (a == null || a.isEmpty) return base;
    final deco = <TextDecoration>[
      if (a['underline'] == true || a['link'] != null) TextDecoration.underline,
      if (a['strike'] == true) TextDecoration.lineThrough,
    ];
    final hl = a['highlight'];
    Color? bg;
    if (hl is String && hl.startsWith('#') && hl.length == 7) {
      final v = int.tryParse(hl.substring(1), radix: 16);
      if (v != null) bg = Color(0x66000000 | v);
    }
    return base.copyWith(
      fontWeight: a['bold'] == true ? FontWeight.w700 : null,
      fontStyle: a['italic'] == true ? FontStyle.italic : null,
      decoration: deco.isEmpty ? null : TextDecoration.combine(deco),
      color: a['link'] != null ? linkColor : null,
      backgroundColor: bg,
    );
  }

  for (final op in delta.toList()) {
    final data = op.data;
    if (data is! String) continue;
    final parts = data.split('\n');
    for (var i = 0; i < parts.length; i++) {
      final text = parts[i].replaceAll(' ', '\n');
      if (text.isNotEmpty) {
        spans.add(TextSpan(text: text, style: styleOf(op.attributes)));
      }
      if (i < parts.length - 1) {
        final a = op.attributes;
        final list = a?['list'];
        final indent = a?['indent'];
        out.add(
          NotesParagraph(
            spans,
            list: list is String ? list : null,
            indent: indent is int ? indent : 0,
          ),
        );
        spans = <InlineSpan>[];
      }
    }
  }
  if (spans.isNotEmpty) out.add(NotesParagraph(spans));
  return out;
}

/// The read-only rendering of speaker notes (viewers, and the pane while
/// not editing): one `Text.rich` per paragraph, list markers ("•", "1.")
/// with 18 px per indent level.
class NotesRichView extends StatelessWidget {
  const NotesRichView({
    super.key,
    required this.json,
    required this.style,
    required this.linkColor,
  });

  final String? json;
  final TextStyle style;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final paragraphs = notesParagraphs(json, base: style, linkColor: linkColor);
    final children = <Widget>[];
    final counters = <int, int>{};
    for (final p in paragraphs) {
      String? marker;
      if (p.list == 'ordered') {
        final n = (counters[p.indent] ?? 0) + 1;
        counters[p.indent] = n;
        counters.removeWhere((k, _) => k > p.indent);
        marker = '$n.';
      } else {
        counters.clear();
        if (p.list == 'bullet') marker = '•';
      }
      final text = Text.rich(TextSpan(children: p.spans, style: style));
      children.add(
        Padding(
          padding: EdgeInsets.only(left: 18.0 * p.indent, bottom: 2),
          child: marker == null
              ? (p.spans.isEmpty ? Text(' ', style: style) : text)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 18, child: Text(marker, style: style)),
                    Expanded(child: text),
                  ],
                ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
