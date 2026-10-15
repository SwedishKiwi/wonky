import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart' show DriveHomeScreen, DriveLocation;
import 'package:wonky_ui/testing.dart';
import 'package:wonky_client/wonky_client.dart'
    show
        AccessRole,
        Client,
        DriveItemKind,
        TemplateCategory,
        TemplateView,
        UuidValue;
import 'package:wonky_slides/config/slides_app_config.dart';
import 'package:wonky_slides/features/model/synced_deck_session.dart';
import 'package:wonky_slides/features/stage/slide_renderer.dart';
import 'package:wonky_slides/features/sync/slides_data.dart';
import 'package:wonky_slides/features/sync/slides_replica.dart';
import 'package:wonky_slides/features/thumbnails/slide_thumbnail.dart';
import 'package:wonky_slides_core/templates.dart';
import 'package:wonky_slides_core/themes.dart' show SlideAppearance;
import 'package:wonky_sync_models/ids.dart' show SequentialIdGenerator;

import '../../sync/support/slides_sync_harness.dart';
import '../../support/slides_harness.dart';
import '../text_editing/text_edit_fixture.dart' show realFonts;

TemplateView _view(SlidesTemplate t, {bool builtin = true}) => TemplateView(
  uuid: UuidValue.fromString(t.uuid),
  key: t.key,
  kind: DriveItemKind.presentation,
  name: t.name,
  description: t.description,
  category: TemplateCategory.values.byName(t.category),
  builtin: builtin,
  previewText: '# ${t.name}\n${t.subtitle}',
);

void main() {
  const config = SlidesAppConfig();

  group('Given a signed-in user with the Slides data layer', () {
    late CommandTestHarness h;
    late FakeSlidesServer server;

    setUp(() async {
      server = await FakeSlidesServer.open();
      h = CommandTestHarness(config: config);
      addTearDown(h.dispose);
      final me = h.services.me!.uuid;
      final dir = await Directory.systemTemp.createTemp('wonky_slides_tpl_');
      addTearDown(() => dir.delete(recursive: true));
      var n = 0;
      SlidesData.install(
        h.services,
        open: (user) => SlidesReplica.open(
          client: Client('http://localhost:1/'),
          path: '${dir.path}/slides_${n++}.db',
          userUuid: user,
        ),
        remote: () => FakeRemote(server, me)..subscribeRole = AccessRole.owner,
      );
      addTearDown(() => SlidesData.uninstall(h.services));
    });

    test('when a built-in template is chosen offline then its deck is '
        'created locally, registered with the space as item uuid and opens '
        'with every slide', () async {
      final c = (await SlidesData.ready(h.services))!;
      await prepareReservations(c);
      h.services.connectivity.forceOffline(true);
      await eventually(() => !c.online.value);
      final t = SlidesTemplates.byKey('slides.lesson')!;

      final uuid = await config.createItem(
        h.services,
        templateUuid: UuidValue.fromString(t.uuid),
        name: t.name,
      );

      expect(uuid, isNotNull);
      expect(h.drive.calls, contains('registerPresentation'));
      expect(h.drive.calls, isNot(contains('createPresentation')));
      expect(h.drive.item(uuid!).name, 'Lesson');
      expect(await c.replica.hasDeck(uuid), isTrue);
      final s = await openDeckSession(h.services, uuid);
      addTearDown(s.dispose);
      await (s as SyncedDeckSession).opened;
      final expected = SlidesTemplateDecksForTest.of(t);
      expect(s.model.deck?.title, 'Lesson');
      expect(s.model.slides, hasLength(expected.model.slides.length));
      expect(s.model.groups, hasLength(expected.model.groups.length));
    });

    test('when a template that is not built in is chosen then the server '
        'copies it', () async {
      final c = (await SlidesData.ready(h.services))!;
      await prepareReservations(c);

      await config.createItem(
        h.services,
        templateUuid: UuidValue.fromString(
          '0192f0a0-0000-7000-8000-00000000beef',
        ),
        name: 'Team template',
      );

      expect(h.drive.calls, contains('createPresentation'));
      expect(h.drive.calls, isNot(contains('registerPresentation')));
    });
  });

  for (final brightness in Brightness.values) {
    group('Given the Slides home with the built-in templates '
        '(${brightness.name})', () {
      late CommandTestHarness h;
      setUp(() {
        h = slidesHarness();
        h.drive.templates = [
          for (final t in SlidesTemplates.all) _view(t),
          _view(SlidesTemplates.byKey('slides.lesson')!, builtin: false),
        ];
      });
      tearDown(() => h.dispose());

      testWidgets('when the template strip shows then built-in cards render '
          'the first slide of their deck, slide-shaped, and a published '
          'template gets the shell\'s miniature', (tester) async {
        await pumpSlides(
          tester,
          h,
          DriveHomeScreen(
            services: h.services,
            location: const DriveLocation.home(),
          ),
          brightness: brightness,
        );
        await tester.pump();

        final thumbs = tester
            .widgetList<SlideThumbnail>(find.byType(SlideThumbnail))
            .toList();
        // The strip shows six templates: five built-ins render slides.
        expect(thumbs, hasLength(5));
        for (final thumb in thumbs) {
          expect(thumb.slideId, thumb.renderer.model.slides.first.id);
          final size = tester.getSize(find.byWidget(thumb));
          expect(size.width / size.height, closeTo(16 / 9, 0.01));
          expect(
            thumb.renderer.thumbnail(thumb.slideId, width: size.width),
            isNotNull,
          );
        }
        expect(
          find.byKey(
            ValueKey<String>('drive.template.${SlidesTemplates.all.first.key}'),
          ),
          findsOneWidget,
        );
        await settleTooltips(tester);
      });
    });
  }

  // Gallery screenshots (12 §4 SL-22): a contact sheet of every template's
  // slides in both appearances, with the real fonts. Set
  // WONKY_TEMPLATE_PNG_DIR to write them.
  final pngDir = Platform.environment['WONKY_TEMPLATE_PNG_DIR'];
  testWidgets('when rendering every template slide then each has a picture '
      '(contact sheets with WONKY_TEMPLATE_PNG_DIR)', (tester) async {
    await tester.runAsync(() => realFonts.ensureAll(realFontFamilies));
    for (final t in SlidesTemplates.all) {
      final renderer = SlideRenderer(
        model: SlidesTemplateDecksForTest.of(t).model,
        fonts: realFonts,
      );
      addTearDown(renderer.dispose);
      for (final appearance in SlideAppearance.values) {
        const w = 480.0, h = 270.0, gap = 16.0, cols = 3;
        final slides = renderer.model.slides;
        final rows = (slides.length + cols - 1) ~/ cols;
        final sheet = ui.PictureRecorder();
        final canvas = Canvas(sheet)
          ..drawColor(const Color(0xff808080), BlendMode.src);
        for (final (i, s) in slides.indexed) {
          final pic = renderer.thumbnail(
            s.id,
            width: w,
            appearance: appearance,
          );
          expect(pic, isNotNull, reason: '${t.key} slide ${i + 1}');
          canvas
            ..save()
            ..translate(
              gap + (i % cols) * (w + gap),
              gap + (i ~/ cols) * (h + gap),
            )
            ..clipRect(const Rect.fromLTWH(0, 0, w, h))
            ..drawPicture(pic!.picture)
            ..restore();
        }
        final picture = sheet.endRecording();
        if (pngDir == null) continue;
        // Contact sheet: every slide of the template, 3 per row.
        await tester.runAsync(() async {
          final image = await picture.toImage(
            (gap + cols * (w + gap)).round(),
            (gap + rows * (h + gap)).round(),
          );
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$pngDir/${t.key}-${appearance.name}.png');
          await file.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
        });
      }
    }
  });
}

/// The families the built-in themes use.
final List<String> realFontFamilies = const [
  'Open Sans',
  'EB Garamond',
  'JetBrains Mono',
  'Roboto',
  'Lato',
  'Source Sans 3',
  'Nunito',
  'Montserrat',
  'Merriweather',
  'Roboto Mono',
];

/// Template decks built with fixed ids (like the gallery previews).
abstract final class SlidesTemplateDecksForTest {
  static final Map<String, SlidesTemplateDeck> _decks = {};

  static SlidesTemplateDeck of(SlidesTemplate t) => _decks[t.key] ??= t.build(
    deckId: '00000000-0000-4000-8000-00000000c0de',
    userId: '00000000-0000-4000-8000-000000000001',
    now: DateTime.utc(2026),
    ids: SequentialIdGenerator(1),
  );
}
