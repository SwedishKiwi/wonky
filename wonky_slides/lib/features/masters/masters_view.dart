import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' show DeckModelIndexes;

import '../../l10n/slides_l10n.dart';
import '../editor_screen/canvas_region.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../navigator/slide_navigator.dart' show OpenContextMenu;
import 'masters_navigator.dart';
import 'masters_targets.dart';

/// Masters mode (Slides 05 §8.1; SL-28): the masters navigator, a banner
/// naming what is edited and how many slides it affects with **Done**,
/// and the canvas editing the layout or master with every canvas tool.
/// Replaces the navigator, canvas and notes of the Normal view.
class MastersView extends StatelessWidget {
  const MastersView({
    super.key,
    required this.services,
    required this.editor,
    required this.onContextMenu,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final OpenContextMenu onContextMenu;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final theme = ShadTheme.of(context);
      // Narrow: a compact navigator (thumbnails stay readable at 140 px).
      final navWidth = c.maxWidth < 600
          ? 140.0
          : editor.navigatorWidth.clamp(180.0, 320.0);
      return Row(
        key: const ValueKey<String>('slides.view.masters'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: navWidth,
            child: MastersNavigator(
              services: services,
              editor: editor,
              width: navWidth,
              onContextMenu: onContextMenu,
            ),
          ),
          Container(width: 1, color: theme.colorScheme.border),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MastersBanner(services: services, editor: editor),
                Expanded(
                  child: CanvasRegion(
                    services: services,
                    editor: editor,
                    onContextMenu: onContextMenu,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

/// "Editing layout “Title and content” of theme Wonky — changes apply to
/// 12 slides · Done" (05 §8.1).
class MastersBanner extends StatelessWidget {
  const MastersBanner({
    super.key,
    required this.services,
    required this.editor,
  });

  final ShellServices services;
  final DeckEditorController editor;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final m = editor.model;
    final id = editor.surfaceId;
    final layout = id == null ? null : m.layout(id);
    final master = MastersTargets.master(editor, const JsonArgs());
    final themeRec = MastersTargets.themeOfTarget(editor);
    final themeName = themeRec?.name ?? '';
    final ix = m.indexes.themes;
    final String text;
    if (layout != null) {
      text = l.mastersBannerLayout(
        layout.name,
        themeName,
        ix.slidesUsingLayout(layout.id),
      );
    } else if (master != null) {
      text = l.mastersBannerMaster(
        master.name,
        themeName,
        ix.slidesUsingMaster(master.id),
      );
    } else {
      text = l.mastersBannerNone;
    }
    return Container(
      key: const ValueKey<String>('slides.masters.banner'),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.layoutTemplate,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                key: const ValueKey<String>('slides.masters.banner.text'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ShadButton(
            key: const ValueKey<String>('slides.masters.done'),
            size: ShadButtonSize.sm,
            onPressed: () => services.dispatcher.invoke(
              'slides.view.setMode',
              args: const {'mode': 'normal'},
              source: InvocationSource.ui,
              context: context,
            ),
            child: Text(l.mastersDone),
          ),
        ],
      ),
    );
  }
}
