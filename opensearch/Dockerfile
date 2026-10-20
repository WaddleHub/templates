# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.opensearch.docker.from}} AS builder

# Copy GPG keys for verification.
COPY opensearch/gpg-keys /tmp/gpg-keys

ENV PREFIX="{{public.opensearch.prefix}}"

RUN set -eux; \
    case "$(uname -m)" in \
    x86_64) ARCHITECTURE="x64" ;; \
    aarch64 | arm64) ARCHITECTURE="arm64" ;; \
    *) echo "[WADDLE ERROR] Unsupported architecture for OpenSearch: $(uname -m)"; exit 1 ;; \
    esac; \
    VERSION="{{tags.opensearch.version.raw}}"; \
    ARCHIVE="opensearch-$VERSION-linux-$ARCHITECTURE.tar.gz"; \
    BASE_URL="https://artifacts.opensearch.org/releases/bundle/opensearch/$VERSION"; \
    {{get_additional_repos public.opensearch.docker}}{{update_repo public.opensearch.docker}}; \
    {{install public.opensearch.docker packages.opensearch.compiletime}}; \
    cd /tmp; \
    HTTP_CODE="$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 "$BASE_URL/$ARCHIVE")"; \
    if [ "$HTTP_CODE" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find OpenSearch tar."; \
    exit 1; \
    fi; \
    curl -fL --retry 3 --retry-delay 5 -O "$BASE_URL/$ARCHIVE"; \
    {{#if (not_empty verifications.opensearch.gpg_keys)}}
curl -fL --retry 3 --retry-delay 5 -O "$BASE_URL/$ARCHIVE.sig"; \
    for key_file in /tmp/gpg-keys/*.asc; do \
    gpg --import "$key_file"; \
    done; \
    gpg --batch --verify "/tmp/$ARCHIVE.sig" "/tmp/$ARCHIVE"; \
    rm -f "/tmp/$ARCHIVE.sig"; \
    rm -rf /tmp/gpg-keys; \
    {{/if}}
    mkdir -p "$PREFIX"; \
    tar -C "$PREFIX" -xzf "/tmp/$ARCHIVE" --no-same-owner --strip-components=1; \
    rm -f "/tmp/$ARCHIVE"; \
    chmod -R 755 "$PREFIX/jdk"; \
    find "$PREFIX/config" -type d -exec chmod 755 {} \;; \
    find "$PREFIX/config" -type f -exec chmod 644 {} \;; \
    rm -rf "$PREFIX/logs"; \
    ln -s "{{project_path 'opensearch/log'}}" "$PREFIX/logs"

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.opensearch.docker.from}}

ENV PATH="{{public.opensearch.prefix}}/bin:{{project_path 'bin'}}:$PATH"
ENV OPENSEARCH_JAVA_OPTS="-Xms{{public.opensearch.jvm_heap_size}}m -Xmx{{public.opensearch.jvm_heap_size}}m"
ENV OPENSEARCH_PATH_CONF="{{project_path 'opensearch/conf'}}"

# Copy OpenSearch from builder stage.
COPY --from=builder "{{public.opensearch.prefix}}" "{{public.opensearch.prefix}}"

RUN set -eux; \
    {{get_additional_repos public.opensearch.docker}}{{update_repo public.opensearch.docker}}; \
    {{install public.opensearch.docker packages.opensearch.runtime}}; \
    "{{public.opensearch.prefix}}/jdk/bin/java" -version
