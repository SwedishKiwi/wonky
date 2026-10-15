import 'dart:convert';

import '../model/api/deck_model.dart';
import '../model/index/deck_indexes.dart';
import '../model/text/slides_text.dart';
import '../theme/layout/placeholder_type.dart';

/// Who changed what between two version captures (Slides 09 §4.1,
/// `SlidesSnapshotIndex.changesJson`): built on the server from the
/// `DeckChangeLog` rows consumed since the previous capture (their
/// `summaryJson` and author), read by the history view to color changes in
/// their author's presence color (09 §4.3 "Author attribution").
///
/// Author lists are in the order of the authors' latest change: the last
/// one is the latest author (a later edit wins the color).
final class SlidesVersionChanges {
  /// Creates the changes.
  const SlidesVersionChanges({
    this.slides = const {},
    this.elements = const {},
    this.groups = const {},
    this.theme = const [],
    this.deck = const [],
    this.agents = const {},
    this.approx = false,
  });

  /// No attribution (old versions, offline, errors).
  static const empty = SlidesVersionChanges();

  /// Format version of [toJson].
  static const int version = 1;

  /// Slide id → author ids (user profile ids).
  final Map<String, List<int>> slides;

  /// Element id → author ids.
  final Map<String, List<int>> elements;

  /// Group id → author ids (groups deleted or revived; other group changes
  /// are not listed in change summaries).
  final Map<String, List<int>> groups;

  /// Authors of theme, master and layout changes.
  final List<int> theme;

  /// Authors of deck-level changes (title, size, numbering).
  final List<int> deck;

  /// Authors who edited through an agent (MCP, AI) in the window, with the
  /// actor kinds (`mcp`, `ai`): shown as "Claude via MCP (Anna)".
  final Map<int, Set<String>> agents;

  /// Whether rows were dropped (very busy windows) or summaries overflowed.
  final bool approx;

  /// The latest author of [slideId] (null when unknown).
  int? latestOfSlide(String slideId) => slides[slideId]?.lastOrNull;

  /// The latest author of [elementId] (null when unknown).
  int? latestOfElement(String elementId) => elements[elementId]?.lastOrNull;

  /// Every author named anywhere.
  Set<int> get authors => {
    for (final l in slides.values) ...l,
    for (final l in elements.values) ...l,
    for (final l in groups.values) ...l,
    ...theme,
    ...deck,
  };

  /// JSON map.
  Map<String, Object?> toJson() => {
    'v': version,
    if (approx) 'approx': true,
    'slides': slides,
    'elements': elements,
    if (groups.isNotEmpty) 'groups': groups,
    if (theme.isNotEmpty) 'theme': theme,
    if (deck.isNotEmpty) 'deck': deck,
    if (agents.isNotEmpty)
      'agents': {
        for (final e in agents.entries) '${e.key}': e.value.toList()..sort(),
      },
  };

  /// JSON text.
  String encode() => jsonEncode(toJson());

  /// Parses [json] leniently (malformed parts read as empty).
  static SlidesVersionChanges parse(String? json) {
    if (json == null || json.isEmpty) return empty;
    Object? m;
    try {
      m = jsonDecode(json);
    } on FormatException {
      return empty;
    }
    if (m is! Map) return empty;
    Map<String, List<int>> ids(Object? v) => {
      if (v is Map)
        for (final e in v.entries)
          if (e.value is List)
            '${e.key}': [
              for (final x in e.value as List)
                if (x is num) x.toInt(),
            ],
    };
    List<int> list(Object? v) => [
      if (v is List)
        for (final x in v)
          if (x is num) x.toInt(),
    ];
    final agents = <int, Set<String>>{};
    final a = m['agents'];
    if (a is Map) {
      for (final e in a.entries) {
        final id = int.tryParse('${e.key}');
        if (id == null || e.value is! List) continue;
        agents[id] = {for (final k in e.value as List) '$k'};
      }
    }
    return SlidesVersionChanges(
      slides: ids(m['slides']),
      elements: ids(m['elements']),
      groups: ids(m['groups']),
      theme: list(m['theme']),
      deck: list(m['deck']),
      agents: agents,
      approx: m['approx'] == true,
    );
  }
}

/// Builds [SlidesVersionChanges] from change-log rows, oldest first
/// ([add] each row's `summaryJson` with its author).
final class SlidesVersionChangesBuilder {
  /// Max slides/elements attributed (then [SlidesVersionChanges.approx]).
  static const maxIds = 5000;

  final Map<String, List<int>> _slides = {};
  final Map<String, List<int>> _elements = {};
  final Map<String, List<int>> _groups = {};
  final List<int> _theme = [];
  final List<int> _deck = [];
  final Map<int, Set<String>> _agents = {};
  bool _approx = false;

  /// Marks the result approximate (rows were left out).
  void markApprox() => _approx = true;

  static void _touch(List<int> list, int author) {
    list
      ..remove(author)
      ..add(author);
  }

  void _id(Map<String, List<int>> m, String id, int author) {
    final list = m[id];
    if (list == null && m.length >= maxIds) {
      _approx = true;
      return;
    }
    _touch(list ?? (m[id] = []), author);
  }

  /// Adds one change-log row: its `summaryJson` (Slides 02 §3.10.1), the
  /// author's user profile id and the actor kind (`user`, `mcp`, `ai`, …).
  void add(String summaryJson, int author, {String actorKind = 'user'}) {
    Object? m;
    try {
      m = jsonDecode(summaryJson);
    } on FormatException {
      _approx = true;
      return;
    }
    if (m is! Map) return;
    List<String> strings(Object? v) => [
      if (v is List)
        for (final x in v)
          if (x is String) x,
    ];
    if (actorKind == 'mcp' || actorKind == 'ai') {
      (_agents[author] ??= {}).add(actorKind);
    }
    for (final id in strings(m['slides'])) {
      _id(_slides, id, author);
    }
    for (final id in strings(m['elements'])) {
      _id(_elements, id, author);
    }
    final deleted = m['deleted'];
    final revived = m['revived'];
    for (final cat in [deleted, revived]) {
      if (cat is! Map) continue;
      for (final id in strings(cat['slides'])) {
        _id(_slides, id, author);
      }
      for (final id in strings(cat['elements'])) {
        _id(_elements, id, author);
      }
      for (final id in strings(cat['groups'])) {
        _id(_groups, id, author);
      }
    }
    final kinds = strings(m['kinds']);
    if (kinds.contains('theme')) _touch(_theme, author);
    if (kinds.contains('deck')) _touch(_deck, author);
    if (m['slidesOverflow'] == true || m['elementsOverflow'] == true) {
      _approx = true;
    }
  }

  /// The changes so far.
  SlidesVersionChanges build() => SlidesVersionChanges(
    slides: {for (final e in _slides.entries) e.key: List.of(e.value)},
    elements: {for (final e in _elements.entries) e.key: List.of(e.value)},
    groups: {for (final e in _groups.entries) e.key: List.of(e.value)},
    theme: List.of(_theme),
    deck: List.of(_deck),
    agents: {for (final e in _agents.entries) e.key: Set.of(e.value)},
    approx: _approx,
  );
}

/// One slide of a version's slide list (`SlidesSnapshotIndex.slidesJson`,
/// 09 §4.1): id, title, group and effective skip, in presentation order.
final class SnapshotSlideEntry {
  /// Creates an entry.
  const SnapshotSlideEntry({
    required this.id,
    required this.title,
    this.groupId,
    this.groupTitle,
    this.skipped = false,
  });

  final String id;

  /// Plain text of the title placeholder ('' when none).
  final String title;
  final String? groupId;
  final String? groupTitle;
  final bool skipped;

  /// JSON map.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'group': ?groupId,
    'groupTitle': ?groupTitle,
    if (skipped) 'skipped': true,
  };

  /// The slide list of [model] in presentation order.
  static List<SnapshotSlideEntry> listOf(DeckModel model) => [
    for (final e in model.indexes.order.entries)
      SnapshotSlideEntry(
        id: e.id,
        title: titleOf(model, e.id),
        groupId: e.groupId,
        groupTitle: e.groupId == null ? null : model.group(e.groupId!)?.title,
        skipped: e.skipped,
      ),
  ];

  /// JSON text of [listOf].
  static String encodeList(DeckModel model) =>
      jsonEncode([for (final s in listOf(model)) s.toJson()]);

  /// The plain text of the slide's title placeholder (first line).
  static String titleOf(DeckModel model, String slideId) {
    for (final e in model.elementsOf(slideId)) {
      if (e.placeholderType == SlidePlaceholderType.title) {
        return SlidesText.plainText(e.text).trim().split('\n').first;
      }
    }
    return '';
  }
}
