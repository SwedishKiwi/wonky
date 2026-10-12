import '../../model/grid_range.dart';
import 'chart_type.dart';
import 'spec_json.dart';

/// Position of a logical column (row when switched) inside the data ranges (08 §3.2).
final class DataRef extends SpecNode {
  /// Creates a reference.
  const DataRef({this.range = 0, this.offset = 0, this.extras = const {}});

  /// Parses JSON leniently.
  factory DataRef.fromJson(Object? json) {
    final r = JsonReader(json);
    return DataRef(
      range: r.intOr('range', 0),
      offset: r.intOr('offset', 0),
      extras: r.extras(const {'range', 'offset'}),
    );
  }

  /// Index into `data.ranges`.
  final int range;

  /// Column (row when switched) index within that range.
  final int offset;
  final Map<String, Object?> extras;

  @override
  Map<String, Object?> toJson() => (JsonWriter(extras)
        ..put('range', range)
        ..put('offset', offset))
      .json;
}

/// The domain (X axis) column.
final class DomainRef extends SpecNode {
  /// Creates a domain reference. [key] (extension) is the source column id (row id when
  /// switched) so the domain survives columns inserted before it inside the range.
  const DomainRef({
    this.ref = const DataRef(),
    this.reverse = false,
    this.key,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory DomainRef.fromJson(Object? json) {
    final r = JsonReader(json);
    return DomainRef(
      ref: DataRef.fromJson(r.obj('ref')),
      reverse: r.boolOr('reverse', false),
      key: r.str('key'),
      extras: r.extras(const {'ref', 'reverse', 'key'}),
    );
  }

  final DataRef ref;
  final bool reverse;
  final String? key;
  final Map<String, Object?> extras;

  /// Copy with changes.
  DomainRef copyWith({DataRef? ref, bool? reverse, String? key}) => DomainRef(
    ref: ref ?? this.ref,
    reverse: reverse ?? this.reverse,
    key: key ?? this.key,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() => (JsonWriter(extras)
        ..put('ref', ref.toJson())
        ..unlessDefault('reverse', reverse, false)
        ..opt('key', key))
      .json;
}

/// One series reference; [key] is the stable series key (source column id, row id when
/// switched) that `spec.series` styles are keyed by.
final class SeriesRef extends SpecNode {
  /// Creates a series reference.
  const SeriesRef({
    required this.key,
    this.ref = const DataRef(),
    this.hidden = false,
    this.extras = const {},
  });

  /// Parses JSON leniently (null when the key is missing).
  static SeriesRef? fromJson(Object? json) {
    final r = JsonReader(json);
    final key = r.str('key');
    if (key == null || key.isEmpty) return null;
    return SeriesRef(
      key: key,
      ref: DataRef.fromJson(r.obj('ref')),
      hidden: r.boolOr('hidden', false),
      extras: r.extras(const {'key', 'ref', 'hidden'}),
    );
  }

  final String key;
  final DataRef ref;

  /// Hidden/removed series: kept for keying (so the column is not re-added automatically) but
  /// not drawn.
  final bool hidden;
  final Map<String, Object?> extras;

  /// Copy with changes.
  SeriesRef copyWith({String? key, DataRef? ref, bool? hidden}) => SeriesRef(
    key: key ?? this.key,
    ref: ref ?? this.ref,
    hidden: hidden ?? this.hidden,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() => (JsonWriter(extras)
        ..put('key', key)
        ..put('ref', ref.toJson())
        ..unlessDefault('hidden', hidden, false))
      .json;
}

/// `data` section (08 §3.2).
final class ChartDataSpec extends SpecNode {
  /// Creates a data section.
  const ChartDataSpec({
    this.ranges = const [],
    this.switchRowsColumns = false,
    this.headerCount,
    this.useFirstColumnAsLabels = true,
    this.treatLabelsAsText = false,
    this.aggregate,
    this.domain,
    this.seriesRefs = const [],
    this.includeHidden = false,
    this.emptyCells = EmptyCellMode.gap,
    this.maxPoints,
    this.extras = const {},
  });

  /// Parses JSON leniently.
  factory ChartDataSpec.fromJson(Object? json) {
    final r = JsonReader(json);
    final ranges = r.list('ranges') ?? const [];
    final refs = r.list('seriesRefs') ?? const [];
    final domain = r.obj('domain');
    return ChartDataSpec(
      ranges: [
        for (final g in ranges)
          if (GridRange.tryParse(g) case final GridRange gr) gr,
      ],
      switchRowsColumns: r.boolOr('switchRowsColumns', false),
      headerCount: r.integer('headerCount'),
      useFirstColumnAsLabels: r.boolOr('useFirstColumnAsLabels', true),
      treatLabelsAsText: r.boolOr('treatLabelsAsText', false),
      aggregate: r.enumOrNull('aggregate', ChartAggregate.values),
      domain: domain == null ? null : DomainRef.fromJson(domain),
      seriesRefs: [
        for (final s in refs)
          if (SeriesRef.fromJson(s) case final SeriesRef sr) sr,
      ],
      includeHidden: r.boolOr('includeHidden', false),
      emptyCells: r.enumOr('emptyCells', EmptyCellMode.values, EmptyCellMode.gap),
      maxPoints: r.integer('maxPoints'),
      extras: r.extras(_keys),
    );
  }

  static const _keys = {
    'ranges',
    'switchRowsColumns',
    'headerCount',
    'useFirstColumnAsLabels',
    'treatLabelsAsText',
    'aggregate',
    'domain',
    'seriesRefs',
    'includeHidden',
    'emptyCells',
    'maxPoints',
  };

  /// Source ranges (≥ 1 for a valid chart).
  final List<GridRange> ranges;
  final bool switchRowsColumns;

  /// Header rows; null = auto-detect (08 §4.2).
  final int? headerCount;
  final bool useFirstColumnAsLabels;
  final bool treatLabelsAsText;
  final ChartAggregate? aggregate;

  /// Explicit domain; null = first column when [useFirstColumnAsLabels].
  final DomainRef? domain;

  /// Ordered series; empty = every non-domain column of the ranges.
  final List<SeriesRef> seriesRefs;
  final bool includeHidden;
  final EmptyCellMode emptyCells;

  /// Downsampling threshold override (08 §12).
  final int? maxPoints;
  final Map<String, Object?> extras;

  /// Copy with changes ([headerCount], [aggregate], [domain], [maxPoints] can be cleared with
  /// the `clear*` flags).
  ChartDataSpec copyWith({
    List<GridRange>? ranges,
    bool? switchRowsColumns,
    int? headerCount,
    bool clearHeaderCount = false,
    bool? useFirstColumnAsLabels,
    bool? treatLabelsAsText,
    ChartAggregate? aggregate,
    bool clearAggregate = false,
    DomainRef? domain,
    bool clearDomain = false,
    List<SeriesRef>? seriesRefs,
    bool? includeHidden,
    EmptyCellMode? emptyCells,
    int? maxPoints,
  }) => ChartDataSpec(
    ranges: ranges ?? this.ranges,
    switchRowsColumns: switchRowsColumns ?? this.switchRowsColumns,
    headerCount: clearHeaderCount ? null : (headerCount ?? this.headerCount),
    useFirstColumnAsLabels: useFirstColumnAsLabels ?? this.useFirstColumnAsLabels,
    treatLabelsAsText: treatLabelsAsText ?? this.treatLabelsAsText,
    aggregate: clearAggregate ? null : (aggregate ?? this.aggregate),
    domain: clearDomain ? null : (domain ?? this.domain),
    seriesRefs: seriesRefs ?? this.seriesRefs,
    includeHidden: includeHidden ?? this.includeHidden,
    emptyCells: emptyCells ?? this.emptyCells,
    maxPoints: maxPoints ?? this.maxPoints,
    extras: extras,
  );

  @override
  Map<String, Object?> toJson() => (JsonWriter(extras)
        ..put('ranges', [for (final r in ranges) r.toJson()])
        ..unlessDefault('switchRowsColumns', switchRowsColumns, false)
        ..opt('headerCount', headerCount)
        ..unlessDefault('useFirstColumnAsLabels', useFirstColumnAsLabels, true)
        ..unlessDefault('treatLabelsAsText', treatLabelsAsText, false)
        ..opt('aggregate', aggregate?.name)
        ..opt('domain', domain?.toJson())
        ..put('seriesRefs', [for (final s in seriesRefs) s.toJson()])
        ..unlessDefault('includeHidden', includeHidden, false)
        ..unlessDefault('emptyCells', emptyCells.name, EmptyCellMode.gap.name)
        ..opt('maxPoints', maxPoints))
      .json;
}
