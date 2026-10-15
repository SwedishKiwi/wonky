import 'package:test/test.dart';
import 'package:wonky_spellcheck/wonky_spellcheck.dart';

/// A checker for a hand-written `.aff`/`.dic` fixture.
SpellChecker checkerFor(String aff, String dic) =>
    SpellChecker(HunspellDictionary.parse(aff, dic));

/// One test per `(word, accepted)` vector, named Given/when/then style.
void checkVectors(
  SpellChecker Function() checker,
  List<(String, bool)> vectors,
) {
  for (final (word, accepted) in vectors) {
    test(
      'when checking "$word" then it is ${accepted ? 'accepted' : 'rejected'}',
      () => expect(checker().check(word), accepted),
    );
  }
}

/// A [Stopwatch] whose elapsed time is set by the test.
final class FakeStopwatch implements Stopwatch {
  FakeStopwatch([this.elapsedMicrosecondsValue = 0]);

  int elapsedMicrosecondsValue;

  @override
  int get frequency => 1000000;

  @override
  int get elapsedTicks => elapsedMicrosecondsValue;

  @override
  Duration get elapsed => Duration(microseconds: elapsedMicrosecondsValue);

  @override
  int get elapsedMicroseconds => elapsedMicrosecondsValue;

  @override
  int get elapsedMilliseconds => elapsedMicrosecondsValue ~/ 1000;

  @override
  bool get isRunning => true;

  @override
  void reset() => elapsedMicrosecondsValue = 0;

  @override
  void start() {}

  @override
  void stop() {}
}

/// A budget large enough that suggestion tests never depend on speed.
const Duration unlimited = Duration(minutes: 1);
