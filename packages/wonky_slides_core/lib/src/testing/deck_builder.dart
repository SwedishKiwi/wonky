import 'dart:convert';

import 'package:wonky_sync_models/ids.dart';

import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../schema/slides_schema.dart';
import '../theme/builtins/builtin_themes.dart';
import '../theme/builtins/theme_package.dart';
import '../planner/theme_copy.dart';
import '../theme/layout/placeholder_type.dart';

/// The user id fixtures act as.
const testUserId = '00000000-0000-7000-8000-0000000000aa';

/// A second user (collaborator scenarios).
const testUserId2 = '00000000-0000-7000-8000-0000000000bb';

/// The deck id fixtures use unless told otherwise.
const testDeckId = '01923456-789a-7bcd-8ef0-123456789abc';

/// The fixed time of fixture rows.
final DateTime testNow = DateTime.utc(2026, 10, 1, 12);

/// The rows of theme package [pkg] copied into deck [deckId] with the
/// deterministic ids of 02 §2.1 (`SlidesIds.themeCopyId/themePartId`):
/// theme, masters, layouts and their elements — the planner's
/// `ThemeCopy.packageRows` (what `CreateDeck`/`ImportTheme` write).
(List<SlidesRow>, ThemeCopyIds) themePackageRows(
  ThemePackage pkg, {
  required String deckId,
  required String sourceKey,
  required IdGenerator ids,
  required DateTime now,
  String? sortKey,
}) => ThemeCopy.packageRows(
  pkg,
  deckId: deckId,
  sourceKey: sourceKey,
  now: now,
  sortKey: sortKey,
);

/// Delta JSON of plain [text].
String deltaOf(String text) => jsonEncode([
  {'insert': text.endsWith('\n') ? text : '$text\n'},
]);

/// Builds deck fixtures as synced rows (tests of every Slides package,
/// suite 15 §4: deterministic ids and times):
///
/// ```dart
/// final b = DeckBuilder();
/// final s1 = b.slide(layoutKey: 'title', title: 'Hello');
/// final g = b.group('Intro');
/// final s2 = b.slide(groupId: g);
/// final box = b.shape(s2, x: 100, y: 100);
/// final model = b.build();
/// ```
///
/// The deck gets the built-in *Wonky* theme unless [theme] is called first.
final class DeckBuilder {
  /// Creates a builder for deck [deckId].
  DeckBuilder({
    this.deckId = testDeckId,
    IdGenerator? ids,
    DateTime? now,
    this.title = 'Test deck',
    this.userId = testUserId,
  }) : ids = ids ?? SequentialIdGenerator(),
       now = now ?? testNow;

  /// The deck id.
  final String deckId;

  /// Id generator (sequential by default).
  final IdGenerator ids;

  /// `createdAt` of every row.
  final DateTime now;

  /// Deck title.
  final String title;

  /// `createdBy`.
  final String userId;

  final List<SlidesRow> _rows = [];
  final Map<String, String?> _lastKey = {};
  ThemeCopyIds? _theme;

  /// The default theme's ids (copies *Wonky* when no theme was added).
  ThemeCopyIds get themeIds => _theme ??= theme();

  /// The next fractional key in key space [space].
  String nextKey(String space) =>
      _lastKey[space] = FractionalIndex.after(_lastKey[space]);

  /// Copies built-in theme [key] into the deck; the first one becomes the
  /// deck's default.
  ThemeCopyIds theme([String key = BuiltInThemes.defaultKey]) {
    final def = BuiltInThemes.byKey(key)!;
    final (rows, copy) = themePackageRows(
      BuiltInThemes.package(key)!,
      deckId: deckId,
      sourceKey: SlidesIds.builtinThemeSourceKey(key, def.version),
      ids: ids,
      now: now,
      sortKey: nextKey('themes'),
    );
    _rows.addAll(rows);
    return _theme ??= copy;
  }

  /// The layout id of [layoutKey] in the default theme.
  String layoutId(String layoutKey) =>
      themeIds.layoutIds[layoutKey] ??
      (throw ArgumentError.value(layoutKey, 'layoutKey', 'No such layout'));

  /// Adds a slide group in the top-level key space.
  String group(String title, {String? color, bool skipped = false}) {
    final id = ids.newId();
    _rows.add((
      SlidesTables.slideGroup,
      {
        SlidesCols.id: id,
        SlidesCols.deckId: deckId,
        SlidesCols.title: title,
        SlidesCols.sortKey: nextKey('top'),
        SlidesCols.parentId: null,
        SlideGroupCols.color: color,
        SlidesCols.skipped: skipped,
        SlidesCols.createdAt: now,
      },
    ));
    return id;
  }

  /// Adds a slide at the end of the top level or of group [groupId], with
  /// the placeholder instances of its layout; [title]/[body] fill the
  /// title/body placeholders.
  String slide({
    String layoutKey = 'titleBody',
    String? groupId,
    String? title,
    String? body,
    String? notes,
    bool skipped = false,
  }) {
    final id = ids.newId();
    final layout = layoutId(layoutKey);
    _rows.add((
      SlidesTables.slide,
      {
        SlidesCols.id: id,
        SlidesCols.deckId: deckId,
        SlidesCols.sortKey: nextKey(groupId ?? 'top'),
        SlideCols.groupId: groupId,
        SlideCols.layoutId: layout,
        SlidesCols.backgroundJson: null,
        SlidesCols.skipped: skipped,
        SlideCols.notes: notes == null ? null : deltaOf(notes),
        SlidesCols.transitionJson: null,
        SlidesCols.hideMasterElements: null,
        SlideCols.timingsJson: null,
        SlidesCols.createdAt: now,
      },
    ));
    // Placeholder instances (05 §5.2).
    for (final (t, c) in List.of(_rows)) {
      if (t != SlidesTables.slideElement || c[ElementCols.layoutId] != layout) {
        continue;
      }
      final type = SlidePlaceholderType.fromName(
        c[ElementCols.placeholderType],
      );
      if (type == null || !type.isInstantiated) continue;
      final text = switch (type) {
        SlidePlaceholderType.title => title,
        SlidePlaceholderType.body => body,
        _ => null,
      };
      _rows.add((
        SlidesTables.slideElement,
        {
          ...elementDefaults(),
          SlidesCols.id: SlidesIds.placeholderInstanceId(
            id,
            c[SlidesCols.id]! as String,
          ),
          SlidesCols.slideId: id,
          SlidesCols.kind: c[SlidesCols.kind],
          ElementCols.placeholderType: type.name,
          ElementCols.placeholderOf: c[SlidesCols.id],
          ElementCols.zKey: nextKey('z:$id'),
          ElementCols.matchKey: SlidesIds.newMatchKey(ids),
          SlidesCols.text: text == null ? null : deltaOf(text),
          SlidesCols.createdAt: now,
        },
      ));
    }
    return id;
  }

  /// Adds an element of [kind] to owner [ownerId] (a slide unless
  /// [ownerKind] says otherwise) on top of its siblings.
  String element(
    String ownerId,
    ElementKind kind, {
    double x = 100,
    double y = 100,
    double width = 400,
    double height = 200,
    double? rotation,
    String? parentId,
    ElementOwnerKind ownerKind = ElementOwnerKind.slide,
    Map<String, Object?> columns = const {},
    String? id,
  }) {
    final elementId = id ?? ids.newId();
    _rows.add((
      SlidesTables.slideElement,
      {
        ...elementDefaults(),
        SlidesCols.id: elementId,
        switch (ownerKind) {
          ElementOwnerKind.slide => SlidesCols.slideId,
          ElementOwnerKind.layout => ElementCols.layoutId,
          ElementOwnerKind.master => ElementCols.masterId,
        }: ownerId,
        SlidesCols.parentId: parentId,
        SlidesCols.kind: kind.name,
        ElementCols.x: x,
        ElementCols.y: y,
        ElementCols.width: width,
        ElementCols.height: height,
        ElementCols.rotation: rotation,
        ElementCols.zKey: nextKey('z:$ownerId:${parentId ?? ''}'),
        ElementCols.matchKey: SlidesIds.newMatchKey(ids),
        SlidesCols.createdAt: now,
        ...columns,
      },
    ));
    return elementId;
  }

  /// Adds a shape (rect by default) with optional [text].
  String shape(
    String slideId, {
    double x = 100,
    double y = 100,
    double width = 400,
    double height = 200,
    String geometry = 'rect',
    String? text,
    String? fillJson,
    String? parentId,
  }) => element(
    slideId,
    ElementKind.shape,
    x: x,
    y: y,
    width: width,
    height: height,
    parentId: parentId,
    columns: {
      ElementCols.dataJson: jsonEncode({'v': 1, 'geometry': geometry}),
      if (text != null) SlidesCols.text: deltaOf(text),
      ElementCols.fillJson: ?fillJson,
    },
  );

  /// Adds a text box.
  String textBox(
    String slideId,
    String text, {
    double x = 100,
    double y = 100,
    double width = 600,
    double height = 120,
  }) => element(
    slideId,
    ElementKind.text,
    x: x,
    y: y,
    width: width,
    height: height,
    columns: {SlidesCols.text: deltaOf(text)},
  );

  /// Adds an element group of [childIds] (already added with [parentId] =
  /// the returned id; use [groupId] to preset the id).
  String elementGroup(
    String slideId, {
    required String groupId,
    double x = 0,
    double y = 0,
    double width = 1000,
    double height = 600,
  }) => element(
    slideId,
    ElementKind.group,
    id: groupId,
    x: x,
    y: y,
    width: width,
    height: height,
    columns: {
      ElementCols.dataJson: jsonEncode({
        'v': 1,
        'childBounds': {'x': x, 'y': y, 'w': width, 'h': height},
      }),
    },
  );

  /// Adds a [rows] × [cols] table; returns the element id and the axis ids.
  (String elementId, List<String> rowIds, List<String> columnIds) table(
    String slideId, {
    int rows = 2,
    int cols = 2,
    double x = 100,
    double y = 100,
    double width = 800,
    double height = 300,
  }) {
    final el = element(
      slideId,
      ElementKind.table,
      x: x,
      y: y,
      width: width,
      height: height,
      columns: {
        ElementCols.dataJson: jsonEncode({'v': 1, 'style': 'theme'}),
      },
    );
    List<String> axes(TableAxisDimension d, int n) => [
      for (var i = 0; i < n; i++) _axis(el, d),
    ];
    return (
      el,
      axes(TableAxisDimension.row, rows),
      axes(TableAxisDimension.column, cols),
    );
  }

  String _axis(String elementId, TableAxisDimension d) {
    final id = ids.newId();
    _rows.add((
      SlidesTables.slideTableAxis,
      {
        SlidesCols.id: id,
        SlidesCols.elementId: elementId,
        TableAxisCols.dimension: d.name,
        SlidesCols.sortKey: nextKey('axis:$elementId:${d.name}'),
        TableAxisCols.size: null,
        TableAxisCols.header: false,
        SlidesCols.createdAt: now,
      },
    ));
    return id;
  }

  /// Adds a table cell with [text] (deterministic id).
  String cell(String elementId, String rowId, String columnId, String text) {
    final id = SlidesIds.tableCellId(elementId, rowId, columnId);
    _rows.add((
      SlidesTables.slideTableCell,
      {
        for (final c in SlidesTables.columns[SlidesTables.slideTableCell]!)
          c: null,
        SlidesCols.id: id,
        SlidesCols.elementId: elementId,
        TableCellCols.rowId: rowId,
        TableCellCols.columnId: columnId,
        SlidesCols.text: deltaOf(text),
        SlidesCols.createdAt: now,
      },
    ));
    return id;
  }

  /// Adds a build on [slideId] for [elementId].
  String build_(
    String slideId,
    String elementId, {
    SlideBuildKind kind = SlideBuildKind.buildIn,
    String effect = 'fade',
    SlideBuildTrigger trigger = SlideBuildTrigger.onClick,
    int durationMs = 500,
    int delayMs = 0,
    String easing = 'easeOut',
    String? optionsJson,
  }) {
    final id = ids.newId();
    _rows.add((
      SlidesTables.slideBuild,
      {
        SlidesCols.id: id,
        SlidesCols.slideId: slideId,
        SlidesCols.elementId: elementId,
        SlidesCols.kind: kind.name,
        BuildCols.effect: effect,
        SlidesCols.sortKey: nextKey('build:$slideId'),
        BuildCols.trigger: trigger.name,
        BuildCols.delayMs: delayMs,
        BuildCols.durationMs: durationMs,
        BuildCols.easing: easing,
        BuildCols.optionsJson: optionsJson,
        SlidesCols.createdAt: now,
      },
    ));
    return id;
  }

  /// The `deck` row.
  SlidesRow get deckRow => (
    SlidesTables.deck,
    {
      SlidesCols.id: deckId,
      DeckCols.title: title,
      DeckCols.width: 1920.0,
      DeckCols.height: 1080.0,
      DeckCols.sizePreset: 'widescreen16x9',
      DeckCols.themeId: themeIds.themeId,
      DeckCols.appearance: 'light',
      DeckCols.language: null,
      DeckCols.showSlideNumbers: false,
      DeckCols.hideNumberOnTitle: true,
      DeckCols.firstSlideNumber: 1,
      DeckCols.footerText: null,
      DeckCols.defaultsJson: null,
      DeckCols.guidesJson: null,
      DeckCols.presentJson: null,
      DeckCols.createdBy: userId,
      SlidesCols.createdAt: now,
    },
  );

  /// Every row: the deck row first, then the others in insertion order.
  List<SlidesRow> get rows {
    final deck = deckRow;
    return [deck, ..._rows];
  }

  /// A model of [rows].
  DeckModel build() => DeckModel.fromRows(deckId, rows);
}
