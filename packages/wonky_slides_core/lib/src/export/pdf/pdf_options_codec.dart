/// JSON form, defaults per layout and copies of [SlidesPdfOptions] (10
/// §11.1): the print preview, the options dialog, the server endpoint's
/// `optionsJson`, MCP `slides.export_pdf` and the user's last-used options
/// (`slidesDefaults.exportOptions`, A-10-4) share it.
library;

import '../../interfaces/pdf.dart';

/// The page sizes in points (portrait width × height).
const Map<SlidesPdfPageSize, (double, double)> slidesPaperSizes = {
  SlidesPdfPageSize.letter: (612, 792),
  SlidesPdfPageSize.a4: (595.28, 841.89),
  SlidesPdfPageSize.legal: (612, 1008),
  SlidesPdfPageSize.a3: (841.89, 1190.55),
  SlidesPdfPageSize.tabloid: (792, 1224),
};

/// The handout grids (10 §11.2).
const List<int> slidesHandoutCounts = [1, 2, 3, 4, 6, 9];

/// Copies of options.
extension SlidesPdfOptionsCopy on SlidesPdfOptions {
  /// A copy with the given fields replaced ([groupIds]/[slideIds]/
  /// [fileName] are cleared with [clearGroupIds]/[clearSlideIds]/
  /// [clearFileName]).
  SlidesPdfOptions copyWith({
    SlidesPdfLayout? layout,
    int? handoutsPerPage,
    bool? handoutOrderVertical,
    bool? includeBuilds,
    bool? includeSkipped,
    String? range,
    List<String>? groupIds,
    bool clearGroupIds = false,
    List<String>? slideIds,
    bool clearSlideIds = false,
    SlidesPdfPageSize? pageSize,
    SlidesPdfOrientation? orientation,
    SlidesPdfMargins? margins,
    bool? frameSlides,
    bool? omitBackground,
    bool? headerDate,
    bool? headerTitle,
    bool? pageNumbers,
    bool? slideNumbers,
    bool? bookmarks,
    bool? links,
    bool? compact,
    bool? finalAnimationState,
    String? fileName,
    bool clearFileName = false,
  }) => SlidesPdfOptions(
    layout: layout ?? this.layout,
    handoutsPerPage: handoutsPerPage ?? this.handoutsPerPage,
    handoutOrderVertical: handoutOrderVertical ?? this.handoutOrderVertical,
    includeBuilds: includeBuilds ?? this.includeBuilds,
    includeSkipped: includeSkipped ?? this.includeSkipped,
    range: range ?? this.range,
    groupIds: clearGroupIds ? null : (groupIds ?? this.groupIds),
    slideIds: clearSlideIds ? null : (slideIds ?? this.slideIds),
    pageSize: pageSize ?? this.pageSize,
    orientation: orientation ?? this.orientation,
    margins: margins ?? this.margins,
    frameSlides: frameSlides ?? this.frameSlides,
    omitBackground: omitBackground ?? this.omitBackground,
    headerDate: headerDate ?? this.headerDate,
    headerTitle: headerTitle ?? this.headerTitle,
    pageNumbers: pageNumbers ?? this.pageNumbers,
    slideNumbers: slideNumbers ?? this.slideNumbers,
    bookmarks: bookmarks ?? this.bookmarks,
    links: links ?? this.links,
    compact: compact ?? this.compact,
    finalAnimationState: finalAnimationState ?? this.finalAnimationState,
    fileName: clearFileName ? null : (fileName ?? this.fileName),
  );

  /// Whether the notes/handout header and footer are on.
  bool get headerFooter => headerDate || headerTitle || pageNumbers;

  /// A copy switched to [layout] with that layout's defaults for paper,
  /// margins and frames (10 §11.1); the other options are kept.
  SlidesPdfOptions withLayout(SlidesPdfLayout layout, {String? locale}) {
    final paper = layout == SlidesPdfLayout.slides
        ? SlidesPdfPageSize.slide
        : SlidesPdfOptionsCodec.defaultPaper(locale);
    return copyWith(
      layout: layout,
      pageSize: paper,
      margins: paper == SlidesPdfPageSize.slide
          ? SlidesPdfMargins.none
          : SlidesPdfMargins.normal,
      frameSlides: layout == SlidesPdfLayout.handouts,
    );
  }
}

/// The JSON codec of [SlidesPdfOptions] (keys of 10 §11.1).
abstract final class SlidesPdfOptionsCodec {
  /// The paper of notes/handouts for [locale]: Letter in the US, Canada
  /// and the Americas that use it, A4 elsewhere.
  static SlidesPdfPageSize defaultPaper(String? locale) {
    final region = (locale ?? '').split(RegExp('[-_]')).skip(1).firstOrNull;
    const letter = {'US', 'CA', 'MX', 'PH', 'CL', 'CO', 'VE', 'PR'};
    if (region != null && letter.contains(region.toUpperCase())) {
      return SlidesPdfPageSize.letter;
    }
    if (locale == null || locale.isEmpty || locale == 'en') {
      return SlidesPdfPageSize.letter;
    }
    return SlidesPdfPageSize.a4;
  }

  /// The options of [json] (unknown keys and invalid values are ignored;
  /// missing keys take the defaults of the requested layout, [locale]
  /// picks the paper of notes/handouts).
  static SlidesPdfOptions fromJson(
    Map<String, Object?> json, {
    String? locale,
  }) {
    T? pick<T extends Enum>(List<T> values, Object? v) {
      if (v is! String) return null;
      for (final e in values) {
        if (e.name == v) return e;
      }
      return null;
    }

    bool? flag(String key) {
      final v = json[key];
      return v is bool ? v : null;
    }

    final layout =
        pick(SlidesPdfLayout.values, json['layout']) ?? SlidesPdfLayout.slides;
    final base = const SlidesPdfOptions().withLayout(layout, locale: locale);
    final n = json['handoutsPerPage'];
    final perPage = n is num && slidesHandoutCounts.contains(n.toInt())
        ? n.toInt()
        : base.handoutsPerPage;
    final rawRange = json['range'];
    var range = base.range;
    List<String>? groupIds;
    if (rawRange is String && isValidRange(rawRange)) range = rawRange.trim();
    if (rawRange is Map && rawRange['groupIds'] is List) {
      groupIds = [
        for (final g in rawRange['groupIds'] as List)
          if (g is String) g,
      ];
    }
    if (json['groupIds'] is List) {
      groupIds = [
        for (final g in json['groupIds'] as List)
          if (g is String) g,
      ];
    }
    final rawIds = json['slideIds'];
    final slideIds = rawIds is List
        ? [
            for (final s in rawIds)
              if (s is String) s,
          ]
        : null;
    final hf = json['headerFooter'];
    final hfMap = hf is Map ? hf.cast<String, Object?>() : null;
    bool hfFlag(String key, bool orElse) {
      if (hf is bool) return hf;
      final v = hfMap?[key];
      return v is bool ? v : orElse;
    }

    final pageSize = pick(SlidesPdfPageSize.values, json['pageSize']);
    final margins = pick(SlidesPdfMargins.values, json['margins']);
    final name = json['fileName'];
    return base.copyWith(
      handoutsPerPage: perPage,
      handoutOrderVertical: json['handoutOrder'] == 'vertical',
      includeBuilds: flag('includeBuilds'),
      includeSkipped: flag('includeSkipped'),
      range: range,
      groupIds: groupIds,
      slideIds: slideIds,
      pageSize: pageSize,
      orientation: pick(SlidesPdfOrientation.values, json['orientation']),
      margins:
          margins ??
          (pageSize == null
              ? null
              : pageSize == SlidesPdfPageSize.slide
              ? SlidesPdfMargins.none
              : SlidesPdfMargins.normal),
      frameSlides: flag('frameSlides'),
      omitBackground: json['background'] == 'omit',
      headerDate: hfFlag('date', base.headerDate),
      headerTitle: hfFlag('title', base.headerTitle),
      pageNumbers: hfFlag('pageNumbers', base.pageNumbers),
      slideNumbers: flag('slideNumbers'),
      bookmarks: flag('bookmarks'),
      links: flag('links'),
      compact: json['quality'] == 'compact',
      finalAnimationState: flag('finalAnimationState'),
      fileName: name is String && name.trim().isNotEmpty
          ? sanitizeFileName(name)
          : null,
    );
  }

  /// The JSON form of [o] (every key; `range` is `{groupIds}` when set).
  static Map<String, Object?> toJson(SlidesPdfOptions o) => {
    'layout': o.layout.name,
    'handoutsPerPage': o.handoutsPerPage,
    'handoutOrder': o.handoutOrderVertical ? 'vertical' : 'horizontal',
    'includeBuilds': o.includeBuilds,
    'includeSkipped': o.includeSkipped,
    'range': o.groupIds != null ? {'groupIds': o.groupIds} : o.range,
    if (o.slideIds != null) 'slideIds': o.slideIds,
    'pageSize': o.pageSize.name,
    'orientation': o.orientation.name,
    'margins': o.margins.name,
    'frameSlides': o.frameSlides,
    'background': o.omitBackground ? 'omit' : 'include',
    'headerFooter': {
      'date': o.headerDate,
      'title': o.headerTitle,
      'pageNumbers': o.pageNumbers,
    },
    'slideNumbers': o.slideNumbers,
    'bookmarks': o.bookmarks,
    'links': o.links,
    'quality': o.compact ? 'compact' : 'high',
    'finalAnimationState': o.finalAnimationState,
    if (o.fileName != null) 'fileName': o.fileName,
  };

  /// The options worth remembering as the user's last used (no per-deck
  /// selection: range, slide/group ids and file name are dropped).
  static Map<String, Object?> toPreferences(SlidesPdfOptions o) => toJson(o)
    ..remove('range')
    ..remove('slideIds')
    ..remove('fileName');

  static final _range = RegExp(
    r'^\s*\d+(\s*-\s*\d+)?(\s*,\s*\d+(\s*-\s*\d+)?)*\s*$',
  );

  /// Whether [range] is `all`, `current`, `selection` or deck positions
  /// (`"1-3,7"`).
  static bool isValidRange(String range) {
    final r = range.trim();
    return r == 'all' ||
        r == 'current' ||
        r == 'selection' ||
        _range.hasMatch(r);
  }

  /// The 0-based deck positions of a positions range (`"1-3,7"` → 0, 1, 2,
  /// 6), clamped to [count]; null for `all`/`current`/`selection` or an
  /// invalid range.
  static List<int>? positions(String range, int count) {
    if (!_range.hasMatch(range)) return null;
    final out = <int>{};
    for (final part in range.split(',')) {
      final ends = part.split('-').map((s) => int.parse(s.trim())).toList();
      final a = ends.first, b = ends.last;
      final lo = a < b ? a : b, hi = a < b ? b : a;
      for (var i = lo; i <= hi && i <= count; i++) {
        if (i >= 1) out.add(i - 1);
      }
    }
    return out.toList()..sort();
  }

  /// [name] without path separators and control characters, ≤ 120 chars
  /// (10 §11.1 `fileName`).
  static String sanitizeFileName(String name) {
    var s = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.toLowerCase().endsWith('.pdf')) s = s.substring(0, s.length - 4);
    if (s.length > 120) s = s.substring(0, 120).trim();
    return s.isEmpty ? 'Presentation' : s;
  }
}
