// Tests for WONKY PATCH AT-1.
import 'package:attributed_text/attributed_text.dart';
import 'package:test/test.dart';

void main() {
  group('AT-1 addAttribution >', () {
    const bold = NamedAttribution('bold');

    test(
        'adding a range inside an existing compatible span keeps the markers balanced',
        () {
      final spans = AttributedSpans()
        ..addAttribution(newAttribution: bold, start: 2, end: 9)
        ..addAttribution(newAttribution: bold, start: 3, end: 8);

      expect(spans.markers, [
        const SpanMarker(
            attribution: bold, offset: 2, markerType: SpanMarkerType.start),
        const SpanMarker(
            attribution: bold, offset: 9, markerType: SpanMarkerType.end),
      ]);
    });

    test('adding a range that ends inside an existing span merges with it', () {
      final spans = AttributedSpans()
        ..addAttribution(newAttribution: bold, start: 5, end: 9)
        ..addAttribution(newAttribution: bold, start: 0, end: 6);

      expect(spans.markers, [
        const SpanMarker(
            attribution: bold, offset: 0, markerType: SpanMarkerType.start),
        const SpanMarker(
            attribution: bold, offset: 9, markerType: SpanMarkerType.end),
      ]);
    });

    test('adding a range after an existing span still caps the new span', () {
      final spans = AttributedSpans()
        ..addAttribution(newAttribution: bold, start: 0, end: 2)
        ..addAttribution(newAttribution: bold, start: 5, end: 7);

      expect(spans.markers.where((m) => m.isEnd).map((m) => m.offset), [2, 7]);
    });
  });
}
