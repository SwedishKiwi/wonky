/// A run of uniformly formatted inline text and its Delta attributes
/// (Write 07 §2.1; shared by the Markdown inline codec).
library;

/// A run of text with uniform inline formatting.
final class InlineRun {
  /// Creates a run.
  const InlineRun(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.link,
    this.mentionUserUuid,
  });

  /// Text; may contain U+2028 (soft break), never `"\n"`.
  final String text;

  /// Bold.
  final bool bold;

  /// Italic.
  final bool italic;

  /// Strikethrough.
  final bool strike;

  /// Inline code.
  final bool code;

  /// Link target.
  final String? link;

  /// Mentioned user UUID (with a `mailto:` [link]).
  final String? mentionUserUuid;

  /// Whether formatting equals [other]'s.
  bool sameFormat(InlineRun other) =>
      bold == other.bold &&
      italic == other.italic &&
      strike == other.strike &&
      code == other.code &&
      link == other.link &&
      mentionUserUuid == other.mentionUserUuid;

  /// Whether the run has no formatting.
  bool get isPlain =>
      !bold &&
      !italic &&
      !strike &&
      !code &&
      link == null &&
      mentionUserUuid == null;

  /// Copy with changed fields.
  InlineRun copyWith({
    String? text,
    bool? bold,
    bool? italic,
    bool? strike,
    bool? code,
    String? link,
    bool clearLink = false,
    String? mentionUserUuid,
    bool clearMention = false,
  }) => InlineRun(
    text ?? this.text,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    strike: strike ?? this.strike,
    code: code ?? this.code,
    link: clearLink ? null : (link ?? this.link),
    mentionUserUuid: clearMention
        ? null
        : (mentionUserUuid ?? this.mentionUserUuid),
  );

  /// Delta attributes of this run (`null` when plain).
  Map<String, dynamic>? toAttributes() {
    final a = <String, dynamic>{
      if (bold && !code) 'bold': true,
      if (italic && !code) 'italic': true,
      if (strike && !code) 'strike': true,
      if (code) 'code': true,
      'link': ?link,
      'mention': ?mentionUserUuid,
    };
    return a.isEmpty ? null : a;
  }

  /// Reads a run from Delta attributes (overlays are ignored).
  factory InlineRun.fromAttributes(String text, Map<String, dynamic>? a) =>
      InlineRun(
        text,
        bold: a?['bold'] == true,
        italic: a?['italic'] == true,
        strike: a?['strike'] == true,
        code: a?['code'] == true,
        link: a?['link'] as String?,
        mentionUserUuid: a?['mention'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is InlineRun && other.text == text && sameFormat(other);

  @override
  int get hashCode =>
      Object.hash(text, bold, italic, strike, code, link, mentionUserUuid);

  @override
  String toString() {
    final f = [
      if (bold) 'b',
      if (italic) 'i',
      if (strike) 's',
      if (code) 'c',
      if (link != null) 'link=$link',
      if (mentionUserUuid != null) '@$mentionUserUuid',
    ];
    return 'Run("$text"${f.isEmpty ? '' : ' ${f.join(',')}'})';
  }

  /// Merges adjacent runs with equal formatting and drops empty runs.
  static List<InlineRun> merge(Iterable<InlineRun> runs) {
    final out = <InlineRun>[];
    for (final r in runs) {
      if (r.text.isEmpty) continue;
      if (out.isNotEmpty && out.last.sameFormat(r)) {
        out[out.length - 1] = out.last.copyWith(text: out.last.text + r.text);
      } else {
        out.add(r);
      }
    }
    return out;
  }

  /// Concatenated text of [runs].
  static String plainText(Iterable<InlineRun> runs) =>
      runs.map((r) => r.text).join();
}
