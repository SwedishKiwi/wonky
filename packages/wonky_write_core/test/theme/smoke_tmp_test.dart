import 'dart:convert';
import 'package:test/test.dart';
import 'package:wonky_write_core/src/theme/resolve/base_theme.dart';
import 'package:wonky_write_core/src/theme/resolve/theme_resolver.dart';
import 'package:wonky_write_core/src/theme/model/values.dart';
void main() {
  test('smoke', () {
    final t = BaseTheme.instance.theme;
    print(t.canonicalJson.length);
    final r = ThemeResolver.instance.resolve(t, ThemeVariant.light);
    print(const JsonEncoder.withIndent(' ').convert(r.toJson()).substring(0, 3000));
    final d = ThemeResolver.instance.resolve(t, ThemeVariant.dark);
    print(d.toJson()['palette']);
    print(d.toJson()['syntax']);
  });
}
