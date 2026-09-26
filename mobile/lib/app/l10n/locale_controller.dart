import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current locale and notifies listeners when it changes.
/// Wire it into MaterialApp via [LocaleScope] (see main.dart).
class LocaleController extends ChangeNotifier {
  LocaleController([Locale initial = const Locale('ru')]) : _locale = initial;

  static const _localeKey = 'app_locale_v1';
  bool _disposed = false;
  bool _selectedSinceStart = false;

  Locale _locale;
  Locale get locale => _locale;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final language = prefs.getString(_localeKey);
      if (_disposed ||
          _selectedSinceStart ||
          language == null ||
          !['ru', 'kk', 'en'].contains(language)) {
        return;
      }
      final saved = Locale(language);
      if (saved != _locale) {
        _locale = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  void setLocale(Locale locale) {
    _selectedSinceStart = true;
    if (locale == _locale) {
      unawaited(_save(locale));
      return;
    }
    _locale = locale;
    notifyListeners();
    unawaited(_save(locale));
  }

  Future<void> _save(Locale locale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, locale.languageCode);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Exposes the [LocaleController] to the widget tree.
/// Read it anywhere with `LocaleScope.of(context).setLocale(...)`.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({
    super.key,
    required LocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    assert(scope?.notifier != null, 'LocaleScope not found');
    return scope!.notifier!;
  }
}
