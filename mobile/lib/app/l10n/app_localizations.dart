import 'package:flutter/widgets.dart';

/// Lightweight hand-written localizations (no codegen / build_runner needed).
/// Supports Kazakh, Russian and English. Look up a string with
/// `AppLocalizations.of(context).t('some_key')`.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('kk'),
    Locale('ru'),
    Locale('en'),
  ];

  static const Map<String, String> localeNames = {
    'kk': 'Қазақша',
    'ru': 'Русский',
    'en': 'English',
  };

  String t(String key) {
    final lang = _data.containsKey(locale.languageCode) ? locale.languageCode : 'ru';
    return _data[lang]?[key] ?? _data['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _data = {
    'en': {
      'nav_today': 'Today', 'nav_trends': 'Trends', 'nav_training': 'Training', 'nav_profile': 'Profile',
      'date': 'Tuesday, Jun 24', 'greeting': 'Good morning, Alex',
      'recovery': 'RECOVERY', 'recovery_msg': 'Your body is primed. Push for a higher-strain session today.',
      'ready': 'READY', 'vs_yesterday': '▲ 6% vs yesterday',
      'strain': 'STRAIN', 'moderate': 'Moderate', 'of_strain': 'of 21.0',
      'sleep': 'SLEEP', 'sleep_dur': '7h 32m', 'great': 'Great',
      'rest_hr': 'REST HR', 'bpm': ' bpm', 'hrv': 'HRV', 'ms': ' ms', 'steps': 'STEPS',
      'trends': 'Trends', 'week': 'Week', 'month': 'Month', 'year': 'Year',
      'avg_recovery_cap': 'Avg 68% · ▲ 4%', 'daily_strain': 'DAILY STRAIN', 'peak_cap': 'Peak 16.2',
      'avg_sleep': 'AVG SLEEP', 'avg_hrv': 'AVG HRV',
      'day_mon': 'M', 'day_tue': 'T', 'day_wed': 'W', 'day_thu': 'T', 'day_fri': 'F', 'day_sat': 'S', 'day_sun': 'S',
      'training': 'Training', 'recommended_today': 'RECOMMENDED TODAY', 'tempo_run': 'Tempo Run · 35 min',
      'tempo_msg': 'High recovery means you can target a strain of 14–16 today.', 'start_session': 'Start session',
      'quick_start': 'QUICK START', 'run': 'Run', 'bike': 'Bike', 'swim': 'Swim', 'strength': 'Strength',
      'recent': 'RECENT', 'morning_run': 'Morning Run', 'run_meta': '5.2 km · 28 min · Strain 11.4', 'yest': 'Yest.',
      'upper_body': 'Upper Body', 'upper_meta': '45 min · RPE 7 · Strain 9.8', 'mon': 'Mon',
      'profile': 'Profile', 'member_since': 'Athlete · Member since 2024',
      'connected': 'Connected · synced 2m ago', 'not_connected': 'Not connected', 'manage': 'Manage', 'connect': 'Connect',
      'battery': 'BATTERY', 'firmware': 'FIRMWARE',
      'bracelet': 'Bracelet', 'bracelet_sub': 'Pair, permissions, sync',
      'privacy': 'Privacy', 'privacy_sub': 'Data export & permissions',
      'api': 'API connection', 'api_sub': 'Backend URL and auth',
      'language': 'Language', 'language_sub': 'App display language', 'choose_language': 'Choose language',
    },
    'ru': {
      'nav_today': 'Сегодня', 'nav_trends': 'Тренды', 'nav_training': 'Тренировки', 'nav_profile': 'Профиль',
      'date': 'Вторник, 24 июня', 'greeting': 'Доброе утро, Алекс',
      'recovery': 'ВОССТАНОВЛЕНИЕ', 'recovery_msg': 'Организм готов. Сегодня можно дать нагрузку посильнее.',
      'ready': 'ГОТОВ', 'vs_yesterday': '▲ 6% к вчера',
      'strain': 'НАГРУЗКА', 'moderate': 'Умеренная', 'of_strain': 'из 21.0',
      'sleep': 'СОН', 'sleep_dur': '7ч 32м', 'great': 'Отлично',
      'rest_hr': 'ПУЛЬС ПОКОЯ', 'bpm': ' уд/м', 'hrv': 'ВСР', 'ms': ' мс', 'steps': 'ШАГИ',
      'trends': 'Тренды', 'week': 'Неделя', 'month': 'Месяц', 'year': 'Год',
      'avg_recovery_cap': 'Сред. 68% · ▲ 4%', 'daily_strain': 'НАГРУЗКА ПО ДНЯМ', 'peak_cap': 'Пик 16.2',
      'avg_sleep': 'СРЕД. СОН', 'avg_hrv': 'СРЕД. ВСР',
      'day_mon': 'Пн', 'day_tue': 'Вт', 'day_wed': 'Ср', 'day_thu': 'Чт', 'day_fri': 'Пт', 'day_sat': 'Сб', 'day_sun': 'Вс',
      'training': 'Тренировки', 'recommended_today': 'РЕКОМЕНДУЕМ СЕГОДНЯ', 'tempo_run': 'Темповый бег · 35 мин',
      'tempo_msg': 'Высокое восстановление — можно целиться в нагрузку 14–16.', 'start_session': 'Начать',
      'quick_start': 'БЫСТРЫЙ СТАРТ', 'run': 'Бег', 'bike': 'Вело', 'swim': 'Плавание', 'strength': 'Силовая',
      'recent': 'НЕДАВНИЕ', 'morning_run': 'Утренний бег', 'run_meta': '5,2 км · 28 мин · Нагр. 11.4', 'yest': 'Вчера',
      'upper_body': 'Верх тела', 'upper_meta': '45 мин · RPE 7 · Нагр. 9.8', 'mon': 'Пн',
      'profile': 'Профиль', 'member_since': 'Атлет · С нами с 2024',
      'connected': 'Подключён · синхрон. 2 мин назад', 'not_connected': 'Не подключён', 'manage': 'Управление', 'connect': 'Подключить',
      'battery': 'ЗАРЯД', 'firmware': 'ПРОШИВКА',
      'bracelet': 'Браслет', 'bracelet_sub': 'Подключение, доступы, синхрон.',
      'privacy': 'Приватность', 'privacy_sub': 'Экспорт данных и доступы',
      'api': 'Подключение API', 'api_sub': 'URL сервера и авторизация',
      'language': 'Язык', 'language_sub': 'Язык интерфейса', 'choose_language': 'Выберите язык',
    },
    'kk': {
      'nav_today': 'Бүгін', 'nav_trends': 'Тренд', 'nav_training': 'Жаттығу', 'nav_profile': 'Профиль',
      'date': 'Сейсенбі, 24 маусым', 'greeting': 'Қайырлы таң, Алекс',
      'recovery': 'ҚАЛПЫНА КЕЛУ', 'recovery_msg': 'Денең дайын. Бүгін жүктемені арттыруға болады.',
      'ready': 'ДАЙЫН', 'vs_yesterday': '▲ 6% кешеге',
      'strain': 'ЖҮКТЕМЕ', 'moderate': 'Орташа', 'of_strain': '21.0-ден',
      'sleep': 'ҰЙҚЫ', 'sleep_dur': '7сағ 32мин', 'great': 'Тамаша',
      'rest_hr': 'ТЫНЫШ ПУЛЬС', 'bpm': ' соқ/мин', 'hrv': 'ЖЖВ', 'ms': ' мс', 'steps': 'ҚАДАМ',
      'trends': 'Тренд', 'week': 'Апта', 'month': 'Ай', 'year': 'Жыл',
      'avg_recovery_cap': 'Орт. 68% · ▲ 4%', 'daily_strain': 'КҮНДЕЛІКТІ ЖҮКТЕМЕ', 'peak_cap': 'Шың 16.2',
      'avg_sleep': 'ОРТ. ҰЙҚЫ', 'avg_hrv': 'ОРТ. ЖЖВ',
      'day_mon': 'Дс', 'day_tue': 'Сс', 'day_wed': 'Ср', 'day_thu': 'Бс', 'day_fri': 'Жм', 'day_sat': 'Сб', 'day_sun': 'Жс',
      'training': 'Жаттығу', 'recommended_today': 'БҮГІНГЕ ҰСЫНЫС', 'tempo_run': 'Темпті жүгіру · 35 мин',
      'tempo_msg': 'Қалпына келу жоғары — жүктемені 14–16-ға бағыттаңыз.', 'start_session': 'Бастау',
      'quick_start': 'ЖЫЛДАМ БАСТАУ', 'run': 'Жүгіру', 'bike': 'Велосипед', 'swim': 'Жүзу', 'strength': 'Күш',
      'recent': 'СОҢҒЫЛАР', 'morning_run': 'Таңғы жүгіру', 'run_meta': '5,2 км · 28 мин · Жүкт. 11.4', 'yest': 'Кеше',
      'upper_body': 'Дене жоғары', 'upper_meta': '45 мин · RPE 7 · Жүкт. 9.8', 'mon': 'Дс',
      'profile': 'Профиль', 'member_since': 'Атлет · 2024 жылдан бері',
      'connected': 'Қосылған · 2 мин бұрын синхр.', 'not_connected': 'Қосылмаған', 'manage': 'Басқару', 'connect': 'Қосу',
      'battery': 'ЗАРЯД', 'firmware': 'БАҒДАРЛАМА',
      'bracelet': 'Білезік', 'bracelet_sub': 'Қосу, рұқсаттар, синхрон.',
      'privacy': 'Құпиялылық', 'privacy_sub': 'Деректер экспорты, рұқсаттар',
      'api': 'API қосылымы', 'api_sub': 'Сервер URL және авторизация',
      'language': 'Тіл', 'language_sub': 'Қолданба тілі', 'choose_language': 'Тілді таңдаңыз',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['kk', 'ru', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
