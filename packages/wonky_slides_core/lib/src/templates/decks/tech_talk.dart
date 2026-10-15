import '../../model/api/kinds.dart';
import '../../motion/builds/build_options.dart';
import '../../motion/builds/transition_spec.dart';
import '../slides_template.dart';
import '../template_builder.dart';
import '../template_text.dart';
import 'parts.dart';

const _callbacks = '''
void showProfile(String id) {
  fetchUser(id).then((user) {
    fetchAvatar(user).then((avatar) {
      render(user, avatar);
    });
  });
}''';

const _awaited = '''
Future<void> showProfile(String id) async {
  final user = await fetchUser(id);
  final avatar = await fetchAvatar(user);
  render(user, avatar);
}''';

const _errors = '''
Future<void> showProfile(String id) async {
  try {
    final user = await fetchUser(id)
        .timeout(const Duration(seconds: 5));
    render(user, await fetchAvatar(user));
  } on TimeoutException {
    showOffline();
  } finally {
    hideSpinner();
  }
}''';

const _streamA = '''
final clicks = button.onClick;

clicks.listen((event) {
  counter.value++;
});''';

const _streamB = '''
final clicks = button.onClick
    .where((event) => !event.repeat)
    .map((event) => event.timeStamp);

clicks.listen((time) {
  counter.value++;
  log('clicked at \$time');
});''';

const _isolate = '''
Future<List<Photo>> loadAlbum(File file) async {
  final bytes = await file.readAsBytes();
  // Parsing 40 MB of JSON takes 300 ms:
  // keep it off the UI isolate.
  return Isolate.run(() => parseAlbum(bytes));
}''';

/// *Tech talk* on *Midnight* (dark): a conference talk that walks through
/// code — a callback pyramid typed into async/await, highlight steps with
/// callouts, a Magic Move of a stream pipeline between two slides — with
/// 3D cube transitions between its parts.
final SlidesTemplate techTalkTemplate = SlidesTemplate(
  key: 'slides.tech-talk',
  name: 'Tech talk',
  description: 'Walk through code with highlight steps and live typing.',
  category: 'education',
  themeKey: 'midnight',
  subtitle: 'Futures, streams and isolates · 25 min',
  defaultTransition: TransitionSpec.of('fade'),
  script: (b) {
    b.slide(
      'title',
      text: {
        'title': 'Async Dart, without the tears',
        'subtitle': 'Futures, streams and isolates · Tech talk · 25 min',
      },
      notes:
          'Introduce yourself in one sentence, then ask who has written a '
          'callback inside a callback this week.',
    );
    b.slide(
      'agenda',
      text: {
        'title': 'Today',
        'body': TemplateText.numbered([
          'From callbacks to await',
          'Errors and timeouts',
          'Streams, step by step',
          'When to reach for an isolate',
        ]),
      },
    );

    final cube = TransitionSpec.of('cube');
    b.group('Futures', color: 'blue');
    final s1 = b.slide(
      'section',
      text: {
        'label': 'Part 1',
        'title': 'From callbacks to await',
        'subtitle': 'Same behavior, half the nesting',
      },
    );
    b.transition([s1], cube);
    final typed = b.slide('code', text: {'title': 'Callbacks, then await'});
    final typedCode = b.codeStates(
      typed,
      const [
        TemplateCodeState(_callbacks, label: 'Callbacks'),
        TemplateCodeState(
          _awaited,
          label: 'async / await',
          mode: 'type',
          // Brisk enough for a talk: about four seconds.
          typing: {'cps': 45, 'maxDurationMs': 4500},
          highlight: '2 | 3 | 4',
          callouts: {
            1: 'Wait for the user **without blocking**',
            2: 'Then the avatar, in order',
            3: 'Plain code — no nesting',
          },
        ),
      ],
      language: 'dart',
      options: const {'title': 'profile.dart', 'chrome': 'tab'},
    );
    b.builds(typed, [
      emphasis(typedCode, 'codeState', params: const {'state': 2}),
      for (var step = 1; step <= 3; step++)
        emphasis(typedCode, 'codeHighlight', params: {'step': step}),
    ]);
    final errors = b.slide('code', text: {'title': 'Errors and timeouts'});
    final errorCode = b.codeStates(
      errors,
      const [
        TemplateCodeState(
          _errors,
          highlight: '3-4 | 6-7 | 8-9',
          callouts: {
            1: 'Give up after **5 s**',
            2: 'Catch only what you expect',
            3: 'Always runs',
          },
        ),
      ],
      language: 'dart',
      options: const {'title': 'profile.dart', 'chrome': 'tab'},
    );
    b.builds(errors, [
      for (var step = 1; step <= 3; step++)
        emphasis(errorCode, 'codeHighlight', params: {'step': step}),
    ]);

    b.group('Streams', color: 'teal');
    final s2 = b.slide(
      'section',
      text: {
        'label': 'Part 2',
        'title': 'Streams, step by step',
        'subtitle': 'Events over time, transformed like lists',
      },
    );
    b.transition([s2], cube);
    final before = b.slide('code', text: {'title': 'A stream of clicks'});
    b.matchKey(
      b.codeStates(before, const [
        TemplateCodeState(_streamA),
      ], language: 'dart'),
      'tech-talk.stream',
    );
    final after = b.slide(
      'code',
      text: {'title': 'A stream of clicks'},
      notes:
          'Magic Move: the code morphs into the new pipeline. Go back to '
          'show the difference again.',
    );
    b.matchKey(
      b.codeStates(after, const [
        TemplateCodeState(_streamB, highlight: '2-3 | 7'),
      ], language: 'dart'),
      'tech-talk.stream',
    );
    b.transition([after], TransitionSpec.of('magicMove'));
    b.slide(
      'comparison',
      text: {
        'title': 'Future or Stream?',
        'headingLeft': 'Future',
        'body': TemplateText.bullets([
          'One value, later',
          'A network request',
          'Reading a file',
        ]),
        'headingRight': 'Stream',
        'bodyRight': TemplateText.bullets([
          'Many values over time',
          'Clicks, sockets, sensors',
          'Lines of a growing log',
        ]),
      },
    );

    b.group('Isolates', color: 'violet');
    final s3 = b.slide(
      'bigNumber',
      text: {
        'bigNumber': '16 ms',
        'caption':
            'is all a frame gets at 60 fps — keep heavy work off the UI '
            'isolate',
      },
    );
    b.transition([s3], cube);
    b.builds(s3, [
      buildIn(
        b.placeholder(s3, 'bigNumber'),
        'zoom',
        trigger: SlideBuildTrigger.withPrevious,
      ),
      buildIn(
        b.placeholder(s3, 'caption'),
        'fade',
        trigger: SlideBuildTrigger.afterPrevious,
      ),
    ]);
    final iso = b.slide('code', text: {'title': 'One line to move work away'});
    final isoCode = b.code(
      iso,
      _isolate,
      language: 'dart',
      highlight: '3-4 | 5',
    );
    b.builds(iso, [
      for (var step = 1; step <= 2; step++)
        emphasis(isoCode, 'codeHighlight', params: {'step': step}),
    ]);
    final takeaways = b.slide(
      'titleBody',
      text: {
        'title': 'Takeaways',
        'body': TemplateText.bullets([
          'await reads top to bottom — prefer it to then()',
          'Add timeouts where the network is involved',
          'Transform streams like lists: where, map, take',
          'Isolate.run for anything over a few milliseconds',
        ]),
      },
    );
    b.builds(takeaways, [
      buildIn(
        b.placeholder(takeaways, 'body'),
        'rise',
        delivery: const BuildDelivery(by: DeliveryBy.paragraph),
      ),
    ]);
    b.endGroup();

    b.slide(
      'title',
      text: {
        'title': 'Thank you!',
        'subtitle': 'Slides and samples: talks.example/async-dart',
      },
    );
  },
);
