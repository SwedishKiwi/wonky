import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../data/api.dart';
import '../drive/drive_format.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/dialogs.dart';
import '../shell/shell_services.dart';

/// Loads and caches the versions of one item.
class VersionsController extends ChangeNotifier {
  VersionsController(this.services, this.itemUuid);

  final ShellServices services;
  final UuidValue itemUuid;
  List<ItemVersionView> versions = const [];
  bool loading = true;
  Object? error;
  bool namedOnly = false;
  int? selectedId;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      versions = await services.repositories.versions.list(
        itemUuid,
        namedOnly: namedOnly,
      );
      error = null;
      selectedId ??= versions.firstOrNull?.id;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setNamedOnly(bool v) {
    namedOnly = v;
    load();
  }

  void select(int id) {
    selectedId = id;
    notifyListeners();
  }

  ItemVersionView? get selected =>
      versions.where((v) => v.id == selectedId).firstOrNull;

  ItemVersionView? previousOf(ItemVersionView v) {
    final i = versions.indexOf(v);
    return i >= 0 && i + 1 < versions.length ? versions[i + 1] : null;
  }

  Future<void> rename(ItemVersionView v, String? name) async {
    await services.repositories.versions.rename(itemUuid, v.id, name);
    await load();
  }
}

/// The versions list grouped by date (suite 07 §5) with ⋮ → name / restore
/// / make a copy. Used by the side panel and the full-screen history.
class VersionsList extends StatelessWidget {
  const VersionsList({
    super.key,
    required this.controller,
    this.onOpenFull,
    this.selectable = false,
  });

  final VersionsController controller;
  final VoidCallback? onOpenFull;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final s = controller.services;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final day = intl.DateFormat.yMMMMd();
        final time = intl.DateFormat.jm();
        final groups = <String, List<ItemVersionView>>{};
        for (final v in c.versions) {
          groups
              .putIfAbsent(day.format(v.createdAt.toLocal()), () => [])
              .add(v);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ShadSwitch(
                      key: const ValueKey<String>('versions.namedOnly'),
                      value: c.namedOnly,
                      onChanged: c.setNamedOnly,
                      label: Text(l.versionsNamedOnly),
                    ),
                  ),
                  if (onOpenFull != null)
                    ShadButton.link(
                      key: const ValueKey<String>('versions.openFull'),
                      size: ShadButtonSize.sm,
                      onPressed: onOpenFull,
                      child: Text(l.versionsOpenFull),
                    ),
                ],
              ),
            ),
            Expanded(
              child: c.loading && c.versions.isEmpty
                  ? const Center(child: ShadSpinner())
                  : c.error != null
                  ? Center(
                      child: Text(
                        errorMessage(c.error!),
                        style: theme.textTheme.muted,
                      ),
                    )
                  : c.versions.isEmpty
                  ? WonkyEmptyState(
                      illustration: EmptyIllustration.history,
                      title: l.versionsEmpty,
                      size: 80,
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                      children: [
                        for (final g in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                            child: Text(
                              g.key,
                              style: theme.textTheme.muted.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final v in g.value)
                            _VersionTile(
                              key: ValueKey<String>('versions.item.${v.id}'),
                              version: v,
                              selected: selectable && c.selectedId == v.id,
                              title:
                                  v.name ?? time.format(v.createdAt.toLocal()),
                              subtitle: [
                                if (v.name != null)
                                  time.format(v.createdAt.toLocal()),
                                if (v.kind == VersionKind.restorePoint)
                                  l.versionsRestorePoint,
                              ].join(' · '),
                              onTap: selectable ? () => c.select(v.id) : null,
                              menu: () => [
                                WonkyMenuItem(
                                  label: v.name == null
                                      ? l.versionsName
                                      : l.versionsRename,
                                  icon: LucideIcons.pencil,
                                  onSelected: () async {
                                    final name = await showNameVersionDialog(
                                      context,
                                      s,
                                      initial: v.name ?? '',
                                    );
                                    if (name != null) await c.rename(v, name);
                                  },
                                ),
                                WonkyMenuItem(
                                  label: l.cmdRestoreVersion,
                                  icon: LucideIcons.archiveRestore,
                                  enabled:
                                      s.activeDocument.value?.role.canEdit ??
                                      s.currentItem.value?.role ==
                                          AccessRole.owner,
                                  onSelected: () async {
                                    await s.dispatcher.invoke(
                                      'shell.versions.restore',
                                      args: {'versionId': v.id},
                                      source: InvocationSource.ui,
                                      context: context,
                                    );
                                    await c.load();
                                  },
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    super.key,
    required this.version,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.menu,
    this.onTap,
  });

  final ItemVersionView version;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final List<WonkyMenuEntry> Function() menu;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.sidebarAccent : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              version.name != null ? LucideIcons.bookmark : LucideIcons.clock,
              size: 14,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: version.name != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  if (version.authors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          for (final a in version.authors.take(5))
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: WonkyAvatar(
                                name: a.displayName,
                                color: theme.colorScheme.presence(a.colorIndex),
                                size: 16,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              version.authors
                                  .map((a) => a.displayName)
                                  .join(', '),
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.muted.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            WonkyDropdownMenu(
              anchor: const ShadAnchor(
                childAlignment: AlignmentDirectional.bottomEnd,
                overlayAlignment: AlignmentDirectional.topEnd,
              ),
              entries: menu,
              builder: (context, ctl) => ShadIconButton.ghost(
                width: 26,
                height: 26,
                iconSize: 14,
                semanticLabel: l.moreActions,
                icon: const Icon(LucideIcons.ellipsisVertical),
                onPressed: ctl.toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps `drive_format` reachable for authors' colors.
Color versionAuthorColor(UserSummary u) => parseHexColor(u.avatarColor);
