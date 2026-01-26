# nginx with Brotli + HTTP/2 + HTTP/3 (QUIC)
# Multi-stage build to compile brotli module

FROM nginx:1.29-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    gcc \
    g++ \
    make \
    pcre-dev \
    openssl-dev \
    zlib-dev \
    linux-headers \
    brotli-dev

# Clone brotli module
RUN git clone --recurse-submodules -j8 \
    https://github.com/google/ngx_brotli.git /tmp/ngx_brotli

# Download nginx source matching installed version
RUN NGINX_VERSION=$(nginx -v 2>&1 | sed 's/.*nginx\///' ) && \
    wget -O /tmp/nginx.tar.gz \
    "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" && \
    tar -xzf /tmp/nginx.tar.gz -C /tmp

# Build brotli module as dynamic module
RUN NGINX_VERSION=$(nginx -v 2>&1 | sed 's/.*nginx\///' ) && \
    cd /tmp/nginx-${NGINX_VERSION} && \
    ./configure \
        --with-compat \
        --add-dynamic-module=/tmp/ngx_brotli && \
    make modules && \
    cp objs/ngx_http_brotli_filter_module.so /tmp/ && \
    cp objs/ngx_http_brotli_static_module.so /tmp/

# =============================================================================
# Final image
# =============================================================================
FROM nginx:1.29-alpine

LABEL maintainer="Netresearch <info@netresearch.de>"
LABEL description="nginx with Brotli, HTTP/2, and HTTP/3 for Moodle 5.x"

# Install runtime dependencies
RUN apk add --no-cache \
    brotli-libs \
    curl \
    openssl

# Copy brotli modules from builder
COPY --from=builder /tmp/ngx_http_brotli_filter_module.so /usr/lib/nginx/modules/
COPY --from=builder /tmp/ngx_http_brotli_static_module.so /usr/lib/nginx/modules/

# Create SSL directory
RUN mkdir -p /etc/nginx/ssl

# Generate self-signed certificate for development
# Production deployments should mount real certificates
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/CN=localhost/O=Moodle Docker/C=DE"

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost/nginx-health || exit 1

# Expose HTTP, HTTPS (TCP), and HTTPS (UDP for HTTP/3)
EXPOSE 80 443 443/udp

CMD ["nginx", "-g", "daemon off;"]
