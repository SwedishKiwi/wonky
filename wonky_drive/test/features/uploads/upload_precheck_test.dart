import 'package:flutter_test/flutter_test.dart';
import 'package:wonky_app/testing.dart';
import 'package:wonky_drive/features/uploads/upload_precheck.dart';
import 'package:wonky_drive/features/uploads/upload_queue.dart';

import '../../support/upload_fakes.dart';

/// The client pre-checks of Drive 02 §3.2 (AC-D2.1 client part).
void main() {
  const mb = 1024 * 1024;
  List<String> names(List<UploadFile> f) => [for (final x in f) x.name];

  group('Given files and a quota', () {
    final files = [
      textFile('a.bin', 1024),
      textFile('b.bin', 10 * mb),
      textFile('c.bin', 40 * mb),
    ];

    for (final (available, expected) in [
      (60 * mb, ['a.bin', 'b.bin', 'c.bin']),
      (50 * mb, ['a.bin', 'b.bin']),
      (41 * mb, ['a.bin', 'b.bin']),
      (5 * mb, ['a.bin']),
      (512, <String>[]),
    ]) {
      test('when $available bytes are left then the files that fit are '
          '$expected', () {
        expect(names(filesThatFit(files, available)), expected);
      });
    }

    test('when the smallest files fit then they are kept in the user\'s '
        'order', () {
      final mixed = [
        textFile('big.bin', 30 * mb),
        textFile('small2.bin', 2 * mb),
        textFile('small1.bin', mb),
      ];

      expect(names(filesThatFit(mixed, 4 * mb)), ['small2.bin', 'small1.bin']);
    });

    test('when 1 KB, 10 MB and 40 MB are uploaded with 50 MB free then the '
        'third doesn\'t fit (AC-D2.1)', () {
      final plan = UploadPlan.of(
        files,
        maxFileBytes: 50 * mb,
        usage: FakeStorage.usageOf(0),
      );

      expect(plan.fitsQuota, isFalse);
      expect(names(plan.fitting), ['a.bin', 'b.bin']);
      expect(plan.neededBytes, 1024 + 50 * mb);
      expect(plan.availableBytes, 50 * mb);
    });

    test('when uploads are still waiting offline then their bytes count '
        'against the cached usage', () {
      final plan = UploadPlan.of(
        [textFile('a.bin', 10 * mb)],
        maxFileBytes: 50 * mb,
        usage: FakeStorage.usageOf(30 * mb),
        pendingBytes: 15 * mb,
      );

      expect(plan.fitsQuota, isFalse);
      expect(plan.availableBytes, 5 * mb);
    });

    test('when the usage is unknown or still calculating then everything '
        'is allowed (the server decides)', () {
      for (final usage in [
        null,
        FakeStorage.usageOf(50 * mb, calculating: true),
      ]) {
        final plan = UploadPlan.of(files, maxFileBytes: 50 * mb, usage: usage);
        expect(plan.fitsQuota, isTrue);
      }
    });
  });

  group('Given the size limit and existing names', () {
    test('when a file is larger than the limit then it is rejected and '
        'not counted', () {
      final plan = UploadPlan.of(
        [textFile('photo.raw', 51 * mb), textFile('ok.txt', 10)],
        maxFileBytes: 50 * mb,
        usage: FakeStorage.usageOf(0),
      );

      expect(names(plan.tooLarge), ['photo.raw']);
      expect(names(plan.files), ['ok.txt']);
      expect(plan.neededBytes, 10);
    });

    test('when a name exists in the folder in another case then it is a '
        'conflict', () {
      final plan = UploadPlan.of(
        [textFile('Notes.PDF'), textFile('new.txt')],
        maxFileBytes: 50 * mb,
        existingNames: {'notes.pdf'},
      );

      expect(names(plan.conflicts), ['Notes.PDF']);
    });

    test('when a file is empty then it is allowed', () {
      final plan = UploadPlan.of(
        [textFile('empty.txt', 0)],
        maxFileBytes: 50 * mb,
        usage: FakeStorage.usageOf(50 * mb),
      );

      expect(plan.fitsQuota, isTrue);
    });
  });
}
