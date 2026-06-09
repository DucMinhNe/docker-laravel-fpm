# laravel-fpm

A slim, production-tuned **PHP-FPM base image for Laravel**. `FROM` it, drop in your app, ship.

## Pull

```
docker pull minhle202/laravel-fpm:8.3
```

## What's inside

- **PHP 8.3** on Alpine (`php:8.3-fpm-alpine`), multi-stage build → small final image
- Extensions: `pdo_mysql`, `mbstring`, `bcmath`, `gd`, `zip`, `exif`, `pcntl`, `opcache`, **`redis`**
- **Composer 2** at `/usr/local/bin/composer`
- **OPcache + tracing JIT** tuned for production (timestamp validation off, large file cache)
- php.ini tuned: `memory_limit=256M`, 32M uploads, errors to stderr, `expose_php=Off`
- Runs as **non-root `www`** (uid/gid 1000), `WORKDIR /var/www/html`
- **HEALTHCHECK** via php-fpm's `/ping` endpoint
- Multi-arch: **linux/amd64** + **linux/arm64**

## Ports

- `9000` — FastCGI (TCP). Point nginx/apache at it.

## Use as your Laravel base

```dockerfile
FROM minhle202/laravel-fpm:8.3
WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction
COPY --chown=www:www . .
# USER www, EXPOSE 9000, HEALTHCHECK and CMD ["php-fpm"] are inherited.
```

Serve it with a separate `nginx:1.27-alpine` container proxying `*.php` to `app:9000`, with MySQL and Redis alongside. A ready-to-use `Dockerfile`, `nginx.conf` and `docker-compose.yml` are in the GitHub repo's `examples/` directory.

## Quick smoke test

The image ships a tiny `public/index.php` with a `/healthz` route so you can verify the runtime standalone:

```
docker run -d --name fpm minhle202/laravel-fpm:8.3
docker exec fpm sh -c \
 'SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
  cgi-fcgi -bind -connect 127.0.0.1:9000'
# -> pong
```

## Extend

Add extensions in your app image with `USER root` → `install-php-extensions ...` → `USER www`. Override PHP/FPM config by adding files under `/usr/local/etc/php/conf.d/` or `/usr/local/etc/php-fpm.d/`.

## License

MIT © Lê Đức Minh
