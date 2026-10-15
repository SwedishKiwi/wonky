import 'package:serverpod/serverpod.dart';

import '../common/models.dart';

/// Facade of Bugs & Improvements (specs/16). Contract stub: the work
/// packages BI-2 and BI-7 implement it.
abstract final class BoardService {
  static Never _todo() => throw UnimplementedError('board: not built yet');

  static Future<BoardMe> me(Session session) async => _todo();
  static Future<BoardPostPage> list(Session session, BoardListQuery q) async =>
      _todo();
  static Future<BoardPostView> getPost(Session session, int number) async =>
      _todo();
  static Future<List<BoardCommentView>> listComments(
    Session session, {
    int? postNumber,
    int? taskNumber,
  }) async => _todo();
  static Future<List<BoardSimilarPost>> similar(
    Session session, {
    required String title,
    required String body,
    BoardPostKind? kind,
  }) async => _todo();
  static Future<String?> getScreenshotUrl(Session session, int number) async =>
      _todo();
  static Future<BoardTaskPage> listTasks(
    Session session,
    List<BoardTaskStatus> statuses,
    String? cursor,
    int limit,
  ) async => _todo();
  static Future<BoardTaskView> getTask(Session session, int number) async =>
      _todo();
  static Stream<BoardPostEvent> watchPost(Session session, int number) =>
      _todo();
  static Stream<BoardPostEvent> watchTasks(Session session) => _todo();
  static Future<FileUploadTicket> createScreenshotUpload(
    Session session,
    UuidValue fileUuid,
    String mimeType,
    int size,
  ) async => _todo();
  static Future<BoardPostView> createPost(
    Session session,
    BoardPostDraft draft,
  ) async => _todo();
  static Future<BoardPostView> editPost(
    Session session,
    int number,
    String title,
    String body,
  ) async => _todo();
  static Future<void> deletePost(Session session, int number) async => _todo();
  static Future<BoardPostView> restorePost(Session session, int number) async =>
      _todo();
  static Future<BoardPostView> removeScreenshot(
    Session session,
    int number,
  ) async => _todo();
  static Future<BoardVoteResult> vote(
    Session session,
    int number,
    int value,
  ) async => _todo();
  static Future<BoardCommentView> addComment(
    Session session, {
    required UuidValue uuid,
    int? postNumber,
    int? taskNumber,
    required String body,
  }) async => _todo();
  static Future<BoardCommentView> editComment(
    Session session,
    UuidValue uuid,
    String body,
  ) async => _todo();
  static Future<void> deleteComment(Session session, UuidValue uuid) async =>
      _todo();
  static Future<BoardCommentView> restoreComment(
    Session session,
    UuidValue uuid,
  ) async => _todo();
  static Future<void> flag(
    Session session,
    int? number,
    UuidValue? commentUuid,
    BoardFlagReason reason,
    String? note,
  ) async => _todo();
  static Future<void> unflag(
    Session session,
    int? number,
    UuidValue? commentUuid,
  ) async => _todo();
  static Future<BoardTaskView> claimTask(Session session, int number) async =>
      _todo();
  static Future<BoardTaskView> releaseTask(Session session, int number) async =>
      _todo();
  static Future<BoardReviewCounts> reviewCounts(Session session) async =>
      _todo();
  static Future<List<BoardReviewItem>> reviewQueue(
    Session session,
    BoardReviewSection section,
  ) async => _todo();
  static Future<BoardPostView> moderatePost(
    Session session,
    int number,
    BoardModerationAction action,
    String? reason,
  ) async => _todo();
  static Future<BoardCommentView> moderateComment(
    Session session,
    UuidValue uuid,
    BoardModerationAction action,
    String? reason,
  ) async => _todo();
  static Future<BoardPostView> adminEditPost(
    Session session,
    int number,
    String title,
    String body,
  ) async => _todo();
  static Future<BoardPostView> setLabels(
    Session session,
    int number,
    BoardPostKind kind,
    BoardArea? area,
    BoardSize? size,
  ) async => _todo();
  static Future<BoardPostView> applySuggestedTitle(
    Session session,
    int number,
  ) async => _todo();
  static Future<BoardPostView> dismissDuplicateHint(
    Session session,
    int number,
  ) async => _todo();
  static Future<BoardPostView> merge(
    Session session,
    int source,
    int target,
  ) async => _todo();
  static Future<BoardPostView> unmerge(Session session, int source) async =>
      _todo();
  static Future<BoardPostView> decline(
    Session session,
    int number,
    String reason,
  ) async => _todo();
  static Future<BoardPostView> reopen(Session session, int number) async =>
      _todo();
  static Future<void> blockUser(
    Session session,
    int userId,
    String reason,
    DateTime? until,
  ) async => _todo();
  static Future<void> unblockUser(Session session, int userId) async => _todo();
  static Future<BoardTaskView> createTask(
    Session session,
    List<int> postNumbers,
    String title,
    BoardArea area,
    BoardSize size,
  ) async => _todo();
  static Future<BoardTaskView> updateTask(
    Session session,
    int number,
    String title,
    BoardArea area,
    BoardSize size,
  ) async => _todo();
  static Future<BoardTaskView> setTaskPosts(
    Session session,
    int number,
    List<int> postNumbers,
  ) async => _todo();
  static Future<BoardTaskView> regeneratePrompt(
    Session session,
    int number,
  ) async => _todo();
  static Future<BoardTaskView> setPrompt(
    Session session,
    int number,
    String body,
  ) async => _todo();
  static Future<BoardTaskView> publishTask(Session session, int number) async =>
      _todo();
  static Future<BoardTaskView> setTaskStatus(
    Session session,
    int number,
    BoardTaskStatus status,
  ) async => _todo();
  static Future<BoardTaskView> linkPullRequest(
    Session session,
    int number,
    String? url,
  ) async => _todo();
  static Future<List<BoardBundleSuggestionView>> suggestBundles(
    Session session,
  ) async => _todo();
  static Future<List<BoardBundleSuggestionView>> listSuggestions(
    Session session,
  ) async => _todo();
  static Future<void> dismissSuggestion(Session session, int id) async =>
      _todo();
}
