import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_sheets_core/model.dart';

import '../../l10n/sheets_l10n.dart';
import 'image_service.dart';

/// `BoxFit` of an image spec's fit (08 §10.1).
BoxFit boxFitOf(ImageFit fit) => switch (fit) {
  ImageFit.stretch => BoxFit.fill,
  ImageFit.contain => BoxFit.contain,
  ImageFit.cover => BoxFit.cover,
};

/// An image over cells (08 §10.1): the decoded image, or a placeholder
/// while it loads ("Image uploading…" while another user's upload is
/// pending) or when it can't be shown.
class ImageObjectView extends StatelessWidget {
  const ImageObjectView({super.key, required this.service, required this.spec});

  final SheetsImageService service;
  final ImageSpec spec;

  @override
  Widget build(BuildContext context) {
    final src = spec.fileUuid.isNotEmpty
        ? spec.fileUuid
        : (spec.sourceUrl ?? '');
    if (src.isEmpty) {
      return const ImagePlaceholder(phase: ImageLoadPhase.failed);
    }
    return ValueListenableBuilder<LoadedImage>(
      valueListenable: service.image(src),
      builder: (context, s, _) {
        final img = s.image;
        if (s.phase == ImageLoadPhase.ready && img != null) {
          return RawImage(
            image: img,
            fit: boxFitOf(spec.fit),
            filterQuality: FilterQuality.medium,
          );
        }
        final phase = service.isUploading(spec.fileUuid)
            ? ImageLoadPhase.loading
            : s.phase;
        return ImagePlaceholder(phase: phase);
      },
    );
  }
}

/// Image placeholder card (loading, uploading elsewhere, failed).
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, required this.phase});

  final ImageLoadPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    final (icon, text) = switch (phase) {
      ImageLoadPhase.uploading => (LucideIcons.cloudUpload, l.imageUploading),
      ImageLoadPhase.failed => (LucideIcons.imageOff, l.imageUnavailable),
      _ => (LucideIcons.image, l.imageLoading),
    };
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.muted,
        border: Border.all(color: theme.colorScheme.border),
      ),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxHeight < 40 || c.maxWidth < 40) {
            return Icon(
              icon,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.mutedForeground),
              if (c.maxHeight >= 64) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    text,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
