import 'dart:async';

import 'package:shad/shad.dart' show LucideIcons;
import 'package:wonky_app/wonky_app.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_core/wonky_core.dart' hide ActorKind;

import '../../commands/write_command.dart';
import '../editor/applier/delta_applier.dart' show DeltaSelection;
import 'proofread_results.dart';
import 'write_ai_controller.dart';

const _category = 'AI';

const _rewriteModes = [
  'improve',
  'fixGrammar',
  'shorter',
  'longer',
  'tone',
  'translate',
  'custom',
  'explain',
  'summarize',
];

/// The Write AI commands (Write 09 §6). Previews are not undoable; applying
/// a result is one undo step labelled "AI: …".
List<Command<CommandArgs>> writeAiCommands(ShellServices services) {
  WriteAiController? ai(CommandContext ctx) => WriteAiController.of(ctx);
  bool on(CommandContext ctx) {
    final a = ai(ctx);
    return a != null && a.shown;
  }

  WriteCommand cmd(
    String id, {
    required String label,
    required FutureOr<CommandResult> Function(
      CommandContext ctx,
      WriteAiController ai,
      JsonArgs args,
    )
    run,
    bool Function(WriteAiController ai, JsonArgs args)? enabled,
    Role role = Role.viewer,
    JsonSchema args = JsonSchema.empty,
    List<KeyBinding> bindings = const [],
    KeyScope scope = KeyScope.global,
    bool palette = true,
    String? description,
    bool needsEditable = false,
  }) => WriteCommand(
    id,
    label: label,
    icon: LucideIcons.sparkles,
    categoryName: _category,
    descriptionText: description,
    requiredRole: role,
    argsSchema: args,
    defaultBindings: bindings,
    keyScope: scope,
    showInPalette: palette,
    needsEditable: needsEditable,
    enabled: (doc, a) {
      final c = WriteAiController.forItem(doc.itemUuid);
      if (c == null || !c.shown) return false;
      return enabled?.call(c, a) ?? c.available;
    },
    reason: (doc, a) {
      final c = WriteAiController.forItem(doc.itemUuid);
      if (c == null) return null;
      final s = c.assistant?.status.value;
      if (s != null && !s.available) return s.message;
      return null;
    },
    run: (ctx, doc, a) async {
      final c = ai(ctx);
      if (c == null || !on(ctx)) {
        return const CommandResult.failed('AI is not available');
      }
      return run(ctx, c, a);
    },
  );

  CommandResult ok([Object? data]) =>
      data == null ? const CommandResult.ok() : CommandResult.ok(data);

  return [
    cmd(
      'write.ai.rewriteSelection',
      label: 'Rewrite with AI',
      description:
          'Rewrites the selection (improve, fixGrammar, shorter, longer, tone, '
          'translate, custom) into a preview; explain/summarize answer in the '
          'panel. Pass range {start, length} to target Delta offsets.',
      role: Role.commenter,
      args: const JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(enumValues: _rewriteModes),
          'tone': JsonSchema.string(),
          'language': JsonSchema.string(),
          'instruction': JsonSchema.string(),
          'range': JsonSchema.object(
            properties: {
              'start': JsonSchema.integer(minimum: 0),
              'length': JsonSchema.integer(minimum: 1),
            },
            required: ['start', 'length'],
          ),
        },
        required: ['mode'],
      ),
      enabled: (c, a) =>
          c.available && (c.hasSelection || a.values['range'] != null),
      run: (ctx, c, a) async {
        final mode = a.string('mode') ?? 'improve';
        final range = a.values['range'];
        DeltaSelection? sel;
        if (range is Map) {
          final s = (range['start'] as num).toInt();
          final l = (range['length'] as num).toInt();
          sel = DeltaSelection(s, s + l);
          c.doc.editor.select(sel);
        }
        if (mode == 'explain' || mode == 'summarize') {
          unawaited(c.explainSelection(summarize: mode == 'summarize'));
          return ok();
        }
        if (!c.canWrite) return const CommandResult.failed('Read-only');
        unawaited(
          c.rewriteSelection(
            mode,
            tone: a.string('tone'),
            language: a.string('language'),
            instruction: a.string('instruction'),
            range: sel,
          ),
        );
        return ok();
      },
    ),
    cmd(
      'write.ai.inline',
      label: 'Ask AI…',
      description:
          'Opens the inline AI prompt at the caret (empty paragraph) or for '
          'the selection.',
      role: Role.commenter,
      bindings: const [KeyBinding('J', mod: true)],
      scope: KeyScope.editor,
      args: const JsonSchema.object(
        properties: {'prompt': JsonSchema.string()},
      ),
      enabled: (c, a) =>
          c.available &&
          c.canWrite &&
          (c.caretInEmptyParagraph ||
              c.hasSelection ||
              a.string('prompt') != null),
      run: (ctx, c, a) async {
        c.openPrompt();
        final prompt = a.string('prompt');
        if (prompt != null) unawaited(c.submitPrompt(prompt));
        return ok();
      },
    ),
    cmd(
      'write.ai.continue',
      label: 'Continue writing',
      description: 'Continues the text at the caret (ghost text; Tab accepts).',
      role: Role.commenter,
      args: const JsonSchema.object(
        properties: {'maxWords': JsonSchema.integer(minimum: 10, maximum: 300)},
      ),
      enabled: (c, a) => c.available && c.canWrite,
      run: (ctx, c, a) async {
        unawaited(c.continueWriting(maxWords: a.integer('maxWords')));
        return ok();
      },
    ),
    cmd(
      'write.ai.summarizeDocument',
      label: 'Summarize document',
      args: const JsonSchema.object(
        properties: {
          'length': JsonSchema.string(
            enumValues: ['short', 'medium', 'detailed'],
          ),
        },
      ),
      run: (ctx, c, a) async {
        unawaited(c.summarizeDocument(length: a.string('length') ?? 'medium'));
        return ok();
      },
    ),
    cmd(
      'write.ai.generateOutline',
      label: 'Generate outline',
      args: const JsonSchema.object(
        properties: {'prompt': JsonSchema.string()},
      ),
      run: (ctx, c, a) async {
        unawaited(c.generateOutline(prompt: a.string('prompt')));
        return ok();
      },
    ),
    cmd(
      'write.ai.proofreadDocument',
      label: 'Proofread document',
      run: (ctx, c, a) async {
        unawaited(c.proofread());
        return ok();
      },
    ),
    cmd(
      'write.ai.previewReplace',
      label: 'Replace with AI result',
      palette: false,
      role: Role.commenter,
      enabled: (c, a) => c.preview?.canApply ?? false,
      run: (ctx, c, a) =>
          c.replace() ? ok() : const CommandResult.failed('Nothing to replace'),
    ),
    cmd(
      'write.ai.previewInsertBelow',
      label: 'Insert AI result below',
      palette: false,
      role: Role.commenter,
      enabled: (c, a) => c.preview?.canApply ?? false,
      run: (ctx, c, a) => c.insert(below: true)
          ? ok()
          : const CommandResult.failed('Nothing to insert'),
    ),
    cmd(
      'write.ai.previewRetry',
      label: 'Try again',
      palette: false,
      enabled: (c, a) => c.preview != null,
      run: (ctx, c, a) async {
        unawaited(c.retry());
        return ok();
      },
    ),
    cmd(
      'write.ai.previewRefine',
      label: 'Refine AI result',
      palette: false,
      args: const JsonSchema.object(
        properties: {'instruction': JsonSchema.string(minLength: 1)},
        required: ['instruction'],
      ),
      enabled: (c, a) => c.preview?.canApply ?? false,
      run: (ctx, c, a) async {
        unawaited(c.refine(a.requireString('instruction')));
        return ok();
      },
    ),
    cmd(
      'write.ai.previewDiscard',
      label: 'Discard AI result',
      palette: false,
      enabled: (c, a) => c.preview != null,
      run: (ctx, c, a) {
        c.discard();
        return ok();
      },
    ),
    cmd(
      'write.ai.setApplyMode',
      label: 'AI apply mode',
      palette: false,
      args: const JsonSchema.object(
        properties: {
          'mode': JsonSchema.string(enumValues: ['edit', 'suggest']),
        },
        required: ['mode'],
      ),
      enabled: (c, a) => c.chat != null,
      run: (ctx, c, a) {
        c.chat?.setApplyMode(
          a.string('mode') == 'suggest'
              ? AiApplyMode.suggest
              : AiApplyMode.edit,
        );
        return ok({'mode': c.chat?.applyMode.name});
      },
    ),
    cmd(
      'write.ai.acceptIssue',
      label: 'Accept proofreading issue',
      palette: false,
      role: Role.commenter,
      args: const JsonSchema.object(
        properties: {'issueId': JsonSchema.string()},
        required: ['issueId'],
      ),
      enabled: (c, a) => c.proofreadResults != null && c.canWrite,
      run: (ctx, c, a) {
        final r = c.proofreadResults!;
        final id = a.requireString('issueId');
        final s = r.issues.where((i) => i.issue.id == id).toList();
        return r.accept(s) ? ok() : const CommandResult.failed('Text changed');
      },
    ),
    cmd(
      'write.ai.dismissIssue',
      label: 'Dismiss proofreading issue',
      palette: false,
      args: const JsonSchema.object(
        properties: {'issueId': JsonSchema.string()},
        required: ['issueId'],
      ),
      enabled: (c, a) => c.proofreadResults != null,
      run: (ctx, c, a) {
        final r = c.proofreadResults!;
        final id = a.requireString('issueId');
        for (final s in r.issues.where((i) => i.issue.id == id)) {
          r.dismiss(s);
        }
        return ok();
      },
    ),
    cmd(
      'write.ai.acceptAllIssues',
      label: 'Accept all proofreading issues',
      palette: false,
      role: Role.commenter,
      args: const JsonSchema.object(
        properties: {
          'category': JsonSchema.string(
            enumValues: ProofreadResults.categories,
          ),
        },
      ),
      enabled: (c, a) => c.proofreadResults != null && c.canWrite,
      run: (ctx, c, a) {
        final r = c.proofreadResults!;
        final cat = a.string('category');
        final list = cat == null
            ? r.open
            : [
                for (final s in r.inCategory(cat))
                  if (s.status == ProofreadIssueStatus.open) s,
              ];
        return r.accept(list)
            ? ok()
            : const CommandResult.failed('Nothing to accept');
      },
    ),
  ];
}
