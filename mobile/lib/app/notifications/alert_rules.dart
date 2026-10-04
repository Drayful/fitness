/// Notification categories the user can switch on and off (TZ §31).
enum AlertCategory {
  lowBattery(defaultOn: true),
  bandAway(defaultOn: true),
  highHeartRate(defaultOn: true),
  sleepShortage(defaultOn: true),
  staleSync(defaultOn: true),
  syncComplete(defaultOn: false);

  const AlertCategory({required this.defaultOn});

  /// Whether the category is on before the user touches the setting.
  /// Sync-complete would fire every 30 minutes, so it starts off.
  final bool defaultOn;
}

/// When to raise each alert, kept free of plugins and widgets so it can be
/// tested. Each rule fires once per episode and re-arms only after the
/// condition clears (or a cooldown passes), to avoid notification spam.
class AlertRules {
  AlertRules({required this.notify, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  /// Called with the category and template parameters for the text.
  final void Function(AlertCategory category, Map<String, Object> params)
  notify;
  final DateTime Function() _now;

  static const lowBatteryPercent = 20;
  static const batteryRearmPercent = 30;
  static const bandAwayAfter = Duration(minutes: 30);
  static const highHeartRateBpm = 120;
  static const highHeartRateReadings = 3;
  static const highHeartRateCooldown = Duration(hours: 1);
  static const shortSleepMinutes = 6 * 60;

  bool _batteryArmed = true;
  DateTime? _awaySince;
  bool _awayNotified = false;
  int _highReadings = 0;
  DateTime? _lastHighHeartRate;
  DateTime? _lastShortNight;
  DateTime? _staleNotifiedFor;
  int _lastSyncCount = 0;

  void onBattery(int? percent) {
    if (percent == null) return;
    if (percent >= batteryRearmPercent) {
      _batteryArmed = true;
    } else if (percent < lowBatteryPercent && _batteryArmed) {
      _batteryArmed = false;
      notify(AlertCategory.lowBattery, {'n': percent});
    }
  }

  /// Watch remembered but out of reach for [bandAwayAfter].
  void onConnection({required bool connected, required bool remembered}) {
    if (connected || !remembered) {
      _awaySince = null;
      _awayNotified = false;
      return;
    }
    final now = _now();
    _awaySince ??= now;
    if (!_awayNotified && now.difference(_awaySince!) >= bandAwayAfter) {
      _awayNotified = true;
      notify(AlertCategory.bandAway, {});
    }
  }

  /// Raised heart rate outside a workout: [highHeartRateReadings] live
  /// readings in a row at or above [highHeartRateBpm], at most hourly.
  void onLiveHeartRate(int? bpm, {required bool workoutActive}) {
    if (bpm == null || workoutActive || bpm < highHeartRateBpm) {
      _highReadings = 0;
      return;
    }
    _highReadings++;
    final now = _now();
    final last = _lastHighHeartRate;
    if (_highReadings >= highHeartRateReadings &&
        (last == null || now.difference(last) >= highHeartRateCooldown)) {
      _lastHighHeartRate = now;
      _highReadings = 0;
      notify(AlertCategory.highHeartRate, {'bpm': bpm});
    }
  }

  /// Last night shorter than [shortSleepMinutes]; once per night.
  void onSleep({required DateTime? bedTime, required int asleepMinutes}) {
    if (bedTime == null || asleepMinutes <= 0) return;
    if (asleepMinutes >= shortSleepMinutes) return;
    if (_lastShortNight == bedTime) return;
    if (_now().difference(bedTime) > const Duration(hours: 20)) return;
    _lastShortNight = bedTime;
    notify(AlertCategory.sleepShortage, {
      'h': asleepMinutes ~/ 60,
      'm': asleepMinutes % 60,
    });
  }

  /// No sync for three days (Spec-06); once per last-sync timestamp.
  void onStaleSync({required bool stale, required DateTime? lastSyncAt}) {
    if (!stale || lastSyncAt == null || _staleNotifiedFor == lastSyncAt) {
      return;
    }
    _staleNotifiedFor = lastSyncAt;
    notify(AlertCategory.staleSync, {
      'd': _now().difference(lastSyncAt).inDays,
    });
  }

  void onHistorySynced(int syncCount) {
    if (syncCount <= _lastSyncCount) return;
    final first = _lastSyncCount == 0;
    _lastSyncCount = syncCount;
    if (!first) notify(AlertCategory.syncComplete, {});
  }
}
