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
/// pending) or when it can't be shown. An image whose upload from this
/// device was refused on quota gets the "Not uploaded — out of storage"
/// overlay with *Retry* and *Remove* (Drive 03 §6.3).
class ImageObjectView extends StatelessWidget {
  const ImageObjectView({
    super.key,
    required this.service,
    required this.spec,
    this.onRemove,
  });

  final SheetsImageService service;
  final ImageSpec spec;

  /// Deletes the image object (*Remove* on the out-of-storage overlay);
  /// null hides the button (viewers).
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final fileUuid = spec.fileUuid;
    if (fileUuid.isEmpty) return _image(context);
    return ListenableBuilder(
      listenable: service.uploadStates,
      builder: (context, _) {
        final image = _image(context);
        if (!service.isOutOfStorage(fileUuid)) return image;
        return Stack(
          fit: StackFit.expand,
          children: [
            image,
            ImageOutOfStorageOverlay(
              onRetry: () => service.retryUpload(fileUuid),
              onRemove: onRemove == null
                  ? null
                  : () {
                      service.forgetUpload(fileUuid);
                      onRemove!();
                    },
            ),
          ],
        );
      },
    );
  }

  Widget _image(BuildContext context) {
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
        // Animated GIFs play in the editor (first frame with reduced
        // motion, in exports and in print; 08 §10.1).
        final animated = s.animated;
        if (s.phase == ImageLoadPhase.ready &&
            animated != null &&
            !MediaQuery.disableAnimationsOf(context)) {
          return Image.memory(
            animated,
            key: ValueKey<String>('sheets.image.animated.$src'),
            fit: boxFitOf(spec.fit),
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          );
        }
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

/// "Not uploaded — out of storage" with *Retry* / *Remove* over an image
/// whose upload was refused on quota (Drive 03 §6.3, 08 §10).
class ImageOutOfStorageOverlay extends StatelessWidget {
  const ImageOutOfStorageOverlay({
    super.key,
    required this.onRetry,
    this.onRemove,
  });

  final VoidCallback onRetry;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final l = sheetsL10n(context);
    return ColoredBox(
      key: const ValueKey<String>('sheets.image.outOfStorage'),
      color: theme.colorScheme.destructive.withValues(alpha: 0.82),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.imageNotUploadedOutOfStorage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.destructiveForeground,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShadButton.secondary(
                      key: const ValueKey<String>('sheets.image.retryUpload'),
                      size: ShadButtonSize.sm,
                      onPressed: onRetry,
                      child: Text(l.imageRetryUpload),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: 6),
                      ShadButton.outline(
                        key: const ValueKey<String>('sheets.image.remove'),
                        size: ShadButtonSize.sm,
                        onPressed: onRemove,
                        child: Text(l.imageRemove),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
