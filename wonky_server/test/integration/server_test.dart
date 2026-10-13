import 'package:clock/clock.dart';
import 'package:serverpod/protocol.dart' as sp show FutureCallEntry;
import 'package:test/test.dart';
import 'package:wonky_server/server.dart' show scheduleMaintenanceJobs;
import 'package:wonky_server/src/generated/future_calls.dart';

import '../support/wonky_serverpod.dart';

const _jobs = [
  'wonky.captureVersions',
  'wonky.sendDigests',
  'wonky.cleanupFiles',
  'wonky.daily',
];

/// Every instance schedules the recurring jobs at start (specs/13 §4).
void main() {
  withWonkyServerpod('Given several instances starting', (
    sessionBuilder,
    endpoints,
  ) {
    /// Upcoming runs per job identifier.
    Future<Map<String, int>> upcoming() async {
      final entries = await sp.FutureCallEntry.db.find(
        sessionBuilder.build(),
        where: (t) => t.identifier.inSet(_jobs.toSet()),
      );
      final now = clock.now().toUtc();
      return {
        for (final id in _jobs)
          id: entries
              .where((e) => e.identifier == id && e.time.isAfter(now))
              .length,
      };
    }

    test(
      'when they schedule the maintenance jobs at the same time then each '
      'job is scheduled once',
      () async {
        final pod = sessionBuilder.build().serverpod;

        await Future.wait([
          scheduleMaintenanceJobs(pod),
          scheduleMaintenanceJobs(pod),
          scheduleMaintenanceJobs(pod),
        ]);

        expect(await upcoming(), {for (final id in _jobs) id: 1});
      },
    );

    test(
      'when a job was scheduled twice then the next start repairs it',
      () async {
        final pod = sessionBuilder.build().serverpod;
        await scheduleMaintenanceJobs(pod);
        await pod.futureCalls
            .callRecurring(identifier: 'wonky.daily')
            .cron('17 3 * * *')
            .maintenance
            .daily();

        await scheduleMaintenanceJobs(pod);

        expect(await upcoming(), {for (final id in _jobs) id: 1});
      },
    );
  });
}
