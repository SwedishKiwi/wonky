import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_core/wonky_core.dart';

import '../editor/controller/editor_types.dart';
import '../suggestions/suggestions_panel.dart';
import 'write_document_api.dart';
import 'write_document_session.dart';

const _ok = CommandResult.ok();
const _nothing = CommandResult.failed('Nothing to do');

/// Write's collaboration commands (Write 08 §7): comments, suggestions,
/// presence and history. Shared comment/version actions stay the suite's
/// `shell.comments.*` / `shell.versions.*`; these add the Write-specific
/// ones. Register them from `WriteAppConfig.commands`.
List<Command<CommandArgs>> writeCollabCommands(ShellServices services) {
  WriteDocumentSession? session(CommandContext ctx) =>
      WriteDocumentSession.of(ctx);
  bool loaded(CommandContext ctx) => session(ctx)?.isLoaded ?? false;

  const threadArgs = JsonSchema.object(
    properties: {'threadUuid': JsonSchema.string(format: 'uuid')},
    required: ['threadUuid'],
  );
  const idsArgs = JsonSchema.object(
    properties: {
      'suggestionIds': JsonSchema.array(
        JsonSchema.string(),
        description:
            'Suggestion ids; default: the active suggestion or the one at '
            'the caret.',
      ),
    },
  );
  const authorArgs = JsonSchema.object(
    properties: {
      'authorUuid': JsonSchema.string(
        format: 'uuid',
        description: 'Only suggestions by this user.',
      ),
    },
  );
  const sessionArgs = JsonSchema.object(
    properties: {'sessionId': JsonSchema.string(minLength: 1)},
    required: ['sessionId'],
  );

  Set<String> ids(WriteDocumentSession s, JsonArgs a) {
    final raw = a.values['suggestionIds'];
    if (raw is List && raw.isNotEmpty) {
      return {for (final v in raw) '$v'};
    }
    final active = s.suggestions.activeId;
    if (active != null) return {active};
    final caret = s.editor.selection?.base;
    final at = caret == null ? null : s.suggestions.idAt(caret);
    return {?at};
  }

  return [
    // ---- Comments ----
    CallbackCommand(
      id: 'write.comments.addDocumentComment',
      title: (_) => 'Comment on the whole document',
      icon: LucideIcons.messageSquareText,
      requiredRole: Role.commenter,
      category: (_) => 'Comments',
      enabled: (ctx, _) => loaded(ctx) && services.comments.value != null,
      run: (ctx, _) async {
        session(ctx)!.comments.startDocumentComment();
        return _ok;
      },
    ),
    CallbackCommand(
      id: 'write.comments.activate',
      title: (_) => 'Open comment',
      argsSchema: threadArgs,
      showInPalette: false,
      category: (_) => 'Comments',
      enabled: (ctx, _) => loaded(ctx),
      run: (ctx, a) async {
        session(ctx)!.comments.activate(a.requireString('threadUuid'));
        return _ok;
      },
    ),
    for (final previous in [false, true])
      CallbackCommand(
        id: previous ? 'write.comments.previous' : 'write.comments.next',
        title: (_) => previous ? 'Previous comment' : 'Next comment',
        icon: previous ? LucideIcons.chevronUp : LucideIcons.chevronDown,
        defaultBindings: [
          KeyBinding(previous ? 'P' : 'N', mod: true, alt: true),
        ],
        keyScope: KeyScope.editor,
        category: (_) => 'Comments',
        enabled: (ctx, _) =>
            loaded(ctx) &&
            session(ctx)!.comments.anchoredOpenThreads.isNotEmpty,
        run: (ctx, _) async =>
            session(ctx)!.comments.next(previous: previous) ? _ok : _nothing,
      ),
    CallbackCommand(
      id: 'write.comments.reattach',
      title: (_) => 'Re-attach comment to selection',
      argsSchema: threadArgs,
      requiredRole: Role.editor,
      isUndoable: true,
      showInPalette: false,
      category: (_) => 'Comments',
      enabled: (ctx, _) =>
          loaded(ctx) && session(ctx)!.comments.selectionRange() != null,
      run: (ctx, a) async =>
          session(ctx)!.comments.reattach(a.requireString('threadUuid'))
          ? _ok
          : _nothing,
    ),
    CallbackCommand(
      id: 'write.comments.deleteThread',
      title: (_) => 'Delete comment thread',
      argsSchema: threadArgs,
      requiredRole: Role.commenter,
      showInPalette: false,
      category: (_) => 'Comments',
      enabled: (ctx, _) => loaded(ctx) && services.comments.value != null,
      run: (ctx, a) => services.dispatcher.invoke(
        'shell.comments.delete',
        args: {'threadUuid': a.requireString('threadUuid')},
        source: ctx.source,
        context: ctx.buildContext,
      ),
    ),

    // ---- Suggestions ----
    CallbackCommand(
      id: 'write.suggestions.accept',
      title: (_) => 'Accept suggestion',
      icon: LucideIcons.check,
      argsSchema: idsArgs,
      requiredRole: Role.editor,
      isUndoable: true,
      category: (_) => 'Suggestions',
      enabled: (ctx, a) => loaded(ctx) && ids(session(ctx)!, a).isNotEmpty,
      run: (ctx, a) async {
        final s = session(ctx)!;
        return s.suggestions.accept(ids(s, a)) ? _ok : _nothing;
      },
    ),
    CallbackCommand(
      id: 'write.suggestions.reject',
      title: (_) => 'Reject suggestion',
      icon: LucideIcons.x,
      argsSchema: idsArgs,
      requiredRole: Role.commenter,
      isUndoable: true,
      category: (_) => 'Suggestions',
      enabled: (ctx, a) {
        final s = session(ctx);
        if (s == null || !s.isLoaded) return false;
        final selected = ids(s, a);
        return selected.isNotEmpty &&
            selected.every((id) {
              final info = s.suggestions.byId(id);
              return info != null && s.suggestions.canReject(info);
            });
      },
      run: (ctx, a) async {
        final s = session(ctx)!;
        return s.suggestions.reject(ids(s, a)) ? _ok : _nothing;
      },
    ),
    for (final accept in [true, false])
      CallbackCommand(
        id: accept
            ? 'write.suggestions.acceptAll'
            : 'write.suggestions.rejectAll',
        title: (_) =>
            accept ? 'Accept all suggestions' : 'Reject all suggestions',
        icon: accept ? LucideIcons.checkCheck : LucideIcons.listX,
        argsSchema: authorArgs,
        requiredRole: Role.editor,
        isUndoable: true,
        category: (_) => 'Suggestions',
        enabled: (ctx, a) =>
            loaded(ctx) &&
            session(
                  ctx,
                )!.suggestions.count(authorUuid: a.string('authorUuid')) >
                0,
        run: (ctx, a) async {
          final c = session(ctx)!.suggestions;
          final author = a.string('authorUuid');
          final ok = accept
              ? c.acceptAll(authorUuid: author)
              : c.rejectAll(authorUuid: author);
          return ok ? _ok : _nothing;
        },
      ),
    for (final previous in [false, true])
      CallbackCommand(
        id: previous ? 'write.suggestions.previous' : 'write.suggestions.next',
        title: (_) => previous ? 'Previous suggestion' : 'Next suggestion',
        category: (_) => 'Suggestions',
        enabled: (ctx, _) =>
            loaded(ctx) && session(ctx)!.suggestions.pending.isNotEmpty,
        run: (ctx, _) async =>
            session(ctx)!.suggestions.next(previous: previous) ? _ok : _nothing,
      ),
    CallbackCommand(
      id: 'write.suggestions.togglePanel',
      title: (_) => 'Suggestions',
      icon: LucideIcons.fileDiff,
      category: (_) => 'Suggestions',
      enabled: (ctx, _) => loaded(ctx),
      checked: (_, _) => services.panels.isOpen(writeSuggestionsPanelId),
      run: (ctx, _) async {
        services.panels.toggle(writeSuggestionsPanelId);
        return _ok;
      },
    ),
    CallbackCommand(
      id: 'write.mode.suggest',
      title: (_) => 'Suggesting',
      icon: LucideIcons.pencilLine,
      requiredRole: Role.commenter,
      category: (_) => 'View',
      showInPalette: false,
      enabled: (ctx, _) => loaded(ctx),
      checked: (ctx, _) => session(ctx)?.editor.mode == EditorMode.suggesting,
      run: (ctx, _) async {
        final s = session(ctx)!;
        s.setMode(
          s.editor.mode == EditorMode.suggesting && s.currentRole.canEdit
              ? EditorMode.editing
              : EditorMode.suggesting,
        );
        return _ok;
      },
    ),

    // ---- Presence ----
    CallbackCommand(
      id: 'write.presence.jumpTo',
      title: (_) => 'Go to collaborator',
      argsSchema: sessionArgs,
      showInPalette: false,
      category: (_) => 'Collaboration',
      enabled: (ctx, _) => loaded(ctx),
      run: (ctx, a) async =>
          session(ctx)!.presence.reveal(a.requireString('sessionId'))
          ? _ok
          : const CommandResult.failed('No cursor for this collaborator'),
    ),
    CallbackCommand(
      id: 'write.presence.follow',
      title: (_) => 'Follow collaborator',
      argsSchema: sessionArgs,
      showInPalette: false,
      category: (_) => 'Collaboration',
      enabled: (ctx, _) => loaded(ctx),
      run: (ctx, a) async {
        session(ctx)!.presence.follow(a.requireString('sessionId'));
        return _ok;
      },
    ),
    CallbackCommand(
      id: 'write.presence.unfollow',
      title: (_) => 'Stop following',
      category: (_) => 'Collaboration',
      enabled: (ctx, _) => session(ctx)?.presence.following != null,
      run: (ctx, _) async {
        session(ctx)!.presence.unfollow();
        return _ok;
      },
    ),

    // ---- History ----
    CallbackCommand(
      id: 'write.history.open',
      title: (_) => 'See version history',
      icon: LucideIcons.history,
      requiredRole: Role.editor,
      category: (_) => 'Version history',
      argsSchema: const JsonSchema.object(
        properties: {'versionId': JsonSchema.integer()},
      ),
      enabled: (ctx, _) => loaded(ctx) && services.connectivity.online,
      run: (ctx, a) async {
        final s = session(ctx)!;
        final v = a.integer('versionId');
        services.router.go(
          '${services.config.itemPath(s.itemUuid.uuid)}/history'
          '${v == null ? '' : '?version=$v'}',
        );
        return _ok;
      },
    ),
    CallbackCommand(
      id: 'write.history.nameCurrentVersion',
      title: (_) => 'Name current version',
      requiredRole: Role.editor,
      category: (_) => 'Version history',
      argsSchema: const JsonSchema.object(
        properties: {'name': JsonSchema.string(minLength: 1, maxLength: 200)},
      ),
      run: (ctx, a) => services.dispatcher.invoke(
        'shell.versions.nameCurrent',
        args: {'name': ?a.string('name')},
        source: ctx.source,
        context: ctx.buildContext,
      ),
    ),
    CallbackCommand(
      id: 'write.history.restore',
      title: (_) => 'Restore this version',
      requiredRole: Role.editor,
      category: (_) => 'Version history',
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'versionId': JsonSchema.integer(),
          'confirmed': JsonSchema.boolean(),
        },
        required: ['versionId'],
      ),
      run: (ctx, a) => services.dispatcher.invoke(
        'shell.versions.restore',
        args: a.values,
        source: ctx.source,
        context: ctx.buildContext,
      ),
    ),
    CallbackCommand(
      id: 'write.history.copyVersion',
      title: (_) => 'Make a copy of this version',
      requiredRole: Role.editor,
      category: (_) => 'Version history',
      showInPalette: false,
      argsSchema: const JsonSchema.object(
        properties: {
          'versionId': JsonSchema.integer(),
          'name': JsonSchema.string(minLength: 1, maxLength: 255),
        },
        required: ['versionId', 'name'],
      ),
      run: (ctx, a) async {
        final item = services.currentItem.value;
        final doc = item?.contentRef;
        final client = services.client;
        if (doc == null || client == null) return _nothing;
        final copy = await ServerWriteDocumentApi(client).copyVersion(
          doc,
          a.integer('versionId')!,
          a.requireString('name'),
          parentUuid: item!.parentUuid,
        );
        return CommandResult.ok({'uuid': copy.uuid.uuid});
      },
    ),

    // ---- Sync ----
    CallbackCommand(
      id: 'write.sync.retry',
      title: (_) => 'Reconnect now',
      icon: LucideIcons.refreshCw,
      category: (_) => 'File',
      enabled: (ctx, _) => session(ctx)?.sync != null,
      run: (ctx, _) async {
        await session(ctx)!.retry();
        return _ok;
      },
    ),
  ];
}
