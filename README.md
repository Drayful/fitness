# YUMN — Flutter + Laravel

В репозитории находятся мобильный прототип и API. Полная экосистема из ТЗ ещё не реализована. Текущий статус, исправления и ограничения: [аудит проекта](docs/project-audit.md). [Вопросы производителю](docs/manufacturer-questions.md).

Размещение Laravel рядом с существующим сайтом и подключение регистрации мобильного приложения описаны в [инструкции для сервера](docs/server-registration-setup.md). Она рассчитана на `/var/www/ella_mobile` и публичный IP `80.242.213.87`, без нового домена.

- `backend/`: Laravel API, авторизация, тренировки, дневные записи сна, экспериментальные расчёты.
- `mobile/`: Flutter, BLE-интеграция с семействами SDK V8/2208A и отправка итогов тренировок.

## Локальный запуск

### Backend

Требования: PHP 8.4+, Composer, драйвер выбранной БД. `.env.example` настроен на PostgreSQL: укажите собственные реквизиты и создайте БД перед миграциями.

```powershell
cd backend
composer install
Copy-Item .env.example .env
# Настройте DB_* в .env.
php artisan key:generate
php artisan migrate
php artisan serve
```

`Copy-Item` и `key:generate` нужны только при первой настройке. Для существующего окружения сохраняйте `.env` и APP_KEY.

### Mobile

Проверено на Flutter 3.41.6 / Dart 3.11.4. Android minimum SDK 23. Для iOS требуется macOS/Xcode, provisioning и проверка Keychain Sharing (Runner.entitlements подключён к конфигурациям Runner).

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=https://80.242.213.87
```

Этот IP уже задан в мобильном коде по умолчанию; `--dart-define` позволяет его переопределить. Суффикс `/api` не добавляйте. В release разрешён только HTTPS. Сертификат на IP и серверный маршрут должны быть настроены по инструкции выше.

Для Android-эмулятора и локального Laravel разрешите HTTP только в debug:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=ALLOW_INSECURE_API=true
```

Этот debug-адрес относится к Android-эмулятору. На телефоне нужен доступный HTTPS-сервер. Для локального HTTP на iOS понадобятся отдельные debug-настройки ATS; production-исключение для прежнего HTTP IP удалено.

После обновления потребуется повторный вход: старый токен из SharedPreferences удаляется; новая сессия хранится в защищённом хранилище ОС. Непереданные итоги тренировок сохраняются там отдельно для каждого аккаунта; повторная отправка выполняется при входе/запуске или через кнопку повтора после ошибки.

На экране подключения выберите подтверждённое семейство SDK для конкретного устройства. До выбора команды тренировок заблокированы. Выбор пока сохраняется только на время работы приложения. BCD и MTU не позволяют автоматически определить модель.

## Обновление существующего сервера

Установите зависимости из `backend/composer.lock`, выполните миграции с обычной для проекта процедурой резервного копирования и обновите конфигурационный кэш. Новая миграция добавляет `workouts.client_id`, уникальность в пределах пользователя и `workouts.metrics`. Сначала обновляется сервер, затем мобильный клиент: иначе повторные отправки старому API могут дублироваться.

```powershell
cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache
```

Серверный HTTPS, `APP_ENV=production`, `APP_DEBUG=false`, секреты и доступы к БД настраиваются в окружении развёртывания. Эти команды на production в рамках проверки не выполнялись.

## Проверки

```powershell
cd backend
composer validate --no-check-publish
composer audit
php artisan test
```

```powershell
cd mobile
flutter analyze
flutter test
```

Автотесты не подтверждают работу конкретной прошивки, фоновую BLE-связь или физиологическую точность. Проверка на физических V8/2208A и сборки Android/iOS остаются обязательными перед выпуском.
