## fitness (Flutter + Laravel)

Монорепозиторий с двумя независимыми приложениями:

- **`backend/`**: Laravel API (REST JSON). Хранит пользователей/данные, считает Strain/Recovery Score.
- **`mobile/`**: Flutter приложение. Ходит в API по HTTP и рендерит UI.

### Структура

```
backend/   Laravel API
mobile/    Flutter app
```

### Быстрый старт (локально)

#### Backend (Laravel)

Требования: PHP 8.2+, Composer, любой SQL (например SQLite).

```
cd backend
copy .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

По умолчанию API будет на `http://127.0.0.1:8000`.

#### Mobile (Flutter)

Требования: Flutter SDK, Android Studio/эмулятор или устройство.

```
cd mobile
flutter pub get
flutter run
```

### Тестирование

- **Backend**: `cd backend` → `php artisan test`
- **Mobile**: `cd mobile` → `flutter test`

