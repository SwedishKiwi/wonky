import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart';

import '../../commands/slides_command.dart' show SlidesKeyScopes;
import '../../config/menus/context_menu_specs.dart';
import '../../l10n/slides_l10n.dart';
import '../../theme/slides_tokens.dart';
import '../toolbar/command_ui.dart';
import 'deck_editor_controller.dart';
import 'slide_labels.dart';
import 'slide_preview.dart';

/// Opens a context menu at a global position (`context.<id>`, 04 §11).
typedef OpenContextMenu = void Function(String menuId, Offset global);

/// The slide navigator region until SL-16 builds the real navigator
/// (04 §5): presentation order with group headers (color dot, title,
/// count), slide rows with number and thumbnail (skipped dimmed, current
/// ringed), *+ New slide* at the bottom, the `slidesNavigator` key scope
/// and the navigator context menus. Clicking a row runs
/// `slides.nav.goToSlide`; drag and drop, multi-selection, collapse and
/// inline rename come with SL-16.
class NavigatorShell extends StatefulWidget {
  const NavigatorShell({
    super.key,
    required this.services,
    required this.editor,
    required this.width,
    required this.onContextMenu,
  });

  final ShellServices services;
  final DeckEditorController editor;
  final double width;
  final OpenContextMenu onContextMenu;

  @override
  State<NavigatorShell> createState() => _NavigatorShellState();
}

class _NavigatorShellState extends State<NavigatorShell> {
  final _scroll = ScrollController();

  DeckEditorController get ed => widget.editor;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ed, widget.services.registry]),
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final tokens = SlidesTokens.of(context);
      final ui = SlidesCommandUi(context, widget.services);
      final rows = _rows();
      final narrowRows = widget.width < 170;
      return KeymapScope(
        scope: SlidesKeyScopes.navigator,
        keymap: widget.services.keymap,
        focusNode: ed.navigatorFocus,
        child: Semantics(
          container: true,
          label: l.navigatorLabel,
          child: ColoredBox(
            key: const ValueKey<String>('slides.navigator'),
            color: tokens.navigatorBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapUp: (d) => widget.onContextMenu(
                      SlidesContextMenuIds.navigatorEmpty,
                      d.globalPosition,
                    ),
                    child: rows.isEmpty
                        ? Center(
                            child: Text(
                              l.navigatorEmpty,
                              key: const ValueKey<String>(
                                'slides.navigator.empty',
                              ),
                              style: theme.textTheme.muted,
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: rows.length,
                            itemBuilder: (context, i) => switch (rows[i]) {
                              final SlideGroupRange g => _groupRow(
                                context,
                                g,
                                tokens,
                              ),
                              final SlideOrderEntry e => _slideRow(
                                context,
                                e,
                                tokens,
                                compact: narrowRows,
                              ),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                  ),
                ),
                Container(height: 1, color: theme.colorScheme.border),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: _newSlideButton(ui),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// Group headers and slides in presentation order.
  List<Object> _rows() {
    final order = ed.order;
    final out = <Object>[];
    final headerAt = {for (final g in order.groups) g.start: g};
    final emptyGroups = [
      for (final g in order.groups)
        if (g.length == 0) g,
    ];
    for (final e in order.entries) {
      final g = headerAt[e.index];
      if (g != null && e.groupId == g.group.id) out.add(g);
      out.add(e);
    }
    out.addAll(emptyGroups);
    return out;
  }

  Widget _newSlideButton(SlidesCommandUi ui) {
    final st = ui.state('slides.slide.new');
    final button = ShadButton.ghost(
      key: const ValueKey<String>('slides.navigator.newSlide'),
      height: 30,
      enabled: st.enabled,
      leading: const Icon(LucideIcons.plus, size: 14),
      onPressed: () =>
          ui.run('slides.slide.new', const {}, InvocationSource.ui),
      child: Text(ui.l.cmdSlideNew),
    );
    final reason = st.disabledReason;
    if (st.enabled || reason == null) return button;
    return ShadTooltip(builder: (_) => Text(reason), child: button);
  }

  Widget _groupRow(
    BuildContext context,
    SlideGroupRange g,
    SlidesTokens tokens,
  ) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final color =
        tokens.groupColor(g.group.color) ?? theme.colorScheme.mutedForeground;
    final title = g.group.title.isEmpty ? l.groupUntitled : g.group.title;
    return Semantics(
      label: l.navigatorGroupSemantics(title, g.length),
      child: GestureDetector(
        key: ValueKey<String>('slides.navigator.group.${g.group.id}'),
        onTap: g.length == 0
            ? null
            : () => widget.services.dispatcher.invoke(
                'slides.nav.goToGroup',
                args: {'groupId': g.group.id},
                source: InvocationSource.ui,
              ),
        onSecondaryTapUp: (d) => widget.onContextMenu(
          SlidesContextMenuIds.navigatorGroup,
          d.globalPosition,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (g.group.skipped)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    LucideIcons.eyeOff,
                    size: 12,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              Text('${g.length}', style: theme.textTheme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slideRow(
    BuildContext context,
    SlideOrderEntry e,
    SlidesTokens tokens, {
    required bool compact,
  }) {
    final theme = ShadTheme.of(context);
    final l = slidesL10n(context);
    final current = e.id == ed.currentSlideId;
    final selected = !current && ed.selectedSlideIds.contains(e.id);
    final resolved = ed.resolver.resolve(e.id);
    final group = e.groupId == null ? null : ed.model.group(e.groupId!);
    final groupColor = group == null ? null : tokens.groupColor(group.color);
    final title = SlideLabels.title(ed.model, e.id);
    final number = Text(
      '${e.index + 1}',
      textAlign: TextAlign.right,
      style: theme.textTheme.muted.copyWith(
        fontSize: 12,
        decoration: e.skipped ? TextDecoration.lineThrough : null,
      ),
    );
    final thumb = Opacity(
      opacity: e.skipped ? 0.4 : 1,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: current
                ? tokens.thumbnailRing
                : selected
                ? tokens.thumbnailSelection
                : theme.colorScheme.border,
            width: current || selected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: resolved == null
              ? const SizedBox(height: 40)
              : SlidePreview(slide: resolved),
        ),
      ),
    );
    return Semantics(
      selected: current,
      button: true,
      label: l.navigatorSlideSemantics(
        e.index + 1,
        ed.order.length,
        title.isEmpty ? l.slideUntitled : title,
      ),
      child: GestureDetector(
        key: ValueKey<String>('slides.navigator.slide.${e.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ed.navigatorFocus.requestFocus();
          widget.services.dispatcher.invoke(
            'slides.nav.goToSlide',
            args: {'slideId': e.id},
            source: InvocationSource.ui,
          );
        },
        onSecondaryTapUp: (d) {
          if (!current) ed.setCurrentSlide(e.id);
          widget.onContextMenu(
            SlidesContextMenuIds.navigatorSlide,
            d.globalPosition,
          );
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(group == null ? 4 : 0, 4, 10, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group != null)
                Container(
                  width: 4,
                  height: 48,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: groupColor ?? theme.colorScheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (!compact)
                SizedBox(
                  width: group == null ? 24 : 20,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 6),
                    child: number,
                  ),
                ),
              Expanded(
                child: compact
                    ? Stack(
                        children: [
                          thumb,
                          Positioned(left: 4, top: 2, child: number),
                        ],
                      )
                    : thumb,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
