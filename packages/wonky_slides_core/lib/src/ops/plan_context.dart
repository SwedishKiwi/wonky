import 'package:wonky_sync_models/ids.dart' show IdGenerator, UuidV7IdGenerator;

/// Thrown when an operation is refused (UI dialog/toast, MCP error); nothing
/// is applied then.
final class PlanException implements Exception {
  /// Creates the exception.
  const PlanException(this.code, this.message, {this.details = const {}});

  /// A limit of 02 §13 would be exceeded.
  static const limit = 'limit';

  /// An argument is invalid (bad id, bad JSON, wrong element kind…).
  static const invalidArgument = 'invalid_argument';

  /// A referenced row does not exist.
  static const notFound = 'not_found';

  /// The element is locked (03 §8.2).
  static const locked = 'locked';

  /// The operation is not implemented (yet) by the planner in use.
  static const unsupported = 'unsupported';

  /// The acting user may not do this (role).
  static const permission = 'permission';

  /// Machine code ([limit], [invalidArgument], [notFound], [locked],
  /// [unsupported], [permission], …).
  final String code;

  /// Human-readable message (02 §13 wording for limits).
  final String message;

  /// Extra details (MCP `details`).
  final Map<String, Object?> details;

  @override
  String toString() => 'PlanException($code): $message';
}

/// The limits of 02 §13 enforced by the planner (client and server).
/// *Config* values come from `ProtocolInfo` (`wonky.slides.*`).
final class SlidesLimits {
  /// Creates limits (defaults = 02 §13).
  const SlidesLimits({
    this.maxSlidesPerDeck = 1000,
    this.maxGroupsPerDeck = 200,
    this.maxElementsPerOwner = 500,
    this.maxElementGroupDepth = 8,
    this.maxTextLength = 20000,
    this.maxNotesLength = 50000,
    this.maxTableRows = 50,
    this.maxTableColumns = 20,
    this.maxBuildsPerSlide = 200,
    this.maxCodeStates = 50,
    this.maxCodeLength = 20000,
    this.maxCodeLines = 1000,
    this.maxThemesPerDeck = 20,
    this.maxMastersPerTheme = 10,
    this.maxLayoutsPerMaster = 50,
    this.minFrameSide = 1,
    this.maxFrameSide = 20000,
    this.maxPosition = 40000,
    this.minFontSize = 6,
    this.maxFontSize = 800,
  });

  /// The defaults of 02 §13.
  static const defaults = SlidesLimits();

  final int maxSlidesPerDeck;
  final int maxGroupsPerDeck;
  final int maxElementsPerOwner;
  final int maxElementGroupDepth;
  final int maxTextLength;
  final int maxNotesLength;
  final int maxTableRows;
  final int maxTableColumns;
  final int maxBuildsPerSlide;
  final int maxCodeStates;
  final int maxCodeLength;
  final int maxCodeLines;
  final int maxThemesPerDeck;
  final int maxMastersPerTheme;
  final int maxLayoutsPerMaster;
  final double minFrameSide;
  final double maxFrameSide;
  final double maxPosition;
  final double minFontSize;
  final double maxFontSize;
}

/// Inputs every plan needs besides the operation and the model (the Slides
/// counterpart of Sheets' `PlanContext`).
final class SlidesPlanContext {
  /// Creates a context.
  SlidesPlanContext({
    required this.userId,
    required this.now,
    IdGenerator? ids,
    this.limits = SlidesLimits.defaults,
    this.isOwner = false,
    this.locale,
  }) : ids = ids ?? const UuidV7IdGenerator();

  /// Acting user (auth user UUID string): `createdBy`, `updatedBy`.
  final String userId;

  /// Time stamp for `createdAt`/`updatedAt` of new rows (inject for
  /// determinism).
  final DateTime now;

  /// Generator of fresh row ids and match keys.
  final IdGenerator ids;

  /// Limits (02 §13).
  final SlidesLimits limits;

  /// Whether the user owns the deck.
  final bool isOwner;

  /// Locale for generated names ("Slide 3", "Group 2"); null = English.
  final String? locale;
}
