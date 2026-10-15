import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/drive_l10n.dart';
import 'storage_controller.dart';

/// Colors of the usage bar: the kind colors of the drive icons (documents
/// blue, spreadsheets green, presentations amber), files violet (the image
/// category color), trash muted (Drive 03 §6.4).
abstract final class StorageColors {
  static Color files(Brightness b) =>
      b == Brightness.dark ? const Color(0xffa78bfa) : const Color(0xff7c3aed);

  static Color trash(ShadColorScheme c) => c.mutedForeground;
}

/// The Storage page's headline: "46.1 MB of 50 MB used", the share of the
/// quota, and the usage by kind as a stacked bar with legend (Drive 03
/// §6.4). Over quota the bar is full in `destructive` with "Over by …";
/// while the backfill calculates, the shell's meter shows "Calculating
/// storage…".
class StorageUsageSummary extends StatelessWidget {
  const StorageUsageSummary({super.key, required this.services});

  final ShellServices services;

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final la = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    return ValueListenableBuilder<StorageUsage?>(
      valueListenable: services.storage,
      builder: (context, u, _) {
        if (u == null) {
          return Text(
            la.settingsStorageUnavailable,
            key: const ValueKey<String>('storage.usage.unavailable'),
            style: theme.textTheme.muted,
          );
        }
        if (u.calculating) {
          return KeyedSubtree(
            key: const ValueKey<String>('storage.usage.calculating'),
            child: StorageMeter(services: services, large: true),
          );
        }
        final used = storageBytes(u.bytesUsed);
        final quota = storageQuota(u.quotaBytes);
        final over = u.bytesUsed > u.quotaBytes;
        final percent = u.quotaBytes <= 0
            ? 0
            : (u.bytesUsed * 100 / u.quotaBytes).floor();
        final free = u.quotaBytes - u.bytesUsed - u.reservedBytes;
        final kinds = [
          (
            'documents',
            la.settingsStorageDocuments,
            u.documentsBytes,
            kindColor(DriveItemKind.document, c),
          ),
          (
            'spreadsheets',
            la.settingsStorageSpreadsheets,
            u.spreadsheetsBytes,
            kindColor(DriveItemKind.spreadsheet, c),
          ),
          (
            'presentations',
            la.settingsStoragePresentations,
            u.presentationsBytes,
            kindColor(DriveItemKind.presentation, c),
          ),
          (
            'files',
            la.settingsStorageFiles,
            u.filesBytes,
            StorageColors.files(theme.brightness),
          ),
          (
            'trash',
            la.settingsStorageTrash,
            u.trashBytes,
            StorageColors.trash(c),
          ),
        ];
        final segments = [
          if (over)
            WonkyStackedBarSegment(
              label: la.storageUsedOfOver(used, quota),
              value: 1,
              color: c.destructive,
              inLegend: false,
            ),
          for (final (id, label, bytes, color) in kinds)
            WonkyStackedBarSegment(
              id: id,
              label: label,
              value: bytes.toDouble(),
              valueLabel: storageBytes(bytes),
              color: color,
              inBar: !over,
            ),
          if (!over)
            WonkyStackedBarSegment(
              id: 'free',
              label: l.storageLegendFree,
              value: free.toDouble(),
              valueLabel: storageBytes(free < 0 ? 0 : free),
              color: c.secondary,
              hollow: true,
              inBar: false,
            ),
        ];
        final headline = Text(
          over
              ? la.storageUsedOfOver(used, quota)
              : la.storageUsedOf(used, quota),
          key: const ValueKey<String>('storage.usage.headline'),
          style: theme.textTheme.h4.copyWith(
            color: over ? c.destructive : null,
          ),
        );
        final side = Text(
          over
              ? l.storageOverBy(storageBytes(u.bytesUsed - u.quotaBytes))
              : l.storagePercent(percent),
          key: const ValueKey<String>('storage.usage.percent'),
          style: theme.textTheme.muted.copyWith(
            color: over ? c.destructive : null,
            fontWeight: FontWeight.w500,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 16,
              runSpacing: 4,
              children: [headline, side],
            ),
            const SizedBox(height: 12),
            WonkyStackedBar(
              key: const ValueKey<String>('storage.usage.bar'),
              keyPrefix: 'storage.legend',
              total: over ? 1 : u.quotaBytes.toDouble(),
              segments: segments,
              semanticLabel: [
                over
                    ? la.storageUsedOfOver(used, quota)
                    : la.storageUsedOf(used, quota),
                l.storageBreakdownLabel,
                for (final s in segments)
                  if (s.inLegend) s.legendText,
              ].join(', '),
            ),
          ],
        );
      },
    );
  }
}

/// *Free up space* (Drive 03 §6.4): *Empty trash* (when the trash holds
/// bytes), *Large files* and *Not opened in 6 months* (when they match
/// anything); *Review* filters the table.
class StorageSuggestions extends StatelessWidget {
  const StorageSuggestions({
    super.key,
    required this.services,
    required this.controller,
    required this.onEmptyTrash,
    required this.onReview,
  });

  final ShellServices services;
  final StoragePageController controller;
  final VoidCallback onEmptyTrash;
  final ValueChanged<StorageFilter> onReview;

  @override
  Widget build(BuildContext context) {
    final l = driveL10n(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, services.storage]),
      builder: (context, _) {
        final trash = services.storage.value?.trashBytes ?? 0;
        final large = controller.large;
        final notOpened = controller.notOpened;
        String countText(
          StorageSuggestion s,
          String Function(StorageSuggestion s) text,
        ) => s.more ? l.storageCardMore(s.count) : text(s);
        final cards = <Widget>[
          if (trash > 0)
            _SuggestionCard(
              id: 'emptyTrash',
              icon: LucideIcons.trash2,
              title: l.storageEmptyTrash,
              body: l.storageCardTrashBody(storageBytes(trash)),
              action: l.storageEmptyTrash,
              onPressed: onEmptyTrash,
            ),
          if (large != null && large.count > 0)
            _SuggestionCard(
              id: 'large',
              icon: LucideIcons.fileStack,
              title: l.storageCardLargeTitle,
              body: countText(large, (s) => l.storageCardLargeBody(s.count)),
              action: l.storageCardReview,
              onPressed: () => onReview(StorageFilter.large),
            ),
          if (notOpened != null && notOpened.count > 0)
            _SuggestionCard(
              id: 'notOpened',
              icon: LucideIcons.clock,
              title: l.storageCardNotOpenedTitle,
              body: countText(
                notOpened,
                (s) =>
                    l.storageCardNotOpenedBody(s.count, storageBytes(s.bytes)),
              ),
              action: l.storageCardReview,
              onPressed: () => onReview(StorageFilter.notOpened),
            ),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l.storageFreeUpTitle, style: theme.textTheme.large),
            ),
            const SizedBox(height: 10),
            if (cards.isEmpty)
              Text(
                l.storageNothingToFree,
                key: const ValueKey<String>('storage.suggestions.none'),
                style: theme.textTheme.muted,
              )
            else
              LayoutBuilder(
                builder: (context, box) {
                  const gap = 12.0;
                  final columns = box.maxWidth >= 720
                      ? 3
                      : box.maxWidth >= 460
                      ? 2
                      : 1;
                  final width = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final c in cards) SizedBox(width: width, child: c),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });

  final String id;
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final c = theme.colorScheme;
    return Container(
      key: ValueKey<String>('storage.suggestion.$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.small,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: theme.textTheme.muted),
          const SizedBox(height: 10),
          ShadButton.outline(
            key: ValueKey<String>('storage.suggestion.$id.action'),
            size: ShadButtonSize.sm,
            onPressed: onPressed,
            child: Text(action, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
