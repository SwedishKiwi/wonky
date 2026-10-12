import '../common/models.dart';

/// Claude model ids and effort levels (suite 10 §1). The only place model
/// ids are written down; everything else asks [AiTier].
abstract final class AiModels {
  /// Default model (Best and Balanced).
  static const opus = 'claude-opus-5-5';

  /// Fast tier and inline completions.
  static const haiku = 'claude-haiku-5-5';

  /// Whether [model] supports the server-side refusal fallback
  /// (`fallbacks: "default"`). Claude Haiku 5.5 has none: sending a list
  /// is a 400 and "default" leaves a decline declined.
  static bool supportsServerFallback(String model) => model != haiku;

  /// Whether [model] returns progress notes between tool calls as
  /// `thinking` blocks with `display: "updates"`.
  static bool supportsDisplayUpdates(String model) => model == opus;
}

/// Effort levels (`output_config.effort`).
abstract final class AiEffort {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';
}

/// A model plus effort level.
class AiTier {
  const AiTier(this.model, this.effort);

  final String model;
  final String effort;

  /// The assistant panel (suite 10 §1 table).
  static AiTier chat(AiQuality q) => switch (q) {
    AiQuality.best => const AiTier(AiModels.opus, AiEffort.high),
    AiQuality.balanced => const AiTier(AiModels.opus, AiEffort.medium),
    AiQuality.fast => const AiTier(AiModels.haiku, AiEffort.low),
  };

  /// Inline rewrite / translate / tone (Write 09 §5.1): the user's setting
  /// with effort capped at `medium`.
  static AiTier rewrite(AiQuality q) => switch (q) {
    AiQuality.best || AiQuality.balanced => const AiTier(
      AiModels.opus,
      AiEffort.medium,
    ),
    AiQuality.fast => const AiTier(AiModels.haiku, AiEffort.low),
  };

  /// Continue writing: Haiku when Fast, else Opus at `low`.
  static AiTier continueWriting(AiQuality q) => switch (q) {
    AiQuality.fast => const AiTier(AiModels.haiku, AiEffort.low),
    _ => const AiTier(AiModels.opus, AiEffort.low),
  };

  /// Summarize, outline, explain and proofread: the user's setting.
  static AiTier document(AiQuality q) => chat(q);

  @override
  String toString() => '$model/$effort';
}
