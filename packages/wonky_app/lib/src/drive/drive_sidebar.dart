import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../data/models_ext.dart';
import '../l10n/wonky_app_localizations.dart';
import '../menus/menu_resolver.dart';
import '../shell/shell_services.dart';
import 'drive_format.dart';
import 'drive_location.dart';
import 'item_actions.dart';

/// The home sidebar (suite 05 §3.1 `DriveSidebar`): *New* menu, views,
/// folder tree under My Drive (lazy, drop target) and storage usage.
class DriveSidebar extends StatefulWidget {
  const DriveSidebar({
    super.key,
    required this.services,
    required this.location,
  });

  /// Width of the sidebar.
  static const double width = 256;

  final ShellServices services;
  final DriveLocation location;

  @override
  State<DriveSidebar> createState() => _DriveSidebarState();
}

class _DriveSidebarState extends State<DriveSidebar> {
  late final WonkyTreeController<DriveItemView> _tree =
      WonkyTreeController<DriveItemView>(loader: _load);
  StorageUsage? _usage;
  bool _treeOpen = false;
  StreamSubscription<DriveChange>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    _tree.dispose();
    super.dispose();
  }

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    s.drive
        .storageUsage()
        .then((u) {
          if (mounted) setState(() => _usage = u);
        })
        .catchError((Object _) {});
    _sub = s.driveChanges.listen((c) {
      if (c.item?.isFolder ?? true) {
        final parent = c.item?.parentUuid?.uuid;
        _tree.refresh(parent);
      }
    });
  }

  Future<List<WonkyTreeNode<DriveItemView>>> _load(
    WonkyTreeNode<DriveItemView>? parent,
  ) async {
    final page = await s.drive.list(
      folderUuid: parent?.value.uuid,
      filter: DriveListFilter(
        view: DriveView.folder,
        kinds: [DriveItemKind.folder],
      ),
      sort: DriveSort(field: DriveSortField.name, descending: false),
      limit: 200,
    );
    return [
      for (final f in page.items)
        if (f.isFolder && !f.isTrashed)
          WonkyTreeNode(
            id: f.uuid.uuid,
            label: f.name,
            value: f,
            icon: LucideIcons.folder,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final loc = widget.location;
    Widget nav(
      String key,
      IconData icon,
      String label,
      DriveLocation target, {
      bool active = false,
    }) => DragTarget<DriveDragData>(
      onWillAcceptWithDetails: (_) => target.kind == DriveLocationKind.myDrive,
      onAcceptWithDetails: (d) => dropIntoFolder(s, d.data, null),
      builder: (context, cand, _) => SidebarNavButton(
        key: ValueKey<String>('drive.nav.$key'),
        icon: icon,
        label: label,
        active: active || cand.isNotEmpty,
        onPressed: () => s.router.go(target.path),
      ),
    );
    return Container(
      width: DriveSidebar.width,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WonkyDropdownMenu(
            entries: () {
              final r = MenuResolver(s);
              final primaryDoc = s.config.primaryKind == DriveItemKind.document;
              return <WonkyMenuEntry>[
                ?r.commandEntry(
                  context,
                  'shell.file.new',
                  args: {'kind': primaryDoc ? 'document' : 'spreadsheet'},
                  label: primaryDoc ? l.menuNewDocument : l.menuNewSpreadsheet,
                  key: 'new.primary',
                ),
                ?r.commandEntry(
                  context,
                  'shell.file.new',
                  args: {'kind': primaryDoc ? 'spreadsheet' : 'document'},
                  label: primaryDoc ? l.menuNewSpreadsheet : l.menuNewDocument,
                  key: 'new.other',
                ),
                ?r.commandEntry(context, 'shell.drive.newFolder'),
                const WonkyMenuSeparator(),
                ?r.commandEntry(context, 'shell.drive.upload'),
                ?r.commandEntry(context, 'shell.file.newFromTemplate'),
              ];
            },
            builder: (context, c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShadButton.outline(
                  key: const ValueKey<String>('drive.new'),
                  height: 48,
                  padding: const EdgeInsets.fromLTRB(12, 0, 20, 0),
                  leading: const Icon(LucideIcons.plus, size: 20),
                  onPressed: c.toggle,
                  decoration: ShadDecoration(
                    shadows: [
                      BoxShadow(
                        color: const Color(0x22000000),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    l.newButton,
                    style: theme.textTheme.small.copyWith(fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Column(
                  children: [
                    nav(
                      'home',
                      LucideIcons.house,
                      l.navHome,
                      const DriveLocation.home(),
                      active: loc.kind == DriveLocationKind.home,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: nav(
                            'myDrive',
                            LucideIcons.hardDrive,
                            l.navMyDrive,
                            const DriveLocation.myDrive(),
                            active: loc.kind == DriveLocationKind.myDrive,
                          ),
                        ),
                        ShadIconButton.ghost(
                          key: const ValueKey<String>('drive.nav.tree'),
                          width: 28,
                          height: 28,
                          iconSize: 14,
                          semanticLabel: _treeOpen
                              ? l.collapseFolders
                              : l.expandFolders,
                          icon: Icon(
                            _treeOpen
                                ? LucideIcons.chevronDown
                                : LucideIcons.chevronRight,
                          ),
                          onPressed: () =>
                              setState(() => _treeOpen = !_treeOpen),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_treeOpen)
                  SizedBox(
                    height: 240,
                    child: WonkyTreeView<DriveItemView>(
                      keyPrefix: 'drive.tree',
                      controller: _tree,
                      semanticLabel: l.folderTree,
                      onActivate: (n) => s.router.go('/drive/${n.id}'),
                      dragData: (n) =>
                          n.value.canManage ? DriveDragData([n.id]) : null,
                      canAcceptDrop: (data, target, pos) =>
                          data is DriveDragData &&
                          pos == WonkyTreeDropPosition.inside &&
                          target.value.canEdit &&
                          !data.uuids.contains(target.id),
                      onDrop: (data, target, pos) {
                        if (data is DriveDragData) {
                          dropIntoFolder(s, data, target.id);
                        }
                      },
                    ),
                  ),
                Column(
                  children: [
                    nav(
                      'shared',
                      LucideIcons.users,
                      l.navShared,
                      const DriveLocation.shared(),
                      active: loc.kind == DriveLocationKind.shared,
                    ),
                    nav(
                      'recent',
                      LucideIcons.clock,
                      l.navRecent,
                      const DriveLocation.recent(),
                      active: loc.kind == DriveLocationKind.recent,
                    ),
                    nav(
                      'starred',
                      LucideIcons.star,
                      l.navStarred,
                      const DriveLocation.starred(),
                      active: loc.kind == DriveLocationKind.starred,
                    ),
                    nav(
                      'offline',
                      LucideIcons.cloudDownload,
                      l.navOffline,
                      const DriveLocation.offline(),
                      active: loc.kind == DriveLocationKind.offline,
                    ),
                    nav(
                      'trash',
                      LucideIcons.trash2,
                      l.navTrash,
                      const DriveLocation.trash(),
                      active: loc.kind == DriveLocationKind.trash,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_usage != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.cloud,
                    size: 16,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.storageUsed(formatBytes(_usage!.bytesUsed)),
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A sidebar navigation row (pill highlight when active).
class SidebarNavButton extends StatelessWidget {
  const SidebarNavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Semantics(
      selected: active,
      child: ShadButton.ghost(
        height: 36,
        width: double.infinity,
        mainAxisAlignment: MainAxisAlignment.start,
        backgroundColor: active ? theme.colorScheme.sidebarAccent : null,
        hoverBackgroundColor: active
            ? theme.colorScheme.sidebarAccent
            : theme.colorScheme.accent,
        decoration: const ShadDecoration(
          border: ShadBorder(radius: BorderRadius.all(Radius.circular(18))),
        ),
        leading: Icon(icon, size: 18),
        onPressed: onPressed,
        child: Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
