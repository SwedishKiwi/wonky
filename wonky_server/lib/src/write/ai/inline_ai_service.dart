import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/ai/ai_config.dart';
import '../../platform/ai/ai_models.dart';
import '../../platform/ai/ai_usage_service.dart';
import '../../platform/ai/anthropic/anthropic_client.dart';
import '../../platform/ai/assistant_service.dart'
    show AssistantErrors, AssistantService;
import '../../platform/common/actor.dart';
import '../../platform/common/errors.dart';
import '../../platform/common/models.dart';
import '../mcp/headless_editor.dart';
import 'write_context_builder.dart';
import 'write_prompts.dart';

/// Inline AI without tools (Write 09 §5.3–5.5): selection rewrites with a
/// preview, continue writing, and summaries / outlines / explanations for
/// the panel. Streams [InlineAiEvent]s.
abstract final class InlineAiService {
  static const rewriteActions = {
    'improve',
    'fixGrammar',
    'shorter',
    'longer',
    'tone',
    'translate',
    'custom',
  };
  static const panelActions = {
    'explain',
    'summarize',
    'summarizeDocument',
    'generateOutline',
  };
  static const continueAction = 'continueWriting';

  /// Words of context before the caret for continue writing.
  static const continueContextWords = 3000;

  static Future<Stream<InlineAiEvent>> run(
    Session session,
    Actor actor,
    InlineAiRequest req, {
    Future<Session> Function()? runSession,
  }) async {
    final action = req.action;
    final isRewrite = rewriteActions.contains(action);
    final isContinue = action == continueAction;
    if (!isRewrite && !isContinue && !panelActions.contains(action)) {
      throw Errors.invalid('Unknown AI action "$action".');
    }
    await AiUsageService.requireAvailable(session, actor.userId);
    final target = await HeadlessDocumentEditor.resolve(
      session,
      actor,
      req.itemUuid,
      min: isRewrite || isContinue ? Role.commenter : Role.viewer,
    );
    final client = AiConfig.client;
    if (client == null) {
      throw WonkyException(
        code: WonkyErrorCode.unavailable,
        message: AiUsageService.notConfiguredMessage,
      );
    }
    final quality = await AiUsageService.quality(session, actor.userId);
    final ctx = await WriteContextBuilder.load(session, target);
    final release = AiUsageService.acquire(actor.userId);
    final request = build(req, ctx, quality, userId: actor.userId);
    final cancel = AiCancelToken();
    final out = StreamController<InlineAiEvent>();
    out.onCancel = cancel.cancel;
    Future<void> body() async {
      final s = runSession == null
          ? await session.serverpod.createSession(enableLogging: false)
          : await runSession();
      try {
        final msg = await client.send(
          request,
          cancel: cancel,
          onText: (t) {
            if (!out.isClosed) {
              out.add(
                InlineAiEvent(type: InlineAiEventType.textDelta, text: t),
              );
            }
          },
        );
        await AiUsageService.record(
          s,
          userId: actor.userId,
          model: msg.model ?? request.model,
          feature: request.feature,
          usage: msg.usage,
        );
        if (out.isClosed) return;
        if (msg.stopReason == 'refusal') {
          out.add(
            InlineAiEvent(
              type: InlineAiEventType.refusal,
              error: AssistantService.refusalText,
            ),
          );
          return;
        }
        out.add(
          InlineAiEvent(
            type: InlineAiEventType.done,
            markdown: clean(msg.text, keepLeadingSpace: isContinue),
            errorCode: msg.stopReason == 'max_tokens' ? 'max_tokens' : null,
          ),
        );
      } on AiCancelledException {
        // Discarded by the user.
      } on AnthropicApiException catch (e) {
        if (!out.isClosed) {
          out.add(
            InlineAiEvent(
              type: InlineAiEventType.error,
              error: AssistantErrors.message(e),
              errorCode: AssistantErrors.code(e),
            ),
          );
        }
      } finally {
        if (runSession == null) await s.close();
      }
    }

    unawaited(
      body()
          .catchError((Object e) {
            if (!out.isClosed) {
              out.add(
                InlineAiEvent(
                  type: InlineAiEventType.error,
                  error: 'Something went wrong. Please try again.',
                  errorCode: 'internal',
                ),
              );
            }
          })
          .whenComplete(() {
            release();
            if (!out.isClosed) unawaited(out.close());
          }),
    );
    return out.stream;
  }

  /// The model request of [req] (pure; tests check prompts and tiers).
  static AnthropicRequest build(
    InlineAiRequest req,
    WriteDocContext ctx,
    AiQuality quality, {
    int? userId,
  }) {
    final action = req.action;
    final outline = WriteContextBuilder.outlineJson(ctx);
    List<Map<String, Object?>> user(String text) => [
      {'type': 'text', 'text': text},
    ];
    if (rewriteActions.contains(action)) {
      final tier = AiTier.rewrite(quality);
      final instruction = WritePrompts.rewriteInstruction(
        action,
        tone: req.tone,
        language: req.targetLanguage,
        instruction: req.instruction,
      );
      final first =
          '<document_title>${ctx.title}</document_title>\n'
          '<document_outline>$outline</document_outline>\n'
          '<context_before>${req.contextBefore ?? ''}</context_before>\n'
          '<selection>${req.selectedMarkdown ?? ''}</selection>\n'
          '<context_after>${req.contextAfter ?? ''}</context_after>\n'
          '<action>$instruction</action>\n'
          'Reply with only the replacement Markdown for <selection>.';
      final prev = req.previousOutput;
      final messages = [
        {'role': 'user', 'content': user(first)},
        if (prev != null) ...[
          {
            'role': 'assistant',
            'content': user(prev.isEmpty ? '(empty)' : prev),
          },
          {
            'role': 'user',
            'content': user(
              'Revise your replacement: '
              '${(req.instruction ?? '').trim().isEmpty ? 'try a different version' : req.instruction!.trim()}. '
              'Reply with only the revised replacement Markdown.',
            ),
          },
        ],
      ];
      return AnthropicRequest(
        model: tier.model,
        effort: tier.effort,
        maxTokens: 32000,
        system: [
          {
            'type': 'text',
            'text': WritePrompts.rewrite,
            'cache_control': {'type': 'ephemeral'},
          },
        ],
        messages: messages,
        cacheConversation: false,
        userId: userId == null ? null : 'u$userId',
        feature: 'rewrite',
      );
    }
    if (action == continueAction) {
      final tier = AiTier.continueWriting(quality);
      final caret = (req.start ?? ctx.doc.length - 1).clamp(
        0,
        ctx.doc.length - 1,
      );
      final before = _lastWords(
        DocumentReader.renderMarkdown(
          ctx.content.slice(0, caret),
          SuggestionViewMode.accepted,
        ),
        continueContextWords,
      );
      final line = ctx.doc.lineAt(caret);
      final emptyLine = line.contentLength == 0;
      final maxWords = (req.maxWords ?? 300).clamp(10, 300);
      return AnthropicRequest(
        model: tier.model,
        effort: tier.effort,
        maxTokens: 8000,
        system: [
          {
            'type': 'text',
            'text': WritePrompts.continueWriting,
            'cache_control': {'type': 'ephemeral'},
          },
        ],
        messages: [
          {
            'role': 'user',
            'content': user(
              '<document_title>${ctx.title}</document_title>\n'
              '<document_outline>$outline</document_outline>\n'
              '<text_before_caret>$before</text_before_caret>\n'
              '<caret>${emptyLine ? 'at the start of an empty paragraph' : 'at the end of the text above, inside its last paragraph'}</caret>\n'
              'Continue writing from the caret. At most $maxWords words.'
              '${(req.instruction ?? '').trim().isEmpty ? '' : ' Guidance from the user: ${req.instruction!.trim()}'}',
            ),
          },
        ],
        cacheConversation: false,
        userId: userId == null ? null : 'u$userId',
        feature: 'continue',
      );
    }
    final tier = AiTier.document(quality);
    String task;
    String body;
    switch (action) {
      case 'explain':
        task =
            'Explain the selected passage in plain words: what it says and '
            'what it means in the context of the document. Be brief.';
        body =
            '<document_outline>$outline</document_outline>\n'
            '<context_before>${req.contextBefore ?? ''}</context_before>\n'
            '<selection>${req.selectedMarkdown ?? ''}</selection>\n'
            '<context_after>${req.contextAfter ?? ''}</context_after>';
      case 'summarize':
        task = 'Summarize the selected passage in a few sentences.';
        body = '<selection>${req.selectedMarkdown ?? ''}</selection>';
      case 'generateOutline':
        final prompt = (req.instruction ?? '').trim();
        final empty = ctx.markdown.trim().isEmpty;
        task = empty || prompt.isNotEmpty
            ? 'Create a document outline as a Markdown list of headings '
                  '(use "#", "##" and "###" headings, one per line, no body '
                  'text)${prompt.isEmpty ? '' : ' for: $prompt'}.'
            : 'Create an outline of this document as Markdown headings '
                  '("#", "##", "###"), one per line, no body text, following '
                  'its actual structure and content.';
        body = empty ? '' : _documentBody(ctx);
      default: // summarizeDocument
        final length = switch (req.summaryLength) {
          'short' => 'in two or three sentences',
          'detailed' =>
            'in detail: a short overview paragraph followed by the key '
                'points of each section as a bullet list',
          _ =>
            'in one paragraph followed by up to five key points as a '
                'bullet list',
        };
        task = 'Summarize the document $length.';
        body = _documentBody(ctx);
    }
    return AnthropicRequest(
      model: tier.model,
      effort: tier.effort,
      maxTokens: 32000,
      system: [
        {
          'type': 'text',
          'text': WritePrompts.documentActions,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
      messages: [
        {
          'role': 'user',
          'content': user(
            '${body.isEmpty ? '' : '$body\n'}<task>$task</task>',
          ),
        },
      ],
      cacheConversation: false,
      userId: userId == null ? null : 'u$userId',
      feature: action == 'generateOutline'
          ? 'outline'
          : action == 'explain'
          ? 'explain'
          : 'summarize',
    );
  }

  static String _documentBody(WriteDocContext ctx) {
    var md = ctx.markdown;
    const limit = WriteContextBuilder.largeTokenLimit * 4;
    var note = '';
    if (md.length > limit) {
      md = md.substring(0, limit);
      note =
          '\n<note>The document was cut off here because it is very long.</note>';
    }
    return '<document title="${ctx.title}">\n$md\n</document>$note';
  }

  static String _lastWords(String text, int words) {
    final parts = text.split(RegExp(r'(?<=\s)'));
    if (parts.length <= words) return text;
    return '…${parts.sublist(parts.length - words).join()}';
  }

  /// Strips an accidental surrounding code fence and trailing whitespace.
  static String clean(String text, {bool keepLeadingSpace = false}) {
    var t = text.trimRight();
    final fence = RegExp(r'^\s*```[a-zA-Z]*\n([\s\S]*?)\n```\s*$');
    final m = fence.firstMatch(t);
    if (m != null) t = m.group(1)!;
    return keepLeadingSpace ? t : t.trimLeft();
  }
}
