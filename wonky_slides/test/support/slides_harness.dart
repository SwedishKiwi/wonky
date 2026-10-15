import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_slides/config/slides_app_config.dart';
import 'package:wonky_ui/testing.dart';

/// A [CommandTestHarness] for Wonky Slides with quiet comment and presence
/// repositories (the editor frame starts both) and a router with the home
/// and the deck route of [SlidesAppConfig].
CommandTestHarness slidesHarness({
  String initialLocation = '/',
  StorageController? storage,
  PresenceRepository? presence,
  CommentRepository? comments,
  VersionRepository? versions,
}) {
  const config = SlidesAppConfig();
  final h = CommandTestHarness(
    config: config,
    storage: storage,
    versions: versions,
    comments: comments ?? QuietCommentRepository(),
    presence: presence ?? QuietPresenceRepository(),
  );
  h.services.router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Text('slides.home', key: ValueKey('home')),
      ),
      GoRoute(
        path: '/p/:uuid',
        builder: (context, state) =>
            config.buildEditor(context, state, state.pathParameters['uuid']!),
      ),
    ],
  );
  return h;
}

/// Pumps [screen] with the harness services, the shell and Slides
/// localizations, in [brightness].
Future<void> pumpSlides(
  WidgetTester tester,
  CommandTestHarness h,
  Widget screen, {
  Brightness brightness = Brightness.light,
  Size size = const Size(1440, 900),
}) async {
  await pumpWonky(
    tester,
    screen,
    brightness: brightness,
    size: size,
    extraDelegates: [
      WonkyAppLocalizations.delegate,
      ...h.services.config.localizationsDelegates,
    ],
    wrap: (context, child) =>
        Provider<ShellServices>.value(value: h.services, child: child!),
  );
  await tester.pumpAndSettle();
}

/// Comments without threads whose live stream stays open and silent.
class QuietCommentRepository implements CommentRepository {
  final _events = StreamController<CommentEvent>.broadcast();

  @override
  Future<List<CommentThreadView>> listThreads(
    UuidValue itemUuid, {
    CommentFilter filter = CommentFilter.all,
  }) async => const [];

  @override
  Stream<CommentEvent> watch(UuidValue itemUuid) => _events.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'QuietCommentRepository does not fake ${invocation.memberName}',
  );
}

/// A presence roster that stays open and silent.
class QuietPresenceRepository implements PresenceRepository {
  final _events = StreamController<PresenceEvent>.broadcast();

  @override
  Stream<PresenceEvent> join(
    UuidValue itemUuid,
    Stream<PresenceUpdate> updates,
  ) => _events.stream;
}
