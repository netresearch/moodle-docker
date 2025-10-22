# Moodle 4.5 Production Docker Image
# PHP 8.3 + Apache on Debian Bookworm

FROM php:8.3-apache-bookworm

LABEL maintainer="Your Team <team@example.com>"
LABEL description="Moodle 4.5 LMS with PHP 8.3"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Core utilities
    wget \
    curl \
    zip \
    unzip \
    git \
    # Image processing
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    # XML and internationalization
    libxml2-dev \
    libicu-dev \
    # Database clients
    default-mysql-client \
    libpq-dev \
    # LDAP
    libldap2-dev \
    # Sodium (required for Moodle 4.5)
    libsodium-dev \
    # Compression
    libbz2-dev \
    libzip-dev \
    # Other libraries
    libonig-dev \
    libcurl4-openssl-dev \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Configure GD with FreeType and JPEG support
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg

# Configure LDAP
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/

# Install PHP extensions required by Moodle
RUN docker-php-ext-install -j$(nproc) \
    # Core required
    mysqli \
    pdo_mysql \
    pgsql \
    pdo_pgsql \
    # Image processing
    gd \
    # XML
    xml \
    xmlrpc \
    soap \
    # Internationalization
    intl \
    # String handling
    mbstring \
    # Compression
    zip \
    bz2 \
    # Math
    bcmath \
    # System V
    sysvmsg \
    sysvsem \
    sysvshm \
    # Process control
    pcntl \
    # Sockets
    sockets \
    # Other
    exif \
    ftp \
    calendar \
    gettext \
    # Required: sodium
    sodium \
    # Performance
    opcache \
    # LDAP
    ldap

# Install PECL extensions
RUN pecl install redis-6.0.2 && docker-php-ext-enable redis
RUN pecl install apcu-5.1.23 && docker-php-ext-enable apcu
RUN pecl install igbinary-3.2.15 && docker-php-ext-enable igbinary

# Configure PHP for Moodle
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'upload_max_filesize = 100M'; \
    echo 'post_max_size = 100M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_vars = 5000'; \
    echo 'file_uploads = On'; \
    echo 'allow_url_fopen = On'; \
    echo 'session.save_handler = files'; \
    echo 'session.auto_start = 0'; \
    echo 'display_errors = Off'; \
    echo 'log_errors = On'; \
    echo 'error_log = /var/log/apache2/php_error.log'; \
} > /usr/local/etc/php/conf.d/moodle.ini

# Configure OPcache for performance
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=10000'; \
    echo 'opcache.revalidate_freq=60'; \
    echo 'opcache.fast_shutdown=1'; \
    echo 'opcache.enable_cli=0'; \
} > /usr/local/etc/php/conf.d/opcache.ini

# Enable Apache modules
RUN a2enmod rewrite expires headers ssl

# Configure Apache for Moodle
RUN { \
    echo '<Directory /var/www/html>'; \
    echo '    Options -Indexes +FollowSymLinks'; \
    echo '    AllowOverride All'; \
    echo '    Require all granted'; \
    echo '</Directory>'; \
    echo ''; \
    echo 'ServerTokens Prod'; \
    echo 'ServerSignature Off'; \
} > /etc/apache2/conf-available/moodle.conf && \
    a2enconf moodle

# Create moodledata directory
RUN mkdir -p /var/moodledata && \
    chown -R www-data:www-data /var/moodledata && \
    chmod -R 0750 /var/moodledata

# Set working directory
WORKDIR /var/www/html

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Run as www-data user (for better security when possible)
# Note: Apache will still run as root, but app processes run as www-data
USER www-data

# Expose HTTP and HTTPS ports
EXPOSE 80 443

# Switch back to root for entrypoint
USER root

# Start Apache
CMD ["apache2-foreground"]
