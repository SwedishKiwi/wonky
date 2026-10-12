/// Suggestion views: accepted / original (08 §2.6, 07 §2.1).
library;

import 'package:dart_quill_delta/dart_quill_delta.dart';

import '../delta/attributes.dart';
import '../delta/delta_utils.dart';
import '../delta/normalizer.dart';

/// Which view of pending suggestions to render.
enum SuggestionViewMode {
  /// All suggestions accepted: `del` text dropped, `ins` text kept,
  /// formatting suggestions keep the new attributes.
  accepted,

  /// All suggestions rejected: `ins` text dropped, `del` text kept,
  /// formatting suggestions restore `before`.
  original,

  /// The document as stored (suggestion attributes kept).
  raw,
}

/// Renders suggestion views of a document.
abstract final class SuggestionView {
  /// The document with all suggestions accepted (overlays `sug_*` removed;
  /// `cmt_*` kept unless [stripComments]).
  static Delta accepted(Delta document, {bool stripComments = false}) => render(
    document,
    SuggestionViewMode.accepted,
    stripComments: stripComments,
  );

  /// The document with all suggestions rejected (the original text).
  static Delta original(Delta document, {bool stripComments = false}) => render(
    document,
    SuggestionViewMode.original,
    stripComments: stripComments,
  );

  /// Renders [document] in [mode]; the result is normalized.
  static Delta render(
    Delta document,
    SuggestionViewMode mode, {
    bool stripComments = false,
  }) {
    if (mode == SuggestionViewMode.raw) {
      return stripComments ? DeltaUtils.stripComments(document) : document;
    }
    final out = Delta();
    for (final op in _splitNewlines(document)) {
      final attrs = op.attributes;
      final marks = Attributes.suggestions(attrs);
      if (marks.isEmpty) {
        out.push(Operation.insert(op.data, _clean(attrs, stripComments)));
        continue;
      }
      final kinds = marks.values.map((m) => m.kind).toSet();
      if (mode == SuggestionViewMode.accepted &&
          kinds.contains(SuggestionKind.del)) {
        continue;
      }
      if (mode == SuggestionViewMode.original &&
          kinds.contains(SuggestionKind.ins)) {
        continue;
      }
      var result = Map<String, dynamic>.from(attrs ?? const {});
      if (mode == SuggestionViewMode.original) {
        // The oldest formatting suggestion holds the true original.
        final fmts =
            marks.values.where((m) => m.kind == SuggestionKind.fmt).toList()
              ..sort((a, b) => b.at.compareTo(a.at));
        for (final m in fmts) {
          final isNewline = op.data == '\n';
          final keys = isNewline ? WonkyAttr.blockKeys : WonkyAttr.inlineKeys;
          result.removeWhere((k, _) => keys.contains(k));
          for (final e in (m.before ?? const <String, dynamic>{}).entries) {
            if (keys.contains(e.key) && e.value != null) {
              result[e.key] = e.value;
            }
          }
        }
      }
      result.removeWhere((k, _) => WonkyAttr.isSuggestion(k));
      out.push(Operation.insert(op.data, _clean(result, stripComments)));
    }
    return const WonkyDeltaNormalizer().normalize(out).document;
  }

  /// Insert ops with every `"\n"` as its own op.
  static Iterable<Operation> _splitNewlines(Delta document) sync* {
    for (final op in document.operations) {
      if (!op.isInsert) continue;
      final data = op.data;
      if (data is! String || !data.contains('\n') || data == '\n') {
        yield op;
        continue;
      }
      var from = 0;
      while (from < data.length) {
        final nl = data.indexOf('\n', from);
        if (nl < 0) {
          yield Operation.insert(data.substring(from), op.attributes);
          break;
        }
        if (nl > from) {
          yield Operation.insert(data.substring(from, nl), op.attributes);
        }
        yield Operation.insert('\n', op.attributes);
        from = nl + 1;
      }
    }
  }

  static Map<String, dynamic>? _clean(
    Map<String, dynamic>? attrs,
    bool stripComments,
  ) {
    if (attrs == null || attrs.isEmpty) return null;
    final r = {
      for (final e in attrs.entries)
        if (!WonkyAttr.isSuggestion(e.key) &&
            !(stripComments && WonkyAttr.isComment(e.key)))
          e.key: e.value,
    };
    return r.isEmpty ? null : r;
  }
}
