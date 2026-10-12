import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../core/offline_storage.dart';
import '../data/models_ext.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'drive_controller.dart';
import 'drive_format.dart';
import 'item_actions.dart';

bool get _modPressed {
  final kb = HardwareKeyboard.instance;
  return kb.isMetaPressed || kb.isControlPressed;
}

/// The list/grid of drive items (suite 05 §3.1) with selection, keyboard
/// navigation, context menus, drag-and-drop and infinite scroll.
class DriveItemsView extends StatefulWidget {
  const DriveItemsView({
    super.key,
    required this.controller,
    required this.services,
    required this.focusNode,
  });

  final DriveController controller;
  final ShellServices services;
  final FocusNode focusNode;

  @override
  State<DriveItemsView> createState() => _DriveItemsViewState();
}

class _DriveItemsViewState extends State<DriveItemsView> {
  final _scroll = ScrollController();

  DriveController get c => widget.controller;
  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        c.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final grid = c.layout == DriveLayout.grid;
    final cols = grid ? _gridColumns : 1;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        c.moveFocus(cols, extend: shift);
      case LogicalKeyboardKey.arrowUp:
        c.moveFocus(-cols, extend: shift);
      case LogicalKeyboardKey.arrowRight when grid:
        c.moveFocus(1, extend: shift);
      case LogicalKeyboardKey.arrowLeft when grid:
        c.moveFocus(-1, extend: shift);
      case LogicalKeyboardKey.home:
        c.moveFocus(-100000, extend: shift);
      case LogicalKeyboardKey.end:
        c.moveFocus(100000, extend: shift);
      case LogicalKeyboardKey.escape:
        if (c.selection.isEmpty) return KeyEventResult.ignored;
        c.clearSelection();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  int _gridColumns = 4;

  void _tap(DriveItemView item) {
    widget.focusNode.requestFocus();
    c.select(
      item,
      toggle: _modPressed,
      range: HardwareKeyboard.instance.isShiftPressed,
    );
  }

  void _open(DriveItemView item) {
    if (item.isTrashed) return;
    if (!s.connectivity.online &&
        !OfflineStorage.of(s).isAvailableOffline(item)) {
      s.toasts.show(WonkyAppLocalizations.of(context).offlineUnavailable);
      return;
    }
    s.openItem(item);
  }

  void _prepareMenu(DriveItemView item) {
    if (!c.isSelected(item)) c.select(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([c, s.connectivity, OfflineStorage.of(s)]),
      builder: (context, _) {
        final items = c.items;
        final body = c.layout == DriveLayout.grid
            ? _grid(context, items)
            : _list(context, l, items);
        return Focus(
          focusNode: widget.focusNode,
          onKeyEvent: _onKey,
          child: Semantics(label: l.driveListLabel, child: body),
        );
      },
    );
  }

  Widget _list(
    BuildContext context,
    WonkyAppLocalizations l,
    List<DriveItemView> items,
  ) {
    final theme = ShadTheme.of(context);
    final rows = <Widget>[];
    RecentGroup? group;
    for (final item in items) {
      if (c.location.groupsByDate) {
        final g = recentGroupOf(item.lastOpenedAt ?? item.modifiedAt);
        if (g != group) {
          group = g;
          rows.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                recentGroupLabel(l, g),
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
      }
      rows.add(
        _ItemRow(
          key: ValueKey<String>('drive.item.${item.uuid.uuid}'),
          item: item,
          services: s,
          selected: c.isSelected(item),
          focused: c.focusedId == item.uuid.uuid && widget.focusNode.hasFocus,
          dragData: () => DriveDragData([
            for (final i in c.isSelected(item) ? c.selection : [item])
              i.uuid.uuid,
          ]),
          onTap: () => _tap(item),
          onOpen: () => _open(item),
          onMenu: () => _prepareMenu(item),
          trash: c.location.isTrash,
        ),
      );
    }
    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
          ),
          child: DefaultTextStyle.merge(
            style: theme.textTheme.muted.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _HeaderCell(
                    label: l.columnName,
                    field: DriveSortField.name,
                    controller: c,
                  ),
                ),
                Expanded(flex: 3, child: Text(l.columnOwner)),
                Expanded(
                  flex: 3,
                  child: _HeaderCell(
                    label: l.columnModified,
                    field: DriveSortField.modifiedAt,
                    controller: c,
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: _HeaderCell(
                    label: l.columnSize,
                    field: DriveSortField.size,
                    controller: c,
                  ),
                ),
                const SizedBox(width: 36),
              ],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: c.clearSelection,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ...rows,
                if (c.loadingMore)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: ShadSpinner()),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, List<DriveItemView> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gridColumns = ((constraints.maxWidth - 32) / 216).floor().clamp(1, 12);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: c.clearSelection,
          child: GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _gridColumns,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 200 / 190,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return _ItemCard(
                key: ValueKey<String>('drive.card.${item.uuid.uuid}'),
                item: item,
                services: s,
                selected: c.isSelected(item),
                focused:
                    c.focusedId == item.uuid.uuid && widget.focusNode.hasFocus,
                dragData: () => DriveDragData([
                  for (final x in c.isSelected(item) ? c.selection : [item])
                    x.uuid.uuid,
                ]),
                onTap: () => _tap(item),
                onOpen: () => _open(item),
                onMenu: () => _prepareMenu(item),
                trash: c.location.isTrash,
              );
            },
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.field,
    required this.controller,
  });

  final String label;
  final DriveSortField field;
  final DriveController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.sortField == field;
    return GestureDetector(
      onTap: () => controller.setSort(field),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                controller.descending
                    ? LucideIcons.arrowDown
                    : LucideIcons.arrowUp,
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared drag/drop + menu wrapper for rows and cards.
class _ItemShell extends StatefulWidget {
  const _ItemShell({
    required this.item,
    required this.services,
    required this.dragData,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    required this.trash,
    required this.builder,
  });

  final DriveItemView item;
  final ShellServices services;
  final DriveDragData Function() dragData;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final bool trash;
  final Widget Function(BuildContext context, bool hover, bool dropTarget)
  builder;

  @override
  State<_ItemShell> createState() => _ItemShellState();
}

class _ItemShellState extends State<_ItemShell> {
  bool _hover = false;
  bool _drop = false;
  DateTime? _lastTap;

  /// Selects on the first click right away and opens on the second one.
  /// (A `GestureDetector.onDoubleTap` delays `onTap` by the double-tap
  /// timeout and loses the double click when the first click changes the
  /// layout under the pointer.)
  void _onTap() {
    final now = DateTime.now();
    final last = _lastTap;
    if (last != null && now.difference(last) <= _doubleClickTimeout) {
      _lastTap = null;
      widget.onOpen();
      return;
    }
    _lastTap = now;
    widget.onTap();
  }

  static const _doubleClickTimeout = Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    Widget child = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: widget.builder(context, _hover, _drop),
      ),
    );
    child = WonkyContextMenuRegion(
      onOpen: widget.onMenu,
      entries: () =>
          itemMenuEntries(context, widget.services, trash: widget.trash),
      child: child,
    );
    if (item.isFolder && !widget.trash) {
      final inner = child;
      child = DragTarget<DriveDragData>(
        onWillAcceptWithDetails: (d) {
          final ok = item.canEdit && !d.data.uuids.contains(item.uuid.uuid);
          if (ok) setState(() => _drop = true);
          return ok;
        },
        onLeave: (_) => setState(() => _drop = false),
        onAcceptWithDetails: (d) {
          setState(() => _drop = false);
          dropIntoFolder(widget.services, d.data, item.uuid.uuid);
        },
        builder: (context, _, _) => inner,
      );
    }
    if (!widget.trash && item.canManage) {
      final inner = child;
      final data = widget.dragData;
      child = Draggable<DriveDragData>(
        data: data(),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: _DragChip(
          label: data().uuids.length > 1 ? '${data().uuids.length}' : item.name,
          icon: kindIcon(item.kind),
        ),
        childWhenDragging: Opacity(opacity: 0.5, child: inner),
        child: inner,
      );
    }
    return child;
  }
}

class _DragChip extends StatelessWidget {
  const _DragChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Transform.translate(
      offset: const Offset(10, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.popover,
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 10),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.small),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.services,
    required this.selected,
    required this.focused,
    required this.dragData,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    required this.trash,
  });

  final DriveItemView item;
  final ShellServices services;
  final bool selected;
  final bool focused;
  final DriveDragData Function() dragData;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final bool trash;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    final available = OfflineStorage.of(services).isAvailableOffline(item);
    final offlineDim = !services.connectivity.online && !available;
    final ownerName = item.owner.id == services.me?.id
        ? l.ownerMe
        : item.owner.displayName;
    return _ItemShell(
      item: item,
      services: services,
      dragData: dragData,
      onTap: onTap,
      onOpen: onOpen,
      onMenu: onMenu,
      trash: trash,
      builder: (context, hover, drop) => Semantics(
        selected: selected,
        button: true,
        label: '${describeKind(l, item.kind)} ${item.name}',
        child: _OfflineDim(
          dim: offlineDim,
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: drop
                  ? c.selection
                  : selected
                  ? c.sidebarAccent
                  : hover
                  ? c.accent.withValues(alpha: 0.6)
                  : null,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: focused ? c.ring : const Color(0x00000000),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Row(
                    children: [
                      Icon(
                        kindIcon(item.kind),
                        size: 18,
                        color: kindColor(item.kind, c),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (item.shared) ...[
                        const SizedBox(width: 6),
                        ShadTooltip(
                          builder: (_) => Text(l.badgeShared),
                          child: Icon(
                            LucideIcons.users,
                            size: 14,
                            color: c.mutedForeground,
                          ),
                        ),
                      ],
                      if (item.starred) ...[
                        const SizedBox(width: 6),
                        Icon(LucideIcons.star, size: 14, color: c.warning),
                      ],
                      if (!item.isFolder && (item.pinnedOffline || available))
                        _OfflineBadge(item: item, available: available),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      WonkyAvatar(
                        name: item.owner.displayName,
                        color: parseHexColor(item.owner.avatarColor),
                        imageUrl: item.owner.avatarUrl,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          ownerName,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.muted.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    relativeDate(l, item.modifiedAt),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted.copyWith(fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    item.isFolder ? '—' : formatBytes(item.sizeBytes),
                    style: theme.textTheme.muted.copyWith(fontSize: 13),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: WonkyDropdownMenu(
                    anchor: const ShadAnchor(
                      childAlignment: AlignmentDirectional.bottomEnd,
                      overlayAlignment: AlignmentDirectional.topEnd,
                    ),
                    entries: () =>
                        itemMenuEntries(context, services, trash: trash),
                    builder: (context, ctl) => ShadIconButton.ghost(
                      key: ValueKey<String>(
                        'drive.item.${item.uuid.uuid}.menu',
                      ),
                      width: 28,
                      height: 28,
                      iconSize: 16,
                      semanticLabel: l.moreActions,
                      icon: const Icon(LucideIcons.ellipsisVertical),
                      onPressed: () {
                        onMenu();
                        ctl.toggle();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.services,
    required this.selected,
    required this.focused,
    required this.dragData,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    required this.trash,
  });

  final DriveItemView item;
  final ShellServices services;
  final bool selected;
  final bool focused;
  final DriveDragData Function() dragData;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onMenu;
  final bool trash;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    return _ItemShell(
      item: item,
      services: services,
      dragData: dragData,
      onTap: onTap,
      onOpen: onOpen,
      onMenu: onMenu,
      trash: trash,
      builder: (context, hover, drop) => Semantics(
        selected: selected,
        button: true,
        label: '${describeKind(l, item.kind)} ${item.name}',
        child: _OfflineDim(
          dim:
              !services.connectivity.online &&
              !OfflineStorage.of(services).isAvailableOffline(item),
          child: Container(
            decoration: BoxDecoration(
              color: drop ? c.selection : (selected ? c.sidebarAccent : c.card),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused
                    ? c.ring
                    : (hover ? c.ring.withValues(alpha: 0.5) : c.border),
                width: focused ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.canvas,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Icon(
                        kindIcon(item.kind),
                        size: 40,
                        color: kindColor(item.kind, c).withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 4, 8),
                  child: Row(
                    children: [
                      Icon(
                        kindIcon(item.kind),
                        size: 16,
                        color: kindColor(item.kind, c),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.small,
                        ),
                      ),
                      if (item.starred)
                        Icon(LucideIcons.star, size: 12, color: c.warning),
                      if (!item.isFolder &&
                          (item.pinnedOffline ||
                              OfflineStorage.of(
                                services,
                              ).isAvailableOffline(item)))
                        _OfflineBadge(
                          item: item,
                          available: OfflineStorage.of(
                            services,
                          ).isAvailableOffline(item),
                        ),
                      WonkyDropdownMenu(
                        entries: () =>
                            itemMenuEntries(context, services, trash: trash),
                        builder: (context, ctl) => ShadIconButton.ghost(
                          width: 26,
                          height: 26,
                          iconSize: 14,
                          semanticLabel: l.moreActions,
                          icon: const Icon(LucideIcons.ellipsisVertical),
                          onPressed: () {
                            onMenu();
                            ctl.toggle();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dims an item that cannot be opened offline (suite 05 §4) and explains
/// why in a tooltip.
class _OfflineDim extends StatelessWidget {
  const _OfflineDim({required this.dim, required this.child});

  final bool dim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!dim) return child;
    return ShadTooltip(
      builder: (_) =>
          Text(WonkyAppLocalizations.of(context).offlineUnavailable),
      child: Opacity(opacity: 0.45, child: child),
    );
  }
}

/// "Available offline" badge: a check for files kept on this device,
/// a download arrow while a pinned file is not downloaded yet.
class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge({required this.item, required this.available});

  final DriveItemView item;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final c = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ShadTooltip(
        builder: (_) => Text(
          available
              ? (item.pinnedOffline ? l.badgeOffline : l.badgeOfflineRecent)
              : l.badgeOfflinePending,
        ),
        child: Icon(
          available ? LucideIcons.circleCheck : LucideIcons.cloudDownload,
          key: ValueKey<String>('drive.offlineBadge.${item.uuid.uuid}'),
          size: 14,
          color: available
              ? (item.pinnedOffline ? c.success : c.mutedForeground)
              : c.mutedForeground,
        ),
      ),
    );
  }
}
