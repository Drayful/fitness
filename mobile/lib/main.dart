import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api/session_controller.dart';
import 'app/auth_gate.dart';
import 'app/l10n/app_localizations.dart';
import 'app/l10n/locale_controller.dart';
import 'app/theme.dart';
import 'band/v8_band_service.dart';

void main() {
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
    unawaited(_localeController.load());
    _session.load();
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
    _bandService.removeListener(_saveVitals);
    _bandService.removeListener(_saveSleep);
    _session.removeListener(_saveSleep);
    _bandService.dispose();
    _localeController.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _session.isAuthenticated) {
      unawaited(_session.synchronize().catchError((_) {}));
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
          child: AnimatedBuilder(
            animation: _localeController,
            builder: (context, _) {
              return MaterialApp(
                title: 'Fitness',
                themeMode: ThemeMode.dark,
                debugShowCheckedModeBanner: false,
                darkTheme: AppTheme.dark(),
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
    );
  }
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
