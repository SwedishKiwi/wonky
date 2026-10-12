import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:highlight/languages/all.dart' show allLanguages;
import 'package:super_editor/super_editor.dart';

import '../attributions/wonky_attributions.dart';
import '../mapping/wonky_schema.dart';
import 'write_stylesheet.dart';

/// Overlays presentation-only [CodeTokenAttribution]s on code block view
/// models (Write 04 §15.4). The document is never changed.
///
/// Results are cached per (node, text, language). Large blocks are tokenized
/// after a debounce so that typing stays responsive; until then the block
/// renders without highlighting.
class CodeHighlightStylePhase extends SingleColumnLayoutStylePhase {
  CodeHighlightStylePhase({this.debounce = const Duration(milliseconds: 120), this.syncLimit = 20000});

  final Duration debounce;

  /// Blocks up to this many characters are tokenized synchronously.
  final int syncLimit;

  final _cache = <String, _Highlighted>{};
  final _pending = <String, Timer>{};

  static final _languageIds = allLanguages.keys.toSet();

  @override
  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final model in viewModel.componentViewModels) _highlight(document, model),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _highlight(Document document, SingleColumnLayoutComponentViewModel model) {
    if (model is! TextComponentViewModel) return model;
    final node = document.getNodeById(model.nodeId);
    if (node == null || !isCodeBlockNode(node)) return model;
    final language = codeLanguageOf(node);
    if (!_languageIds.contains(language)) return model;
    final text = model.text;
    final plain = text.toPlainText(includePlaceholders: false);

    final cached = _cache[node.id];
    if (cached == null || cached.text != plain || cached.language != language) {
      if (plain.length <= syncLimit) {
        _cache[node.id] = _Highlighted(plain, language, tokenize(plain, language));
      } else {
        _schedule(node.id, plain, language);
        return model;
      }
    }
    final spans = _cache[node.id]!.spans;
    if (spans.isEmpty) return model;

    final copy = model.copy();
    final highlighted = text.copy();
    for (final (start, end, token) in spans) {
      if (end > start && end <= highlighted.length) {
        highlighted.addAttribution(CodeTokenAttribution(token), SpanRange(start, end - 1), autoMerge: false);
      }
    }
    (copy as TextComponentViewModel).text = highlighted;
    return copy;
  }

  void _schedule(String nodeId, String text, String language) {
    _pending[nodeId]?.cancel();
    _pending[nodeId] = Timer(debounce, () {
      _pending.remove(nodeId);
      _cache[nodeId] = _Highlighted(text, language, tokenize(text, language));
      markDirty();
    });
  }

  /// Token spans `(start, end, class)` of [code] in [language].
  static List<(int, int, String)> tokenize(String code, String language) {
    try {
      final result = highlight.parse(code, language: language);
      final spans = <(int, int, String)>[];
      var offset = 0;
      void visit(Node node, String? inherited) {
        final className = node.className ?? inherited;
        final value = node.value;
        if (value != null) {
          if (className != null) spans.add((offset, offset + value.length, className.split(' ').first));
          offset += value.length;
        }
        for (final child in node.children ?? const <Node>[]) {
          visit(child, className);
        }
      }

      for (final node in result.nodes ?? const <Node>[]) {
        visit(node, null);
      }
      return offset == code.length ? spans : const [];
    } catch (_) {
      return const [];
    }
  }
}

class _Highlighted {
  _Highlighted(this.text, this.language, this.spans);

  final String text;
  final String language;
  final List<(int, int, String)> spans;
}

/// Lays out right-to-left paragraphs right-to-left (Write 04 §38): direction
/// from the first strong character; nothing is stored in the Delta.
class TextDirectionStylePhase extends SingleColumnLayoutStylePhase {
  TextDirectionStylePhase({this.fallback = TextDirection.ltr});

  /// Direction of the document language (for blocks without strong chars).
  TextDirection fallback;

  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final model in viewModel.componentViewModels)
          if (model is TextComponentViewModel)
            _withDirection(model)
          else
            model,
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _withDirection(SingleColumnLayoutComponentViewModel model) {
    final textModel = model as TextComponentViewModel;
    final direction = detectTextDirection(textModel.text.toPlainText(), fallback: fallback);
    if (direction == textModel.textDirection) return model;
    final copy = model.copy();
    (copy as TextComponentViewModel)
      ..textDirection = direction
      ..textAlignment = direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    return copy;
  }
}
