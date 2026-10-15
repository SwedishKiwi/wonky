import 'dart:convert';

import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/testing.dart';

/// A blank slide with elements and builds for timeline tests: builds get
/// short names for golden step tables.
final class MotionFixture {
  MotionFixture() {
    slide = b.slide(layoutKey: 'blank');
  }

  final b = DeckBuilder();
  late final String slide;
  final Map<String, String> names = {};
  final Map<String, MotionElement> overrides = {};

  /// A shape at ([x], [y]) of [w] × [h] (center (300, 200) by default).
  String shape({
    double x = 100,
    double y = 100,
    double w = 400,
    double h = 200,
    String? text,
  }) => b.shape(slide, x: x, y: y, width: w, height: h, text: text);

  /// A text box with [text].
  String text(String text) =>
      b.textBox(slide, text, x: 100, y: 500, width: 800, height: 300);

  /// An element of [kind] whose motion geometry is [element] (code states,
  /// chart shape).
  String special(ElementKind kind, MotionElement Function(String id) element) {
    final id = b.element(slide, kind, x: 100, y: 100, width: 400, height: 200);
    overrides[id] = element(id);
    return id;
  }

  /// Adds build [name] on [element].
  String build(
    String name,
    String element, {
    SlideBuildKind kind = SlideBuildKind.buildIn,
    String effect = 'fade',
    SlideBuildTrigger trigger = SlideBuildTrigger.onClick,
    int durationMs = 500,
    int delayMs = 0,
    String easing = 'easeOut',
    Map<String, Object?>? options,
  }) {
    final id = b.build_(
      slide,
      element,
      kind: kind,
      effect: effect,
      trigger: trigger,
      durationMs: durationMs,
      delayMs: delayMs,
      easing: easing,
      optionsJson: options == null ? null : jsonEncode({'v': 1, ...options}),
    );
    names[id] = name;
    return id;
  }

  /// The compiled timeline of the slide.
  SlideTimeline compile({
    CompileOptions options = const CompileOptions(),
    String? transitionJson,
  }) {
    final model = b.build();
    final input = SlideMotionInput.fromDeck(model, slide, options: options);
    return SlideTimelineCompiler.compile(
      SlideMotionInput(
        slide: input.slide,
        builds: input.builds,
        elements: {...?input.elements, ...overrides},
        transition: transitionJson == null
            ? input.transition
            : TransitionSpec.decode(transitionJson).value,
        slideWidth: input.slideWidth,
        slideHeight: input.slideHeight,
        options: options,
        resolveColor: input.resolveColor,
      ),
    );
  }

  /// The golden step table of [t]: `step/duration: name[#part][~dim]@start+length …`.
  List<String> table(SlideTimeline t) => [
    for (final s in t.steps)
      '${s.index}/${s.durationMs}:${[for (final e in s.effects) ' ${names[e.buildId] ?? '?'}'
            '${e.part == 0 ? '' : '#${e.part}'}'
            '${e.role == EffectRole.dim ? '~dim' : ''}'
            '@${e.startMs}+${e.durationMs}'].join()}',
  ];
}
