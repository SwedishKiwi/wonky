import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart';

const _uuid = '0192a3b4-c5d6-7e8f-9a0b-1c2d3e4f5a6b';

void main() {
  group('Given the (v2) drive file tools', () {
    test('when listing the drive tools then every file tool is defined', () {
      final names = DriveTools.all.map((t) => t.name).toSet();

      expect(
        names,
        containsAll([
          'drive.upload_file',
          'drive.create_upload',
          'drive.complete_upload',
          'drive.download_file',
          'drive.convert_file',
          'drive.get_storage',
        ]),
      );
      expect(names.length, DriveTools.all.length);
    });

    test('when checking scopes then reads need drive:read and writes '
        'drive:write', () {
      expect(DriveTools.downloadFile.scopes, {McpScope.driveRead});
      expect(DriveTools.getStorage.scopes, {McpScope.driveRead});
      for (final t in [
        DriveTools.uploadFile,
        DriveTools.createUpload,
        DriveTools.completeUpload,
        DriveTools.convertFile,
      ]) {
        expect(t.scopes, {McpScope.driveWrite}, reason: t.name);
        expect(t.annotations.readOnly, isFalse, reason: t.name);
      }
      expect(DriveTools.downloadFile.annotations.readOnly, isTrue);
    });

    test('when validating upload_file args then a name is required and '
        'content is free-form', () {
      final s = DriveTools.uploadFile.inputSchema;

      expect(s.accepts({'name': 'a.txt', 'text': 'hi'}), isTrue);
      expect(
        s.accepts({
          'name': 'a.png',
          'content_base64': 'iVBORw0=',
          'mime_type': 'image/png',
          'parent_uuid': _uuid,
        }),
        isTrue,
      );
      expect(s.accepts({'text': 'hi'}), isFalse);
      expect(s.accepts({'name': '', 'text': 'hi'}), isFalse);
      expect(s.accepts({'name': 'a', 'bogus': 1}), isFalse);
    });

    test('when validating create_upload args then the size is a '
        'non-negative integer', () {
      final s = DriveTools.createUpload.inputSchema;

      expect(s.accepts({'name': 'big.zip', 'size_bytes': 0}), isTrue);
      expect(s.accepts({'name': 'big.zip', 'size_bytes': 20000000}), isTrue);
      expect(s.accepts({'name': 'big.zip', 'size_bytes': -1}), isFalse);
      expect(s.accepts({'name': 'big.zip'}), isFalse);
      expect(s.accepts({'name': 'big.zip', 'size_bytes': 1.5}), isFalse);
    });

    test('when validating download and convert args then the enums are '
        'enforced', () {
      final d = DriveTools.downloadFile.inputSchema;
      final c = DriveTools.convertFile.inputSchema;

      expect(d.accepts({'uuid': _uuid}), isTrue);
      expect(d.accepts({'uuid': _uuid, 'as': 'url'}), isTrue);
      expect(d.accepts({'uuid': _uuid, 'as': 'pdf'}), isFalse);
      expect(c.accepts({'uuid': _uuid, 'target': 'spreadsheet'}), isTrue);
      expect(
        c.accepts({
          'uuid': _uuid,
          'target': 'document',
          'name': 'Notes',
          'options': {'separator': ';'},
        }),
        isTrue,
      );
      expect(c.accepts({'uuid': _uuid, 'target': 'presentation'}), isFalse);
      expect(c.accepts({'uuid': _uuid}), isFalse);
      expect(DriveTools.completeUpload.inputSchema.accepts({}), isFalse);
      expect(DriveTools.getStorage.inputSchema.accepts({}), isTrue);
    });

    test('when filtering lists then kinds and file_category are accepted', () {
      final search = DriveTools.search.inputSchema;
      final list = DriveTools.listFolder.inputSchema;

      expect(
        search.accepts({
          'kind': 'file',
          'kinds': ['presentation', 'file'],
          'file_category': 'pdf',
        }),
        isTrue,
      );
      expect(
        list.accepts({
          'kinds': ['folder', 'file'],
          'file_category': 'image',
        }),
        isTrue,
      );
      expect(list.accepts({'kinds': <String>[]}), isFalse);
      expect(list.accepts({'file_category': 'movie'}), isFalse);
      expect(search.accepts({'kind': 'deck'}), isFalse);
    });

    test('when describing byte-adding tools then agents are told about the '
        'quota and not to delete files', () {
      for (final t in [
        DriveTools.uploadFile,
        DriveTools.createUpload,
        DriveTools.convertFile,
      ]) {
        expect(t.description, contains('drive.get_storage'), reason: t.name);
        expect(t.description, contains('quota_exceeded'), reason: t.name);
        expect(t.description, contains('never'), reason: t.name);
      }
    });
  });

  group('Given the (v2) scopes and UI-bridge tools', () {
    test('when listing scopes then the slides scopes are registered', () {
      expect(McpScope.all, containsAll(['slides:read', 'slides:edit']));
      expect(McpScope.all.toSet().length, McpScope.all.length);
    });

    test('when looking up ui.drive tools then they need ui:control and a '
        'session id is optional', () {
      expect(UiDriveTools.all.map((t) => t.name), [
        'ui.drive.get_selection',
        'ui.drive.select_items',
        'ui.drive.get_upload_queue',
        'ui.drive.open_preview',
        'ui.drive.get_preview_state',
      ]);
      for (final t in UiDriveTools.all) {
        expect(t.scopes, {McpScope.uiControl}, reason: t.name);
        expect(McpToolCatalog.byName(t.name), same(t));
        expect(
          (t.inputSchema.toJson()['properties'] as Map).containsKey(
            'session_id',
          ),
          isTrue,
        );
      }
      expect(
        UiDriveTools.selectItems.inputSchema.accepts({
          'uuids': [_uuid],
        }),
        isTrue,
      );
      expect(UiDriveTools.openPreview.inputSchema.accepts({}), isFalse);
    });

    test('when serializing every drive tool then names are snake_case and '
        'schemas are objects', () {
      for (final t in [...DriveTools.all, ...UiDriveTools.all]) {
        expect(t.name, matches(RegExp(r'^[a-z]+(\.[a-z_]+)+$')));
        final json = t.toJson();
        expect((json['inputSchema'] as Map)['type'], 'object', reason: t.name);
      }
    });
  });
}
