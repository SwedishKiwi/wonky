import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';

import '../l10n/wonky_app_localizations.dart';

/// Icon of a drive item kind.
IconData kindIcon(DriveItemKind kind) => switch (kind) {
  DriveItemKind.folder => LucideIcons.folder,
  DriveItemKind.document => LucideIcons.fileText,
  DriveItemKind.spreadsheet => LucideIcons.sheet,
};

/// Brand color of a kind (Write blue, Sheets green, folders muted).
Color kindColor(DriveItemKind kind, ShadColorScheme c) => switch (kind) {
  DriveItemKind.folder => c.mutedForeground,
  DriveItemKind.document => const Color(0xff2563eb),
  DriveItemKind.spreadsheet => const Color(0xff16a34a),
};

String describeKind(WonkyAppLocalizations l, DriveItemKind kind) => switch (kind) {
  DriveItemKind.folder => l.kindFolder,
  DriveItemKind.document => l.kindDocument,
  DriveItemKind.spreadsheet => l.kindSpreadsheet,
};

/// "10:42", "Yesterday", "Mar 3", "Mar 3, 2024" (suite 05 §3.1).
String relativeDate(WonkyAppLocalizations l, DateTime t, {DateTime? now, String? locale}) {
  final n = (now ?? clock.now()).toLocal();
  final d = t.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return intl.DateFormat.jm(locale).format(d);
  if (diff == 1) return l.dateYesterday;
  if (d.year == n.year) return intl.DateFormat.MMMd(locale).format(d);
  return intl.DateFormat.yMMMd(locale).format(d);
}

/// "Just now", "5 min ago", "3 h ago", or a date (comments, notifications).
String timeAgo(WonkyAppLocalizations l, DateTime t, {DateTime? now}) {
  final n = now ?? clock.now();
  final diff = n.difference(t);
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  return relativeDate(l, t, now: n);
}

/// Groups for the Recent view.
enum RecentGroup { today, yesterday, thisWeek, earlier }

RecentGroup recentGroupOf(DateTime t, {DateTime? now}) {
  final n = (now ?? clock.now()).toLocal();
  final d = t.toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final days = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (days <= 0) return RecentGroup.today;
  if (days == 1) return RecentGroup.yesterday;
  if (days < n.weekday) return RecentGroup.thisWeek;
  return RecentGroup.earlier;
}

String recentGroupLabel(WonkyAppLocalizations l, RecentGroup g) => switch (g) {
  RecentGroup.today => l.groupToday,
  RecentGroup.yesterday => l.groupYesterday,
  RecentGroup.thisWeek => l.groupThisWeek,
  RecentGroup.earlier => l.groupEarlier,
};

/// "12 KB", "3.4 MB".
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v < 10 ? v.toStringAsFixed(1) : v.round()} ${units[i]}';
}

/// Parses a `#rrggbb` avatar color.
Color parseHexColor(String hex, {Color fallback = const Color(0xff71717a)}) {
  final t = hex.replaceFirst('#', '');
  final v = int.tryParse(t.length == 6 ? 'ff$t' : t, radix: 16);
  return v == null ? fallback : Color(v);
}
