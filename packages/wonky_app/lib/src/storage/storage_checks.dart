import 'package:wonky_client/wonky_client.dart';

import '../data/models_ext.dart';
import '../shell/shell_services.dart';
import 'quota_dialog.dart';
import 'quota_error_presenter.dart';
import 'storage_controller.dart';

/// Client-side quota pre-checks the apps run before byte-adding actions
/// (Drive 03 §6.3, §7.2): uploads, imports, copies and image inserts. Each
/// check shows the matching *Out of storage* dialog itself and returns
/// whether the action may go on. The server stays authoritative (its
/// `quotaExceeded` refusals go through [QuotaErrorPresenter]); checks
/// **fail open** offline, while the usage is unknown or still calculating.
///
/// Reached as `services.storageChecks`:
///
/// ```dart
/// // An image insert into the open item (charged to its owner):
/// if (!await s.storageChecks.ensureRoom(bytes.length,
///     reason: QuotaReasons.image, item: s.currentItem.value)) {
///   return const CommandResult.cancelled();
/// }
///
/// // A Drive upload of several files: the indices that may start.
/// final ok = await s.storageChecks.fittingUploads([for (final f in files) f.size]);
/// ```
class StorageChecks {
  StorageChecks(this.services);

  final ShellServices services;

  /// Fallback for `ServerLimits.maxFileUploadBytes` before `meta.getInfo`.
  static const defaultMaxFileUploadBytes = 50 * 1024 * 1024;

  /// The cap for one uploaded file (`wonky.files.maxFileUploadBytes`).
  int get maxFileUploadBytes =>
      services.serverInfo.value?.limits.maxFileUploadBytes ??
      defaultMaxFileUploadBytes;

  /// Whether [bytes] fit the user's own room as far as the client knows
  /// (no dialog; e.g. to disable *OK* of a copy dialog). True while the
  /// usage is unknown or calculating.
  bool fits(int bytes) => services.storage.value?.fits(bytes) ?? true;

  /// The pre-check of one byte-adding action of [bytes]: the known usage
  /// first (own items only), then, when [askServer] and online,
  /// `drive.checkRoom(bytes, item)` — which charges the owner of [item]
  /// (someone else's item: the owner variant of the dialog). Shows the
  /// dialog and returns false when the bytes don't fit.
  ///
  /// [reason] is a [QuotaReasons] value (`image` picks the "Images added to
  /// this document…" text of the owner variant).
  Future<bool> ensureRoom(
    int bytes, {
    String reason = QuotaReasons.upload,
    DriveItemView? item,
    bool askServer = true,
  }) async {
    if (bytes <= 0) return true;
    final owned = item == null || item.myRole.isOwner;
    final u = services.storage.value;
    if (owned && u != null && !u.fits(bytes)) {
      await services.quotaErrors.show(
        OwnQuotaProblem(
          neededBytes: bytes,
          availableBytes: u.availableBytes,
          quotaBytes: u.quotaBytes,
        ),
      );
      return false;
    }
    if (!askServer || !services.connectivity.online) return true;
    try {
      await services.storage.checkRoom(bytes, itemUuid: item?.uuid);
      return true;
    } catch (e) {
      final problem = services.quotaErrors.problemOf(
        e,
        itemKind: item?.kind,
        itemName: item?.name,
        reason: reason,
      );
      if (problem == null) return true; // Offline or failing: fail open.
      await services.quotaErrors.show(problem);
      return false;
    }
  }

  /// The pre-check of an upload of several files with [sizes] (bytes, in
  /// order): returns the indices that may start, in order.
  ///
  /// - Files above [maxFileUploadBytes] are left out (*This file is too
  ///   large*).
  /// - All the rest fit → all of them.
  /// - One file, or no file fits alone → *You're out of storage* → none.
  /// - Some fit → *Not enough storage for all files*: *Upload the files that
  ///   fit* returns the files that fit (in order, while room is left);
  ///   *Manage storage* and *Cancel* return none.
  Future<List<int>> fittingUploads(
    List<int> sizes, {
    bool askServer = true,
  }) async {
    final cap = maxFileUploadBytes;
    final candidates = [
      for (var i = 0; i < sizes.length; i++)
        if (sizes[i] <= cap) i,
    ];
    if (candidates.length < sizes.length) {
      await services.quotaErrors.show(FileTooLargeProblem(maxBytes: cap));
    }
    if (candidates.isEmpty) return const [];
    final total = candidates.fold<int>(0, (a, i) => a + sizes[i]);
    final u = services.storage.value;
    int? available;
    var quota = u?.quotaBytes ?? 50 * 1024 * 1024;
    if (u != null && !u.fits(total)) {
      available = u.availableBytes;
    } else if (askServer && services.connectivity.online) {
      try {
        await services.storage.checkRoom(total);
      } catch (e) {
        final d = QuotaErrorPresenter.detailsOf(e);
        if (d != null) {
          available = d.availableBytes;
          quota = d.quotaBytes;
        } else if (QuotaErrorPresenter.isQuotaExceeded(e)) {
          available = u?.availableBytes ?? 0;
        }
      }
    }
    if (available == null) return candidates;
    final fitting = <int>[];
    var left = available;
    for (final i in candidates) {
      if (sizes[i] <= left) {
        fitting.add(i);
        left -= sizes[i];
      }
    }
    if (candidates.length == 1 || fitting.isEmpty) {
      await services.quotaErrors.show(
        OwnQuotaProblem(
          neededBytes: total,
          availableBytes: available,
          quotaBytes: quota,
        ),
      );
      return const [];
    }
    final choice = await services.quotaErrors.show(
      BatchQuotaProblem(
        fileCount: candidates.length,
        neededBytes: total,
        availableBytes: available,
      ),
    );
    return choice == QuotaDialogChoice.uploadFitting ? fitting : const [];
  }
}
