import 'package:serverpod/serverpod.dart' show UuidValue;
import 'package:test/test.dart';
import 'package:wonky_server/src/generated/protocol.dart';
import 'package:wonky_server/src/platform/mcp/drive_tool_handlers.dart';

const _uuid = '0190a8a0-0000-7000-8000-00000000000a';

DriveItemView _item(DriveItemKind kind) => DriveItemView(
  uuid: UuidValue.fromString(_uuid),
  kind: kind,
  name: 'Item',
  owner: UserSummary(
    id: 1,
    uuid: UuidValue.fromString('0190a8a0-0000-7000-8000-000000000001'),
    displayName: 'Anna',
    email: 'anna@example.com',
    avatarColor: '#2563eb',
    colorIndex: 0,
  ),
  role: AccessRole.owner,
  shared: false,
  sizeBytes: 0,
  createdAt: DateTime.utc(2026),
  modifiedAt: DateTime.utc(2026),
  starred: false,
  pinnedOffline: false,
  editorsCanShare: true,
  nonEditorsCanExport: true,
  viewersSeeComments: true,
);

void main() {
  group('Given the browser URLs of MCP tool results (suite 09 §4)', () {
    for (final (kind, path) in [
      (DriveItemKind.document, '/write/d/'),
      (DriveItemKind.spreadsheet, '/sheets/s/'),
      (DriveItemKind.presentation, '/slides/p/'),
      // (v2) Folders open in Wonky Drive (suite 03 §2), not `/write/drive/`.
      (DriveItemKind.folder, '/drive/f/'),
      (DriveItemKind.file, '/drive/file/'),
    ]) {
      test('when the item is a ${kind.name} then the URL is $path<uuid>', () {
        expect(
          Uri.parse(DriveToolHandlers.urlOf(_item(kind))).path,
          '$path$_uuid',
        );
      });
    }
  });
}
