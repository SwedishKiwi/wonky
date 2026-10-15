import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;

import '../../editor_screen/deck_editor_controller.dart';
import '../style/element_style.dart';
import '../style/style_sections.dart';
import 'line_tool.dart';

/// Inspector › Format › **Line** (04 §7.2): color, weight, dash, ends,
/// arrowheads start/end + size, routing.
Widget lineSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final lines = [
    for (final e in s.targets)
      if (e.record.kind == ElementKind.line) e,
  ];
  final theme = s.theme;
  final on = s.enabled('slides.line.setRouting', const {'routing': 'straight'});
  String? arrow(String key) => ElementStyle.common(lines, (e) {
    final st = theme == null ? null : ElementStyle.effectiveStroke(e, theme);
    return (key == 'start' ? st?.startArrow : st?.endArrow) ?? 'none';
  });
  final size = ElementStyle.common(lines, (e) {
    final st = theme == null ? null : ElementStyle.effectiveStroke(e, theme);
    return st?.arrowSize ?? 'm';
  });
  final routing = ElementStyle.common(
    lines,
    (e) => '${e.data?['routing'] ?? 'straight'}',
  );
  Widget arrowRow(String end, String label) => InspectorRow(
    label: label,
    child: StyleSelect<String>(
      keyName: 'line.$end',
      value: arrow(end),
      options: arrowStyles,
      label: (v) => s.l.arrowStyleName(v),
      enabled: on,
      placeholder: s.l.styleMixed,
      onChanged: (v) => s.run('slides.line.setArrow', {'end': end, 'style': v}),
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      strokeControls(s, lines, keyName: 'line', line: true),
      arrowRow('start', s.l.lineStartArrow),
      arrowRow('end', s.l.lineEndArrow),
      InspectorRow(
        label: s.l.styleLabelArrowSize,
        child: StyleSelect<String>(
          keyName: 'line.arrowSize',
          value: size,
          options: arrowSizes,
          label: (v) => s.l.arrowSizeName(v),
          enabled: on,
          placeholder: s.l.styleMixed,
          onChanged: (v) =>
              s.run('slides.line.setArrow', {'end': 'both', 'size': v}),
        ),
      ),
      InspectorRow(
        label: s.l.styleLabelRouting,
        child: StyleSelect<String>(
          keyName: 'line.routing',
          value: routing,
          options: lineRoutings,
          label: (v) => s.l.routingName(v),
          enabled: on,
          placeholder: s.l.styleMixed,
          onChanged: (v) => s.run('slides.line.setRouting', {'routing': v}),
        ),
      ),
    ],
  );
}
