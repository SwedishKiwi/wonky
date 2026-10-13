import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../attributions/wonky_attributions.dart';
import '../mapping/wonky_schema.dart';
import '../model/code_languages.dart';
import 'code_highlighter.dart';
import 'write_stylesheet.dart';

/// Overlays presentation-only [CodeTokenAttribution]s on code block view
/// models (Write 04 §15.4). The document is never changed.
///
/// Tokens come from [CodeHighlighter] (`syntax_highlight` grammars). A
/// grammar is loaded the first time a block needs it; the block renders plain
/// until then and is restyled when it arrives. Languages without a grammar
/// ([CodeLanguages.grammarFor]) stay plain.
///
/// Results are cached per (node, text, language). Large blocks are tokenized
/// after a debounce so that typing stays responsive; until then the block
/// renders without highlighting.
class CodeHighlightStylePhase extends SingleColumnLayoutStylePhase {
  CodeHighlightStylePhase({
    this.debounce = const Duration(milliseconds: 120),
    this.syncLimit = 20000,
  });

  final Duration debounce;

  /// Blocks up to this many characters are tokenized synchronously.
  final int syncLimit;

  final _cache = <String, _Highlighted>{};
  final _pending = <String, Timer>{};
  bool _closed = false;

  // No `dispose` override: super_editor disposes style phases whenever it
  // recreates its layout presenter (stylesheet, zoom or theme change) and
  // then keeps using the same phase objects, so pending tokenizations and
  // grammar loads must survive it. The editor calls [close] instead.

  /// Cancels pending work for good (when the editor is disposed).
  void close() {
    _closed = true;
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
  }

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final model in viewModel.componentViewModels)
          _highlight(document, model),
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _highlight(
    Document document,
    SingleColumnLayoutComponentViewModel model,
  ) {
    if (model is! TextComponentViewModel) return model;
    final node = document.getNodeById(model.nodeId);
    if (node == null || !isCodeBlockNode(node)) return model;
    final grammar = CodeLanguages.grammarFor(codeLanguageOf(node));
    if (grammar == null) return model;
    if (!CodeHighlighter.isLoaded(grammar)) {
      unawaited(
        CodeHighlighter.load(grammar).then((loaded) {
          if (loaded && !_closed) markDirty();
        }),
      );
      return model;
    }
    final text = model.text;
    final plain = text.toPlainText(includePlaceholders: false);

    final cached = _cache[node.id];
    if (cached == null || cached.text != plain || cached.grammar != grammar) {
      if (plain.length <= syncLimit) {
        _cache[node.id] = _Highlighted(
          plain,
          grammar,
          CodeHighlighter.tokenize(plain, grammar),
        );
      } else {
        _schedule(node.id, plain, grammar);
        return model;
      }
    }
    final spans = _cache[node.id]!.spans;
    if (spans.isEmpty) return model;

    final copy = model.copy();
    final highlighted = text.copy();
    for (final (start, end, token) in spans) {
      if (end > start && end <= highlighted.length) {
        highlighted.addAttribution(
          CodeTokenAttribution(token),
          SpanRange(start, end - 1),
          autoMerge: false,
        );
      }
    }
    (copy as TextComponentViewModel).text = highlighted;
    return copy;
  }

  void _schedule(String nodeId, String text, String grammar) {
    if (_closed) return;
    _pending[nodeId]?.cancel();
    _pending[nodeId] = Timer(debounce, () {
      _pending.remove(nodeId);
      _cache[nodeId] = _Highlighted(
        text,
        grammar,
        CodeHighlighter.tokenize(text, grammar),
      );
      markDirty();
    });
  }

  /// Token spans `(start, end, class)` of [code] in [language] (a
  /// normalised language id); empty when the language has no grammar or the
  /// grammar is not loaded yet.
  static List<(int, int, String)> tokenize(String code, String language) {
    final grammar = CodeLanguages.grammarFor(language);
    if (grammar == null) return const [];
    return CodeHighlighter.tokenize(code, grammar);
  }
}

class _Highlighted {
  _Highlighted(this.text, this.grammar, this.spans);

  final String text;
  final String grammar;
  final List<(int, int, String)> spans;
}

/// Lays out right-to-left paragraphs right-to-left (Write 04 §38): direction
/// from the first strong character; nothing is stored in the Delta.
class TextDirectionStylePhase extends SingleColumnLayoutStylePhase {
  TextDirectionStylePhase({this.fallback = TextDirection.ltr});

  /// Direction of the document language (for blocks without strong chars).
  TextDirection fallback;

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final model in viewModel.componentViewModels)
          if (model is TextComponentViewModel) _withDirection(model) else model,
      ],
    );
  }

  SingleColumnLayoutComponentViewModel _withDirection(
    SingleColumnLayoutComponentViewModel model,
  ) {
    final textModel = model as TextComponentViewModel;
    final direction = detectTextDirection(
      textModel.text.toPlainText(),
      fallback: fallback,
    );
    if (direction == textModel.textDirection) return model;
    final copy = model.copy();
    (copy as TextComponentViewModel)
      ..textDirection = direction
      ..textAlignment = direction == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left;
    return copy;
  }
}
