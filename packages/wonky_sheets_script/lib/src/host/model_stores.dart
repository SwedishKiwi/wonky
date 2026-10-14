import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:wonky_sheets_core/wonky_sheets_core.dart';

import 'services.dart';
import 'workbook_access.dart';

/// Column names of the synced script tables (02 §3.6).
abstract final class ScriptCols {
  /// `script_*.projectId` (relation to `ScriptProject`).
  static const projectId = 'projectId';

  /// `script_property.key`.
  static const key = 'key';

  /// `script_property.value`.
  static const value = 'value';

  /// `script_trigger.kind`.
  static const kind = 'kind';

  /// `script_trigger.functionName`, `macro.functionName`.
  static const functionName = 'functionName';

  /// `script_trigger.scheduleJson`.
  static const scheduleJson = 'scheduleJson';

  /// `script_trigger.runAsUserId`.
  static const runAsUserId = 'runAsUserId';

  /// `script_trigger.enabled`.
  static const enabled = 'enabled';

  /// `script_trigger.optionsJson`.
  static const optionsJson = 'optionsJson';

  /// `createdAt` of every table.
  static const createdAt = 'createdAt';

  /// `script_file.name`, `script_project.name`, `macro.name`.
  static const name = 'name';

  /// `script_file.source`.
  static const source = 'source';

  /// `script_file.sortKey`.
  static const sortKey = 'sortKey';

  /// `script_file.contentHash`.
  static const contentHash = 'contentHash';

  /// `macro.shortcutSlot`.
  static const shortcutSlot = 'shortcutSlot';

  /// `script_project.settingsJson`.
  static const settingsJson = 'settingsJson';
}

/// The script project row of the workbook, if any.
GenericRecord? scriptProjectOf(WorkbookModel model) {
  final projects = model.otherRecords(SheetsTables.scriptProject).toList();
  if (projects.isEmpty) return null;
  projects.sort((a, b) => a.id.compareTo(b.id));
  return projects.first;
}

/// Document properties stored as synced `ScriptProperty` rows of the
/// spreadsheet's script project (09 §6.9). Writes go through the planner (so
/// they sync) and are marked not undoable.
final class ModelDocumentProperties implements PropertyStore {
  /// Creates the store.
  ModelDocumentProperties(this.access, {Clock? clock})
    : _clock = clock ?? const Clock();

  /// The workbook.
  final WorkbookAccess access;
  final Clock _clock;

  String _projectId() {
    final p = scriptProjectOf(access.model);
    if (p == null) {
      throw StateError('The spreadsheet has no script project.');
    }
    return p.id;
  }

  Iterable<GenericRecord> _rows() {
    final project = scriptProjectOf(access.model)?.id;
    if (project == null) return const [];
    return access.model
        .otherRecords(SheetsTables.scriptProperty)
        .where((r) => r.columns[ScriptCols.projectId] == project);
  }

  @override
  Map<String, String> all() => {
    for (final r in _rows())
      '${r.columns[ScriptCols.key]}': '${r.columns[ScriptCols.value]}',
  };

  @override
  void set(String key, String value) {
    final existing = _rows()
        .where((r) => r.columns[ScriptCols.key] == key)
        .firstOrNull;
    if (existing != null) {
      access.apply(
        GenericRowWrite(SheetsTables.scriptProperty, existing.id, {
          ScriptCols.value: value,
        }, label: 'Set script property'),
        undoable: false,
      );
      return;
    }
    access.apply(
      GenericRowWrite(SheetsTables.scriptProperty, access.ids.newId(), {
        ScriptCols.projectId: _projectId(),
        ScriptCols.key: key,
        ScriptCols.value: value,
        ScriptCols.createdAt: _clock.now().toUtc(),
      }, label: 'Set script property'),
      undoable: false,
    );
  }

  @override
  void delete(String key) {
    for (final r
        in _rows().where((r) => r.columns[ScriptCols.key] == key).toList()) {
      access.apply(
        GenericRowWrite(
          SheetsTables.scriptProperty,
          r.id,
          const {},
          delete: true,
          label: 'Delete script property',
        ),
        undoable: false,
      );
    }
  }
}

/// Installable triggers of the current user (`ScriptApp`, 09 §6.11).
abstract interface class TriggerStore {
  /// Creates a trigger; [schedule] for time-driven triggers.
  ScriptTriggerInfo create(
    String functionName,
    String eventType,
    Map<String, Object?>? schedule,
  );

  /// The triggers of the running user.
  List<ScriptTriggerInfo> list();

  /// Deletes the trigger [uid] (own triggers; owners: all).
  void delete(String uid);
}

/// [TriggerStore] over synced `ScriptTrigger` rows. The server picks new rows
/// up from change-log processing (09 §8.7.3).
final class ModelTriggerStore implements TriggerStore {
  /// Creates the store for the run-as user [userId].
  ModelTriggerStore(
    this.access, {
    required this.userId,
    this.isOwner = false,
    this.maxPerUser = 20,
    Clock? clock,
  }) : _clock = clock ?? const Clock();

  /// The workbook.
  final WorkbookAccess access;

  /// Auth user UUID of the installer.
  final String userId;

  /// Owners may delete other users' triggers.
  final bool isOwner;

  /// Installable triggers per user per spreadsheet (09 §10).
  final int maxPerUser;

  final Clock _clock;

  Iterable<GenericRecord> _rows() {
    final project = scriptProjectOf(access.model)?.id;
    if (project == null) return const [];
    return access.model
        .otherRecords(SheetsTables.scriptTrigger)
        .where((r) => r.columns[ScriptCols.projectId] == project);
  }

  static ScriptTriggerInfo _info(GenericRecord r) => ScriptTriggerInfo(
    uid: r.id,
    functionName: '${r.columns[ScriptCols.functionName]}',
    eventType: '${r.columns[ScriptCols.kind]}',
    scheduleJson: r.columns[ScriptCols.scheduleJson] as String?,
    runAsUserId: r.columns[ScriptCols.runAsUserId]?.toString(),
    enabled: r.columns[ScriptCols.enabled] != false,
  );

  @override
  ScriptTriggerInfo create(
    String functionName,
    String eventType,
    Map<String, Object?>? schedule,
  ) {
    const kinds = {'timeDriven', 'onEdit', 'onChange', 'installableOnOpen'};
    if (!kinds.contains(eventType)) {
      throw ArgumentError('Unknown trigger event $eventType');
    }
    if (eventType == 'timeDriven' && (schedule == null || schedule.isEmpty)) {
      throw ArgumentError(
        'A time-driven trigger needs a schedule (everyMinutes, everyHours, '
        'everyDays, everyWeeks, onMonthDay or at).',
      );
    }
    final own = list().length;
    if (own >= maxPerUser) {
      throw StateError(
        'You can have at most $maxPerUser triggers in this spreadsheet.',
      );
    }
    final project = scriptProjectOf(access.model);
    if (project == null) {
      throw StateError('The spreadsheet has no script project.');
    }
    final id = access.ids.newId();
    access.apply(
      GenericRowWrite(SheetsTables.scriptTrigger, id, {
        ScriptCols.projectId: project.id,
        ScriptCols.kind: eventType,
        ScriptCols.functionName: functionName,
        ScriptCols.scheduleJson: schedule == null
            ? null
            : jsonEncode(_jsonable(schedule)),
        ScriptCols.runAsUserId: userId,
        ScriptCols.enabled: true,
        ScriptCols.optionsJson: null,
        ScriptCols.createdAt: _clock.now().toUtc(),
      }, label: 'Add trigger'),
      undoable: false,
    );
    return ScriptTriggerInfo(
      uid: id,
      functionName: functionName,
      eventType: eventType,
      scheduleJson: schedule == null ? null : jsonEncode(_jsonable(schedule)),
      runAsUserId: userId,
    );
  }

  @override
  List<ScriptTriggerInfo> list() => [
    for (final r in _rows())
      if ('${r.columns[ScriptCols.runAsUserId]}' == userId) _info(r),
  ];

  @override
  void delete(String uid) {
    final row = _rows().where((r) => r.id == uid).firstOrNull;
    if (row == null) throw ArgumentError('Unknown trigger $uid');
    if (!isOwner && '${row.columns[ScriptCols.runAsUserId]}' != userId) {
      throw StateError("Only the owner can delete other users' triggers.");
    }
    access.apply(
      GenericRowWrite(
        SheetsTables.scriptTrigger,
        uid,
        const {},
        delete: true,
        label: 'Delete trigger',
      ),
      undoable: false,
    );
  }

  static Object? _jsonable(Object? v) => switch (v) {
    DateTime d => d.toUtc().toIso8601String(),
    Map<Object?, Object?> m => {
      for (final e in m.entries) '${e.key}': _jsonable(e.value),
    },
    List<Object?> l => [for (final e in l) _jsonable(e)],
    _ => v,
  };
}
