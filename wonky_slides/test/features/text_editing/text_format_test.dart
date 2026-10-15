import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_slides/features/text_editing/text_format.dart';

void main() {
  group('Given the box defaults of a placeholder', () {
    test('when they name a bulleted list then a plain paragraph is '
        'bulleted', () {
      expect(effectiveList(const {}, const {'list': 'bullet'}), 'bullet');
    });

    test('when they also set listStyle none (the statement layout over the '
        'master body, SL-36) then a plain paragraph has no list', () {
      expect(
        effectiveList(const {}, const {'list': 'bullet', 'listStyle': 'none'}),
        isNull,
      );
    });

    test('when the paragraph has its own list then it wins over a '
        'listStyle none default', () {
      expect(
        effectiveList(const {'list': 'ordered'}, const {'listStyle': 'none'}),
        'ordered',
      );
    });
  });
}
