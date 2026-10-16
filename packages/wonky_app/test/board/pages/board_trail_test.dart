import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/src/board/pages/board_trail.dart';

/// The board's breadcrumb trail (specs/16 §4.3): derived from the board's
/// hierarchy (root › list › task › post), carried in the URL query, and
/// never a loop.
void main() {
  BoardTrail parse(String location) => BoardTrail.parse(Uri.parse(location))!;

  group('Given a board location', () {
    test('when parsed then the lists, posts, tasks and contribute map to '
        'their trails', () {
      expect(parse('/improvements'), BoardTrail.root);
      expect(
        parse('/improvements/bugs'),
        const BoardTrail(list: BoardTab.bugs),
      );
      expect(parse('/improvements/review').list, BoardTab.review);
      expect(parse('/improvements/contribute').contribute, isTrue);
      expect(parse('/improvements/p/5'), const BoardTrail(post: 5));
      expect(
        parse('/improvements/p/5?list=tasks&task=1'),
        const BoardTrail(list: BoardTab.tasks, task: 1, post: 5),
      );
      expect(
        parse('/improvements/t/2?list=done'),
        const BoardTrail(list: BoardTab.done, task: 2),
      );
      expect(BoardTrail.parse(Uri.parse('/recent')), isNull);
      expect(BoardTrail.parse(Uri.parse('/improvements/p/x')), isNull);
    });

    test('when the query is unknown or contradicts the hierarchy then the '
        'defaults apply', () {
      expect(parse('/improvements/p/5?list=nope').list, isNull);
      expect(
        parse('/improvements/p/5?list=tasks').list,
        isNull,
        reason: 'Up for grabs lists no posts',
      );
      expect(
        parse('/improvements/p/5?list=bugs&task=1'),
        const BoardTrail(task: 1, post: 5),
        reason: 'a task is not under Bugs',
      );
      expect(parse('/improvements/t/2?list=improvements').list, isNull);
    });

    test('when a trail is written then its location round-trips', () {
      for (final l in [
        '/improvements',
        '/improvements/bugs',
        '/improvements/tasks',
        '/improvements/contribute',
        '/improvements/p/5',
        '/improvements/p/5?list=bugs',
        '/improvements/p/5?list=tasks&task=1',
        '/improvements/t/2',
        '/improvements/t/2?list=review',
      ]) {
        expect(parse(l).location, l);
      }
    });
  });

  group('Given the trail rules', () {
    const bugs = BoardTrail(list: BoardTab.bugs);
    const tasks = BoardTrail(list: BoardTab.tasks);

    test('when a post or task opens from a list then it goes under it', () {
      expect(bugs.openPost(4).location, '/improvements/p/4?list=bugs');
      expect(tasks.openTask(1).location, '/improvements/t/1?list=tasks');
      expect(
        tasks.openPost(4).location,
        '/improvements/p/4',
        reason: 'Up for grabs has no posts: the post\'s own list',
      );
      expect(
        bugs.openTask(1).location,
        '/improvements/t/1',
        reason: 'Bugs has no tasks: the task\'s own list',
      );
    });

    test(
      'when a linked post opens from a task then it goes under the task',
      () {
        final post = tasks.openTask(1).openPost(5);
        expect(post.location, '/improvements/p/5?list=tasks&task=1');
      },
    );

    test('when a post opens its task then the trail truncates to it, never '
        'post › task › post › task', () {
      final post = tasks.openTask(1).openPost(5);
      final task = post.openTask(1);
      expect(task.location, '/improvements/t/1?list=tasks');
      expect(task.openPost(5), post, reason: 'and back down, same trail');
      expect(
        bugs.openPost(4).openTask(1).location,
        '/improvements/t/1',
        reason: 'a post outside the task: the task under its own list',
      );
    });

    test('when another post opens from a post then it replaces it', () {
      final post = tasks.openTask(1).openPost(5);
      final sibling = post.openPost(7);
      expect(sibling.location, '/improvements/p/7?list=tasks&task=1');
      expect(post.isSiblingOf(sibling), isTrue);
      expect(
        bugs.openPost(4).openPost(8).location,
        '/improvements/p/8?list=bugs',
      );
    });

    test('when the trail is at its deepest then nothing goes deeper than '
        'root › list › task › post', () {
      var t = tasks.openTask(1).openPost(5);
      for (var i = 0; i < 5; i++) {
        t = t.openTask(i + 2).openPost(i + 10);
        expect(t.list, BoardTab.tasks);
        expect(t.post, i + 10);
        expect(t.task, i + 2);
      }
    });

    test('when moving at the same depth then it is a sibling move (replaces '
        'history), else not', () {
      expect(bugs.isSiblingOf(tasks), isTrue, reason: 'tab switch');
      expect(tasks.isSiblingOf(tasks.openTask(1)), isFalse);
      expect(tasks.openTask(1).isSiblingOf(tasks.openTask(2)), isTrue);
      expect(
        bugs.openPost(4).isSiblingOf(bugs.openPost(4).openTask(1)),
        isFalse,
      );
      expect(
        tasks.openTask(1).openPost(5).isSiblingOf(tasks.openTask(1)),
        isFalse,
        reason: 'up the trail',
      );
    });
  });
}
