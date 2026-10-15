import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart'
    show CommandResult, InvocationSource;

import '../l10n/wonky_app_localizations.dart';
import '../shell/form_dialog.dart';
import '../shell/shell_services.dart';
import 'storage_format.dart';

/// The `reason` values of `QuotaExceededDetails` (Drive 03 §7.1; the
/// server's `QuotaReason`).
abstract final class QuotaReasons {
  static const upload = 'upload';
  static const image = 'image';
  static const import = 'import';
  static const convert = 'convert';
  static const copy = 'copy';
  static const template = 'template';
  static const transfer = 'transfer';
  static const restoreVersionCopy = 'restoreVersionCopy';
}

/// Why a byte-adding action can't run: one variant of the *Out of storage*
/// dialog (Drive 03 §6.3).
sealed class QuotaProblem {
  const QuotaProblem();
}

/// "You're out of storage": the user's own quota.
class OwnQuotaProblem extends QuotaProblem {
  const OwnQuotaProblem({
    required this.neededBytes,
    required this.availableBytes,
    required this.quotaBytes,
  });

  /// Null when unknown (the body then only says what is left).
  final int? neededBytes;
  final int availableBytes;
  final int quotaBytes;
}

/// "Anna Berg is out of storage": content added to someone else's item
/// counts against its owner.
class OwnerQuotaProblem extends QuotaProblem {
  const OwnerQuotaProblem({
    required this.ownerName,
    this.itemKind,
    this.reason = QuotaReasons.image,
  });

  final String ownerName;

  /// The kind of the item ("this document" / "this spreadsheet" / …).
  final DriveItemKind? itemKind;
  final String reason;
}

/// "Not enough storage for all files": a batch upload where only some
/// files fit.
class BatchQuotaProblem extends QuotaProblem {
  const BatchQuotaProblem({
    required this.fileCount,
    required this.neededBytes,
    required this.availableBytes,
  });

  final int fileCount;
  final int neededBytes;
  final int availableBytes;
}

/// "Bo Chen doesn't have enough storage": an ownership transfer request.
class TransferQuotaProblem extends QuotaProblem {
  const TransferQuotaProblem({
    required this.newOwnerName,
    required this.neededBytes,
    this.itemName,
  });

  final String newOwnerName;
  final int neededBytes;
  final String? itemName;
}

/// "You don't have enough storage": accepting an ownership transfer.
class TransferAcceptQuotaProblem extends QuotaProblem {
  const TransferAcceptQuotaProblem({
    required this.neededBytes,
    required this.availableBytes,
    this.itemName,
  });

  final int neededBytes;
  final int availableBytes;
  final String? itemName;
}

/// "This file is too large": [maxBytes] is the configured cap, or the room
/// left when [byQuota].
class FileTooLargeProblem extends QuotaProblem {
  const FileTooLargeProblem({required this.maxBytes, this.byQuota = false});

  final int maxBytes;
  final bool byQuota;
}

/// What the user chose in the *Out of storage* dialog.
enum QuotaDialogChoice {
  /// *Manage storage* (the Storage page is opened by [showQuotaDialog]).
  manage,

  /// *Upload the files that fit* (batch variant).
  uploadFitting,

  /// *Close*, *Cancel*, Esc.
  close,
}

/// The *Out of storage* dialog (Drive 03 §6.3): a `ShadDialog.alert` built
/// from a [WonkyDialogSpec], so the MCP UI bridge can read and press it
/// (`dialog.quota`; buttons `manage`, `fit`, `close`/`cancel`).
abstract final class QuotaExceededDialog {
  static const dialogKey = 'dialog.quota';

  /// The dialog of [problem] in [l].
  static WonkyDialogSpec spec(WonkyAppLocalizations l, QuotaProblem problem) {
    final manage = DialogButtonSpec(
      id: 'manage',
      label: l.cmdManageStorage,
      primary: true,
      validates: false,
    );
    final close = DialogButtonSpec(
      id: 'close',
      label: l.actionClose,
      validates: false,
    );
    WonkyDialogSpec of(
      String title,
      String body,
      List<DialogButtonSpec> buttons, {
      String cancelId = 'close',
      double width = 420,
    }) => WonkyDialogSpec(
      title: title,
      description: body,
      buttons: buttons,
      cancelId: cancelId,
      dialogKey: dialogKey,
      alert: true,
      width: width,
    );
    switch (problem) {
      case OwnQuotaProblem(:final neededBytes, :final availableBytes):
        return of(
          l.quotaOwnTitle,
          neededBytes == null
              ? l.quotaOwnBodyUnknown(
                  storageBytes(availableBytes),
                  storageQuota(problem.quotaBytes),
                )
              : l.quotaOwnBody(
                  storageBytes(neededBytes),
                  storageBytes(availableBytes),
                  storageQuota(problem.quotaBytes),
                ),
          [close, manage],
        );
      case OwnerQuotaProblem(:final ownerName, :final itemKind):
        return of(
          l.quotaOwnerTitle(ownerName),
          problem.reason == QuotaReasons.image
              ? l.quotaOwnerImageBody(_kindName(itemKind), ownerName)
              : l.quotaOwnerBody(ownerName),
          [close.primaryButton],
        );
      case BatchQuotaProblem():
        return of(
          l.quotaBatchTitle,
          l.quotaBatchBody(
            problem.fileCount,
            storageBytes(problem.neededBytes),
            storageBytes(problem.availableBytes),
          ),
          [
            DialogButtonSpec(
              id: 'cancel',
              label: l.actionCancel,
              validates: false,
            ),
            DialogButtonSpec(
              id: 'manage',
              label: l.cmdManageStorage,
              validates: false,
            ),
            DialogButtonSpec(
              id: 'fit',
              label: l.quotaBatchFit,
              primary: true,
              validates: false,
            ),
          ],
          cancelId: 'cancel',
          // Three buttons side by side.
          width: 480,
        );
      case TransferQuotaProblem(:final newOwnerName):
        return of(
          l.quotaTransferTitle(newOwnerName),
          l.quotaTransferBody(
            newOwnerName,
            storageBytes(problem.neededBytes),
            problem.itemName ?? l.quotaItemFallback,
          ),
          [close.primaryButton],
        );
      case TransferAcceptQuotaProblem():
        return of(
          l.quotaTransferAcceptTitle,
          l.quotaTransferAcceptBody(
            problem.itemName ?? l.quotaItemFallback,
            storageBytes(problem.neededBytes),
            storageBytes(problem.availableBytes),
          ),
          [close, manage],
        );
      case FileTooLargeProblem(:final maxBytes, :final byQuota):
        return of(
          l.quotaTooLargeTitle,
          byQuota
              ? l.quotaTooLargeNowBody(storageBytes(maxBytes))
              : l.quotaTooLargeBody(storageQuota(maxBytes)),
          [close.primaryButton],
        );
    }
  }

  static String _kindName(DriveItemKind? kind) => switch (kind) {
    DriveItemKind.spreadsheet => 'spreadsheet',
    DriveItemKind.presentation => 'presentation',
    _ => 'document',
  };
}

extension on DialogButtonSpec {
  DialogButtonSpec get primaryButton =>
      DialogButtonSpec(id: id, label: label, primary: true, validates: false);
}

/// Shows the *Out of storage* dialog for [problem]; *Manage storage* runs
/// `shell.storage.open` (Drive's Storage page, cross-app from the other
/// homes) after the dialog closes.
Future<QuotaDialogChoice> showQuotaDialog(
  BuildContext context,
  ShellServices services,
  QuotaProblem problem,
) async {
  final l = WonkyAppLocalizations.of(context);
  final r = await showWonkyFormDialog(
    context,
    QuotaExceededDialog.spec(l, problem),
  );
  switch (r?.buttonId) {
    case 'manage':
      await services.dispatcher
          .invoke('shell.storage.open', source: InvocationSource.ui)
          .catchError((Object e) {
            debugPrint('Opening the Storage page failed: $e');
            return const CommandResult.failed('error');
          });
      return QuotaDialogChoice.manage;
    case 'fit':
      return QuotaDialogChoice.uploadFitting;
    default:
      return QuotaDialogChoice.close;
  }
}
