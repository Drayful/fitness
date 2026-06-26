import 'package:flutter/widgets.dart';

/// Holds the app's current locale and notifies listeners when it changes.
/// Wire it into MaterialApp via [LocaleScope] (see main.dart).
class LocaleController extends ChangeNotifier {
  LocaleController([Locale initial = const Locale('ru')]) : _locale = initial;

  Locale _locale;
  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
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
