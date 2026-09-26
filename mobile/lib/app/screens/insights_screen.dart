import 'package:flutter/material.dart';

import '../../api/session_controller.dart';
import '../l10n/app_localizations.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = SessionScope.of(context);
    final snapshots = session.recentVitals;
    return RefreshIndicator(
      onRefresh: session.refreshHistory,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l.t('trends'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('saved_history'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${l.t('workouts_saved')}: ${session.savedWorkouts.length}',
                  ),
                  Text(
                    '${l.t('sleep_records_saved')}: ${session.savedSleepObservations.length}',
                  ),
                  if (session.averageHeartRate != null)
                    Text(
                      '${l.t('avg_last_10_hr')}: '
                      '${session.averageHeartRate!.toStringAsFixed(1)}${l.t('bpm')}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.t('saved_measurements'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (snapshots.isEmpty)
            Text(l.t('no_saved_measurements'))
          else
            for (final snapshot in snapshots)
              _SnapshotCard(snapshot: snapshot, l: l),
        ],
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot, required this.l});

  final Map<String, dynamic> snapshot;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final when = DateTime.tryParse(
      snapshot['measured_at']?.toString() ?? '',
    )?.toLocal();
    final pieces = <String>[
      if (snapshot['heart_rate'] != null)
        '${l.t('heart_rate')}: ${snapshot['heart_rate']}${l.t('bpm')}',
      if (snapshot['spo2'] != null) 'SpO₂: ${snapshot['spo2']}%',
      if (snapshot['temperature_c'] != null)
        '${l.t('temp_label')}: ${snapshot['temperature_c']} °C',
      if (snapshot['steps'] != null) '${l.t('steps')}: ${snapshot['steps']}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              when == null
                  ? '—'
                  : '${MaterialLocalizations.of(context).formatMediumDate(when)} '
                        '${TimeOfDay.fromDateTime(when).format(context)}',
            ),
            const SizedBox(height: 4),
            Text(pieces.join(' · ')),
          ],
        ),
      ),
    );
  }
}
