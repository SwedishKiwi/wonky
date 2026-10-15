import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart';
import 'package:wonky_sync_models/ids.dart' show SlidesIds;
import 'package:wonky_ui/wonky_ui.dart';

import '../../commands/theme_commands.dart' show unusedThemes;
import '../../config/panels/slides_panels.dart';
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'preview_card.dart';
import 'theme_previews.dart';

/// The Themes side panel (`slides.panel.themes`, Slides 05 §9).
SidePanelSpec themesPanelSpec(
  BuildContext context,
  ShellServices services,
  DeckEditorController editor,
) => SidePanelSpec(
  id: SlidesPanels.themes,
  title: slidesL10n(context).themesPanelTitle,
  icon: LucideIcons.palette,
  builder: (context) => ThemesPanel(services: services, editor: editor),
);

/// Stable widget keys of the Themes panel.
abstract final class ThemesPanelKeys {
  static const panel = ValueKey<String>('slides.themes.panel');

  static ValueKey<String> appearance(SlideAppearance a) =>
      ValueKey<String>('slides.themes.appearance.${a.name}');

  static const scopeAll = ValueKey<String>('slides.themes.scope.all');
  static const scopeSelected = ValueKey<String>('slides.themes.scope.selected');

  static ValueKey<String> deckTheme(String id) =>
      ValueKey<String>('slides.themes.deck.$id');

  static ValueKey<String> deckThemeMenu(String id) =>
      ValueKey<String>('slides.themes.deck.$id.menu');

  static ValueKey<String> builtIn(String key) =>
      ValueKey<String>('slides.themes.builtin.$key');

  static const import = ValueKey<String>('slides.themes.import');
  static const removeUnused = ValueKey<String>('slides.themes.removeUnused');
}

/// The Themes panel (05 §9): the deck's appearance (Light | Dark), where a
/// click applies (all slides or the selected ones), the themes in this
/// presentation (preview, default badge, usage, ⋮ Rename / Duplicate /
/// Set as default / Edit / Remove), the 10 built-in themes as previews in
/// the current appearance, *Import theme from a presentation…* and *Remove
/// unused themes*. Every action is a command (one undo step each);
/// previews are drawn from in-memory preview decks and never write.
class ThemesPanel extends StatefulWidget {
  const ThemesPanel({super.key, required this.services, required this.editor});

  final ShellServices services;
  final DeckEditorController editor;

  @override
  State<ThemesPanel> createState() => _ThemesPanelState();
}

class _ThemesPanelState extends State<ThemesPanel> {
  final _scroll = ScrollController();

  /// Where a click applies (panel state, 05 §9 "Apply to").
  bool _selectedOnly = false;

  DeckEditorController get ed => widget.editor;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _apply(SlidesCommandUi ui, Map<String, Object?> source) => ui.run(
    'slides.theme.apply',
    {...source, 'scope': _selectedOnly ? 'selected' : 'all'},
    InvocationSource.ui,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([ed, widget.services.registry]),
    builder: (context, _) {
      final l = slidesL10n(context);
      final theme = ShadTheme.of(context);
      final ui = SlidesCommandUi(context, widget.services);
      final previews = ThemePreviews.of(ed)..subtitle = l.themePreviewSubtitle;
      final m = ed.model;
      final appearance = m.deck?.appearance ?? SlideAppearance.light;
      final canApply = ui.state('slides.theme.apply').enabled;
      final defaultId = m.indexes.themes.defaultTheme?.id;

      Widget heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(
          text,
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
      );

      final selectedCount = ed.selectedSlideIds.length;
      final children = <Widget>[
        heading(l.inspectorAppearance),
        _appearance(ui, l, appearance),
        heading(l.themesApplyTo),
        ShadRadioGroup<bool>(
          key: ValueKey<String>('slides.themes.scope.$_selectedOnly'),
          initialValue: _selectedOnly,
          onChanged: (v) {
            if (v != null) setState(() => _selectedOnly = v);
          },
          items: [
            ShadRadio<bool>(
              key: ThemesPanelKeys.scopeAll,
              value: false,
              label: Text(l.themesApplyAll),
            ),
            ShadRadio<bool>(
              key: ThemesPanelKeys.scopeSelected,
              value: true,
              label: Text(
                l.themesApplySelected(selectedCount == 0 ? 1 : selectedCount),
              ),
            ),
          ],
        ),
        heading(l.themesInPresentation),
        for (final t in m.themes)
          _deckThemeRow(
            context,
            ui,
            l,
            previews,
            t,
            appearance: appearance,
            isDefault: t.id == defaultId,
            enabled: canApply,
          ),
        if (unusedThemes(m).isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: ShadButton.link(
              key: ThemesPanelKeys.removeUnused,
              size: ShadButtonSize.sm,
              padding: EdgeInsets.zero,
              enabled: ui.state('slides.theme.removeUnused').enabled,
              onPressed: () => ui.run(
                'slides.theme.removeUnused',
                const {},
                InvocationSource.ui,
              ),
              child: Text(l.cmdThemeRemoveUnused),
            ),
          ),
        heading(l.themesBuiltIn),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 440 ? 3 : 2;
            final w = (c.maxWidth - (cols - 1) * 6) / cols - 12;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final def in BuiltInThemes.all)
                  _builtInCard(
                    ui,
                    previews,
                    def,
                    width: w.clamp(80, 220).toDouble(),
                    appearance: appearance,
                    current: _builtInCopy(m, def)?.id == defaultId,
                    enabled: canApply,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        ShadButton.outline(
          key: ThemesPanelKeys.import,
          size: ShadButtonSize.sm,
          enabled: ui.state('slides.theme.import').enabled,
          leading: const Icon(LucideIcons.fileInput, size: 14),
          onPressed: () =>
              ui.run('slides.theme.import', const {}, InvocationSource.ui),
          child: Flexible(
            child: Text(
              l.themesImport,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ];
      return Semantics(
        container: true,
        label: l.themesPanelTitle,
        child: KeyedSubtree(
          key: ThemesPanelKeys.panel,
          child: WonkyScrollArea(
            controller: _scroll,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              children: children,
            ),
          ),
        ),
      );
    },
  );

  /// The deck's copy of built-in [def] (by `sourceKey`), if any.
  static DeckThemeRec? _builtInCopy(DeckModel m, BuiltInThemeDef def) {
    final key = SlidesIds.builtinThemeSourceKey(def.key, def.version);
    return m.themes.where((t) => t.sourceKey == key).firstOrNull;
  }

  Widget _appearance(
    SlidesCommandUi ui,
    SlidesLocalizations l,
    SlideAppearance current,
  ) {
    Widget button(SlideAppearance a, String label, IconData icon) {
      final args = {'appearance': a.name};
      final st = ui.state('slides.deck.setAppearance', args);
      final on = a == current;
      void run() =>
          ui.run('slides.deck.setAppearance', args, InvocationSource.ui);
      return Expanded(
        child: Semantics(
          selected: on,
          child: on
              ? ShadButton.secondary(
                  key: ThemesPanelKeys.appearance(a),
                  size: ShadButtonSize.sm,
                  enabled: st.enabled,
                  leading: Icon(icon, size: 14),
                  onPressed: run,
                  child: Text(label),
                )
              : ShadButton.ghost(
                  key: ThemesPanelKeys.appearance(a),
                  size: ShadButtonSize.sm,
                  enabled: st.enabled,
                  leading: Icon(icon, size: 14),
                  onPressed: run,
                  child: Text(label),
                ),
        ),
      );
    }

    return Row(
      spacing: 4,
      children: [
        button(SlideAppearance.light, l.appearanceLight, LucideIcons.sun),
        button(SlideAppearance.dark, l.appearanceDark, LucideIcons.moon),
      ],
    );
  }

  Widget _deckThemeRow(
    BuildContext context,
    SlidesCommandUi ui,
    SlidesLocalizations l,
    ThemePreviews previews,
    DeckThemeRec t, {
    required SlideAppearance appearance,
    required bool isDefault,
    required bool enabled,
  }) {
    final theme = ShadTheme.of(context);
    final deck = previews.deckTheme(t.id);
    final card = deck?.cardSlideId;
    final used = ed.model.indexes.themes.slidesUsingTheme(t.id);
    final name = t.name.isEmpty ? l.themeUntitled : t.name;
    final menu = WonkyDropdownMenu(
      anchor: const ShadAnchor(
        childAlignment: AlignmentDirectional.bottomEnd,
        overlayAlignment: AlignmentDirectional.topEnd,
        offset: Offset(0, 4),
      ),
      entries: () => MenuResolver(widget.services).entries(context, [
        for (final id in [
          'slides.theme.rename',
          'slides.theme.duplicate',
          'slides.theme.setDefault',
          'slides.theme.edit',
          'slides.theme.delete',
        ])
          MenuSpec.command(
            id,
            args: {'themeId': t.id},
            id: 'themes.${t.id}.${id.split('.').last}',
          ),
      ]),
      builder: (context, c) => ShadIconButton.ghost(
        key: ThemesPanelKeys.deckThemeMenu(t.id),
        width: 28,
        height: 28,
        iconSize: 16,
        semanticLabel: l.themesMore(name),
        icon: const Icon(LucideIcons.ellipsisVertical),
        onPressed: c.toggle,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: PreviewCard(
              key: ThemesPanelKeys.deckTheme(t.id),
              label: name,
              semanticsHint: l.themesUsedBy(used),
              selected: isDefault,
              onPressed: enabled ? () => _apply(ui, {'themeId': t.id}) : null,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: deck == null || card == null
                        ? const SizedBox(width: 96, height: 54)
                        : ThemePreviewThumbnail(
                            deck: deck,
                            slideId: card,
                            width: 96,
                            appearance: appearance,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isDefault)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: ShadBadge.secondary(
                              child: Text(l.themesDefault),
                            ),
                          ),
                        Text(
                          l.themesUsedBy(used),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          menu,
        ],
      ),
    );
  }

  Widget _builtInCard(
    SlidesCommandUi ui,
    ThemePreviews previews,
    BuiltInThemeDef def, {
    required double width,
    required SlideAppearance appearance,
    required bool current,
    required bool enabled,
  }) {
    final deck = previews.builtIn(def.key);
    final card = deck.cardSlideId;
    return PreviewCard(
      key: ThemesPanelKeys.builtIn(def.key),
      label: def.name,
      selected: current,
      onPressed: enabled ? () => _apply(ui, {'builtin': def.key}) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: card == null
                ? SizedBox(width: width, height: width * 9 / 16)
                : ThemePreviewThumbnail(
                    deck: deck,
                    slideId: card,
                    width: width,
                    appearance: appearance,
                  ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: width,
            child: Text(
              def.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ShadTheme.of(
                context,
              ).textTheme.small.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
