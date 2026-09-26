import 'package:flutter/material.dart';

import '../../api/session_controller.dart';
import '../../band/workout_model.dart';
import '../l10n/app_localizations.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = SessionScope.of(context);
    final snapshots = session.recentVitals;
    return RefreshIndicator(
      onRefresh: session.synchronize,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l.t('trends'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (session.pendingUploadCount > 0) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${l.t('pending_uploads')}: ${session.pendingUploadCount}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await session.synchronize();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.t('sync_failed'))),
                            );
                          }
                        }
                      },
                      child: Text(l.t('retry')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
          const SizedBox(height: 20),
          Text(
            l.t('workouts_saved'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (session.savedWorkouts.isEmpty)
            Text(l.t('no_workouts'))
          else
            for (final workout in session.savedWorkouts.take(5))
              _WorkoutCard(summary: workout, l: l),
          const SizedBox(height: 20),
          Text(
            l.t('saved_sleep'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (session.savedSleepObservations.isEmpty)
            Text(l.t('no_sleep_data'))
          else
            for (final observation in session.savedSleepObservations.take(5))
              _SleepCard(observation: observation, l: l),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.summary, required this.l});

  final WorkoutSummary summary;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final label = l.t('workout_type_${summary.type.name}');
    final name = label.startsWith('workout_type_') ? summary.type.name : label;
    final minutes = (summary.durationSeconds / 60).round();
    final details = <String>[
      '$minutes ${l.t('duration_minutes')}',
      if (summary.averageHeartRate != null)
        '${l.t('workout_avg_hr')}: ${summary.averageHeartRate}${l.t('bpm')}',
    ];
    return Card(
      child: ListTile(
        title: Text(name),
        subtitle: Text(
          [
            MaterialLocalizations.of(
              context,
            ).formatMediumDate(summary.startTime),
            ...details,
          ].join(' · '),
        ),
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  const _SleepCard({required this.observation, required this.l});

  final Map<String, dynamic> observation;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final endedAt = DateTime.tryParse(
      observation['ended_at']?.toString() ?? '',
    )?.toLocal();
    final minutes = (observation['observed_minutes'] as num?)?.toInt();
    return Card(
      child: ListTile(
        title: Text(
          endedAt == null
              ? '—'
              : MaterialLocalizations.of(context).formatMediumDate(endedAt),
        ),
        subtitle: Text(
          [
            if (minutes != null) '$minutes ${l.t('minutes_observed')}',
            if (observation['stages_validated'] != true)
              l.t('stages_unverified'),
          ].join(' · '),
        ),
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
