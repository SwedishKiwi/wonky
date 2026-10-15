import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wonky_slides_core/interfaces.dart';
import 'package:wonky_slides_core/model.dart' show DeckModel;
import 'package:wonky_slides_core/pdf.dart';

import '../../l10n/slides_l10n.dart';
import 'slides_client_export.dart';

/// Which slides the preview prints (10 §11.1 `range`).
enum PrintRangeChoice { all, current, selection, custom }

/// Renders a PDF with [options] (the print preview's renderer; tests
/// replace it).
typedef SlidesPdfRenderFn =
    Future<SlidesPdfResult> Function(
      DeckModel deck,
      SlidesPdfOptions options,
      bool Function() isCancelled,
    );

/// The state of the print / PDF preview (Slides 10 §12): the options of the
/// settings column, the client-rendered PDF (regenerated 300 ms after the
/// last change, older renders discarded) and its page count and warnings.
class SlidesPrintController extends ChangeNotifier {
  SlidesPrintController({
    required this.deck,
    required this.render,
    required SlidesPdfOptions options,
    this.currentSlideId,
    this.selectedSlideIds = const [],
    this.debounce = const Duration(milliseconds: 300),
    this.locale,
  }) : _options = options.copyWith(clearSlideIds: true, clearGroupIds: true) {
    final r = options.range.trim();
    if (r != 'all' && SlidesPdfOptionsCodec.positions(r, 1 << 20) != null) {
      _range = PrintRangeChoice.custom;
      _custom = r;
    }
    _options = _options.copyWith(range: 'all');
    deck.addListener(_onDeck);
  }

  final DeckModel deck;
  final SlidesPdfRenderFn render;

  /// The editor's current slide (`current` range).
  final String? currentSlideId;

  /// The navigator selection (`selection` range).
  final List<String> selectedSlideIds;

  /// Delay between an option change and the new render.
  final Duration debounce;

  /// Locale of the paper defaults (Letter/A4).
  final String? locale;

  SlidesPdfOptions _options;
  PrintRangeChoice _range = PrintRangeChoice.all;
  String _custom = '';

  Uint8List? _pdf;
  int? _pageCount;
  List<String> _warnings = const [];
  bool _busy = false;
  Object? _error;
  int _generation = 0;
  Timer? _timer;
  bool _disposed = false;

  /// The options shown in the settings column (range = `all`; the range
  /// choice is [range]).
  SlidesPdfOptions get options => _options;

  PrintRangeChoice get range => _range;

  /// The positions text of the custom range (`"1-3,7"`).
  String get customRange => _custom;

  /// Whether the custom range text is valid.
  bool get customRangeValid =>
      _range != PrintRangeChoice.custom ||
      SlidesPdfOptionsCodec.positions(_custom.trim(), 1 << 20) != null;

  Uint8List? get pdf => _pdf;
  int? get pageCount => _pageCount;
  List<String> get warnings => _warnings;
  bool get busy => _busy;
  Object? get error => _error;

  /// The options the PDF is rendered with: the range choice resolved to
  /// slide ids or positions.
  SlidesPdfOptions get effectiveOptions => switch (_range) {
    PrintRangeChoice.all => _options,
    PrintRangeChoice.current => _options.copyWith(slideIds: [?currentSlideId]),
    PrintRangeChoice.selection => _options.copyWith(
      slideIds: selectedSlideIds.isEmpty ? [?currentSlideId] : selectedSlideIds,
    ),
    PrintRangeChoice.custom => _options.copyWith(range: _custom.trim()),
  };

  /// Applies [o] and schedules a render.
  void setOptions(SlidesPdfOptions o) {
    _options = o.copyWith(range: 'all', clearSlideIds: true);
    _changed();
  }

  /// Switches the layout with its paper/margin/frame defaults.
  void setLayout(SlidesPdfLayout layout) =>
      setOptions(_options.withLayout(layout, locale: locale));

  void setRange(PrintRangeChoice r, {String? custom}) {
    _range = r;
    if (custom != null) _custom = custom;
    _changed();
  }

  void _changed() {
    notifyListeners();
    if (!customRangeValid) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(refresh()));
  }

  void _onDeck(Object? _) {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 1), () => unawaited(refresh()));
  }

  /// Renders now (the first render and *Try again*).
  Future<void> refresh() async {
    _timer?.cancel();
    if (_disposed) return;
    final gen = ++_generation;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final r = await render(
        deck,
        effectiveOptions,
        () => _disposed || gen != _generation,
      );
      if (_disposed || gen != _generation) return;
      _pdf = Uint8List.fromList(r.bytes);
      _pageCount = r.pageCount;
      _warnings = r.warnings;
      _busy = false;
      notifyListeners();
    } on SlidesPdfCancelledException {
      // A newer render took over.
    } on Object catch (e) {
      if (_disposed || gen != _generation) return;
      _error = e;
      _busy = false;
      notifyListeners();
    }
  }

  /// The warning texts of the current PDF.
  List<String> warningTexts(SlidesLocalizations l) => [
    for (final w in {
      for (final code in _warnings) SlidesClientExport.warning(l, code),
    })
      w,
  ];

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    deck.removeListener(_onDeck);
    super.dispose();
  }
}
