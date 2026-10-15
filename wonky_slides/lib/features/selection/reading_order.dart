import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

/// The reading order of a slide's elements (03 §17.2), used by Tab cycling
/// (§3.3) and the canvas semantics.
///
/// When any element has a `readingKey`, the keyed elements come first in
/// key order, then the others automatically. Automatic order: title
/// placeholder, subtitle, then visual rows (vertical centers within 10 % of
/// the slide height form a row; rows top → bottom, left → right inside a
/// row; right → left with [rtl]), slide number/footer/date last. Hidden
/// elements are excluded, decorative ones too unless [includeDecorative].
/// With [custom] false the `readingKey`s are ignored (the automatic order,
/// for the accessibility checker's comparison, SL-34).
abstract final class ReadingOrder {
  static int _rank(ResolvedElement e) => switch (e.placeholderType) {
    SlidePlaceholderType.title => 0,
    SlidePlaceholderType.subtitle => 1,
    SlidePlaceholderType.slideNumber ||
    SlidePlaceholderType.footer ||
    SlidePlaceholderType.date => 3,
    _ => 2,
  };

  /// [elements] (siblings, slide space) in reading order.
  static List<ResolvedElement> of(
    List<ResolvedElement> elements, {
    required double slideHeight,
    bool rtl = false,
    bool includeDecorative = true,
    bool custom = true,
  }) {
    final visible = [
      for (final e in elements)
        if (!e.hidden && (includeDecorative || !e.record.decorative)) e,
    ];
    final keyed = [
      for (final e in visible)
        if (custom && e.record.readingKey != null) e,
    ]..sort((a, b) => a.record.readingKey!.compareTo(b.record.readingKey!));
    final rest = [
      for (final e in visible)
        if (!custom || e.record.readingKey == null) e,
    ];
    return [...keyed, ..._automatic(rest, slideHeight, rtl)];
  }

  static List<ResolvedElement> _automatic(
    List<ResolvedElement> list,
    double slideHeight,
    bool rtl,
  ) {
    final band = slideHeight * 0.1;
    double cy(ResolvedElement e) => e.frame.y + e.frame.height / 2;
    double cx(ResolvedElement e) => e.frame.x + e.frame.width / 2;
    final out = <ResolvedElement>[];
    for (final rank in [0, 1, 2, 3]) {
      final group = [
        for (final e in list)
          if (_rank(e) == rank) e,
      ]..sort((a, b) => cy(a).compareTo(cy(b)));
      // Rows: consecutive (by center y) elements within the band of the
      // row's first element.
      final rows = <List<ResolvedElement>>[];
      for (final e in group) {
        if (rows.isNotEmpty && (cy(e) - cy(rows.last.first)).abs() <= band) {
          rows.last.add(e);
        } else {
          rows.add([e]);
        }
      }
      for (final row in rows) {
        row.sort(
          (a, b) => rtl ? cx(b).compareTo(cx(a)) : cx(a).compareTo(cx(b)),
        );
        out.addAll(row);
      }
    }
    return out;
  }
}
