/// Presentation metadata of the transition catalog (06 §5.1, §7.2, §13)
/// for the Transition tab (SL-30), MCP and the AI: tile group, a one-line
/// description (English; the app shows its ARB strings keyed by id), the
/// reduced-motion behavior, the parameter that picks a direction, and a
/// Lucide glyph. The types themselves (ids, names, parameters, durations,
/// 3D flag, availability) are `TransitionCatalog` (06 §7.2).
library;

import '../builds/transition_spec.dart';

/// Tile groups of the Transition tab.
enum TransitionGroup {
  /// None, fade, dissolve, push, slide, cover, uncover, wipe, iris, zoom.
  basic,

  /// Flip, cube, doorway, swap, revolve (perspective).
  threeD,

  /// Magic Move.
  magic,
}

/// Metadata of one transition type.
final class TransitionInfo {
  const TransitionInfo._(
    this.id,
    this.group,
    this.description,
    this.icon, {
    this.directionParam,
    this.reducedMotion = 'fade',
  });

  /// The type id (`TransitionCatalog`).
  final String id;
  final TransitionGroup group;

  /// One sentence (accessible tile description, MCP, AI prompt).
  final String description;

  /// Lucide icon name of the tile glyph.
  final String icon;

  /// The parameter holding a direction (4-way or 8-way pad), or null.
  final String? directionParam;

  /// What plays with *Reduce motion* (06 §13): `fade` (300 ms), `same`
  /// (already a fade), `crossfade` (Magic Move), `none` (a cut stays a cut).
  final String reducedMotion;

  /// The catalog entry.
  TransitionTypeSpec get spec => TransitionCatalog.byId(id)!;

  /// Every available type in catalog order (P2 types are left out).
  static List<TransitionInfo> get all => [
    for (final t in TransitionCatalog.types)
      if (t.available && _byId[t.id] != null) _byId[t.id]!,
  ];

  /// The types of [group].
  static List<TransitionInfo> inGroup(TransitionGroup group) => [
    for (final i in all)
      if (i.group == group) i,
  ];

  /// The metadata of [id], or null (unknown or P2 types).
  static TransitionInfo? of(String id) => _byId[id];

  static final Map<String, TransitionInfo> _byId = {
    for (final i in _infos) i.id: i,
  };

  static const _infos = [
    TransitionInfo._(
      'none',
      TransitionGroup.basic,
      'The new slide replaces the old one instantly.',
      'square',
      reducedMotion: 'none',
    ),
    TransitionInfo._(
      'fade',
      TransitionGroup.basic,
      'The new slide fades in over the old one, or both fade through a '
          'color.',
      'blend',
      reducedMotion: 'same',
    ),
    TransitionInfo._(
      'dissolve',
      TransitionGroup.basic,
      'The new slide appears through a grain of random cells.',
      'grip',
    ),
    TransitionInfo._(
      'push',
      TransitionGroup.basic,
      'The new slide pushes the old one off the screen.',
      'arrow-left-to-line',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'slide',
      TransitionGroup.basic,
      'The new slide slides in over the old one.',
      'panel-left-open',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'cover',
      TransitionGroup.basic,
      'The new slide slides over the old one, which dims.',
      'layers',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'uncover',
      TransitionGroup.basic,
      'The old slide slides away and reveals the new one.',
      'panel-left-close',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'wipe',
      TransitionGroup.basic,
      'A soft edge sweeps across and reveals the new slide.',
      'move-right',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'iris',
      TransitionGroup.basic,
      'A growing circle, square or diamond reveals the new slide.',
      'circle-dot',
    ),
    TransitionInfo._(
      'zoom',
      TransitionGroup.basic,
      'The new slide grows in, or the old one shrinks away.',
      'zoom-in',
    ),
    TransitionInfo._(
      'flip',
      TransitionGroup.threeD,
      'The slide flips over like a card; the new slide is on its back.',
      'flip-horizontal-2',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'cube',
      TransitionGroup.threeD,
      'Both slides are faces of a cube that turns a quarter turn.',
      'box',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'doorway',
      TransitionGroup.threeD,
      'The old slide opens like double doors; the new one comes forward.',
      'door-open',
    ),
    TransitionInfo._(
      'swap',
      TransitionGroup.threeD,
      'The slides swap places, front and back, on an arc.',
      'arrow-left-right',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'revolve',
      TransitionGroup.threeD,
      'The old slide swings away on its edge like a door.',
      'rotate-3d',
      directionParam: 'direction',
    ),
    TransitionInfo._(
      'magicMove',
      TransitionGroup.magic,
      'Objects on both slides morph into each other; the rest fades.',
      'wand-sparkles',
      reducedMotion: 'crossfade',
    ),
  ];

  /// JSON (MCP, AI): the catalog entry plus this metadata.
  Map<String, Object?> toJson() => {
    ...spec.toJson(),
    'group': group.name,
    'description': description,
    'icon': icon,
    'directionParam': ?directionParam,
    'reducedMotion': reducedMotion,
  };
}
