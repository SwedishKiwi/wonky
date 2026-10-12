import 'package:wonky_client/wonky_client.dart';

/// Where the home screen is (suite 03 §2 drive routes).
enum DriveLocationKind { home, myDrive, folder, shared, starred, recent, offline, trash, search }

class DriveLocation {
  const DriveLocation._(this.kind, [this.folderUuid, this.query]);

  const DriveLocation.home() : this._(DriveLocationKind.home);
  const DriveLocation.myDrive() : this._(DriveLocationKind.myDrive);
  const DriveLocation.folder(String uuid) : this._(DriveLocationKind.folder, uuid);
  const DriveLocation.shared() : this._(DriveLocationKind.shared);
  const DriveLocation.starred() : this._(DriveLocationKind.starred);
  const DriveLocation.recent() : this._(DriveLocationKind.recent);
  const DriveLocation.offline() : this._(DriveLocationKind.offline);
  const DriveLocation.trash() : this._(DriveLocationKind.trash);
  const DriveLocation.search(String query) : this._(DriveLocationKind.search, null, query);

  final DriveLocationKind kind;
  final String? folderUuid;
  final String? query;

  UuidValue? get folder => folderUuid == null ? null : UuidValue.fromString(folderUuid!);

  /// The server list view.
  DriveView get view => switch (kind) {
    DriveLocationKind.shared => DriveView.sharedWithMe,
    DriveLocationKind.starred => DriveView.starred,
    DriveLocationKind.recent || DriveLocationKind.home => DriveView.recent,
    DriveLocationKind.offline => DriveView.offline,
    DriveLocationKind.trash => DriveView.trash,
    _ => DriveView.folder,
  };

  /// The route of this location.
  String get path => switch (kind) {
    DriveLocationKind.home => '/',
    DriveLocationKind.myDrive => '/my-drive',
    DriveLocationKind.folder => '/drive/$folderUuid',
    DriveLocationKind.shared => '/shared',
    DriveLocationKind.starred => '/starred',
    DriveLocationKind.recent => '/recent',
    DriveLocationKind.offline => '/offline',
    DriveLocationKind.trash => '/trash',
    DriveLocationKind.search => '/search?q=${Uri.encodeQueryComponent(query ?? '')}',
  };

  bool get isTrash => kind == DriveLocationKind.trash;

  /// Whether items are grouped by Today / Yesterday / …
  bool get groupsByDate => kind == DriveLocationKind.home || kind == DriveLocationKind.recent;

  @override
  bool operator ==(Object other) =>
      other is DriveLocation && other.kind == kind && other.folderUuid == folderUuid && other.query == query;

  @override
  int get hashCode => Object.hash(kind, folderUuid, query);
}
