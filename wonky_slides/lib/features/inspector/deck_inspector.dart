import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' show ElementOwnerKind;
import 'package:wonky_slides_core/themes.dart' show SlideAppearance;
import 'package:wonky_ui/wonky_ui.dart';

import '../../config/menus/slides_menu_spec.dart' show groupColorLabel;
import '../../config/slides_features.dart';
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../toolbar/command_ui.dart';
import '../masters/surface_inspector.dart';
import '../themes/editor/theme_editor_sections.dart';
import 'animate/animate_tab.dart';
import 'inspector_sections.dart';

/// The docked inspector (Slides 04 §7): tabs **Format** · **Animate** ·
/// **Slide** (Animate only while `SlidesFeature.animations` is on) over a scrollable list of collapsible sections from the
/// section registry ([inspectorSections]). The Format tab follows the
/// selection (04 §7.2; an empty state with quick insert buttons when
/// nothing is selected), the Animate tab hosts 06 §5's UI (sub-tabs
/// Transition / Build / Order; SL-30), the Slide tab edits the current
/// slide (04 §7.4). Viewers see it read-only (every control is a command,
/// disabled with its reason).
class DeckInspector extends StatefulWidget {
  const DeckInspector({
    super.key,
    required this.services,
    required this.editor,
    this.onClose,
  });

  final ShellServices services;
  final DeckEditorController editor;

  /// Closes the inspector (overlay mode on narrow widths).
  final VoidCallback? onClose;

  @override
  State<DeckInspector> createState() => _DeckInspectorState();
}

class _DeckInspectorState extends State<DeckInspector> {
  final _scroll = ScrollController();

  /// Collapsed sections (all open by default, per user while the editor
  /// is open).
  final Set<String> _collapsed = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DeckEditorController get ed => widget.editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ed, widget.services.registry]),
    builder: (context, _) {
      final theme = ShadTheme.of(context);
      final l = slidesL10n(context);
      final ui = SlidesCommandUi(context, widget.services);
      final reveal = ed.inspectorSection;
      if (reveal != null) _collapsed.remove(reveal);
      return Semantics(
        container: true,
        label: l.inspectorLabel,
        child: DecoratedBox(
          key: const ValueKey<String>('slides.inspector'),
          decoration: BoxDecoration(
            color: theme.colorScheme.card,
            border: Border(left: BorderSide(color: theme.colorScheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _tabs(context, l, ui),
              Container(height: 1, color: theme.colorScheme.border),
              Expanded(
                child: WonkyScrollArea(
                  controller: _scroll,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    children: switch (ed.inspectorTab) {
                      InspectorTab.format => _format(context, l, ui),
                      InspectorTab.animate => _animate(context, l, ui),
                      // Masters mode (SL-28): the Slide tab edits the
                      // layout or master, the Theme tab the theme.
                      InspectorTab.slide when ed.editsMasters => [
                        for (final s in mastersSurfaceSections)
                          _section(context, s, l, null),
                      ],
                      InspectorTab.slide => _slide(context, l, ui),
                      InspectorTab.theme => [
                        for (final s in themeEditorSections)
                          _section(context, s, l, null),
                      ],
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _tabs(
    BuildContext context,
    SlidesLocalizations l,
    SlidesCommandUi ui,
  ) {
    final theme = ShadTheme.of(context);
    Widget tab(InspectorTab t, String label) {
      final selected = ed.inspectorTab == t;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: ShadButton.ghost(
            key: ValueKey<String>('slides.inspector.tab.${t.name}'),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            backgroundColor: selected ? theme.colorScheme.muted : null,
            onPressed: () => ui.run(
              t == InspectorTab.animate
                  ? 'slides.panel.animate'
                  : 'slides.inspector.open',
              t == InspectorTab.animate ? const {} : {'tab': t.name},
              InvocationSource.ui,
            ),
            child: Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      child: Row(
        children: [
          tab(InspectorTab.format, l.inspectorFormat),
          // The Animate tab (SL-30) while `animations` is on.
          if (SlidesFeatures.isOn(SlidesFeature.animations))
            tab(InspectorTab.animate, l.inspectorAnimate),
          tab(
            InspectorTab.slide,
            !ed.editsMasters
                ? l.inspectorSlide
                : ed.surfaceKind == ElementOwnerKind.layout
                ? l.inspectorLayout
                : l.inspectorMaster,
          ),
          if (ed.editsMasters) tab(InspectorTab.theme, l.inspectorTheme),
          ShadTooltip(
            builder: (_) => Text(l.inspectorClose),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('slides.inspector.close'),
              width: 28,
              height: 28,
              iconSize: 16,
              semanticLabel: l.inspectorClose,
              icon: const Icon(LucideIcons.x),
              onPressed:
                  widget.onClose ??
                  () => ui.run(
                    'slides.view.toggleInspector',
                    const {},
                    InvocationSource.ui,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    InspectorSectionSpec spec,
    SlidesLocalizations l,
    Widget Function()? body,
  ) {
    final theme = ShadTheme.of(context);
    final open = !_collapsed.contains(spec.id);
    final content =
        spec.builder?.call(context, widget.services, ed) ??
        body?.call() ??
        Text(l.inspectorSectionSoon, style: theme.textTheme.muted);
    return Padding(
      key: ValueKey<String>('slides.inspector.section.${spec.id}'),
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: ShadButton.ghost(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              mainAxisAlignment: MainAxisAlignment.start,
              onPressed: () => setState(() {
                if (!_collapsed.remove(spec.id)) _collapsed.add(spec.id);
              }),
              leading: Icon(
                open ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              child: Flexible(
                child: Text(
                  spec.title(l),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 2, 4, 10),
              child: content,
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Format

  List<Widget> _format(
    BuildContext context,
    SlidesLocalizations l,
    SlidesCommandUi ui,
  ) {
    final kind = ed.selectionKind;
    if (kind == DeckSelectionKind.none) {
      final theme = ShadTheme.of(context);
      return [
        const SizedBox(height: 24),
        Icon(
          LucideIcons.mousePointerClick,
          size: 32,
          color: theme.colorScheme.mutedForeground,
        ),
        const SizedBox(height: 10),
        Text(
          l.inspectorFormatEmpty,
          key: const ValueKey<String>('slides.inspector.formatEmpty'),
          textAlign: TextAlign.center,
          style: theme.textTheme.muted,
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (id, icon) in [
              ('slides.insert.textBox', LucideIcons.type),
              ('slides.insert.shape', LucideIcons.square),
              ('slides.insert.image', LucideIcons.image),
            ])
              _commandButton(ui, id, icon: icon),
          ],
        ),
      ];
    }
    return [
      for (final s in formatSectionsFor(kind)) _section(context, s, l, null),
    ];
  }

  Widget _commandButton(
    SlidesCommandUi ui,
    String id, {
    IconData? icon,
    Map<String, Object?> args = const {},
    String? label,
    bool outline = true,
  }) {
    final st = ui.state(id, args);
    final text = label ?? ui.title(id);
    final button = outline
        ? ShadButton.outline(
            key: ValueKey<String>(
              'slides.inspector.cmd.$id.${args.values.join('.')}',
            ),
            size: ShadButtonSize.sm,
            enabled: st.enabled,
            leading: icon == null ? null : Icon(icon, size: 14),
            onPressed: () => ui.run(id, args, InvocationSource.ui),
            child: Flexible(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
        : ShadButton.ghost(
            size: ShadButtonSize.sm,
            enabled: st.enabled,
            leading: icon == null ? null : Icon(icon, size: 14),
            onPressed: () => ui.run(id, args, InvocationSource.ui),
            child: Flexible(
              child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          );
    final reason = st.disabledReason;
    if (st.enabled || reason == null) return button;
    return ShadTooltip(builder: (_) => Text(reason), child: button);
  }

  // --------------------------------------------------------------- Animate

  /// 06 §5: SL-30's Animate tab (`features/inspector/animate/`).
  List<Widget> _animate(
    BuildContext context,
    SlidesLocalizations l,
    SlidesCommandUi ui,
  ) => [AnimateTab(services: widget.services, editor: ed)];

  // ----------------------------------------------------------------- Slide

  List<Widget> _slide(
    BuildContext context,
    SlidesLocalizations l,
    SlidesCommandUi ui,
  ) {
    final theme = ShadTheme.of(context);
    final entry = ed.currentEntry;
    if (entry == null) {
      return [
        const SizedBox(height: 24),
        Text(
          l.navigatorEmpty,
          textAlign: TextAlign.center,
          style: theme.textTheme.muted,
        ),
      ];
    }
    final slide = entry.slide;
    final layoutId = slide.layoutId;
    final layout = layoutId == null ? null : ed.model.layout(layoutId);
    final group = entry.groupId == null ? null : ed.model.group(entry.groupId!);
    final themeRec = ed.model.defaultTheme;
    final appearance = ed.model.deck?.appearance ?? SlideAppearance.light;

    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.small)),
          control,
        ],
      ),
    );

    Widget switchRow(String id, String label, bool value) {
      final st = ui.state(id);
      final sw = ShadSwitch(
        key: ValueKey<String>('slides.inspector.switch.$id'),
        value: value,
        enabled: st.enabled,
        onChanged: (_) => ui.run(id, const {}, InvocationSource.ui),
      );
      final reason = st.disabledReason;
      return row(
        label,
        st.enabled || reason == null
            ? sw
            : ShadTooltip(builder: (_) => Text(reason), child: sw),
      );
    }

    Widget value(String text) => Text(
      text,
      style: theme.textTheme.small.copyWith(
        color: theme.colorScheme.mutedForeground,
      ),
    );

    final bodies = <String, Widget Function()>{
      'layout': () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(l.inspectorCurrentLayout, value(layout?.name ?? '—')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _commandButton(ui, 'slides.slide.resetToLayout'),
              if (SlidesFeatures.isOn(SlidesFeature.masters))
                _commandButton(
                  ui,
                  'slides.view.setMode',
                  args: const {'mode': 'masters'},
                  label: l.menuEditLayout,
                ),
            ],
          ),
        ],
      ),
      'background': () => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _commandButton(ui, 'slides.slide.setBackground'),
          _commandButton(ui, 'slides.slide.applyBackgroundToAll'),
        ],
      ),
      'theme': () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            l.sectionTheme,
            value(
              themeRec == null
                  ? '—'
                  : ed.resolver.resolveTheme(themeRec, appearance).theme.name,
            ),
          ),
          row(
            l.inspectorAppearance,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (a, label) in [
                  (SlideAppearance.light, l.appearanceLight),
                  (SlideAppearance.dark, l.appearanceDark),
                ])
                  _appearanceButton(ui, a, label, appearance == a),
              ],
            ),
          ),
          _commandButton(
            ui,
            'slides.panel.themes',
            label: l.menuChangeTheme,
            icon: LucideIcons.palette,
          ),
        ],
      ),
      'visibility': () => Column(
        children: [
          switchRow(
            'slides.slide.toggleSkip',
            l.cmdSlideToggleSkip,
            entry.skipped,
          ),
          switchRow(
            'slides.slide.setHideMasterElements',
            l.cmdSlideSetHideMasterElements,
            slide.hideMasterElements ?? false,
          ),
        ],
      ),
      'group': () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group == null)
            value(l.inspectorNotInGroup)
          else ...[
            row(l.inspectorGroupName, value(group.title)),
            row(
              l.menuGroupColor,
              value(
                group.color == null
                    ? l.colorNone
                    : groupColorLabel(l, group.color!),
              ),
            ),
            _commandButton(ui, 'slides.group.removeSlides'),
          ],
        ],
      ),
      'info': () => Column(
        children: [
          row(
            l.inspectorSlideNumber,
            value(l.statusSlideOf(entry.index + 1, ed.order.length)),
          ),
          row(l.inspectorCurrentLayout, value(layout?.name ?? '—')),
          if (entry.skipped) row(l.inspectorSkipped, value(l.yes)),
        ],
      ),
    };
    return [
      for (final s in slideSections) _section(context, s, l, bodies[s.id]),
    ];
  }

  Widget _appearanceButton(
    SlidesCommandUi ui,
    SlideAppearance a,
    String label,
    bool selected,
  ) {
    final args = {'appearance': a.name};
    final st = ui.state('slides.deck.setAppearance', args);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Semantics(
        selected: selected,
        child: selected
            ? ShadButton.secondary(
                key: ValueKey<String>('slides.inspector.appearance.${a.name}'),
                size: ShadButtonSize.sm,
                enabled: st.enabled,
                onPressed: () => ui.run(
                  'slides.deck.setAppearance',
                  args,
                  InvocationSource.ui,
                ),
                child: Text(label),
              )
            : ShadButton.ghost(
                key: ValueKey<String>('slides.inspector.appearance.${a.name}'),
                size: ShadButtonSize.sm,
                enabled: st.enabled,
                onPressed: () => ui.run(
                  'slides.deck.setAppearance',
                  args,
                  InvocationSource.ui,
                ),
                child: Text(label),
              ),
      ),
    );
  }
}
