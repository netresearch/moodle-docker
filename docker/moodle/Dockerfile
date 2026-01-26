# Moodle 5.x Runtime Image
# PHP 8.4 FPM on Alpine

FROM php:8.4-fpm-alpine

LABEL maintainer="Netresearch <info@netresearch.de>"
LABEL description="Moodle 5.x PHP-FPM runtime"

# Build dependencies (removed after compile)
ARG BUILD_DEPS="autoconf g++ make libpng-dev libjpeg-turbo-dev freetype-dev \
    libxml2-dev icu-dev libzip-dev libsodium-dev oniguruma-dev \
    postgresql-dev openldap-dev bzip2-dev curl-dev"

# Runtime dependencies
ARG RUNTIME_DEPS="bash curl git unzip \
    libpng libjpeg-turbo freetype libxml2 icu-libs libzip libsodium \
    oniguruma postgresql-libs libldap libbz2 \
    fcgi"

# Install dependencies and PHP extensions
RUN apk add --no-cache $RUNTIME_DEPS $BUILD_DEPS \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j$(nproc) \
        mysqli pdo_mysql \
        pgsql pdo_pgsql \
        gd \
        xml soap \
        intl \
        mbstring \
        zip bz2 \
        bcmath \
        opcache \
        ldap \
        sodium \
        exif \
        sockets \
        pcntl \
    && pecl install redis igbinary apcu \
    && docker-php-ext-enable redis igbinary apcu \
    && apk del $BUILD_DEPS \
    && rm -rf /tmp/* /var/cache/apk/*

# PHP configuration for Moodle
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'upload_max_filesize = 100M'; \
    echo 'post_max_size = 100M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_vars = 5000'; \
    echo 'file_uploads = On'; \
    echo 'session.save_handler = files'; \
    echo 'display_errors = Off'; \
    echo 'log_errors = On'; \
} > /usr/local/etc/php/conf.d/moodle.ini

# OPcache configuration with JIT
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=0'; \
    echo 'opcache.jit=1255'; \
    echo 'opcache.jit_buffer_size=128M'; \
} > /usr/local/etc/php/conf.d/opcache.ini

# PHP-FPM pool configuration
RUN { \
    echo '[www]'; \
    echo 'pm = dynamic'; \
    echo 'pm.max_children = 50'; \
    echo 'pm.start_servers = 5'; \
    echo 'pm.min_spare_servers = 5'; \
    echo 'pm.max_spare_servers = 35'; \
    echo 'pm.max_requests = 500'; \
    echo 'pm.status_path = /status'; \
    echo 'ping.path = /ping'; \
    echo 'ping.response = pong'; \
} > /usr/local/etc/php-fpm.d/zz-moodle.conf

# PHP-FPM healthcheck script
RUN echo '#!/bin/sh' > /usr/local/bin/php-fpm-healthcheck \
    && echo 'SCRIPT_NAME=/ping SCRIPT_FILENAME=/ping REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 | grep -q pong' >> /usr/local/bin/php-fpm-healthcheck \
    && chmod +x /usr/local/bin/php-fpm-healthcheck

# Create directories
RUN mkdir -p /var/www/html /var/moodledata \
    && chown -R www-data:www-data /var/www/html /var/moodledata

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /var/www/html

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
