import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../toolbar/command_ui.dart';
import 'deck_editor_controller.dart';

/// Status bar, left (Slides 04 §14): "Slide 4 of 24" · the current slide's
/// group (color dot + title) · "2 skipped".
class DeckStatusLeft extends StatelessWidget {
  const DeckStatusLeft({super.key, required this.editor});

  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: editor,
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final style = theme.textTheme.small.copyWith(fontSize: 12);
      final order = editor.order;
      final entry = editor.currentEntry;
      final group = entry?.groupId == null
          ? null
          : editor.model.group(entry!.groupId!);
      final skipped = order.entries.where((e) => e.skipped).length;
      return Row(
        key: const ValueKey<String>('slides.status.left'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            entry == null
                ? l.statusNoSlides
                : l.statusSlideOf(entry.index + 1, order.length),
            key: const ValueKey<String>('slides.status.position'),
            style: style,
          ),
          if (group != null) ...[
            Text('  ·  ', style: style),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    SlidesTokens.of(context).groupColor(group.color) ??
                    theme.colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                group.title,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
          if (skipped > 0) ...[
            Text('  ·  ', style: style),
            Text(
              l.statusSkipped(skipped),
              key: const ValueKey<String>('slides.status.skipped'),
              style: style.copyWith(color: theme.colorScheme.mutedForeground),
            ),
          ],
        ],
      );
    },
  );
}

/// Status bar, right (04 §14): view mode buttons (Normal / Grid / Outline)
/// and zoom (− Fit/100 % +); every control is a command.
class DeckStatusRight extends StatelessWidget {
  const DeckStatusRight({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([editor, services.registry]),
    builder: (context, _) {
      final ui = SlidesCommandUi(context, services);
      final l = ui.l;
      final theme = ShadTheme.of(context);
      Widget icon(
        String key,
        IconData icon,
        String label,
        String id, {
        Map<String, Object?> args = const {},
        bool selected = false,
      }) {
        final st = ui.state(id, args);
        return ShadTooltip(
          builder: (_) => Text(label),
          child: Semantics(
            selected: selected,
            child: ShadIconButton.ghost(
              key: ValueKey<String>('slides.status.$key'),
              width: 24,
              height: 22,
              iconSize: 14,
              semanticLabel: label,
              enabled: st.enabled,
              backgroundColor: selected ? theme.colorScheme.muted : null,
              icon: Icon(icon),
              onPressed: () => ui.run(id, args, InvocationSource.ui),
            ),
          ),
        );
      }

      final zoomLabel = editor.zoomFit
          ? l.zoomFit
          : l.zoomPercent((editor.zoom * 100).round());
      return Row(
        key: const ValueKey<String>('slides.status.right'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (mode, i, label) in [
            (DeckViewMode.normal, LucideIcons.panelsTopLeft, l.viewNormal),
            (DeckViewMode.grid, LucideIcons.layoutGrid, l.viewGrid),
            (DeckViewMode.outline, LucideIcons.listTree, l.viewOutline),
          ])
            icon(
              'mode.${mode.name}',
              i,
              label,
              'slides.view.setMode',
              args: {'mode': mode.name},
              selected: editor.mode == mode,
            ),
          const SizedBox(width: 10),
          icon(
            'zoomOut',
            LucideIcons.minus,
            l.cmdViewZoomOut,
            'slides.view.zoomOut',
          ),
          ShadButton.ghost(
            key: const ValueKey<String>('slides.status.zoom'),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onPressed: () => ui.run(
              editor.zoomFit ? 'slides.view.zoom' : 'slides.view.zoomFit',
              editor.zoomFit ? const {'percent': 100} : const {},
              InvocationSource.ui,
            ),
            child: Text(
              zoomLabel,
              style: theme.textTheme.small.copyWith(fontSize: 12),
            ),
          ),
          icon(
            'zoomIn',
            LucideIcons.plus,
            l.cmdViewZoomIn,
            'slides.view.zoomIn',
          ),
        ],
      );
    },
  );
}
