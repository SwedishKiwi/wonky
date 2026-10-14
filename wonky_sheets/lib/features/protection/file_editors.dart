import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart'
    show AccessRole, SharingInfo, UuidValue;

import 'protection_dialogs.dart';

/// The editors of the spreadsheet file offered by the protection
/// permissions dialog (07 §10.2): loaded from the sharing repository and
/// cached per user on this device, so the list also works offline.
abstract final class FileEditors {
  static String _key(UuidValue item) => 'sheets.fileEditors.${item.uuid}';

  /// Editors and the owner of [item]. Offline (or when sharing can't be
  /// read) the last list seen on this device is used ([FileEditorList.offline]);
  /// [known] user ids missing from it are added with the id as label.
  static Future<FileEditorList> load(
    ShellServices s,
    UuidValue item, {
    Iterable<String> known = const [],
  }) async {
    try {
      final info = await s.repositories.sharing.getSharing(item);
      final list = editorsOf(info);
      try {
        await s.userStore.write(_key(item), [
          for (final e in list)
            {'id': e.userId, 'label': e.label, 'email': ?e.email},
        ]);
      } on Object {
        // Caching is best effort.
      }
      return FileEditorList(_withKnown(list, known));
    } on Object {
      return FileEditorList(
        _withKnown(await cached(s, item), known),
        offline: true,
      );
    }
  }

  /// The cached list of [item] (empty when never loaded on this device).
  static Future<List<ProtectionEditorOption>> cached(
    ShellServices s,
    UuidValue item,
  ) async {
    try {
      final raw = await s.userStore.read(_key(item));
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map && e['id'] is String)
            ProtectionEditorOption(
              userId: e['id'] as String,
              label: (e['label'] as String?) ?? e['id'] as String,
              email: e['email'] as String?,
            ),
      ];
    } on Object {
      return const [];
    }
  }

  /// The owner and the editors of [info].
  static List<ProtectionEditorOption> editorsOf(SharingInfo info) {
    final out = <ProtectionEditorOption>[
      ProtectionEditorOption(
        userId: info.owner.uuid.uuid,
        label: info.owner.displayName,
        email: info.owner.email,
      ),
    ];
    for (final p in info.permissions) {
      final u = p.user;
      if (u == null) continue;
      if (p.role != AccessRole.editor && p.role != AccessRole.owner) continue;
      if (out.any((o) => o.userId == u.uuid.uuid)) continue;
      out.add(
        ProtectionEditorOption(
          userId: u.uuid.uuid,
          label: u.displayName,
          email: u.email,
        ),
      );
    }
    return out;
  }

  static List<ProtectionEditorOption> _withKnown(
    List<ProtectionEditorOption> list,
    Iterable<String> known,
  ) => [
    ...list,
    for (final id in known)
      if (!list.any((e) => e.userId.toLowerCase() == id.toLowerCase()))
        ProtectionEditorOption(userId: id, label: id),
  ];

  /// Shares [item] with [emails] as editors (the invite flow of the
  /// permissions dialog, 07 §10.2; not part of the undo step). Returns the
  /// user ids of the emails that belong to accounts, and the emails that
  /// were invited (no account yet).
  static Future<({Map<String, String> userIds, List<String> invited})> invite(
    ShellServices s,
    UuidValue item,
    List<String> emails,
  ) async {
    final info = await s.repositories.sharing.share(
      item,
      emails: emails,
      role: AccessRole.editor,
    );
    final ids = <String, String>{};
    final invited = <String>[];
    for (final m in emails) {
      String? id;
      for (final p in info.permissions) {
        final u = p.user;
        if (u != null && u.email.toLowerCase() == m.toLowerCase()) {
          id = u.uuid.uuid;
          break;
        }
      }
      if (id != null) {
        ids[m] = id;
      } else {
        invited.add(m);
      }
    }
    try {
      await s.userStore.write(_key(item), [
        for (final e in editorsOf(info))
          {'id': e.userId, 'label': e.label, 'email': ?e.email},
      ]);
    } on Object {
      // Best effort.
    }
    return (userIds: ids, invited: invited);
  }
}

/// [FileEditors.load] result.
class FileEditorList {
  const FileEditorList(this.editors, {this.offline = false});

  final List<ProtectionEditorOption> editors;

  /// The list comes from this device's cache (sharing couldn't be read).
  final bool offline;
}
