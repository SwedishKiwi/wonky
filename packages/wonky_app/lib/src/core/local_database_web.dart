/// On the web the database name is the OPFS / IndexedDB key.
Future<String> databasePath(String fileName, String? directory) async =>
    fileName;

/// Database deletion is unsupported on the web; callers truncate tables.
Future<void> deleteDatabase(String fileName, String? directory) async {}
