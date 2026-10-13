/// Pure-Dart id helpers of Wonky Sheets (specs/wonky_sheets/02 §2): deterministic
/// UUIDv5 ids, fractional indexing and the 22-character base-62 UUID codec.
///
/// This library has no Serverpod imports, so `wonky_sheets_core` and any pure
/// Dart code can use it without pulling in the generated models.
library;

export 'src/ids/base62.dart' show Base62Uuid, base62Digits, base62Value;
export 'src/ids/fractional_index.dart' show FractionalIndex;
export 'src/ids/sheets_ids.dart'
    show
        IdGenerator,
        SeededIdGenerator,
        SequentialIdGenerator,
        SheetsIds,
        UuidV7IdGenerator;
