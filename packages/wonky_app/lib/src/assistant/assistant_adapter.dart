import 'package:flutter/widgets.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' show Role;

import 'assistant_models.dart';

/// What an app contributes to the shared assistant panel for its open file
/// (suite 10 §3 "specialized per app"): context hints and chips, Show and
/// Undo of tool changes, quick prompts and inserting results.
abstract class AssistantDocumentAdapter implements Listenable {
  /// The open drive item.
  UuidValue get itemUuid;

  /// The user's role on it (Commenters always get Suggest).
  Role get role;

  /// Volatile context for a chat message. [chips] are the chips the user
  /// kept (removed chips are not sent).
  AssistantContextHints hints({
    required AiApplyMode applyMode,
    required Set<String> chips,
    bool includeComments = false,
  });

  /// The context chips right now (selection, …). Notifies listeners when
  /// they change.
  List<AssistantContextChip> get chips;

  /// Quick prompts of the app.
  List<AssistantQuickPrompt> get quickPrompts;

  /// Reveals and flashes the range of a tool change.
  void show(AssistantActivity activity);

  /// Undoes the run's undo step when it is still the latest change of that
  /// run on the user's stack; false when it can't (the panel then reverts
  /// each change on the server).
  Future<bool> undoRun(String runId);

  /// A run finished: relabel its undo step (`AI: <summary>`).
  void runFinished(String runId, String summary);

  /// Inserts Markdown at the cursor ([atTop]: at the document start) as one
  /// undoable step.
  Future<bool> insertMarkdown(String markdown, {bool atTop = false});
}

/// Optional hooks of an [AssistantDocumentAdapter] whose AI changes are
/// server-side change records (Wonky Sheets 12 §6.2–6.3): an adapter that
/// also implements this interface is told about the run's composite
/// server change (one undo step), Suggest-mode previews and finished tool
/// calls, and can add widgets under a reply ("Review changes").
abstract interface class AssistantRunHooks {
  /// A tool call finished ([activity] carries `range` / `objectId`).
  void toolFinished(AssistantActivity activity);

  /// An Edit-mode run committed its changes as one server change
  /// (`done.changeId`); [summary] is the short label of the run.
  void runCommitted(AssistantReplyEntry reply, String changeId, String summary);

  /// A Suggest-mode run recorded an AI changes preview (`previewReady`).
  void previewReady(AssistantReplyEntry reply, String previewId);

  /// Extra widgets under [reply] (null = none).
  Widget? replyFooter(BuildContext context, AssistantReplyEntry reply);
}
