# syntax=docker/dockerfile:1

# ──────────────────────────────────────────────────────────────────────────────
# laravel-fpm — a slim, production-tuned PHP-FPM base image for Laravel apps.
# Multi-stage build: Composer comes from the official composer image, PHP
# extensions are installed for the TARGET platform via mlocati's
# install-php-extensions (which compiles/installs and keeps exactly the runtime
# shared libraries each extension needs, then purges build deps). No arch is
# hardcoded, so the same Dockerfile builds for linux/amd64 and linux/arm64.
# ──────────────────────────────────────────────────────────────────────────────

ARG PHP_VERSION=8.3
ARG COMPOSER_VERSION=2
# Pin the extension installer for reproducible builds.
ARG PHP_EXT_INSTALLER_VERSION=2.11.1

# ── Composer binary (pinned major) ────────────────────────────────────────────
FROM composer:${COMPOSER_VERSION} AS composer

# ── Runtime: the actual base image people FROM ────────────────────────────────
FROM php:${PHP_VERSION}-fpm-alpine AS runtime

ARG PHP_EXT_INSTALLER_VERSION

LABEL org.opencontainers.image.title="laravel-fpm" \
      org.opencontainers.image.description="Slim, production-tuned PHP-FPM base image for Laravel (PHP 8.3, Composer 2, Redis, OPcache)." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.authors="Lê Đức Minh"

# fcgi provides cgi-fcgi, used by the HEALTHCHECK to hit php-fpm's /ping.
RUN apk add --no-cache fcgi

# Install the PHP extensions Laravel apps need. install-php-extensions resolves
# build + runtime deps per architecture, then trims the build deps, so the final
# layer only carries the .so files and the runtime libraries they link against.
ADD https://github.com/mlocati/docker-php-extension-installer/releases/download/${PHP_EXT_INSTALLER_VERSION}/install-php-extensions \
    /usr/local/bin/
RUN chmod +x /usr/local/bin/install-php-extensions \
    && install-php-extensions \
        pdo_mysql \
        mbstring \
        bcmath \
        gd \
        zip \
        exif \
        pcntl \
        opcache \
        redis \
    && rm -rf /usr/local/bin/install-php-extensions /var/cache/apk/* /tmp/*

# Composer for downstream `composer install` during app image builds.
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

# Production php.ini + opcache + php-fpm pool config (loaded after the defaults).
COPY rootfs/ /

# Tiny example document root so the bare base image is smoke-testable standalone
# (a real Laravel app overwrites /var/www/html with its own public/index.php).
COPY public/ /var/www/html/public/

# Create the non-root runtime user/group `www` (uid/gid 1000) and make the
# default Laravel app directory writable by it.
RUN addgroup -g 1000 -S www \
    && adduser -u 1000 -S -G www -h /var/www -s /sbin/nologin www \
    && mkdir -p /var/www/html \
    && chown -R www:www /var/www

WORKDIR /var/www/html

# php-fpm listens on 9000 (tcp) for an upstream nginx/apache.
EXPOSE 9000

# Drop privileges. php-fpm master + workers run as www (see php-fpm.d override).
USER www

# Liveness: hit php-fpm's built-in /ping endpoint (pool sets ping.path=/ping,
# ping.response=pong) over FastCGI via cgi-fcgi.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET \
        cgi-fcgi -bind -connect 127.0.0.1:9000 2>/dev/null | grep -q pong || exit 1

CMD ["php-fpm"]
