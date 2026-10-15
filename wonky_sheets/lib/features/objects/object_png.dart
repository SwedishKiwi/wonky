import 'package:flutter/foundation.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_charts_flutter/wonky_charts_flutter.dart';

import '../images/image_service.dart';
import '../sheet_editor/sheet_editor_controller.dart';
import 'objects_controller.dart';

/// PNG renderings of objects for the system clipboard (08 §9.5: charts at
/// 2×, images as PNG), so a copied chart or image pastes into other apps.
abstract final class ObjectPng {
  /// The PNG of [o], or null for kinds without one (slicers) or images
  /// that aren't loaded.
  static Future<Uint8List?> of(
    SheetEditorController ed,
    EmbeddedObjectRecord o, {
    double pixelRatio = 2,
    bool dark = false,
  }) async {
    switch (o.kind) {
      case EmbeddedObjectKind.chart:
        final spec = ChartSpec.fromJson(o.specJson);
        if (spec.isFromNewerVersion) return null;
        final objs = ObjectsController.of(ed);
        final a = objs.anchorOf(o);
        var w = a?.width ?? ObjectAnchor.defaultChartWidth;
        var h = a?.height ?? ObjectAnchor.defaultChartHeight;
        if (w <= 0) w = ObjectAnchor.defaultChartWidth;
        if (h <= 0) h = ObjectAnchor.defaultChartHeight;
        final scene = objs
            .chartOf(o)
            .sceneFor(
              w,
              h,
              dark: dark,
              export: true,
              tokens: dark ? ChartUiTokens.dark : ChartUiTokens.light,
            );
        return chartSceneToPng(scene, pixelRatio: pixelRatio);
      case EmbeddedObjectKind.image:
        final spec = ImageSpec.fromJson(o.specJson);
        final src = spec.fileUuid.isNotEmpty
            ? spec.fileUuid
            : (spec.sourceUrl ?? '');
        if (src.isEmpty) return null;
        return SheetsImageService.of(ed).pngOf(src);
      default:
        return null;
    }
  }
}
