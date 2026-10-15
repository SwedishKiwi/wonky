import 'code_tokenizer.dart';
import 'default_code_tokenizer.dart';

/// A [CodeTokenizer] that remembers recent results per (language, text)
/// (Slides 07 §14: "cached per (text hash, language)"): thumbnails, the
/// canvas, present mode and type-in frames tokenize the same states again
/// and again.
///
/// A small LRU of whole results; texts are compared in full on a hash hit,
/// so a collision never returns wrong tokens.
final class CachedCodeTokenizer implements CodeTokenizer {
  /// Wraps [inner] (default [DefaultCodeTokenizer]) with an LRU of
  /// [capacity] entries.
  CachedCodeTokenizer({CodeTokenizer? inner, this.capacity = 64})
    : inner = inner ?? DefaultCodeTokenizer.instance;

  /// The shared cache over [DefaultCodeTokenizer].
  static final CachedCodeTokenizer shared = CachedCodeTokenizer();

  /// The tokenizer doing the work.
  final CodeTokenizer inner;

  /// Maximum number of cached results.
  final int capacity;

  // Insertion-ordered (a map literal is a LinkedHashMap): the first key is
  // the least recently used.
  final _entries = <(String, int), List<(String, List<CodeToken>)>>{};
  var _size = 0;

  /// Cache hits since creation (tests, diagnostics).
  int hits = 0;

  /// Cache misses since creation.
  int misses = 0;

  @override
  bool supports(String language) => inner.supports(language);

  @override
  List<CodeToken> tokenize(String code, String language) {
    final key = (language, code.hashCode);
    final bucket = _entries.remove(key);
    if (bucket != null) {
      _entries[key] = bucket; // most recently used
      for (final (text, tokens) in bucket) {
        if (text == code) {
          hits++;
          return tokens;
        }
      }
    }
    misses++;
    final tokens = List<CodeToken>.unmodifiable(inner.tokenize(code, language));
    (_entries[key] ??= []).add((code, tokens));
    _size++;
    while (_size > capacity && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _size -= _entries.remove(oldest)!.length;
    }
    return tokens;
  }

  /// Forgets everything.
  void clear() {
    _entries.clear();
    _size = 0;
  }
}
