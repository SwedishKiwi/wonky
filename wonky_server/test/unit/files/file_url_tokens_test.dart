import 'package:clock/clock.dart';
import 'package:serverpod/serverpod.dart' show UuidValue;
import 'package:test/test.dart';
import 'package:wonky_server/src/platform/files/file_url_tokens.dart';

void main() {
  final file = UuidValue.fromString('0190a0e0-0000-7000-8000-000000000001');
  final other = UuidValue.fromString('0190a0e0-0000-7000-8000-000000000002');
  final t0 = DateTime.utc(2026, 10, 15, 12);

  setUp(() => FileUrlTokens.keyOverride = List.filled(32, 7));
  tearDown(() => FileUrlTokens.keyOverride = null);

  group('Given a download token', () {
    late String token;
    setUp(() {
      token = withClock(
        Clock.fixed(t0),
        () => FileUrlTokens.issue(
          purpose: FileUrlPurpose.download,
          fileUuid: file,
          userId: 42,
        ),
      );
    });

    test('when verifying it within 15 minutes then it grants the user', () {
      final grant = withClock(
        Clock.fixed(t0.add(const Duration(minutes: 14))),
        () => FileUrlTokens.verify(
          token,
          purpose: FileUrlPurpose.download,
          fileUuid: file,
        ),
      );

      expect(grant?.userId, 42);
    });

    test('when verifying it after 15 minutes then it is refused', () {
      final grant = withClock(
        Clock.fixed(t0.add(const Duration(minutes: 15))),
        () => FileUrlTokens.verify(
          token,
          purpose: FileUrlPurpose.download,
          fileUuid: file,
        ),
      );

      expect(grant, isNull);
    });

    test('when used for another file or purpose then it is refused', () {
      withClock(Clock.fixed(t0), () {
        expect(
          FileUrlTokens.verify(
            token,
            purpose: FileUrlPurpose.download,
            fileUuid: other,
          ),
          isNull,
        );
        expect(
          FileUrlTokens.verify(
            token,
            purpose: FileUrlPurpose.upload,
            fileUuid: file,
          ),
          isNull,
        );
      });
    });

    test('when the payload or signature is tampered then it is refused', () {
      final parts = token.split('.');
      final forged = '${parts[0]}x.${parts[1]}';
      final otherKey = withClock(Clock.fixed(t0), () {
        FileUrlTokens.keyOverride = List.filled(32, 8);
        return FileUrlTokens.verify(
          token,
          purpose: FileUrlPurpose.download,
          fileUuid: file,
        );
      });
      FileUrlTokens.keyOverride = List.filled(32, 7);

      withClock(Clock.fixed(t0), () {
        expect(
          FileUrlTokens.verify(
            forged,
            purpose: FileUrlPurpose.download,
            fileUuid: file,
          ),
          isNull,
        );
        expect(
          FileUrlTokens.verify(
            'garbage',
            purpose: FileUrlPurpose.download,
            fileUuid: file,
          ),
          isNull,
        );
      });
      expect(otherKey, isNull);
    });
  });

  test('when issuing an upload token then it carries the declared size', () {
    final grant = withClock(Clock.fixed(t0), () {
      final token = FileUrlTokens.issue(
        purpose: FileUrlPurpose.upload,
        fileUuid: file,
        userId: 7,
        sizeBytes: 1234,
      );
      return FileUrlTokens.verify(
        token,
        purpose: FileUrlPurpose.upload,
        fileUuid: file,
      );
    });

    expect(grant?.sizeBytes, 1234);
  });
}
