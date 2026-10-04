import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/session_controller.dart';
import 'app/auth_gate.dart';
import 'app/l10n/app_localizations.dart';
import 'app/l10n/locale_controller.dart';
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
    unawaited(_localeController.load());
    unawaited(_themeController.load());
    _session.load();
    // Reconnect to last session's watch instead of making the user rescan.
    unawaited(_bandService.restoreLastDevice());
    _startServerSync();
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
    _bandService.removeListener(_saveSleep);
    _session.removeListener(_saveSleep);
    _bandService.removeListener(_saveHistory);
    _session.removeListener(_saveHistory);
    _bandService.dispose();
    _localeController.dispose();
    _themeController.dispose();
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
