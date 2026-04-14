#!/bin/sh
set -e
cd /var/www/html

if [ ! -f .env ]; then
  cp .env.example .env
fi

composer install --no-interaction

if ! grep -q '^APP_KEY=base64:' .env 2>/dev/null; then
  php artisan key:generate --force --ansi
fi

chmod -R ug+rwX storage bootstrap/cache 2>/dev/null || true

php artisan migrate --force --ansi

exec "$@"
