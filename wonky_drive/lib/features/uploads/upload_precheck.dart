import 'package:wonky_client/wonky_client.dart';

import 'upload_queue.dart';

/// Most files in one upload batch (Drive 02 §3.1).
const maxUploadBatchFiles = 500;

/// Default of `ServerLimits.maxFileUploadBytes` (50 MB).
const defaultMaxFileUploadBytes = 50 * 1024 * 1024;

/// Default quota (50 MB) for dialog texts while the usage is unknown.
const defaultQuotaBytes = 50 * 1024 * 1024;

/// The client pre-checks of a batch (Drive 02 §3.2): size, quota, names.
/// The server stays authoritative.
class UploadPlan {
  UploadPlan._({
    required this.files,
    required this.tooLarge,
    required this.neededBytes,
    required this.availableBytes,
    required this.fitting,
    required this.conflicts,
  });

  /// Checks [files] against [maxFileBytes], the cached [usage] minus the
  /// bytes of uploads still waiting to reach the server ([pendingBytes]),
  /// and the lower-case names in the target folder ([existingNames]).
  /// [availableBytes] (the server's answer) replaces the cached usage.
  factory UploadPlan.of(
    List<UploadFile> files, {
    required int maxFileBytes,
    StorageUsage? usage,
    int pendingBytes = 0,
    int? availableBytes,
    Set<String> existingNames = const {},
  }) {
    final ok = <UploadFile>[];
    final tooLarge = <UploadFile>[];
    for (final f in files) {
      (f.size > maxFileBytes ? tooLarge : ok).add(f);
    }
    final needed = ok.fold<int>(0, (a, f) => a + f.size);
    // While the server is still calculating, enforcement fails open
    // (Drive 03 §9): no client refusal either.
    final int? available =
        availableBytes ??
        (usage == null || usage.calculating
            ? null
            : usage.availableBytes - pendingBytes);
    final fitting = available == null || needed <= available
        ? ok
        : filesThatFit(ok, available);
    return UploadPlan._(
      files: ok,
      tooLarge: tooLarge,
      neededBytes: needed,
      availableBytes: available == null
          ? null
          : (available < 0 ? 0 : available),
      fitting: fitting,
      conflicts: [
        for (final f in ok)
          if (existingNames.contains(f.name.toLowerCase())) f,
      ],
    );
  }

  /// The files within the size limit, in the user's order.
  final List<UploadFile> files;

  /// Files over the size limit (shown as failed rows in the panel).
  final List<UploadFile> tooLarge;

  /// Bytes of [files].
  final int neededBytes;

  /// What is left of the quota (null = unknown or still calculating).
  final int? availableBytes;

  /// The files that fit the quota (all of [files] when they all fit).
  final List<UploadFile> fitting;

  /// Files whose name already exists in the target folder.
  final List<UploadFile> conflicts;

  bool get fitsQuota => fitting.length == files.length;
}

/// The files of [files] that fit into [available] bytes: smallest first,
/// returned in the user's order (Drive 02 §3.2, *Upload the files that
/// fit*).
List<UploadFile> filesThatFit(List<UploadFile> files, int available) {
  final bySize = [...files.indexed]
    ..sort((a, b) {
      final c = a.$2.size.compareTo(b.$2.size);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  var left = available;
  final keep = <int>{};
  for (final (i, f) in bySize) {
    if (f.size > left) break;
    left -= f.size;
    keep.add(i);
  }
  return [
    for (final (i, f) in files.indexed)
      if (keep.contains(i)) f,
  ];
}
