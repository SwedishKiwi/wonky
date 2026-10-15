/// Immutable records of the synced Slides rows (02 §11): one class per model
/// table, built from generic column maps (UUIDs as lower-case strings, enums
/// by name, `DateTime` in UTC) — independent of the generated Serverpod
/// classes, as Sheets' `WorkbookModel` records.
library;

import '../../schema/slides_schema.dart';
import '../../theme/layout/placeholder_type.dart';
import '../../theme/layout/slide_size.dart';
import '../../theme/model/common.dart';
import 'kinds.dart';

/// Typed readers for column maps (lenient: numbers may arrive as `int`,
/// booleans as `0/1`, dates as ISO strings).
abstract final class SlidesColumnReader {
  /// `String` or null.
  static String? str(Map<String, Object?> m, String k) => m[k]?.toString();

  /// `double` or null.
  static double? dbl(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// `int` or null.
  static int? integer(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// `bool` or null.
  static bool? boolean(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is bool) return v;
    if (v == 'true' || v == 1) return true;
    if (v == 'false' || v == 0) return false;
    return null;
  }

  /// `DateTime` (UTC) or null; accepts ISO strings and epoch milliseconds.
  static DateTime? date(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is DateTime) return v.toUtc();
    if (v is String) return DateTime.tryParse(v)?.toUtc();
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    return null;
  }
}

/// The epoch used when a row has no `createdAt`.
final DateTime slidesEpochUtc = DateTime.utc(1970);

/// Base of the records of the deck model. A record holds the **full row**:
/// every column of its table ([SlidesTables.columns]) is present in
/// [columns] (missing ones as null), so `currentColumns` describes the whole
/// row for the undo inverter.
abstract base class SlidesRecord {
  /// Creates a record over [columns] (must hold `id`).
  SlidesRecord(String table, Map<String, Object?> columns)
    : columns = Map.unmodifiable(_full(table, columns)),
      id = columns[SlidesCols.id]! as String;

  static Map<String, Object?> _full(String table, Map<String, Object?> c) {
    final known = SlidesTables.columns[table];
    if (known == null) return c;
    return {
      for (final k in known) k: c[k],
      for (final e in c.entries)
        if (!known.contains(e.key)) e.key: e.value,
    };
  }

  /// Row id (canonical lower-case UUID string).
  final String id;

  /// Every column of the row, including `id`.
  final Map<String, Object?> columns;

  /// Table name ([SlidesTables]).
  String get table;

  /// A copy of [columns].
  Map<String, Object?> toColumns() => Map.of(columns);

  /// The value of [column].
  Object? operator [](String column) => columns[column];

  /// A record of the same table with [update] applied.
  SlidesRecord withColumns(Map<String, Object?> update) =>
      slidesRecordFromColumns(table, {
        ...columns,
        ...update,
        SlidesCols.id: id,
      });

  /// `createdAt` (the epoch when missing).
  DateTime get createdAt =>
      SlidesColumnReader.date(columns, SlidesCols.createdAt) ?? slidesEpochUtc;

  /// String column.
  String? str(String c) => SlidesColumnReader.str(columns, c);

  /// Double column.
  double? dbl(String c) => SlidesColumnReader.dbl(columns, c);

  /// Int column.
  int? integer(String c) => SlidesColumnReader.integer(columns, c);

  /// Bool column ([orElse] when null).
  bool flag(String c, {bool orElse = false}) =>
      SlidesColumnReader.boolean(columns, c) ?? orElse;

  /// Sort key column (`sortKey`), `''` when missing.
  String get sortKeyOrEmpty => str(SlidesCols.sortKey) ?? '';

  @override
  bool operator ==(Object other) =>
      other is SlidesRecord &&
      other.table == table &&
      _mapEquals(other.columns, columns);

  @override
  int get hashCode => Object.hash(table, id);

  @override
  String toString() => '$table($id)';
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

/// A record of a table the model does not know (forward compatibility).
final class GenericSlidesRecord extends SlidesRecord {
  /// Creates the record.
  GenericSlidesRecord(this.table, Map<String, Object?> columns)
    : super(table, columns);

  @override
  final String table;
}

/// Builds the record class of [table] from a full column map.
SlidesRecord slidesRecordFromColumns(
  String table,
  Map<String, Object?> columns,
) => switch (table) {
  SlidesTables.deck => DeckRec(columns),
  SlidesTables.deckTheme => DeckThemeRec(columns),
  SlidesTables.slideMaster => SlideMasterRec(columns),
  SlidesTables.slideLayout => SlideLayoutRec(columns),
  SlidesTables.slideGroup => SlideGroupRec(columns),
  SlidesTables.slide => SlideRec(columns),
  SlidesTables.slideElement => SlideElementRec(columns),
  SlidesTables.slideTableAxis => SlideTableAxisRec(columns),
  SlidesTables.slideTableCell => SlideTableCellRec(columns),
  SlidesTables.slideBuild => SlideBuildRec(columns),
  SlidesTables.codeState => CodeStateRec(columns),
  SlidesTables.chartLink => ChartLinkRec(columns),
  _ => GenericSlidesRecord(table, columns),
};

/// `deck` (02 §3.1). `id` = space UUID = drive item UUID.
final class DeckRec extends SlidesRecord {
  /// Creates the record.
  DeckRec(Map<String, Object?> columns) : super(SlidesTables.deck, columns);

  @override
  String get table => SlidesTables.deck;

  /// Title (mirrored to the drive item name).
  String get title => str(DeckCols.title) ?? '';

  /// Design width in su (default 1920).
  double get width => dbl(DeckCols.width) ?? 1920;

  /// Design height in su (default 1080).
  double get height => dbl(DeckCols.height) ?? 1080;

  /// `sizePreset` name.
  String get sizePresetName =>
      str(DeckCols.sizePreset) ?? SlideSizeKind.widescreen16x9.name;

  /// `sizePreset` as the theme core's [SlideSizeKind] (custom when unknown).
  SlideSizeKind get sizePreset {
    for (final k in SlideSizeKind.values) {
      if (k.name == sizePresetName) return k;
    }
    return SlideSizeKind.custom;
  }

  /// Default theme id (missing = the theme with the smallest id, 02 §10).
  String? get themeId => str(DeckCols.themeId);

  /// `appearance`.
  SlideAppearance get appearance => str(DeckCols.appearance) == 'dark'
      ? SlideAppearance.dark
      : SlideAppearance.light;

  /// BCP-47 language or null.
  String? get language => str(DeckCols.language);

  /// Slide numbers on.
  bool get showSlideNumbers => flag(DeckCols.showSlideNumbers);

  /// No number on `title` layouts.
  bool get hideNumberOnTitle => flag(DeckCols.hideNumberOnTitle, orElse: true);

  /// First slide number.
  int get firstSlideNumber => integer(DeckCols.firstSlideNumber) ?? 1;

  /// Footer text (null = hidden).
  String? get footerText => str(DeckCols.footerText);

  /// `defaultsJson`.
  String? get defaultsJson => str(DeckCols.defaultsJson);

  /// `guidesJson`.
  String? get guidesJson => str(DeckCols.guidesJson);

  /// `presentJson`.
  String? get presentJson => str(DeckCols.presentJson);

  /// Creator (auth user UUID).
  String get createdBy => str(DeckCols.createdBy) ?? '';
}

/// `deck_theme` (02 §3.2, 05 §2). JSON columns are decoded by the theme
/// core (`deckThemeFromColumns`).
final class DeckThemeRec extends SlidesRecord {
  /// Creates the record.
  DeckThemeRec(Map<String, Object?> columns)
    : super(SlidesTables.deckTheme, columns);

  @override
  String get table => SlidesTables.deckTheme;

  /// Theme name.
  String get name => str(SlidesCols.name) ?? '';

  /// Provenance (`builtin:<key>@<v>`, `deck:<item>:<theme>`) or null.
  String? get sourceKey => str(DeckThemeCols.sourceKey);

  /// Order in the Themes panel.
  String get sortKey => sortKeyOrEmpty;

  /// The theme JSON columns by name (for `deckThemeFromColumns`).
  Map<String, String?> get themeColumns => {
    for (final c in const [
      DeckThemeCols.colorsJson,
      DeckThemeCols.fontsJson,
      DeckThemeCols.textStylesJson,
      DeckThemeCols.backgroundJson,
      DeckThemeCols.shapeStyleJson,
      DeckThemeCols.tableStyleJson,
      DeckThemeCols.codeStyleJson,
      DeckThemeCols.chartStyleJson,
    ])
      c: str(c),
  };
}

/// `slide_master` (02 §3.2).
final class SlideMasterRec extends SlidesRecord {
  /// Creates the record.
  SlideMasterRec(Map<String, Object?> columns)
    : super(SlidesTables.slideMaster, columns);

  @override
  String get table => SlidesTables.slideMaster;

  /// Owning theme.
  String? get themeId => str(SlideMasterCols.themeId);

  /// Name.
  String get name => str(SlidesCols.name) ?? '';

  /// Order among the masters of the theme.
  String get sortKey => sortKeyOrEmpty;

  /// Background JSON (null = theme background).
  String? get backgroundJson => str(SlidesCols.backgroundJson);
}

/// `slide_layout` (02 §3.2).
final class SlideLayoutRec extends SlidesRecord {
  /// Creates the record.
  SlideLayoutRec(Map<String, Object?> columns)
    : super(SlidesTables.slideLayout, columns);

  @override
  String get table => SlidesTables.slideLayout;

  /// Owning master.
  String? get masterId => str(SlideLayoutCols.masterId);

  /// Name ("Title and content").
  String get name => str(SlidesCols.name) ?? '';

  /// Built-in layout key (maps layouts between themes) or null.
  String? get key => str(SlideLayoutCols.key);

  /// Order among the layouts of the master.
  String get sortKey => sortKeyOrEmpty;

  /// Background JSON (null = master background).
  String? get backgroundJson => str(SlidesCols.backgroundJson);

  /// Don't draw the master's non-placeholder elements.
  bool get hideMasterElements => flag(SlidesCols.hideMasterElements);

  /// Not offered in the layout picker.
  bool get hidden => flag(SlidesCols.hidden);
}

/// `slide_group` (02 §3.4).
final class SlideGroupRec extends SlidesRecord {
  /// Creates the record.
  SlideGroupRec(Map<String, Object?> columns)
    : super(SlidesTables.slideGroup, columns);

  @override
  String get table => SlidesTables.slideGroup;

  /// Title.
  String get title => str(SlidesCols.title) ?? '';

  /// Key in the top-level key space (shared with ungrouped slides).
  String get sortKey => sortKeyOrEmpty;

  /// Reserved for nesting (P2); null in v1.
  String? get parentId => str(SlidesCols.parentId);

  /// Palette token or null.
  String? get color => str(SlideGroupCols.color);

  /// Skips all its slides.
  bool get skipped => flag(SlidesCols.skipped);
}

/// `slide` (02 §3.3).
final class SlideRec extends SlidesRecord {
  /// Creates the record.
  SlideRec(Map<String, Object?> columns) : super(SlidesTables.slide, columns);

  @override
  String get table => SlidesTables.slide;

  /// Key in the top-level space (no group) or in the group's space.
  String get sortKey => sortKeyOrEmpty;

  /// Group id (plain UUID, may dangle) or null.
  String? get groupId => str(SlideCols.groupId);

  /// Layout id (plain UUID, may dangle) or null.
  String? get layoutId => str(SlideCols.layoutId);

  /// Background JSON (null = layout ▸ master ▸ theme).
  String? get backgroundJson => str(SlidesCols.backgroundJson);

  /// Skipped when presenting/exporting.
  bool get skipped => flag(SlidesCols.skipped);

  /// Speaker notes Delta JSON or null.
  String? get notes => str(SlideCols.notes);

  /// Transition JSON (null = deck default).
  String? get transitionJson => str(SlidesCols.transitionJson);

  /// Hide master elements (null = the layout's setting).
  bool? get hideMasterElements =>
      SlidesColumnReader.boolean(columns, SlidesCols.hideMasterElements);

  /// Rehearsed timings JSON.
  String? get timingsJson => str(SlideCols.timingsJson);
}

/// `slide_element` (02 §3.5).
final class SlideElementRec extends SlidesRecord {
  /// Creates the record.
  SlideElementRec(Map<String, Object?> columns)
    : super(SlidesTables.slideElement, columns);

  @override
  String get table => SlidesTables.slideElement;

  /// Owning slide (exactly one owner column is set).
  String? get slideId => str(SlidesCols.slideId);

  /// Owning layout.
  String? get layoutId => str(ElementCols.layoutId);

  /// Owning master.
  String? get masterId => str(ElementCols.masterId);

  /// The owner row id (slide, layout or master), or null when none is set.
  String? get ownerId => slideId ?? layoutId ?? masterId;

  /// The kind of the owner, or null when none is set.
  ElementOwnerKind? get ownerKind => slideId != null
      ? ElementOwnerKind.slide
      : layoutId != null
      ? ElementOwnerKind.layout
      : masterId != null
      ? ElementOwnerKind.master
      : null;

  /// Element group this element belongs to, or null (top level).
  String? get parentId => str(SlidesCols.parentId);

  /// Kind name.
  String get kindName => str(SlidesCols.kind) ?? ElementKind.shape.name;

  /// Kind (unknown names read as [ElementKind.shape]).
  ElementKind get kind => ElementKind.fromName(kindName) ?? ElementKind.shape;

  /// Layers-panel name or null.
  String? get name => str(SlidesCols.name);

  /// Frame x (null on placeholder instances = inherit).
  double? get x => dbl(ElementCols.x);

  /// Frame y.
  double? get y => dbl(ElementCols.y);

  /// Frame width.
  double? get width => dbl(ElementCols.width);

  /// Frame height.
  double? get height => dbl(ElementCols.height);

  /// Rotation in degrees (null = 0 / inherit).
  double? get rotation => dbl(ElementCols.rotation);

  /// Horizontal flip.
  bool get flipH => flag(ElementCols.flipH);

  /// Vertical flip.
  bool get flipV => flag(ElementCols.flipV);

  /// The stored frame when all four values are set.
  SuRect? get frame {
    final fx = x, fy = y, fw = width, fh = height;
    if (fx == null || fy == null || fw == null || fh == null) return null;
    return SuRect(fx, fy, fw, fh);
  }

  /// Stacking key among siblings.
  String get zKey => str(ElementCols.zKey) ?? '';

  /// Reading-order override.
  String? get readingKey => str(ElementCols.readingKey);

  /// Locked.
  bool get locked => flag(ElementCols.locked);

  /// Hidden.
  bool get hidden => flag(SlidesCols.hidden);

  /// Placeholder type (definition on layouts/masters, instance on slides).
  SlidePlaceholderType? get placeholderType =>
      SlidePlaceholderType.fromName(str(ElementCols.placeholderType));

  /// The layout/master placeholder an instance inherits from.
  String? get placeholderOf => str(ElementCols.placeholderOf);

  /// Whether this element is a placeholder (definition or instance).
  bool get isPlaceholder => str(ElementCols.placeholderType) != null;

  /// Magic Move key.
  String get matchKey => str(ElementCols.matchKey) ?? '';

  /// Rich text Delta JSON.
  String? get text => str(SlidesCols.text);

  /// `textStyleJson`.
  String? get textStyleJson => str(ElementCols.textStyleJson);

  /// `fillJson`.
  String? get fillJson => str(ElementCols.fillJson);

  /// `strokeJson`.
  String? get strokeJson => str(ElementCols.strokeJson);

  /// `effectsJson`.
  String? get effectsJson => str(ElementCols.effectsJson);

  /// Opacity 0..1 (null = 1).
  double? get opacity => dbl(ElementCols.opacity);

  /// Kind payload JSON (02 §6).
  String? get dataJson => str(ElementCols.dataJson);

  /// Click action JSON.
  String? get linkJson => str(ElementCols.linkJson);

  /// Alt text.
  String? get altText => str(ElementCols.altText);

  /// Excluded from alt-text checks.
  bool get decorative => flag(ElementCols.decorative);
}

/// `slide_table_axis` (02 §3.6).
final class SlideTableAxisRec extends SlidesRecord {
  /// Creates the record.
  SlideTableAxisRec(Map<String, Object?> columns)
    : super(SlidesTables.slideTableAxis, columns);

  @override
  String get table => SlidesTables.slideTableAxis;

  /// The table element.
  String? get elementId => str(SlidesCols.elementId);

  /// Row or column.
  TableAxisDimension get dimension =>
      TableAxisDimension.fromName(str(TableAxisCols.dimension)) ??
      TableAxisDimension.row;

  /// Order among the axes of one table and dimension.
  String get sortKey => sortKeyOrEmpty;

  /// Size in su (null = even split / fit).
  double? get size => dbl(TableAxisCols.size);

  /// Header styling.
  bool get header => flag(TableAxisCols.header);
}

/// `slide_table_cell` (02 §3.6). Id = `SlidesIds.tableCellId`.
final class SlideTableCellRec extends SlidesRecord {
  /// Creates the record.
  SlideTableCellRec(Map<String, Object?> columns)
    : super(SlidesTables.slideTableCell, columns);

  @override
  String get table => SlidesTables.slideTableCell;

  /// The table element.
  String? get elementId => str(SlidesCols.elementId);

  /// Row axis id.
  String? get rowId => str(TableCellCols.rowId);

  /// Column axis id.
  String? get columnId => str(TableCellCols.columnId);

  /// Rich text Delta JSON.
  String? get text => str(SlidesCols.text);

  /// Fill ColorRef.
  String? get fill => str(TableCellCols.fill);

  /// Vertical alignment.
  String? get vAlign => str(TableCellCols.vAlign);

  /// Padding `"t,r,b,l"`.
  String? get padding => str(TableCellCols.padding);

  /// Merge origin row span (null = 1).
  int get rowSpan => integer(TableCellCols.rowSpan) ?? 1;

  /// Merge origin column span (null = 1).
  int get colSpan => integer(TableCellCols.colSpan) ?? 1;
}

/// `slide_build` (02 §3.7, 06).
final class SlideBuildRec extends SlidesRecord {
  /// Creates the record.
  SlideBuildRec(Map<String, Object?> columns)
    : super(SlidesTables.slideBuild, columns);

  @override
  String get table => SlidesTables.slideBuild;

  /// The slide.
  String? get slideId => str(SlidesCols.slideId);

  /// The animated element.
  String? get elementId => str(SlidesCols.elementId);

  /// Kind.
  SlideBuildKind get kind =>
      SlideBuildKind.fromName(str(SlidesCols.kind)) ?? SlideBuildKind.buildIn;

  /// Effect key.
  String get effect => str(BuildCols.effect) ?? '';

  /// Order on the slide.
  String get sortKey => sortKeyOrEmpty;

  /// Trigger.
  SlideBuildTrigger get trigger =>
      SlideBuildTrigger.fromName(str(BuildCols.trigger)) ??
      SlideBuildTrigger.onClick;

  /// Delay (ms).
  int get delayMs => integer(BuildCols.delayMs) ?? 0;

  /// Duration (ms).
  int get durationMs => integer(BuildCols.durationMs) ?? 0;

  /// Easing expression.
  String get easing => str(BuildCols.easing) ?? '';

  /// Options JSON.
  String? get optionsJson => str(BuildCols.optionsJson);
}

/// `code_state` (02 §3.8, 07).
final class CodeStateRec extends SlidesRecord {
  /// Creates the record.
  CodeStateRec(Map<String, Object?> columns)
    : super(SlidesTables.codeState, columns);

  @override
  String get table => SlidesTables.codeState;

  /// The code element.
  String? get elementId => str(SlidesCols.elementId);

  /// Order among the states.
  String get sortKey => sortKeyOrEmpty;

  /// Label.
  String? get label => str(SlidesCols.label);

  /// Source.
  String get code => str(CodeStateCols.code) ?? '';

  /// Language (null = the element's).
  String? get language => str(CodeStateCols.language);

  /// Title (null = the element's).
  String? get title => str(SlidesCols.title);

  /// Highlight steps.
  String? get highlight => str(CodeStateCols.highlight);

  /// Callouts JSON.
  String? get annotationsJson => str(CodeStateCols.annotationsJson);

  /// Transition from the previous state.
  String? get transitionJson => str(SlidesCols.transitionJson);
}

/// `chart_link` (02 §3.9, 08). Id = `SlidesIds.chartLinkId(elementId)`.
final class ChartLinkRec extends SlidesRecord {
  /// Creates the record.
  ChartLinkRec(Map<String, Object?> columns)
    : super(SlidesTables.chartLink, columns);

  @override
  String get table => SlidesTables.chartLink;

  /// The chart element.
  String? get elementId => str(SlidesCols.elementId);

  /// Spreadsheet drive item UUID.
  String get spreadsheetItemUuid =>
      str(ChartLinkCols.spreadsheetItemUuid) ?? '';

  /// Sheets chart object id.
  String get chartObjectId => str(ChartLinkCols.chartObjectId) ?? '';

  /// Sheet of the chart at the last update.
  String? get sheetId => str(ChartLinkCols.sheetId);

  /// Source chart spec JSON.
  String get sourceSpecJson => str(ChartLinkCols.sourceSpecJson) ?? '';

  /// Data snapshot JSON.
  String get dataSnapshotJson => str(ChartLinkCols.dataSnapshotJson) ?? '';

  /// Opaque source version.
  String get sourceVersion => str(ChartLinkCols.sourceVersion) ?? '';

  /// Snapshot time.
  DateTime get updatedAt =>
      SlidesColumnReader.date(columns, ChartLinkCols.updatedAt) ??
      slidesEpochUtc;

  /// Snapshot author.
  String? get updatedBy => str(ChartLinkCols.updatedBy);

  /// Update automatically.
  bool get autoUpdate => flag(ChartLinkCols.autoUpdate);
}
