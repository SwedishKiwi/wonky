/// The look of the rich editor's content: the suite's Markdown rendering
/// (the shell's `WonkyMarkdown`: small text, h3-sized headings, muted
/// quotes with a bar, code in a muted box) on super_editor.
library;

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:super_editor/super_editor.dart';

import '../codec/markdown_document_codec.dart';
import '../codec/markdown_features.dart';
import '../editor/rich_editor_reactions.dart';

/// The monospace family of code (as in the shell's Markdown renderer).
const richEditorMonoFamily = 'JetBrains Mono';

/// The text styles of the editor, from the shad theme.
class RichEditorStyle {
  RichEditorStyle.of(BuildContext context)
    : theme = ShadTheme.of(context),
      base = ShadTheme.of(context).textTheme.small.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: ShadTheme.of(context).colorScheme.foreground,
      );

  final ShadThemeData theme;

  /// Paragraph text.
  final TextStyle base;

  ShadColorScheme get colors => theme.colorScheme;

  /// Inner padding of the field (the text inputs' 12 × 8).
  static const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  /// Space between blocks.
  static const blockGap = 6.0;

  /// The width of the quote bar and the gap after it.
  static const quoteBar = 3.0;
  static const quoteGap = 10.0;

  /// Inner padding of code boxes.
  static const codePadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);

  TextStyle get code =>
      base.copyWith(fontFamily: richEditorMonoFamily, fontSize: 12);

  TextStyle get hint => theme.textTheme.muted.copyWith(height: base.height);

  /// The stylesheet of the document.
  Stylesheet stylesheet() => Stylesheet(
    documentPadding: padding,
    inlineTextStyler: _inline,
    rules: [
      StyleRule(
        BlockSelector.all,
        (doc, node) => {
          Styles.maxWidth: double.infinity,
          Styles.padding: const CascadingPadding.only(bottom: blockGap),
          Styles.textStyle: base,
        },
      ),
      for (final h in ['header1', 'header2', 'header3'])
        StyleRule(
          BlockSelector(h),
          (doc, node) => {
            Styles.textStyle: base.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          },
        ),
      for (final h in ['header4', 'header5', 'header6'])
        StyleRule(
          BlockSelector(h),
          (doc, node) => {
            Styles.textStyle: base.copyWith(fontWeight: FontWeight.w600),
          },
        ),
      StyleRule(
        const BlockSelector('blockquote'),
        (doc, node) => {
          Styles.padding: const CascadingPadding.only(
            left: quoteBar + quoteGap,
          ),
          Styles.textStyle: base.copyWith(color: colors.mutedForeground),
        },
      ),
      StyleRule(
        const BlockSelector('blockquote').after('blockquote'),
        (doc, node) => {Styles.padding: const CascadingPadding.only(top: 0)},
      ),
      StyleRule(
        const BlockSelector('code'),
        (doc, node) => {
          // The box's padding is added around the component.
          Styles.padding: CascadingPadding.only(
            left: codePadding.left,
            right: codePadding.right,
            bottom: blockGap + codePadding.bottom,
          ),
          Styles.textStyle: code,
        },
      ),
      StyleRule(
        BlockSelector.all.last(),
        (doc, node) => {
          Styles.padding: CascadingPadding.only(
            bottom: isCodeLike(node) ? codePadding.bottom : 0,
          ),
        },
      ),
    ],
  );

  TextStyle _inline(Set<Attribution> attributions, TextStyle style) {
    var s = style;
    if (attributions.contains(boldAttribution)) {
      s = s.copyWith(fontWeight: FontWeight.w600);
    }
    if (attributions.contains(italicsAttribution)) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }
    final decorations = <TextDecoration>[
      if (attributions.contains(strikethroughAttribution))
        TextDecoration.lineThrough,
      if (attributions.any((a) => a is LinkAttribution))
        TextDecoration.underline,
    ];
    if (decorations.isNotEmpty) {
      s = s.copyWith(
        decoration: TextDecoration.combine(decorations),
        decorationColor: attributions.any((a) => a is LinkAttribution)
            ? colors.primary
            : null,
      );
    }
    if (attributions.any((a) => a is LinkAttribution)) {
      s = s.copyWith(color: colors.primary);
    }
    if (attributions.contains(codeAttribution)) {
      s = s.copyWith(
        fontFamily: richEditorMonoFamily,
        fontSize: (style.fontSize ?? 14) - 1,
        backgroundColor: colors.muted,
      );
    }
    return s;
  }

  /// The component builders: paragraphs (quote bar, code box, hint), list
  /// items, tasks (shad checkbox) and rules.
  List<ComponentBuilder> componentBuilders(Editor editor, {String? hint}) => [
    if (hint != null && hint.isNotEmpty) _HintBuilder(hint, this.hint),
    _ParagraphBuilder(this, editor.document),
    const ListItemComponentBuilder(),
    _TaskBuilder(editor, this),
    _RuleBuilder(this),
  ];
}

/// The placeholder in the empty field's paragraph.
class _HintBuilder extends HintComponentBuilder {
  _HintBuilder(String hint, TextStyle style) : super(hint, (_) => style);

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (!isPlainParagraph(node) || (node as ParagraphNode).text.isNotEmpty) {
      return null;
    }
    return super.createViewModel(document, node);
  }
}

class _ParagraphBuilder implements ComponentBuilder {
  const _ParagraphBuilder(this.style, this.document);

  final RichEditorStyle style;
  final Document document;
  static const _inner = ParagraphComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ParagraphNode) return null;
    return _inner.createViewModel(document, node);
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    if (viewModel is! ParagraphComponentViewModel) return null;
    final blockType = viewModel.blockType;
    // super_editor adds the block type to every span's attributions; for
    // code that would draw every character as inline code.
    final component = _inner.createComponent(
      componentContext,
      blockType == codeAttribution
          ? (viewModel.copy()..blockType = null)
          : viewModel,
    );
    if (component == null) return null;
    if (blockType == blockquoteAttribution) {
      return CustomPaint(
        painter: _QuoteBar(style.colors.border),
        child: component,
      );
    }
    if (blockType == codeAttribution) {
      final node = document.getNodeById(viewModel.nodeId);
      return _CodeBox(
        literal: node?.getMetadataValue(MarkdownNodeMetadata.raw) == true,
        style: style,
        child: component,
      );
    }
    final level = MarkdownDocumentCodec.headingLevelOf(
      _BlockTypeNode(blockType),
    );
    if (level != null) {
      return Semantics(header: true, headingLevel: level, child: component);
    }
    return component;
  }
}

/// A node stand-in to read a heading level from a block type.
class _BlockTypeNode extends ParagraphNode {
  _BlockTypeNode(Attribution? type)
    : super(
        id: '',
        text: AttributedText(),
        metadata: {NodeMetadata.blockType: type},
      );
}

class _QuoteBar extends CustomPainter {
  _QuoteBar(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(
        -(RichEditorStyle.quoteBar + RichEditorStyle.quoteGap),
        0,
        RichEditorStyle.quoteBar,
        size.height,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_QuoteBar oldDelegate) => oldDelegate.color != color;
}

/// A code block (or a block kept as literal Markdown) as one muted box. The
/// box ignores pointers and its padding is outside the component, so taps,
/// caret and selection stay aligned with the text (like Write's code
/// blocks).
class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.literal,
    required this.style,
    required this.child,
  });

  final bool literal;
  final RichEditorStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = RichEditorStyle.codePadding;
    return Semantics(
      label: literal ? 'Markdown' : 'code block',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -p.left,
            right: -p.right,
            top: 0,
            bottom: -p.bottom,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: style.colors.muted,
                  borderRadius: BorderRadius.circular(6),
                  border: literal
                      ? Border.all(color: style.colors.border)
                      : null,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: p.top),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Tasks with the shad checkbox (super_editor's uses Material's).
class _TaskBuilder implements ComponentBuilder {
  _TaskBuilder(Editor editor, this.style)
    : _inner = TaskComponentBuilder(editor);

  final TaskComponentBuilder _inner;
  final RichEditorStyle style;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => _inner.createViewModel(document, node);

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    if (viewModel is! TaskComponentViewModel) return null;
    return _TaskComponent(
      key: componentContext.componentKey,
      viewModel: viewModel,
    );
  }
}

class _TaskComponent extends StatefulWidget {
  const _TaskComponent({super.key, required this.viewModel});

  final TaskComponentViewModel viewModel;

  @override
  State<_TaskComponent> createState() => _TaskComponentState();
}

class _TaskComponentState extends State<_TaskComponent>
    with ProxyDocumentComponent<_TaskComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      childDocumentComponentKey.currentState as TextComposable;

  TextStyle _styles(Set<Attribution> attributions) {
    final style = widget.viewModel.textStyleBuilder(attributions);
    if (!widget.viewModel.isComplete) return style;
    final theme = ShadTheme.of(context);
    return style.copyWith(
      color: theme.colorScheme.mutedForeground,
      decoration: style.decoration == null
          ? TextDecoration.lineThrough
          : TextDecoration.combine([
              TextDecoration.lineThrough,
              style.decoration!,
            ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.viewModel;
    final base = m.textStyleBuilder({});
    final lineHeight = (base.fontSize ?? 14) * (base.height ?? 1.45);
    return Semantics(
      checked: m.isComplete,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The checkbox sits where a bullet's dot would (same indents).
          SizedBox(
            width: (defaultListItemIndentCalculator(base, m.indent) - 22).clamp(
              0.0,
              double.infinity,
            ),
          ),
          SizedBox(
            width: 22,
            height: lineHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShadCheckbox(
                value: m.isComplete,
                size: 14,
                enabled: m.setComplete != null,
                onChanged: m.setComplete == null
                    ? null
                    : (v) => m.setComplete!(v),
              ),
            ),
          ),
          Expanded(
            child: TextComponent(
              key: _textKey,
              text: m.text,
              textDirection: m.textDirection,
              textAlign: m.textAlignment,
              textStyleBuilder: _styles,
              inlineWidgetBuilders: m.inlineWidgetBuilders,
              textSelection: m.selection,
              selectionColor: m.selectionColor,
              highlightWhenEmpty: m.highlightWhenEmpty,
              underlines: m.createUnderlines(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rules as the theme's border line.
class _RuleBuilder implements ComponentBuilder {
  const _RuleBuilder(this.style);

  final RichEditorStyle style;
  static const _inner = HorizontalRuleComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => _inner.createViewModel(document, node);

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel viewModel,
  ) {
    if (viewModel is! HorizontalRuleComponentViewModel) return null;
    return HorizontalRuleComponent(
      componentKey: componentContext.componentKey,
      color: style.colors.border,
      thickness: 1,
      selection:
          viewModel.selection?.nodeSelection
              as UpstreamDownstreamNodeSelection?,
      selectionColor: viewModel.selectionColor,
      showCaret: viewModel.caret != null,
      caretColor: viewModel.caretColor,
      opacity: viewModel.opacity,
    );
  }
}
