import '../model/api/deck_model.dart';
import '../model/api/kinds.dart';
import '../model/api/records.dart';
import '../model/index/deck_indexes.dart';
import '../model/text/slides_text.dart';
import '../ops/operations.dart';
import '../theme/layout/placeholder_type.dart';

/// One design idea for a slide (Slides 11 §6.6): another layout of the
/// slide's theme. Applying it is [op] (one undo step "Apply design idea").
final class DesignIdea {
  const DesignIdea({
    required this.id,
    required this.slideId,
    required this.layoutId,
    required this.layoutKey,
    required this.name,
    required this.score,
    required this.description,
  });

  /// Stable within a slide: the layout id.
  final String id;
  final String slideId;
  final String layoutId;

  /// The layout's key (null for custom layouts without one).
  final String? layoutKey;

  /// The layout's name.
  final String name;

  /// The deterministic fit, 0–1 (higher first).
  final double score;

  /// A short description for the AI ranking ("Big number: one large
  /// number with a caption").
  final String description;

  /// The operation that applies the idea.
  SlidesOperation get op => SetSlideProps([slideId], layoutId: layoutId);

  /// `id: description` (the ranking request line).
  String get rankLine => '$id: $name — $description';
}

/// What a slide holds, for [DesignIdeasEngine].
final class SlideContentProfile {
  SlideContentProfile._({
    required this.hasTitle,
    required this.bodies,
    required this.lines,
    required this.images,
    required this.code,
    required this.charts,
    required this.tables,
    required this.number,
    required this.quote,
    required this.title,
  });

  /// The profile of [slideId] in [m].
  factory SlideContentProfile.of(DeckModel m, String slideId) {
    var hasTitle = false;
    var title = '';
    var bodies = 0;
    var lines = 0;
    var images = 0, code = 0, charts = 0, tables = 0;
    final texts = <String>[];
    for (final e in m.allElementsOf(slideId)) {
      switch (e.kind) {
        case ElementKind.image:
          images++;
        case ElementKind.code:
          code++;
        case ElementKind.chart:
          charts++;
        case ElementKind.table:
          tables++;
        default:
      }
      final text = SlidesText.plainText(e.text).trim();
      if (text.isEmpty) continue;
      if (e.placeholderType == SlidePlaceholderType.title) {
        hasTitle = true;
        title = text;
        continue;
      }
      bodies++;
      final ls = [
        for (final l in text.split('\n'))
          if (l.trim().isNotEmpty) l.trim(),
      ];
      lines += ls.length;
      texts.addAll(ls);
    }
    final number =
        texts.isNotEmpty && texts.length <= 2 && _number.hasMatch(texts.first);
    final quote =
        texts.isNotEmpty &&
        texts.length <= 3 &&
        (texts.first.startsWith('"') ||
            texts.first.startsWith('“') ||
            texts.first.startsWith('«'));
    return SlideContentProfile._(
      hasTitle: hasTitle,
      bodies: bodies,
      lines: lines,
      images: images,
      code: code,
      charts: charts,
      tables: tables,
      number: number,
      quote: quote,
      title: title,
    );
  }

  static final _number = RegExp(
    r'^[\s$€£¥+\-~≈]*\d[\d.,\s]*\s*(%|x|×|k|K|M|B|bn|m)?\s*$',
  );

  final bool hasTitle;
  final String title;

  /// Text bodies other than the title.
  final int bodies;

  /// Non-empty text lines of those bodies.
  final int lines;
  final int images, code, charts, tables;

  /// A lone big number (first body line).
  final bool number;

  /// A quotation.
  final bool quote;

  bool get empty =>
      !hasTitle && bodies == 0 && images + code + charts + tables == 0;
}

/// The deterministic candidates of *Design ideas* (Slides 11 §6.6): the
/// visible layouts of the slide's theme that suit its content, scored by
/// simple rules (works without AI as "Layout ideas"; the AI only ranks
/// them). Candidates change no content: applying one changes the slide's
/// layout and the planner maps the content by placeholder type (05 §5.4).
abstract final class DesignIdeasEngine {
  /// Ideas below this score are left out.
  static const minScore = 0.2;

  /// The ideas for [slideId], best first (empty for an empty slide).
  static List<DesignIdea> candidates(DeckModel m, String slideId) {
    final slide = m.slide(slideId);
    if (slide == null) return const [];
    final p = SlideContentProfile.of(m, slideId);
    if (p.empty) return const [];
    final themes = m.indexes.themes;
    final current = themes.effectiveLayout(slide);
    final theme =
        (current == null ? null : themes.themeOfLayout(current)) ??
        themes.defaultTheme;
    if (theme == null) return const [];
    final out = <(DesignIdea, int)>[];
    var order = 0;
    for (final l in themes.layoutsOfTheme(theme.id)) {
      order++;
      if (l.hidden || l.id == current?.id) continue;
      final (score, description) = _score(l, p);
      if (score < minScore) continue;
      out.add((
        DesignIdea(
          id: l.id,
          slideId: slideId,
          layoutId: l.id,
          layoutKey: l.key,
          name: l.name,
          score: score,
          description: description,
        ),
        order,
      ));
    }
    out.sort((a, b) {
      final c = b.$1.score.compareTo(a.$1.score);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final (idea, _) in out) idea];
  }

  static (double, String) _score(SlideLayoutRec l, SlideContentProfile p) {
    final media = p.images + p.code + p.charts + p.tables;
    final textOnly = media == 0;
    final agendaTitle = RegExp(
      r'\b(agenda|overview|contents|outline|topics)\b',
      caseSensitive: false,
    ).hasMatch(p.title);
    return switch (l.key) {
      'title' => (
        p.bodies <= 1 && p.lines <= 2 && textOnly ? 0.55 : 0.1,
        'Title slide: a large title with a subtitle',
      ),
      'section' => (
        p.bodies == 0 && textOnly ? 0.8 : (p.lines <= 1 ? 0.4 : 0.1),
        'Section header: a large title that opens a part',
      ),
      'titleBody' => (
        p.lines >= 1 && p.lines <= 8 ? 0.7 : (p.lines > 8 ? 0.5 : 0.3),
        'Title and content: a title with bullets',
      ),
      'titleOnly' => (
        media > 0 ? 0.6 : 0.25,
        'Title only: a title above free content',
      ),
      'twoColumns' => (
        p.bodies >= 2 || p.lines >= 6 ? 0.75 : 0.3,
        'Two columns: the content split into two lists',
      ),
      'comparison' => (
        p.bodies >= 2 ? 0.65 : (p.lines >= 4 ? 0.4 : 0.15),
        'Comparison: two headed columns side by side',
      ),
      'bigNumber' => (
        p.number ? 0.9 : 0.1,
        'Big number: one large number with a caption',
      ),
      'quote' => (p.quote ? 0.9 : 0.15, 'Quote: a large quotation'),
      'statement' => (
        p.lines <= 2 && textOnly ? 0.6 : 0.15,
        'Statement: one short sentence, large and centered',
      ),
      'imageFull' => (
        p.images > 0 ? 0.7 : 0.0,
        'Full-bleed image with a caption over it',
      ),
      'imageLeft' => (
        p.images > 0 ? 0.8 : 0.0,
        'Image left, title and text right',
      ),
      'imageRight' => (
        p.images > 0 ? 0.8 : 0.0,
        'Image right, title and text left',
      ),
      'code' => (p.code > 0 ? 0.9 : 0.0, 'Code: a title above a code block'),
      'chart' => (p.charts > 0 ? 0.85 : 0.0, 'Chart: a title, chart, caption'),
      'agenda' => (
        p.lines >= 3 && p.lines <= 8 ? (agendaTitle ? 0.85 : 0.35) : 0.1,
        'Agenda: a numbered list of topics',
      ),
      'blank' => (0.0, 'Blank'),
      _ => (0.3, 'Custom layout "${l.name}"'),
    };
  }
}
