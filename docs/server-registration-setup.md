# Регистрация мобильного приложения через 80.242.213.87

Проверено 23 сентября 2026. Пользователь указал, что API-файлы находятся в `/var/www/ella_mobile` на сервере `80.242.213.87`. Публичные ответы подтверждают наличие маршрута Laravel на **HTTP**: `GET http://80.242.213.87/api/auth/register` возвращает `405` и `Allow: POST`, а `/api/auth/me` — `401` в JSON. Они не подтверждают подключение к PostgreSQL и успешное создание пользователя.

На **HTTPS** проверка сертификата для IP завершается ошибкой имени (`SEC_E_WRONG_PRINCIPAL`). Если отключить проверку сертификата только для диагностики, `/api/auth/me` попадает в другой Laravel по пути `/var/www/appella` и возвращает `404`. Этот HTTPS-сайт показывает наружу трассировку ошибки, включая пути на сервере. Рабочее приложение не должно отключать проверку TLS.

**Цель:** `https://80.242.213.87/api/auth/register` должен попадать в Laravel мобильного проекта с сертификатом, который содержит IP `80.242.213.87` в SAN. Существующий сайт по своему имени должен продолжить работать. В мобильном коде этот URL стоит по умолчанию; `API_BASE_URL` позволяет переопределить его при сборке.

## 1. Прочитать состояние сервера до изменения

SSH-доступ из текущего рабочего окружения не настроен, поэтому эти команды ещё не выполнялись. Запускать их через SSH на `80.242.213.87`:

```bash
hostname -f
find /var/www/ella_mobile -maxdepth 2 -type f \( -name artisan -o -name composer.json -o -name pubspec.yaml \) -print
php -v
php -m | grep -Ei 'pdo_pgsql|mbstring|openssl|fileinfo|xml|ctype|tokenizer'
composer --version
sudo nginx -T > /tmp/nginx-before-yumn.txt
sudo nginx -t
sudo ss -ltnp | grep -E ':80 |:443 '
sudo certbot --version
ls -l /run/php/
```

Найти действующие `server` блоки для `80.242.213.87`, `default_server` на 80/443 и сайта `app.palitra-and-me.kz`. `nginx -T` может содержать внутренние адреса и настройки — его полный вывод не публиковать. Подтвердить, что `artisan` лежит либо в `/var/www/ella_mobile/backend`, либо непосредственно в `/var/www/ella_mobile`. Далее пример использует первый вариант; если фактический путь иной, заменить его в командах и `root` Nginx. Корень веб-сервера — только каталог Laravel `public/`.

## 2. Подготовить Laravel и БД

Сохранить текущие серверные `.env`, `storage/` и базу PostgreSQL. Перенести актуальный `backend/` из этого репозитория без замены серверного `.env` и пользовательских файлов в `storage/`. Убедиться, что на сервере PHP 8.4, Composer и `pdo_pgsql`.

```bash
cd /var/www/ella_mobile/backend
composer install --no-dev --prefer-dist --optimize-autoloader
php artisan about
php artisan route:list --path=api
php artisan migrate:status
```

Проверить `APP_KEY`, `DB_CONNECTION=pgsql`, `DB_HOST=127.0.0.1`, `DB_PORT=5432`, `DB_DATABASE=fitness` и права указанного пользователя БД. Пароль хранится только в `.env` на сервере. Если Laravel запущен в Docker, `127.0.0.1` относится к контейнеру и может быть неправильным адресом PostgreSQL. Не запускать `docker-compose.yml` из репозитория: он поднимает отдельную БД.

При существующем `APP_KEY` не запускать `key:generate`. После резервной копии и проверки списка миграций:

```bash
php artisan migrate --force
php artisan optimize:clear
php artisan config:cache
sudo chown -R www-data:www-data storage bootstrap/cache
```

Для регистрации нужны таблицы `users` и `personal_access_tokens`. `migrate:fresh` использовать нельзя: он удалит действующие таблицы. Новая миграция тренировок также входит в пакет; она добавляет `client_id` и `metrics`.

## 3. Получить доверенный HTTPS-сертификат на IP

[Let's Encrypt выдаёт сертификаты на IP](https://letsencrypt.org/2026/03/11/shorter-certs-certbot). Для `webroot` требуется Certbot **5.4+**; сертификат живёт **6 дней**, поэтому продление и перезагрузка Nginx обязательны. Порты 80 и 443 должны быть доступны снаружи.

Сначала добавить к Nginx отдельный HTTP `server` для `server_name 80.242.213.87`, как в [HTTP-шаблоне](../deploy/nginx-yumn-ip-http.conf.example). Его каталог `/.well-known/acme-challenge/` должен обслуживать публичный IP, не попадая в существующий сайт. Проверить:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Затем получить сертификат. При первой отладке можно добавить `--staging`; такой сертификат **не** будет доверенным. Для финального результата команда без `--staging`:

```bash
sudo certbot certonly \
  --preferred-profile shortlived \
  --webroot \
  --webroot-path /var/www/ella_mobile/backend/public \
  --ip-address 80.242.213.87
```

После выдачи добавить [HTTPS-шаблон](../deploy/nginx-yumn-ip-https.conf.example). Certbot сейчас не устанавливает IP-сертификат в Nginx автоматически. Путь к сертификату: `/etc/letsencrypt/live/80.242.213.87/fullchain.pem` и `privkey.pem`. Выбрать ровно один `default_server` на 443: HTTPS-клиент при подключении по IP может не послать SNI, и тогда Nginx отдаст сертификат и сайт существующего default server. При необходимости убрать `default_server` у прежнего 443 блока и назначить его IP-блоку; предварительно проверить конфигурацию сайта. Доменный виртуальный хост продолжит выбираться по SNI.

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo certbot renew --dry-run
```

Выполнить настройку автоматического `certbot renew` (systemd timer или cron) и deploy-hook `systemctl reload nginx` после успешного обновления. Без hook Nginx может продолжить отдавать истёкший сертификат. Установить `APP_URL=https://80.242.213.87` в Laravel мобильного API и `APP_ENV=production`, `APP_DEBUG=false`. У существующего HTTPS Laravel также отключить публичную трассировку ошибок после проверки его конфигурации.

## 4. Проверить регистрацию

После настройки **без** `-k` и `--insecure`:

```bash
curl -i https://80.242.213.87/up
curl -i -H 'Accept: application/json' https://80.242.213.87/api/auth/me
curl -i -H 'Accept: application/json' https://80.242.213.87/api/auth/register
```

Ожидаются соответственно `200`, `401` и `405` с `Allow: POST`; не должно быть ошибки сертификата или пути `/var/www/appella` в ответе. Затем выполнить одну пробную регистрацию с отдельным тестовым email и проверить `201`, токен, чтение `/api/auth/me` с токеном и запись в `users`/`personal_access_tokens`. Тестовый аккаунт после проверки удалить через безопасную административную процедуру. Пароли и токены не помещать в переписку или командные логи.

Если регистрация даёт `500`, сначала проверить журнал `storage/logs/laravel.log`, миграции, `pdo_pgsql`, подключение и права БД. Если `404`, проверить выбор Nginx `server` блока и Laravel `route:list`. Если `422`, посмотреть валидацию полей JSON.

## 5. Собрать и установить мобильное приложение

`mobile/lib/api/api_client.dart` по умолчанию использует `https://80.242.213.87`; тот же адрес можно указать явно:

```powershell
cd D:\Dev\app_phone\mobile
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://80.242.213.87
```

Адрес указывается без `/api` на конце. Уже установленное APK со старым `185.2.227.187` нужно пересобрать и заменить. В release HTTP запрещён; Android/iOS не будут доверять сертификату на другое имя. Реквизиты PostgreSQL в приложение не передаются.

## Доступ к серверу

Сейчас удалённые файлы и PostgreSQL не проверены: в этом окружении нет SSH-ключа или настройки подключения к серверу. Поэтому миграции, Nginx и сертификат на сервере ещё не изменены. Для применения нужен SSH-доступ с достаточными правами; пароль SSH и БД в чат присылать не нужно.
