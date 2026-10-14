import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;
import 'package:wonky_ui/wonky_ui.dart';

import '../data/api.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'versions_list.dart';

/// Full-screen version history (suite 07 §5, `/…/:uuid/history`): the app's
/// [VersionRenderer] on the left, versions on the right, top bar with
/// *Back to editing* and *Restore this version*.
class VersionHistoryScreen extends StatefulWidget {
  const VersionHistoryScreen({
    super.key,
    required this.services,
    required this.itemUuid,
  });

  final ShellServices services;
  final String itemUuid;

  /// *Show changes* of the history route (on by default); apps' commands
  /// toggle it (Sheets: `sheets.history.toggleShowChanges`).
  static final ValueNotifier<bool> showChanges = ValueNotifier(true);

  @override
  State<VersionHistoryScreen> createState() => _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends State<VersionHistoryScreen> {
  late final VersionsController c = VersionsController(
    widget.services,
    UuidValue.fromString(widget.itemUuid),
  );
  DriveItemView? _item;
  Object? _error;

  bool get _showChanges => VersionHistoryScreen.showChanges.value;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    c.load();
    s.drive
        .get(c.itemUuid)
        .then((v) {
          if (mounted) setState(() => _item = v);
          s.currentItem.value = v;
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _back() => s.router.go(s.config.itemPath(widget.itemUuid));

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final renderer = s.config.versionRenderer;
    if (_error != null) {
      return WonkyEmptyState(
        illustration: EmptyIllustration.noAccess,
        title: l.noAccessTitle,
        description: errorMessage(_error!),
      );
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _back},
      child: ColoredBox(
        color: theme.colorScheme.background,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: theme.colorScheme.border),
                ),
              ),
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  c,
                  VersionHistoryScreen.showChanges,
                ]),
                builder: (context, _) {
                  final v = c.selected;
                  return Row(
                    children: [
                      ShadButton.ghost(
                        key: const ValueKey<String>('history.back'),
                        leading: const Icon(LucideIcons.arrowLeft, size: 16),
                        onPressed: _back,
                        child: Text(l.historyBack),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          v == null
                              ? (_item?.name ?? '')
                              : (v.name ??
                                    intl.DateFormat.yMMMd().add_jm().format(
                                      v.createdAt.toLocal(),
                                    )),
                          style: theme.textTheme.large,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ShadSwitch(
                        value: _showChanges,
                        onChanged: (x) =>
                            VersionHistoryScreen.showChanges.value = x,
                        label: Text(l.historyShowChanges),
                      ),
                      const SizedBox(width: 12),
                      ShadButton(
                        key: const ValueKey<String>('history.restore'),
                        enabled:
                            v != null &&
                            (_item?.role == AccessRole.owner ||
                                _item?.role == AccessRole.editor),
                        onPressed: () async {
                          await s.dispatcher.invoke(
                            'shell.versions.restore',
                            args: {'versionId': v!.id},
                            source: InvocationSource.ui,
                            context: context,
                          );
                          await c.load();
                        },
                        child: Text(l.historyRestoreThis),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: theme.colorScheme.canvas,
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          c,
                          VersionHistoryScreen.showChanges,
                        ]),
                        builder: (context, _) {
                          final v = c.selected;
                          if (v == null) {
                            return c.loading
                                ? const Center(child: ShadSpinner())
                                : Center(
                                    child: Text(
                                      l.versionsEmpty,
                                      style: theme.textTheme.muted,
                                    ),
                                  );
                          }
                          if (renderer == null) {
                            return Center(
                              child: Text(
                                l.historyNoRenderer,
                                style: theme.textTheme.muted,
                              ),
                            );
                          }
                          return renderer.build(
                            context,
                            itemUuid: c.itemUuid,
                            version: v,
                            previous: c.previousOf(v),
                            showChanges: _showChanges,
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    width: 320,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: theme.colorScheme.border),
                      ),
                    ),
                    child: VersionsList(controller: c, selectable: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
