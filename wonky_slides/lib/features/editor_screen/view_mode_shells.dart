import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import 'deck_editor_controller.dart';
import 'slide_labels.dart';

/// Outline view (04 §10), shell: slide titles and the first body
/// placeholder's lines, grouped, read-only (editing and promote/demote are
/// SL-34's).
class OutlineViewShell extends StatefulWidget {
  const OutlineViewShell({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final DeckEditorController editor;

  @override
  State<OutlineViewShell> createState() => _OutlineViewShellState();
}

class _OutlineViewShellState extends State<OutlineViewShell> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ed = widget.editor;
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final tokens = SlidesTokens.of(context);
    String? lastGroup;
    final rows = <Widget>[];
    for (final e in ed.order.entries) {
      if (e.groupId != lastGroup && e.groupId != null) {
        final g = ed.model.group(e.groupId!);
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        tokens.groupColor(g?.color) ??
                        theme.colorScheme.mutedForeground,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (g?.title ?? l.groupUntitled).toUpperCase(),
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      lastGroup = e.groupId;
      final title = SlideLabels.title(ed.model, e.id);
      String body = '';
      for (final el in ed.model.elementsOf(e.id)) {
        if (el.placeholderType == SlidePlaceholderType.body) {
          body = SlidesText.plainText(el.text).trim();
          break;
        }
      }
      rows.add(
        GestureDetector(
          key: ValueKey<String>('slides.outline.slide.${e.id}'),
          onTap: () => widget.services.dispatcher.invoke(
            'slides.nav.goToSlide',
            args: {'slideId': e.id},
            source: InvocationSource.ui,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text('${e.index + 1}', style: theme.textTheme.muted),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? l.outlineNoTitle : title,
                        style:
                            (title.isEmpty
                                    ? theme.textTheme.muted
                                    : theme.textTheme.p)
                                .copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: e.skipped
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                      ),
                      for (final line in body.split('\n'))
                        if (line.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 2),
                            child: Text('•  $line', style: theme.textTheme.p),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      key: const ValueKey<String>('slides.view.outline'),
      color: theme.colorScheme.background,
      child: WonkyScrollArea(
        controller: _scroll,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 40),
          children: [
            Text(l.outlineReadOnlyNote, style: theme.textTheme.muted),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(l.navigatorEmpty, style: theme.textTheme.muted)
            else
              ...rows,
          ],
        ),
      ),
    );
  }
}

/// Masters mode (05 §8), shell until SL-28: an explanation and *Back to
/// Normal view*.
class MastersModeShell extends StatelessWidget {
  const MastersModeShell({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = slidesL10n(context);
    return Center(
      key: const ValueKey<String>('slides.view.masters'),
      child: SingleChildScrollView(
        child: WonkyEmptyState(
          illustration: EmptyIllustration.documents,
          title: l.mastersSoonTitle,
          description: l.mastersSoonBody,
          actions: [
            ShadButton.outline(
              key: const ValueKey<String>('slides.view.masters.back'),
              onPressed: () => services.dispatcher.invoke(
                'slides.view.setMode',
                args: const {'mode': 'normal'},
                source: InvocationSource.ui,
                context: context,
              ),
              child: Text(l.backToNormalView),
            ),
          ],
        ),
      ),
    );
  }
}
