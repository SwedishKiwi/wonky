import 'package:uuid/uuid.dart';

import '../generated/protocol.dart';

/// The current synced schema release (suite 01 §7, Slides 12 §1): every
/// `database: sync` model of this package, shared by all apps.
///
/// The offline-sync engine refuses peers whose `syncTablesHash` differs, so
/// the server, the generated client and every app change together. A change
/// to any synced model (a table, column, type, nullability, default, index or
/// foreign key) changes the hash: the guard tests (server
/// `test/unit/sync/sync_schema_release_test.dart`, Sheets
/// `test/sync/sync_schema_release_test.dart`) then fail until [name] and
/// [syncTablesHash] are bumped here and the release is recorded in
/// specs/wonky_slides/02-data-model.md §14.1.
///
/// The engine's hash covers table definitions only, not the values of enum
/// columns (stored by name), yet an enum value a peer doesn't know fails to
/// decode there. [syncEnumsHash] closes that gap: the guard test of this
/// package (`test/tables/sync_schema_release_test.dart`) fails when an enum
/// value is added until the release is bumped and recorded too.
abstract final class SyncSchemaRelease {
  /// Release name: S-1 = the Sheets tables + the Slides tables of M9; S-2
  /// (M10, SL-24) = + `BuildTrigger.onElementClick` (reserved, 06 A-06-2;
  /// no table change, so [syncTablesHash] stayed). The Sheets-only schema
  /// before S-1 hashed to
  /// `1a5f0730-2976-5ef7-b870-dbdc1b965fa5:8faad583-3b96-5cb4-a39e-5b141d5f9b15`.
  static const String name = 'S-2';

  /// `OfflineSyncEngine.computeSyncTablesHash` of the release.
  static const String syncTablesHash =
      'b54df85b-b26f-5da7-aa12-d8761b0c27cc:'
      '588b3c43-b2f7-5c93-a691-bb5704e6ffe8';

  /// [computeEnumsHash] of [syncedEnums] for the release.
  static const String syncEnumsHash =
      '137e402a-d9fd-5f33-99f2-0c4ef7340b37:'
      '656de501-33c1-57fb-90bd-364b8be5aa08';

  /// The values of every enum the synced models use, by enum name.
  static Map<String, List<String>> get syncedEnums => {
    'ActorKind': _names(ActorKind.values),
    'BuildKind': _names(BuildKind.values),
    'BuildTrigger': _names(BuildTrigger.values),
    'DeckAppearance': _names(DeckAppearance.values),
    'Dimension': _names(Dimension.values),
    'EmbeddedObjectKind': _names(EmbeddedObjectKind.values),
    'HorizontalAlign': _names(HorizontalAlign.values),
    'PlaceholderType': _names(PlaceholderType.values),
    'RecalcMode': _names(RecalcMode.values),
    'ScriptBuildStatus': _names(ScriptBuildStatus.values),
    'SheetKind': _names(SheetKind.values),
    'SlideElementKind': _names(SlideElementKind.values),
    'SlideSizePreset': _names(SlideSizePreset.values),
    'TableDimension': _names(TableDimension.values),
    'TriggerKind': _names(TriggerKind.values),
    'VerticalAlign': _names(VerticalAlign.values),
    'WrapStrategy': _names(WrapStrategy.values),
  };

  static List<String> _names(List<Enum> values) => [
    for (final v in values) v.name,
  ];

  /// A deterministic hash of [enums] (names sorted, values in declaration
  /// order: appending a value changes it), in the two-UUIDv5 form of the
  /// engine's table hash.
  static String computeEnumsHash(Map<String, List<String>> enums) {
    final names = enums.keys.toList()..sort();
    final signature = [
      for (final n in names) '$n:${enums[n]!.join(',')}',
    ].join(';');
    const uuid = Uuid();
    return '${uuid.v5(Namespace.url.value, signature)}:'
        '${uuid.v5(Namespace.oid.value, signature)}';
  }
}
