/// Embedded objects on the grid: anchors, placement, move/resize, snapping,
/// z-order and anchor maintenance (Sheets 08 §1, §9, §10.1, §11).
library;

export 'align.dart' show ObjectAlign;
export 'anchor.dart' show ObjectAnchor;
export 'maintenance.dart' show AnchorMaintenance;
export 'object_geometry.dart'
    show
        GridSnap,
        ObjectGeometry,
        ResizeHandle,
        SmartGuides,
        SmartSnap,
        SnapGuide;
export 'placement.dart' show ChartSheetAnchors, ObjectPlacement;
export 'z_order.dart' show ZOrder, ZOrderItem;
