import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../data/api.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/page_frame.dart';
import '../shell/shell_services.dart';
import 'drive_format.dart';

String templateCategoryLabel(WonkyAppLocalizations l, TemplateCategory c) =>
    switch (c) {
      TemplateCategory.personal => l.templatePersonal,
      TemplateCategory.work => l.templateWork,
      TemplateCategory.education => l.templateEducation,
      TemplateCategory.projectManagement => l.templateProjectManagement,
      TemplateCategory.finance => l.templateFinance,
    };

Future<void> _createFrom(
  BuildContext context,
  ShellServices s,
  TemplateView? t,
) async {
  final l = WonkyAppLocalizations.of(context);
  try {
    final uuid = await s.config.createItem(
      s,
      parentUuid: s.currentFolder.value?.uuid,
      templateUuid: t?.uuid,
      name: t?.name,
    );
    if (uuid != null) s.router.go(s.config.itemPath(uuid.uuid));
  } catch (e) {
    s.toasts.error(l.errorGeneric, description: errorMessage(e));
  }
}

/// A template preview card.
class TemplateCard extends StatelessWidget {
  const TemplateCard({
    super.key,
    required this.services,
    this.template,
    this.width = 148,
  });

  final ShellServices services;

  /// null = Blank.
  final TemplateView? template;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final t = template;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: t?.name ?? l.templateBlank,
        child: GestureDetector(
          key: ValueKey<String>(
            'drive.template.${t?.key ?? t?.uuid.uuid ?? 'blank'}',
          ),
          onTap: () => _createFrom(context, services, t),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: width * 1.25,
                  width: width,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.page,
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: t == null
                      ? Center(
                          child: Icon(
                            LucideIcons.plus,
                            size: 40,
                            color: services.config.brandColor,
                          ),
                        )
                      : SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: _TemplateThumbnail(text: t.previewText),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  t?.name ?? l.templateBlank,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small,
                ),
                if (t != null)
                  Text(
                    templateCategoryLabel(l, t.category),
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A miniature of a template's first lines: headings bold, the rest small
/// (the server sends one line per block, headings prefixed with "#").
class _TemplateThumbnail extends StatelessWidget {
  const _TemplateThumbnail({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fg = theme.colorScheme.foreground;
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].startsWith('# '))
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4, bottom: 2),
              child: Text(
                lines[i].substring(2),
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: i == 0 ? 9 : 7.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            )
          else
            Text(
              lines[i],
              maxLines: 2,
              overflow: TextOverflow.clip,
              style: theme.textTheme.muted.copyWith(
                fontSize: 6.5,
                height: 1.45,
              ),
            ),
      ],
    );
  }
}

/// The collapsible "Start a new …" strip on Home (suite 05 §3.1).
class TemplateStrip extends StatefulWidget {
  const TemplateStrip({super.key, required this.services});

  final ShellServices services;

  @override
  State<TemplateStrip> createState() => _TemplateStripState();
}

class _TemplateStripState extends State<TemplateStrip> {
  late final Future<List<TemplateView>> _templates = widget.services.drive
      .listTemplates(widget.services.config.primaryKind);

  bool get _hidden =>
      widget.services.prefs.device<bool>('drive.templatesHidden') ?? false;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final s = widget.services;
    return Container(
      color: theme.colorScheme.canvas,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.templateStripTitle(
                    describeKind(l, s.config.primaryKind).toLowerCase(),
                  ),
                  style: theme.textTheme.small,
                ),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => s.router.go('/templates'),
                trailing: const Icon(LucideIcons.chevronsUpDown, size: 14),
                child: Text(l.templateGallery),
              ),
              ShadTooltip(
                builder: (_) =>
                    Text(_hidden ? l.templatesShow : l.templatesHide),
                child: ShadIconButton.ghost(
                  key: const ValueKey<String>('drive.templates.toggle'),
                  width: 28,
                  height: 28,
                  iconSize: 16,
                  semanticLabel: _hidden ? l.templatesShow : l.templatesHide,
                  icon: Icon(
                    _hidden ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                  ),
                  onPressed: () async {
                    await s.prefs.setDevice('drive.templatesHidden', !_hidden);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
          if (!_hidden) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: FutureBuilder<List<TemplateView>>(
                future: _templates,
                builder: (context, snap) {
                  final list = snap.data ?? const <TemplateView>[];
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      TemplateCard(services: s),
                      for (final t in list.take(6)) ...[
                        const SizedBox(width: 16),
                        TemplateCard(services: s, template: t),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `/templates` — all templates by category.
class TemplateGalleryScreen extends StatelessWidget {
  const TemplateGalleryScreen({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ShellPageFrame(
      services: services,
      title: l.templateGallery,
      child: FutureBuilder<List<TemplateView>>(
        future: services.drive.listTemplates(services.config.primaryKind),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: ShadSpinner());
          }
          if (snap.hasError) {
            return WonkyEmptyState(
              illustration: EmptyIllustration.error,
              title: l.errorGeneric,
              description: errorMessage(snap.error!),
            );
          }
          final byCat = <TemplateCategory, List<TemplateView>>{};
          for (final t in snap.data!) {
            byCat.putIfAbsent(t.category, () => []).add(t);
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [TemplateCard(services: services)],
              ),
              for (final cat in TemplateCategory.values)
                if (byCat[cat] != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    templateCategoryLabel(l, cat),
                    style: theme.textTheme.h4,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final t in byCat[cat]!)
                        TemplateCard(services: services, template: t),
                    ],
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}
