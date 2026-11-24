# syntax=docker/dockerfile:1

FROM nginx:mainline-alpine AS base

# Use matching runtime libraries in both the compiler and final image.
RUN apk add --no-cache --upgrade \
    libcrypto3 libmaxminddb-libs libssl3 musl pcre2 zlib zstd-libs

FROM base AS build

RUN apk add --no-cache \
    build-base cmake curl libmaxminddb-dev linux-headers \
    openssl-dev pcre2-dev zlib-dev zstd-dev

WORKDIR /src

# BuildKit resolves each default branch and fetches its Git submodules.
ADD https://github.com/google/ngx_brotli.git ngx_brotli/
ADD https://github.com/leev/ngx_http_geoip2_module.git ngx_http_geoip2_module/
ADD https://github.com/tokers/zstd-nginx-module.git zstd-nginx-module/

RUN <<'BUILD_MODULES'
set -eu

cmake -S ngx_brotli/deps/brotli -B ngx_brotli/deps/brotli/out \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
cmake --build ngx_brotli/deps/brotli/out --parallel "$(nproc)" --target brotlienc
BUILD_MODULES

ARG NGINX_SOURCE_VERSION

RUN <<'BUILD_NGINX'
set -eu
: "${NGINX_SOURCE_VERSION:?Set the NGINX Mainline version with --build-arg NGINX_SOURCE_VERSION}"
curl -fsSL --retry 3 "https://nginx.org/download/nginx-$NGINX_SOURCE_VERSION.tar.gz" -o nginx.tar.gz
mkdir nginx
tar -xzf nginx.tar.gz --strip-components=1 -C nginx
cd nginx

# Use the base image's paths and feature flags, preserving quoted compiler flags.
base_config=$(nginx -V 2>&1)
configure_args=$(printf '%s\n' "$base_config" | sed -n 's/^configure arguments: //p')
test -n "$configure_args"
eval "set -- $configure_args"
./configure "$@" \
    --add-module=/src/ngx_brotli \
    --add-module=/src/ngx_http_geoip2_module \
    --add-module=/src/zstd-nginx-module
make -j"$(nproc)"
install -D -m755 -s objs/nginx /out/nginx

licenses=/out/licenses
install -Dm644 LICENSE "$licenses/copyright"
install -Dm644 /src/ngx_brotli/LICENSE "$licenses/ngx_brotli.LICENSE"
install -Dm644 /src/ngx_brotli/deps/brotli/LICENSE "$licenses/brotli.LICENSE"
install -Dm644 /src/ngx_http_geoip2_module/LICENSE "$licenses/ngx_http_geoip2_module.LICENSE"
install -Dm644 /src/zstd-nginx-module/LICENSE "$licenses/zstd-nginx-module.LICENSE"
BUILD_NGINX

FROM base

ARG NGINX_SOURCE_VERSION
ENV NGINX_VERSION="$NGINX_SOURCE_VERSION"
LABEL org.opencontainers.image.version="$NGINX_SOURCE_VERSION"

COPY --from=build /out/nginx /usr/sbin/nginx
COPY --from=build /out/licenses/ /usr/share/licenses/nginx-custom/

RUN nginx -t
