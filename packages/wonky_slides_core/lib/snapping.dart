/// Canvas geometry of Wonky Slides (specs/wonky_slides 03 §4–§5): the
/// `SnapEngine` (smart guides, equal spacing, equal size, connection-site
/// gluing, rotation snapping), `FrameTransforms` (resize by handle,
/// multi-selection scaling, rotation, group child space) and the
/// `Deck.guidesJson` codec. Pure Dart.
library;

export 'src/snapping/frame_transforms.dart';
export 'src/snapping/snap_engine.dart';
export 'src/snapping/user_guides.dart';
