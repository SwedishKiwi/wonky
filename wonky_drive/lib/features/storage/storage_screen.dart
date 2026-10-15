import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart'
    show CommandResult, InvocationSource, KeyScope;
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/drive_l10n.dart';
import 'storage_controller.dart';
import 'storage_overview.dart';
import 'storage_table.dart';

/// The Storage page `/storage` (Drive 03 §6.4, Drive 04 §7) in the home
/// frame (top bar, storage banner, left menu with *Storage* highlighted):
/// the usage by kind, *Free up space* suggestions and the items by counted
/// size with multi-selection (*Move to trash*, *Delete forever*,
/// *Download*). [filter] comes from `?filter=` (`drive.storage.show`).
class StorageScreen extends StatefulWidget {
  const StorageScreen({
    super.key,
    required this.services,
    this.filter = StorageFilter.all,
  });

  final ShellServices services;
  final StorageFilter filter;

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  late final StoragePageController c = StoragePageController(
    services: widget.services,
    filter: widget.filter,
  );
  final _scroll = ScrollController();
  final _listFocus = FocusNode(debugLabel: 'storage.list');
  final _searchFocus = FocusNode(debugLabel: 'storage.search');
  final _sidebarFocus = FocusNode(
    debugLabel: 'storage.sidebar',
    skipTraversal: true,
  );
  final _topFocus = FocusNode(debugLabel: 'storage.top', skipTraversal: true);
  bool _sidebarOpen = true;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(c.reload());
    unawaited(s.storage.refresh().catchError((Object _) => null));
    s.focusRegions
      ..clear()
      ..addAll([_topFocus, _sidebarFocus, _listFocus]);
    s.driveSearchFocus = _searchFocus;
    s.currentItem.value = null;
    s.currentFolder.value = null;
    _scroll.addListener(() {
      final p = _scroll.position;
      if (p.pixels > p.maxScrollExtent - 400) unawaited(c.loadMore());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _listFocus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(StorageScreen old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter) c.setFilter(widget.filter);
  }

  @override
  void dispose() {
    s.focusRegions.removeWhere(
      (f) => f == _topFocus || f == _sidebarFocus || f == _listFocus,
    );
    if (s.driveSearchFocus == _searchFocus) s.driveSearchFocus = null;
    c.dispose();
    _scroll.dispose();
    _listFocus.dispose();
    _searchFocus.dispose();
    _sidebarFocus.dispose();
    _topFocus.dispose();
    super.dispose();
  }

  // ---- Actions (all through commands) ----

  Future<CommandResult> _invoke(
    String id, [
    Map<String, Object?> args = const {},
  ]) => s.dispatcher.invoke(
    id,
    args: args,
    source: InvocationSource.ui,
    context: context,
  );

  List<String> get _selectedIds => [for (final i in c.selection) i.uuid.uuid];

  void _showFilter(StorageFilter f) =>
      unawaited(_invoke('drive.storage.show', {'filter': f.name}));

  /// *Empty trash* with the count and the bytes it frees (Drive 03 §6.4).
  Future<void> _emptyTrash() async {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final size = storageBytes(s.storage.value?.trashBytes ?? 0);
    int? count;
    try {
      final page = await c.api.listByStorage(
        StorageListFilter(trashedOnly: true),
        limit: StoragePageController.suggestionLimit,
      );
      if (page.nextCursor == null) count = page.items.length;
    } on Object {
      // Unknown count: the generic text.
    }
    if (!mounted) return;
    final ok = await confirmDialog(
      context,
      title: l.storageEmptyTrashTitleConfirm,
      description: count == null
          ? l.storageEmptyTrashBodyUnknown(size)
          : l.storageEmptyTrashBody(count, size),
      confirmLabel: la.emptyTrashAction,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final r = await _invoke('shell.drive.emptyTrash', {'confirmed': true});
    if (r.isOk) s.toasts.show(driveL10nOf(s).storageTrashEmptied);
  }

  Future<void> _deleteForever() async {
    final items = c.selection;
    if (items.isEmpty) return;
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.storageDeleteTitle(items.length),
      description: l.storageDeleteBody(storageBytes(c.selectedBytes)),
      confirmLabel: la.cmdDeleteForever,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final r = await _invoke('shell.drive.deleteForever', {
      'uuids': [for (final i in items) i.uuid.uuid],
      'confirmed': true,
    });
    if (r.isOk) s.toasts.show(driveL10nOf(s).storageDeleted(items.length));
  }

  void _open(DriveItemView item) {
    c.select(item);
    unawaited(_invoke('shell.drive.open', {'uuid': item.uuid.uuid}));
  }

  void _tap(DriveItemView item) {
    final keys = HardwareKeyboard.instance;
    _listFocus.requestFocus();
    c.select(
      item,
      toggle: keys.isMetaPressed || keys.isControlPressed,
      range: keys.isShiftPressed,
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        c.moveFocus(1, extend: shift);
      case LogicalKeyboardKey.arrowUp:
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

  /// Below `md` the left menu is a drawer (Drive 04 §2).
  Future<void> _openDrawer() => showShadSheet<void>(
    context: context,
    side: ShadSheetSide.left,
    barrierLabel: WonkyAppLocalizations.of(context).actionClose,
    builder: (sheetContext) => ShadSheet(
      key: const ValueKey<String>('home.drawer'),
      closeIcon: ShadIconButton.ghost(
        key: const ValueKey<String>('home.drawer.close'),
        width: 32,
        height: 32,
        iconSize: 16,
        semanticLabel: WonkyAppLocalizations.of(sheetContext).actionClose,
        icon: const Icon(LucideIcons.x),
        onPressed: () => Navigator.of(sheetContext).maybePop(),
      ),
      scrollable: false,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxWidth: HomeSidebar.width + 8),
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: HomeSidebar(
            services: s,
            location: const DriveLocation.home(),
            activeDestination: HomeNavDestination.storage,
            onNavigate: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 768;
    final sidebarVisible = _sidebarOpen && !narrow;
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
                onToggleSidebar: narrow
                    ? _openDrawer
                    : () => setState(() => _sidebarOpen = !_sidebarOpen),
                contentStart: sidebarVisible ? HomeSidebar.width + 20 : null,
              ),
            ),
            StorageBanner(services: s),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sidebarVisible)
                    Focus(
                      focusNode: _sidebarFocus,
                      child: HomeSidebar(
                        services: s,
                        location: const DriveLocation.home(),
                        activeDestination: HomeNavDestination.storage,
                      ),
                    ),
                  Expanded(
                    child: Container(
                      key: const ValueKey<String>('storage.page'),
                      margin: EdgeInsets.only(
                        right: narrow ? 0 : 12,
                        bottom: narrow ? 0 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.card,
                        borderRadius: narrow ? null : BorderRadius.circular(16),
                        border: narrow
                            ? null
                            : Border.all(color: theme.colorScheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _content(context),
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

  Widget _content(BuildContext context) {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final pad = box.maxWidth < 480 ? 12.0 : 24.0;
        final wide = box.maxWidth - 2 * pad >= 760;
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => Focus(
            focusNode: _listFocus,
            onKeyEvent: _onKey,
            child: WonkyScrollArea(
              controller: _scroll,
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(
                                  l.storageTitle,
                                  style: theme.textTheme.h3,
                                ),
                              ),
                            ),
                            if ((s.storage.value?.trashBytes ?? 0) > 0)
                              ShadButton.outline(
                                key: const ValueKey<String>(
                                  'storage.emptyTrash',
                                ),
                                size: ShadButtonSize.sm,
                                leading: const Icon(
                                  LucideIcons.trash2,
                                  size: 14,
                                ),
                                onPressed: _emptyTrash,
                                child: Text(l.storageEmptyTrash),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StorageUsageSummary(services: s),
                        const SizedBox(height: 28),
                        StorageSuggestions(
                          services: s,
                          controller: c,
                          onEmptyTrash: _emptyTrash,
                          onReview: _showFilter,
                        ),
                        const SizedBox(height: 28),
                        StorageTableTitle(
                          filter: c.filter,
                          onFilter: _showFilter,
                        ),
                        const SizedBox(height: 8),
                        StorageTableBar(
                          controller: c,
                          wide: wide,
                          onTrash: () => unawaited(
                            _invoke('shell.drive.trash', {
                              'uuids': _selectedIds,
                            }),
                          ),
                          onRestore: () => unawaited(
                            _invoke('shell.drive.restore', {
                              'uuids': _selectedIds,
                            }),
                          ),
                          onDeleteForever: () => unawaited(_deleteForever()),
                          onDownload: () => unawaited(
                            _invoke('drive.file.download', {
                              'uuids': _selectedIds,
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._rows(context, pad, wide),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
                    sliver: SliverList.list(
                      children: [
                        if (c.loadingMore)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              l.storageLoadingMore,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.muted,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          l.storageWhatCountsTitle,
                          style: theme.textTheme.small,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          la.settingsStorageWhatCountsBody,
                          key: const ValueKey<String>('storage.whatCounts'),
                          style: theme.textTheme.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _rows(BuildContext context, double pad, bool wide) {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    Widget box(Widget child) => SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      sliver: SliverToBoxAdapter(child: child),
    );
    if (c.loading && c.items.isEmpty) {
      return [
        box(
          SizedBox(
            height: 220,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: LoadingShimmer.driveList(rows: 4),
              ),
            ),
          ),
        ),
      ];
    }
    final error = c.error;
    if (error != null && c.items.isEmpty) {
      final offline = isOfflineError(error);
      return [
        box(
          WonkyEmptyState(
            key: const ValueKey<String>('storage.error'),
            illustration: offline
                ? EmptyIllustration.offline
                : EmptyIllustration.error,
            title: offline ? l.storageOfflineTitle : l.storageErrorTitle,
            description: offline ? l.storageOfflineBody : errorMessage(error),
            size: 96,
            actions: [
              ShadButton.outline(
                key: const ValueKey<String>('storage.retry'),
                onPressed: () => unawaited(c.reload()),
                child: Text(la.actionRetry),
              ),
            ],
          ),
        ),
      ];
    }
    if (c.items.isEmpty) {
      return [
        box(
          WonkyEmptyState(
            key: const ValueKey<String>('storage.empty'),
            illustration: c.filter == StorageFilter.trash
                ? EmptyIllustration.trash
                : EmptyIllustration.folder,
            title: switch (c.filter) {
              StorageFilter.all => l.storageEmptyTitle,
              StorageFilter.trash => l.storageEmptyTrashTitle,
              _ => l.storageEmptyFilterTitle,
            },
            size: 96,
            actions: [
              if (c.filter != StorageFilter.all)
                ShadButton.outline(
                  key: const ValueKey<String>('storage.empty.showAll'),
                  onPressed: () => _showFilter(StorageFilter.all),
                  child: Text(l.storageClearFilter),
                ),
            ],
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        sliver: SliverList.builder(
          itemCount: c.items.length,
          itemBuilder: (context, i) {
            final item = c.items[i];
            return StorageRow(
              key: ValueKey<String>('storage.item.${item.uuid.uuid}'),
              services: s,
              controller: c,
              item: item,
              wide: wide,
              focused: c.focusedId == item.uuid.uuid && _listFocus.hasFocus,
              onTap: () => _tap(item),
              onOpen: () => _open(item),
            );
          },
        ),
      ),
    ];
  }
}

/// `/storage?filter=…` → [StorageScreen] (registered by `DriveAppConfig`).
Widget storageRoutePage(ShellServices services, Uri uri) => StorageScreen(
  services: services,
  filter: StorageFilter.parse(uri.queryParameters['filter']),
);
