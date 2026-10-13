import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shad/shad.dart';
import 'package:wonky_client/wonky_client.dart';
import 'package:wonky_ui/wonky_ui.dart';

import '../data/api.dart';
import '../drive/drive_format.dart';
import '../l10n/wonky_app_localizations.dart';
import '../shell/shell_services.dart';
import 'activity_dashboard_controller.dart';
import 'activity_feed.dart';
import 'trend_chart.dart';

/// Stable keys of the activity dashboard (specs/15 §7).
abstract final class ActivityDashboardKeys {
  static const dialog = ValueKey<String>('activity.dashboard');
  static const period = ValueKey<String>('activity.dashboard.period');
  static const tabs = ValueKey<String>('activity.dashboard.tabs');
  static const viewTrend = ValueKey<String>('activity.dashboard.viewTrend');
  static const commentTrend = ValueKey<String>(
    'activity.dashboard.commentTrend',
  );
  static const viewHistory = ValueKey<String>(
    'activity.dashboard.showViewHistory',
  );
  static ValueKey<String> viewer(int userId) =>
      ValueKey<String>('activity.dashboard.viewer.$userId');
}

enum ActivityDashboardTab { viewers, trends, activity }

/// Tools › Activity dashboard (suite 07 §6).
Future<void> showActivityDashboardDialog(
  BuildContext context,
  ShellServices s,
  DriveItemView item,
) {
  final l = WonkyAppLocalizations.of(context);
  return showShadDialog<void>(
    context: context,
    builder: (context) => ShadDialog(
      key: ActivityDashboardKeys.dialog,
      title: Text(l.activityTitle(item.name)),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.actionClose),
        ),
      ],
      child: SizedBox(
        width: 560,
        height: 480,
        child: ActivityDashboardView(services: s, item: item),
      ),
    ),
  );
}

/// The dashboard body (public for widget tests): period selector, tabs
/// (Viewers / Trends / Activity) and the "Show my view history" toggle.
class ActivityDashboardView extends StatefulWidget {
  const ActivityDashboardView({
    super.key,
    required this.services,
    required this.item,
  });

  final ShellServices services;
  final DriveItemView item;

  @override
  State<ActivityDashboardView> createState() => _ActivityDashboardViewState();
}

class _ActivityDashboardViewState extends State<ActivityDashboardView> {
  late final ActivityDashboardController _ctl = ActivityDashboardController(
    widget.services.repositories.activity,
    widget.item.uuid,
  );
  ActivityDashboardTab? _tab;

  @override
  void initState() {
    super.initState();
    unawaited(_ctl.load());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    return ListenableBuilder(
      listenable: _ctl,
      builder: (context, _) {
        final d = _ctl.dashboard;
        final tabs = [
          if (d == null || d.canSeeViewers) ActivityDashboardTab.viewers,
          ActivityDashboardTab.trends,
          ActivityDashboardTab.activity,
        ];
        final tab = _tab != null && tabs.contains(_tab) ? _tab! : tabs.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ShadTabs<ActivityDashboardTab>(
                    key: ActivityDashboardKeys.tabs,
                    value: tab,
                    onChanged: (t) => setState(() => _tab = t),
                    tabs: [
                      for (final t in tabs)
                        ShadTab(
                          key: ValueKey<String>(
                            'activity.dashboard.tab.${t.name}',
                          ),
                          value: t,
                          child: Text(switch (t) {
                            ActivityDashboardTab.viewers =>
                              l.activityTabViewers,
                            ActivityDashboardTab.trends => l.activityTabTrends,
                            ActivityDashboardTab.activity =>
                              l.activityTabActivity,
                          }),
                        ),
                    ],
                  ),
                ),
                if (tab != ActivityDashboardTab.activity) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: ShadSelect<int>(
                      key: ActivityDashboardKeys.period,
                      initialValue: _ctl.days,
                      options: [
                        for (final p in ActivityDashboardController.periods)
                          ShadOption(
                            value: p,
                            child: Text(l.activityPeriodDays(p)),
                          ),
                      ],
                      selectedOptionBuilder: (context, v) =>
                          Text(l.activityPeriodDays(v)),
                      onChanged: (v) {
                        if (v != null) unawaited(_ctl.setDays(v));
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (tab) {
                ActivityDashboardTab.activity => SingleChildScrollView(
                  child: ActivityFeed(
                    services: widget.services,
                    itemUuid: widget.item.uuid,
                    pageSize: 50,
                  ),
                ),
                _ when d == null && _ctl.error != null => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        errorMessage(_ctl.error!),
                        style: theme.textTheme.muted,
                      ),
                      const SizedBox(height: 8),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: _ctl.load,
                        child: Text(l.actionRetry),
                      ),
                    ],
                  ),
                ),
                _ when d == null => const Center(child: ShadSpinner()),
                ActivityDashboardTab.viewers => _ViewersList(dashboard: d),
                ActivityDashboardTab.trends => _Trends(dashboard: d),
              },
            ),
            const ShadSeparator.horizontal(),
            ShadSwitch(
              key: ActivityDashboardKeys.viewHistory,
              value: _ctl.showViewHistory,
              enabled: !_ctl.savingSetting,
              onChanged: _ctl.setShowViewHistory,
              label: Text(l.activityShowMyViewHistory),
              sublabel: Text(
                _ctl.settingError != null
                    ? errorMessage(_ctl.settingError!)
                    : l.activityShowMyViewHistoryHint,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ViewersList extends StatelessWidget {
  const _ViewersList({required this.dashboard});

  final ActivityDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    final d = dashboard;
    final hidden = d.hiddenViewers > 0
        ? Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l.activityViewersHidden(d.hiddenViewers),
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          )
        : null;
    if (d.viewers.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          WonkyEmptyState(
            illustration: EmptyIllustration.search,
            title: l.activityViewersEmpty(d.days),
            size: 72,
          ),
          ?hidden,
        ],
      );
    }
    return ListView(
      children: [
        Text(
          l.activityViewersCount(d.viewers.length, d.days),
          style: theme.textTheme.muted.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 6),
        for (final v in d.viewers)
          Padding(
            key: ActivityDashboardKeys.viewer(v.user.id),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: MergeSemantics(
              child: Row(
                children: [
                  WonkyAvatar(
                    name: v.user.displayName,
                    color: parseHexColor(v.user.avatarColor),
                    imageUrl: v.user.avatarUrl,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.user.displayName,
                          style: theme.textTheme.small,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          v.user.email,
                          style: theme.textTheme.muted.copyWith(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        l.activityLastViewed(timeAgo(l, v.lastViewedAt)),
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      Text(
                        l.activityViewCount(v.views),
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ?hidden,
      ],
    );
  }
}

class _Trends extends StatelessWidget {
  const _Trends({required this.dashboard});

  final ActivityDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l = WonkyAppLocalizations.of(context);
    final theme = ShadTheme.of(context);
    Widget section(
      Key key,
      String title,
      String hint,
      List<ActivityTrendPoint> points,
      Color? color,
    ) {
      final total = points.fold<int>(0, (s, p) => s + p.count);
      final peak = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Text('$total', style: theme.textTheme.large),
            ],
          ),
          Text(hint, style: theme.textTheme.muted.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          TrendChart(
            key: key,
            points: points,
            color: color,
            height: 90,
            semanticLabel: l.activityChartSummary(title, total, peak),
          ),
        ],
      );
    }

    return ListView(
      children: [
        section(
          ActivityDashboardKeys.viewTrend,
          l.activityViewTrend,
          l.activityViewTrendHint,
          dashboard.viewTrend,
          null,
        ),
        const SizedBox(height: 20),
        section(
          ActivityDashboardKeys.commentTrend,
          l.activityCommentTrend,
          l.activityCommentTrendHint,
          dashboard.commentTrend,
          theme.colorScheme.info,
        ),
      ],
    );
  }
}
