import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-system choice (design screen Onb-03-Theme),
/// persisted across launches. Defaults to the system setting.
class ThemeController extends ChangeNotifier {
  static const _modeKey = 'app_theme_mode_v1';
  bool _disposed = false;
  bool _selectedSinceStart = false;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_modeKey);
      if (_disposed || _selectedSinceStart || name == null) return;
      for (final m in ThemeMode.values) {
        if (m.name == name && m != _mode) {
          _mode = m;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void setMode(ThemeMode mode) {
    _selectedSinceStart = true;
    if (mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
    unawaited(_save(mode));
  }

  Future<void> _save(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Exposes the [ThemeController]: `ThemeScope.of(context).setMode(...)`.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, 'ThemeScope not found');
    return scope!.notifier!;
  }
}
