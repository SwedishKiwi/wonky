import 'dart:convert';

import 'package:test/test.dart';
import 'package:wonky_sheets_core/src/data_tools/data_tools.dart';

import '../../rules/support/core.dart';
import '../../rules/support/rule_fixtures.dart';

const owner = 'owner-uuid';
const creator = 'creator-uuid';
const editor = 'editor-uuid';
const bo = 'bo-uuid';

void main() {
  late WorkbookBuilder b;
  late String s1;
  late String s2;
  setUp(() {
    b = WorkbookBuilder();
    s1 = b.sheet('Sheet1', rows: 50, cols: 8);
    s2 = b.sheet('Config', rows: 10, cols: 4);
    b.use('Sheet1');
    // F2:F40 restricted to the creator + Bo.
    b.row(SheetsTables.protectedRange, fid(1), {
      Cols.sheetId: s1,
      Cols.rangeJson: gridRange(b, s1, 1, 5, 39, 5).encode(),
      'editorsJson': jsonEncode([bo]),
      Cols.createdBy: creator,
    });
    // A45:B46 warning only.
    b.row(SheetsTables.protectedRange, fid(2), {
      Cols.sheetId: s1,
      Cols.rangeJson: gridRange(b, s1, 44, 0, 45, 1).encode(),
      'warningOnly': true,
      Cols.createdBy: creator,
    });
    // Sheet "Config" protected except B2:B5.
    b.use('Config');
    b.row(SheetsTables.protectedRange, fid(3), {
      Cols.sheetId: s2,
      'exceptRangesJson': GridRange.encodeList([gridRange(b, s2, 1, 1, 4, 1)]),
      Cols.createdBy: creator,
    });
  });

  group('Given protected ranges and a protected sheet (07 §10.3)', () {
    final matrix = <(String, WriteIntent Function(String s1, String s2), String, bool, GuardStatus)>[
      ('editor types in F5', (s1, s2) => CellWrites(s1, [GridRect.cell(4, 5)]), editor, false, GuardStatus.blocked),
      ('owner types in F5', (s1, s2) => CellWrites(s1, [GridRect.cell(4, 5)]), editor, true, GuardStatus.allowed),
      ('creator types in F5', (s1, s2) => CellWrites(s1, [GridRect.cell(4, 5)]), creator, false, GuardStatus.allowed),
      ('listed editor types in F5', (s1, s2) => CellWrites(s1, [GridRect.cell(4, 5)]), bo, false, GuardStatus.allowed),
      ('editor pastes a block overlapping F5', (s1, s2) => CellWrites(s1, [const GridRect(3, 3, 6, 6)]), editor, false, GuardStatus.blocked),
      ('editor writes outside', (s1, s2) => CellWrites(s1, [const GridRect(0, 0, 0, 4)]), editor, false, GuardStatus.allowed),
      ('editor writes into a warning range', (s1, s2) => CellWrites(s1, [GridRect.cell(44, 0)]), editor, false, GuardStatus.warnings),
      ('editor writes warning + blocked', (s1, s2) => CellWrites(s1, [GridRect.cell(44, 0), GridRect.cell(4, 5)]), editor, false, GuardStatus.blocked),
      ('editor deletes row 10', (s1, s2) => Structural(s1, Dimension.rows, [9], StructuralOp.delete), editor, false, GuardStatus.blocked),
      ('editor deletes row 1', (s1, s2) => Structural(s1, Dimension.rows, [0], StructuralOp.delete), editor, false, GuardStatus.allowed),
      ('editor deletes column F', (s1, s2) => Structural(s1, Dimension.columns, [5], StructuralOp.delete), editor, false, GuardStatus.blocked),
      ('editor adds a CF rule over F', (s1, s2) => RuleWrite(s1, RuleKind.conditionalFormat, [const GridRect(0, 5, 49, 5)]), editor, false, GuardStatus.blocked),
      ('editor renames Sheet1', (s1, s2) => SheetOp(s1, 'rename'), editor, false, GuardStatus.allowed),
      ('editor renames Config', (s1, s2) => SheetOp(s2, 'rename'), editor, false, GuardStatus.blocked),
      ('editor adds a chart on Config', (s1, s2) => ObjectWrite(s2), editor, false, GuardStatus.blocked),
      ('editor types in Config B3 (except)', (s1, s2) => CellWrites(s2, [GridRect.cell(2, 1)]), editor, false, GuardStatus.allowed),
      ('editor types in Config A3', (s1, s2) => CellWrites(s2, [GridRect.cell(2, 0)]), editor, false, GuardStatus.blocked),
      ('editor inserts a row in Config', (s1, s2) => Structural(s2, Dimension.rows, [2], StructuralOp.insert), editor, false, GuardStatus.blocked),
      ('editor creates a basic filter on Config', (s1, s2) => FilterWrite(s2, const GridRect(1, 1, 4, 1)), editor, false, GuardStatus.blocked),
      ('editor creates a filter view on Config', (s1, s2) => FilterWrite(s2, const GridRect(0, 0, 4, 3), isView: true), editor, false, GuardStatus.allowed),
      ('editor creates a basic filter over F', (s1, s2) => FilterWrite(s1, const GridRect(0, 4, 49, 6)), editor, false, GuardStatus.blocked),
      ('editor adds a named range', (s1, s2) => const NameWrite(), editor, false, GuardStatus.allowed),
    ];
    for (final (name, intent, user, isOwner, status) in matrix) {
      test('when the $name then the result is ${status.name}', () {
        final g = ProtectionGuard(b.build());
        expect(g.check(intent(s1, s2), user, isOwner: isOwner).status, status);
      });
    }

    test('when blocked then the hits name the protection and the touched cells', () {
      final r = ProtectionGuard(b.build()).check(CellWrites(s1, [const GridRect(3, 3, 6, 6)]), editor, isOwner: false);
      expect(r.hits.single, ProtectionHit(fid(1), const GridRect(3, 5, 6, 5), warningOnly: false));
      expect(r.protectionIds, {fid(1)});
    });

    test('when indexing protections then except ranges are subtracted', () {
      final m = b.build();
      final idx = ProtectedIndex(m.sheet(s2)!);
      expect(idx.at(2, 1), isEmpty);
      expect(idx.at(2, 0), [fid(3)]);
      expect(ProtectedIndex(m.sheet(s1)!).intersecting(const GridRect(0, 0, 49, 7)), hasLength(2));
    });

    test('when checking who may manage a protection then owner, creator and editors may', () {
      final p = b.build().sheet(s1)!.protections[fid(1)]!;
      expect(ProtectionGuard.canManage(p, bo, isOwner: false), isTrue);
      expect(ProtectionGuard.canManage(p, editor, isOwner: false), isFalse);
      expect(ProtectionGuard.canManage(p, editor, isOwner: true), isTrue);
      expect(kProtectedRangeErrorCode, 'protected_range');
    });
  });
}
