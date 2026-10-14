import 'dart:convert';

import 'package:test/test.dart';

import '../support/core.dart';

import '../support/fake_hooks.dart';
import '../support/rule_fixtures.dart';

String boolRule(
  Map<String, Object?> condition,
  Map<String, Object?> format, {
  bool? stop,
}) => jsonEncode({
  'v': 1,
  'type': 'boolean',
  'condition': condition,
  'format': format,
  'stopIfTrue': ?stop,
});

const display = FunctionDisplayText(_plain);
String _plain(CellValue v, String? f) => ValueText.automatic(v);

void main() {
  group('Given the CF rule codec', () {
    test(
      'when parsing a boolean rule then disallowed format keys are kept only for export',
      () {
        final r =
            CfRule.parse(
                  boolRule(
                    {'type': 'notBlank'},
                    {
                      'bold': true,
                      'fillColor': '#FCE8E6',
                      'numberFormat': '0.00',
                    },
                    stop: true,
                  ),
                )
                as CfBooleanRule;
        expect(r.format.toMap(), {'bold': true, 'fillColor': '#FCE8E6'});
        expect(r.extraFormat, {'numberFormat': '0.00'});
        expect(r.stopIfTrue, isTrue);
        expect((r.toJson()['format'] as Map)['numberFormat'], '0.00');
      },
    );

    test(
      'when stopIfTrue is absent then it reads false (XLSX semantics) but new rules default true',
      () {
        final parsed =
            CfRule.parse(boolRule({'type': 'notBlank'}, {'bold': true}))
                as CfBooleanRule;
        expect(parsed.stopIfTrue, isFalse);
        expect(
          CfBooleanRule(
            condition: Condition.of(ConditionType.notBlank),
            format: CellFormat.empty,
          ).stopIfTrue,
          isTrue,
        );
      },
    );

    test(
      'when round-tripping color scales, data bars and icon sets then JSON is stable',
      () {
        for (final json in [
          '{"v":1,"type":"colorScale","points":[{"kind":"min","color":"#FFFFFF"},{"kind":"percentile","value":"50","color":"#FFD666"},{"kind":"max","color":"#57BB8A"}]}',
          '{"v":1,"type":"dataBar","min":{"kind":"min"},"max":{"kind":"max"},"color":"#638EC6","negativeColor":"#E06666","gradient":true,"axis":"auto","direction":"context","showValue":true}',
          '{"v":1,"type":"iconSet","set":"3arrows","thresholds":[{"op":">=","kind":"percent","value":"67"},{"op":">","kind":"percent","value":"33"}],"reverse":false,"showValue":true}',
        ]) {
          expect(CfRule.parse(json).encode(), json);
        }
      },
    );

    test('when the type is unknown then the rule is kept verbatim', () {
      final r = CfRule.parse('{"v":1,"type":"sparkle","x":1}');
      expect(r, isA<CfUnknownRule>());
      expect(r.toJson(), {'v': 1, 'type': 'sparkle', 'x': 1});
    });

    test(
      'when listing presets then there are 9 styles and 12 color scales',
      () {
        expect(CfPresets.formattingStyles, hasLength(9));
        expect(CfPresets.formattingStyles.first.format.toMap(), {
          'fillColor': '#B7E1CD',
        });
        final scales = CfPresets.colorScales();
        expect(scales, hasLength(12));
        expect(scales.first.points.last.color, '#57BB8A');
        expect(scales.map((s) => s.id).toSet(), hasLength(12));
      },
    );
  });

  group('Given a sheet with values in A1:A5 and CF rules', () {
    late WorkbookBuilder b;
    late String sid;
    setUp(() {
      b = WorkbookBuilder();
      sid = b.sheet('Sheet1', rows: 20, cols: 6);
      b.values('A1', [
        [0],
        [25],
        [50],
        [75],
        [100],
      ]);
    });

    CfEvaluator evaluator(WorkbookModel m, {FormulaHooks? hooks}) =>
        CfEvaluator(m, ModelCellSource(m), display, hooks);

    test(
      'when a white→green scale applies then min is #FFFFFF, max #57BB8A and mid interpolates (AC-F11)',
      () {
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], CfPresets.colorScales().first.rule.encode());
        final m = b.build();
        final cf = evaluator(m);
        expect(cf.evaluate(sid, 0, 0).overlay[FormatAttr.fillColor], '#FFFFFF');
        expect(cf.evaluate(sid, 4, 0).overlay[FormatAttr.fillColor], '#57BB8A');
        expect(cf.evaluate(sid, 4, 0).scaleColor, '#57BB8A');
        expect(
          cf.evaluate(sid, 2, 0).overlay[FormatAttr.fillColor],
          ColorUtil.lerp('#FFFFFF', '#57BB8A', 0.5),
        );
      },
    );

    test(
      'when a 3-point scale has a percentile midpoint then the midpoint value gets the mid color',
      () {
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], CfPresets.colorScales()[6].rule.encode()); // red → yellow → green
        final m = b.build();
        final cf = evaluator(m);
        expect(cf.evaluate(sid, 2, 0).scaleColor, CfPresets.yellow);
        expect(cf.evaluate(sid, 0, 0).scaleColor, CfPresets.red);
        expect(
          cf.evaluate(sid, 1, 0).scaleColor,
          ColorUtil.lerp(CfPresets.red, CfPresets.yellow, 0.5),
        );
      },
    );

    test('when the scale uses number points then values outside clamp', () {
      final rule = CfColorScaleRule([
        ColorScalePoint.of(CfValueKind.number, '#000000', '30'),
        ColorScalePoint.of(CfValueKind.number, '#FFFFFF', '70'),
      ]);
      addCfRule(b, sid, fid(1), 'a0', [
        gridRange(b, sid, 0, 0, 4, 0),
      ], rule.encode());
      final cf = evaluator(b.build());
      expect(cf.evaluate(sid, 0, 0).scaleColor, '#000000');
      expect(cf.evaluate(sid, 4, 0).scaleColor, '#FFFFFF');
      expect(
        cf.evaluate(sid, 2, 0).scaleColor,
        ColorUtil.lerp('#000000', '#FFFFFF', 0.5),
      );
    });

    test(
      'when two matching rules default to stopIfTrue then only the first applies (AC-F10)',
      () {
        addCfRule(
          b,
          sid,
          fid(1),
          'a0',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule({'type': 'notBlank'}, {'fillColor': '#FF0000'}, stop: true),
        );
        addCfRule(b, sid, fid(2), 'a1', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], boolRule({'type': 'notBlank'}, {'bold': true}, stop: true));
        final r = evaluator(b.build()).evaluate(sid, 1, 0);
        expect(r.overlay.toMap(), {'fillColor': '#FF0000'});
      },
    );

    test(
      'when stopIfTrue is off on the first rule then both rules apply per attribute (AC-F10)',
      () {
        addCfRule(
          b,
          sid,
          fid(1),
          'a0',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule({'type': 'notBlank'}, {'fillColor': '#FF0000'}, stop: false),
        );
        addCfRule(
          b,
          sid,
          fid(2),
          'a1',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule(
            {'type': 'notBlank'},
            {'bold': true, 'fillColor': '#00FF00'},
          ),
        );
        final r = evaluator(b.build()).evaluate(sid, 1, 0);
        expect(r.overlay.toMap(), {'bold': true, 'fillColor': '#FF0000'});
      },
    );

    test(
      'when rules are ordered by sortKey then priority follows the key, not insertion',
      () {
        addCfRule(
          b,
          sid,
          fid(1),
          'a5',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule({'type': 'notBlank'}, {'fillColor': '#111111'}, stop: true),
        );
        addCfRule(
          b,
          sid,
          fid(2),
          'a1',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule({'type': 'notBlank'}, {'fillColor': '#222222'}, stop: true),
        );
        expect(
          evaluator(
            b.build(),
          ).evaluate(sid, 0, 0).overlay[FormatAttr.fillColor],
          '#222222',
        );
      },
    );

    test('when a disabled rule matches then it is skipped', () {
      addCfRule(
        b,
        sid,
        fid(1),
        'a0',
        [gridRange(b, sid, 0, 0, 4, 0)],
        boolRule({'type': 'notBlank'}, {'bold': true}),
        enabled: false,
      );
      expect(evaluator(b.build()).evaluate(sid, 0, 0).isEmpty, isTrue);
    });

    test(
      'when a boolean rule sets the fill then a lower-priority scale does not override it',
      () {
        addCfRule(
          b,
          sid,
          fid(1),
          'a0',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule(
            {
              'type': 'numberGreater',
              'values': [
                {'v': '60'},
              ],
            },
            {'fillColor': '#123456'},
            stop: false,
          ),
        );
        addCfRule(b, sid, fid(2), 'a1', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], CfPresets.colorScales().first.rule.encode());
        final cf = evaluator(b.build());
        expect(cf.evaluate(sid, 4, 0).overlay[FormatAttr.fillColor], '#123456');
        expect(cf.evaluate(sid, 4, 0).scaleColor, isNull);
        expect(cf.evaluate(sid, 0, 0).scaleColor, '#FFFFFF');
      },
    );

    test(
      'when a data bar applies then the bar length is proportional to the value',
      () {
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], const CfDataBarRule().encode());
        final cf = evaluator(b.build());
        expect(
          cf.evaluate(sid, 2, 0).dataBar,
          isA<DataBarResult>().having((d) => d.end, 'end', 0.5),
        );
        expect(cf.evaluate(sid, 4, 0).dataBar!.end, 1.0);
        expect(cf.evaluate(sid, 4, 0).dataBar!.axis, isNull);
      },
    );

    test(
      'when values are negative then the bar grows from the proportional axis in the negative color',
      () {
        b.values('B1', [
          [-50],
          [50],
          [150],
        ]);
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 1, 2, 1),
        ], const CfDataBarRule().encode());
        final cf = evaluator(b.build());
        final neg = cf.evaluate(sid, 0, 1).dataBar!;
        expect(neg.negative, isTrue);
        expect(neg.color, '#E06666');
        expect(neg.axis, 0.25);
        expect((neg.start, neg.end), (0.0, 0.25));
        final pos = cf.evaluate(sid, 1, 1).dataBar!;
        expect((pos.start, pos.end), (0.25, 0.5));
      },
    );

    test(
      'when all values are negative then bars grow leftwards from an axis at the right edge',
      () {
        b.values('B1', [
          [-100],
          [-50],
          [0],
        ]);
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 1, 1, 1),
        ], const CfDataBarRule().encode());
        final cf = evaluator(b.build());

        final most = cf.evaluate(sid, 0, 1).dataBar!;
        final least = cf.evaluate(sid, 1, 1).dataBar!;

        expect((most.start, most.end, most.axis), (0.0, 1.0, 1.0));
        expect((least.start, least.end), (1.0, 1.0));
        expect(most.negative, isTrue);
      },
    );

    test('when the axis is in the middle then bars grow from 50 %', () {
      b.values('B1', [
        [-50],
        [100],
      ]);
      addCfRule(b, sid, fid(1), 'a0', [
        gridRange(b, sid, 0, 1, 1, 1),
      ], const CfDataBarRule(axis: DataBarAxis.middle).encode());
      final cf = evaluator(b.build());

      final neg = cf.evaluate(sid, 0, 1).dataBar!;
      final pos = cf.evaluate(sid, 1, 1).dataBar!;

      expect((neg.start, neg.end, neg.axis), (0.25, 0.5, 0.5));
      expect((pos.start, pos.end), (0.5, 1.0));
    });

    test('when the direction is rtl then the bar is mirrored', () {
      addCfRule(
        b,
        sid,
        fid(1),
        'a0',
        [gridRange(b, sid, 0, 0, 4, 0)],
        const CfDataBarRule(
          direction: DataBarDirection.rtl,
          showValue: false,
        ).encode(),
      );
      final bar = evaluator(b.build()).evaluate(sid, 3, 0).dataBar!;

      expect(bar.rightToLeft, isTrue);
      expect(bar.showValue, isFalse);
      expect(bar.end, 0.75);
    });

    test('when an icon set is reversed then the icon order flips', () {
      final rule = CfIconSetRule(
        set: IconSetKind.trafficLights3,
        thresholds: [
          IconThreshold(const CfThreshold(CfValueKind.number, '60')),
          IconThreshold(
            const CfThreshold(CfValueKind.number, '25'),
            inclusive: false,
          ),
        ],
        reverse: true,
      );
      addCfRule(b, sid, fid(1), 'a0', [
        gridRange(b, sid, 0, 0, 4, 0),
      ], rule.encode());
      final cf = evaluator(b.build());

      expect(
        cf.evaluate(sid, 4, 0).icon,
        const IconResult(IconSetKind.trafficLights3, 2),
      );
      expect(cf.evaluate(sid, 1, 0).icon!.index, 0, reason: '25 is not > 25');
      expect(cf.evaluate(sid, 2, 0).icon!.index, 1);
    });

    test(
      'when evaluating a visible rectangle then only cells with conditional formatting are returned',
      () {
        addCfRule(
          b,
          sid,
          fid(1),
          'a0',
          [gridRange(b, sid, 0, 0, 4, 0)],
          boolRule(
            {
              'type': 'numberGreater',
              'values': [
                {'v': '30'},
              ],
            },
            {'bold': true},
          ),
        );
        addCfRule(b, sid, fid(2), 'a1', [
          gridRange(b, sid, 3, 0, 9, 2),
        ], CfPresets.colorScales().first.rule.encode());
        final cf = evaluator(b.build());

        final out = cf.evaluateRect(sid, const GridRect(0, 0, 19, 5));

        expect(out.keys.toSet(), {
          const CellPos(2, 0),
          const CellPos(3, 0),
          const CellPos(4, 0),
        });
        expect(out[const CellPos(3, 0)]!.overlay[FormatAttr.bold], isTrue);
        expect(out[const CellPos(3, 0)]!.scaleColor, isNotNull);
        expect(cf.evaluateRect(sid, const GridRect(12, 0, 19, 5)), isEmpty);
      },
    );

    test(
      'when a draft covers the rectangle then the draft is previewed in rectangle results',
      () {
        final cf = evaluator(b.build());
        cf.setDraft(
          CfDraft(
            sheetId: sid,
            ruleId: fid(9),
            sortKey: 'a0',
            ranges: const [GridRect(0, 0, 1, 0)],
            rule: CfBooleanRule(
              condition: Condition.of(ConditionType.notBlank),
              format: CellFormat({FormatAttr.italic: true}),
            ),
          ),
        );

        final out = cf.evaluateRect(sid, const GridRect(0, 0, 5, 5));

        expect(out.keys, unorderedEquals(const [CellPos(0, 0), CellPos(1, 0)]));
      },
    );

    test(
      'when an icon set has percent thresholds then icons follow top-down evaluation',
      () {
        final rule = CfIconSetRule(
          set: IconSetKind.arrows3,
          thresholds: [
            IconThreshold(const CfThreshold(CfValueKind.percent, '67')),
            IconThreshold(const CfThreshold(CfValueKind.percent, '33')),
          ],
        );
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], rule.encode());
        final cf = evaluator(b.build());
        expect(cf.evaluate(sid, 4, 0).icon!.index, 0);
        expect(cf.evaluate(sid, 2, 0).icon!.index, 1);
        expect(cf.evaluate(sid, 0, 0).icon!.index, 2);
      },
    );

    test(
      'when computing range stats over two ranges then all numeric values count',
      () {
        b.value('C1', 1000);
        b.value('C2', 'text');
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
          gridRange(b, sid, 0, 2, 1, 2),
        ], CfPresets.colorScales().first.rule.encode());
        final m = b.build();
        final stats = evaluator(m).rangeStats(sid, fid(1));
        expect((stats.count, stats.min, stats.max), (6, 0.0, 1000.0));
        expect(stats.percentile(0.5), 62.5);
      },
    );

    test(
      'when a cell value changes then invalidating the cell refreshes stats-dependent results',
      () {
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], CfPresets.colorScales().first.rule.encode());
        final m = b.build();
        final cf = evaluator(m);
        expect(
          cf.evaluate(sid, 2, 0).scaleColor,
          ColorUtil.lerp('#FFFFFF', '#57BB8A', 0.5),
        );
        final s = m.sheets.single;
        final cellId = SheetsIds.cellId(sid, b.rowId(4), b.colId(0));
        m.upsertRow(SheetsTables.cell, cellId, {
          Cols.sheetId: sid,
          CellCols.rowId: b.rowId(4),
          CellCols.columnId: b.colId(0),
          CellCols.content: 'n:200',
        });
        expect(s.cellAt(4, 0)!.content, 'n:200');
        cf.invalidateCells(sid, [(rowId: b.rowId(4), colId: b.colId(0))]);
        expect(
          cf.evaluate(sid, 2, 0).scaleColor,
          ColorUtil.lerp('#FFFFFF', '#57BB8A', 0.25),
        );
      },
    );

    test(
      'when a draft rule is set then it previews without persisting and clearing restores',
      () {
        final m = b.build();
        final cf = evaluator(m);
        expect(cf.evaluate(sid, 0, 0).isEmpty, isTrue);
        cf.setDraft(
          CfDraft(
            sheetId: sid,
            ruleId: 'draft',
            sortKey: 'a0',
            ranges: const [GridRect(0, 0, 4, 0)],
            rule: CfBooleanRule(
              condition: Condition.of(ConditionType.notBlank),
              format: CellFormat({FormatAttr.italic: true}),
            ),
          ),
        );
        expect(cf.evaluate(sid, 0, 0).overlay.toMap(), {'italic': true});
        expect(m.sheets.single.cfRules, isEmpty);
        cf.setDraft(null);
        expect(cf.evaluate(sid, 0, 0).isEmpty, isTrue);
      },
    );

    test(
      'when a draft edits an existing rule then the stored version is replaced in the preview',
      () {
        addCfRule(b, sid, fid(1), 'a0', [
          gridRange(b, sid, 0, 0, 4, 0),
        ], boolRule({'type': 'notBlank'}, {'bold': true}));
        final cf = evaluator(b.build());
        cf.setDraft(
          CfDraft(
            sheetId: sid,
            ruleId: fid(1),
            sortKey: 'a0',
            ranges: const [GridRect(0, 0, 4, 0)],
            rule: CfBooleanRule(
              condition: Condition.of(ConditionType.blank),
              format: CellFormat({FormatAttr.bold: true}),
            ),
          ),
        );
        expect(cf.evaluate(sid, 0, 0).isEmpty, isTrue);
        expect(cf.evaluate(sid, 10, 0).isEmpty, isTrue);
      },
    );
  });

  group('Given a CF rule =\$C2>100 on A2:F100 (AC-F9)', () {
    late WorkbookBuilder b;
    late WorkbookModel m;
    late String sid;
    late FakeHooks hooks;
    late CfEvaluator cf;
    setUp(() {
      b = WorkbookBuilder();
      sid = b.sheet('Sheet1', rows: 100, cols: 6);
      b.values('C2', [
        [50],
        [150],
        [100],
        [101],
      ]);
      addCfRule(
        b,
        sid,
        fid(1),
        'a0',
        [gridRange(b, sid, 1, 0, 99, 5)],
        boolRule(
          {
            'type': 'customFormula',
            'values': [
              {'v': r'=$C2>100'},
            ],
          },
          {'fillColor': '#FCE8E6'},
          stop: true,
        ),
      );
      m = b.build();
      final values = ModelCellSource(m);
      hooks = FakeHooks(values);
      cf = CfEvaluator(m, values, display, hooks);
    });

    test(
      'when evaluating rows then entire rows where C > 100 are highlighted',
      () {
        expect(cf.evaluate(sid, 1, 0).isEmpty, isTrue);
        for (var c = 0; c < 6; c++) {
          expect(
            cf.evaluate(sid, 2, c).overlay[FormatAttr.fillColor],
            '#FCE8E6',
          );
        }
        expect(cf.evaluate(sid, 3, 5).isEmpty, isTrue);
        expect(cf.evaluate(sid, 4, 3).overlay[FormatAttr.fillColor], '#FCE8E6');
        expect(
          cf.evaluate(sid, 0, 0).isEmpty,
          isTrue,
          reason: 'row 1 is outside the range',
        );
      },
    );

    test(
      'when results are cached then re-evaluating does not call the formula again',
      () {
        cf.evaluate(sid, 2, 0);
        final n = hooks.evaluations;
        cf.evaluate(sid, 2, 0);
        expect(hooks.evaluations, n);
      },
    );

    test(
      'when C7 changes and the engine notifies the rule then row 7 updates',
      () {
        expect(cf.evaluate(sid, 6, 0).isEmpty, isTrue);
        m.upsertRow(
          SheetsTables.cell,
          SheetsIds.cellId(sid, b.rowId(6), b.colId(2)),
          {
            Cols.sheetId: sid,
            CellCols.rowId: b.rowId(6),
            CellCols.columnId: b.colId(2),
            CellCols.content: 'n:500',
          },
        );
        cf.invalidateRule(fid(1));
        expect(cf.evaluate(sid, 6, 0).overlay[FormatAttr.fillColor], '#FCE8E6');
      },
    );
  });
}
