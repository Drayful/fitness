import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_rules.dart';

/// System notifications for [AlertCategory] events, with per-category
/// on/off switches the user controls (TZ §31). The OS permission is asked
/// once, the first time an alert is about to be shown.
class NotificationService extends ChangeNotifier {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  static const _prefix = 'notify_category_v1_';
  static const _permissionAskedKey = 'notify_permission_asked_v1';
  static const _channelId = 'yumn_alerts';

  final Map<AlertCategory, bool> _enabled = {
    for (final c in AlertCategory.values) c: c.defaultOn,
  };
  bool _ready = false;
  bool _disposed = false;

  bool isEnabled(AlertCategory c) => _enabled[c] ?? c.defaultOn;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final c in AlertCategory.values) {
        final saved = prefs.getBool('$_prefix${c.name}');
        if (saved != null) _enabled[c] = saved;
      }
    } catch (_) {}
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested lazily, not at launch.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (_) {
      // No plugin (tests, unsupported platform): stay silent.
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setEnabled(AlertCategory c, bool on) async {
    _enabled[c] = on;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix${c.name}', on);
    } catch (_) {}
    if (on) await _ensurePermission(force: true);
  }

  Future<void> show(AlertCategory c, String title, String body) async {
    if (!_ready || !isEnabled(c)) return;
    await _ensurePermission();
    try {
      await _plugin.show(
        id: c.index,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'YUMN',
            channelDescription: 'Watch and health alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  Future<void> _ensurePermission({bool force = false}) async {
    if (!_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force && prefs.getBool(_permissionAskedKey) == true) return;
      await prefs.setBool(_permissionAskedKey, true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true);
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

/// Exposes [NotificationService] to the widget tree.
class NotificationScope extends InheritedNotifier<NotificationService> {
  const NotificationScope({
    super.key,
    required NotificationService service,
    required super.child,
  }) : super(notifier: service);

  static NotificationService of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<NotificationScope>();
    assert(scope?.notifier != null, 'NotificationScope not found');
    return scope!.notifier!;
  }
}
