# -------------------------------------------------
# Compiletime routine.
# -------------------------------------------------
FROM {{public.php.docker.from}} AS builder

# Copy GPG keys for verification.
COPY php/gpg-keys /tmp/gpg-keys

ENV PATH="{{project_path 'bin'}}:{{public.php.prefix}}/bin:{{public.php.prefix}}/sbin:{{project_path 'website/src/vendor/bin'}}:{{project_path 'website/src/bin'}}:{{#if public.composer.install}}{{project_path 'composer/conf/home/vendor/bin'}}{{/if}}:${PATH}"

# Update repository and install packages required by compiler routine.
RUN set -eux; \
    export CPPFLAGS="-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE"; \
    export LDFLAGS="-pie -Wl,-O1"; \
    export CFLAGS="-fpic -fpie -fstack-protector-strong -O2"; \
    {{get_additional_repos public.php.docker}}{{update_repo public.php.docker}}; \
    {{install public.php.docker packages.php.compiletime}}; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    {{#if (version_compare tags.php.version.raw '<' '5.5.0')}}
PHP_TAR_EXT="gz"; \
    PHP_TAR_FLAG="z"; \
    {{else}}
PHP_TAR_EXT="xz"; \
    PHP_TAR_FLAG="J"; \
    {{/if}}
if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://www.php.net/distributions/{{tags.php.version.full_raw}}.tar.${PHP_TAR_EXT})" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find PHP tar."; \
    exit 1; \
    fi; \
    curl -L --retry 3 --retry-delay 5 https://www.php.net/distributions/{{tags.php.version.full_raw}}.tar.${PHP_TAR_EXT} -o /tmp/php.tar.${PHP_TAR_EXT}; \
    {{#if (not_empty verifications.php.gpg_keys)}}
if [ "$(curl -o /dev/null --silent -LIw '%{http_code}' --retry 3 --retry-delay 5 https://www.php.net/distributions/{{tags.php.version.full_raw}}.tar.${PHP_TAR_EXT}.asc)" != "200" ]; then \
    echo "[WADDLE ERROR] Failed to find PHP ASC file."; \
    exit 1; \
    fi; \
    curl -L --retry 3 --retry-delay 5 https://www.php.net/distributions/{{tags.php.version.full_raw}}.tar.${PHP_TAR_EXT}.asc -o /tmp/php.tar.${PHP_TAR_EXT}.asc; \
    for key_file in /tmp/gpg-keys/*.asc; do \
    gpg --import "$key_file"; \
    done; \
    gpg --batch --verify /tmp/php.tar.${PHP_TAR_EXT}.asc /tmp/php.tar.${PHP_TAR_EXT}; \
    rm -rf /tmp/gpg-keys; \
    {{/if}}
for src_dest in \
    "/usr/lib/libc-client.a:/usr/lib/x86_64-linux-gnu/libc-client.a" \
    "/usr/include/x86_64-linux-gnu/gmp.h:/usr/include/gmp.h" \
    "/usr/include/x86_64-linux-gnu/curl:/usr/include/curl"; do \
    src="${src_dest%%:*}"; \
    dest="${src_dest#*:}"; \
    if [ -e "$src" ] && [ ! -e "$dest" ]; then \
    mkdir -p "$(dirname "$dest")"; \
    ln -s "$src" "$dest"; \
    fi; \
    done; \
    mkdir -p /tmp/php; \
    tar -C /tmp/php -x${PHP_TAR_FLAG}f /tmp/php.tar.${PHP_TAR_EXT} --no-same-owner --strip-components=1; \
    mkdir -p "{{public.php.prefix}}"; \
    cd /tmp/php; \
    ./configure \
    --build="$gnuArch" \
    {{#if (version_compare tags.php.version.raw '>=' '8.1.0')}}
$(test "$gnuArch" = 's390x-linux-musl' && echo '--without-pcre-jit') \
    {{/if}}
{{parse_compile_options 'php' tags.php.version.raw public.php.compile_options}}; \
    make -C /tmp/php -s -j"$(nproc)"; \
    make -C /tmp/php install; \
    mkdir -p "{{public.php.prefix}}/etc"; \
    cp -f /tmp/php/php.ini-production "{{public.php.prefix}}/etc/php.ini"; \
    mkdir -p "{{public.php.prefix}}/etc/conf.d"; \
    touch "{{public.php.prefix}}/etc/conf.d/ext.ini"; \
    {{#if (has_compile_option 'pear' public.php.compile_options)}}
pecl update-channels; \
    pear config-set php_ini "{{public.php.prefix}}/etc/conf.d/ext.ini"; \
    {{/if}}
php --version

# Temporarily re-assign PHP scandir to enable extension dependency detection.
ENV PHP_INI_SCAN_DIR="{{public.php.prefix}}/etc/conf.d"

{{#if (not_empty php_extensions.packages.compiletime)}}
# Install packages required by PHP extensions (PIE & PECL).
RUN set -eux; \
    {{install public.php.docker php_extensions.packages.compiletime}}
{{/if}}

{{#if (not_empty php_extensions.pecl)}}
# Install PECL extensions.
{{#each php_extensions.pecl}}
{{#if @first}}RUN set -eux;{{else}} {{/if}} yes '' | pecl install -o "{{get_pecl_extension this}}"{{#unless @last}}; \ {{/unless}}
{{/each}}
{{/if}}

{{#if (not_empty php_extensions.pie)}}
# Install PIE and PIE extensions.
RUN set -eux; \
    curl -L --retry 3 --retry-delay 5 https://github.com/php/pie/releases/latest/download/pie.phar -o /usr/local/bin/pie; \
    chmod +x /usr/local/bin/pie; \
    {{#each php_extensions.pie}}
pie install "{{get_pie_extension this}}"{{#unless @last}}; \
    {{/unless}}{{/each}}
{{/if}}

# -------------------------------------------------
# Runtime environment.
# -------------------------------------------------
FROM {{public.php.docker.from}}

ENV PATH="{{project_path 'bin'}}:{{public.php.prefix}}/bin:{{public.php.prefix}}/sbin:{{project_path 'website/src/vendor/bin'}}:{{project_path 'website/src/bin'}}:{{#if public.composer.install}}{{project_path 'composer/conf/home/vendor/bin'}}{{/if}}:${PATH}"
ENV COMPOSER_HOME={{project_path 'composer/conf/home'}}

# Copy PHP from builder stage.
COPY --from=builder "{{public.php.prefix}}" "{{public.php.prefix}}"

# Install required packages and configure environment.
RUN set -eux; \
    {{get_additional_repos public.php.docker}}{{update_repo public.php.docker}}; \
    {{install public.php.docker packages.php.runtime}}; \
    {{#if (not_empty php_extensions.packages.runtime)}}
    {{install public.php.docker php_extensions.packages.runtime}}; \
    {{/if}}
    if [ -n "$(command -v apparmor)" ] && [ -f /etc/apparmor.d/usr.bin.msmtp ]; then \
    mkdir -p /etc/apparmor.d/disable; \
    ln -s /etc/apparmor.d/usr.bin.msmtp /etc/apparmor.d/disable/usr.bin.msmtp; \
    apparmor_parser -R /etc/apparmor.d/usr.bin.msmtp; \
    fi; \
    ln -s {{project_path 'website/src'}} {{paths.web_src_shortcut}}; \
    cp -r "{{public.php.prefix}}/etc" "/opt/php_conf"; \
    rm -r "{{public.php.prefix}}/etc"; \
    ln -s "{{project_path 'php/conf'}}" "{{public.php.prefix}}/etc"; \
    php --version

{{#if (is_equal public.website.platform 'symfony')}}
# Symfony specific directives.
#
# The git identity is system-wide (/etc/gitconfig) so it applies whatever HOME
# and UID the container runs with, for anything that commits inside website/src.
RUN set -eux; \
    git config --system user.email "{{public.website.admin_email}}"; \
    git config --system user.name "{{public.website.admin_username}}"
{{/if}}
