import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';

import '../support/screen_pump.dart';

TemplateView _deck({String key = 'slides.pitch-deck'}) => TemplateView(
  uuid: const Uuid().v5obj(Namespace.url.value, 'wonky-template:$key'),
  key: key,
  kind: DriveItemKind.presentation,
  name: 'Pitch deck',
  description: 'Tell investors your story.',
  category: TemplateCategory.work,
  builtin: true,
  previewText: '# Lumen\nReal-time energy insights for every building',
  themeKey: 'aurora',
  previewStyle: TemplatePreviewStyle(
    paper: '#f5f3ff',
    text: '#4c4f6b',
    heading: '#1e1b4b',
    accent: '#db2777',
    darkPaper: '#120f33',
    darkText: '#cbd5e1',
    darkHeading: '#f8fafc',
    darkAccent: '#f472b6',
    banner: false,
    centeredHeadings: false,
    uppercaseHeadings: false,
    fontCategory: 'sans',
  ),
);

/// (v2, Slides 04 §15) Presentation template cards are slide-shaped and
/// show a miniature title slide unless the app renders a preview
/// (`WonkyAppConfig.templatePreview`).
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Given an app home for presentations (${brightness.name}) '
        'when the template strip shows then presentation cards are 16:9 '
        'with the title slide miniature', (tester) async {
      final h = CommandTestHarness(
        config: const TestAppConfig(
          app: WonkyAppKind.slides,
          scope: HomeScope.kind(DriveItemKind.presentation),
        ),
        drive: FakeDriveRepository(templates: [_deck()]),
      );
      addTearDown(h.dispose);
      h.services.router = GoRouter(
        routes: [
          for (final p in const ['/', '/my-files', '/templates', '/p/:uuid'])
            GoRoute(path: p, builder: (_, _) => const SizedBox()),
        ],
      );

      await pumpScreen(
        tester,
        h,
        DriveHomeScreen(
          services: h.services,
          location: const DriveLocation.home(),
        ),
        brightness: brightness,
      );

      final card = find.byKey(
        const ValueKey<String>('drive.template.slides.pitch-deck'),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Lumen')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Real-time energy insights for every building'),
        ),
        findsOneWidget,
      );
      // The blank card is slide-shaped too.
      final blank = find.byKey(const ValueKey<String>('drive.template.blank'));
      for (final f in [card, blank]) {
        final preview = find
            .descendant(of: f, matching: find.byType(Container))
            .first;
        final size = tester.getSize(preview);
        expect(size.width, closeTo(148 * 1.4, 0.01));
        expect((size.width - 2) / (size.height - 2), closeTo(16 / 9, 0.01));
      }
    });
  }
}
