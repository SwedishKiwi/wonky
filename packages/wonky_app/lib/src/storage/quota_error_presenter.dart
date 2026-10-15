import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';

import '../commands/command_dispatcher.dart';
import '../shell/shell_services.dart';
import 'quota_dialog.dart';

/// Maps `quotaExceeded` errors from any endpoint to the *Out of storage*
/// dialog (Drive 03 §6.3, §7.1).
///
/// - Commands: [attach] (done by `ShellServices`) listens to every command
///   invocation; a human-invoked command that fails with `quotaExceeded`
///   shows the dialog. Menus, the palette and shortcuts skip their error
///   toast for these errors ([isQuotaExceeded]). Agent invocations (MCP, AI,
///   scripts) get the error only (the assistant explains it, Drive 03 §6.6).
/// - Other code (background uploads, import handlers) calls [present] in its
///   `catch` and skips its own error message when it returns true.
///
/// Each error object is shown once (a nested command reports the same error
/// twice).
class QuotaErrorPresenter {
  QuotaErrorPresenter(this.services);

  final ShellServices services;
  StreamSubscription<CommandInvoked>? _sub;
  Object? _lastShown;

  /// Whether [error] is a `quotaExceeded` refusal.
  static bool isQuotaExceeded(Object? error) =>
      error is WonkyException && error.code == WonkyErrorCode.quotaExceeded;

  /// The details of a `quotaExceeded` [error] (null for other errors or a
  /// missing/invalid `detailsJson`).
  static QuotaExceededDetails? detailsOf(Object? error) {
    if (!isQuotaExceeded(error)) return null;
    final json = (error as WonkyException).detailsJson;
    if (json == null) return null;
    try {
      return QuotaExceededDetails.fromJson(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// The dialog variant of [error], or null when it isn't `quotaExceeded`.
  /// [itemKind] / [itemName] describe the item the action targeted (default:
  /// the open item); [reason] overrides the server's reason (e.g. `image`
  /// for a `drive.checkRoom` pre-check of an image insert).
  QuotaProblem? problemOf(
    Object error, {
    DriveItemKind? itemKind,
    String? itemName,
    String? reason,
  }) {
    if (!isQuotaExceeded(error)) return null;
    final d = detailsOf(error);
    final open = services.currentItem.value;
    if (d == null) {
      final u = services.storage.value;
      return OwnQuotaProblem(
        neededBytes: null,
        availableBytes: u?.availableBytes ?? 0,
        quotaBytes: u?.quotaBytes ?? 50 * 1024 * 1024,
      );
    }
    final why = reason ?? d.reason;
    if (why == QuotaReasons.transfer) {
      return d.isCaller
          ? TransferAcceptQuotaProblem(
              neededBytes: d.neededBytes,
              availableBytes: d.availableBytes,
              itemName: itemName ?? open?.name,
            )
          : TransferQuotaProblem(
              newOwnerName: d.chargedUserName,
              neededBytes: d.neededBytes,
              itemName: itemName ?? open?.name,
            );
    }
    if (!d.isCaller) {
      return OwnerQuotaProblem(
        ownerName: d.chargedUserName,
        itemKind: itemKind ?? open?.kind,
        reason: why,
      );
    }
    return OwnQuotaProblem(
      neededBytes: d.neededBytes,
      availableBytes: d.availableBytes,
      quotaBytes: d.quotaBytes,
    );
  }

  /// Shows the dialog when [error] is `quotaExceeded` and returns true
  /// (handled: skip your own error toast); false for other errors. The
  /// dialog opens without waiting; use [show] to await the choice.
  bool present(
    Object error, {
    BuildContext? context,
    DriveItemKind? itemKind,
    String? itemName,
    String? reason,
  }) {
    final problem = problemOf(
      error,
      itemKind: itemKind,
      itemName: itemName,
      reason: reason,
    );
    if (problem == null) return false;
    if (identical(error, _lastShown)) return true;
    _lastShown = error;
    unawaited(show(problem, context: context));
    return true;
  }

  /// Shows the dialog of [problem]; null when there is no navigator (e.g.
  /// in command tests).
  Future<QuotaDialogChoice?> show(
    QuotaProblem problem, {
    BuildContext? context,
  }) async {
    final c = (context != null && context.mounted)
        ? context
        : services.navigatorContext;
    if (c == null || !c.mounted) return null;
    return showQuotaDialog(c, services, problem);
  }

  /// Presents the `quotaExceeded` errors of human-invoked commands.
  void attach() {
    _sub ??= services.dispatcher.events.listen((e) {
      final error = e.error;
      if (error == null || e.source.isAgent) return;
      present(error);
    });
  }

  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
  }
}
