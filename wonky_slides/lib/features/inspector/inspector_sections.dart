import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../elements/chart/chart_section.dart';
import '../elements/code/code_section.dart';
import '../elements/common/arrange_section.dart';
import '../elements/icon/icon_section.dart';
import '../elements/image/image_section.dart';
import '../elements/line/line_section.dart';
import '../elements/style/style_sections.dart';
import '../elements/table/table_sections.dart';
import '../elements/text/text_inspector_section.dart';
import '../layouts/layout_section.dart';
import '../themes/background_section.dart';

/// Builds the body of an inspector section.
typedef InspectorSectionBuilder =
    Widget Function(
      BuildContext context,
      ShellServices services,
      DeckEditorController ed,
    );

/// One section of the docked inspector (Slides 04 §7): an accordion item
/// on the Format or Slide tab. [kinds] lists the selection kinds whose
/// Format tab shows it (04 §7.2; empty for Slide-tab sections). Format
/// sections without a [builder] are hidden until their work package
/// supplies the body; Slide-tab sections get theirs from the inspector.
class InspectorSectionSpec {
  const InspectorSectionSpec({
    required this.id,
    required this.title,
    required this.tab,
    this.kinds = const {},
    this.builder,
  });

  /// Stable id (`slides.inspector.open {section}`).
  final String id;
  final String Function(SlidesLocalizations l) title;
  final InspectorTab tab;
  final Set<DeckSelectionKind> kinds;
  final InspectorSectionBuilder? builder;
}

const _textual = {
  DeckSelectionKind.text,
  DeckSelectionKind.shape,
  DeckSelectionKind.table,
};

/// The inspector's section registry (Slides 04 §7.2 / §7.4 in order).
/// Work packages that build a section's controls set its [builder] here
/// (a one-line change, Slides 12 §2) with the widget from their own
/// feature folder.
final List<InspectorSectionSpec> inspectorSections = [
  // ---- Format tab (by selection, 04 §7.2)
  const InspectorSectionSpec(
    id: 'text',
    title: _sectionText,
    tab: InspectorTab.format,
    kinds: _textual,
    builder: textInspectorSection,
  ),
  const InspectorSectionSpec(
    id: 'line',
    title: _sectionLine,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.line},
    builder: lineSection,
  ),
  const InspectorSectionSpec(
    id: 'image',
    title: _sectionImage,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.image},
    builder: imageSection,
  ),
  const InspectorSectionSpec(
    id: 'table',
    title: _sectionTable,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.table},
    builder: tableSection,
  ),
  const InspectorSectionSpec(
    id: 'cell',
    title: _sectionCell,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.table},
    builder: cellSection,
  ),
  const InspectorSectionSpec(
    id: 'icon',
    title: _sectionIcon,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.icon},
    builder: iconSection,
  ),
  const InspectorSectionSpec(
    id: 'code',
    title: _sectionCode,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.code},
    builder: codeSection,
  ),
  const InspectorSectionSpec(
    id: 'chart',
    title: _sectionChart,
    tab: InspectorTab.format,
    kinds: {DeckSelectionKind.chart},
    builder: chartSection,
  ),
  const InspectorSectionSpec(
    id: 'fill',
    title: _sectionFill,
    tab: InspectorTab.format,
    kinds: {
      DeckSelectionKind.text,
      DeckSelectionKind.shape,
      DeckSelectionKind.multiple,
    },
    builder: fillSection,
  ),
  const InspectorSectionSpec(
    id: 'border',
    title: _sectionBorder,
    tab: InspectorTab.format,
    kinds: {
      DeckSelectionKind.text,
      DeckSelectionKind.shape,
      DeckSelectionKind.image,
      DeckSelectionKind.multiple,
    },
    builder: borderSection,
  ),
  const InspectorSectionSpec(
    id: 'effects',
    title: _sectionEffects,
    tab: InspectorTab.format,
    kinds: {
      DeckSelectionKind.text,
      DeckSelectionKind.shape,
      DeckSelectionKind.line,
      DeckSelectionKind.image,
      DeckSelectionKind.code,
      DeckSelectionKind.group,
      DeckSelectionKind.multiple,
    },
    builder: effectsSection,
  ),
  const InspectorSectionSpec(
    id: 'arrange',
    title: _sectionArrange,
    tab: InspectorTab.format,
    kinds: {
      DeckSelectionKind.text,
      DeckSelectionKind.shape,
      DeckSelectionKind.line,
      DeckSelectionKind.image,
      DeckSelectionKind.table,
      DeckSelectionKind.icon,
      DeckSelectionKind.code,
      DeckSelectionKind.chart,
      DeckSelectionKind.group,
      DeckSelectionKind.multiple,
    },
    builder: arrangeSection,
  ),
  const InspectorSectionSpec(
    id: 'link',
    title: _sectionLink,
    tab: InspectorTab.format,
    kinds: {
      DeckSelectionKind.text,
      DeckSelectionKind.shape,
      DeckSelectionKind.image,
      DeckSelectionKind.icon,
    },
  ),
  const InspectorSectionSpec(
    id: 'accessibility',
    title: _sectionAccessibility,
    tab: InspectorTab.format,
    kinds: {
      DeckSelectionKind.text,
      DeckSelectionKind.shape,
      DeckSelectionKind.image,
      DeckSelectionKind.icon,
      DeckSelectionKind.chart,
      DeckSelectionKind.group,
    },
    builder: accessibilitySection,
  ),
  // ---- Slide tab (04 §7.4); bodies in `slide_tab.dart` until SL-16/17.
  const InspectorSectionSpec(
    id: 'layout',
    title: _sectionLayout,
    tab: InspectorTab.slide,
    builder: layoutSection,
  ),
  const InspectorSectionSpec(
    id: 'background',
    title: _sectionBackground,
    tab: InspectorTab.slide,
    builder: backgroundSection,
  ),
  const InspectorSectionSpec(
    id: 'theme',
    title: _sectionTheme,
    tab: InspectorTab.slide,
  ),
  const InspectorSectionSpec(
    id: 'visibility',
    title: _sectionVisibility,
    tab: InspectorTab.slide,
  ),
  const InspectorSectionSpec(
    id: 'group',
    title: _sectionGroup,
    tab: InspectorTab.slide,
  ),
  const InspectorSectionSpec(
    id: 'info',
    title: _sectionInfo,
    tab: InspectorTab.slide,
  ),
];

/// The Format-tab sections for the current selection, in order. Sections
/// without a [InspectorSectionSpec.builder] belong to work that is not
/// built yet (code SL-31, chart SL-32, link editing) and are left out
/// (SL-23: the inspector only shows what works).
List<InspectorSectionSpec> formatSectionsFor(DeckSelectionKind kind) => [
  for (final s in inspectorSections)
    if (s.tab == InspectorTab.format &&
        s.kinds.contains(kind) &&
        s.builder != null)
      s,
];

/// The Slide-tab sections.
List<InspectorSectionSpec> get slideSections => [
  for (final s in inspectorSections)
    if (s.tab == InspectorTab.slide) s,
];

String _sectionText(SlidesLocalizations l) => l.sectionText;
String _sectionLine(SlidesLocalizations l) => l.sectionLine;
String _sectionImage(SlidesLocalizations l) => l.sectionImage;
String _sectionTable(SlidesLocalizations l) => l.sectionTable;
String _sectionCell(SlidesLocalizations l) => l.sectionCell;
String _sectionIcon(SlidesLocalizations l) => l.sectionIcon;
String _sectionCode(SlidesLocalizations l) => l.sectionCode;
String _sectionChart(SlidesLocalizations l) => l.sectionChart;
String _sectionFill(SlidesLocalizations l) => l.sectionFill;
String _sectionBorder(SlidesLocalizations l) => l.sectionBorder;
String _sectionEffects(SlidesLocalizations l) => l.sectionEffects;
String _sectionArrange(SlidesLocalizations l) => l.sectionArrange;
String _sectionLink(SlidesLocalizations l) => l.sectionLink;
String _sectionAccessibility(SlidesLocalizations l) => l.sectionAccessibility;
String _sectionLayout(SlidesLocalizations l) => l.sectionLayout;
String _sectionBackground(SlidesLocalizations l) => l.sectionBackground;
String _sectionTheme(SlidesLocalizations l) => l.sectionTheme;
String _sectionVisibility(SlidesLocalizations l) => l.sectionVisibility;
String _sectionGroup(SlidesLocalizations l) => l.sectionGroup;
String _sectionInfo(SlidesLocalizations l) => l.sectionInfo;
