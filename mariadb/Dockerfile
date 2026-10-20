# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.mariadb.docker.from}} AS builder

ENV PATH="{{public.mariadb.prefix}}/bin:{{project_path 'bin'}}:$PATH"
ENV CC=gcc
ENV CXX=g++

# With the DuckDB plugin turned off, its source (a very large submodule) isn't downloaded either.
RUN set -eux; \
    {{get_additional_repos public.mariadb.docker}}{{update_repo public.mariadb.docker}}; \
    {{install public.mariadb.docker packages.mariadb.compiletime}}; \
    if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://github.com/MariaDB/server.git)" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find MariaDB git repository!"; \
    exit 1; \
    fi; \
    mkdir -p /tmp/mariadb; \
    git clone --depth 1 --branch "{{tags.mariadb.name}}" https://github.com/MariaDB/server.git /tmp/mariadb; \
    git -C /tmp/mariadb{{#if (has_compile_option 'PLUGIN_DUCKDB' public.mariadb.compile_options 'NO')}} \
        -c submodule.storage/duckdb/third_parties/duckdb.update=none{{/if}} \
        submodule update --init --recursive; \
    mkdir -p "{{public.mariadb.prefix}}"; \
    cmake -S /tmp/mariadb -B /tmp/mariadb {{parse_compile_options 'mariadb' tags.mariadb.version.raw public.mariadb.compile_options}}; \
    make -C /tmp/mariadb -s -j{{public.mariadb.parallel_build_jobs}}; \
    make -C /tmp/mariadb install

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.mariadb.docker.from}}

ENV PATH="{{public.mariadb.prefix}}/bin:{{project_path 'bin'}}:$PATH"

# Copy MariaDB to runtime environment.
COPY --from=builder "{{public.mariadb.prefix}}" "{{public.mariadb.prefix}}"

# Install required packages and configure environment.
RUN set -eux; \
    {{get_additional_repos public.mariadb.docker}}{{update_repo public.mariadb.docker}}; \
    {{install public.mariadb.docker packages.mariadb.runtime}}; \
    mariadb --version
