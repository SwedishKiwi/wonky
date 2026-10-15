import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/drive_l10n.dart';
import '../preview/file_category_icon.dart';
import 'storage_controller.dart';

/// Column widths of the Storage table (wide layout).
abstract final class StorageColumns {
  static const check = 36.0;
  static const kind = 150.0;
  static const location = 150.0;
  static const lastOpened = 120.0;
  static const size = 84.0;
  static const menu = 36.0;
}

/// "PNG image", "Spreadsheet", … for the *Kind* column.
String storageKindLabel(BuildContext context, DriveItemView item) {
  if (item.kind == DriveItemKind.file) {
    return fileTypeLabel(
      driveL10n(context),
      item.fileCategory ?? FileCategory.other,
      FileTypes.extensionOf(item.name),
    );
  }
  return describeKind(WonkyAppLocalizations.of(context), item.kind);
}

/// The title row of the table: "Items using storage" and the *Type* menu,
/// or the chip of a *Free up space* filter with ✕.
class StorageTableTitle extends StatelessWidget {
  const StorageTableTitle({
    super.key,
    required this.filter,
    required this.onFilter,
  });

  final StorageFilter filter;
  final ValueChanged<StorageFilter> onFilter;

  static String filterLabel(DriveLocalizations l, StorageFilter f) =>
      switch (f) {
        StorageFilter.all => l.storageFilterAll,
        StorageFilter.documents => l.storageFilterDocuments,
        StorageFilter.spreadsheets => l.storageFilterSpreadsheets,
        StorageFilter.presentations => l.storageFilterPresentations,
        StorageFilter.files => l.storageFilterFiles,
        StorageFilter.trash => l.storageFilterTrash,
        StorageFilter.large => l.storageFilterLarge,
        StorageFilter.notOpened => l.storageFilterNotOpened,
      };

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    final Widget control;
    if (filter.isSuggestion) {
      control = ShadButton.secondary(
        key: const ValueKey<String>('storage.filter.clear'),
        size: ShadButtonSize.sm,
        trailing: const Icon(LucideIcons.x, size: 14),
        onPressed: () => onFilter(StorageFilter.all),
        child: Semantics(
          hint: l.storageClearFilter,
          child: Text(filterLabel(l, filter)),
        ),
      );
    } else {
      control = WonkyDropdownMenu(
        anchor: const ShadAnchor(
          childAlignment: AlignmentDirectional.bottomEnd,
          overlayAlignment: AlignmentDirectional.topEnd,
        ),
        entries: () => [
          for (final f in StorageFilter.typeFilters)
            WonkyMenuRadioItem(
              key: ValueKey<String>('storage.filter.${f.name}'),
              label: filterLabel(l, f),
              selected: f == filter,
              onSelected: () => onFilter(f),
            ),
        ],
        builder: (context, ctl) => ShadButton.outline(
          key: const ValueKey<String>('storage.filter'),
          size: ShadButtonSize.sm,
          trailing: const Icon(LucideIcons.chevronDown, size: 14),
          onPressed: ctl.toggle,
          child: Text(l.storageFilterLabel(filterLabel(l, filter))),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              l.storageItemsTitle,
              style: theme.textTheme.large,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        control,
      ],
    );
  }
}

/// Column headers (with the select-all checkbox) or, with a selection,
/// the selection bar: "3 selected · 12.4 MB", *Move to trash*, *Restore*,
/// *Delete forever* (trashed items), *Download* (files), ✕.
class StorageTableBar extends StatelessWidget {
  const StorageTableBar({
    super.key,
    required this.controller,
    required this.wide,
    required this.onTrash,
    required this.onRestore,
    required this.onDeleteForever,
    required this.onDownload,
  });

  final StoragePageController controller;
  final bool wide;
  final VoidCallback onTrash;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;
  final VoidCallback onDownload;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    final c0 = controller;
    final sel = c0.selection;
    final all = c0.items.isNotEmpty && sel.length == c0.items.length;
    final checkbox = SizedBox(
      width: StorageColumns.check,
      child: Center(
        child: Semantics(
          label: l.storageSelectAll,
          child: ShadCheckbox(
            key: const ValueKey<String>('storage.selectAll'),
            value: all,
            onChanged: (v) => v ? c0.selectAll() : c0.clearSelection(),
          ),
        ),
      ),
    );
    if (sel.isNotEmpty) {
      final trashed = sel.every((i) => i.isTrashed);
      final live = sel.every((i) => !i.isTrashed);
      final files = sel.every(
        (i) =>
            i.kind == DriveItemKind.file &&
            i.uploadState != FileUploadState.uploading,
      );
      Widget action(
        String id,
        IconData icon,
        String label,
        VoidCallback onPressed, {
        bool destructive = false,
      }) => ShadTooltip(
        builder: (_) => Text(label),
        child: ShadIconButton.ghost(
          key: ValueKey<String>('storage.selection.$id'),
          width: 32,
          height: 32,
          iconSize: 16,
          semanticLabel: label,
          icon: Icon(icon, color: destructive ? c.destructive : null),
          onPressed: onPressed,
        ),
      );
      return Container(
        key: const ValueKey<String>('storage.selectionBar'),
        height: height,
        decoration: BoxDecoration(
          color: c.secondary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            checkbox,
            Expanded(
              child: Text(
                l.storageSelectionSize(
                  sel.length,
                  storageBytes(c0.selectedBytes),
                ),
                key: const ValueKey<String>('storage.selection.count'),
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.small,
              ),
            ),
            if (live)
              action('trash', LucideIcons.trash2, la.cmdMoveToTrash, onTrash),
            if (trashed) ...[
              action(
                'restore',
                LucideIcons.archiveRestore,
                la.cmdRestore,
                onRestore,
              ),
              action(
                'deleteForever',
                LucideIcons.trash,
                la.cmdDeleteForever,
                onDeleteForever,
                destructive: true,
              ),
            ],
            if (files)
              action(
                'download',
                LucideIcons.download,
                l.storageDownload,
                onDownload,
              ),
            action(
              'clear',
              LucideIcons.x,
              l.storageClearSelection,
              c0.clearSelection,
            ),
            const SizedBox(width: 4),
          ],
        ),
      );
    }
    Widget header(String text, {double? width, bool end = false}) {
      final t = Text(
        text,
        overflow: TextOverflow.ellipsis,
        textAlign: end ? TextAlign.end : TextAlign.start,
        style: theme.textTheme.muted.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      return width == null
          ? Expanded(child: t)
          : SizedBox(width: width, child: t);
    }

    return SizedBox(
      key: const ValueKey<String>('storage.columns'),
      height: height,
      child: Row(
        children: [
          checkbox,
          header(l.storageColumnName),
          if (wide) ...[
            header(l.storageColumnKind, width: StorageColumns.kind),
            header(l.storageColumnLocation, width: StorageColumns.location),
            header(l.storageColumnLastOpened, width: StorageColumns.lastOpened),
          ],
          header(l.storageColumnStorage, width: StorageColumns.size, end: true),
          const SizedBox(width: StorageColumns.menu + 4),
        ],
      ),
    );
  }
}

/// One row of the Storage table: checkbox, icon, name (with *In trash*),
/// kind, location, last opened, counted size and the item menu.
class StorageRow extends StatefulWidget {
  const StorageRow({
    super.key,
    required this.services,
    required this.controller,
    required this.item,
    required this.wide,
    required this.focused,
    required this.onTap,
    required this.onOpen,
  });

  final ShellServices services;
  final StoragePageController controller;
  final DriveItemView item;
  final bool wide;
  final bool focused;

  /// A click (with the modifier state already applied by the caller).
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  State<StorageRow> createState() => _StorageRowState();
}

class _StorageRowState extends State<StorageRow> {
  bool _hover = false;
  DateTime? _lastTap;

  static const _doubleClick = Duration(milliseconds: 500);

  /// Selects on the first click at once and opens on the second (like the
  /// drive list).
  void _tap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null && now.difference(last) <= _doubleClick) {
      _lastTap = null;
      widget.onOpen();
      return;
    }
    _lastTap = now;
    widget.onTap();
  }

  void _menuOpening() {
    final c = widget.controller;
    if (!c.isSelected(widget.item)) c.select(widget.item);
  }

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    final s = widget.services;
    final item = widget.item;
    final selected = widget.controller.isSelected(item);
    final kind = storageKindLabel(context, item);
    final size = storageBytes(item.countedBytes);
    final muted = theme.textTheme.muted.copyWith(fontSize: 13);
    final parent = item.parentUuid;
    final location = item.isTrashed
        ? la.navTrash
        : parent == null
        ? la.navMyDrive
        : switch (widget.controller.folderName(parent)) {
            null => '…',
            '' => '—',
            final name => name,
          };
    final opened = item.lastOpenedAt;
    final icon = item.kind == DriveItemKind.file
        ? FileCategoryIcon(
            item.fileCategory ?? FileCategory.other,
            size: 18,
            code: FileTypes.languageOf(item.name) != null,
          )
        : DriveKindIcon(item.kind, size: 18);
    List<WonkyMenuEntry> entries() =>
        itemMenuEntries(context, s, trash: item.isTrashed);

    final row = Container(
      height: 44,
      decoration: BoxDecoration(
        color: selected
            ? c.sidebarAccent
            : _hover
            ? c.accent.withValues(alpha: 0.6)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.focused ? c.ring : const Color(0x00000000),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: StorageColumns.check,
            child: Center(
              child: Semantics(
                label: l.storageSelectRow(item.name),
                child: ShadCheckbox(
                  key: ValueKey<String>('storage.row.${item.uuid.uuid}.check'),
                  value: selected,
                  onChanged: (_) =>
                      widget.controller.select(item, toggle: true),
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    s.config.listItemName(s, item),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (item.isTrashed) ...[
                  const SizedBox(width: 8),
                  ShadBadge.secondary(
                    key: ValueKey<String>(
                      'storage.row.${item.uuid.uuid}.trashed',
                    ),
                    child: Text(l.storageInTrash),
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (widget.wide) ...[
            SizedBox(
              width: StorageColumns.kind,
              child: Text(kind, overflow: TextOverflow.ellipsis, style: muted),
            ),
            SizedBox(
              width: StorageColumns.location,
              child: Text(
                location,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
            SizedBox(
              width: StorageColumns.lastOpened,
              child: Text(
                opened == null ? '—' : relativeDate(la, opened),
                overflow: TextOverflow.ellipsis,
                style: muted,
                semanticsLabel: opened == null ? l.storageNeverOpened : null,
              ),
            ),
          ],
          SizedBox(
            width: StorageColumns.size,
            child: Text(
              size,
              textAlign: TextAlign.end,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: muted.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: StorageColumns.menu,
            child: WonkyDropdownMenu(
              anchor: const ShadAnchor(
                childAlignment: AlignmentDirectional.bottomEnd,
                overlayAlignment: AlignmentDirectional.topEnd,
              ),
              entries: entries,
              builder: (context, ctl) => ShadIconButton.ghost(
                key: ValueKey<String>('storage.row.${item.uuid.uuid}.menu'),
                width: 28,
                height: 28,
                iconSize: 16,
                semanticLabel: la.moreActions,
                icon: const Icon(LucideIcons.ellipsisVertical),
                onPressed: () {
                  _menuOpening();
                  ctl.toggle();
                },
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      key: ValueKey<String>('storage.row.${item.uuid.uuid}'),
      selected: selected,
      button: true,
      label: l.storageRowLabel(item.name, kind, size),
      child: WonkyContextMenuRegion(
        onOpen: _menuOpening,
        entries: entries,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: _tap, child: row),
        ),
      ),
    );
  }
}
