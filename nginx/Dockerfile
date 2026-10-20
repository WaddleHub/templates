# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.nginx.docker.from}} AS builder

# Copy GPG keys for verification.
COPY nginx/gpg-keys /tmp/gpg-keys

# Update repository and install packages required for compilation routine.
RUN set -eux; \
    {{get_additional_repos public.nginx.docker}}{{update_repo public.nginx.docker}}; \
    {{install public.nginx.docker packages.nginx.compiletime}}; \
    if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://nginx.org/download/nginx-{{tags.nginx.version.raw}}.tar.gz)" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find Nginx tar."; \
    exit 1; \
    fi; \
    curl -L --retry 3 --retry-delay 5 https://nginx.org/download/nginx-{{tags.nginx.version.raw}}.tar.gz -o /tmp/nginx.tar.gz; \
    {{#if (not_empty verifications.nginx.gpg_keys)}}
if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://nginx.org/download/nginx-{{tags.nginx.version.raw}}.tar.gz.asc)" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find Nginx ASC file."; \
    exit 1; \
    fi; \
    curl -L --retry 3 --retry-delay 5 https://nginx.org/download/nginx-{{tags.nginx.version.raw}}.tar.gz.asc -o /tmp/nginx.tar.gz.asc; \
    for key_file in /tmp/gpg-keys/*.asc; do \
    gpg --import "$key_file"; \
    done; \
    gpg --batch --verify /tmp/nginx.tar.gz.asc /tmp/nginx.tar.gz; \
    rm -rf /tmp/gpg-keys; \
    {{/if}}
mkdir -p /tmp/nginx; \
    tar -C /tmp/nginx -xzf /tmp/nginx.tar.gz --no-same-owner --strip-components=1; \
    mkdir -p "{{public.nginx.prefix}}"; \
    cd /tmp/nginx; \
    {{#if public.nginx.letsencrypt}}
    git clone https://github.com/nginx/nginx-acme /tmp/nginx-acme; \
    {{/if}}./configure {{parse_compile_options 'nginx' tags.nginx.version.raw public.nginx.compile_options}}; \
    make -C /tmp/nginx -s -j{{public.nginx.parallel_build_jobs}}; \
    make -C /tmp/nginx install

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.nginx.docker.from}}

ENV PATH="{{project_path 'bin'}}:{{public.nginx.prefix}}/sbin:$PATH"

# Copy Nginx from builder stage.
COPY --from=builder "{{public.nginx.prefix}}" "{{public.nginx.prefix}}"
{{#if public.nginx.letsencrypt}}
# CA certificates are required for the nginx-acme module to verify the ACME server.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
{{/if}}

# Install required packages and configure the environment.
# The compiled conf dir is copied to /opt/nginx_conf (seeded by run.sh at startup),
# then replaced with a symlink to the project's nginx/conf — exposing it to the project.
RUN set -eux; \
    {{get_additional_repos public.nginx.docker}}{{update_repo public.nginx.docker}}; \
    {{install public.nginx.docker packages.nginx.runtime}}; \
    sed -i -e 's#http {#http {\n    resolver 127.0.0.11 valid=30s ipv6=off;\n    include "{{project_path 'nginx/conf/conf.d/*.conf'}}";\n#' "{{public.nginx.prefix}}/conf/nginx.conf"; \
    sed -i -e '1s|^|include "{{project_path 'nginx/conf/modules.conf'}}";\n|' "{{public.nginx.prefix}}/conf/nginx.conf"; \
    ln -s "{{project_path 'website/src'}}" "{{paths.web_src_shortcut}}"; \
    cp -r "{{public.nginx.prefix}}/conf" /opt/nginx_conf; \
    rm -r "{{public.nginx.prefix}}/conf"; \
    ln -s "{{project_path 'nginx/conf'}}" "{{public.nginx.prefix}}/conf"; \
    nginx -v
