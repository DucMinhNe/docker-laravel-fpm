# syntax=docker/dockerfile:1
#
# Example: build a real Laravel app ON TOP OF the laravel-fpm base image.
# Copy this into your Laravel project root as `Dockerfile` and adjust as needed.
#
# Multi-stage so Composer dev tooling never lands in the final runtime image.

ARG BASE=minhle202/laravel-fpm:8.3

# ── Stage 1: install PHP dependencies with Composer ───────────────────────────
FROM ${BASE} AS vendor

WORKDIR /var/www/html

# Copy only the files needed to resolve dependencies first (better layer cache).
COPY composer.json composer.lock ./

# --no-dev / optimized autoloader for production. `composer` ships in the base.
RUN composer install \
        --no-dev \
        --no-interaction \
        --no-progress \
        --prefer-dist \
        --optimize-autoloader \
        --no-scripts

# ── Stage 2: final app image ──────────────────────────────────────────────────
FROM ${BASE} AS app

WORKDIR /var/www/html

# Application source.
COPY --chown=www:www . .

# Vendor dir resolved in stage 1.
COPY --from=vendor --chown=www:www /var/www/html/vendor ./vendor

# Cache Laravel config/routes/views at build time for speed (optional but nice).
# Comment these out if your config depends on runtime env not present at build.
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    || true

# The base image already sets USER www, EXPOSE 9000, HEALTHCHECK and CMD
# ["php-fpm"]. Nothing else required — nginx (separate container) serves
# /var/www/html/public and proxies *.php to this container on port 9000.
