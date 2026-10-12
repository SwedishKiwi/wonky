import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart' show DriveItemView;
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show OutlineEntry;

/// Document languages (BCP-47 with native names), Write 05 §12.7.
const documentLanguages = <String, String>{
  'en-US': 'English (United States)',
  'en-GB': 'English (United Kingdom)',
  'en-AU': 'English (Australia)',
  'en-CA': 'English (Canada)',
  'sv-SE': 'Svenska',
  'da-DK': 'Dansk',
  'nb-NO': 'Norsk bokmål',
  'fi-FI': 'Suomi',
  'de-DE': 'Deutsch',
  'de-CH': 'Deutsch (Schweiz)',
  'fr-FR': 'Français',
  'fr-CA': 'Français (Canada)',
  'es-ES': 'Español (España)',
  'es-MX': 'Español (México)',
  'it-IT': 'Italiano',
  'pt-PT': 'Português (Portugal)',
  'pt-BR': 'Português (Brasil)',
  'nl-NL': 'Nederlands',
  'pl-PL': 'Polski',
  'cs-CZ': 'Čeština',
  'sk-SK': 'Slovenčina',
  'hu-HU': 'Magyar',
  'ro-RO': 'Română',
  'el-GR': 'Ελληνικά',
  'tr-TR': 'Türkçe',
  'ru-RU': 'Русский',
  'uk-UA': 'Українська',
  'he-IL': 'עברית',
  'ar': 'العربية',
  'hi-IN': 'हिन्दी',
  'th-TH': 'ไทย',
  'vi-VN': 'Tiếng Việt',
  'id-ID': 'Bahasa Indonesia',
  'ja-JP': '日本語',
  'ko-KR': '한국어',
  'zh-CN': '中文（简体）',
  'zh-TW': '中文（繁體）',
};

/// The display name of a language tag.
String languageName(String? tag) =>
    tag == null ? 'Not set' : (documentLanguages[tag] ?? tag);

/// Document language (`write.dialog.language`). Returns the tag.
Future<String?> showLanguageDialog(BuildContext context, {String? current}) =>
    showShadDialog<String>(
      context: context,
      builder: (context) => _LanguageDialog(current: current),
    );

class _LanguageDialog extends StatefulWidget {
  const _LanguageDialog({this.current});
  final String? current;

  @override
  State<_LanguageDialog> createState() => _LanguageDialogState();
}

class _LanguageDialogState extends State<_LanguageDialog> {
  late String _value = widget.current ?? 'en-US';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final options = documentLanguages.entries.where(
      (e) =>
          _search.isEmpty ||
          e.value.toLowerCase().contains(_search.toLowerCase()) ||
          e.key.toLowerCase().contains(_search.toLowerCase()),
    );
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.language'),
      title: const Text('Document language'),
      description: const Text(
        'Used for spelling, hyphenation in exports and screen readers.',
      ),
      constraints: const BoxConstraints(maxWidth: 420),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(
          key: const ValueKey<String>('write.dialog.language.ok'),
          onPressed: () => Navigator.of(context).pop(_value),
          child: const Text('OK'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ShadSelect<String>.withSearch(
          key: const ValueKey<String>('write.dialog.language.select'),
          initialValue: _value,
          minWidth: 360,
          maxHeight: 320,
          searchPlaceholder: const Text('Search languages'),
          onSearchChanged: (v) => setState(() => _search = v),
          options: [
            for (final e in options)
              ShadOption(value: e.key, child: Text('${e.value}  ·  ${e.key}')),
          ],
          selectedOptionBuilder: (context, v) => Text(languageName(v)),
          onChanged: (v) => setState(() => _value = v ?? _value),
        ),
      ),
    );
  }
}

/// Document details (`write.dialog.properties`, Write 05 §12.8). Returns the
/// edited front matter (null when unchanged / cancelled).
Future<String?> showDocumentDetailsDialog(
  BuildContext context, {
  required DriveItemView? item,
  required String location,
  required int words,
  required String language,
  required String themeName,
  required int revision,
  required String? frontMatter,
  required bool canEdit,
}) => showShadDialog<String>(
  context: context,
  builder: (_) => _DetailsDialog(
    item: item,
    location: location,
    words: words,
    language: language,
    themeName: themeName,
    revision: revision,
    frontMatter: frontMatter,
    canEdit: canEdit,
  ),
);

class _DetailsDialog extends StatefulWidget {
  const _DetailsDialog({
    required this.item,
    required this.location,
    required this.words,
    required this.language,
    required this.themeName,
    required this.revision,
    required this.frontMatter,
    required this.canEdit,
  });

  final DriveItemView? item;
  final String location;
  final int words;
  final String language;
  final String themeName;
  final int revision;
  final String? frontMatter;
  final bool canEdit;

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final _fm = TextEditingController(text: widget.frontMatter ?? '');
  String? _error;

  @override
  void dispose() {
    _fm.dispose();
    super.dispose();
  }

  /// Minimal YAML sanity check: `key: value` lines, lists, comments.
  String? _validate(String text) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.trim().isEmpty || l.trimLeft().startsWith('#')) continue;
      if (l.trim() == '---') return 'Line ${i + 1}: remove the --- fences';
      final isList = l.trimLeft().startsWith('- ');
      final isContinuation = l.startsWith(' ') || l.startsWith('\t');
      if (!isList && !isContinuation && !l.contains(':')) {
        return 'Line ${i + 1}: expected "key: value"';
      }
    }
    return null;
  }

  void _save() {
    final text = _fm.text.trimRight();
    final error = _validate(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(text == (widget.frontMatter ?? '') ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final i = widget.item;
    final date = intl.DateFormat.yMMMd('en_US').add_jm();
    String size(int bytes) => bytes < 1024
        ? '$bytes B'
        : bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(1)} KB'
        : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    final rows = <(String, String)>[
      ('Title', i?.name ?? ''),
      ('Location', widget.location),
      if (i != null) ('Owner', i.owner.displayName),
      if (i != null) ('Created', date.format(i.createdAt.toLocal())),
      if (i != null)
        (
          'Modified',
          '${date.format(i.modifiedAt.toLocal())}'
              '${i.modifiedBy == null ? '' : ' by ${i.modifiedBy!.displayName}'}',
        ),
      if (i != null) ('Size', size(i.sizeBytes)),
      ('Words', intl.NumberFormat.decimalPattern('en_US').format(widget.words)),
      ('Language', widget.language),
      ('Theme', widget.themeName),
      ('Revision', '${widget.revision}'),
    ];
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.properties'),
      title: const Text('Document details'),
      constraints: const BoxConstraints(maxWidth: 560),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (widget.canEdit)
          ShadButton(
            key: const ValueKey<String>('write.dialog.properties.save'),
            onPressed: _save,
            child: const Text('Save'),
          ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(k, style: theme.textTheme.muted),
                  ),
                  Expanded(child: Text(v, style: theme.textTheme.small)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text('Front matter (YAML)', style: theme.textTheme.small),
          const SizedBox(height: 6),
          ShadTextarea(
            key: const ValueKey<String>('write.dialog.properties.frontMatter'),
            controller: _fm,
            readOnly: !widget.canEdit,
            minHeight: 96,
            maxHeight: 220,
            placeholder: const Text('title: My document\ntags: [notes]'),
            style: TextStyle(
              fontFamily: WonkyTheme.monoFamily,
              fontSize: 13,
              color: theme.colorScheme.foreground,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Read-only Markdown source (`write.dialog.markdownSource`, Write 05
/// §12.12) with line numbers, wrap toggle, Copy and Download.
Future<void> showMarkdownSourceDialog(
  BuildContext context, {
  required String markdown,
  required VoidCallback onDownload,
}) => showShadDialog<void>(
  context: context,
  builder: (_) =>
      _MarkdownSourceDialog(markdown: markdown, onDownload: onDownload),
);

class _MarkdownSourceDialog extends StatefulWidget {
  const _MarkdownSourceDialog({
    required this.markdown,
    required this.onDownload,
  });
  final String markdown;
  final VoidCallback onDownload;

  @override
  State<_MarkdownSourceDialog> createState() => _MarkdownSourceDialogState();
}

class _MarkdownSourceDialogState extends State<_MarkdownSourceDialog> {
  bool _wrap = true;
  bool _copied = false;
  final _v = ScrollController();
  final _h = ScrollController();

  @override
  void dispose() {
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final lines = widget.markdown.split('\n');
    final mono = TextStyle(
      fontFamily: WonkyTheme.monoFamily,
      fontSize: 13,
      height: 1.5,
      color: cs.foreground,
    );
    final numbers = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < lines.length; i++)
          Text('${i + 1}', style: mono.copyWith(color: cs.mutedForeground)),
      ],
    );
    final text = Text(
      widget.markdown,
      key: const ValueKey<String>('write.dialog.markdownSource.text'),
      style: mono,
    );
    final size = MediaQuery.sizeOf(context);
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.markdownSource'),
      title: const Text('Markdown source'),
      constraints: BoxConstraints(
        maxWidth: (size.width * 0.9).clamp(320, 900),
        maxHeight: size.height * 0.85,
      ),
      actions: [
        ShadCheckbox(
          value: _wrap,
          onChanged: (v) => setState(() => _wrap = v),
          label: const Text('Wrap lines'),
        ),
        ShadButton.outline(
          key: const ValueKey<String>('write.dialog.markdownSource.download'),
          leading: const Icon(LucideIcons.download, size: 16),
          onPressed: widget.onDownload,
          child: const Text('Download .md'),
        ),
        ShadButton.outline(
          key: const ValueKey<String>('write.dialog.markdownSource.copy'),
          leading: Icon(
            _copied ? LucideIcons.check : LucideIcons.copy,
            size: 16,
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: widget.markdown));
            if (mounted) setState(() => _copied = true);
          },
          child: Text(_copied ? 'Copied' : 'Copy'),
        ),
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: cs.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.border),
        ),
        padding: const EdgeInsets.all(12),
        child: SelectionArea(
          child: WonkyScrollArea(
            controller: _v,
            child: SingleChildScrollView(
              controller: _v,
              child: _wrap
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        numbers,
                        const SizedBox(width: 12),
                        Expanded(child: text),
                      ],
                    )
                  : SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [numbers, const SizedBox(width: 12), text],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Go to heading" quick list (`write.nav.goToHeading` without args).
Future<OutlineEntry?> showGoToHeadingDialog(
  BuildContext context,
  List<OutlineEntry> outline,
) => showShadDialog<OutlineEntry>(
  context: context,
  builder: (_) => _GoToHeading(outline: outline),
);

class _GoToHeading extends StatefulWidget {
  const _GoToHeading({required this.outline});
  final List<OutlineEntry> outline;

  @override
  State<_GoToHeading> createState() => _GoToHeadingState();
}

class _GoToHeadingState extends State<_GoToHeading> {
  String _q = '';
  int _i = 0;

  List<OutlineEntry> get _matches => [
    for (final e in widget.outline)
      if (_q.isEmpty || e.text.toLowerCase().contains(_q.toLowerCase())) e,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final m = _matches;
    final minLevel = widget.outline.isEmpty
        ? 1
        : widget.outline.map((e) => e.level).reduce((a, b) => a < b ? a : b);
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.goToHeading'),
      title: const Text('Go to heading'),
      constraints: const BoxConstraints(maxWidth: 480),
      child: Focus(
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(
              () => _i = (_i + 1).clamp(0, m.isEmpty ? 0 : m.length - 1),
            );
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
            setState(
              () => _i = (_i - 1).clamp(0, m.isEmpty ? 0 : m.length - 1),
            );
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 4),
            ShadInput(
              autofocus: true,
              placeholder: const Text('Search headings'),
              leading: const Icon(LucideIcons.search, size: 16),
              onChanged: (v) => setState(() {
                _q = v;
                _i = 0;
              }),
              onSubmitted: (_) {
                if (m.isNotEmpty) {
                  Navigator.of(context).pop(m[_i.clamp(0, m.length - 1)]);
                }
              },
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: m.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('No headings', style: theme.textTheme.muted),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: m.length,
                      itemBuilder: (context, i) {
                        final e = m[i];
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(e),
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              10.0 + (e.level - minLevel) * 14,
                              7,
                              10,
                              7,
                            ),
                            decoration: BoxDecoration(
                              color: i == _i ? theme.colorScheme.accent : null,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e.text.isEmpty ? 'Untitled heading' : e.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                fontWeight: e.level == minLevel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Markdown & formatting guide (`write.help.markdownGuide`).
Future<void> showMarkdownGuide(BuildContext context) => showShadDialog<void>(
  context: context,
  builder: (context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    const rows = [
      (
        '# Heading 1 … ###### Heading 6',
        'Headings (type at the start of a line)',
      ),
      ('**bold** or __bold__', 'Bold (⌘B / Ctrl+B)'),
      ('*italic* or _italic_', 'Italic (⌘I / Ctrl+I)'),
      ('~~strikethrough~~', 'Strikethrough (⌘⇧X / Ctrl+Shift+X)'),
      ('`code`', 'Inline code (⌘E / Ctrl+E)'),
      ('[text](https://…)', 'Link (⌘K / Ctrl+K)'),
      ('- item  or  * item', 'Bulleted list'),
      ('1. item', 'Numbered list'),
      ('[ ] task  or  [x] done', 'Checklist'),
      ('> quote', 'Quote'),
      ('``` + space', 'Code block'),
      ('---', 'Divider'),
      ('/', 'Command menu: insert tables, images and more'),
      ('@', 'Mention a person'),
    ];
    final mono = TextStyle(
      fontFamily: WonkyTheme.monoFamily,
      fontSize: 13,
      color: cs.foreground,
    );
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.markdownGuide'),
      title: const Text('Markdown & formatting'),
      description: const Text(
        'Wonky Write documents are Markdown. Type these shortcuts and they '
        'turn into formatting as you write.',
      ),
      constraints: const BoxConstraints(maxWidth: 600),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (syntax, meaning) in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: cs.border)),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(syntax, style: mono)),
                  Expanded(child: Text(meaning, style: theme.textTheme.small)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Underline and text colors are not part of Markdown — use bold or '
            'italic, or change how emphasis looks with a theme.',
            style: theme.textTheme.muted,
          ),
        ],
      ),
    );
  },
);
