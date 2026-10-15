import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'storage_controller.dart';
import 'storage_format.dart';

/// The storage meter (Drive 03 §6.1): a 4 px bar and "12.3 MB of 50 MB
/// used" — in the bottom section of every home's left menu, in Settings ›
/// Storage and (with [large]) at the top of Drive's Storage page.
///
/// The bar is `primary` below the warning threshold, `warning` from 90 %
/// and `destructive` at the quota ("… used — over quota"); indeterminate
/// with "Calculating storage…" while the server computes the usage. With
/// [onOpen] it is a button (click, Enter or Space; the left menu passes
/// `shell.storage.open`). Hidden while the usage is unknown.
class StorageMeter extends StatefulWidget {
  const StorageMeter({
    super.key,
    required this.services,
    this.onOpen,
    this.large = false,
  });

  final ShellServices services;
  final VoidCallback? onOpen;

  /// The Storage page's big meter: an 8 px bar and larger text.
  final bool large;

  @override
  State<StorageMeter> createState() => _StorageMeterState();
}

class _StorageMeterState extends State<StorageMeter> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge([s.storage, s.connectivity]),
      builder: (context, _) {
        final u = s.storage.value;
        if (u == null) return const SizedBox.shrink();
        return _meter(
          context,
          u,
          offline: s.storage.stale || !s.connectivity.online,
        );
      },
    );
  }

  Widget _meter(BuildContext context, StorageUsage u, {required bool offline}) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final large = widget.large;
    final calculating = u.calculating;
    final hasQuota = u.quotaBytes > 0;
    final over = hasQuota && u.bytesUsed >= u.quotaBytes;
    final used = storageBytes(u.bytesUsed);
    final quota = storageQuota(u.quotaBytes);
    final text = calculating
        ? l.storageCalculating
        : !hasQuota
        ? l.storageUsed(used)
        : over
        ? l.storageUsedOfOver(used, quota)
        : l.storageUsedOf(used, quota);
    final fraction = u.usedFraction.clamp(0.0, 1.0);
    final color = over
        ? theme.colorScheme.destructive
        : u.isWarning()
        ? theme.colorScheme.warning
        : theme.colorScheme.primary;
    final tooltip = offline
        ? l.storageMeterTooltipOffline
        : l.storageMeterTooltip;
    final open = widget.onOpen;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasQuota || calculating) ...[
          ShadProgress(
            key: const ValueKey<String>('storage.meter.bar'),
            value: calculating ? null : fraction,
            minHeight: large ? 8 : 4,
            color: color,
          ),
          SizedBox(height: large ? 8 : 6),
        ],
        Text(
          text,
          key: const ValueKey<String>('storage.meter.text'),
          style: large
              ? theme.textTheme.p.copyWith(
                  fontWeight: FontWeight.w600,
                  color: over ? theme.colorScheme.destructive : null,
                )
              : theme.textTheme.muted.copyWith(
                  fontSize: 12,
                  color: over ? theme.colorScheme.destructive : null,
                ),
        ),
      ],
    );
    final semantics = calculating || !hasQuota
        ? text
        : l.storageMeterValue(text, (u.usedFraction * 100).round());
    Widget meter = Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: large ? 0 : 6),
      decoration: BoxDecoration(
        color: open != null && _hover ? theme.colorScheme.accent : null,
        border: _focus
            ? Border.all(color: theme.colorScheme.ring, width: 2)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: body,
    );
    if (open != null) {
      meter = FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              open();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: meter,
        ),
      );
    }
    return Semantics(
      key: const ValueKey<String>('storage.meter'),
      container: true,
      button: open != null,
      focusable: open != null,
      onTap: open,
      label: l.navStorage,
      value: semantics,
      hint: tooltip,
      excludeSemantics: true,
      child: ShadTooltip(builder: (_) => Text(tooltip), child: meter),
    );
  }
}
