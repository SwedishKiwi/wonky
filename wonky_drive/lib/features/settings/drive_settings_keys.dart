import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

/// The Drive settings (Drive 04 §8): keys of `UserPreferences.driveDefaults`
/// with their defaults and value checks (`drive.prefs.set`).
abstract final class DriveSettings {
  static const layout = 'layout';
  static const sortField = 'sortField';
  static const sortDescending = 'sortDescending';
  static const foldersOnTop = 'foldersOnTop';
  static const showExtensions = 'showExtensions';
  static const askOnNameConflict = 'askOnNameConflict';
  static const convertUploads = 'convertUploads';

  /// The sort fields of the *Default sort* setting (the filter bar's).
  static const sortFields = [
    DriveSortField.name,
    DriveSortField.modifiedAt,
    DriveSortField.lastOpenedByMe,
    DriveSortField.lastModifiedByMe,
    DriveSortField.size,
  ];

  /// Value checks of the keys `drive.prefs.set` accepts.
  static final Map<String, bool Function(Object? v)> validators = {
    layout: (v) => v == 'list' || v == 'grid',
    sortField: (v) => sortFields.any((f) => f.name == v),
    sortDescending: (v) => v is bool,
    foldersOnTop: (v) => v is bool,
    showExtensions: (v) => v is bool,
    askOnNameConflict: (v) => v is bool,
    convertUploads: (v) => v is bool,
  };

  /// Per-device choices a new default replaces (the list's layout and sort
  /// are remembered per device, Drive 04 §3.3).
  static const deviceOverrides = <String, List<String>>{
    layout: [DriveController.viewLayoutKey],
    sortField: [
      DriveController.viewSortFieldKey,
      DriveController.viewSortDescendingKey,
    ],
    sortDescending: [
      DriveController.viewSortFieldKey,
      DriveController.viewSortDescendingKey,
    ],
    foldersOnTop: [DriveController.viewFoldersOnTopKey],
  };

  static Map<String, Object?> _d(ShellServices s) => s.prefs.driveDefaults;

  static bool? _bool(ShellServices s, String key) {
    final v = _d(s)[key];
    return v is bool ? v : null;
  }

  /// *Default layout* (List).
  static DriveLayout layoutOf(ShellServices s) =>
      _d(s)[layout] == 'grid' ? DriveLayout.grid : DriveLayout.list;

  /// *Default sort* (Last modified).
  static DriveSortField sortFieldOf(ShellServices s) =>
      DriveSortField.values.asNameMap()[_d(s)[sortField]] ??
      DriveSortField.modifiedAt;

  /// Sort order (descending except for names).
  static bool sortDescendingOf(ShellServices s) =>
      _bool(s, sortDescending) ?? sortFieldOf(s) != DriveSortField.name;

  /// *Folders on top* (on).
  static bool foldersOnTopOf(ShellServices s) => _bool(s, foldersOnTop) ?? true;

  /// *Show file extensions* (on).
  static bool showsExtensions(ShellServices s) =>
      _bool(s, showExtensions) ?? true;

  /// *Ask when uploaded files have the same name* (on).
  static bool asksOnNameConflict(ShellServices s) =>
      _bool(s, askOnNameConflict) ?? true;

  /// *Convert uploads to Wonky formats* (off, v2 review Q13).
  static bool convertsUploads(ShellServices s) =>
      _bool(s, convertUploads) ?? false;
}
