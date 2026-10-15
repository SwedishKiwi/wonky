import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../elements/style/style_sections.dart';
import '../toolbar/command_ui.dart';

/// The stored solid color of a slide `backgroundJson` (`theme:bg2`,
/// `#RRGGBB`), or null (inherited, or not a solid fill).
String? backgroundColorOf(String? backgroundJson) {
  if (backgroundJson == null) return null;
  try {
    final j = jsonDecode(backgroundJson);
    final fill = j is Map ? j['fill'] : null;
    if (fill is Map && fill['type'] == 'solid' && fill['color'] is String) {
      return fill['color'] as String;
    }
  } on FormatException {
    // Not JSON: treated as inherited.
  }
  return null;
}

/// Inspector › Slide › **Background** (Slides 04 §7.4): a solid color
/// (theme colors first, so it follows the appearance), *Reset to layout
/// background* and *Apply to all slides*. Gradient and image backgrounds
/// are drawn when present (from themes and templates) but not edited here
/// yet (`TODO.md`).
Widget backgroundSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final ui = SlidesCommandUi(context, services);
  final l = slidesL10n(context);
  final id = ed.currentSlideId;
  final slide = id == null ? null : ed.model.slide(id);
  final resolved = id == null ? null : ed.resolver.resolve(id);
  final theme = resolved?.theme;
  final swatch = resolved == null
      ? null
      : Color(
          resolved.background.effectiveColor(
            theme?.colorOf('bg1') ?? 0xffffffff,
          ),
        );
  final st = ui.state('slides.slide.setBackground', const {'reset': true});
  final hasOwn = slide?.backgroundJson != null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InspectorRow(
        label: l.styleLabelColor,
        child: StyleColorButton(
          keyName: 'background',
          label: l.sectionBackground,
          value: backgroundColorOf(slide?.backgroundJson),
          swatch: swatch,
          theme: theme,
          resetLabel: l.backgroundResetToLayout,
          enabled: st.enabled,
          onChanged: (c) => ui.run(
            'slides.slide.setBackground',
            c == null ? const {'reset': true} : {'color': c},
            InvocationSource.ui,
          ),
        ),
      ),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ShadButton.outline(
            key: const ValueKey<String>('slides.inspector.background.reset'),
            size: ShadButtonSize.sm,
            enabled: st.enabled && hasOwn,
            onPressed: () => ui.run('slides.slide.setBackground', const {
              'reset': true,
            }, InvocationSource.ui),
            child: Flexible(
              child: Text(
                l.backgroundResetToLayout,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          ShadButton.outline(
            key: const ValueKey<String>('slides.inspector.background.applyAll'),
            size: ShadButtonSize.sm,
            enabled: ui.state('slides.slide.applyBackgroundToAll').enabled,
            onPressed: () => ui.run(
              'slides.slide.applyBackgroundToAll',
              const {},
              InvocationSource.ui,
            ),
            child: Flexible(
              child: Text(
                l.cmdSlideApplyBackgroundToAll,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
