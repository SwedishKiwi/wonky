/// Enum-like column values of the Slides tables (02 §3.11) as core enums,
/// independent of the generated Serverpod enums (values match by name).
library;

/// `SlideElement.kind` (02 §3.11 `SlideElementKind`).
enum ElementKind {
  /// Text box.
  text,

  /// Geometric shape (may hold text).
  shape,

  /// Line, arrow or connector.
  line,

  /// Image.
  image,

  /// Table (axes and cells are rows of their own).
  table,

  /// Icon (Lucide or emoji).
  icon,

  /// Code block (07).
  code,

  /// Chart (08).
  chart,

  /// Element group (children reference it as `parentId`).
  group;

  /// The kind named [name], or null.
  static ElementKind? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }

  /// Whether elements of this kind hold a rich text body in `text`.
  bool get hasText => this == text || this == shape;
}

/// `SlideBuild.kind` (02 §3.11 `BuildKind`, 06 §2).
enum SlideBuildKind {
  /// Appears.
  buildIn,

  /// Disappears.
  buildOut,

  /// Emphasis.
  emphasis,

  /// Motion path.
  motion;

  /// The kind named [name], or null.
  static SlideBuildKind? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// `SlideBuild.trigger` (02 §3.11 `BuildTrigger`, 06 §4.1).
enum SlideBuildTrigger {
  /// On click (a new step).
  onClick,

  /// With the previous build.
  withPrevious,

  /// After the previous build.
  afterPrevious,

  /// On click of another element (interactive decks, P2; schema S-2
  /// reserves the value). The timeline skips such builds and the planner
  /// refuses to write it.
  onElementClick;

  /// The trigger named [name], or null.
  static SlideBuildTrigger? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// `SlideTableAxis.dimension` (02 §3.6 `TableDimension`).
enum TableAxisDimension {
  /// A table row.
  row,

  /// A table column.
  column;

  /// The dimension named [name], or null.
  static TableAxisDimension? fromName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// Which kind of row owns a `SlideElement` (02 §3.5: exactly one of
/// `slideId`, `layoutId`, `masterId` is set).
enum ElementOwnerKind {
  /// A slide.
  slide,

  /// A layout of a master.
  layout,

  /// A master.
  master,
}
