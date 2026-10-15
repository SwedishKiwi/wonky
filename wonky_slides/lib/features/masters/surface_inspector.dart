import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';
import 'package:wonky_slides_core/model.dart' show DeckModelIndexes;
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../../config/menus/slides_menu_spec.dart' show placeholderTypeLabel;
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../elements/style/style_sections.dart';
import '../inspector/inspector_sections.dart';
import '../themes/background_section.dart' show backgroundColorOf;
import '../themes/editor/theme_editor_controls.dart';
import '../toolbar/command_ui.dart';
import 'masters_targets.dart';

/// Inspector › **Layout** / **Master** in masters mode (Slides 05 §8.1;
/// SL-28): the Slide tab's place, editing the layout or master on the
/// canvas — name, usage, *Hide master objects*, *Hidden in layout picker*
/// (layouts), background, the placeholders with *Insert placeholder*, and
/// the theme.
final List<InspectorSectionSpec> mastersSurfaceSections = [
  InspectorSectionSpec(
    id: 'surface',
    title: (l) => l.mastersSectionProperties,
    tab: InspectorTab.slide,
    builder: _properties,
  ),
  InspectorSectionSpec(
    id: 'background',
    title: (l) => l.sectionBackground,
    tab: InspectorTab.slide,
    builder: _background,
  ),
  InspectorSectionSpec(
    id: 'placeholders',
    title: (l) => l.mastersSectionPlaceholders,
    tab: InspectorTab.slide,
    builder: _placeholders,
  ),
];

Widget _button(
  SlidesCommandUi ui,
  String id, {
  Map<String, Object?> args = const {},
  String? label,
  IconData? icon,
}) {
  final st = ui.state(id, args);
  final b = ShadButton.outline(
    key: ValueKey<String>('slides.masters.inspector.$id'),
    size: ShadButtonSize.sm,
    enabled: st.enabled,
    leading: icon == null ? null : Icon(icon, size: 14),
    onPressed: () => ui.run(id, args, InvocationSource.ui),
    child: Flexible(
      child: Text(
        label ?? ui.title(id),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
  final reason = st.disabledReason;
  return st.enabled || reason == null
      ? b
      : ShadTooltip(builder: (_) => Text(reason), child: b);
}

Widget _switch(
  SlidesCommandUi ui,
  String id,
  String label,
  bool value,
  Map<String, Object?> args,
) {
  final st = ui.state(id, args);
  return InspectorRow(
    label: label,
    child: ShadSwitch(
      key: ValueKey<String>('slides.masters.inspector.switch.$id'),
      value: value,
      enabled: st.enabled,
      onChanged: (v) => ui.run(id, {...args, 'value': v}, InvocationSource.ui),
    ),
  );
}

Widget _properties(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final ui = SlidesCommandUi(context, services);
  final l = slidesL10n(context);
  final theme = ShadTheme.of(context);
  final id = ed.surfaceId;
  final layout = id == null ? null : ed.model.layout(id);
  final master = MastersTargets.master(ed, const JsonArgs());
  if (layout == null && master == null) {
    return Text(l.mastersBannerNone, style: theme.textTheme.muted);
  }
  final ix = ed.model.indexes.themes;
  final used = layout != null
      ? ix.slidesUsingLayout(layout.id)
      : ix.slidesUsingMaster(master!.id);
  final themeRec = MastersTargets.themeOfTarget(ed);
  final canEdit =
      ui.state('slides.layout.rename').enabled ||
      ui.state('slides.master.rename').enabled;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorRow(
        label: l.themeNameLabel,
        child: ThemeCommitField(
          keyName: 'surface.name',
          value: layout?.name ?? master!.name,
          enabled: canEdit,
          semanticLabel: l.themeNameLabel,
          onCommit: (v) => ui.run(
            layout != null ? 'slides.layout.rename' : 'slides.master.rename',
            {
              layout != null ? 'layoutId' : 'masterId':
                  layout?.id ?? master!.id,
              'name': v,
            },
            InvocationSource.ui,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          [
            l.themesUsedBy(used),
            if (themeRec != null) l.mastersOfTheme(themeRec.name),
          ].join(' · '),
          key: const ValueKey<String>('slides.masters.inspector.usage'),
          style: theme.textTheme.muted.copyWith(fontSize: 12),
        ),
      ),
      if (layout != null) ...[
        _switch(
          ui,
          'slides.layout.setHideMasterElements',
          l.cmdLayoutSetHideMasterElements,
          layout.hideMasterElements,
          {'layoutId': layout.id},
        ),
        _switch(
          ui,
          'slides.layout.toggleHidden',
          l.mastersHiddenInPicker,
          layout.hidden,
          {'layoutId': layout.id},
        ),
      ],
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: layout != null
            ? [
                _button(ui, 'slides.layout.duplicate', icon: LucideIcons.copy),
                _button(ui, 'slides.layout.delete', icon: LucideIcons.trash2),
              ]
            : [
                _button(ui, 'slides.layout.add', icon: LucideIcons.squarePlus),
                _button(ui, 'slides.master.duplicate', icon: LucideIcons.copy),
                _button(ui, 'slides.master.delete', icon: LucideIcons.trash2),
              ],
      ),
      const SizedBox(height: 8),
      _button(
        ui,
        'slides.inspector.open',
        args: const {'tab': 'theme'},
        label: l.cmdThemeEdit,
        icon: LucideIcons.palette,
      ),
    ],
  );
}

Widget _background(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final ui = SlidesCommandUi(context, services);
  final l = slidesL10n(context);
  final id = ed.surfaceId;
  final layout = id == null ? null : ed.model.layout(id);
  final master = layout == null && id != null ? ed.model.master(id) : null;
  if (layout == null && master == null) return const SizedBox.shrink();
  final cmd = layout != null
      ? 'slides.layout.setBackground'
      : 'slides.master.setBackground';
  final idArg = layout != null
      ? {'layoutId': layout.id}
      : {'masterId': master!.id};
  final own = layout?.backgroundJson ?? master?.backgroundJson;
  final resolved = ed.resolver.resolve(id!);
  final themeData = resolved?.theme;
  final swatch = resolved == null
      ? null
      : Color(
          resolved.background.effectiveColor(
            themeData?.colorOf('bg1') ?? 0xffffffff,
          ),
        );
  final resetLabel = layout != null
      ? l.mastersBackgroundUseMaster
      : l.mastersBackgroundUseTheme;
  final st = ui.state(cmd, idArg);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorRow(
        label: l.styleLabelColor,
        child: StyleColorButton(
          keyName: 'masters.background',
          label: l.sectionBackground,
          value: backgroundColorOf(own),
          swatch: swatch,
          theme: themeData,
          resetLabel: resetLabel,
          enabled: st.enabled,
          onChanged: (c) => ui.run(cmd, {
            ...idArg,
            if (c == null) 'reset': true else 'color': c,
          }, InvocationSource.ui),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: ShadButton.outline(
          key: const ValueKey<String>(
            'slides.masters.inspector.background.reset',
          ),
          size: ShadButtonSize.sm,
          enabled: st.enabled && own != null,
          onPressed: () =>
              ui.run(cmd, {...idArg, 'reset': true}, InvocationSource.ui),
          child: Flexible(
            child: Text(
              resetLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _placeholders(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final ui = SlidesCommandUi(context, services);
  final l = slidesL10n(context);
  final theme = ShadTheme.of(context);
  final id = ed.surfaceId;
  if (id == null) return const SizedBox.shrink();
  final placeholders = ed.model.indexes.placeholders.placeholdersOf(id);
  final enabled = ui.state('slides.layout.insertPlaceholder', {
    'type': 'body',
  }).enabled;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (placeholders.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(l.mastersNoPlaceholders, style: theme.textTheme.muted),
        ),
      for (final p in placeholders)
        Semantics(
          button: true,
          selected: ed.selectedElementIds.contains(p.id),
          child: ShadButton.ghost(
            key: ValueKey<String>('slides.masters.placeholder.${p.id}'),
            size: ShadButtonSize.sm,
            mainAxisAlignment: MainAxisAlignment.start,
            backgroundColor: ed.selectedElementIds.contains(p.id)
                ? theme.colorScheme.muted
                : null,
            leading: const Icon(LucideIcons.squareDashed, size: 14),
            onPressed: () {
              ed.selectElements([p.id]);
              ed.canvasFocus.requestFocus();
            },
            child: Flexible(
              child: Text(
                placeholderTypeLabel(l, p.placeholderType!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      const SizedBox(height: 6),
      InspectorRow(
        label: l.cmdLayoutInsertPlaceholder,
        child: ThemeSelect(
          keyName: 'insertPlaceholder',
          value: null,
          options: [for (final t in MastersTargets.insertable) t.name],
          labelOf: (v) =>
              placeholderTypeLabel(l, SlidePlaceholderType.fromName(v)!),
          placeholder: l.mastersChoosePlaceholder,
          enabled: enabled,
          onChanged: (v) => ui.run('slides.layout.insertPlaceholder', {
            'type': v,
          }, InvocationSource.ui),
        ),
      ),
    ],
  );
}
