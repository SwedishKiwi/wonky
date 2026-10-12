/// Markdown front matter (`---\n…\n---` at the top, 02 §2.1).
library;

/// Front matter helpers.
abstract final class FrontMatter {
  static final _open = RegExp(r'^---[ \t]*\n');
  static final _close = RegExp(r'^(?:---|\.\.\.)[ \t]*$', multiLine: true);

  /// Splits [source] into front matter (without fences, `null` when absent)
  /// and body. The body has the blank lines after the closing fence removed.
  static ({String? frontMatter, String body}) split(String source) {
    final open = _open.firstMatch(source);
    if (open == null) return (frontMatter: null, body: source);
    final rest = source.substring(open.end);
    final close = _close.firstMatch(rest);
    if (close == null) return (frontMatter: null, body: source);
    final fm = rest.substring(0, close.start);
    // The content must look like YAML (key: value lines, lists, comments) —
    // otherwise `---` is a thematic break.
    final lines = fm.split('\n').where((l) => l.trim().isNotEmpty);
    final yamlish = lines.every(
      (l) => RegExp(
        r'^(\s*#|\s*-\s|\s+\S|[A-Za-z0-9_\-"'
        "'"
        r']+\s*:)',
      ).hasMatch(l),
    );
    if (!yamlish) return (frontMatter: null, body: source);
    var body = rest.substring(close.end);
    body = body.replaceFirst(RegExp(r'^\n+'), '');
    final text = fm.endsWith('\n') ? fm.substring(0, fm.length - 1) : fm;
    return (frontMatter: text, body: body);
  }

  /// Re-emits front matter for export (`---\n<fm>\n---\n\n`).
  static String wrap(String frontMatter) =>
      '---\n${frontMatter.trimRight()}\n---\n\n';

  /// A top-level scalar field (`key: value`), unquoted; `null` if absent.
  static String? field(String? frontMatter, String key) {
    if (frontMatter == null) return null;
    final m = RegExp(
      '^${RegExp.escape(key)}\\s*:\\s*(.*)\$',
      multiLine: true,
    ).firstMatch(frontMatter);
    if (m == null) return null;
    var v = m.group(1)!.trim();
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
    }
    return v.isEmpty ? null : v;
  }

  /// The `title` field.
  static String? title(String? frontMatter) => field(frontMatter, 'title');

  /// `tags` as a list (`tags: [a, b]` or `tags: a, b`).
  static List<String> tags(String? frontMatter) {
    final v = field(frontMatter, 'tags');
    if (v == null) return const [];
    final inner = v.startsWith('[') && v.endsWith(']')
        ? v.substring(1, v.length - 1)
        : v;
    return [
      for (final t in inner.split(','))
        if (t.trim().isNotEmpty)
          t.trim().replaceAll(RegExp('^["\']|["\']\$'), ''),
    ];
  }
}
