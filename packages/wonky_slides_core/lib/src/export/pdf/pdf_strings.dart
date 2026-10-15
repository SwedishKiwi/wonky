/// The texts a Slides PDF prints itself (bookmarks, notes/handout headers
/// and footers). English defaults; the app passes its localized strings.
library;

String _slide(int n) => 'Slide $n';
String _continued(int n) => 'Notes (continued) — Slide $n';
String _pageOf(int page, int count) => 'Page $page of $count';

/// Texts of Slides PDFs (10 §11.2).
final class SlidesPdfStrings {
  /// Creates strings (English by default).
  const SlidesPdfStrings({
    this.slide = _slide,
    this.notesContinued = _continued,
    this.pageOf = _pageOf,
    this.untitledGroup = 'Untitled section',
    this.untitledDeck = 'Untitled presentation',
  });

  /// A slide's bookmark title without a title placeholder ("Slide 7").
  final String Function(int number) slide;

  /// The heading of a notes continuation page.
  final String Function(int number) notesContinued;

  /// The footer of notes/handout pages ("Page 2 of 9").
  final String Function(int page, int count) pageOf;

  /// The bookmark of a group without a title.
  final String untitledGroup;

  /// The title of a deck without one.
  final String untitledDeck;
}
