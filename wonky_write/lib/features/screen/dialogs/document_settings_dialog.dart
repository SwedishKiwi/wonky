import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_write_core/wonky_write_core.dart' hide ThemeCatalog;

import '../../themes/theme_picker.dart';
import '../command_invoke.dart';
import '../write_document_controller.dart';
import 'document_dialogs.dart';

/// Document settings (`write.dialog.documentSettings`, Write 05 §13.1):
/// General (language, layout, my default mode), Theme, Page setup and
/// Markdown (front matter). Every change runs a command (meta changes are
/// undoable).
Future<void> showDocumentSettingsDialog(
  BuildContext context,
  WriteDocumentController doc, {
  String? tab,
}) => showShadDialog<void>(
  context: context,
  builder: (_) => DocumentSettingsDialog(doc: doc, initialTab: tab),
);

class DocumentSettingsDialog extends StatefulWidget {
  const DocumentSettingsDialog({super.key, required this.doc, this.initialTab});

  final WriteDocumentController doc;
  final String? initialTab;

  @override
  State<DocumentSettingsDialog> createState() => _DocumentSettingsDialogState();
}

class _DocumentSettingsDialogState extends State<DocumentSettingsDialog> {
  late String _tab = widget.initialTab ?? 'general';
  late final ValueNotifier<String?> _theme = ValueNotifier(
    widget.doc.documentTheme.option.uuid,
  );

  WriteDocumentController get d => widget.doc;

  @override
  void initState() {
    super.initState();
    d.addListener(_sync);
    // The grid lists the user's own themes too.
    unawaited(d.themes.loadMine());
  }

  void _sync() {
    _theme.value = d.documentTheme.option.uuid;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    d.removeListener(_sync);
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final tabs = <(String, String, IconData)>[
      ('general', 'General', LucideIcons.settings),
      ('theme', 'Theme', LucideIcons.palette),
      ('pageSetup', 'Page setup', LucideIcons.ruler),
      ('markdown', 'Markdown', LucideIcons.fileCode),
    ];
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return ShadDialog(
      key: const ValueKey<String>('write.dialog.documentSettings'),
      title: const Text('Document settings'),
      description: d.canChangeSettings
          ? null
          : const Text('Only editors can change document settings.'),
      constraints: BoxConstraints(
        maxWidth: (size.width * 0.92).clamp(320, 880),
        maxHeight: size.height * 0.88,
      ),
      actions: [
        ShadButton(
          key: const ValueKey<String>('write.dialog.documentSettings.done'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 168,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (id, label, icon) in tabs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ShadButton.ghost(
                      key: ValueKey<String>(
                        'write.dialog.documentSettings.$id',
                      ),
                      mainAxisAlignment: MainAxisAlignment.start,
                      backgroundColor: _tab == id ? cs.accent : null,
                      leading: Icon(icon, size: 16),
                      onPressed: () => setState(() => _tab = id),
                      child: Text(label),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(child: _content(context)),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    Widget control, {
    String? hint,
  }) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.small),
          const SizedBox(height: 6),
          control,
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint, style: theme.textTheme.muted.copyWith(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ro = !d.canChangeSettings;
    switch (_tab) {
      case 'theme':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current theme: ${d.documentTheme.option.name}',
              style: theme.textTheme.small,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ThemeGrid(
                catalog: d.themes,
                selected: _theme,
                onSelect: ro
                    ? null
                    : (o) => invokeCommand(
                        context,
                        'write.theme.apply',
                        args: {'themeId': o.uuid},
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () =>
                      invokeCommand(context, 'write.theme.setUserDefault'),
                  child: const Text('Save as my default theme'),
                ),
                ShadButton.ghost(
                  key: const ValueKey<String>(
                    'write.dialog.settings.customizeTheme',
                  ),
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.paintbrush, size: 14),
                  onPressed: () {
                    final services = ShellScope.of(context);
                    Navigator.of(context).pop();
                    unawaited(invokeWith(services, 'write.theme.openEditor'));
                  },
                  child: const Text('Customize…'),
                ),
              ],
            ),
          ],
        );
      case 'pageSetup':
        final s = d.pageSetup;
        final m = s.marginsOr(d.themeMargins);
        String inch(double pt) => '${(pt / 72).toStringAsFixed(2)}"';
        String hf(HeaderFooterSpec x) => !x.enabled || x.isEmpty
            ? 'None'
            : [
                x.left,
                x.center,
                x.right,
              ].where((t) => t.isNotEmpty).join(' · ');
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summary(
                context,
                'Layout',
                s.layout == PageLayoutMode.pages ? 'Pages' : 'Pageless',
              ),
              _summary(
                context,
                'Paper',
                '${s.paper.name.toUpperCase()} · ${s.orientation.name}',
              ),
              _summary(
                context,
                'Margins',
                s.margins == null
                    ? 'From the theme (${inch(m.top)} ${inch(m.right)} ${inch(m.bottom)} ${inch(m.left)})'
                    : '${inch(m.top)} ${inch(m.right)} ${inch(m.bottom)} ${inch(m.left)}',
              ),
              _summary(context, 'Header', hf(s.header)),
              _summary(context, 'Footer', hf(s.footer)),
              const SizedBox(height: 12),
              ShadButton.outline(
                key: const ValueKey<String>(
                  'write.dialog.documentSettings.editPageSetup',
                ),
                onPressed: () => invokeCommand(context, 'write.doc.pageSetup'),
                child: const Text('Edit page setup…'),
              ),
            ],
          ),
        );
      case 'markdown':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Front matter is YAML metadata at the top of the Markdown file '
              '(title, tags, author…). It is kept on import and export.',
              style: theme.textTheme.muted,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (d.frontMatter ?? '').isEmpty
                    ? 'No front matter'
                    : d.frontMatter!,
                style: theme.textTheme.small.copyWith(
                  fontFamily: 'packages/shad/GeistMono',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ShadButton.outline(
                  onPressed: () =>
                      invokeCommand(context, 'write.doc.properties'),
                  child: Text(ro ? 'View details…' : 'Edit front matter…'),
                ),
                const SizedBox(width: 8),
                ShadButton.ghost(
                  onPressed: () =>
                      invokeCommand(context, 'write.tools.viewMarkdown'),
                  child: const Text('View Markdown source'),
                ),
              ],
            ),
          ],
        );
      default:
        final prefs = ShellScope.of(context).prefs;
        final defaultMode =
            prefs.writeDefaults['defaultMode'] as String? ?? 'editing';
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(
                context,
                'Language',
                Row(
                  children: [
                    Text(languageName(d.language), style: theme.textTheme.p),
                    const SizedBox(width: 12),
                    ShadButton.outline(
                      key: const ValueKey<String>(
                        'write.dialog.documentSettings.language',
                      ),
                      size: ShadButtonSize.sm,
                      enabled: !ro,
                      onPressed: () =>
                          invokeCommand(context, 'write.doc.languageDialog'),
                      child: const Text('Change…'),
                    ),
                  ],
                ),
              ),
              _row(
                context,
                'Layout',
                ShadRadioGroup<String>(
                  key: ValueKey<String>('layout.${d.pageSetup.layout.name}'),
                  initialValue: d.pageSetup.layout.name,
                  enabled: !ro,
                  axis: Axis.horizontal,
                  spacing: 16,
                  onChanged: (v) => invokeCommand(
                    context,
                    'write.doc.setLayout',
                    args: {'layout': v},
                  ),
                  items: const [
                    ShadRadio(
                      key: ValueKey<String>(
                        'write.dialog.documentSettings.pages',
                      ),
                      value: 'pages',
                      label: Text('Pages'),
                    ),
                    ShadRadio(
                      key: ValueKey<String>(
                        'write.dialog.documentSettings.pageless',
                      ),
                      value: 'pageless',
                      label: Text('Pageless'),
                    ),
                  ],
                ),
                hint: 'Pageless shows one continuous column, like a web page.',
              ),
              _row(
                context,
                'Default mode for me',
                ShadSelect<String>(
                  initialValue: defaultMode,
                  minWidth: 200,
                  options: const [
                    ShadOption(value: 'editing', child: Text('Editing')),
                    ShadOption(value: 'suggesting', child: Text('Suggesting')),
                    ShadOption(value: 'viewing', child: Text('Viewing')),
                  ],
                  selectedOptionBuilder: (context, v) =>
                      Text(v[0].toUpperCase() + v.substring(1)),
                  onChanged: (v) {
                    if (v != null) {
                      invokeCommand(
                        context,
                        'write.prefs.setDefaultMode',
                        args: {'mode': v},
                      );
                    }
                  },
                ),
                hint: 'Used when you open documents you can edit.',
              ),
            ],
          ),
        );
    }
  }

  Widget _summary(BuildContext context, String label, String value) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: theme.textTheme.muted)),
          Expanded(child: Text(value, style: theme.textTheme.small)),
        ],
      ),
    );
  }
}
