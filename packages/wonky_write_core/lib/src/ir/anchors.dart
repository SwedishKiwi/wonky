/// Heading anchor ids (`h-<slug>-<n>`, 07 §2.1).
library;

/// Generates unique heading anchor ids for one document.
///
/// The id of a heading is `h-<slug>-<n>` where `slug` is the lower-cased
/// heading text with runs of non-letter/digit characters replaced by `-`
/// (max 60 chars, `section` when empty) and `n` counts headings with the same
/// slug in document order, starting at 1.
final class AnchorIdGenerator {
  final _counts = <String, int>{};

  static final _nonWord = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  /// Slug of [text].
  static String slugify(String text) {
    var slug = text.toLowerCase().replaceAll(_nonWord, '-');
    slug = slug.replaceAll(RegExp('^-+|-+\$'), '');
    if (slug.length > 60) {
      slug = slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '');
      // Do not cut a surrogate pair in half.
      if (slug.isNotEmpty) {
        final last = slug.codeUnitAt(slug.length - 1);
        if (last >= 0xD800 && last <= 0xDBFF) {
          slug = slug.substring(0, slug.length - 1);
        }
      }
    }
    return slug.isEmpty ? 'section' : slug;
  }

  /// The next unique id for a heading with [text].
  String next(String text) {
    final slug = slugify(text);
    final n = (_counts[slug] ?? 0) + 1;
    _counts[slug] = n;
    return 'h-$slug-$n';
  }
}
