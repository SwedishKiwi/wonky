import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/files.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../../l10n/drive_l10n.dart';
import '../file_category_icon.dart';
import '../file_preview_controller.dart';
import '../preview_content.dart';

/// Loading: a page skeleton, plus a spinner after 300 ms (Drive 02 §6.1).
class PreviewLoading extends StatefulWidget {
  const PreviewLoading({super.key});

  static const spinnerDelay = Duration(milliseconds: 300);

  @override
  State<PreviewLoading> createState() => _PreviewLoadingState();
}

class _PreviewLoadingState extends State<PreviewLoading> {
  Timer? _timer;
  bool _spinner = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(PreviewLoading.spinnerDelay, () {
      if (mounted) setState(() => _spinner = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      label: driveL10n(context).previewLoading,
      liveRegion: true,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              key: const ValueKey<String>('drive.preview.skeleton'),
              width: 320,
              height: 220,
              decoration: BoxDecoration(
                color: cs.muted,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            if (_spinner)
              const ShadSpinner(key: ValueKey<String>('drive.preview.spinner')),
          ],
        ),
      ),
    );
  }
}

/// A centered message with an icon and actions (uploading, errors,
/// offline, too large, not found).
class PreviewMessage extends StatelessWidget {
  const PreviewMessage({
    super.key,
    required this.title,
    this.description,
    this.illustration,
    this.icon,
    this.actions = const [],
  });

  final String title;
  final String? description;
  final EmptyIllustration? illustration;
  final IconData? icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ill = illustration;
    if (ill != null) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: WonkyEmptyState(
            illustration: ill,
            title: title,
            description: description,
            actions: actions,
          ),
        ),
      );
    }
    final theme = ShadTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                Icon(icon, size: 40, color: theme.colorScheme.mutedForeground),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.large,
              ),
              if (description != null) ...[
                const SizedBox(height: 6),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "everything else" card (Drive 02 §6.7): category icon at 96 px,
/// name, "ZIP archive · 12.4 MB", owner, modified date, *Download* and,
/// for convertible types, *Open with*.
class UnsupportedFileView extends StatelessWidget {
  const UnsupportedFileView({
    super.key,
    required this.controller,
    this.title,
    this.message,
    this.icon,
  });

  final FilePreviewController controller;

  /// Overrides "No preview available" (e.g. "This PDF is password-protected").
  final String? title;

  /// A line under the title.
  final String? message;

  /// Overrides the category icon.
  final IconData? icon;

  static const cardKey = ValueKey<String>('drive.preview.unsupported');
  static const downloadKey = ValueKey<String>('drive.preview.card.download');

  @override
  Widget build(BuildContext context) {
    final item = controller.item!;
    final type = controller.type!;
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final s = controller.services;
    final me = s.me;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = intl.DateFormat.yMMMd(
      locale,
    ).format(item.modifiedAt.toLocal());
    final convert = type.convertTarget;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          key: cardKey,
          constraints: const BoxConstraints(maxWidth: 420),
          child: ShadCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null)
                  Icon(icon, size: 96, color: cs.mutedForeground)
                else
                  FileCategoryIcon(type.category, size: 96),
                const SizedBox(height: 16),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.large,
                ),
                const SizedBox(height: 4),
                Text(
                  l.previewTypeSize(
                    fileTypeLabel(l, type.category, type.extension),
                    formatStorageBytes(item.sizeBytes),
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 2),
                Text(
                  me != null && item.owner.id == me.id
                      ? l.previewOwnedByMe
                      : l.previewOwnedBy(item.owner.displayName),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
                Text(
                  l.previewModified(date),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 16),
                Text(
                  title ?? l.previewNoPreview,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.p,
                ),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.muted,
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (controller.canDownload)
                      ShadButton(
                        key: downloadKey,
                        leading: const Icon(LucideIcons.download, size: 16),
                        onPressed: () => s.dispatcher.invoke(
                          'drive.file.download',
                          context: context,
                        ),
                        child: Text(l.previewDownload),
                      ),
                    if (convert != null)
                      ShadButton.outline(
                        key: const ValueKey<String>(
                          'drive.preview.card.openWith',
                        ),
                        leading: const Icon(
                          LucideIcons.squareArrowOutUpRight,
                          size: 16,
                        ),
                        onPressed: () => s.dispatcher.invoke(
                          'drive.file.openWith',
                          args: {'app': convert.name},
                          context: context,
                        ),
                        child: Text(
                          l.previewOpenWithApp(convertAppName(convert)),
                        ),
                      ),
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

/// "Wonky Write" / "Wonky Sheets".
String convertAppName(ConvertTarget t) => switch (t) {
  ConvertTarget.write => WonkyAppKind.write.productName,
  ConvertTarget.sheets => WonkyAppKind.sheets.productName,
};

/// The body for a non-ready phase or a failed viewer.
Widget previewStateBody(BuildContext context, FilePreviewController c) {
  final l = driveL10n(context);
  final s = c.services;
  Widget download() => ShadButton.outline(
    key: const ValueKey<String>('drive.preview.state.download'),
    leading: const Icon(LucideIcons.download, size: 16),
    onPressed: () =>
        s.dispatcher.invoke('drive.file.download', context: context),
    child: Text(l.previewDownload),
  );
  Widget retry() => ShadButton(
    key: const ValueKey<String>('drive.preview.retry'),
    leading: const Icon(LucideIcons.refreshCw, size: 16),
    onPressed: c.load,
    child: Text(l.previewRetry),
  );
  Widget back() => ShadButton.outline(
    leading: const Icon(LucideIcons.arrowLeft, size: 16),
    onPressed: () => s.dispatcher.invoke('shell.nav.home', context: context),
    child: Text(l.backToDrive),
  );
  final canDownload = c.canDownload;
  switch (c.phase) {
    case PreviewPhase.loading:
      return const PreviewLoading();
    case PreviewPhase.uploading:
      final p = c.uploadPercent;
      return PreviewMessage(
        key: const ValueKey<String>('drive.preview.state.uploading'),
        icon: LucideIcons.cloudUpload,
        title: p == null
            ? l.previewUploadingTitle
            : l.previewUploadingPercent(p),
        description: l.previewUploadingDescription,
      );
    case PreviewPhase.offline:
      return PreviewMessage(
        key: const ValueKey<String>('drive.preview.state.offline'),
        illustration: EmptyIllustration.offline,
        title: l.previewOfflineTitle,
        description: l.previewOfflineDescription,
        actions: [retry()],
      );
    case PreviewPhase.notFound:
      return PreviewMessage(
        key: const ValueKey<String>('drive.preview.state.notFound'),
        illustration: EmptyIllustration.noAccess,
        title: l.previewNotFoundTitle,
        description: l.previewNotFoundDescription,
        actions: [back()],
      );
    case PreviewPhase.notAFile:
      return PreviewMessage(title: l.previewOpeningInApp);
    case PreviewPhase.tooLarge:
      return UnsupportedFileView(
        key: const ValueKey<String>('drive.preview.state.tooLarge'),
        controller: c,
        title: l.previewTooLargeTitle,
        message: l.previewTooLargeDescription(
          formatStorageBytes(
            c.type?.viewer == PreviewViewer.image
                ? PreviewLimits.imageOriginalBytes
                : PreviewLimits.maxBytes,
          ),
        ),
      );
    case PreviewPhase.failed:
      final problem = c.problem ?? PreviewProblem.load;
      if (problem == PreviewProblem.load || c.item == null) {
        return PreviewMessage(
          key: const ValueKey<String>('drive.preview.state.error'),
          illustration: EmptyIllustration.error,
          title: l.previewErrorTitle,
          description: l.previewErrorDescription,
          actions: [retry(), if (canDownload && c.item != null) download()],
        );
      }
      return UnsupportedFileView(
        key: ValueKey<String>('drive.preview.state.${problem.name}'),
        controller: c,
        icon: problem == PreviewProblem.pdfPassword
            ? LucideIcons.fileLock
            : LucideIcons.fileWarning,
        title: switch (problem) {
          PreviewProblem.imageBroken => l.previewImageBroken,
          PreviewProblem.pdfBroken => l.previewPdfBroken,
          PreviewProblem.pdfPassword => l.previewPdfPassword,
          PreviewProblem.pdfUnavailable => l.previewPdfUnavailable,
          PreviewProblem.notText => l.previewNotText,
          PreviewProblem.load => l.previewErrorTitle,
        },
      );
    case PreviewPhase.ready:
      return const SizedBox.shrink();
  }
}
