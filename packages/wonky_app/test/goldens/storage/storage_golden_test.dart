@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_app/wonky_app.dart';

import '../../storage/support/storage_pump.dart';

/// Goldens of the storage UI in light and dark (D-11, Drive 03 §6; plan
/// 05 §4.4): the meter (normal, warning, over quota, calculating), the
/// banner (90 %, over quota with *Empty trash*) and every *Out of storage*
/// dialog variant. Masters are made and compared on CI Linux only
/// (specs/15 §7): run locally with `-x golden`.
void main() {
  late CommandTestHarness h;
  tearDown(() => h.dispose());

  const meters = {'normal': 12.3, 'warning': 46.1, 'over': 50.4};

  const problems = <String, QuotaProblem>{
    'own': OwnQuotaProblem(
      neededBytes: 13002342,
      availableBytes: 3250585,
      quotaBytes: quota,
    ),
    'owner': OwnerQuotaProblem(ownerName: 'Anna Berg'),
    'batch': BatchQuotaProblem(
      fileCount: 5,
      neededBytes: 65011712,
      availableBytes: 19398656,
    ),
    'transfer': TransferQuotaProblem(
      newOwnerName: 'Bo Chen',
      neededBytes: 8598323,
      itemName: 'Q3 deck',
    ),
    'accept': TransferAcceptQuotaProblem(
      neededBytes: 8598323,
      availableBytes: 2097152,
      itemName: 'Q3 deck',
    ),
    'too_large': FileTooLargeProblem(maxBytes: quota),
  };

  for (final b in Brightness.values) {
    for (final MapEntry(key: name, value: usedMb) in meters.entries) {
      testWidgets('storage meter $name ${b.name}', (tester) async {
        h = storageHarness(storage: FakeStorage.used((usedMb * mb).round()));
        await pumpWithShell(
          tester,
          h,
          Center(
            child: SizedBox(
              width: 240,
              child: StorageMeter(services: h.services, onOpen: () {}),
            ),
          ),
          brightness: b,
          size: const Size(280, 80),
        );
        await expectLater(
          find.byType(StorageMeter),
          matchesGoldenFile('storage_meter_${name}_${b.name}.png'),
        );
      });
    }

    testWidgets('storage meter calculating ${b.name}', (tester) async {
      h = storageHarness(storage: FakeStorage.used(3 * mb, calculating: true));
      await pumpWithShell(
        tester,
        h,
        Center(
          child: SizedBox(
            width: 240,
            child: StorageMeter(services: h.services),
          ),
        ),
        brightness: b,
        size: const Size(280, 80),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await expectLater(
        find.byType(StorageMeter),
        matchesGoldenFile('storage_meter_calculating_${b.name}.png'),
      );
    });

    for (final (name, used, trash) in [
      ('warning', 46 * mb, 0),
      ('over', 52 * mb, 8 * mb),
    ]) {
      testWidgets('storage banner $name ${b.name}', (tester) async {
        h = storageHarness(storage: FakeStorage.used(used, trashBytes: trash));
        await pumpWithShell(
          tester,
          h,
          Align(
            alignment: Alignment.topCenter,
            child: StorageBanner(services: h.services),
          ),
          brightness: b,
          size: const Size(900, 80),
        );
        await expectLater(
          find.byType(StorageBanner),
          matchesGoldenFile('storage_banner_${name}_${b.name}.png'),
        );
      });
    }

    for (final MapEntry(key: name, value: p) in problems.entries) {
      testWidgets('quota dialog $name ${b.name}', (tester) async {
        h = storageHarness(storage: FakeStorage.used(49 * mb));
        await pumpWithShell(
          tester,
          h,
          const SizedBox(),
          brightness: b,
          // 360 px (suite DoD); stacked buttons.
          size: const Size(360, 560),
        );
        h.services.quotaErrors.show(p).ignore();
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const ValueKey('dialog.quota')),
          matchesGoldenFile('quota_dialog_${name}_${b.name}.png'),
        );
      });
    }
  }
}
