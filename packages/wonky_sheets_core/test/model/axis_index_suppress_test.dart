import 'package:test/test.dart';
import 'package:wonky_sheets_core/model.dart';
import 'package:wonky_sync_models/ids.dart' show FractionalIndex;

void main() {
  group('Given rows hidden by a computed layer', () {
    late AxisIndex axis;

    setUp(() {
      axis = AxisIndex();
      String? key;
      for (var i = 0; i < 5; i++) {
        key = FractionalIndex.between(key, null);
        axis.upsert('r$i', key);
      }
      axis.setHiddenLayer('filter', {'r1', 'r2'});
    });

    test('when the layer is suppressed then the rows show but the layer '
        'still reports them (07 §4.3)', () {
      expect(axis.isHidden(1), isTrue);
      expect(axis.sizeAt(1), 0);

      axis.setLayerSuppressed('filter', true);

      expect(axis.isHidden(1), isFalse);
      expect(axis.sizeAt(1), axis.defaultSize);
      expect(axis.isHiddenBy('filter', 1), isTrue);
      expect(axis.hiddenLayer('filter'), {'r1', 'r2'});
      expect(axis.isLayerSuppressed('filter'), isTrue);
    });

    test('when another layer is active then only the suppressed one is '
        'ignored', () {
      axis
        ..setHiddenLayer('filterView', {'r3'})
        ..setLayerSuppressed('filter', true);

      expect(axis.isHidden(1), isFalse);
      expect(axis.isHidden(3), isTrue);

      axis.setLayerSuppressed('filter', false);
      expect(axis.isHidden(1), isTrue);
    });
  });
}
