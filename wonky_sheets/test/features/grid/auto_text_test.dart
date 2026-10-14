import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_sheets/features/grid/paint/auto_text.dart';
import 'package:wonky_sheets/theme/sheets_tokens.dart';

void main() {
  final light = GridPaintTokens.of(Brightness.light);
  final dark = GridPaintTokens.of(Brightness.dark);
  const yellow = Color(0xFFFFF2CC);
  const navy = Color(0xFF1C2E4A);

  test('Given no fill, then automatic text keeps the theme color', () {
    expect(autoTextOn(light, null), light.autoText);
    expect(autoTextOn(dark, null), dark.autoText);
  });

  test('Given a light fill in dark mode, then automatic text turns dark and '
      'readable (verification finding)', () {
    final c = autoTextOn(dark, yellow);
    expect(contrastRatio(c, yellow), greaterThanOrEqualTo(4.5));
    expect(c, isNot(dark.autoText));
  });

  test('Given a dark fill in light mode, then automatic text turns light', () {
    final c = autoTextOn(light, navy);
    expect(contrastRatio(c, navy), greaterThanOrEqualTo(4.5));
  });

  test('Given a light fill in light mode, then the theme color stays', () {
    expect(autoTextOn(light, yellow), light.autoText);
  });
}
