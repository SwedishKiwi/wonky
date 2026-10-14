import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../l10n/sheets_l10n.dart';

/// Thrown by [IoProgress.check] after *Cancel*.
class IoCancelled implements Exception {
  const IoCancelled();
}

/// Phase text and cancellation of a running import/export.
class IoProgress {
  final ValueNotifier<String> phase = ValueNotifier('');
  final ValueNotifier<double?> value = ValueNotifier(null);
  bool cancelled = false;

  /// Throws [IoCancelled] when the user cancelled.
  void check() {
    if (cancelled) throw const IoCancelled();
  }

  /// Sets the phase and lets the dialog paint before synchronous work.
  Future<void> step(String text, [double? progress]) async {
    check();
    phase.value = text;
    value.value = progress;
    await Future<void>.delayed(const Duration(milliseconds: 32));
    check();
  }
}

/// Runs [work] behind a modal progress dialog titled [title] (11 §3.2:
/// progress with Cancel). Returns null when cancelled.
Future<T?> runWithProgress<T>(
  BuildContext context, {
  required String title,
  required Future<T> Function(IoProgress progress) work,
  bool cancellable = true,
}) async {
  final progress = IoProgress();
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  unawaited(
    showShadDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProgressDialog(
        title: title,
        progress: progress,
        onCancel: cancellable
            ? () {
                progress.cancelled = true;
                if (open) {
                  open = false;
                  nav.pop();
                }
              }
            : null,
      ),
    ).whenComplete(() => open = false),
  );
  try {
    await Future<void>.delayed(const Duration(milliseconds: 32));
    return await work(progress);
  } on IoCancelled {
    return null;
  } finally {
    if (open) {
      open = false;
      nav.pop();
    }
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({
    required this.title,
    required this.progress,
    this.onCancel,
  });

  final String title;
  final IoProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l = sheetsL10n(context);
    final theme = ShadTheme.of(context);
    return ShadDialog(
      key: const ValueKey<String>('dialog.ioProgress'),
      closeIcon: const SizedBox.shrink(),
      title: Text(title),
      actions: [
        if (onCancel != null)
          ShadButton.outline(
            key: const ValueKey<String>('dialog.ioProgress.cancel'),
            onPressed: onCancel,
            child: Text(l.importCancel),
          ),
      ],
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: progress.phase,
              builder: (context, p, _) => Semantics(
                liveRegion: true,
                child: Text(p, style: theme.textTheme.muted),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<double?>(
              valueListenable: progress.value,
              builder: (context, v, _) => ShadProgress(value: v),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [e] as an error toast titled [title].
void showIoError(ShellServices s, String title, Object e) =>
    s.toasts.error(title, description: errorMessage(e));
