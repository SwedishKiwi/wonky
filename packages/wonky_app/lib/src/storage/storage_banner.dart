import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart'
    show CommandResult, InvocationSource;
import 'package:wonky_ui/wonky_ui.dart';

import '../data/models_ext.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'storage_controller.dart';
import 'storage_format.dart';

/// Where a [StorageBanner] is shown: dismissal rules differ (Drive 03 §6.2).
enum StorageBannerPlace { home, editor }

/// The storage banner (Drive 03 §6.2, suite 03 §4): one line below the top
/// bar of a home or the header of an editor —
///
/// | State | Tint | Dismissal |
/// |-------|------|-----------|
/// | ≥ 90 % "You've used 46.1 MB of your 50 MB storage." | `warning` | per device for 7 days |
/// | Over quota "You're out of storage. …" | `destructive` | homes: not dismissible; editors: per device until the next day |
///
/// Actions: *Manage storage* (`shell.storage.open`), and *Empty trash*
/// first when the trash holds ≥ 10 % of the usage (§7.4). Editors show it
/// only for items the user owns ([item]). It follows the
/// `StorageController`, so it appears and disappears live.
class StorageBanner extends StatefulWidget {
  const StorageBanner({
    super.key,
    required this.services,
    this.place = StorageBannerPlace.home,
    this.item,
  });

  final ShellServices services;
  final StorageBannerPlace place;

  /// The open item (editors): the banner shows only when the user owns it.
  final DriveItemView? item;

  /// Device-store keys of the dismissal times (ISO 8601).
  static const warningDismissedKey = 'storage.banner.warningDismissedAt';
  static const overDismissedKey = 'storage.banner.overDismissedAt';

  /// How long a dismissed 90 % banner stays hidden.
  static const warningSnooze = Duration(days: 7);

  @override
  State<StorageBanner> createState() => _StorageBannerState();
}

enum _Level { warning, over }

class _StorageBannerState extends State<StorageBanner> {
  DateTime? _warningDismissed;
  DateTime? _overDismissed;

  ShellServices get s => widget.services;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final w = await s.deviceStore.read(StorageBanner.warningDismissedKey);
      final o = await s.deviceStore.read(StorageBanner.overDismissedKey);
      if (!mounted) return;
      setState(() {
        _warningDismissed = w is String ? DateTime.tryParse(w) : null;
        _overDismissed = o is String ? DateTime.tryParse(o) : null;
      });
    } catch (_) {}
  }

  _Level? _levelOf(StorageUsage? u) {
    if (u == null || u.calculating || u.quotaBytes <= 0) return null;
    if (widget.place == StorageBannerPlace.editor) {
      final item = widget.item;
      if (item == null || !item.myRole.isOwner) return null;
    }
    final now = clock.now();
    if (u.overQuota) {
      final d = _overDismissed;
      final dismissed =
          widget.place == StorageBannerPlace.editor &&
          d != null &&
          _sameDay(d.toLocal(), now.toLocal());
      return dismissed ? null : _Level.over;
    }
    if (u.isWarning()) {
      final d = _warningDismissed;
      final dismissed =
          d != null && now.difference(d) < StorageBanner.warningSnooze;
      return dismissed ? null : _Level.warning;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _dismiss(_Level level) {
    final now = clock.now();
    setState(() {
      if (level == _Level.over) {
        _overDismissed = now;
      } else {
        _warningDismissed = now;
      }
    });
    unawaited(
      s.deviceStore
          .write(
            level == _Level.over
                ? StorageBanner.overDismissedKey
                : StorageBanner.warningDismissedKey,
            now.toUtc().toIso8601String(),
          )
          .catchError((Object _) {}),
    );
  }

  void _invoke(String id) {
    unawaited(
      s.dispatcher
          .invoke(id, source: InvocationSource.ui, context: context)
          .catchError((Object e) {
            debugPrint('$id failed: $e');
            return const CommandResult.failed('error');
          }),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<StorageUsage?>(
    valueListenable: s.storage,
    builder: (context, u, _) {
      final level = _levelOf(u);
      if (level == null || u == null) return const SizedBox.shrink();
      return _banner(context, u, level);
    },
  );

  Widget _banner(BuildContext context, StorageUsage u, _Level level) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final over = level == _Level.over;
    final tint = over
        ? theme.colorScheme.destructive
        : theme.colorScheme.warning;
    final dismissible = !over || widget.place == StorageBannerPlace.editor;
    final trashFirst = over && u.trashBytes * 10 >= u.bytesUsed;
    final text = over
        ? l.storageBannerOver
        : l.storageBannerWarning(
            storageBytes(u.bytesUsed),
            storageQuota(u.quotaBytes),
          );
    final prefix = over ? 'storage.banner.over' : 'storage.banner.warning';
    final actions = [
      if (trashFirst && u.trashBytes > 0)
        ShadButton.outline(
          key: ValueKey<String>('$prefix.emptyTrash'),
          size: ShadButtonSize.sm,
          height: 28,
          onPressed: () => _invoke('shell.drive.emptyTrash'),
          // Long labels (translations) ellipsize on narrow windows.
          child: Flexible(
            child: Text(
              l.cmdEmptyTrash,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ShadButton.outline(
        key: ValueKey<String>('$prefix.manage'),
        size: ShadButtonSize.sm,
        height: 28,
        onPressed: () => _invoke('shell.storage.open'),
        // Long labels (translations) ellipsize on narrow windows.
        child: Flexible(
          child: Text(
            l.cmdManageStorage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: ValueKey<String>(prefix),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            tint.withValues(alpha: 0.12),
            theme.colorScheme.background,
          ),
          border: Border(
            bottom: BorderSide(color: tint.withValues(alpha: 0.35)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              over ? LucideIcons.hardDrive : LucideIcons.triangleAlert,
              size: 16,
              color: tint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.normal,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                  Wrap(spacing: 8, runSpacing: 6, children: actions),
                ],
              ),
            ),
            if (dismissible)
              ShadTooltip(
                builder: (_) => Text(l.storageBannerDismiss),
                child: ShadIconButton.ghost(
                  key: ValueKey<String>('$prefix.dismiss'),
                  width: 28,
                  height: 28,
                  iconSize: 16,
                  icon: Icon(
                    LucideIcons.x,
                    semanticLabel: l.storageBannerDismiss,
                  ),
                  onPressed: () => _dismiss(level),
                ),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
