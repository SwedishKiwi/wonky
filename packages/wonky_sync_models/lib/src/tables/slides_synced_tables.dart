import 'package:serverpod_database/serverpod_database.dart' show TableRow;
import 'package:serverpod_serialization/serverpod_serialization.dart'
    show UuidValue;

import '../generated/protocol.dart';
import 'synced_tables.dart';

/// All synced tables of Wonky Slides (`database: sync`, Slides 02 §3), by
/// name, in dependency order (parents first): the table codec of the Slides
/// writer, server writer and test devices. Sheets' tables are
/// [SyncedTables]; the two sets are disjoint.
abstract final class SlidesSyncedTables {
  /// Specs in dependency order (parents first): apply inserts in this order,
  /// deletes in reverse. `slide_element` references itself (`parentId`):
  /// within the table, parents are inserted first by the writers (the
  /// foreign keys are deferred, so one transaction may hold any order).
  static final List<SyncedTableSpec<TableRow<UuidValue>>> all = [
    SyncedTableSpec<Deck>.of(Deck.t, Deck.fromJson),
    SyncedTableSpec<DeckTheme>.of(DeckTheme.t, DeckTheme.fromJson),
    SyncedTableSpec<SlideMaster>.of(SlideMaster.t, SlideMaster.fromJson),
    SyncedTableSpec<SlideLayout>.of(SlideLayout.t, SlideLayout.fromJson),
    SyncedTableSpec<SlideGroup>.of(SlideGroup.t, SlideGroup.fromJson),
    SyncedTableSpec<Slide>.of(Slide.t, Slide.fromJson),
    SyncedTableSpec<SlideElement>.of(SlideElement.t, SlideElement.fromJson),
    SyncedTableSpec<SlideTableAxis>.of(
      SlideTableAxis.t,
      SlideTableAxis.fromJson,
    ),
    SyncedTableSpec<SlideTableCell>.of(
      SlideTableCell.t,
      SlideTableCell.fromJson,
    ),
    SyncedTableSpec<SlideBuild>.of(SlideBuild.t, SlideBuild.fromJson),
    SyncedTableSpec<CodeState>.of(CodeState.t, CodeState.fromJson),
    SyncedTableSpec<ChartLink>.of(ChartLink.t, ChartLink.fromJson),
    SyncedTableSpec<DeckChangeLog>.of(DeckChangeLog.t, DeckChangeLog.fromJson),
  ];

  /// Specs by table name.
  static final Map<String, SyncedTableSpec<TableRow<UuidValue>>> byName = {
    for (final s in all) s.name: s,
  };

  /// The spec of [table]; throws for unknown tables.
  static SyncedTableSpec<TableRow<UuidValue>> of(String table) =>
      byName[table] ?? (throw ArgumentError.value(table, 'table'));
}
