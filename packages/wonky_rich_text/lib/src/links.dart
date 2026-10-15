/// Link and image source policies shared by validator, normalizer, codecs.
library;

/// Rules for `link` attribute values and image sources.
///
/// Canonical URLs are fixed points of CommonMark link-destination
/// normalization: existing `%XX` escapes are kept and every other character
/// outside the URI reserved/unreserved set (spaces, non-ASCII, `<>"\^`{|}`) is
/// percent-encoded (UTF-8). This makes URLs survive Markdown round trips.
abstract final class LinkPolicy {
  /// URL schemes allowed for `link`.
  static const linkSchemes = {'http', 'https', 'mailto', 'wonky', 'tel', 'ftp'};

  /// Source prefixes allowed for image embeds.
  static const imageSourcePrefixes = [
    'wonky-file://',
    'https://',
    'http://',
    'import-image://',
  ];

  static final _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');
  static final _percent = RegExp('%[0-9A-Fa-f]{2}');

  /// Percent-encodes [url] into canonical form (idempotent).
  static String canonicalUrl(String url) => url.splitMapJoin(
    _percent,
    onMatch: (m) => m[0]!,
    onNonMatch: (s) => _encodeFull(s),
  );

  static String _encodeFull(String s) {
    // Uri.encodeFull throws on lone surrogates; replace them first.
    final b = StringBuffer();
    for (final rune in s.runes) {
      b.writeCharCode(rune >= 0xD800 && rune <= 0xDFFF ? 0xFFFD : rune);
    }
    return Uri.encodeFull(b.toString());
  }

  /// Whether [url] is a canonical, allowed link target.
  static bool isValidLink(String url) {
    if (url.isEmpty || url.length > 4096) return false;
    if (canonicalUrl(url) != url) return false;
    final m = _scheme.firstMatch(url);
    if (m == null) return false;
    final scheme = m.group(1)!;
    if (!linkSchemes.contains(scheme)) return false;
    if ((scheme == 'http' || scheme == 'https' || scheme == 'ftp') &&
        (!url.startsWith('$scheme://') || url.length == scheme.length + 3)) {
      return false;
    }
    if (url.length == m.end) return false;
    return Uri.tryParse(url) != null;
  }

  /// Canonicalizes a link: trims, lower-cases the scheme and percent-encodes.
  /// Returns `null` when the link cannot be made valid (unknown scheme such
  /// as `javascript:`, relative URL).
  static String? normalizeLink(String url) {
    var u = url.trim();
    final m = _scheme.firstMatch(u);
    if (m == null) return null;
    u = m.group(1)!.toLowerCase() + u.substring(m.group(1)!.length);
    u = canonicalUrl(u);
    return isValidLink(u) ? u : null;
  }

  /// Whether [src] is a valid, canonical image source.
  static bool isValidImageSource(String src) {
    if (src.isEmpty || src.length > 4096) return false;
    if (canonicalUrl(src) != src) return false;
    for (final p in imageSourcePrefixes) {
      if (src.startsWith(p)) return src.length > p.length;
    }
    return false;
  }

  /// Canonicalizes an image source; `null` when not allowed.
  static String? normalizeImageSource(String src) {
    final u = canonicalUrl(src.trim());
    return isValidImageSource(u) ? u : null;
  }

  /// Whether [url] is a `mailto:` link.
  static bool isMailto(String url) => url.startsWith('mailto:');
}
