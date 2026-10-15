import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shad/shad.dart';
import 'package:wonky_app/wonky_app.dart';

/// A 1×1 transparent PNG.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<void> _open(WidgetTester tester, Brightness brightness) async {
  await tester.pumpWidget(
    ShadApp(
      theme: ShadThemeData(
        brightness: brightness,
        colorScheme: brightness == Brightness.dark
            ? const ShadSlateColorScheme.dark()
            : const ShadSlateColorScheme.light(),
      ),
      home: Builder(
        builder: (context) => Center(
          child: ShadButton(
            onPressed: () => showImageLightbox(
              context,
              image: MemoryImage(_png),
              alt: 'A tiny dot',
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  // Image decoding is real async work.
  for (var i = 0; i < 50; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(ShadSpinner).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

String _zoom(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(LightboxKeys.zoomLabel)).data!;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Given an image (${brightness.name}) when opening the '
        'lightbox then it shows at 100 % with its alt text', (tester) async {
      await _open(tester, brightness);

      expect(find.byKey(LightboxKeys.overlay), findsOneWidget);
      expect(_zoom(tester), '100%');
      expect(find.text('A tiny dot'), findsOneWidget);
    });
  }

  testWidgets('Given the lightbox when zooming in and out then the zoom stays '
      'within 25–400 %', (tester) async {
    await _open(tester, Brightness.light);

    for (var i = 0; i < 12; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
    }
    expect(_zoom(tester), '400%');

    for (var i = 0; i < 20; i += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
    }
    expect(_zoom(tester), '25%');

    await tester.tap(find.byKey(LightboxKeys.fit));
    await tester.pump();
    expect(_zoom(tester), '100%');
  });

  testWidgets('Given the lightbox when pressing Esc then it closes', (
    tester,
  ) async {
    await _open(tester, Brightness.light);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(LightboxKeys.overlay), findsNothing);
  });

  testWidgets('Given the lightbox when clicking the close button then it '
      'closes', (tester) async {
    await _open(tester, Brightness.dark);

    await tester.tap(find.byKey(LightboxKeys.close));
    await tester.pumpAndSettle();

    expect(find.byKey(LightboxKeys.overlay), findsNothing);
  });
}
