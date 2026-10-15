import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import '../features/preview/file_preview_controller.dart';
import '../features/preview/preview_commands.dart' show filePreviewPath;
import '../features/preview/preview_content.dart';
import '../features/preview/preview_host.dart';
import '../features/storage/storage_controller.dart';
import '../features/uploads/upload_host.dart';
import '../features/uploads/upload_task.dart';

/// Wonky Drive's UI-bridge tools (`ui.drive.*`, Drive 04 §13, definitions
/// in `wonky_core`'s `UiDriveTools`), executed in the live Drive window.
/// Actions stay commands (`ui.invoke_command` with `drive.*` / `shell.*`);
/// these tools read window state that isn't a command and select items.
abstract final class UiDriveToolHandlers {
  static Map<String, UiToolHandler> all(ShellServices services) => {
    'ui.drive.get_selection': getSelection,
    'ui.drive.select_items': selectItems,
    'ui.drive.get_upload_queue': getUploadQueue,
    'ui.drive.open_preview': openPreview,
    'ui.drive.get_preview_state': getPreviewState,
  };

  static Map<String, Object?> itemJson(DriveItemView i) => {
    'uuid': i.uuid.uuid,
    'name': i.name,
    'kind': i.kind.name,
    'file_category': i.fileCategory?.name,
    'size_bytes': i.countedBytes,
    'trashed': i.isTrashed,
  };

  static String _viewOf(DriveLocationKind k) => switch (k) {
    DriveLocationKind.home => 'home',
    DriveLocationKind.myDrive => 'my_drive',
    DriveLocationKind.folder => 'folder',
    DriveLocationKind.shared => 'shared',
    DriveLocationKind.starred => 'starred',
    DriveLocationKind.recent => 'recent',
    DriveLocationKind.offline => 'offline',
    DriveLocationKind.trash => 'trash',
    DriveLocationKind.search => 'search',
  };

  /// `ui.drive.get_selection`: the view (a drive location, `storage` or
  /// `preview`), the current folder and the selected items.
  static Future<UiToolResult> getSelection(
    UiToolContext ctx,
    Map<String, Object?> args,
  ) async {
    final s = ctx.services;
    final storage = StorageHost.of(s).page.value;
    final preview = FilePreviewHost.of(s).active.value;
    final list = s.driveView.value;
    final Map<String, Object?> result;
    if (storage != null) {
      result = {
        'view': 'storage',
        'filter': storage.filter.name,
        'folder': null,
        'items': [for (final i in storage.selection) itemJson(i)],
        'listed': storage.items.length,
      };
    } else if (preview != null) {
      final item = preview.item;
      result = {
        'view': 'preview',
        'folder': null,
        'items': [if (item != null) itemJson(item)],
      };
    } else if (list != null) {
      final folder = list.folder;
      result = {
        'view': _viewOf(list.location.kind),
        if (list.location.query != null) 'query': list.location.query,
        'folder': folder == null
            ? null
            : {
                'uuid': folder.uuid.uuid,
                'name': folder.name,
                'path': [for (final p in list.path) p.name],
              },
        'items': [for (final i in list.selection) itemJson(i)],
        'listed': list.items.length,
      };
    } else {
      result = {
        'view': null,
        'folder': null,
        'items': [for (final i in s.driveSelection.value) itemJson(i)],
      };
    }
    final n = (result['items']! as List).length;
    return UiToolResult(result, text: '$n selected');
  }

  /// `ui.drive.select_items {uuids}`: replaces the selection of the shown
  /// list (drive view or Storage page) and focuses the first item.
  static Future<UiToolResult> selectItems(
    UiToolContext ctx,
    Map<String, Object?> args,
  ) async {
    final s = ctx.services;
    final raw = args['uuids'];
    if (raw is! List) {
      throw const UiToolException('invalid_argument', 'uuids is required.');
    }
    final uuids = [for (final u in raw) '$u'];
    final storage = StorageHost.of(s).page.value;
    final list = s.driveView.value;
    final List<String> notFound;
    final List<DriveItemView> selected;
    if (storage != null) {
      notFound = storage.selectIds(uuids);
      selected = storage.selection;
    } else if (list != null) {
      final listed = {for (final i in list.items) i.uuid.uuid};
      final found = [
        for (final u in uuids)
          if (listed.contains(u)) u,
      ];
      list.selectIds(found, focus: found.firstOrNull);
      notFound = [
        for (final u in uuids)
          if (!listed.contains(u)) u,
      ];
      selected = list.selection;
    } else {
      throw const UiToolException(
        'unavailable',
        'No item list is shown. Navigate to a Drive view or the Storage page '
            'first (ui.navigate).',
      );
    }
    await uiSettle();
    return UiToolResult({
      'selected': [for (final i in selected) itemJson(i)],
      'not_found': notFound,
    }, text: '${selected.length} selected');
  }

  static String _state(UploadStatus st) => switch (st) {
    UploadStatus.queued => 'queued',
    UploadStatus.waitingForNetwork => 'waitingForNetwork',
    UploadStatus.starting => 'starting',
    UploadStatus.uploading => 'uploading',
    UploadStatus.verifying => 'verifying',
    UploadStatus.done => 'done',
    UploadStatus.failed => 'failed',
    UploadStatus.cancelled => 'cancelled',
  };

  /// `ui.drive.get_upload_queue`: every upload of the panel with totals.
  static Future<UiToolResult> getUploadQueue(
    UiToolContext ctx,
    Map<String, Object?> args,
  ) async {
    final host = UploadHost.of(ctx.services);
    final q = host.queue.value;
    final tasks = q?.tasks ?? const <UploadTask>[];
    return UiToolResult({
      'available': q != null,
      'panel_visible': host.panelVisible.value,
      'uploads': [
        for (final t in tasks)
          {
            'upload_id': t.id,
            'item_uuid': (t.result?.uuid ?? t.itemUuid).uuid,
            'name': t.fileName,
            'size_bytes': t.sizeBytes,
            'state': _state(t.status),
            'sent_bytes': t.status == UploadStatus.done
                ? t.sizeBytes
                : t.bytesSent,
            'parent_uuid': t.parentUuid?.uuid,
            'error': ?t.failure?.name,
            'message': ?t.error,
            if (t.result case final r? when r.kind != DriveItemKind.file)
              'converted_to': r.kind.name,
          },
      ],
      'totals': {
        'count': tasks.length,
        'active': q?.activeCount ?? 0,
        'done': q?.doneCount ?? 0,
        'failed': q?.failedCount ?? 0,
        'progress': q == null ? 0 : (q.batchProgress * 100).round(),
      },
    }, text: '${tasks.length} uploads');
  }

  /// `ui.drive.open_preview {uuid}`: opens `/file/<uuid>` in this window.
  static Future<UiToolResult> openPreview(
    UiToolContext ctx,
    Map<String, Object?> args,
  ) async {
    final uuid = args['uuid'];
    if (uuid is! String || !_uuid.hasMatch(uuid)) {
      throw const UiToolException('invalid_argument', 'uuid is required.');
    }
    final path = filePreviewPath(uuid);
    ctx.services.router.go(path);
    await uiSettle();
    return UiToolResult({'uuid': uuid, 'route': path}, text: path);
  }

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String _viewer(FilePreviewController c) {
    if (c.phase == PreviewPhase.failed) return 'error';
    return switch (c.viewer) {
      PreviewViewer.image => 'image',
      PreviewViewer.pdf => 'pdf',
      PreviewViewer.text => 'text',
      PreviewViewer.csv => 'csv',
      PreviewViewer.unsupported => 'unsupported',
      null => c.phase.name,
    };
  }

  /// `ui.drive.get_preview_state`: viewer, page, zoom, error of the open
  /// file preview.
  static Future<UiToolResult> getPreviewState(
    UiToolContext ctx,
    Map<String, Object?> args,
  ) async {
    final c = FilePreviewHost.of(ctx.services).active.value;
    if (c == null) {
      throw const UiToolException(
        'unavailable',
        'No file preview is open (ui.drive.open_preview).',
      );
    }
    final pdf = c.viewer == PreviewViewer.pdf ? c.pdf : null;
    final viewer = _viewer(c);
    return UiToolResult({
      'uuid': c.itemUuid.uuid,
      'name': c.item?.name,
      'phase': c.phase.name,
      'type': viewer,
      'mime_type': c.type?.mimeType,
      'page': pdf == null ? null : c.pdfPage + 1,
      'page_count': pdf?.pageCount,
      'zoom': c.canZoom ? (c.effectiveZoom * 100).round() : null,
      'fit': c.canZoom ? c.zoom == null : null,
      'rotation': c.viewer == PreviewViewer.image ? c.quarterTurns * 90 : null,
      'wrap': c.viewer == PreviewViewer.text ? c.wrap : null,
      'error': c.problem?.name,
      'has_next': c.hasNext,
      'has_previous': c.hasPrevious,
    }, text: '$viewer ${c.item?.name ?? ''}'.trim());
  }
}
