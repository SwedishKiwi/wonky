import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:wonky_core/wonky_core.dart' show McpScope, Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart'
    show ChartDescriber, ChartSourceSnapshot;
import 'package:wonky_slides_core/charts.dart';
import 'package:wonky_slides_core/code.dart' show CodeElementData;
import 'package:wonky_slides_core/markdown.dart' show DeckOutlineCodec;
import 'package:wonky_slides_core/model.dart';
import 'package:wonky_slides_core/motion.dart';
import 'package:wonky_slides_core/ops.dart';
import 'package:wonky_slides_core/schema.dart';
import 'package:wonky_slides_core/themes.dart' show SlidePlaceholderType;

import '../../platform/common/models.dart';
import '../../platform/mcp/tool_support.dart';
import '../../platform/sharing/access_service.dart';
import '../charts/slides_chart_service.dart';
import '../exports/slides_export_service.dart';
import 'slides_content.dart';
import 'slides_input.dart';
import 'slides_mcp_support.dart';
import 'slides_read_handlers.dart';
import 'slides_writes.dart';

/// Linked charts, code blocks, builds, transitions and export (Slides 11
/// §3.9–§3.12).
abstract final class SlidesMediaHandlers {
  static Future<SlidesTarget> _edit(ToolContext ctx, ToolArgs a) =>
      SlidesMcp.open(ctx, a, min: Role.editor);

  // ---------------------------------------------------------------- charts

  /// Linked-chart tools also need `sheets:read` (11 §2.4).
  static void _requireSheetsRead(ToolContext ctx) {
    if (!ctx.scopes.contains(McpScope.sheetsRead)) {
      throw McpToolException(
        McpErrorCode.forbidden,
        'Charts from Sheets also need the ${McpScope.sheetsRead} scope.',
        details: {
          'required_scopes': [McpScope.sheetsRead],
        },
      );
    }
  }

  /// Maps `SlidesChartService` errors (08 §4.3 reasons) to tool errors.
  static McpToolException _chartError(WonkyException e) {
    String? reason;
    try {
      final d = e.detailsJson == null ? null : jsonDecode(e.detailsJson!);
      if (d is Map) reason = d['reason'] as String?;
    } on FormatException {
      reason = null;
    }
    final code = switch (reason) {
      'no_access' || 'spreadsheet_trashed' => SlidesErrorCode.chartNoAccess,
      'export_disabled' => SlidesErrorCode.chartExportDisabled,
      'chart_not_found' => SlidesErrorCode.chartNotFound,
      'chart_too_large' => SlidesErrorCode.chartTooLarge,
      'unsupported_spec' => SlidesErrorCode.chartUnsupportedSpec,
      _ => null,
    };
    if (code == null) return McpToolException.fromWonky(e);
    return McpToolException(code, e.message, details: {'reason': reason});
  }

  static Future<ResolvedChartSnapshot> _resolve(
    ToolContext ctx,
    UuidValue spreadsheet,
    String chartId,
  ) async {
    try {
      final v = await SlidesChartService.resolveSnapshot(
        ctx.session,
        ctx.actor,
        spreadsheet,
        chartId,
      );
      return ResolvedChartSnapshot(
        spreadsheetUuid: v.spreadsheetUuid.uuid,
        chartObjectId: v.chartObjectId,
        sourceSpecJson: v.sourceSpecJson,
        dataSnapshotJson: v.dataSnapshotJson,
        sourceVersion: v.sourceVersion,
        sheetId: v.sheetId,
        warnings: v.warnings,
      );
    } on WonkyException catch (e) {
      throw _chartError(e);
    }
  }

  static Future<ToolResult> listSheetCharts(ToolContext ctx, ToolArgs a) async {
    _requireSheetsRead(ctx);
    final uuid = SlidesMcp.parseRef(
      a.requireString('spreadsheet'),
      what: 'spreadsheet',
    );
    try {
      final list = await SlidesChartService.listCharts(
        ctx.session,
        ctx.actor,
        uuid,
      );
      return ToolResult({
        'spreadsheet': uuid.uuid,
        'spreadsheet_title': list.spreadsheetTitle,
        'export_allowed': list.exportAllowed,
        'charts': [
          for (final c in list.charts)
            {
              'chart_id': c.chartObjectId,
              'title': c.title,
              'type': c.type,
              'is_3d': c.is3D,
              'sheet': c.sheetName,
              if (c.unsupported) 'unsupported': true,
            },
        ],
      }, text: '${list.charts.length} charts in "${list.spreadsheetTitle}"');
    } on WonkyException catch (e) {
      throw _chartError(e);
    }
  }

  /// Whether the deck reaches people the spreadsheet doesn't (08 §6,
  /// 11 §8.3): a deck link without a spreadsheet link, or a deck owner or
  /// member without access to the spreadsheet.
  static Future<bool> broaderAudience(
    Session session,
    DriveItem deck,
    UuidValue spreadsheetUuid,
  ) async {
    final sheet = await AccessService.findItem(session, spreadsheetUuid);
    if (sheet == null) return false;
    final deckLink = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(deck.id!),
    );
    final sheetLink = await ShareLink.db.findFirstRow(
      session,
      where: (t) => t.itemId.equals(sheet.id!),
    );
    if (deckLink?.role != null && sheetLink?.role == null) return true;
    final members = await DriveItemPermission.db.find(
      session,
      where: (t) => t.itemId.equals(deck.id!) & t.userId.notEquals(null),
      limit: 200,
    );
    final users = {deck.ownerId, for (final p in members) ?p.userId};
    for (final u in users) {
      if (await AccessService.effectiveRole(session, u, sheet) == null) {
        return true;
      }
    }
    return false;
  }

  static Future<ToolResult> insertLinkedChart(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    _requireSheetsRead(ctx);
    final t = await _edit(ctx, a);
    final spreadsheet = SlidesMcp.parseRef(
      a.requireString('spreadsheet'),
      what: 'spreadsheet',
    );
    final r = await _resolve(ctx, spreadsheet, a.requireString('chart_id'));
    final link = a.boolean('link') ?? true;
    final useDeckTheme = a.boolean('use_deck_theme') ?? true;
    final auto = a.boolean('auto_update') ?? false;
    final warnings = <SlidesWarning>[
      for (final w in r.warnings) SlidesWarning('chart_data', w),
    ];
    if (await broaderAudience(ctx.session, t.item, spreadsheet)) {
      warnings.add(
        const SlidesWarning(
          'broader_audience',
          'The presentation is shared more widely than the spreadsheet: '
              'people who can open the presentation will see this chart\'s data.',
        ),
      );
    }
    final snap = ChartSourceSnapshot.fromColumns(
      r.sourceSpecJson,
      r.dataSnapshotJson,
    );
    final title = snap.spec.title.hasText
        ? snap.spec.title.text
        : snap.dataSnapshot.source.chartTitle;
    final alt = ChartDescriber.describe(snap.spec, snap.data);
    String? elementId;
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.insert_linked_chart',
      warnings: warnings,
      build: (s) {
        final m = s.model;
        final slideId = SlidesMcp.slideId(m, a.values['slide']);
        final frameArg = a.object('frame');
        final placement = a.object('placement');
        // An empty chart placeholder takes the chart (08 §4.2).
        if (frameArg == null && placement == null) {
          for (final e in SlidesMcp.placeholders(
            m,
            slideId,
            SlidePlaceholderType.chart,
          )) {
            if (m.chartLinkOf(e.id) != null || e.dataJson != null) continue;
            elementId = e.id;
            s.run(ChartLinkOps.link(e.id, r, autoUpdate: auto));
            s.run(
              SetChartStyle(e.id, {
                'style': {'useDeckTheme': useDeckTheme},
              }),
            );
            if (!link) s.run(UnlinkChart(e.id));
            s.run(
              SetElementProps(
                [e.id],
                altText: Patch(alt),
                elementName: title.isEmpty ? null : Patch(title),
              ),
            );
            return;
          }
        }
        final (sw, sh) = SlidesInput.slideSize(m);
        final w = sw * 0.7, h = sh * 0.7;
        final f = SlidesInput.frame(
          m,
          frame: frameArg,
          placement: placement,
          fallback: SuRect((sw - w) / 2, (sh - h) / 2, w, h),
          pointer: '/frame',
        );
        final data = ChartElementData(
          source: link ? SlideChartSource.linked : SlideChartSource.static,
          style: SlideChartStyle(useDeckTheme: useDeckTheme),
          snapshot: link ? null : snap,
        );
        final plan = s.run(
          InsertElements(slideId, [
            ElementSpec(
              kind: ElementKind.chart,
              x: f.x,
              y: f.y,
              width: f.width,
              height: f.height,
              columns: {
                ElementCols.dataJson: data.encode(),
                if (title.isNotEmpty) SlidesCols.name: title,
                ElementCols.altText: alt,
              },
            ),
          ]),
        );
        elementId = (plan.result['elementIds']! as List).single as String;
        if (link) {
          s.run(ChartLinkOps.link(elementId!, r, autoUpdate: auto));
        }
      },
    );
    return SlidesWrites.result(o, 'Inserted the chart "$title"', {
      'element_id': elementId,
      'linked': link,
    });
  }

  static Future<ToolResult> refreshLinkedCharts(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    _requireSheetsRead(ctx);
    final t = await _edit(ctx, a);
    final (o, r) = await refreshCharts(ctx, t, refs: a.list('elements'));
    final total =
        r['updated']!.length + r['up_to_date']!.length + r['failed']!.length;
    return SlidesWrites.result(
      o,
      'Updated ${r['updated']!.length} of $total linked charts',
      r,
    );
  }

  /// Updates linked charts ([refs], default all) from their spreadsheets;
  /// returns the outcome and `{updated, up_to_date, failed}`.
  static Future<(SlidesWriteOutcome, Map<String, List<Object?>>)> refreshCharts(
    ToolContext ctx,
    SlidesTarget t, {
    List<Object?>? refs,
  }) async {
    final m = t.model;
    final ids = refs == null || refs.isEmpty
        ? [
            for (final p in ChartLinkOps.probesOf(m))
              if (p.elementId case final String id) id,
          ]
        : SlidesMcp.elementIds(m, refs);
    final updated = <String>[];
    final upToDate = <String>[];
    final failed = <Map<String, Object?>>[];
    final ops = <SlidesOperation>[];
    for (final id in ids) {
      final link = m.chartLinkOf(id);
      if (link == null) {
        failed.add({'element_id': id, 'code': 'not_linked'});
        continue;
      }
      try {
        final r = await _resolve(
          ctx,
          UuidValue.withValidation(link.spreadsheetItemUuid),
          link.chartObjectId,
        );
        if (r.sourceVersion == link.sourceVersion) {
          upToDate.add(id);
          continue;
        }
        ops.add(ChartLinkOps.update(id, r));
        updated.add(id);
      } on McpToolException catch (e) {
        failed.add({'element_id': id, 'code': e.code});
      }
    }
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.refresh_linked_charts',
      warnings: [
        for (final f in failed)
          SlidesWarning(
            'chart_stale',
            'The chart could not be updated (${f['code']}).',
            elementId: f['element_id'] as String?,
          ),
      ],
      build: (s) {
        for (final op in ops) {
          s.run(op);
        }
      },
    );
    return (
      o,
      <String, List<Object?>>{
        'updated': updated,
        'up_to_date': upToDate,
        'failed': failed,
      },
    );
  }

  static Future<ToolResult> updateChartStyle(
    ToolContext ctx,
    ToolArgs a,
  ) async {
    final t = await _edit(ctx, a);
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.update_chart_style',
      build: (s) {
        final m = s.model;
        final id = SlidesMcp.elementId(m, a.values['element']);
        SlidesMcp.elementOfKind(m, id, {ElementKind.chart}, 'a chart');
        final overrides = a.object('overrides');
        if (overrides != null) {
          final rejected = ChartOverrides.rejectedPaths(
            SlidesInput.camel(overrides),
          );
          if (rejected.isNotEmpty) {
            throw SlidesMcp.invalid(
              'These overrides are not allowed: ${rejected.join(', ')}.',
              pointer: '/overrides',
            );
          }
        }
        final camera = a.object('camera');
        final patch = <String, Object?>{
          if (a.boolean('use_deck_theme') case final bool v)
            'style': {'useDeckTheme': v},
          if (camera != null) 'camera': SlidesInput.camel(camera),
          if (overrides != null) 'overrides': SlidesInput.camel(overrides),
          if (a.present('background')) 'background': a.string('background'),
        };
        if (patch.isEmpty) return;
        s.run(SetChartStyle(id, patch));
      },
    );
    return SlidesWrites.result(o, 'Updated the chart style');
  }

  static Future<ToolResult> unlinkChart(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.unlink_chart',
      build: (s) {
        final id = SlidesMcp.elementId(s.model, a.values['element']);
        if (s.model.chartLinkOf(id) == null) {
          throw McpToolException(
            SlidesErrorCode.invalidTarget,
            'Element $id is not a linked chart.',
          );
        }
        s.run(UnlinkChart(id));
      },
    );
    return SlidesWrites.result(o, 'Unlinked the chart');
  }

  // ------------------------------------------------------------------ code

  /// `CodeState` columns of an MCP code state.
  static Map<String, Object?> _stateColumns(
    Map<String, Object?> st,
    String pointer,
  ) {
    final callouts = st['callouts'];
    final arrive = st['arrive'];
    return {
      CodeStateCols.code: '${st['code'] ?? ''}'.replaceAll('\r\n', '\n'),
      if (st['label'] is String) SlidesCols.label: st['label'],
      if (st['title'] is String) SlidesCols.title: st['title'],
      if (st['language'] is String)
        CodeStateCols.language: SlidesContent.normalizeLanguage(
          st['language']! as String,
        ),
      if (st['highlight'] is String) CodeStateCols.highlight: st['highlight'],
      if (callouts is Map && callouts.isNotEmpty)
        CodeStateCols.annotationsJson: jsonEncode({
          'v': 1,
          'steps': {
            for (final e in callouts.entries)
              '${e.key}': e.value is Map ? e.value : {'text': '${e.value}'},
          },
        }),
      if (arrive is Map)
        SlidesCols.transitionJson: jsonEncode({
          'v': 1,
          ...SlidesInput.camel(arrive),
        }),
    };
  }

  static Map<String, Object?> _codeOptions(Map<String, Object?>? o) => {
    if (o != null) ...SlidesInput.camel(o),
  };

  /// The *Build all steps* builds of code element [id] (06 §10, 07 §6;
  /// the app's `BuildRecipes.allSteps` for code): a `codeState` emphasis
  /// per further state and a `codeHighlight` per highlight step, each on
  /// click.
  static List<BuildSpec> codeSteps(DeckModel m, String id) {
    final specs = <BuildSpec>[];
    for (final (i, s) in m.codeStatesOf(id).indexed) {
      if (i > 0) {
        specs.add(
          BuildEdits.spec(
            elementId: id,
            kind: SlideBuildKind.emphasis,
            effect: 'codeState',
            params: {'state': i + 1},
          ),
        );
      }
      for (var k = 1; k <= MotionCodeState.stepsOf(s.highlight); k++) {
        specs.add(
          BuildEdits.spec(
            elementId: id,
            kind: SlideBuildKind.emphasis,
            effect: 'codeHighlight',
            params: {'step': k},
          ),
        );
      }
    }
    return specs;
  }

  static Future<ToolResult> addCodeBlock(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final states = [
      for (final (i, x) in a.list('states')!.indexed)
        _stateColumns((x! as Map).cast<String, Object?>(), '/states/$i'),
    ];
    final language = a.requireString('language');
    final options = _codeOptions(a.object('options'));
    String? elementId;
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.add_code_block',
      build: (s) {
        final m = s.model;
        final slideId = SlidesMcp.slideId(m, a.values['slide']);
        final frameArg = a.object('frame');
        final placement = a.object('placement');
        if (frameArg == null && placement == null) {
          // An empty code placeholder takes the code (07 §3.6).
          for (final e in SlidesMcp.placeholders(
            m,
            slideId,
            SlidePlaceholderType.code,
          )) {
            if (m.codeStatesOf(e.id).isNotEmpty) continue;
            elementId = e.id;
            s.run(
              SetElementData(
                e.id,
                jsonEncode(
                  CodeElementData.fromJson({
                    'v': 1,
                    ...options,
                    'language': SlidesContent.normalizeLanguage(language),
                  }).toJson(),
                ),
              ),
            );
            s.run(AddCodeStates(e.id, states));
            break;
          }
        }
        if (elementId == null) {
          final (sw, sh) = SlidesInput.slideSize(m);
          final w = (sw * 0.6).roundToDouble(), h = (sh * 0.5).roundToDouble();
          final f = SlidesInput.frame(
            m,
            frame: frameArg,
            placement: placement,
            fallback: SuRect(
              ((sw - w) / 2).roundToDouble(),
              ((sh - h) / 2).roundToDouble(),
              w,
              h,
            ),
            pointer: '/frame',
          );
          final plan = s.run(
            InsertElements(slideId, [
              SlidesContent.codeSpec(
                f,
                language: language,
                states: states,
                options: options,
              ),
            ]),
          );
          elementId = (plan.result['elementIds']! as List).single as String;
        }
        if (a.string('builds') == 'all_steps') {
          final specs = codeSteps(s.model, elementId!);
          if (specs.isNotEmpty) s.run(AddBuilds(slideId, specs));
        }
      },
    );
    return SlidesWrites.result(o, 'Added a ${language.trim()} code block', {
      'element_id': elementId,
    });
  }

  static Future<ToolResult> setCodeStates(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final states = [
      for (final (i, x) in a.list('states')!.indexed)
        _stateColumns((x! as Map).cast<String, Object?>(), '/states/$i'),
    ];
    final builds = a.string('builds') ?? 'keep';
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.set_code_states',
      force: a.boolean('force') ?? false,
      build: (s) {
        final m = s.model;
        final id = SlidesMcp.elementId(m, a.values['element']);
        final rec = SlidesMcp.elementOfKind(m, id, {
          ElementKind.code,
        }, 'a code block');
        final old = m.codeStatesOf(id);
        for (var i = 0; i < states.length && i < old.length; i++) {
          final cols = {...states[i]};
          for (final c in [
            SlidesCols.label,
            SlidesCols.title,
            CodeStateCols.language,
            CodeStateCols.highlight,
            CodeStateCols.annotationsJson,
            SlidesCols.transitionJson,
          ]) {
            cols.putIfAbsent(c, () => null);
          }
          s.run(UpdateCodeState(old[i].id, cols));
        }
        if (states.length > old.length) {
          s.run(
            AddCodeStates(
              id,
              states.sublist(old.length),
              afterStateId: old.isEmpty ? null : old.last.id,
            ),
          );
        } else if (old.length > states.length) {
          s.run(
            DeleteCodeStates([
              for (final st in old.sublist(states.length)) st.id,
            ]),
          );
        }
        final slideId = rec.slideId;
        if (slideId != null && builds != 'keep') {
          final mine = [
            for (final b in s.model.buildsOf(slideId))
              if (b.elementId == id) b.id,
          ];
          if (mine.isNotEmpty) s.run(DeleteBuilds(mine));
          if (builds == 'all_steps') {
            final specs = codeSteps(s.model, id);
            if (specs.isNotEmpty) s.run(AddBuilds(slideId, specs));
          }
        }
      },
    );
    return SlidesWrites.result(
      o,
      'Set ${states.length} code state${states.length == 1 ? '' : 's'}',
    );
  }

  static Future<ToolResult> updateCodeBlock(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.update_code_block',
      build: (s) {
        final m = s.model;
        final id = SlidesMcp.elementId(m, a.values['element']);
        final rec = SlidesMcp.elementOfKind(m, id, {
          ElementKind.code,
        }, 'a code block');
        Map<String, Object?> current = {};
        try {
          final d = jsonDecode(rec.dataJson ?? '{}');
          if (d is Map) current = d.cast<String, Object?>();
        } on FormatException {
          current = {};
        }
        final next = {
          ...current,
          'v': 1,
          ..._codeOptions(a.object('options')),
          if (a.string('language') case final String l)
            'language': SlidesContent.normalizeLanguage(l),
        };
        s.run(
          SetElementData(
            id,
            jsonEncode(CodeElementData.fromJson(next).toJson()),
          ),
        );
      },
    );
    return SlidesWrites.result(o, 'Updated the code block');
  }

  // ---------------------------------------------------------------- builds

  static SlideBuildKind _kind(String v, String pointer) {
    final k = SlideBuildKind.values.asNameMap()[SlidesInput.camelEnum(v)];
    if (k == null) {
      throw SlidesMcp.invalid('Unknown kind "$v".', pointer: pointer);
    }
    return k;
  }

  static SlideBuildTrigger? _trigger(Object? v) => v is String
      ? SlideBuildTrigger.values.asNameMap()[SlidesInput.camelEnum(v)]
      : null;

  /// The options JSON (`params`, `delivery`, `afterBuild`) of an MCP build.
  static Map<String, Object?> _options(Map<String, Object?> b) {
    final delivery = (b['delivery'] as Map?)?.cast<String, Object?>();
    return {
      if (b['params'] is Map) 'params': b['params'],
      if (delivery != null)
        'delivery': {
          for (final e in SlidesInput.camel(delivery).entries)
            e.key:
                e.value is String && (e.key == 'by' || e.key == 'partTrigger')
                ? SlidesInput.camelEnum(e.value! as String)
                : e.value,
        },
      if (b['after_build'] is Map)
        'afterBuild': SlidesInput.camel(b['after_build']! as Map),
    };
  }

  /// A validated `BuildSpec` for [b] (11 §3.11): unknown effects are
  /// `invalid_args` with the effects allowed for the element.
  static BuildSpec buildSpec(
    DeckModel m,
    Map<String, Object?> b, {
    required String slideId,
    required String pointer,
    required List<SlidesWarning> warnings,
  }) {
    final elementId = SlidesMcp.elementId(
      m,
      b['element'],
      pointer: '$pointer/element',
    );
    final element = m.element(elementId)!;
    if (element.slideId != slideId) {
      throw SlidesMcp.invalid(
        'Element $elementId is not on this slide.',
        pointer: '$pointer/element',
      );
    }
    final kind = _kind('${b['kind']}', '$pointer/kind');
    final effect = '${b['effect']}';
    if (EffectCatalog.byId(kind, effect) == null) {
      final allowed = [
        for (final e in EffectCatalog.forElement(kind, element.kind)) e.id,
      ];
      throw McpToolException(
        McpErrorCode.invalidArgs,
        'Unknown ${b['kind']} effect "$effect" for a ${element.kind.name}. '
        'Allowed: ${allowed.join(', ')}.',
        details: [
          {'pointer': '$pointer/effect', 'message': 'unknown effect'},
          {'allowed': allowed},
        ],
      );
    }
    final v = BuildOptions.fromJson(_options(b), kind: kind, effect: effect);
    if (v.errors.isNotEmpty) {
      throw SlidesMcp.invalid(
        'Invalid build options: ${v.errors.first}',
        pointer: pointer,
      );
    }
    for (final w in v.warnings) {
      warnings.add(
        SlidesWarning('clamped', '$w', elementId: elementId, pointer: pointer),
      );
    }
    final spec = EffectCatalog.byId(kind, effect)!;
    return BuildSpec(
      elementId: elementId,
      kind: kind,
      effect: effect,
      trigger: _trigger(b['trigger']) ?? SlideBuildTrigger.onClick,
      delayMs: (b['delay_ms'] as num?)?.toInt() ?? 0,
      durationMs: (b['duration_ms'] as num?)?.toInt() ?? spec.defaultDurationMs,
      easing: b['easing'] as String? ?? spec.defaultEasing,
      optionsJson: v.value.encode(),
    );
  }

  static Future<ToolResult> setBuilds(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final list = a.list('builds')!;
    final warnings = <SlidesWarning>[];
    late String slideId;
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.set_builds',
      label: 'set_builds (${list.length})',
      warnings: warnings,
      build: (s) {
        final m = s.model;
        slideId = SlidesMcp.slideId(m, a.values['slide']);
        final specs = [
          for (final (i, raw) in list.indexed)
            buildSpec(
              m,
              (raw! as Map).cast<String, Object?>(),
              slideId: slideId,
              pointer: '/builds/$i',
              warnings: warnings,
            ),
        ];
        if ((a.string('mode') ?? 'replace') == 'replace') {
          final old = [for (final b in m.buildsOf(slideId)) b.id];
          if (old.isNotEmpty) s.run(DeleteBuilds(old));
        }
        if (specs.isNotEmpty) s.run(AddBuilds(slideId, specs));
      },
    );
    final timeline = SlidesReadHandlers.timelineJson(t.model, slideId);
    return SlidesWrites.result(
      o,
      'Set ${list.length} build${list.length == 1 ? '' : 's'}: '
      '${timeline['steps']} clicks',
      {'timeline': timeline},
    );
  }

  static Future<ToolResult> updateBuild(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final patch = a.object('patch')!;
    final warnings = <SlidesWarning>[];
    String? slideId;
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.update_build',
      warnings: warnings,
      build: (s) {
        final m = s.model;
        final id = SlidesMcp.canonicalId(a.requireString('build_id'));
        final b = id == null ? null : m.build(id);
        if (b == null) {
          throw McpToolException(
            McpErrorCode.notFound,
            'Build ${a.string('build_id')} not found (slides.get_slide with '
            'include builds).',
          );
        }
        slideId = b.slideId;
        final kind = patch['kind'] is String
            ? _kind(patch['kind']! as String, '/patch/kind')
            : null;
        final effect = patch['effect'] as String?;
        if (effect != null &&
            EffectCatalog.byId(kind ?? b.kind, effect) == null) {
          throw SlidesMcp.invalid(
            'Unknown effect "$effect".',
            pointer: '/patch/effect',
          );
        }
        final options = _options(patch);
        s.run(
          BuildEdits.update(
            m,
            [b.id],
            kind: kind,
            effect: effect,
            trigger: _trigger(patch['trigger']),
            delayMs: (patch['delay_ms'] as num?)?.toInt(),
            durationMs: (patch['duration_ms'] as num?)?.toInt(),
            easing: patch['easing'] as String?,
            options: options.isEmpty ? null : options,
          ),
        );
      },
    );
    return SlidesWrites.result(o, 'Updated the build', {
      if (slideId != null)
        'timeline': SlidesReadHandlers.timelineJson(t.model, slideId!),
    });
  }

  static Future<ToolResult> deleteBuilds(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    var n = 0;
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.delete_builds',
      build: (s) {
        final m = s.model;
        final ids = <String>[];
        for (final raw in a.list('build_ids') ?? const []) {
          final id = SlidesMcp.canonicalId('$raw');
          if (id == null || m.build(id) == null) {
            throw McpToolException(
              McpErrorCode.notFound,
              'Build $raw not found.',
            );
          }
          ids.add(id);
        }
        if (a.values['slide'] != null) {
          final slide = SlidesMcp.slideId(m, a.values['slide']);
          ids.addAll([for (final b in m.buildsOf(slide)) b.id]);
        }
        if (ids.isEmpty &&
            a.list('build_ids') == null &&
            a.values['slide'] == null) {
          throw SlidesMcp.invalid('Give build_ids or slide.');
        }
        n = ids.toSet().length;
        if (n > 0) s.run(DeleteBuilds(ids.toSet().toList()));
      },
    );
    return SlidesWrites.result(o, 'Deleted $n build${n == 1 ? '' : 's'}');
  }

  static Future<ToolResult> setTransition(ToolContext ctx, ToolArgs a) async {
    final t = await _edit(ctx, a);
    final slides = a.values['slides'];
    final tr = a.object('transition');
    var summary = '';
    final o = await SlidesWrites.run(
      ctx,
      t,
      tool: 'slides.set_transition',
      build: (s) {
        final m = s.model;
        TransitionSpec? spec;
        if (tr != null) {
          final v = TransitionSpec.decode(SlidesInput.transitionJson(tr));
          if (!v.isValid) {
            throw SlidesMcp.invalid(
              'Invalid transition: ${v.errors.first}',
              pointer: '/transition',
            );
          }
          spec = v.value;
        }
        if (slides == 'all') {
          s.run(
            BuildEdits.applyTransitionToAll(
              m,
              transition: spec ?? TransitionSpec.none,
            ),
          );
          summary = 'Set the transition of every slide';
          return;
        }
        final ids = SlidesMcp.slideIds(m, (slides as List?)?.cast<Object?>());
        s.run(
          SetSlideProps(
            ids,
            transitionJson: Patch(spec?.encode()),
          ),
        );
        summary =
            'Set the transition of ${ids.length} slide${ids.length == 1 ? '' : 's'}';
      },
    );
    return SlidesWrites.result(o, summary);
  }

  // ---------------------------------------------------------------- export

  static Future<ToolResult> exportPdf(ToolContext ctx, ToolArgs a) async {
    var t = await SlidesMcp.open(ctx, a);
    Map<String, Object?>? refreshed;
    if (a.boolean('refresh_linked_charts') ?? false) {
      if (!t.canEdit) {
        throw McpToolException(
          McpErrorCode.forbidden,
          'Only editors can update linked charts before exporting.',
        );
      }
      _requireSheetsRead(ctx);
      final (o, r) = await refreshCharts(ctx, t);
      refreshed = {...r, 'change_id': o.write.changeId?.uuid};
      t = await SlidesMcp.open(ctx, a);
    }
    final options = SlidesInput.camel(a.object('options') ?? const {});
    final view = await SlidesExportService.export(
      ctx.session,
      ctx.actor,
      t.item.uuid,
      'pdf',
      jsonEncode(options),
    );
    return ToolResult(
      {
        'format': 'pdf',
        'file_name': view.fileName,
        'mime_type': view.mimeType,
        'size_bytes': view.sizeBytes,
        'page_count': view.pageCount,
        'download_url': view.downloadUrl,
        'expires_at': view.expiresAt.toIso8601String(),
        'warnings': [
          for (final w in view.warnings) {'code': w.kind, 'message': w.message},
        ],
        'refreshed_charts': ?refreshed,
      },
      text: 'Download: ${view.downloadUrl} (valid until ${view.expiresAt})',
    );
  }

  /// `drive.export` of a presentation (11 §3.12): `pdf` (as export_pdf),
  /// `md` (the outline Markdown, inline).
  static Future<ToolResult> driveExport(
    ToolContext ctx,
    UuidValue uuid,
    String format,
  ) async {
    final t = await SlidesMcp.openRef(ctx, uuid.uuid);
    switch (format) {
      case 'pdf':
        return exportPdf(ctx, ToolArgs({'deck': uuid.uuid}));
      case 'md':
        if (t.role < Role.editor && !t.item.nonEditorsCanExport) {
          throw McpToolException(
            McpErrorCode.forbidden,
            'The owner has disabled downloads for viewers.',
          );
        }
        final md = DeckOutlineCodec.write(t.model);
        return ToolResult({
          'format': 'md',
          'file_name': '${t.item.name}.md',
          'mime_type': 'text/markdown',
          'size_bytes': utf8.encode(md).length,
          'content': md,
        }, text: md);
      default:
        throw McpToolException(
          McpErrorCode.invalidArgs,
          'Presentations export as pdf or md.',
        );
    }
  }
}
