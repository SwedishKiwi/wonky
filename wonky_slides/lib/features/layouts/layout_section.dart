import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart' show InvocationSource;

import '../../config/slides_features.dart';
import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import '../toolbar/command_ui.dart';
import 'layout_gallery.dart';

/// Inspector › Slide › **Layout** (Slides 04 §7.4): the layout gallery of
/// the current slide's theme (`slides.slide.applyLayout` on the selected
/// slides), *Reset slide to layout* and *Edit layout* (master mode).
Widget layoutSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final ui = SlidesCommandUi(context, services);
  final l = slidesL10n(context);
  final enabled = ui.state('slides.slide.applyLayout').enabled;
  Widget button(String id, String label, {Map<String, Object?>? args}) {
    final st = ui.state(id, args ?? const {});
    final b = ShadButton.outline(
      key: ValueKey<String>('slides.inspector.layout.$id'),
      size: ShadButtonSize.sm,
      enabled: st.enabled,
      onPressed: () => ui.run(id, args ?? const {}, InvocationSource.ui),
      child: Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    final reason = st.disabledReason;
    return st.enabled || reason == null
        ? b
        : ShadTooltip(builder: (_) => Text(reason), child: b);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (context, c) {
          // Two or three thumbnails per row at inspector widths.
          final cols = c.maxWidth >= 300 ? 3 : 2;
          final w = ((c.maxWidth - (cols - 1) * 4) / cols - 12)
              .clamp(56, 140)
              .toDouble();
          // A bounded, scrollable strip (about two rows), so the other
          // Slide-tab sections stay in reach.
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 2 * (w * 9 / 16 + 34) + 4),
            child: SingleChildScrollView(
              child: LayoutGallery(
                editor: ed,
                thumbWidth: w,
                enabled: enabled,
                onSelected: (layout) => ui.run('slides.slide.applyLayout', {
                  'layoutId': layout.id,
                }, InvocationSource.ui),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          button('slides.slide.resetToLayout', l.cmdSlideResetToLayout),
          // Layout editing is SL-28's (hidden until built, SL-23).
          if (SlidesFeatures.isOn(SlidesFeature.masters))
            button(
              'slides.view.setMode',
              l.menuEditLayout,
              args: const {'mode': 'masters'},
            ),
        ],
      ),
    ],
  );
}
