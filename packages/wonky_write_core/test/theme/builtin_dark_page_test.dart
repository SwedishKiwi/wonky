import 'package:test/test.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

void main() {
  group('Given the built-in themes in dark mode', () {
    for (final b in BuiltinThemes.all) {
      test('when resolving ${b.name} then the page stands out from the '
          'canvas', () {
        final dark = ThemeResolver.instance.resolve(b.theme, ThemeVariant.dark);

        final ratio = ContrastChecker.ratio(
          dark.page.paperColor,
          dark.page.canvasColor,
        );

        expect(ratio, greaterThanOrEqualTo(1.18));
      });

      test('when resolving ${b.name} then code blocks differ from the '
          'page', () {
        final dark = ThemeResolver.instance.resolve(b.theme, ThemeVariant.dark);

        expect(dark.codeBlock.box.background, isNot(dark.page.paperColor));
      });
    }
  });
}
