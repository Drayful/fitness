import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/session_controller.dart';
import 'app/auth_gate.dart';
import 'app/l10n/app_localizations.dart';
import 'app/l10n/locale_controller.dart';
import 'app/notifications/alert_rules.dart';
import 'app/notifications/notification_service.dart';
import 'app/theme.dart';
import 'app/theme_controller.dart';
import 'band/v8_band_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Before anything touches Bluetooth, or iOS keeps its "Turn on Bluetooth"
  // alert enabled for the whole run.
  await V8BandService.applyBleOptions();
  runApp(const FitnessApp());
}

class FitnessApp extends StatefulWidget {
  const FitnessApp({super.key});

  @override
  State<FitnessApp> createState() => _FitnessAppState();
}

class _FitnessAppState extends State<FitnessApp> with WidgetsBindingObserver {
  final _bandService = V8BandService();
  final _localeController = LocaleController();
  final _themeController = ThemeController();
  final _session = SessionController();
  DateTime? _lastHeartRateUploadAt;
  String? _lastSleepUploadId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bandService.addListener(_saveVitals);
    _bandService.addListener(_saveSleep);
    _session.addListener(_saveSleep);
    _bandService.addListener(_saveHistory);
    _session.addListener(_saveHistory);
    _session.addListener(_pushBodyProfile);
    unawaited(_localeController.load());
    unawaited(_themeController.load());
    _session.load();
    // Reconnect to last session's watch instead of making the user rescan.
    unawaited(_bandService.restoreLastDevice());
    unawaited(_bandService.loadAlarm());
    unawaited(_notifications.init());
    _bandService.addListener(_evaluateAlerts);
    _startServerSync();
  }

  // ── Notifications (TZ §31) ──
  final _notifications = NotificationService();
  late final _alertRules = AlertRules(notify: _onAlert);
  DateTime? _lastAlertVitalsAt;

  void _onAlert(AlertCategory category, Map<String, Object> params) {
    final l = AppLocalizations(_localeController.locale);
    var body = l.t('notif_${category.name}_body');
    params.forEach((k, v) => body = body.replaceAll('{$k}', '$v'));
    unawaited(
      _notifications.show(category, l.t('notif_${category.name}_title'), body),
    );
  }

  /// Feeds band state into the alert rules. Also run from the periodic
  /// timer, because "watch away for 30 min" needs time to pass.
  void _evaluateAlerts() {
    final band = _bandService;
    _alertRules.onBattery(band.deviceInfo?.batteryPercent);
    _alertRules.onConnection(
      connected: band.isConnected,
      remembered: band.hasRememberedDevice,
    );
    // Only count genuinely new live readings, not every unrelated update.
    if (band.liveVitalsAt != null && band.liveVitalsAt != _lastAlertVitalsAt) {
      _lastAlertVitalsAt = band.liveVitalsAt;
      _alertRules.onLiveHeartRate(
        band.liveVitals?.heartRate,
        workoutActive: band.isWorkoutActive,
      );
    }
    final sleep = band.sleepSummary;
    if (sleep != null && sleep.hasData) {
      _alertRules.onSleep(
        bedTime: sleep.bedTime,
        asleepMinutes: sleep.hasValidatedStages
            ? sleep.sleepMinutes
            : sleep.observedMinutes,
      );
    }
    _alertRules.onStaleSync(stale: band.isSyncStale, lastSyncAt: band.lastSyncAt);
    _alertRules.onHistorySynced(band.historySyncCount);
  }

  /// Server-side history (averages, saved workouts, sleep) only changed on
  /// launch before; poll it while the app is in the foreground.
  Timer? _serverSyncTimer;

  void _startServerSync() {
    _serverSyncTimer?.cancel();
    _serverSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (_session.isAuthenticated) {
        unawaited(_session.synchronize().catchError((_) {}));
      }
      _evaluateAlerts();
    });
  }

  void _saveVitals() {
    final vitals = _bandService.liveVitals;
    final measuredAt = _bandService.liveVitalsAt;
    if (!_session.isAuthenticated ||
        !_bandService.variantConfirmed ||
        vitals == null ||
        measuredAt == null) {
      return;
    }
    if (_lastHeartRateUploadAt != null &&
        measuredAt.difference(_lastHeartRateUploadAt!) <
            const Duration(seconds: 30)) {
      return;
    }
    _lastHeartRateUploadAt = measuredAt;
    unawaited(
      _session
          .uploadVitals(
            vitals,
            measuredAt,
            model: _bandService.variantConfirmed ? _bandService.variant : null,
          )
          .catchError((_) {}),
    );
  }

  /// Upload band memory after each history sync (TZ §5). A failed upload
  /// is retried with the next sync; the server ignores duplicates.
  int _uploadedHistorySync = 0;

  void _pushBodyProfile() {
    unawaited(_bandService.setBodyProfile(_session.bodyProfile));
    unawaited(_bandService.setStepGoal(_session.stepGoal));
  }

  void _saveHistory() {
    final count = _bandService.historySyncCount;
    if (count == 0 ||
        count == _uploadedHistorySync ||
        !_session.isAuthenticated) {
      return;
    }
    _uploadedHistorySync = count;
    unawaited(
      _session
          .uploadBandHistory(
            _bandService.historySamples,
            _bandService.dailyActivity,
            model: _bandService.variantConfirmed ? _bandService.variant : null,
          )
          .catchError((_) {}),
    );
  }

  void _saveSleep() {
    final summary = _bandService.sleepSummary;
    if (!_session.isAuthenticated ||
        summary == null ||
        !summary.hasData ||
        summary.bedTime == null) {
      return;
    }
    final id =
        '${_session.userEmail}-${summary.bedTime!.toUtc().microsecondsSinceEpoch}';
    if (id == _lastSleepUploadId) return;
    _lastSleepUploadId = id;
    unawaited(
      _session
          .uploadSleep(summary, records: _bandService.sleepRecords)
          .catchError((_) {}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serverSyncTimer?.cancel();
    _bandService.removeListener(_saveVitals);
    _bandService.removeListener(_evaluateAlerts);
    _bandService.removeListener(_saveSleep);
    _session.removeListener(_saveSleep);
    _bandService.removeListener(_saveHistory);
    _session.removeListener(_saveHistory);
    _session.removeListener(_pushBodyProfile);
    _bandService.dispose();
    _localeController.dispose();
    _themeController.dispose();
    _notifications.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startServerSync();
      unawaited(_bandService.onAppResumed().catchError((_) {}));
      if (_session.isAuthenticated) {
        unawaited(_session.synchronize().catchError((_) {}));
      }
    } else if (state == AppLifecycleState.paused) {
      _serverSyncTimer?.cancel();
    } else if (state == AppLifecycleState.detached) {
      unawaited(_bandService.disconnect());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BandServiceScope(
      service: _bandService,
      child: SessionScope(
        controller: _session,
        child: LocaleScope(
          controller: _localeController,
          child: ThemeScope(
            controller: _themeController,
            child: NotificationScope(
            service: _notifications,
            child: AnimatedBuilder(
            animation: Listenable.merge([_localeController, _themeController]),
            builder: (context, _) {
              return MaterialApp(
                title: 'Fitness',
                themeMode: _themeController.mode,
                debugShowCheckedModeBanner: false,
                theme: _lightTheme,
                darkTheme: _darkTheme,
                // Point the AppTheme shorthands at the palette actually in use.
                builder: (context, child) {
                  AppTheme.sync(Theme.of(context).brightness);
                  return child!;
                },
                locale: _localeController.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const AuthGate(),
              );
            },
          ),
          ),
          ),
        ),
      ),
    );
  }

  // Built once: ThemeData construction is not free and the palettes are const.
  static final _lightTheme = AppTheme.light();
  static final _darkTheme = AppTheme.dark();
}

class BandServiceScope extends InheritedWidget {
  const BandServiceScope({
    super.key,
    required this.service,
    required super.child,
  });

  final V8BandService service;

  static V8BandService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BandServiceScope>();
    assert(scope != null, 'BandServiceScope not found');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(BandServiceScope oldWidget) =>
      service != oldWidget.service;
}
