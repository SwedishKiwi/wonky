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
/// - the transition stub (`TransitionCompiler` → `TransitionPlan.cut`)
///   that SL-25 replaces.
library;

export 'src/motion/builds/build_edits.dart';
export 'src/motion/builds/build_options.dart';
export 'src/motion/builds/parts.dart';
export 'src/motion/builds/transition_spec.dart';
export 'src/motion/easing/motion_easing.dart';
export 'src/motion/effects/effect_catalog.dart';
export 'src/motion/stub/transition_stub.dart';
export 'src/motion/timeline/motion_input.dart';
export 'src/motion/timeline/slide_frame.dart';
export 'src/motion/timeline/slide_timeline.dart';
export 'src/motion/util/seeded_random.dart';
export 'src/theme/model/common.dart' show SuRect;
