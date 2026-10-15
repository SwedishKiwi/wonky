/// Placeholder types (Slides 02 §3.11 `PlaceholderType`, 05 §4–§5).
library;

/// The type of a placeholder. Values match the synced `PlaceholderType` enum
/// by name (serialized by name, 02 §3.11).
enum SlidePlaceholderType {
  /// Slide title.
  title,

  /// Subtitle.
  subtitle,

  /// Body text (lists).
  body,

  /// Picture.
  picture,

  /// Chart (08).
  chart,

  /// Table.
  table,

  /// Code (07).
  code,

  /// Caption.
  caption,

  /// Big number.
  bigNumber,

  /// Quote.
  quote,

  /// Quote attribution.
  attribution,

  /// Slide number (drawn from the layout/master, not instantiated).
  slideNumber,

  /// Footer (drawn from the layout/master, not instantiated).
  footer,

  /// Date (P2; drawn from the layout/master, not instantiated).
  date,

  /// Any object.
  object;

  /// Parses a name; `null` when unknown.
  static SlidePlaceholderType? fromName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// Whether slides get an instance of this placeholder when a layout is
  /// applied (05 §5.2: slide number, footer and date are drawn directly).
  bool get isInstantiated =>
      this != slideNumber && this != footer && this != date;

  /// Whether the placeholder holds text.
  bool get holdsText => switch (this) {
    picture || chart || table || code || object => false,
    _ => true,
  };

  /// The theme text style used when nothing in the chain sets one (05 §5.3).
  String? get defaultStyleKey => switch (this) {
    title => 'title',
    subtitle => 'subtitle',
    body => 'body',
    caption => 'caption',
    bigNumber => 'bigNumber',
    quote => 'quote',
    attribution => 'attribution',
    slideNumber || footer || date => 'label',
    picture || chart || table || code || object => null,
  };
}
