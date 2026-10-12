import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_ui/wonky_ui.dart';
import 'package:wonky_write/features/themes/document_theme.dart';
import 'package:wonky_write/features/themes/theme_picker.dart';
import 'package:wonky_write_core/wonky_write_core.dart' hide ThemeCatalog;

void main() {
  testWidgets('Given the theme picker when a card is tapped then the theme '
      'is selected', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final selected = ValueNotifier<String?>(BuiltinThemes.wonkyDefault.uuid);
    ThemeOption? picked;
    await tester.pumpWidget(
      ShadApp(
        theme: WonkyTheme.light(),
        home: Builder(
          builder: (context) => ShadButton(
            onPressed: () => showThemePicker(
              context,
              catalog: WriteThemeCatalog(),
              selected: selected,
              onSelect: (o) => picked = o,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ThemeCard), findsNWidgets(8));

    await tester.tap(find.byKey(const ValueKey('write.theme.card.classic-serif')));
    await tester.pump();

    expect(picked?.builtinKey, 'classic-serif');
  });
}
