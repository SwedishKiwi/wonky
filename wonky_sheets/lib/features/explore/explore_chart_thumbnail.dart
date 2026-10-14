import 'package:flutter/widgets.dart';
import 'package:wonky_sheets_core/model.dart';

import '../charts/controller/chart_controller.dart'
    show chartDarkOf, chartUiTokensOf;
import '../charts/render/chart_painter.dart';
import '../sheet_editor/sheet_editor_controller.dart';

/// A miniature of a suggested chart (Explore, 04 §7): the spec resolved
/// against the live data, laid out at [layoutSize] and painted scaled down
/// to [size] with the chart painter, in the app's light/dark chart colors.
class ExploreChartThumbnail extends StatefulWidget {
  const ExploreChartThumbnail({
    super.key,
    required this.editor,
    required this.spec,
    this.size = const Size(132, 84),
    this.layoutSize = const Size(264, 168),
  });

  final SheetEditorController editor;
  final ChartSpec spec;
  final Size size;
  final Size layoutSize;

  @override
  State<ExploreChartThumbnail> createState() => _ExploreChartThumbnailState();
}

class _ExploreChartThumbnailState extends State<ExploreChartThumbnail> {
  ChartScene? _scene;
  Object? _key;

  ChartScene? _build(BuildContext context) {
    final dark = chartDarkOf(context);
    final tokens = chartUiTokensOf(context);
    final key = (widget.spec, dark, tokens.card, tokens.foreground);
    if (_key == key) return _scene;
    _key = key;
    final ed = widget.editor;
    try {
      // Thumbnails show the shape of the data, not its titles.
      final spec = widget.spec;
      final data = ChartPipeline.resolve(spec, ed.model, ed.engine);
      _scene = ChartPipeline.layout(
        spec,
        data,
        size: ChartSize(widget.layoutSize.width, widget.layoutSize.height),
        theme: ChartTheme.from(ed.model.theme, dark: dark, tokens: tokens),
        measurer: FlutterTextMeasurer.instance,
        locale: ed.locale,
      ).scene;
    } on Object catch (e) {
      debugPrint('Explore chart thumbnail failed: $e');
      _scene = null;
    }
    return _scene;
  }

  @override
  Widget build(BuildContext context) {
    final scene = _build(context);
    final scale = widget.size.width / widget.layoutSize.width;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(
          size: widget.size,
          painter: ChartScenePainter(scene, scale: scale),
        ),
      ),
    );
  }
}
