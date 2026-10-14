import 'package:flutter/foundation.dart';
import 'package:wonky_client/wonky_client.dart';

import '../shell/shell_services.dart';

/// How much an app keeps on this device (Settings › Offline & storage).
@immutable
class OfflineUsage {
  const OfflineUsage({
    this.documents = 0,
    this.pinned = 0,
    this.pendingChanges = 0,
    this.pendingUploads = 0,
    this.bytes = 0,
    this.warnings = const [],
  });

  static const empty = OfflineUsage();

  /// Files available offline.
  final int documents;

  /// Of which pinned ("Make available offline").
  final int pinned;

  /// Files with local changes that are not on the server yet.
  final int pendingChanges;

  /// Images/files waiting to be uploaded.
  final int pendingUploads;

  /// Approximate size of the local data.
  final int bytes;

  /// Limits of this device the user should know about (Sheets: "Offline
  /// storage is limited in this browser"), shown in Settings › Offline &
  /// storage.
  final List<OfflineWarning> warnings;

  OfflineUsage operator +(OfflineUsage o) => OfflineUsage(
    documents: documents + o.documents,
    pinned: pinned + o.pinned,
    pendingChanges: pendingChanges + o.pendingChanges,
    pendingUploads: pendingUploads + o.pendingUploads,
    bytes: bytes + o.bytes,
    warnings: [...warnings, ...o.warnings],
  );

  @override
  bool operator ==(Object other) =>
      other is OfflineUsage &&
      other.documents == documents &&
      other.pinned == pinned &&
      other.pendingChanges == pendingChanges &&
      other.pendingUploads == pendingUploads &&
      other.bytes == bytes &&
      listEquals(other.warnings, warnings);

  @override
  int get hashCode => Object.hash(
    documents,
    pinned,
    pendingChanges,
    pendingUploads,
    bytes,
    Object.hashAll(warnings),
  );
}

/// A storage limit of this device shown in Settings › Offline & storage.
@immutable
class OfflineWarning {
  const OfflineWarning({required this.title, this.description});

  final String title;
  final String? description;

  @override
  bool operator ==(Object other) =>
      other is OfflineWarning &&
      other.title == title &&
      other.description == description;

  @override
  int get hashCode => Object.hash(title, description);
}

/// Local data an app keeps for offline use (suite 12): Write's document
/// cache and outbox, Sheets' replicas. Registered with [OfflineStorage].
abstract class OfflineDataProvider implements Listenable {
  /// Stable id (`write`, `sheets`).
  String get id;

  /// Whether [item] can be opened right now without the server. Return
  /// null when the provider does not handle the item's kind.
  bool? isAvailableOffline(DriveItemView item);

  /// What is stored.
  OfflineUsage get usage;

  /// Deletes everything (Clear local data). Unsynced changes are lost.
  Future<void> clear();
}

/// The offline data providers of one app shell, used by the drive list
/// (dimmed unavailable items, offline badges) and Settings › Offline &
/// storage (usage, Clear local data).
class OfflineStorage extends ChangeNotifier {
  OfflineStorage._();

  static final Expando<OfflineStorage> _of = Expando('OfflineStorage');

  /// The registry of [services].
  static OfflineStorage of(ShellServices services) =>
      _of[services] ??= OfflineStorage._();

  final List<OfflineDataProvider> _providers = [];

  List<OfflineDataProvider> get providers => List.unmodifiable(_providers);

  void register(OfflineDataProvider p) {
    if (_providers.contains(p)) return;
    _providers.removeWhere((o) => o.id == p.id);
    _providers.add(p);
    p.addListener(notifyListeners);
    notifyListeners();
  }

  void unregister(OfflineDataProvider p) {
    if (!_providers.remove(p)) return;
    p.removeListener(notifyListeners);
    notifyListeners();
  }

  /// Whether [item] opens offline: folders always (the drive cache), files
  /// when a provider has them; without a provider for the kind, items
  /// pinned offline count as available.
  bool isAvailableOffline(DriveItemView item) {
    if (item.kind == DriveItemKind.folder) return true;
    for (final p in _providers) {
      final r = p.isAvailableOffline(item);
      if (r != null) return r;
    }
    return item.pinnedOffline;
  }

  OfflineUsage get usage =>
      _providers.fold(OfflineUsage.empty, (a, p) => a + p.usage);

  /// Clears every provider.
  Future<void> clearAll() async {
    for (final p in [..._providers]) {
      await p.clear();
    }
    notifyListeners();
  }
}
