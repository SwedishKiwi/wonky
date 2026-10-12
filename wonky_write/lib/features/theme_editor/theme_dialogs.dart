import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_write_core/wonky_write_core.dart' show ThemeIssue;

import '../themes/theme_repository.dart';

/// Rename dialog (`write.theme.rename` without a name).
Future<String?> showRenameThemeDialog(BuildContext context, String current) =>
    showTextInputDialog(
      context,
      title: 'Rename theme',
      label: 'Name',
      confirmLabel: 'Rename',
      initial: current,
      maxLength: 80,
      dialogKey: 'write.dialog.renameTheme',
      validator: (v) {
        final t = v.trim();
        if (t.isEmpty) return 'Enter a name';
        if (t.length > 80) return 'At most 80 characters';
        return null;
      },
    );

/// How to resolve a [ThemeConflict] (Write 06 §10.4).
enum ThemeConflictChoice { reload, overwrite, copy }

/// The theme was saved from another window or by someone else.
Future<ThemeConflictChoice?> showThemeConflictDialog(
  BuildContext context,
  ThemeConflict conflict,
) async {
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: 'This theme was changed elsewhere',
      description:
          '“${conflict.serverName}” was saved in another window '
          '(version ${conflict.serverVersion}) while you were editing it.',
      dialogKey: 'write.dialog.themeConflict',
      buttons: const [
        DialogButtonSpec(id: 'cancel', label: 'Cancel'),
        DialogButtonSpec(id: 'copy', label: 'Save as copy'),
        DialogButtonSpec(id: 'reload', label: 'Reload theirs'),
        DialogButtonSpec(
          id: 'overwrite',
          label: 'Overwrite',
          primary: true,
          destructive: true,
        ),
      ],
    ),
  );
  return switch (r?.buttonId) {
    'reload' => ThemeConflictChoice.reload,
    'overwrite' => ThemeConflictChoice.overwrite,
    'copy' => ThemeConflictChoice.copy,
    _ => null,
  };
}

/// What to do with unsaved theme changes when leaving the editor.
enum UnsavedThemeChoice { save, discard }

Future<UnsavedThemeChoice?> showUnsavedThemeDialog(
  BuildContext context,
  String name,
) async {
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: 'Save changes to “$name”?',
      description: 'Your changes to this theme are not saved yet.',
      dialogKey: 'write.dialog.unsavedTheme',
      buttons: const [
        DialogButtonSpec(id: 'cancel', label: 'Cancel'),
        DialogButtonSpec(id: 'discard', label: 'Discard', destructive: true),
        DialogButtonSpec(id: 'save', label: 'Save', primary: true),
      ],
    ),
  );
  return switch (r?.buttonId) {
    'save' => UnsavedThemeChoice.save,
    'discard' => UnsavedThemeChoice.discard,
    _ => null,
  };
}

/// Import report (Write 06 §10.5): errors block the import; warnings ask
/// to *Import anyway*. Returns true to import.
Future<bool> showThemeImportReport(
  BuildContext context, {
  List<ThemeIssue> errors = const [],
  List<ThemeIssue> warnings = const [],
}) async {
  String lines(List<ThemeIssue> issues) => [
    for (final i in issues.take(12))
      '• ${i.path.isEmpty ? '' : '${i.path}: '}${i.message}',
    if (issues.length > 12) '• … and ${issues.length - 12} more',
  ].join('\n');
  final blocking = errors.isNotEmpty;
  final r = await showWonkyFormDialog(
    context,
    WonkyDialogSpec(
      title: blocking ? 'This theme can’t be imported' : 'Import with changes?',
      description: blocking
          ? lines(errors)
          : 'Some values were adjusted:\n${lines(warnings)}',
      dialogKey: 'write.dialog.themeImport',
      buttons: [
        if (blocking)
          const DialogButtonSpec(id: 'cancel', label: 'OK', primary: true)
        else ...const [
          DialogButtonSpec(id: 'cancel', label: 'Cancel'),
          DialogButtonSpec(id: 'import', label: 'Import anyway', primary: true),
        ],
      ],
    ),
  );
  return r?.buttonId == 'import';
}

/// The revision history of a theme; returns the revision to load into the
/// draft.
Future<ThemeRevision?> showThemeRevisionsDialog(
  BuildContext context,
  List<ThemeRevision> revisions, {
  required int current,
}) => showShadDialog<ThemeRevision>(
  context: context,
  builder: (context) {
    final theme = ShadTheme.of(context);
    String when(DateTime d) {
      final l = d.toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      return '${l.year}-${two(l.month)}-${two(l.day)} '
          '${two(l.hour)}:${two(l.minute)}';
    }

    return ShadDialog(
      key: const ValueKey<String>('write.dialog.themeRevisions'),
      title: const Text('Theme versions'),
      description: const Text(
        'Load an earlier version into the editor. It becomes your draft; '
        'save to keep it.',
      ),
      constraints: const BoxConstraints(maxWidth: 480),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: revisions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No saved versions yet.',
                style: theme.textTheme.muted,
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in revisions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.version == current
                                        ? 'Version ${r.version} (current)'
                                        : 'Version ${r.version}',
                                    style: theme.textTheme.small.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    [
                                      when(r.createdAt),
                                      ?r.savedBy,
                                      if (r.byAgent) 'via an assistant',
                                    ].join(' · '),
                                    style: theme.textTheme.muted.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (r.version != current)
                              ShadButton.outline(
                                key: ValueKey<String>(
                                  'write.dialog.themeRevisions.load.${r.version}',
                                ),
                                size: ShadButtonSize.sm,
                                onPressed: () => Navigator.of(context).pop(r),
                                child: const Text('Load'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  },
);
