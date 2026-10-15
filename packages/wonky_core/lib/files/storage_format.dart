/// Bytes as users see them (Drive 03 §3): binary units labeled KB/MB/GB,
/// one decimal below 100 ("12.3 MB", "2.0 MB"), none from 100 ("820 KB"),
/// and "0 bytes" / "512 bytes" below one kilobyte.
String formatStorageBytes(int bytes) {
  if (bytes <= 0) return '0 bytes';
  if (bytes < 1024) return bytes == 1 ? '1 byte' : '$bytes bytes';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value < 100
      ? value.toStringAsFixed(1)
      : value.round().toString();
  return '$text ${units[unit]}';
}
