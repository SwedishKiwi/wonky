import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_code_flutter/wonky_code_flutter.dart' show CodeLanguages;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/drive_l10n.dart';
import 'file_preview_controller.dart';
import 'file_preview_screen.dart' show previewTitleIcon;
import 'preview_content.dart';
import 'viewers/preview_states.dart' show convertAppName;

/// Invokes a command by id with arguments.
typedef PreviewInvoke =
    Future<void> Function(String id, [Map<String, Object?> args]);

Widget _iconButton({
  required Key key,
  required IconData icon,
  required String tooltip,
  VoidCallback? onPressed,
  bool selected = false,
}) => ShadTooltip(
  builder: (_) => Text(tooltip),
  child: selected
      ? ShadIconButton.secondary(
          key: key,
          width: 32,
          height: 32,
          iconSize: 16,
          icon: Icon(icon),
          semanticLabel: tooltip,
          onPressed: onPressed,
        )
      : ShadIconButton.ghost(
          key: key,
          width: 32,
          height: 32,
          iconSize: 16,
          icon: Icon(icon),
          semanticLabel: tooltip,
          onPressed: onPressed,
        ),
);

/// The 48 px top bar of the preview (Drive 04 §6). Narrow layouts move
/// *Open with*, *Share* and the star into ⋮.
class PreviewTopBar extends StatelessWidget {
  const PreviewTopBar({
    super.key,
    required this.controller,
    required this.narrow,
    required this.titleController,
    required this.onInvoke,
  });

  final FilePreviewController controller;
  final bool narrow;
  final DocumentTitleFieldController titleController;
  final PreviewInvoke onInvoke;

  static const backKey = ValueKey<String>('drive.preview.back');
  static const closeKey = ValueKey<String>('drive.preview.close');
  static const downloadKey = ValueKey<String>('drive.preview.download');
  static const openWithKey = ValueKey<String>('drive.preview.openWith');
  static const shareKey = ValueKey<String>('drive.preview.share');
  static const starKey = ValueKey<String>('drive.preview.star');
  static const moreKey = ValueKey<String>('drive.preview.more');
  static const detailsKey = ValueKey<String>('drive.preview.detailsToggle');

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    final c = controller;
    final item = c.item;
    final s = c.services;
    final uuid = c.itemUuid.uuid;
    final convert = c.type?.convertTarget;
    final usable = item != null && c.phase != PreviewPhase.notFound;
    final trashed = item?.isTrashed ?? false;
    final detailsOpen = s.panels.isOpen(ShellPanels.details);

    List<WonkyMenuEntry> moreEntries() => [
      if (narrow && convert != null)
        WonkyMenuItem(
          label: l.previewOpenWithApp(convertAppName(convert)),
          icon: LucideIcons.squareArrowOutUpRight,
          onSelected: () => onInvoke('drive.file.openWith', {
            'uuid': uuid,
            'app': convert.name,
          }),
        ),
      if (narrow && item != null && item.canShare)
        WonkyMenuItem(
          label: l.previewShare,
          icon: LucideIcons.userPlus,
          onSelected: () => onInvoke('shell.sharing.open', {'uuid': uuid}),
        ),
      if (narrow && item != null && !trashed)
        WonkyMenuItem(
          label: item.starred ? l.previewUnstar : l.previewStar,
          icon: LucideIcons.star,
          onSelected: () => onInvoke('shell.drive.setStarred', {
            'uuid': uuid,
            'starred': !item.starred,
          }),
        ),
      if (narrow) const WonkyMenuSeparator(),
      WonkyMenuItem(
        label: l.previewRename,
        icon: LucideIcons.pencil,
        enabled: item != null && item.canManage && !trashed,
        onSelected: () => onInvoke('shell.drive.rename', {'uuid': uuid}),
      ),
      WonkyMenuItem(
        label: l.previewMove,
        icon: LucideIcons.folderInput,
        enabled: item != null && item.canManage && !trashed,
        onSelected: () => onInvoke('shell.drive.move', {'uuid': uuid}),
      ),
      WonkyMenuItem(
        label: l.previewCopy,
        icon: LucideIcons.copy,
        enabled: item != null && !trashed,
        onSelected: () => onInvoke('shell.drive.copy', {'uuid': uuid}),
      ),
      WonkyMenuItem(
        label: l.previewDetails,
        icon: LucideIcons.info,
        onSelected: () => onInvoke('shell.file.details'),
      ),
      const WonkyMenuSeparator(),
      WonkyMenuItem(
        label: l.previewTrash,
        icon: LucideIcons.trash2,
        destructive: true,
        enabled: item != null && item.canManage && !trashed,
        onSelected: () => onInvoke('shell.drive.trash', {'uuid': uuid}),
      ),
    ];

    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _iconButton(
              key: backKey,
              icon: LucideIcons.arrowLeft,
              tooltip: l.previewClose,
              onPressed: () => onInvoke('drive.preview.close'),
            ),
            const SizedBox(width: 6),
            previewTitleIcon(c),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: item == null
                    ? const SizedBox.shrink()
                    : DocumentTitleField(
                        key: const ValueKey<String>('drive.preview.title'),
                        title: item.name,
                        controller: titleController,
                        readOnly: !item.canManage || trashed,
                        onRename: (name) => onInvoke('shell.drive.rename', {
                          'uuid': uuid,
                          'name': name,
                        }),
                      ),
              ),
            ),
            if (usable && !narrow && convert != null) ...[
              WonkyDropdownMenu(
                entries: () => [
                  WonkyMenuItem(
                    label: convertAppName(convert),
                    leading: WonkyProductIcon(
                      convert.name == 'write'
                          ? WonkyProduct.write
                          : WonkyProduct.sheets,
                      size: 16,
                    ),
                    onSelected: () => onInvoke('drive.file.openWith', {
                      'uuid': uuid,
                      'app': convert.name,
                    }),
                  ),
                ],
                builder: (context, menu) => ShadButton.outline(
                  key: openWithKey,
                  size: ShadButtonSize.sm,
                  trailing: const Icon(LucideIcons.chevronDown, size: 14),
                  onPressed: menu.toggle,
                  child: Text(l.previewOpenWith),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (usable && c.canDownload)
              narrow
                  ? _iconButton(
                      key: downloadKey,
                      icon: LucideIcons.download,
                      tooltip: l.previewDownload,
                      onPressed: () => onInvoke('drive.file.download'),
                    )
                  : ShadButton.outline(
                      key: downloadKey,
                      size: ShadButtonSize.sm,
                      leading: const Icon(LucideIcons.download, size: 14),
                      onPressed: () => onInvoke('drive.file.download'),
                      child: Text(l.previewDownload),
                    ),
            if (usable && !narrow) ...[
              const SizedBox(width: 6),
              if (item.canShare)
                ShadButton(
                  key: shareKey,
                  size: ShadButtonSize.sm,
                  leading: const Icon(LucideIcons.userPlus, size: 14),
                  onPressed: () =>
                      onInvoke('shell.sharing.open', {'uuid': uuid}),
                  child: Text(l.previewShare),
                ),
              if (!trashed)
                _iconButton(
                  key: starKey,
                  icon: item.starred ? LucideIcons.starOff : LucideIcons.star,
                  tooltip: item.starred ? l.previewUnstar : l.previewStar,
                  onPressed: () => onInvoke('shell.drive.setStarred', {
                    'uuid': uuid,
                    'starred': !item.starred,
                  }),
                ),
            ],
            if (usable)
              WonkyDropdownMenu(
                entries: moreEntries,
                // End-aligned: at narrow widths ⋮ is the last button and a
                // start-aligned menu ran off the right edge (D-18).
                anchor: const ShadAnchor(
                  childAlignment: AlignmentDirectional.bottomEnd,
                  overlayAlignment: AlignmentDirectional.topEnd,
                  offset: Offset(0, 4),
                ),
                builder: (context, menu) => _iconButton(
                  key: moreKey,
                  icon: LucideIcons.ellipsisVertical,
                  tooltip: l.previewMore,
                  onPressed: menu.toggle,
                ),
              ),
            if (usable && !narrow)
              _iconButton(
                key: detailsKey,
                icon: LucideIcons.info,
                tooltip: l.previewDetails,
                selected: detailsOpen,
                onPressed: () => onInvoke('shell.file.details'),
              ),
            if (!narrow) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: theme.colorScheme.border,
              ),
              _iconButton(
                key: closeKey,
                icon: LucideIcons.x,
                tooltip: l.previewClose,
                onPressed: () => onInvoke('drive.preview.close'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The viewer bar (Drive 04 §6): zoom/fit/rotate for images,
/// wrap/language/*Copy all*/lines for text, *Table*/*Text* for CSV, and
/// "3 of 12 in "Holiday"".
class PreviewViewerBar extends StatelessWidget {
  const PreviewViewerBar({
    super.key,
    required this.controller,
    required this.narrow,
    required this.onInvoke,
  });

  final FilePreviewController controller;
  final bool narrow;
  final PreviewInvoke onInvoke;

  static const zoomInKey = ValueKey<String>('drive.preview.zoomIn');
  static const zoomOutKey = ValueKey<String>('drive.preview.zoomOut');
  static const zoomLabelKey = ValueKey<String>('drive.preview.zoomLabel');
  static const fitKey = ValueKey<String>('drive.preview.zoomFit');
  static const actualKey = ValueKey<String>('drive.preview.zoomActual');
  static const rotateKey = ValueKey<String>('drive.preview.rotate');
  static const wrapKey = ValueKey<String>('drive.preview.wrap');
  static const copyKey = ValueKey<String>('drive.preview.copyAll');
  static const positionKey = ValueKey<String>('drive.preview.position');
  static const tableKey = ValueKey<String>('drive.preview.csvTable');
  static const textKey = ValueKey<String>('drive.preview.csvText');

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    final c = controller;
    final muted = theme.textTheme.muted;
    final viewer = c.type!.viewer;

    List<Widget> zoom() => [
      _iconButton(
        key: zoomOutKey,
        icon: LucideIcons.minus,
        tooltip: l.previewZoomOut,
        onPressed: () => onInvoke('drive.preview.zoomOut'),
      ),
      SizedBox(
        width: 52,
        child: Text(
          l.previewZoomPercent((c.effectiveZoom * 100).round()),
          key: zoomLabelKey,
          textAlign: TextAlign.center,
          style: theme.textTheme.small,
        ),
      ),
      _iconButton(
        key: zoomInKey,
        icon: LucideIcons.plus,
        tooltip: l.previewZoomIn,
        onPressed: () => onInvoke('drive.preview.zoomIn'),
      ),
      _iconButton(
        key: fitKey,
        icon: LucideIcons.minimize,
        tooltip: l.previewZoomFit,
        selected: c.zoom == null,
        onPressed: () => onInvoke('drive.preview.zoomFit'),
      ),
    ];

    final tools = <Widget>[
      ...switch (viewer) {
        PreviewViewer.image => [
          ...zoom(),
          _iconButton(
            key: actualKey,
            icon: LucideIcons.scan,
            tooltip: l.previewZoomActual,
            selected: c.zoom == 1,
            onPressed: () => onInvoke('drive.preview.zoomActual'),
          ),
          _iconButton(
            key: rotateKey,
            icon: LucideIcons.rotateCw,
            tooltip: l.previewRotate,
            onPressed: () => onInvoke('drive.preview.rotate'),
          ),
          if (!narrow && c.imageWidth != null) ...[
            const SizedBox(width: 8),
            Text(
              l.previewImageSize(c.imageWidth!, c.imageHeight!),
              style: muted,
            ),
          ],
          if (!narrow && c.fromServerPreview) ...[
            const SizedBox(width: 8),
            Text(l.previewServerPreviewNote, style: muted),
          ],
        ],
        PreviewViewer.text => _textTools(context, l, muted),
        PreviewViewer.csv => [
          ShadButton.ghost(
            key: tableKey,
            size: ShadButtonSize.sm,
            backgroundColor: c.csvAsTable ? theme.colorScheme.secondary : null,
            onPressed: () => c.setCsvAsTable(true),
            child: Text(l.previewCsvTable),
          ),
          ShadButton.ghost(
            key: textKey,
            size: ShadButtonSize.sm,
            backgroundColor: c.csvAsTable ? null : theme.colorScheme.secondary,
            onPressed: () => c.setCsvAsTable(false),
            child: Text(l.previewCsvText),
          ),
          const SizedBox(width: 8),
          if (c.csvAsTable)
            Text(l.previewCsvRows(c.csv?.rows.length ?? 0), style: muted)
          else
            ..._textTools(context, l, muted),
        ],
        PreviewViewer.unsupported => const <Widget>[],
      },
    ];

    final i = c.siblingIndex;
    final position = i < 0 || c.siblings.length < 2
        ? null
        : c.folderName == null
        ? l.previewPositionNoFolder(i + 1, c.siblings.length)
        : l.previewPosition(i + 1, c.siblings.length, c.folderName!);

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: tools),
              ),
            ),
            if (position != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  position,
                  key: positionKey,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _textTools(
    BuildContext context,
    DriveLocalizations l,
    TextStyle muted,
  ) {
    final c = controller;
    final lang = c.type?.language;
    return [
      _iconButton(
        key: wrapKey,
        icon: LucideIcons.wrapText,
        tooltip: l.previewWrap,
        selected: c.wrap,
        onPressed: () => onInvoke('drive.preview.toggleWrap'),
      ),
      _iconButton(
        key: copyKey,
        icon: LucideIcons.copy,
        tooltip: l.previewCopyAll,
        onPressed: () => onInvoke('drive.preview.copyAll'),
      ),
      const SizedBox(width: 8),
      Text(
        lang == null ? l.previewPlainText : CodeLanguages.displayName(lang),
        style: muted,
      ),
      const SizedBox(width: 12),
      Text(l.previewLines(c.text?.lineCount ?? 0), style: muted),
    ];
  }
}
