import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/wonky_app.dart' show CommandState;
import 'package:wonky_slides/features/present/present_settings.dart';
import 'package:wonky_slides/l10n/slides_l10n.dart';

import '../harness/deck_harness.dart';
import '../support/deck_screen.dart' show sampleDeck;

/// The present commands (Slides 10 §14; SL-19) through the real
/// dispatcher on the deck harness: starting opens the present route, the
/// in-presentation commands are disabled without a present screen, and
/// `slides.deck.setPresentSettings` is one undoable step.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = slidesL10nEnglish;
  late DeckHarness d;

  setUp(() => d = DeckHarness.open(fixture: sampleDeck()));
  tearDown(() => d.dispose());

  String location() =>
      d.services.router.routeInformationProvider.value.uri.toString();
  CommandState state(String id, [Map<String, Object?> args = const {}]) =>
      d.services.dispatcher.stateOf(id, args);
  String deckPath() => '/p/${d.session.itemUuid.uuid}';

  group('Given an open deck', () {
    test('when presenting from the current slide then the present route '
        'opens at it', () async {
      final second = d.editor.order.entries[1].id;
      d.editor.setCurrentSlide(second);

      final r = await d.run('slides.present.fromCurrent');

      expect(r.isOk, isTrue, reason: r.message);
      expect(location(), '${deckPath()}/present?slide=$second');
    });

    test('when presenting from the start then no slide is named', () async {
      await d.run('slides.present.fromStart');

      expect(location(), '${deckPath()}/present');
    });

    test('when opening the presenter view then view=presenter', () async {
      await d.run('slides.present.presenterView', {'from': 'start'});

      expect(location(), '${deckPath()}/present?view=presenter');
    });

    test('when presenting from a slide then it is named', () async {
      final last = d.editor.order.entries.last.id;

      await d.run('slides.present.fromSlide', {'slideId': last});

      expect(location(), '${deckPath()}/present?slide=$last');
    });

    test('when joining as audience then the audience route of the session '
        'opens', () async {
      await d.run('slides.present.joinAsAudience', {
        'sessionId': 'AbCdEfGhIjKlMnOpQrStUv',
      });

      expect(
        location(),
        '${deckPath()}/present?view=audience&session=AbCdEfGhIjKlMnOpQrStUv',
      );
    });

    test('when not presenting then in-presentation commands are disabled '
        'with a reason', () {
      for (final id in [
        'slides.present.next',
        'slides.present.previous',
        'slides.present.end',
        'slides.present.blank',
        'slides.present.picker',
        'slides.present.tool',
        'slides.present.help',
      ]) {
        final st = state(id, const {'color': 'black', 'tool': 'pen'});
        expect(st.enabled, isFalse, reason: id);
        expect(st.disabledReason, l.reasonNotPresenting, reason: id);
      }
    });

    test('when presentation settings are patched then presentJson changes '
        'in one undo step that undo and redo replay', () async {
      final r = await d.run('slides.deck.setPresentSettings', {
        'patch': {'endBehavior': 'loop', 'letterboxColor': '#202020'},
      });

      expect(r.isOk, isTrue, reason: r.message);
      PresentSettings now() => PresentSettings.parse(d.model.deck!.presentJson);
      expect(now().endBehavior, 'loop');
      expect(now().letterboxColor, 0xff202020);
      expect(d.undoLabels, hasLength(1));

      await d.undo();
      expect(d.model.deck!.presentJson, isNull);
      await d.redo();
      expect(now().endBehavior, 'loop');
    });

    test('when a settings patch is invalid then nothing changes', () async {
      final r = await d.run('slides.deck.setPresentSettings', {
        'patch': {'mode': 'disco'},
      });

      expect(r.isOk, isFalse);
      expect(d.model.deck!.presentJson, isNull);
      expect(d.undoLabels, isEmpty);
    });
  });
}
