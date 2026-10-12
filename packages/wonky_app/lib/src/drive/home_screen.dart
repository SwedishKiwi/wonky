import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../commands/keymap_service.dart';
import '../commands/shell_commands/general_commands.dart';
import '../config/wonky_app_config.dart';
import '../data/api.dart';
import '../l10n/wonky_app_localizations.dart';
import '../menus/menu_resolver.dart';
import '../shell/shell_services.dart';
import 'details_panel.dart';
import 'drive_controller.dart';
import 'drive_location.dart';
import 'drive_sidebar.dart';
import 'item_actions.dart';
import 'template_gallery.dart';
import 'top_bar.dart';
import 'item_list.dart';

/// Home and every drive view (suite 05 §3): top bar, sidebar, template strip,
/// filter / selection bar, list or grid, details panel.
class DriveHomeScreen extends StatefulWidget {
  const DriveHomeScreen({super.key, required this.services, required this.location});

  final ShellServices services;
  final DriveLocation location;

  @override
  State<DriveHomeScreen> createState() => _DriveHomeScreenState();
}

class _DriveHomeScreenState extends State<DriveHomeScreen> {
  late final DriveController c = DriveController(services: widget.services, location: widget.location);
  final _listFocus = FocusNode(debugLabel: 'drive.list');
  final _searchFocus = FocusNode(debugLabel: 'drive.search');
  final _sidebarFocus = FocusNode(debugLabel: 'drive.sidebar', skipTraversal: true);
  final _topFocus = FocusNode(debugLabel: 'drive.top', skipTraversal: true);
  bool _sidebarOpen = true;
  bool _dropping = false;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(c.reload());
    s.focusRegions
      ..clear()
      ..addAll([_topFocus, _sidebarFocus, _listFocus]);
    s.driveSearchFocus = _searchFocus;
    s.currentItem.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(DriveHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) c.setLocation(widget.location);
  }

  @override
  void dispose() {
    s.focusRegions.removeWhere((f) => f == _topFocus || f == _sidebarFocus || f == _listFocus);
    if (s.driveSearchFocus == _searchFocus) s.driveSearchFocus = null;
    c.dispose();
    _listFocus.dispose();
    _searchFocus.dispose();
    _sidebarFocus.dispose();
    _topFocus.dispose();
    super.dispose();
  }

  String _title(WonkyAppLocalizations l) => switch (widget.location.kind) {
    DriveLocationKind.home => l.navHome,
    DriveLocationKind.myDrive => l.navMyDrive,
    DriveLocationKind.folder => c.folder?.name ?? '',
    DriveLocationKind.shared => l.navShared,
    DriveLocationKind.starred => l.navStarred,
    DriveLocationKind.recent => l.navRecent,
    DriveLocationKind.offline => l.navOffline,
    DriveLocationKind.trash => l.navTrash,
    DriveLocationKind.search => l.searchResultsFor(widget.location.query ?? ''),
  };

  Future<void> _onDrop(DropDoneDetails d) async {
    setState(() => _dropping = false);
    final handler = s.config.importHandler;
    if (handler == null || !c.canCreateHere) return;
    final files = <ImportFile>[];
    for (final f in d.files) {
      final name = f.name;
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      if (!handler.extensions.contains(ext)) continue;
      files.add(ImportFile(name: name, bytes: await f.readAsBytes(), mimeType: f.mimeType));
    }
    if (!mounted) return;
    if (files.isEmpty) {
      s.toasts.show(WonkyAppLocalizations.of(context).importUnsupported);
      return;
    }
    try {
      final items = await handler.importFiles(context, s, files, parentUuid: c.folder?.uuid);
      for (final v in items) {
        s.emitDriveChange(DriveChange(kind: DriveChangeKind.created, itemUuid: v.uuid, item: v));
      }
    } catch (e) {
      s.toasts.error(s.l10n?.importFailed ?? 'Error', description: errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 768;
    final sidebarVisible = _sidebarOpen && !narrow;
    final main = ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final showTemplates = widget.location.kind == DriveLocationKind.home ||
            (widget.location.kind == DriveLocationKind.myDrive);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTemplates) TemplateStrip(services: s),
            _Header(controller: c, services: s, title: _title(l)),
            Expanded(child: _body(context, l)),
          ],
        );
      },
    );
    return ColoredBox(
      color: theme.colorScheme.background,
      child: KeymapScope(
        scope: KeyScope.drive,
        keymap: s.keymap,
        child: Column(
          children: [
            Focus(
              focusNode: _topFocus,
              child: WonkyTopBar(
                services: s,
                searchFocus: _searchFocus,
                initialQuery: widget.location.query,
                onToggleSidebar: () => setState(() => _sidebarOpen = !_sidebarOpen),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sidebarVisible)
                    Focus(focusNode: _sidebarFocus, child: DriveSidebar(services: s, location: widget.location)),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: narrow ? 0 : 12, bottom: narrow ? 0 : 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.card,
                        borderRadius: narrow ? null : BorderRadius.circular(16),
                        border: narrow ? null : Border.all(color: theme.colorScheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: WonkySplitView(
                        controller: s.panels,
                        panels: [
                          SidePanelSpec(
                            id: ShellPanels.details,
                            title: l.cmdDetails,
                            icon: LucideIcons.info,
                            builder: (_) => SelectionDetailsPanel(services: s),
                          ),
                        ],
                        child: DropTarget(
                          onDragEntered: (_) => setState(() => _dropping = true),
                          onDragExited: (_) => setState(() => _dropping = false),
                          onDragDone: _onDrop,
                          child: Stack(
                            children: [
                              Positioned.fill(child: main),
                              if (_dropping)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.06),
                                        border: Border.all(color: theme.colorScheme.ring, width: 2),
                                      ),
                                      child: Center(child: Text(l.dropToUpload, style: theme.textTheme.large)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WonkyAppLocalizations l) {
    if (c.loading && c.items.isEmpty) return LoadingShimmer.driveList();
    if (c.error != null && c.items.isEmpty) {
      final offline = isOfflineError(c.error!);
      return WonkyEmptyState(
        illustration: offline ? EmptyIllustration.offline : EmptyIllustration.error,
        title: offline ? l.driveOfflineTitle : l.errorGeneric,
        description: offline ? l.driveOfflineBody : errorMessage(c.error!),
        actions: [ShadButton.outline(onPressed: c.reload, child: Text(l.actionRetry))],
      );
    }
    if (c.items.isEmpty) return _empty(context, l);
    return DriveItemsView(controller: c, services: s, focusNode: _listFocus);
  }

  Widget _empty(BuildContext context, WonkyAppLocalizations l) {
    final (ill, title, desc) = switch (widget.location.kind) {
      DriveLocationKind.starred => (EmptyIllustration.starred, l.emptyStarredTitle, l.emptyStarredBody),
      DriveLocationKind.shared => (EmptyIllustration.shared, l.emptySharedTitle, l.emptySharedBody),
      DriveLocationKind.trash => (EmptyIllustration.trash, l.emptyTrashViewTitle, l.emptyTrashViewBody),
      DriveLocationKind.offline => (EmptyIllustration.offline, l.emptyOfflineTitle, l.emptyOfflineBody),
      DriveLocationKind.search => (EmptyIllustration.search, l.emptySearchTitle, l.emptySearchBody),
      DriveLocationKind.folder => (EmptyIllustration.folder, l.emptyFolderTitle, l.emptyFolderBody),
      _ => (EmptyIllustration.documents, l.emptyHomeTitle, l.emptyHomeBody),
    };
    final r = MenuResolver(s);
    final newEntry = r.commandEntry(context, 'shell.file.new', key: 'empty.new');
    return WonkyEmptyState(
      key: const ValueKey<String>('drive.empty'),
      illustration: ill,
      title: title,
      description: desc,
      actions: [
        if (c.canCreateHere && newEntry != null && widget.location.kind != DriveLocationKind.trash)
          ShadButton(
            key: const ValueKey<String>('drive.empty.new'),
            leading: const Icon(LucideIcons.plus, size: 16),
            onPressed: newEntry.onSelected,
            child: Text(newEntry.label),
          ),
      ],
    );
  }
}

/// Breadcrumb/title + filter bar, or the selection action bar.
class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.services, required this.title});

  final DriveController controller;
  final ShellServices services;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = controller;
    final sel = c.selection;
    void run(String id, [Map<String, Object?> args = const {}]) =>
        services.dispatcher.invoke(id, args: args, source: InvocationSource.toolbar, context: context);
    Widget cmdIcon(String id, IconData icon, String label, {String? key}) {
      final st = services.dispatcher.stateOf(id);
      return ShadTooltip(
        builder: (_) => Text(label),
        child: ShadIconButton.ghost(
          key: ValueKey<String>(key ?? 'drive.selection.${id.split('.').last}'),
          width: 32,
          height: 32,
          iconSize: 16,
          semanticLabel: label,
          enabled: st.enabled,
          icon: Icon(icon),
          onPressed: () => run(id),
        ),
      );
    }

    final titleRow = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: c.location.kind == DriveLocationKind.folder
                ? _Breadcrumb(controller: c, services: services)
                : Semantics(header: true, child: Text(title, style: theme.textTheme.h4, overflow: TextOverflow.ellipsis)),
          ),
          if (c.location.isTrash && c.items.isNotEmpty)
            ShadButton.outline(
              key: const ValueKey<String>('drive.emptyTrash'),
              size: ShadButtonSize.sm,
              onPressed: () => run('shell.drive.emptyTrash'),
              child: Text(l.cmdEmptyTrash),
            ),
          ShadTooltip(
            builder: (_) => Text(c.layout == DriveLayout.list ? l.layoutGrid : l.layoutList),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('drive.layout'),
              semanticLabel: c.layout == DriveLayout.list ? l.layoutGrid : l.layoutList,
              icon: Icon(c.layout == DriveLayout.list ? LucideIcons.layoutGrid : LucideIcons.list, size: 18),
              onPressed: () => c.setLayout(c.layout == DriveLayout.list ? DriveLayout.grid : DriveLayout.list),
            ),
          ),
          ShadTooltip(
            builder: (_) => Text(l.cmdDetails),
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('drive.details'),
              semanticLabel: l.cmdDetails,
              icon: const Icon(LucideIcons.info, size: 18),
              onPressed: () => run('shell.file.details'),
            ),
          ),
        ],
      ),
    );

    Widget bar;
    if (sel.isNotEmpty) {
      final trash = c.location.isTrash;
      bar = Container(
        key: const ValueKey<String>('drive.selectionBar'),
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 44,
        decoration: BoxDecoration(color: theme.colorScheme.secondary, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            ShadIconButton.ghost(
              key: const ValueKey<String>('drive.selection.clear'),
              width: 32,
              height: 32,
              iconSize: 16,
              semanticLabel: l.actionClear,
              icon: const Icon(LucideIcons.x),
              onPressed: c.clearSelection,
            ),
            Text(l.selectedCount(sel.length), style: theme.textTheme.small),
            const SizedBox(width: 12),
            if (trash) ...[
              cmdIcon('shell.drive.restore', LucideIcons.archiveRestore, l.cmdRestore),
              cmdIcon('shell.drive.deleteForever', LucideIcons.trash, l.cmdDeleteForever),
            ] else ...[
              cmdIcon('shell.sharing.open', LucideIcons.userPlus, l.cmdShare),
              cmdIcon('shell.drive.move', LucideIcons.folderInput, l.cmdMove),
              cmdIcon('shell.drive.copy', LucideIcons.copy, l.cmdMakeCopy),
              cmdIcon('shell.drive.setStarred', LucideIcons.star, l.cmdStar),
              if (sel.length == 1) cmdIcon('shell.drive.rename', LucideIcons.pencil, l.cmdRename),
              cmdIcon('shell.drive.trash', LucideIcons.trash2, l.cmdMoveToTrash),
              WonkyDropdownMenu(
                entries: () => itemMenuEntries(context, services, trash: false),
                builder: (context, ctl) => ShadIconButton.ghost(
                  width: 32,
                  height: 32,
                  iconSize: 16,
                  semanticLabel: l.moreActions,
                  icon: const Icon(LucideIcons.ellipsisVertical),
                  onPressed: ctl.toggle,
                ),
              ),
            ],
          ],
        ),
      );
    } else {
      String typeLabel(DriveTypeFilter t) => switch (t) {
        DriveTypeFilter.primary => services.config.primaryKind == DriveItemKind.document ? l.typeDocuments : l.typeSpreadsheets,
        DriveTypeFilter.documents => l.typeDocuments,
        DriveTypeFilter.spreadsheets => l.typeSpreadsheets,
        DriveTypeFilter.folders => l.typeFolders,
        DriveTypeFilter.all => l.typeAll,
      };
      String ownerLabel(DriveOwnerFilter o) => switch (o) {
        DriveOwnerFilter.anyone => l.ownerAnyone,
        DriveOwnerFilter.me => l.ownerMeFilter,
        DriveOwnerFilter.notMe => l.ownerNotMe,
      };
      String sortLabel(DriveSortField f) => switch (f) {
        DriveSortField.name => l.sortName,
        DriveSortField.modifiedAt => l.sortModified,
        DriveSortField.lastOpenedByMe => l.sortOpenedByMe,
        DriveSortField.lastModifiedByMe => l.sortModifiedByMe,
        DriveSortField.size => l.sortSize,
        DriveSortField.createdAt => l.sortCreated,
      };
      Widget chip(String key, String label, List<WonkyMenuEntry> Function() entries) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: WonkyDropdownMenu(
          entries: entries,
          builder: (context, ctl) => ShadButton.outline(
            key: ValueKey<String>('drive.filter.$key'),
            size: ShadButtonSize.sm,
            trailing: const Icon(LucideIcons.chevronDown, size: 14),
            onPressed: ctl.toggle,
            child: Text(label),
          ),
        ),
      );
      bar = Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip('type', typeLabel(c.typeFilter), () => [
                for (final t in DriveTypeFilter.values)
                  if (!(t == DriveTypeFilter.primary &&
                      (services.config.primaryKind == DriveItemKind.document ? DriveTypeFilter.documents : DriveTypeFilter.spreadsheets) == t))
                    WonkyMenuRadioItem(label: typeLabel(t), selected: c.typeFilter == t, onSelected: () => c.setTypeFilter(t)),
              ]),
              chip('owner', ownerLabel(c.ownerFilter), () => [
                for (final o in DriveOwnerFilter.values)
                  WonkyMenuRadioItem(label: ownerLabel(o), selected: c.ownerFilter == o, onSelected: () => c.setOwnerFilter(o)),
              ]),
              chip('sort', l.sortBy(sortLabel(c.sortField)), () => [
                for (final f in [DriveSortField.name, DriveSortField.modifiedAt, DriveSortField.lastOpenedByMe, DriveSortField.lastModifiedByMe, DriveSortField.size])
                  WonkyMenuRadioItem(label: sortLabel(f), selected: c.sortField == f, onSelected: () => c.setSort(f, descending: f != DriveSortField.name)),
                const WonkyMenuSeparator(),
                WonkyMenuCheckItem(label: l.sortDescending, checked: c.descending, onSelected: () => c.setSort(c.sortField, descending: !c.descending)),
                WonkyMenuCheckItem(label: l.foldersOnTop, checked: c.foldersFirst, onSelected: () => c.setFoldersFirst(!c.foldersFirst)),
              ]),
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [titleRow, bar]);
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.controller, required this.services});

  final DriveController controller;
  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    Widget crumb(String label, String? folderUuid, {bool last = false}) => DragTarget<DriveDragData>(
      onWillAcceptWithDetails: (_) => !last,
      onAcceptWithDetails: (d) => dropIntoFolder(services, d.data, folderUuid),
      builder: (context, cand, _) => last
          ? Text(label, style: theme.textTheme.h4)
          : ShadButton.ghost(
              size: ShadButtonSize.sm,
              backgroundColor: cand.isNotEmpty ? theme.colorScheme.selection : null,
              onPressed: () => services.router.go(folderUuid == null ? '/my-drive' : '/drive/$folderUuid'),
              child: Text(label, style: theme.textTheme.large.copyWith(color: theme.colorScheme.mutedForeground)),
            ),
    );
    final f = controller.folder;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          crumb(l.navMyDrive, null),
          for (final p in controller.path) ...[
            const Icon(LucideIcons.chevronRight, size: 16),
            crumb(p.name, p.uuid.uuid),
          ],
          if (f != null) ...[
            const Icon(LucideIcons.chevronRight, size: 16),
            crumb(f.name, f.uuid.uuid, last: true),
          ],
        ],
      ),
    );
  }
}
