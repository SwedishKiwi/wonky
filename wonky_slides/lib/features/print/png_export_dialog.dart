import 'package:flutter/widgets.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/slides_l10n.dart';
import '../editor_screen/deck_editor_controller.dart';
import 'slides_png_export.dart';

/// *File › Download ▸ PNG* (Slides 10 §13): which slides (current,
/// selected, all), the size (1×, 2×, 4× of the slide size in su, capped at
/// 7,680 px wide), which build state (as printed, after the last build,
/// each build stage) and a transparent background. A `WonkyDialogSpec`
/// (MCP-operable through `ui.get_dialog` / `ui.fill_dialog`). Returns the
/// chosen options (with [initial]'s file name and zip flag) or null.
Future<SlidesPngOptions?> showPngExportDialog(
  BuildContext context,
  DeckEditorController ed,
  SlidesPngOptions initial,
) async {
  final l = slidesL10n(context);
  final la = WonkyAppLocalizations.of(context);
  final deck = ed.model.deck;
  final sw = deck?.width ?? 1920, sh = deck?.height ?? 1080;
  final hasSelection = ed.selectedSlideIds.length > 1;
  final ranges = {
    'current': l.pngSlidesCurrent,
    if (hasSelection) 'selection': l.pngSlidesSelection,
    'all': l.pngSlidesAll,
  };
  final range = ranges.containsKey(initial.range)
      ? initial.range
      : (initial.range == 'selection' ? 'current' : 'all');
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: l.pngDialogTitle,
      description: l.pngDialogHint,
      dialogKey: 'dialog.slides.downloadPng',
      fields: [
        SelectFieldSpec(
          id: 'range',
          label: l.pngSlides,
          options: ranges,
          initial: range,
        ),
        SelectFieldSpec(
          id: 'scale',
          label: l.pngSize,
          options: {
            for (final k in SlidesPngOptions.scales)
              '$k': () {
                final (w, h) = SlidesPngExport.sizeOf(sw, sh, k);
                return l.pngSizeOption(k, w, h);
              }(),
          },
          initial: '${initial.scale}',
        ),
        SelectFieldSpec(
          id: 'frames',
          label: l.pngFrames,
          options: {
            SlidesImageFrames.print.id: l.pngFramesPrint,
            SlidesImageFrames.last.id: l.pngFramesFinal,
            SlidesImageFrames.builds.id: l.pngFramesBuilds,
          },
          initial: initial.frames.id,
        ),
        CheckboxFieldSpec(
          id: 'transparent',
          label: l.pngTransparent,
          initial: initial.transparent,
        ),
      ],
      buttons: [
        DialogButtonSpec(id: 'cancel', label: la.actionCancel),
        DialogButtonSpec(id: 'download', label: l.pngDownload, primary: true),
      ],
    ),
  );
  if (r?.buttonId != 'download') return null;
  return initial.copyWith(
    range: r!.text('range'),
    scale: int.tryParse(r.text('scale')) ?? initial.scale,
    frames: SlidesImageFrames.parse(r.text('frames')),
    transparent: r.flag('transparent'),
  );
}
