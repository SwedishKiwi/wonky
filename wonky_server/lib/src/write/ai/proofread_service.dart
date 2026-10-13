import 'dart:async';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_write_core/wonky_write_core.dart';

import '../../platform/ai/ai_models.dart';
import '../../platform/ai/ai_usage_service.dart';
import '../../platform/ai/ai_keys.dart';
import '../../platform/ai/llm/ai_client.dart';
import '../../platform/ai/assistant_service.dart'
    show AssistantErrors, AssistantService;
import '../../platform/common/actor.dart';
import '../../platform/common/models.dart';
import '../mcp/headless_editor.dart';
import 'write_context_builder.dart';
import 'write_prompts.dart';

/// A section of the document sent in one proofreading request.
class ProofreadSection {
  const ProofreadSection(this.start, this.length, this.text);

  /// Delta range of the section.
  final int start;
  final int length;

  /// The section's plain text (as quotes match it).
  final String text;
}

/// Proofreading (Write 09 §5.5): the document is split into sections of at
/// most [maxWords] words at headings, up to [parallel] are processed at
/// once, and the model reports findings through the strict server-local
/// tool `report_issues`. Quotes are validated against the head; issues
/// whose quote is not found are dropped.
abstract final class ProofreadService {
  static const maxWords = 8000;
  static const parallel = 3;
  static const toolName = 'report_issues';
  static const categories = [
    'spelling',
    'grammar',
    'punctuation',
    'style',
    'clarity',
  ];

  /// The strict result tool.
  static const tool = AiToolSpec(
    name: toolName,
    description:
        'Reports every proofreading issue found in the section. Call it '
        'exactly once, with an empty list when there are no issues.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'issues': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'quote': {
                'type': 'string',
                'description': 'Exact text to replace, copied verbatim.',
              },
              'occurrence': {
                'type': 'integer',
                'description': '1-based occurrence of quote in the section.',
              },
              'replacement': {'type': 'string'},
              'category': {'type': 'string', 'enum': categories},
              'explanation': {'type': 'string'},
            },
            'required': [
              'quote',
              'occurrence',
              'replacement',
              'category',
              'explanation',
            ],
            'additionalProperties': false,
          },
        },
      },
      'required': ['issues'],
      'additionalProperties': false,
    },
  );

  static Future<Stream<ProofreadEvent>> run(
    Session session,
    Actor actor,
    UuidValue itemUuid, {
    int? start,
    int? length,
    Future<Session> Function()? runSession,
  }) async {
    await AiUsageService.requireAvailable(session, actor.userId);
    final target = await HeadlessDocumentEditor.resolve(
      session,
      actor,
      itemUuid,
    );
    final backend = await AiKeys.backendFor(session, actor.userId);
    if (backend == null) {
      throw WonkyException(
        code: WonkyErrorCode.unavailable,
        message: AiUsageService.notConfiguredMessage,
      );
    }
    final quality = await AiUsageService.quality(session, actor.userId);
    final ctx = await WriteContextBuilder.load(session, target);
    final release = AiUsageService.acquire(actor.userId);
    final sections = split(ctx, start: start, length: length);
    final cancel = AiCancelToken();
    final out = StreamController<ProofreadEvent>();
    out.onCancel = cancel.cancel;
    void emit(ProofreadEvent e) {
      if (!out.isClosed) out.add(e);
    }

    Future<void> body() async {
      final s = runSession == null
          ? await session.serverpod.createSession(enableLogging: false)
          : await runSession();
      var done = 0;
      var refused = false;
      String? error;
      String? errorCode;
      try {
        final queue = List.of(sections);
        var n = 0;
        Future<void> worker() async {
          while (queue.isNotEmpty && !cancel.isCancelled) {
            final section = queue.removeAt(0);
            final i = n++;
            try {
              final req = request(
                section,
                quality,
                model: backend.model,
                userId: actor.userId,
              );
              final msg = await backend.client.send(req, cancel: cancel);
              await AiUsageService.record(
                s,
                userId: actor.userId,
                model: msg.model ?? req.model,
                feature: 'proofread',
                usage: msg.usage,
              );
              if (msg.stopReason == AiStopReason.refusal) {
                refused = true;
              } else {
                final issues = validate(ctx, section, msg, prefix: 's$i');
                emit(
                  ProofreadEvent(
                    type: 'issues',
                    issues: issues,
                    sectionsDone: ++done,
                    sectionsTotal: sections.length,
                    revision: ctx.revision,
                  ),
                );
                continue;
              }
            } on AiCancelledException {
              return;
            } on AiApiException catch (e) {
              error ??= AssistantErrors.message(e);
              errorCode ??= AssistantErrors.code(e);
            }
            emit(
              ProofreadEvent(
                type: 'progress',
                sectionsDone: ++done,
                sectionsTotal: sections.length,
              ),
            );
          }
        }

        await Future.wait([
          for (var w = 0; w < parallel && w < sections.length; w++) worker(),
        ]);
        if (error != null) {
          emit(
            ProofreadEvent(type: 'error', error: error, errorCode: errorCode),
          );
        } else if (refused && done == 0) {
          emit(
            ProofreadEvent(
              type: 'refusal',
              error: AssistantService.refusalText,
            ),
          );
        }
        emit(
          ProofreadEvent(
            type: 'done',
            sectionsDone: done,
            sectionsTotal: sections.length,
            revision: ctx.revision,
          ),
        );
      } finally {
        if (runSession == null) await s.close();
      }
    }

    unawaited(
      body()
          .catchError((Object e) {
            emit(
              ProofreadEvent(
                type: 'error',
                error: 'Something went wrong. Please try again.',
                errorCode: 'internal',
              ),
            );
          })
          .whenComplete(() {
            release();
            if (!out.isClosed) unawaited(out.close());
          }),
    );
    return out.stream;
  }

  static int _words(String s) => RegExp(r'\S+').allMatches(s).length;

  /// Splits the document (or the range) into sections of at most
  /// [maxWords] words, at headings where possible, else at paragraphs.
  static List<ProofreadSection> split(
    WriteDocContext ctx, {
    int? start,
    int? length,
    int limit = maxWords,
  }) {
    final doc = ctx.doc;
    final from = (start ?? 0).clamp(0, doc.length);
    final to = length == null
        ? doc.length
        : (from + length).clamp(from, doc.length);
    final lines = [
      for (final l in doc.lines)
        if (l.end > from && l.start < to) l,
    ];
    final out = <ProofreadSection>[];
    var buf = <DocumentLine>[];
    var words = 0;
    void flush() {
      if (buf.isEmpty) return;
      final s = buf.first.start;
      final e = buf.last.end;
      final text = buf
          .map((l) => l.isEmbedLine ? '' : l.text)
          .join('\n')
          .replaceAll('￼', '');
      if (text.trim().isNotEmpty) out.add(ProofreadSection(s, e - s, text));
      buf = [];
      words = 0;
    }

    for (final l in lines) {
      final w = l.isEmbedLine ? 0 : _words(l.text);
      final heading = l.format.type == BlockType.heading;
      if (buf.isNotEmpty &&
          (words + w > limit || (heading && words > limit ~/ 2))) {
        flush();
      }
      buf.add(l);
      words += w;
    }
    flush();
    return out;
  }

  /// The model request of [section] ([model] maps a tier to the
  /// provider's model id).
  static AiRequest request(
    ProofreadSection section,
    AiQuality quality, {
    required String Function(AiTier tier) model,
    int? userId,
  }) {
    final tier = AiTier.document(quality);
    return AiRequest(
      model: model(tier),
      effort: tier.effort,
      maxTokens: 32000,
      system: WritePrompts.proofread,
      tools: const [tool],
      messages: [
        ChatMessage.user(
          '<section>\n${section.text}\n</section>\n'
          'Proofread the section and call report_issues once.',
        ),
      ],
      userId: userId == null ? null : 'u$userId',
      feature: 'proofread',
    );
  }

  /// The model's issues located in the head: occurrence within the section
  /// is converted to the document-wide occurrence (for quote addressing).
  static List<ProofreadIssue> validate(
    WriteDocContext ctx,
    ProofreadSection section,
    AiResponse msg, {
    String prefix = '',
  }) {
    final out = <ProofreadIssue>[];
    final resolver = AddressResolver.of(ctx.doc);
    var n = 0;
    for (final use in msg.toolCalls) {
      if (use.toolName != toolName) continue;
      final issues = use.arguments?['issues'];
      if (issues is! List) continue;
      for (final raw in issues) {
        if (raw is! Map) continue;
        final quote = raw['quote'];
        final replacement = raw['replacement'];
        if (quote is! String || quote.isEmpty || replacement is! String) {
          continue;
        }
        if (quote == replacement) continue;
        final category = categories.contains(raw['category'])
            ? raw['category'] as String
            : 'style';
        final occ = (raw['occurrence'] as num?)?.toInt() ?? 1;
        final all = resolver.findQuote(quote);
        final inSection = [
          for (var i = 0; i < all.length; i++)
            if (all[i].start >= section.start &&
                all[i].start + quote.length <= section.start + section.length)
              i,
        ];
        if (inSection.isEmpty) continue;
        final pick = inSection[(occ - 1).clamp(0, inSection.length - 1)];
        final m = all[pick];
        out.add(
          ProofreadIssue(
            id: '$prefix-${n++}',
            quote: quote,
            occurrence: pick + 1,
            replacement: replacement,
            category: category,
            explanation: '${raw['explanation'] ?? ''}',
            start: m.start,
            length: quote.length,
          ),
        );
      }
    }
    return out;
  }
}
