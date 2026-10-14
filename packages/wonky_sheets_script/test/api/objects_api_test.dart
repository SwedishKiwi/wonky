import 'package:clock/clock.dart';
import 'package:test/test.dart';
import 'package:wonky_core/wonky_core.dart' show Role;
import 'package:wonky_sheets_core/wonky_sheets_core.dart';
import 'package:wonky_sheets_script/testing.dart';
import 'package:wonky_sheets_script/wonky_sheets_script.dart';

const _source = r'''
import 'package:wonky/wonky.dart';

Sheet get _s => SpreadsheetApp.active.sheetByName('Sheet1')!;

String insertChart() {
  final chart = _s.newChart()
      .setChartType('bar')
      .addRange(_s.getRange('A1:C3'))
      .setTitle('Totals')
      .setPosition(5, 2)
      .setOption('legend.position', 'bottom')
      .build();
  final inserted = _s.insertChart(chart);
  return '${inserted.chartType}|${inserted.title}|${inserted.row}|${inserted.column}|${inserted.ranges.first.a1Notation}|${_s.charts.length}';
}

String modifyAndRemoveChart() {
  final c = _s.insertChart(_s.newChart().addRange(_s.getRange('A1:C2')).build());
  final updated = _s.updateChart(c.modify().setChartType('line').setTitle('Trend').build());
  final type = updated.chartType;
  _s.removeChart(updated);
  return '$type|${updated.title}|${_s.charts.length}';
}

String filterRows() {
  final f = _s.getRange('A1:C3').createFilter();
  f.setColumnFilterCriteria(1, FilterCriteria.whenNumberGreaterThan(2));
  final c = _s.filter!.getColumnFilterCriteria(1)!;
  final range = f.range.a1Notation;
  f.removeColumnFilterCriteria(1);
  final cleared = _s.filter!.getColumnFilterCriteria(1) == null;
  f.remove();
  return '${c.conditionType}|$range|$cleared|${_s.filter == null}';
}

String conditionalFormat() {
  final rule = ConditionalFormatRuleBuilder()
      .setRanges([_s.getRange('A1:C2')])
      .whenNumberGreaterThan(3)
      .setBackground('#ffcc00')
      .setBold(true)
      .build();
  final added = _s.addConditionalFormatRule(rule);
  final listed = _s.conditionalFormatRules;
  final summary = '${listed.length}|${added.type}|${added.conditionType}|${added.background}|${added.ranges.first.a1Notation}';
  _s.removeConditionalFormatRule(added);
  return '$summary|${_s.conditionalFormatRules.length}';
}

String gradient() {
  final r = _s.addConditionalFormatRule(ConditionalFormatRuleBuilder()
      .setRanges([_s.getRange('A1:A2')])
      .setGradient('#FFFFFF', '#00FF00')
      .build());
  return r.type;
}

String protect() {
  final p = _s.getRange('A1:B2').protect();
  p.description = 'Totals';
  p.warningOnly = true;
  final whole = _s.protect();
  final n = _s.protections.length;
  final d = p.description;
  final w = p.isWarningOnly;
  final range = p.range!.a1Notation;
  whole.remove();
  return '$n|$d|$w|$range|${whole.range == null}|${_s.protections.length}';
}

String lockAndCache() {
  final lock = LockService.documentLock;
  final got = lock.tryLock(1000);
  final has = lock.hasLock;
  lock.releaseLock();
  final cache = CacheService.documentCache;
  cache.put('k', 'v');
  cache.putAll({'a': '1', 'b': '2'});
  final all = cache.getAll(['a', 'b', 'missing']);
  cache.remove('a');
  return '$got|$has|${cache.get('k')}|${all.length}|${cache.get('a') == null}|${CacheService.userCache.get('k') == null}';
}

String plannerOps() {
  _s.getRange('A1:C2').sort([SortSpec(column: 1, ascending: false)]);
  _s.getRange('A5:A7').values = [['x'], ['x'], ['y']];
  final unique = _s.getRange('A5:A7').removeDuplicates();
  _s.getRange('B5').value = '  hi  ';
  _s.getRange('B5').trimWhitespace();
  String? none;
  return '${_s.getRange('A1').value}|${unique.a1Notation}|[${_s.getRange('B5').value}]|$none';
}

Object? CACHED(Object? key) {
  final c = CacheService.documentCache;
  final hit = c.get('cf:$key');
  if (hit != null) return 'hit $hit';
  c.put('cf:$key', 'one');
  return 'miss';
}
''';

void main() {
  late ScriptProgram program;
  setUpAll(() => program = compileScript({'main.dart': _source}));

  group('Given the object API members (09 §6.3)', () {
    late ScriptTestBench bench;
    setUp(() => bench = ScriptTestBench(conformanceWorkbook()));
    tearDown(() => bench.dispose());

    Future<Object?> run(String fn, {Role role = Role.editor}) async {
      final r = await bench.run(program, fn, role: role);
      expect(
        r.status,
        ExecutionStatus.completed,
        reason:
            '${r.error?.type} ${r.error} ${r.error?.frames} ${r.logs.map((l) => l.message)}',
      );
      return r.result;
    }

    test(
      'when sort, removeDuplicates and trimWhitespace run then they apply',
      () async {
        expect(await run('plannerOps'), '4|A5:A6|[hi]|null');
      },
    );

    test(
      'when a chart is built and inserted then it is on the sheet',
      () async {
        expect(await run('insertChart'), 'bar|Totals|5|2|A1:C3|1');
        final s = bench.model.sheetByName('Sheet1')!;
        final o = s.objects.values.single;
        expect(o.kind, EmbeddedObjectKind.chart);
        expect(ChartSpec.fromJson(o.specJson).legend.position.name, 'bottom');
      },
    );

    test(
      'when a chart is modified and removed then the sheet has none',
      () async {
        expect(await run('modifyAndRemoveChart'), 'line|Trend|0');
      },
    );

    test('when a filter is created then criteria round-trip', () async {
      expect(await run('filterRows'), 'numberGreater|A1:C3|true|true');
    });

    test('when a conditional format rule is added then it is listed', () async {
      expect(
        await run('conditionalFormat'),
        '1|boolean|numberGreater|#FFCC00|A1:C2|0',
      );
      expect(await run('gradient'), 'colorScale');
    });

    test('when ranges are protected then protections are listed', () async {
      expect(await run('protect'), '2|Totals|true|A1:B2|true|1');
    });

    test('when a viewer protects a range then it is denied', () async {
      final r = await bench.run(program, 'protect', role: Role.viewer);
      expect(r.status, ExecutionStatus.failed);
      expect(r.error!.type, 'PermissionDeniedException');
    });

    test(
      'when locks and caches are used then values are kept per scope',
      () async {
        expect(await run('lockAndCache'), 'true|true|v|2|true|true');
      },
    );

    test('when a custom function caches then the next call hits', () async {
      final first = await bench.run(
        program,
        'CACHED',
        kind: ExecutionKind.customFunction,
        args: ['x'],
      );
      expect(first.result, 'miss', reason: '${first.error}');
      final second = await bench.run(
        program,
        'CACHED',
        kind: ExecutionKind.customFunction,
        args: ['x'],
      );
      expect(second.result, 'hit one');
    });
  });

  group('Given server locks', () {
    test(
      'when a second owner waits then it gets the lock on release',
      () async {
        final locks = MemoryScriptLocks();
        final a = Object(), b = Object();
        expect(locks.acquire('k', a, Duration.zero), isTrue);
        expect(locks.acquire('k', b, Duration.zero), isFalse);
        final waiting = locks.acquire('k', b, const Duration(seconds: 5));
        locks.release('k', a);
        expect(await waiting, isTrue);
        expect(locks.holds('k', b), isTrue);
      },
    );

    test('when the wait times out then acquire returns false', () async {
      final locks = MemoryScriptLocks();
      final a = Object(), b = Object();
      locks.acquire('k', a, Duration.zero);
      expect(
        await locks.acquire('k', b, const Duration(milliseconds: 20)),
        isFalse,
      );
      expect(locks.holds('k', a), isTrue);
    });
  });

  group('Given the script cache', () {
    test('when the time to live passes then the value is gone', () {
      var now = DateTime.utc(2026);
      final cache = MemoryScriptCache(clock: Clock(() => now));
      cache.put('k', 'v', const Duration(seconds: 10));
      expect(cache.get('k'), 'v');
      now = now.add(const Duration(seconds: 11));
      expect(cache.get('k'), isNull);
    });
  });
}
