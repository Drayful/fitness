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
      'heart_rate': 'HEART RATE', 'spo2': 'SpO2', 'pct': '%', 'temp_label': 'TEMP', 'celsius': '°C',
      'live': 'LIVE', 'connect_band': 'Connect your band', 'connect_band_sub': 'Go to Profile → Connect to see live metrics',
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
      'sleep_analysis': 'Sleep Analysis', 'sleep_score': 'SCORE', 'sleep_duration': 'DURATION',
      'bedtime': 'Bedtime', 'wake_time': 'Wake',
      'deep_sleep': 'Deep', 'light_sleep': 'Light', 'rem_sleep': 'REM', 'awake_stage': 'Awake',
      'hypnogram': 'SLEEP PATTERN', 'stage_breakdown': 'STAGE BREAKDOWN',
      'sleep_efficiency': 'Efficiency', 'total_time': 'Total in bed',
      'syncing': 'Syncing...', 'syncing_sub': 'Reading sleep data from band',
      'no_sleep_data': 'No Sleep Data',
      'no_sleep_sub': 'Wear your band while sleeping to track stages',
      'no_sleep_sub_connected': 'Tap the sync button above to fetch sleep data',
      // Workout
      'walk': 'Walk', 'kcal': 'kcal', 'back': 'Back',
      'workout_starting': 'Starting workout...', 'workout_start_failed': 'Could not start workout',
      'workout_start_failed_sub': 'Make sure your band is connected and try again.',
      'workout_complete': 'Workout Complete', 'workout_done': 'Done',
      'workout_no_data': 'No data was recorded for this workout.',
      'workout_distance': 'DISTANCE', 'workout_duration': 'DURATION',
      'workout_calories': 'CALORIES', 'workout_pace': 'PACE', 'workout_avg_hr': 'AVG HR',
      'workout_pause': 'Pause', 'workout_resume': 'Resume', 'workout_end': 'End Workout',
      'workout_continue': 'Continue',
      'workout_end_confirm': 'End workout?',
      'workout_end_confirm_sub': 'Your progress will be saved.',
      'workout_still_active': 'Still active?',
      'workout_inactive_msg': 'No movement detected for %m minutes.',
      'workout_connect_hint': 'Connect your band to start a workout',
      'workout_type_run': 'Run', 'workout_type_cycling': 'Cycling', 'workout_type_walk': 'Walk',
      'workout_type_workout': 'Workout', 'workout_type_yoga': 'Yoga', 'workout_type_hiking': 'Hiking',
      'workout_type_basketball': 'Basketball', 'workout_type_dance': 'Dance',
      'workout_type_meditation': 'Meditation',
    },
    'ru': {
      'nav_today': 'Сегодня', 'nav_trends': 'Тренды', 'nav_training': 'Тренировки', 'nav_profile': 'Профиль',
      'date': 'Вторник, 24 июня', 'greeting': 'Доброе утро, Алекс',
      'recovery': 'ВОССТАНОВЛЕНИЕ', 'recovery_msg': 'Организм готов. Сегодня можно дать нагрузку посильнее.',
      'ready': 'ГОТОВ', 'vs_yesterday': '▲ 6% к вчера',
      'strain': 'НАГРУЗКА', 'moderate': 'Умеренная', 'of_strain': 'из 21.0',
      'sleep': 'СОН', 'sleep_dur': '7ч 32м', 'great': 'Отлично',
      'rest_hr': 'ПУЛЬС ПОКОЯ', 'bpm': ' уд/м', 'hrv': 'ВСР', 'ms': ' мс', 'steps': 'ШАГИ',
      'heart_rate': 'ПУЛЬС', 'spo2': 'SpO2', 'pct': '%', 'temp_label': 'ТЕМП.', 'celsius': '°C',
      'live': 'ЛАЙВ', 'connect_band': 'Подключите браслет', 'connect_band_sub': 'Профиль → Подключить, чтобы видеть данные',
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
      'sleep_analysis': 'Анализ сна', 'sleep_score': 'ОЦЕНКА', 'sleep_duration': 'ДЛИТЕЛЬНОСТЬ',
      'bedtime': 'Отбой', 'wake_time': 'Подъём',
      'deep_sleep': 'Глубокий', 'light_sleep': 'Лёгкий', 'rem_sleep': 'REM', 'awake_stage': 'Бодрств.',
      'hypnogram': 'ПАТТЕРН СНА', 'stage_breakdown': 'СТАДИИ СНА',
      'sleep_efficiency': 'Эффективность', 'total_time': 'Всего в постели',
      'syncing': 'Синхронизация...', 'syncing_sub': 'Чтение данных сна с браслета',
      'no_sleep_data': 'Нет данных о сне',
      'no_sleep_sub': 'Носите браслет во время сна для отслеживания',
      'no_sleep_sub_connected': 'Нажмите кнопку синхронизации выше',
      // Тренировка
      'walk': 'Ходьба', 'kcal': 'ккал', 'back': 'Назад',
      'workout_starting': 'Запускаем тренировку...', 'workout_start_failed': 'Не удалось начать',
      'workout_start_failed_sub': 'Убедитесь, что браслет подключён, и повторите.',
      'workout_complete': 'Тренировка завершена', 'workout_done': 'Готово',
      'workout_no_data': 'Данные за эту тренировку не записались.',
      'workout_distance': 'ДИСТАНЦИЯ', 'workout_duration': 'ВРЕМЯ',
      'workout_calories': 'КАЛОРИИ', 'workout_pace': 'ТЕМП', 'workout_avg_hr': 'СРЕД. ПУЛЬС',
      'workout_pause': 'Пауза', 'workout_resume': 'Продолжить', 'workout_end': 'Завершить',
      'workout_continue': 'Продолжить',
      'workout_end_confirm': 'Завершить тренировку?',
      'workout_end_confirm_sub': 'Результат будет сохранён.',
      'workout_still_active': 'Ещё тренируетесь?',
      'workout_inactive_msg': 'Движений нет уже %m минут.',
      'workout_connect_hint': 'Подключите браслет, чтобы начать',
      'workout_type_run': 'Бег', 'workout_type_cycling': 'Велосипед', 'workout_type_walk': 'Ходьба',
      'workout_type_workout': 'Тренировка', 'workout_type_yoga': 'Йога', 'workout_type_hiking': 'Хайкинг',
      'workout_type_basketball': 'Баскетбол', 'workout_type_dance': 'Танцы',
      'workout_type_meditation': 'Медитация',
    },
    'kk': {
      'nav_today': 'Бүгін', 'nav_trends': 'Тренд', 'nav_training': 'Жаттығу', 'nav_profile': 'Профиль',
      'date': 'Сейсенбі, 24 маусым', 'greeting': 'Қайырлы таң, Алекс',
      'recovery': 'ҚАЛПЫНА КЕЛУ', 'recovery_msg': 'Денең дайын. Бүгін жүктемені арттыруға болады.',
      'ready': 'ДАЙЫН', 'vs_yesterday': '▲ 6% кешеге',
      'strain': 'ЖҮКТЕМЕ', 'moderate': 'Орташа', 'of_strain': '21.0-ден',
      'sleep': 'ҰЙҚЫ', 'sleep_dur': '7сағ 32мин', 'great': 'Тамаша',
      'rest_hr': 'ТЫНЫШ ПУЛЬС', 'bpm': ' соқ/мин', 'hrv': 'ЖЖВ', 'ms': ' мс', 'steps': 'ҚАДАМ',
      'heart_rate': 'ПУЛЬС', 'spo2': 'SpO2', 'pct': '%', 'temp_label': 'ТЕМП.', 'celsius': '°C',
      'live': 'ТІКЕЛЕЙ', 'connect_band': 'Білезікті қосыңыз', 'connect_band_sub': 'Профиль → Қосу — деректерді көру үшін',
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
      'sleep_analysis': 'Ұйқы талдауы', 'sleep_score': 'БАҒА', 'sleep_duration': 'ҰЗАҚТЫҚ',
      'bedtime': 'Ұйықтау', 'wake_time': 'Ояну',
      'deep_sleep': 'Терең', 'light_sleep': 'Жеңіл', 'rem_sleep': 'REM', 'awake_stage': 'Ояу',
      'hypnogram': 'ҰЙҚ ПАТТЕРНІ', 'stage_breakdown': 'ҰЙҚЫ КЕЗЕҢДЕРІ',
      'sleep_efficiency': 'Тиімділік', 'total_time': 'Барлығы төсекте',
      'syncing': 'Синхрондауда...', 'syncing_sub': 'Браслеттен ұйқы деректері оқылуда',
      'no_sleep_data': 'Ұйқы деректері жоқ',
      'no_sleep_sub': 'Ұйқыны бақылау үшін браслет киіңіз',
      'no_sleep_sub_connected': 'Жоғарыдағы синхрондау батырмасын басыңыз',
      // Жаттығу
      'walk': 'Жаяу', 'kcal': 'ккал', 'back': 'Артқа',
      'workout_starting': 'Жаттығу басталуда...', 'workout_start_failed': 'Бастаудан сәтсіздік',
      'workout_start_failed_sub': 'Білезіктің қосылғанын тексеріп, қайталаңыз.',
      'workout_complete': 'Жаттығу аяқталды', 'workout_done': 'Дайын',
      'workout_no_data': 'Бұл жаттығуда деректер жазылмады.',
      'workout_distance': 'ҚАШЫҚТЫҚ', 'workout_duration': 'УАҚЫТ',
      'workout_calories': 'КАЛОРИЯ', 'workout_pace': 'ҚАРҚЫН', 'workout_avg_hr': 'ОРТ. ПУЛЬС',
      'workout_pause': 'Тоқтат', 'workout_resume': 'Жалғастыру', 'workout_end': 'Аяқтау',
      'workout_continue': 'Жалғастыру',
      'workout_end_confirm': 'Жаттығуды аяқтайсыз ба?',
      'workout_end_confirm_sub': 'Нәтиже сақталады.',
      'workout_still_active': 'Жаттығу жалғасуда ма?',
      'workout_inactive_msg': '%m минут бойы қозғалыс жоқ.',
      'workout_connect_hint': 'Жаттығуды бастау үшін білезікті қосыңыз',
      'workout_type_run': 'Жүгіру', 'workout_type_cycling': 'Велосипед', 'workout_type_walk': 'Жаяу',
      'workout_type_workout': 'Жаттығу', 'workout_type_yoga': 'Йога', 'workout_type_hiking': 'Хайкинг',
      'workout_type_basketball': 'Баскетбол', 'workout_type_dance': 'Би',
      'workout_type_meditation': 'Медитация',
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
