<?php

/**
 * Minimal example document root shipped INSIDE the base image so it can be
 * smoke-tested standalone (without a real Laravel app in front of php-fpm).
 *
 * A real Laravel app replaces /var/www/html with its own code, whose own
 * public/index.php boots the framework. This file is purely a placeholder so
 * `docker run` of the bare base image responds to requests and proves the
 * runtime (extensions, fpm, user) is healthy.
 *
 * Routes:
 *   GET /            -> small JSON banner
 *   GET /healthz     -> {"status":"ok"} for app-level health probes
 */

declare(strict_types=1);

header('Content-Type: application/json');

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if ($path === '/healthz') {
    http_response_code(200);
    echo json_encode([
        'status'     => 'ok',
        'php'        => PHP_VERSION,
        'extensions' => [
            'pdo_mysql' => extension_loaded('pdo_mysql'),
            'mbstring'  => extension_loaded('mbstring'),
            'bcmath'    => extension_loaded('bcmath'),
            'gd'        => extension_loaded('gd'),
            'zip'       => extension_loaded('zip'),
            'exif'      => extension_loaded('exif'),
            'pcntl'     => extension_loaded('pcntl'),
            'opcache'   => extension_loaded('Zend OPcache'),
            'redis'     => extension_loaded('redis'),
        ],
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    exit;
}

http_response_code(200);
echo json_encode([
    'image'   => 'laravel-fpm',
    'message' => 'PHP-FPM base image for Laravel is running. FROM this image to build your app.',
    'php'     => PHP_VERSION,
    'sapi'    => PHP_SAPI,
    'user'    => function_exists('posix_getpwuid') && function_exists('posix_geteuid')
        ? (posix_getpwuid(posix_geteuid())['name'] ?? 'unknown')
        : (getenv('USER') ?: 'www'),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
