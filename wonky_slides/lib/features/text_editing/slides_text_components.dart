import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';
import 'package:wonky_slides_core/scene.dart' as scene;

import '../stage/flutter_text_layout_engine.dart';
import 'slides_delta_mapper.dart';

/// What the overlay's paragraphs are styled with: the box's resolved text
/// styles, the layout width (the text box content width, su) and the
/// auto-fit scale — exactly what the scene builder lays the static text
/// out with (03 §6.1, §6.10).
@immutable
class SlidesTextLayoutSpec {
  const SlidesTextLayoutSpec({
    required this.styles,
    required this.width,
    this.scale = 1,
  });

  final scene.ResolvedTextStyles styles;

  /// Layout width (su).
  final double width;

  /// Auto-fit font scale.
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is SlidesTextLayoutSpec &&
      identical(other.styles, styles) &&
      other.width == width &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(identityHashCode(styles), width, scale);
}

/// The Flutter text style of a styled run — the same values the
/// `FlutterTextLayoutEngine` pushes for static text, so the overlay's
/// `RenderParagraph` and the canvas's `ui.Paragraph` shape identically.
TextStyle slidesRunTextStyle(scene.StyledRun r, double lineHeight) => TextStyle(
  color: Color(r.color),
  fontFamily: r.fontFamily,
  fontSize: r.fontSize,
  fontWeight: FontWeight.values[((r.fontWeight ~/ 100) - 1).clamp(0, 8)],
  fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
  letterSpacing: r.letterSpacing,
  height: lineHeight,
  leadingDistribution: TextLeadingDistribution.even,
  decoration: TextDecoration.combine([
    if (r.underline) TextDecoration.underline,
    if (r.strike) TextDecoration.lineThrough,
  ]),
  decorationColor: Color(r.color),
  backgroundColor: r.highlight == null ? null : Color(r.highlight!),
);

/// A presentation-only attribution of the overlay's view models: the
/// concrete style of one styled run (never stored in the document).
@immutable
class SlidesRunStyleAttribution implements Attribution {
  const SlidesRunStyleAttribution(this.style);

  final TextStyle style;

  @override
  String get id => 'slides.runStyle';

  @override
  bool canMergeWith(Attribution other) => this == other;

  @override
  bool operator ==(Object other) =>
      other is SlidesRunStyleAttribution && other.style == style;

  @override
  int get hashCode => style.hashCode;
}

/// A paragraph's list marker as the static renderer places it: the glyph
/// paragraph and its offset from the paragraph's top-left (su).
@immutable
class SlidesMarker {
  const SlidesMarker({
    required this.text,
    required this.style,
    required this.offset,
    this.paragraph,
  });

  final String text;
  final TextStyle style;
  final Offset offset;

  /// The laid-out glyph (the static engine's own paragraph when available).
  final ui.Paragraph? paragraph;

  @override
  bool operator ==(Object other) =>
      other is SlidesMarker &&
      other.text == text &&
      other.style == style &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(text, style, offset);
}

/// View model of one Slides paragraph (paragraph, list item or task).
class SlidesTextViewModel extends SingleColumnLayoutComponentViewModel
    with TextComponentViewModel {
  SlidesTextViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    required this.text,
    required this.textStyleBuilder,
    this.inlineWidgetBuilders = const [],
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.maxLines,
    this.overflow = TextOverflow.visible,
    this.selection,
    this.selectionColor = const Color(0x00000000),
    this.highlightWhenEmpty = false,
    this.textIndent = 0,
    this.markStyle,
    this.marker,
  });

  @override
  AttributedText text;
  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  InlineWidgetBuilderChain inlineWidgetBuilders;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;
  @override
  int? maxLines;
  @override
  TextOverflow overflow;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;

  /// Left edge of the text (su; list hanging indent included).
  double textIndent;

  /// The paragraph mark's style (empty paragraphs take their height from
  /// it); part of equality because empty text carries no run styles.
  TextStyle? markStyle;

  /// The list marker, or null.
  SlidesMarker? marker;

  @override
  SlidesTextViewModel copy() => internalCopy(
    SlidesTextViewModel(
      nodeId: nodeId,
      text: text.copy(),
      textStyleBuilder: textStyleBuilder,
    ),
  );

  @override
  SlidesTextViewModel internalCopy(SlidesTextViewModel subclassInstance) {
    final copy = super.internalCopy(subclassInstance) as SlidesTextViewModel;
    copy
      ..textIndent = textIndent
      ..markStyle = markStyle
      ..marker = marker;
    return copy;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlidesTextViewModel &&
          textViewModelEquals(other) &&
          textIndent == other.textIndent &&
          markStyle == other.markStyle &&
          marker == other.marker;

  @override
  int get hashCode =>
      textViewModelHashCode ^
      textIndent.hashCode ^
      markStyle.hashCode ^
      marker.hashCode;
}

/// Builds [SlidesTextViewModel]s and [SlidesTextComponent]s for every text
/// node of a Slides body (paragraphs, list items, tasks). The styling comes
/// from [SlidesTextStylePhase].
class SlidesTextComponentBuilder implements ComponentBuilder {
  const SlidesTextComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ParagraphNode && node is! ListItemNode && node is! TaskNode) {
      return null;
    }
    return SlidesTextViewModel(
      nodeId: node.id,
      text: (node as TextNode).text,
      textStyleBuilder: (_) => const TextStyle(),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! SlidesTextViewModel) return null;
    return SlidesTextComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
    );
  }
}

/// One paragraph of the overlay: super_editor's [TextComponent] at the
/// paragraph's text indent plus the list marker where the static renderer
/// draws it.
class SlidesTextComponent extends StatefulWidget {
  const SlidesTextComponent({super.key, required this.viewModel});

  final SlidesTextViewModel viewModel;

  @override
  State<SlidesTextComponent> createState() => _SlidesTextComponentState();
}

class _SlidesTextComponentState extends State<SlidesTextComponent>
    with ProxyDocumentComponent<SlidesTextComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      childDocumentComponentKey.currentState as TextComposable;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final marker = vm.marker;
    return Stack(
      clipBehavior: Clip.none,
      // The text takes the full layout width (alignment happens inside the
      // paragraph, like the static engine's).
      fit: StackFit.passthrough,
      children: [
        Padding(
          padding: EdgeInsets.only(left: vm.textIndent),
          child: TextComponent(
            key: _textKey,
            text: vm.text,
            textDirection: vm.textDirection,
            textAlign: vm.textAlignment,
            // Slide text never follows the OS text scale (the static
            // renderer doesn't either).
            textScaler: TextScaler.noScaling,
            maxLines: vm.maxLines,
            overflow: vm.overflow,
            textStyleBuilder: vm.textStyleBuilder,
            inlineWidgetBuilders: vm.inlineWidgetBuilders,
            textSelection: vm.selection,
            selectionColor: vm.selectionColor,
            highlightWhenEmpty: vm.highlightWhenEmpty,
            underlines: vm.createUnderlines(),
          ),
        ),
        if (marker != null)
          Positioned(
            left: 0,
            top: 0,
            child: IgnorePointer(
              child: CustomPaint(painter: _MarkerPainter(marker)),
            ),
          ),
      ],
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter(this.marker);

  final SlidesMarker marker;

  @override
  void paint(Canvas canvas, Size size) {
    final p =
        marker.paragraph ??
        (ui.ParagraphBuilder(ui.ParagraphStyle())
              ..pushStyle(marker.style.getTextStyle())
              ..addText(marker.text))
            .build();
    if (marker.paragraph == null) {
      p.layout(const ui.ParagraphConstraints(width: 10000));
    }
    canvas.drawParagraph(p, marker.offset);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.marker != marker;
}

/// Styles the overlay's paragraphs from the shared paragraph model
/// (`TextParagraphs`, SL-10) of the document being edited: run styles,
/// alignment, direction, spacing, indents and list markers are those of the
/// static rendering, so caret, selection and glyphs sit where the canvas
/// drew them (03 §6.1, R4).
///
/// The view-model text is the paragraph's *display* text (caps transforms
/// applied when they keep the length, soft breaks as U+2028) carrying one
/// [SlidesRunStyleAttribution] per run; positions map 1:1 to the node.
class SlidesTextStylePhase extends SingleColumnLayoutStylePhase {
  SlidesTextStylePhase({
    required this._spec,
    required this.engine,
    this.mapper = const SlidesDeltaMapper(),
  });

  /// The static renderer's engine (marker placement, R4).
  final FlutterTextLayoutEngine engine;
  final SlidesDeltaMapper mapper;

  SlidesTextLayoutSpec _spec;

  /// The styles, width and auto-fit scale.
  SlidesTextLayoutSpec get spec => _spec;
  set spec(SlidesTextLayoutSpec value) {
    if (value == _spec) return;
    _spec = value;
    markDirty();
  }

  @override
  SingleColumnLayoutViewModel style(
    Document document,
    SingleColumnLayoutViewModel viewModel,
  ) {
    final body = mapper.bodyOf(document);
    final paras = scene.TextParagraphs.build(
      body,
      _spec.styles,
      scale: _spec.scale,
    );
    final markers = _markers(body, paras);
    final paragraphOf = <String, int>{};
    var i = 0;
    for (final node in document) {
      if (node is TextNode) paragraphOf[node.id] = i++;
    }
    final last = paras.length - 1;
    return SingleColumnLayoutViewModel(
      padding: EdgeInsets.zero,
      componentViewModels: [
        for (final vm in viewModel.componentViewModels)
          if (vm is SlidesTextViewModel &&
              (paragraphOf[vm.nodeId] ?? paras.length) < paras.length)
            _styled(
              vm.copy(),
              paras[paragraphOf[vm.nodeId]!],
              first: paragraphOf[vm.nodeId] == 0,
              last: paragraphOf[vm.nodeId] == last,
              marker: markers[paragraphOf[vm.nodeId]!],
            )
          else
            vm,
      ],
    );
  }

  SlidesTextViewModel _styled(
    SlidesTextViewModel vm,
    scene.StyledParagraph p, {
    required bool first,
    required bool last,
    SlidesMarker? marker,
  }) {
    final source = vm.text.toPlainText(includePlaceholders: false);
    final display = StringBuffer();
    final runs = <(int, int, TextStyle)>[];
    var at = 0;
    for (var i = 0; i < p.runs.length; i++) {
      final r = p.runs[i];
      final from = (r.start - p.start).clamp(at, source.length);
      final to =
          (i + 1 < p.runs.length ? p.runs[i + 1].start : p.end) - p.start;
      final end = to.clamp(from, source.length);
      if (from > at) display.write(source.substring(at, from));
      // Caps transforms that change the length (ß → SS) show the source
      // text: positions must stay 1:1 with the node.
      display.write(
        r.text.length == end - from ? r.text : source.substring(from, end),
      );
      runs.add((from, end, slidesRunTextStyle(r, p.lineHeight)));
      at = end;
    }
    if (at < source.length) display.write(source.substring(at));
    final text = AttributedText(display.toString());
    for (final (from, to, style) in runs) {
      if (to > from) {
        text.addAttribution(
          SlidesRunStyleAttribution(style),
          SpanRange(from, to - 1),
        );
      }
    }
    final markStyle = slidesRunTextStyle(p.mark, p.lineHeight);
    return vm
      ..text = text
      ..maxWidth = double.infinity
      ..padding = EdgeInsets.only(
        top: first ? 0 : p.spaceBefore,
        bottom: last ? 0 : p.spaceAfter,
      )
      ..textStyleBuilder = (attributions) {
        for (final a in attributions) {
          if (a is SlidesRunStyleAttribution) return a.style;
        }
        return markStyle;
      }
      ..textDirection = p.rtl ? TextDirection.rtl : TextDirection.ltr
      ..textAlignment = switch (p.align) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        'justify' => TextAlign.justify,
        _ => p.rtl ? TextAlign.right : TextAlign.left,
      }
      ..overflow = TextOverflow.visible
      ..textIndent = p.textIndent
      ..markStyle = markStyle
      ..marker = marker;
  }

  /// The list markers by paragraph, placed like the static engine places
  /// them (it lays the body out anyway; the result is cached).
  List<SlidesMarker?> _markers(
    scene.TextBody body,
    List<scene.StyledParagraph> paras,
  ) {
    final out = List<SlidesMarker?>.filled(paras.length, null);
    if (!paras.any((p) => p.marker != null)) return out;
    final layout = engine.layout(
      body,
      _spec.styles,
      width: _spec.width,
      scale: _spec.scale,
    );
    final placed = FlutterTextLayoutEngine.paragraphsOf(layout)?.paragraphs;
    var k = 0;
    for (var i = 0; i < paras.length; i++) {
      final p = paras[i];
      final m = p.marker;
      if (placed == null || k >= placed.length) break;
      final text = placed[k++];
      if (m == null) continue;
      if (k >= placed.length) break;
      final mp = placed[k++];
      out[i] = SlidesMarker(
        text: m.text,
        style: slidesRunTextStyle(m, 1),
        offset: Offset(mp.dx, mp.dy - text.dy),
        paragraph: mp.paragraph,
      );
    }
    return out;
  }
}
