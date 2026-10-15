import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../../l10n/wonky_app_localizations.dart';

/// User-visible names of the board's enums (specs/16 §2).
extension BoardLabels on WonkyAppLocalizations {
  String boardKindName(BoardPostKind k) => switch (k) {
    BoardPostKind.bug => boardKindBug,
    BoardPostKind.idea => boardKindIdea,
  };

  String boardAreaName(BoardArea a) => switch (a) {
    BoardArea.drive => boardAreaDrive,
    BoardArea.write => boardAreaWrite,
    BoardArea.sheets => boardAreaSheets,
    BoardArea.slides => boardAreaSlides,
    BoardArea.suite => boardAreaSuite,
    BoardArea.server => boardAreaServer,
  };

  String boardSizeName(BoardSize s) => switch (s) {
    BoardSize.small => boardSizeSmall,
    BoardSize.medium => boardSizeMedium,
    BoardSize.large => boardSizeLarge,
  };

  String boardStatusName(BoardPostStatus s) => switch (s) {
    BoardPostStatus.open => boardStatusOpen,
    BoardPostStatus.planned => boardStatusPlanned,
    BoardPostStatus.done => boardStatusDone,
    BoardPostStatus.shipped => boardStatusShipped,
    BoardPostStatus.declined => boardStatusDeclined,
    BoardPostStatus.duplicate => boardStatusDuplicate,
  };

  String boardTaskStatusName(BoardTaskStatus s) => switch (s) {
    BoardTaskStatus.draft => boardTaskDraft,
    BoardTaskStatus.published => boardTaskPublished,
    BoardTaskStatus.claimed => boardTaskClaimed,
    BoardTaskStatus.inReview => boardTaskInReview,
    BoardTaskStatus.done => boardStatusDone,
    BoardTaskStatus.shipped => boardStatusShipped,
    BoardTaskStatus.cancelled => boardTaskCancelled,
  };

  String boardFlagReasonName(BoardFlagReason r) => switch (r) {
    BoardFlagReason.offensive => boardReasonOffensive,
    BoardFlagReason.spam => boardReasonSpam,
    BoardFlagReason.personalData => boardReasonPersonalData,
    BoardFlagReason.security => boardReasonSecurity,
    BoardFlagReason.other => boardReasonOther,
  };

  String boardModerationName(BoardModeration m) => switch (m) {
    BoardModeration.checking => boardModerationChecking,
    BoardModeration.visible => boardModerationVisible,
    BoardModeration.held => boardModerationHeld,
    BoardModeration.removed => boardModerationRemoved,
  };

  String boardSortName(BoardSort s) => switch (s) {
    BoardSort.trending => boardSortTrending,
    BoardSort.top => boardSortTop,
    BoardSort.newest => boardSortNew,
    BoardSort.discussed => boardSortDiscussed,
  };
}

/// The design-system color of a status (always shown with its label,
/// specs/16 §4.7).
Color boardStatusColor(ShadColorScheme cs, Enum status) => switch (status) {
  BoardPostStatus.planned ||
  BoardTaskStatus.published ||
  BoardTaskStatus.claimed => cs.info,
  BoardTaskStatus.inReview => cs.warning,
  BoardPostStatus.done ||
  BoardPostStatus.shipped ||
  BoardTaskStatus.done ||
  BoardTaskStatus.shipped => cs.success,
  BoardPostStatus.declined || BoardTaskStatus.cancelled => cs.destructive,
  _ => cs.mutedForeground,
};
