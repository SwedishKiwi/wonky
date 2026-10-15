/// The motion model of Wonky Slides (specs/wonky_slides/06 §2–§4, §9,
/// 12 §5.5), pure Dart (client, server, PDF, MCP):
///
/// - the timeline: `SlideTimelineCompiler.compile(SlideMotionInput)` →
///   `SlideTimeline` (`steps`, `initial`, `endOfStep`, `frameAt`,
///   `finalFrame`, `printFrame`, `describe`), frames (`SlideFrame`,
///   `ElementVisualState` with clips, parts, chart reveal and code view);
/// - the build model: `EffectCatalog` (06 §3), `BuildOptions`
///   (`SlideBuild.optionsJson`), `TransitionSpec` (`Slide.transitionJson`),
///   `DeckMotionDefaults` (`Deck.defaultsJson`), `MotionEasing` (06 §4.3),
///   text/chart parts and part order, and `BuildEdits` (operations for the
///   Animate commands: add/update/move/remove, copy/paste animation,
///   transitions);
/// - transitions (SL-25, 06 §7, §12.2, §13): `TransitionCompiler.compile` /
///   `between` / `preview` → `TransitionPlan` (`frameAt(ms)`, `at(t)`,
///   `sample(n)`, `describe()`) → `TransitionFrame` (snapshot quads with
///   2D/3D transforms, clips, dissolve, shading; or a `MagicMoveFrame`),
///   `TransitionInfo` (tile groups, descriptions, glyphs);
/// - Magic Move (SL-25, 06 §8, §9.5): `MagicMoveSlide` (`fromDeck`),
///   `MagicMoveMatcher` (keys, content signatures, names, groups),
///   `MagicMovePlan` (`MorphPair`s with path, glyph-run, code-token and
///   chart-camera descriptors; `frameAt(ms)` → both slides' frames, layers
///   and pair states), `PathMorph`, `TextMorph`, `ChartCameraView`.
library;

export 'src/motion/builds/build_edits.dart';
export 'src/motion/builds/build_options.dart';
export 'src/motion/builds/parts.dart';
export 'src/motion/builds/transition_spec.dart';
export 'src/motion/easing/motion_easing.dart';
export 'src/motion/effects/effect_catalog.dart';
export 'src/motion/magic_move/chart_camera.dart';
export 'src/motion/magic_move/magic_move_matcher.dart';
export 'src/motion/magic_move/magic_move_plan.dart';
export 'src/motion/magic_move/magic_move_slide.dart';
export 'src/motion/magic_move/morph_geometry.dart';
export 'src/motion/magic_move/path_morph.dart';
export 'src/motion/magic_move/text_morph.dart';
export 'src/motion/timeline/motion_input.dart';
export 'src/motion/timeline/slide_frame.dart';
export 'src/motion/timeline/slide_timeline.dart';
export 'src/motion/transitions/transition_compiler.dart';
export 'src/motion/transitions/transition_frame.dart';
export 'src/motion/transitions/transition_info.dart';
export 'src/motion/transitions/transition_programs.dart'
    show frontFacing, faceShade;
export 'src/motion/util/seeded_random.dart';
export 'src/theme/model/common.dart' show SuRect;
