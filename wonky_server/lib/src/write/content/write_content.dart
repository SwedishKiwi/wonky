import 'package:uuid/uuid.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/common/models.dart';

/// Conversions between Markdown/plain text and Write document deltas for
/// server-side creation (templates, imports, MCP).
abstract final class WriteContent {
  /// Converts Markdown to a normalized document delta.
  static ({Delta delta, List<ImportWarningView> warnings}) fromMarkdown(
    String markdown,
  ) {
    final delta = Delta();
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    String? fence;
    for (final raw in lines) {
      final line = raw.replaceAll('\t', '    ');
      if (fence != null) {
        if (line.trimLeft().startsWith('```')) {
          fence = null;
          continue;
        }
        if (line.isNotEmpty) delta.insert(line);
        delta.insert('\n', {'code-block': fence});
        continue;
      }
      final fenceMatch = RegExp(r'^\s*```\s*([A-Za-z0-9_+#.\-]*)').firstMatch(
        line,
      );
      if (fenceMatch != null) {
        fence = fenceMatch.group(1) ?? '';
        continue;
      }
      if (line.trim().isEmpty) continue;
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        _inline(delta, heading.group(2)!);
        delta.insert('\n', {'header': heading.group(1)!.length});
        continue;
      }
      if (RegExp(r'^\s*(-{3,}|\*{3,})\s*$').hasMatch(line)) {
        delta.insert({'divider': {'id': _id()}});
        delta.insert('\n');
        continue;
      }
      final task = RegExp(r'^(\s*)[-*+]\s+\[( |x|X)\]\s+(.*)$').firstMatch(line);
      if (task != null) {
        _inline(delta, task.group(3)!);
        delta.insert('\n', {
          'list': task.group(2) == ' ' ? 'unchecked' : 'checked',
          ..._indent(task.group(1)!),
        });
        continue;
      }
      final bullet = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        _inline(delta, bullet.group(2)!);
        delta.insert('\n', {'list': 'bullet', ..._indent(bullet.group(1)!)});
        continue;
      }
      final ordered = RegExp(r'^(\s*)\d+[.)]\s+(.*)$').firstMatch(line);
      if (ordered != null) {
        _inline(delta, ordered.group(2)!);
        delta.insert('\n', {'list': 'ordered', ..._indent(ordered.group(1)!)});
        continue;
      }
      final quote = RegExp(r'^\s*>\s?(.*)$').firstMatch(line);
      if (quote != null) {
        _inline(delta, quote.group(1)!);
        delta.insert('\n', {'blockquote': true});
        continue;
      }
      _inline(delta, line.trim());
      delta.insert('\n');
    }
    if (delta.isEmpty) delta.insert('\n');
    final normalized = const WonkyDeltaNormalizer().normalize(delta).document;
    return (delta: normalized, warnings: const []);
  }

  /// Converts plain text (one paragraph per line) to a document delta.
  static Delta fromPlainText(String text) {
    final delta = Delta();
    for (final line in text.replaceAll('\r\n', '\n').split('\n')) {
      if (line.isNotEmpty) delta.insert(line.replaceAll('\t', '    '));
      delta.insert('\n');
    }
    return const WonkyDeltaNormalizer().normalize(delta).document;
  }

  static Map<String, Object> _indent(String leading) {
    final level = (leading.length ~/ 2).clamp(0, 8);
    return level == 0 ? const {} : {'indent': level};
  }

  static final _inlinePattern = RegExp(
    r'(\*\*[^*]+\*\*)|(~~[^~]+~~)|(`[^`]+`)|(\*[^*]+\*)|(_[^_]+_)|(\[[^\]]+\]\([^)\s]+\))',
  );

  static void _inline(Delta delta, String text) {
    var index = 0;
    for (final m in _inlinePattern.allMatches(text)) {
      if (m.start > index) delta.insert(text.substring(index, m.start));
      final s = m[0]!;
      if (m[1] != null) {
        delta.insert(s.substring(2, s.length - 2), {'bold': true});
      } else if (m[2] != null) {
        delta.insert(s.substring(2, s.length - 2), {'strike': true});
      } else if (m[3] != null) {
        delta.insert(s.substring(1, s.length - 1), {'code': true});
      } else if (m[4] != null || m[5] != null) {
        delta.insert(s.substring(1, s.length - 1), {'italic': true});
      } else {
        final link = RegExp(r'^\[([^\]]+)\]\(([^)\s]+)\)$').firstMatch(s)!;
        delta.insert(link.group(1)!, {'link': link.group(2)!});
      }
      index = m.end;
    }
    if (index < text.length) delta.insert(text.substring(index));
  }

  static String _id() => const Uuid().v7();
}
