# laravel-fpm

A slim, production-tuned **PHP-FPM base image for Laravel** — PHP 8.3 on Alpine, with every extension a typical Laravel app needs, Composer 2, Redis, and OPcache+JIT pre-tuned. Runs as a non-root user, ships a HEALTHCHECK, and is built to be the image you `FROM`.

```bash
docker pull minhle202/laravel-fpm:8.3
```

## Why this image

You shouldn't reinvent a PHP-FPM Dockerfile for every Laravel project. This is a clean, minimal **base/runtime image**: bring your app code on top of it, run `composer install`, and ship. No nginx baked in (use a separate nginx container), no bloat, no `:latest` surprises.

## What's inside

- **PHP 8.3** (`php:8.3-fpm-alpine`), multi-stage build for a small final image
- **Extensions**: `pdo_mysql`, `mbstring`, `bcmath`, `gd`, `zip`, `exif`, `pcntl`, `opcache`, and **`redis`** (PECL)
- **Composer 2** at `/usr/local/bin/composer` (copied from the official `composer:2` image)
- **OPcache + JIT** tuned for production (`validate_timestamps=0`, large file cache, tracing JIT)
- **php.ini** tuned: `memory_limit=256M`, `upload_max_filesize=32M`, `post_max_size=40M`, errors to stderr, `expose_php=Off`
- Runs as **non-root user `www`** (uid/gid 1000)
- **HEALTHCHECK** via php-fpm's built-in `/ping` endpoint (using `cgi-fcgi`)
- Builds for **linux/amd64** and **linux/arm64**

## Ports & user

| | |
|---|---|
| Exposed port | `9000` (FastCGI/TCP — point nginx/apache at it) |
| User | `www` (uid 1000, gid 1000) |
| Workdir | `/var/www/html` |
| CMD | `php-fpm` |

## Quick smoke test (standalone)

The fastest check needs nothing but the image — hit php-fpm's built-in `/ping`
over FastCGI from inside the container (this is also what the HEALTHCHECK does):

```bash
docker run -d --name fpm minhle202/laravel-fpm:8.3
docker exec fpm sh -c \
  'SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
   cgi-fcgi -bind -connect 127.0.0.1:9000'
# pong

docker inspect --format '{{.State.Health.Status}}' fpm
# healthy
```

The image also ships a tiny `public/index.php` (with a `/healthz` route) so you
can drive it through nginx. nginx and php-fpm are separate containers that share
the document root, so mount the example `public/` into both:

```bash
docker network create demo

docker run -d --name fpm --network demo --network-alias app \
  minhle202/laravel-fpm:8.3

docker run -d --name web --network demo -p 8080:80 \
  -v "$PWD/examples/nginx.conf:/etc/nginx/conf.d/default.conf:ro" \
  -v "$PWD/public:/var/www/html/public:ro" \
  nginx:1.27-alpine

curl -s localhost:8080/healthz
# {"status":"ok","php":"8.3.x","extensions":{...all true...}}
```

(In a real app the shared root is your code, mounted via a named volume — see
[`examples/docker-compose.yml`](examples/docker-compose.yml).)

## Use it as your Laravel base image

In your Laravel project's `Dockerfile`:

```dockerfile
FROM minhle202/laravel-fpm:8.3 AS vendor
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-scripts

FROM minhle202/laravel-fpm:8.3 AS app
WORKDIR /var/www/html
COPY --chown=www:www . .
COPY --from=vendor --chown=www:www /var/www/html/vendor ./vendor
RUN php artisan config:cache && php artisan route:cache && php artisan view:cache || true
# Base image already sets USER www, EXPOSE 9000, HEALTHCHECK and CMD ["php-fpm"].
```

A complete, copy-paste `Dockerfile.app`, `nginx.conf`, and a full **nginx + mysql + redis** `docker-compose.yml` live in [`examples/`](examples/).

### docker-compose (app + nginx + mysql)

```yaml
services:
  app:
    build: { context: ., dockerfile: Dockerfile }   # FROM minhle202/laravel-fpm:8.3
    environment:
      DB_HOST: mysql
      REDIS_HOST: redis
    volumes: [ "app-code:/var/www/html" ]

  web:
    image: nginx:1.27-alpine
    ports: [ "8080:80" ]
    volumes:
      - ./examples/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - app-code:/var/www/html:ro
    depends_on: [ app ]

  mysql:
    image: mysql:8.4
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: rootsecret

  redis:
    image: redis:7-alpine

volumes:
  app-code:
```

(Full version with healthchecks in [`examples/docker-compose.yml`](examples/docker-compose.yml).)

## How to extend

- **More extensions**: the image uses [`install-php-extensions`](https://github.com/mlocati/docker-php-extension-installer) under the hood. In your app `Dockerfile`, add `USER root` → install → `USER www`.
- **Tune FPM/OPcache**: drop your own files into `/usr/local/etc/php/conf.d/` and `/usr/local/etc/php-fpm.d/` (loaded after the image's `zz-*` files).
- **Queues / scheduler**: run extra containers from the same image with a different `command`, e.g. `php artisan queue:work` or a cron loop for `php artisan schedule:run`.

## Build it yourself

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t minhle202/laravel-fpm:8.3 \
  --push .
```

## Tags

- `8.3`, `latest` → PHP 8.3, Composer 2

## License

MIT © Lê Đức Minh — see [LICENSE](LICENSE).
