/// The M9 stub of the transition API (06 §9.5, 12 §5.5): every transition
/// compiles to a cut. SL-25 replaces it with `TransitionCompiler` /
/// `MagicMoveMatcher` in `core/motion/{transitions,magic_move}/`; the type
/// names stay.
library;

import '../timeline/slide_frame.dart';

/// The plan of a transition between two slides (06 §9.5). Stub: a cut.
final class TransitionPlan {
  /// Creates a plan.
  const TransitionPlan({
    this.durationMs = 0,
    this.outgoing = const [],
    this.incoming = const [],
  });

  /// A cut (no animation).
  static const cut = TransitionPlan();

  final int durationMs;

  /// Element ids leaving with the outgoing slide.
  final List<String> outgoing;

  /// Element ids arriving with the incoming slide.
  final List<String> incoming;
}

/// Compiles the transition into a slide (06 §9.5).
abstract final class TransitionCompiler {
  /// M9 stub: every transition is a cut.
  static TransitionPlan compile({
    required SlideFrame from,
    required SlideFrame to,
    String? transitionJson,
  }) => TransitionPlan.cut;
}
