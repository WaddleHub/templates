# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.redis.docker.from}} AS builder

ENV PREFIX={{public.redis.prefix}}

# Update repository and install packages required for compilation routine.
RUN set -eux; \
    {{get_additional_repos public.redis.docker}}{{update_repo public.redis.docker}}; \
    {{install public.redis.docker packages.redis.compiletime}}; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    dpkgArch="$(dpkg --print-architecture)"; \
    JEMALLOC_CONFIGURE_OPTS="--build=$gnuArch --with-lg-hugepage=21"; \
    case "${dpkgArch##*-}" in \
        amd64 | i386 | x32) JEMALLOC_CONFIGURE_OPTS="$JEMALLOC_CONFIGURE_OPTS --with-lg-page=12" ;; \
        *) JEMALLOC_CONFIGURE_OPTS="$JEMALLOC_CONFIGURE_OPTS --with-lg-page=16" ;; \
    esac; \
    export JEMALLOC_CONFIGURE_OPTS; \
    if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 {{tags.redis.tar}})" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find Redis download!"; \
    exit 1; \
    fi; \
    mkdir -p /tmp/redis; \
    curl -fL --retry 3 --retry-delay 5 {{tags.redis.tar}} -o /tmp/redis.tar.gz; \
    tar -C /tmp/redis -xzf /tmp/redis.tar.gz --no-same-owner --strip-components=1; \
    mkdir -p {{public.redis.prefix}}/conf; \
    cp /tmp/redis/redis.conf {{public.redis.prefix}}/conf; \
    make -C /tmp/redis -s -j{{public.redis.parallel_build_jobs}}; \
    make -C /tmp/redis install

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.redis.docker.from}}

ENV PATH="{{project_path 'bin'}}:{{public.redis.prefix}}/bin:$PATH"

# Copy Redis from builder stage.
COPY --from=builder {{public.redis.prefix}} {{public.redis.prefix}}

RUN set -eux; \
    {{get_additional_repos public.redis.docker}}{{update_repo public.redis.docker}}; \
    {{install public.redis.docker packages.redis.runtime}}; \
    cp -r {{public.redis.prefix}}/conf "/opt/redis_conf"; \
    rm -r {{public.redis.prefix}}/conf; \
    ln -s "{{project_path 'redis/conf'}}" {{public.redis.prefix}}/conf; \
    redis-cli --version; \
    redis-server --version
