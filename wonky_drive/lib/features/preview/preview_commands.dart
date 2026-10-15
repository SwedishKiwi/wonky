import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/files.dart';
import 'package:wonky_core/wonky_core.dart';

import '../../l10n/drive_l10n.dart';
import 'file_preview_controller.dart';
import 'preview_content.dart';
import 'preview_host.dart';

/// Key scope of the file preview (Drive 04 §10): active while focus is in
/// the preview, never in text fields.
const previewKeyScope = KeyScope('drivePreview');

/// The preview route of [uuid] (`DriveAppConfig.itemPath`).
String filePreviewPath(String uuid) => '/file/$uuid';

String _category(BuildContext c) => driveL10n(c).categoryPreview;

CommandResult _ok([Object? data]) => CommandResult.ok(data);

/// The file preview commands (Drive 04 §9): open, *Open with*, download,
/// prev/next, zoom, rotate, go to page, wrap, copy, close. None of them
/// changes stored state, so none is undoable.
List<Command<CommandArgs>> previewCommands(ShellServices s) {
  final host = FilePreviewHost.of(s);
  FilePreviewController? active() => host.active.value;

  bool viewerIs(PreviewViewer v) => active()?.viewer == v;

  CallbackCommand cmd(
    String id, {
    required String Function(DriveLocalizations l) title,
    required Future<CommandResult> Function(CommandContext, JsonArgs) run,
    IconData? icon,
    List<KeyBinding> bindings = const [],
    KeyScope scope = previewKeyScope,
    JsonSchema args = JsonSchema.empty,
    bool Function(CommandContext, JsonArgs)? enabled,
    bool? Function(CommandContext, JsonArgs)? checked,
    bool palette = true,
  }) => CallbackCommand(
    id: id,
    title: (c) => title(driveL10n(c)),
    run: run,
    icon: icon,
    defaultBindings: bindings,
    keyScope: scope,
    argsSchema: args,
    enabled: enabled,
    checked: checked,
    showInPalette: palette,
    category: _category,
  );

  return [
    cmd(
      'drive.file.preview',
      title: (l) => l.cmdPreviewFile,
      icon: LucideIcons.eye,
      bindings: const [KeyBinding(Keys.space)],
      scope: KeyScope.drive,
      args: const JsonSchema.object(
        properties: {
          'uuid': JsonSchema.string(
            format: 'uuid',
            description: 'File to preview; default: the selected file.',
          ),
        },
      ),
      enabled: (ctx, a) => a.string('uuid') != null || _selectedFile(s) != null,
      run: (ctx, a) async {
        final uuid = a.string('uuid') ?? _selectedFile(s)?.uuid.uuid;
        if (uuid == null) return const CommandResult.cancelled();
        s.router.go(filePreviewPath(uuid));
        return _ok({'uuid': uuid});
      },
    ),
    cmd(
      'drive.file.openWith',
      title: (l) => l.cmdOpenWith,
      icon: LucideIcons.squareArrowOutUpRight,
      scope: KeyScope.global,
      args: const JsonSchema.object(
        properties: {
          'uuid': JsonSchema.string(
            format: 'uuid',
            description: 'File to convert; default: the previewed file.',
          ),
          'app': JsonSchema.string(enumValues: ['write', 'sheets']),
        },
      ),
      enabled: (ctx, a) =>
          a.string('uuid') != null || active()?.type?.convertTarget != null,
      run: (ctx, a) async {
        final c = active();
        final uuid = a.string('uuid') ?? c?.itemUuid.uuid;
        final target = switch (a.string('app')) {
          'write' => ConvertTarget.write,
          'sheets' => ConvertTarget.sheets,
          _ => c?.type?.convertTarget,
        };
        if (uuid == null || target == null) {
          return const CommandResult.cancelled();
        }
        final app = target == ConvertTarget.write
            ? WonkyAppKind.write
            : WonkyAppKind.sheets;
        final path = Uri(
          path: '/import',
          queryParameters: {'file': uuid},
        ).toString();
        // Same tab, full page load (Drive 02 §7.2).
        await s.crossApp.open(app, path);
        return _ok({'app': app.name, 'path': path});
      },
    ),
    cmd(
      'drive.file.download',
      title: (l) => l.cmdDownloadFile,
      icon: LucideIcons.download,
      scope: KeyScope.global,
      // Drive 04 §9 (P1 binding): the open preview or the selected files.
      bindings: const [KeyBinding('D', mod: true, shift: true)],
      args: const JsonSchema.object(
        properties: {
          'uuids': JsonSchema.array(
            JsonSchema.string(format: 'uuid'),
            description:
                'Files to download; default: the open preview, '
                'else the selected files.',
          ),
        },
      ),
      enabled: (ctx, a) =>
          a.strings('uuids').isNotEmpty ||
          (active()?.canDownload ?? false) ||
          _selectedFiles(s).isNotEmpty,
      run: (ctx, a) async {
        final l = driveL10nOf(s);
        var ids = a.strings('uuids');
        if (ids.isEmpty && active() == null) {
          ids = [for (final f in _selectedFiles(s)) f.uuid.uuid];
        }
        try {
          final bool started;
          if (ids.isEmpty) {
            final c = active();
            if (c == null) return const CommandResult.cancelled();
            started = await c.download();
          } else {
            // Several files become a ZIP in P1 (Drive 02 §8); one by one.
            var all = true;
            for (final id in ids) {
              final uuid = UuidValue.fromString(id);
              final item = await host.api.item(uuid);
              if (item.kind != DriveItemKind.file) continue;
              final url = await host.api.contentUrl(uuid, download: true);
              final u = url.url;
              all =
                  u != null &&
                  await host.downloader.download(u, item.name) &&
                  all;
            }
            started = all;
          }
          if (!started) {
            s.toasts.show(l.previewDownloadUnavailable);
            return CommandResult.failed(l.previewDownloadUnavailable);
          }
          return _ok();
        } on Object catch (e) {
          s.toasts.error(l.previewDownloadFailed, description: errorMessage(e));
          return CommandResult.failed(errorMessage(e));
        }
      },
    ),
    cmd(
      'drive.preview.next',
      title: (l) => l.cmdPreviewNext,
      icon: LucideIcons.chevronRight,
      bindings: const [KeyBinding(Keys.arrowRight)],
      enabled: (ctx, a) => active()?.hasNext ?? false,
      run: (ctx, a) async => _step(s, active(), 1),
    ),
    cmd(
      'drive.preview.previous',
      title: (l) => l.cmdPreviewPrevious,
      icon: LucideIcons.chevronLeft,
      bindings: const [KeyBinding(Keys.arrowLeft)],
      enabled: (ctx, a) => active()?.hasPrevious ?? false,
      run: (ctx, a) async => _step(s, active(), -1),
    ),
    cmd(
      'drive.preview.zoomIn',
      title: (l) => l.cmdPreviewZoomIn,
      icon: LucideIcons.zoomIn,
      bindings: const [
        KeyBinding('='),
        KeyBinding('+'),
        KeyBinding('+', shift: true),
      ],
      enabled: (ctx, a) => active()?.canZoom ?? false,
      run: (ctx, a) async {
        active()!.zoomIn();
        return _ok();
      },
    ),
    cmd(
      'drive.preview.zoomOut',
      title: (l) => l.cmdPreviewZoomOut,
      icon: LucideIcons.zoomOut,
      bindings: const [KeyBinding('-')],
      enabled: (ctx, a) => active()?.canZoom ?? false,
      run: (ctx, a) async {
        active()!.zoomOut();
        return _ok();
      },
    ),
    cmd(
      'drive.preview.zoomFit',
      title: (l) => l.cmdPreviewZoomFit,
      icon: LucideIcons.minimize,
      bindings: const [KeyBinding('0')],
      enabled: (ctx, a) => active()?.canZoom ?? false,
      run: (ctx, a) async {
        active()!.zoomFit();
        return _ok();
      },
    ),
    cmd(
      'drive.preview.zoomActual',
      title: (l) => l.cmdPreviewZoomActual,
      icon: LucideIcons.scan,
      bindings: const [KeyBinding('1')],
      enabled: (ctx, a) => active()?.canZoom ?? false,
      run: (ctx, a) async {
        active()!.zoomActual();
        return _ok();
      },
    ),
    cmd(
      'drive.preview.rotate',
      title: (l) => l.cmdPreviewRotate,
      icon: LucideIcons.rotateCw,
      bindings: const [KeyBinding('R')],
      enabled: (ctx, a) => viewerIs(PreviewViewer.image),
      run: (ctx, a) async {
        active()!.rotate();
        return _ok({'quarterTurns': active()!.quarterTurns});
      },
    ),
    cmd(
      'drive.preview.toggleWrap',
      title: (l) => l.cmdPreviewToggleWrap,
      icon: LucideIcons.wrapText,
      bindings: const [KeyBinding('Z', alt: true)],
      enabled: (ctx, a) =>
          viewerIs(PreviewViewer.text) ||
          (viewerIs(PreviewViewer.csv) && !(active()?.csvAsTable ?? true)),
      checked: (ctx, a) => active()?.wrap ?? false,
      run: (ctx, a) async {
        active()!.toggleWrap();
        return _ok({'wrap': active()!.wrap});
      },
    ),
    cmd(
      'drive.preview.copyAll',
      title: (l) => l.cmdPreviewCopyAll,
      icon: LucideIcons.copy,
      enabled: (ctx, a) => active()?.text != null,
      run: (ctx, a) async {
        await active()!.copyAll();
        s.toasts.show(driveL10nOf(s).previewCopied);
        return _ok();
      },
    ),
    cmd(
      'drive.preview.close',
      title: (l) => l.cmdPreviewClose,
      icon: LucideIcons.x,
      bindings: const [KeyBinding(Keys.escape)],
      enabled: (ctx, a) => active() != null,
      run: (ctx, a) async {
        closePreview(s, active());
        return _ok();
      },
    ),
  ];
}

/// The item-menu entries of a selection of ready files (Drive 04 §3.7):
/// *Preview* and *Open with ▸ Wonky Write/Sheets* for one file, *Download* for all.
ItemMenuContribution fileItemMenu(
  BuildContext context,
  List<DriveItemView> selection,
) {
  final files =
      selection.isNotEmpty &&
      selection.every(
        (i) =>
            i.kind == DriveItemKind.file &&
            i.uploadState != FileUploadState.uploading,
      );
  if (!files) return ItemMenuContribution.none;
  final l = driveL10n(context);
  final single = selection.length == 1 ? selection.single : null;
  final target = single == null ? null : FileTypes.convertTargetOf(single.name);
  return ItemMenuContribution(
    hide: const {'shell.drive.open'},
    commands: [
      if (single != null)
        ItemMenuCommand('drive.file.preview', args: {'uuid': single.uuid.uuid}),
      if (single != null && target != null)
        ItemMenuCommand(
          'drive.file.openWith',
          args: {'uuid': single.uuid.uuid, 'app': target.name},
          label: l.previewOpenWithApp(
            target == ConvertTarget.write
                ? WonkyAppKind.write.productName
                : WonkyAppKind.sheets.productName,
          ),
        ),
      ItemMenuCommand(
        'drive.file.download',
        args: {
          'uuids': [for (final i in selection) i.uuid.uuid],
        },
      ),
    ],
  );
}

/// The selected ready files of a drive list (all of the selection, or
/// none when it holds anything else).
List<DriveItemView> _selectedFiles(ShellServices s) {
  final sel = s.driveSelection.value;
  final files = sel.every(
    (i) =>
        i.kind == DriveItemKind.file &&
        i.uploadState != FileUploadState.uploading,
  );
  return files ? sel : const [];
}

/// The single selected ready file of a drive list, if any.
DriveItemView? _selectedFile(ShellServices s) {
  final sel = s.driveSelection.value;
  if (sel.length != 1) return null;
  final i = sel.single;
  return i.kind == DriveItemKind.file &&
          i.uploadState != FileUploadState.uploading
      ? i
      : null;
}

CommandResult _step(ShellServices s, FilePreviewController? c, int delta) {
  final next = c?.neighbor(delta);
  if (next == null) return const CommandResult.cancelled();
  s.router.go(filePreviewPath(next.uuid.uuid));
  return CommandResult.ok({'uuid': next.uuid.uuid});
}

/// Leaves the preview for the location it was opened from (skipping
/// previews reached with prev/next), with the file selected (Drive 04 §6);
/// without such a location, the file's folder.
void closePreview(ShellServices s, FilePreviewController? c) {
  final item = c?.item;
  if (item != null) s.driveSelection.value = [item];
  for (var i = s.navIndex - 1; i >= 0; i--) {
    final loc = s.navHistory[i];
    if (!loc.startsWith('/file/')) {
      // Rewind the shell history to that entry in one navigation.
      s.navIndex = i + 1;
      s.goBack();
      return;
    }
  }
  // Opened by a link or after a reload: the file's folder, not the home.
  final parent = item?.parentUuid;
  s.router.go(
    parent != null
        ? '/f/${parent.uuid}'
        : item != null && item.role == AccessRole.owner
        ? '/my-drive'
        : '/',
  );
}
