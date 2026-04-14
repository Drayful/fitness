## Backend (Laravel API)

### Что реализовано

- **Auth**: регистрация/логин через Sanctum token (Bearer)
- **Workouts**: CRUD (минимально: list/create/show/delete)
- **Daily metrics**: чек-ин сна
- **Scores**: `Strain` и `Recovery` за сегодня (простая стартовая формула)

### Эндпоинты

Без авторизации:

- `POST /api/auth/register`
- `POST /api/auth/login`

С авторизацией (`Authorization: Bearer <token>`):

- `GET /api/auth/me`
- `POST /api/auth/logout`
- `GET /api/workouts`
- `POST /api/workouts`
- `GET /api/workouts/{id}`
- `DELETE /api/workouts/{id}`
- `POST /api/checkins/sleep`
- `GET /api/scores/today`

### Локальный запуск

#### Вариант A: Postgres через Docker (рекомендуется)

Из корня репозитория:

```
docker compose up -d
```

Далее в `backend/.env` должны быть:

- `DB_CONNECTION=pgsql`
- `DB_HOST=127.0.0.1`
- `DB_PORT=5432`
- `DB_DATABASE=fitness`
- `DB_USERNAME=fitness`
- `DB_PASSWORD=fitness`

#### Вариант B: локально установленный Postgres

Поднимите Postgres сами и пропишите параметры подключения в `backend/.env`.

```
cd backend
copy .env.example .env
php artisan key:generate
php artisan migrate
php artisan serve
```

### Быстрые проверки через curl

Регистрация:

```
curl -X POST http://127.0.0.1:8000/api/auth/register ^
  -H "Content-Type: application/json" ^
  -d "{\"name\":\"Test\",\"email\":\"test@example.com\",\"password\":\"password123\"}"
```

Сохраните `token` из ответа и подставьте далее.

Создать тренировку:

```
curl -X POST http://127.0.0.1:8000/api/workouts ^
  -H "Authorization: Bearer <token>" ^
  -H "Content-Type: application/json" ^
  -d "{\"performed_at\":\"2026-04-13 10:00:00\",\"type\":\"run\",\"duration_minutes\":45,\"intensity\":7}"
```

Получить скоринг:

```
curl http://127.0.0.1:8000/api/scores/today -H "Authorization: Bearer <token>"
```

<p align="center"><a href="https://laravel.com" target="_blank"><img src="https://raw.githubusercontent.com/laravel/art/master/logo-lockup/5%20SVG/2%20CMYK/1%20Full%20Color/laravel-logolockup-cmyk-red.svg" width="400" alt="Laravel Logo"></a></p>

<p align="center">
<a href="https://github.com/laravel/framework/actions"><img src="https://github.com/laravel/framework/workflows/tests/badge.svg" alt="Build Status"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/dt/laravel/framework" alt="Total Downloads"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/v/laravel/framework" alt="Latest Stable Version"></a>
<a href="https://packagist.org/packages/laravel/framework"><img src="https://img.shields.io/packagist/l/laravel/framework" alt="License"></a>
</p>

## About Laravel

Laravel is a web application framework with expressive, elegant syntax. We believe development must be an enjoyable and creative experience to be truly fulfilling. Laravel takes the pain out of development by easing common tasks used in many web projects, such as:

- [Simple, fast routing engine](https://laravel.com/docs/routing).
- [Powerful dependency injection container](https://laravel.com/docs/container).
- Multiple back-ends for [session](https://laravel.com/docs/session) and [cache](https://laravel.com/docs/cache) storage.
- Expressive, intuitive [database ORM](https://laravel.com/docs/eloquent).
- Database agnostic [schema migrations](https://laravel.com/docs/migrations).
- [Robust background job processing](https://laravel.com/docs/queues).
- [Real-time event broadcasting](https://laravel.com/docs/broadcasting).

Laravel is accessible, powerful, and provides tools required for large, robust applications.

## Learning Laravel

Laravel has the most extensive and thorough [documentation](https://laravel.com/docs) and video tutorial library of all modern web application frameworks, making it a breeze to get started with the framework.

In addition, [Laracasts](https://laracasts.com) contains thousands of video tutorials on a range of topics including Laravel, modern PHP, unit testing, and JavaScript. Boost your skills by digging into our comprehensive video library.

You can also watch bite-sized lessons with real-world projects on [Laravel Learn](https://laravel.com/learn), where you will be guided through building a Laravel application from scratch while learning PHP fundamentals.

## Agentic Development

Laravel's predictable structure and conventions make it ideal for AI coding agents like Claude Code, Cursor, and GitHub Copilot. Install [Laravel Boost](https://laravel.com/docs/ai) to supercharge your AI workflow:

```bash
composer require laravel/boost --dev

php artisan boost:install
```

Boost provides your agent 15+ tools and skills that help agents build Laravel applications while following best practices.

## Contributing

Thank you for considering contributing to the Laravel framework! The contribution guide can be found in the [Laravel documentation](https://laravel.com/docs/contributions).

## Code of Conduct

In order to ensure that the Laravel community is welcoming to all, please review and abide by the [Code of Conduct](https://laravel.com/docs/contributions#code-of-conduct).

## Security Vulnerabilities

If you discover a security vulnerability within Laravel, please send an e-mail to Taylor Otwell via [taylor@laravel.com](mailto:taylor@laravel.com). All security vulnerabilities will be promptly addressed.

## License

The Laravel framework is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
