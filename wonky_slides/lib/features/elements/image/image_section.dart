import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_slides_core/model.dart' hide SlidesText;

import '../../editor_screen/deck_editor_controller.dart';
import '../../uploads/slides_image_service.dart';
import '../style/style_sections.dart';

/// Inspector › Format › **Image** (04 §7.2, 03 §6.5): *Replace image*,
/// *Crop*, *Mask with shape*, *Reset image*, *Download original*, the
/// adjustments (brightness, contrast, saturation, temperature −100…100,
/// blur 0…40; grayscale, sepia, invert; *Reset adjustments* — each written
/// on release, one undo step), and the upload state of an image the
/// server refused for storage (*Retry* / *Remove*).
Widget imageSection(
  BuildContext context,
  ShellServices services,
  DeckEditorController ed,
) {
  final s = StyleScope(context, services, ed);
  final images = [
    for (final e in s.targets)
      if (e.record.kind == ElementKind.image) e,
  ];
  if (images.length != 1) return const SizedBox.shrink();
  final e = images.single;
  final theme = ShadTheme.of(context);
  final data = e.data ?? const <String, Object?>{};
  final adjust = data['adjust'] is Map
      ? (data['adjust'] as Map).cast<String, Object?>()
      : const <String, Object?>{};
  final src = data['src'];
  final uuid = src is String ? SlidesImageService.fileUuidOf(src) : null;
  final service = SlidesImageService.of(ed);

  Widget button(String id, IconData icon, {Map<String, Object?>? args}) =>
      ShadButton.outline(
        key: ValueKey<String>('slides.image.section.$id'),
        size: ShadButtonSize.sm,
        enabled: s.enabled(id, args ?? const {}),
        leading: Icon(icon, size: 14),
        onPressed: () => s.run(id, args ?? const {}),
        child: Flexible(
          child: Text(
            s.ui.title(id),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );

  Widget slider(String key, String label, double min, double max) {
    final v = adjust[key];
    final value = v is num
        ? (key == 'blur' ? v.toDouble() : v.toDouble() * 100)
        : 0.0;
    return InspectorRow(
      label: label,
      child: AdjustSlider(
        keyName: key,
        value: value,
        min: min,
        max: max,
        enabled: s.enabled('slides.image.adjust', {key: 0}),
        onCommit: (x) => s.run('slides.image.adjust', {key: x.roundToDouble()}),
      ),
    );
  }

  Widget toggle(String key, String label) => InspectorRow(
    label: label,
    child: ShadSwitch(
      key: ValueKey<String>('slides.image.adjust.$key'),
      value: adjust[key] == true,
      enabled: s.enabled('slides.image.adjust', {key: true}),
      onChanged: (v) => s.run('slides.image.adjust', {key: v}),
    ),
  );

  return ListenableBuilder(
    listenable: service.uploadStates,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (uuid != null && service.isOutOfStorage(uuid))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  s.l.imageNotUploadedOutOfStorage,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.destructive,
                  ),
                ),
                button('slides.image.retryUpload', LucideIcons.refreshCw),
                button('slides.image.removeNotUploaded', LucideIcons.trash2),
              ],
            ),
          )
        else if (uuid != null && service.isUploading(uuid))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.l.imageUploading,
              key: const ValueKey<String>('slides.image.section.uploading'),
              style: theme.textTheme.muted,
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            button('slides.image.replace', LucideIcons.imageUp),
            button('slides.image.crop', LucideIcons.crop),
            button('slides.image.mask', LucideIcons.squareDashed),
            button('slides.image.reset', LucideIcons.rotateCcw),
            button('slides.image.downloadOriginal', LucideIcons.download),
          ],
        ),
        const SizedBox(height: 12),
        Text(s.l.imageAdjustments, style: theme.textTheme.small),
        const SizedBox(height: 8),
        slider('brightness', s.l.imageBrightness, -100, 100),
        slider('contrast', s.l.imageContrast, -100, 100),
        slider('saturation', s.l.imageSaturation, -100, 100),
        slider('temperature', s.l.imageTemperature, -100, 100),
        slider('blur', s.l.imageBlur, 0, 40),
        toggle('grayscale', s.l.imageGrayscale),
        toggle('sepia', s.l.imageSepia),
        toggle('invert', s.l.imageInvert),
        Align(
          alignment: Alignment.centerLeft,
          child: button(
            'slides.image.adjust',
            LucideIcons.rotateCcw,
            args: const {'reset': true},
          ),
        ),
      ],
    ),
  );
}

/// A slider that commits once on release (one undo step per drag).
class AdjustSlider extends StatefulWidget {
  const AdjustSlider({
    super.key,
    required this.keyName,
    required this.value,
    required this.min,
    required this.max,
    required this.onCommit,
    this.enabled = true,
  });

  final String keyName;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onCommit;
  final bool enabled;

  @override
  State<AdjustSlider> createState() => _AdjustSliderState();
}

class _AdjustSliderState extends State<AdjustSlider> {
  double? _live;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final v = (_live ?? widget.value).clamp(widget.min, widget.max);
    return Row(
      children: [
        Expanded(
          child: ShadSlider(
            key: ValueKey<String>(
              'slides.image.adjust.${widget.keyName}.${widget.value}',
            ),
            initialValue: v,
            min: widget.min,
            max: widget.max,
            enabled: widget.enabled,
            onChanged: (x) => setState(() => _live = x),
            onChangeEnd: (x) {
              setState(() => _live = null);
              widget.onCommit(x);
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 32,
          child: Text(
            '${v.round()}',
            style: theme.textTheme.small,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
