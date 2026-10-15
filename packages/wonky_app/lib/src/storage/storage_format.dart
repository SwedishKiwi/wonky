import 'package:wonky_core/files.dart' show formatStorageBytes;

/// Bytes as shown in meters, banners and dialogs (Drive 03 §3): binary
/// units labeled KB/MB, one decimal below 100 ("12.3 MB"), "0 bytes".
String storageBytes(int bytes) => formatStorageBytes(bytes);

/// The quota, which is always a whole number ("50 MB", not "50.0 MB").
String storageQuota(int bytes) =>
    formatStorageBytes(bytes).replaceFirst(RegExp(r'\.0 '), ' ');
