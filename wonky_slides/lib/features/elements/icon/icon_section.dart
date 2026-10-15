import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/icons.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;

import '../../editor_screen/deck_editor_controller.dart';
import '../style/element_style.dart';
import '../style/style_sections.dart';

/// Inspector › Format › **Icon** (04 §7.2): the icon (*Replace icon…*),
/// color, stroke width (Lucide icons) and background fill.
Widget iconSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final theme = ShadTheme.of(context);
  final icons = [
    for (final e in s.targets)
      if (e.record.kind == ElementKind.icon) e,
  ];
  final lucide = [
    for (final e in icons)
      if (e.data?['set'] != 'emoji') e,
  ];
  final rt = s.theme;
  final argb = rt == null
      ? null
      : ElementStyle.common(lucide, (e) => ElementStyle.strokeArgb(e, rt));
  final name = icons.length == 1
      ? (icons.single.data?['set'] == 'emoji'
            ? '${icons.single.data?['char'] ?? ''}'
            : LucideCatalog.of('${icons.single.data?['name']}')?.label ??
                  '${icons.single.data?['name'] ?? ''}')
      : s.l.styleMixed;
  final width = ElementStyle.common(
    lucide,
    (e) => LucideGlyphs.snapStrokeWidth(e.data?['strokeWidth'] as num?),
  );
  final strokeOn = s.enabled('slides.icon.setStrokeWidth', const {'value': 2});
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorRow(
        label: s.l.styleLabelIcon,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ShadButton.outline(
            key: const ValueKey<String>('slides.style.icon.replace'),
            size: ShadButtonSize.sm,
            enabled: s.enabled('slides.icon.replace'),
            leading: const Icon(LucideIcons.replace, size: 14),
            onPressed: () => s.run('slides.icon.replace'),
            child: Flexible(
              child: Text(
                s.ui.title('slides.icon.replace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      if (lucide.isNotEmpty) ...[
        InspectorRow(
          label: s.l.styleLabelColor,
          child: StyleColorButton(
            keyName: 'icon',
            label: s.l.menuIconColor,
            value: s.storedColor(lucide, (e) => e.stroke, 'color'),
            swatch: argb == null ? null : Color(argb),
            theme: rt,
            resetLabel: s.l.colorThemeDefault,
            enabled: s.enabled('slides.format.stroke', const {'reset': true}),
            onChanged: (c) => s.run(
              'slides.format.stroke',
              c == null ? const {'reset': true} : {'color': c},
            ),
          ),
        ),
        InspectorRow(
          label: s.l.styleLabelStrokeWidth,
          child: StyleSelect<double>(
            keyName: 'icon.strokeWidth',
            value: width,
            options: LucideGlyphs.strokeWidths,
            label: (w) => w == w.roundToDouble() ? '${w.toInt()}' : '$w',
            enabled: strokeOn,
            placeholder: s.l.styleMixed,
            onChanged: (w) => s.run('slides.icon.setStrokeWidth', {'value': w}),
          ),
        ),
      ],
      const SizedBox(height: 4),
      fillSection(context, services, ed),
    ],
  );
}
