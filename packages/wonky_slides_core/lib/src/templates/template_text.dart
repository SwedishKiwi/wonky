import 'dart:convert';

/// A run of text with inline attributes (02 §4.1: `bold`, `italic`,
/// `color` as a `ColorRef` string, `size` in su, `font`, …).
final class TemplateRun {
  /// Creates a run.
  const TemplateRun(this.text, [this.attributes = const {}]);

  /// Bold text.
  const TemplateRun.bold(this.text) : attributes = const {'bold': true};

  /// The characters (no line breaks; a paragraph ends with [TemplatePara]).
  final String text;

  /// Inline attributes.
  final Map<String, Object?> attributes;
}

/// A paragraph: runs plus block attributes (`style`, `align`, `list`,
/// `indent`, `spaceAfter`, …).
final class TemplatePara {
  /// A paragraph of plain [text] with block [attributes].
  TemplatePara(String text, [this.attributes = const {}])
    : runs = [TemplateRun(text)];

  /// A paragraph of [runs].
  const TemplatePara.runs(this.runs, [this.attributes = const {}]);

  /// The runs.
  final List<TemplateRun> runs;

  /// Block attributes.
  final Map<String, Object?> attributes;
}

/// Helpers that write the Delta JSON of template text bodies (02 §4.1).
abstract final class TemplateText {
  /// The Delta JSON of [paragraphs].
  static String delta(List<TemplatePara> paragraphs) {
    final ops = <Map<String, Object?>>[];
    for (final p in paragraphs) {
      for (final r in p.runs) {
        if (r.text.isEmpty) continue;
        ops.add({
          'insert': r.text,
          if (r.attributes.isNotEmpty) 'attributes': r.attributes,
        });
      }
      ops.add({
        'insert': '\n',
        if (p.attributes.isNotEmpty) 'attributes': p.attributes,
      });
    }
    if (ops.isEmpty) ops.add({'insert': '\n'});
    return jsonEncode(ops);
  }

  /// The Delta JSON of a template body: a `String` (one paragraph per
  /// line), a [TemplatePara] or a list of [TemplatePara]s.
  static String of(Object body) => switch (body) {
    final String s => delta([
      for (final line in s.split('\n')) TemplatePara(line),
    ]),
    final TemplatePara p => delta([p]),
    final List<TemplatePara> l => delta(l),
    _ => throw ArgumentError.value(
      body,
      'body',
      'String, TemplatePara or List<TemplatePara>',
    ),
  };

  /// Bullet paragraphs; a leading `- ` indents an item one level. (The
  /// text engines draw list markers from paragraph attributes only, so the
  /// placeholders' default `list` is written out.)
  static List<TemplatePara> bullets(List<String> items) =>
      _list(items, 'bullet');

  /// Numbered paragraphs (agendas, steps); `- ` indents.
  static List<TemplatePara> numbered(List<String> items) =>
      _list(items, 'ordered');

  static List<TemplatePara> _list(List<String> items, String kind) => [
    for (final i in items)
      i.startsWith('- ')
          ? TemplatePara(i.substring(2), {'list': kind, 'indent': 1})
          : TemplatePara(i, {'list': kind}),
  ];

  /// The plain text of a template body (search text, previews).
  static String plain(Object body) => switch (body) {
    final String s => s,
    final TemplatePara p => p.runs.map((r) => r.text).join(),
    final List<TemplatePara> l => l.map(plain).join('\n'),
    _ => '',
  };
}
