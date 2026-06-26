import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/l10n/app_localizations.dart';
import 'app/l10n/locale_controller.dart';
import 'app/root_shell.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bandService.dispose();
    _localeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_bandService.disconnect());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BandServiceScope(
      service: _bandService,
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
              home: const RootShell(),
            );
          },
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
    final scope = context.dependOnInheritedWidgetOfExactType<BandServiceScope>();
    assert(scope != null, 'BandServiceScope not found');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(BandServiceScope oldWidget) => service != oldWidget.service;
}
