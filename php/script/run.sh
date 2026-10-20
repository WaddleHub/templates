#!/bin/sh -eux

CONF_DIR="{{project_path 'php/conf'}}"

# Create session, log and source directories.
mkdir -p "{{project_path 'ssl'}}" "{{project_path 'php/data/sessions'}}" "{{project_path 'php/log'}}" "{{project_path 'website/src'}}"
{{#if public.php.install_cron}}

# Create cron log for accurate permissions.
touch "{{project_path 'php/log/cron.log'}}"
{{/if}}

# Publish updated config files to host directory.
rsync -ru /opt/php_conf/ "$CONF_DIR/"

# Setup PHP FPM config files.
if [ ! -f "$CONF_DIR/php-fpm.conf" ] && [ -f "$CONF_DIR/php-fpm.conf.default" ]; then
    cp "$CONF_DIR/php-fpm.conf.default" "$CONF_DIR/php-fpm.conf"
    printf "\ninclude={{project_path 'php/conf/pool.d'}}/*.conf" >> "$CONF_DIR/php-fpm.conf"
fi

if [ ! -f "$CONF_DIR/php-fpm.d/www.conf" ] && [ -f "$CONF_DIR/php-fpm.d/www.conf.default" ]; then
    cp "$CONF_DIR/php-fpm.d/www.conf.default" "$CONF_DIR/php-fpm.d/www.conf"
fi

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} \
    "{{project_path 'php/data/sessions'}}" "{{project_path 'php/log'}}" 2>/dev/null || true

# Same as above, for each platform's own writable runtime directories. Avoid running this on
# a fresh install of the platform since it would otherwise create directories and refuse the
# platform installer to run against a non-empty target.
if [ -n "$(ls -A "{{project_path 'website/src'}}" 2>/dev/null)" ]; then
    : # No-op so the block is still valid shell for a platform with no daemon-owned dirs.
    {{#each (get_daemon_owned_dirs public.website.platform)}}
    mkdir -p "{{project_path 'website/src'}}/{{this}}"
    chown -R {{get_daemon_user ../public.php.docker}}:{{get_daemon_group ../public.php.docker}} \
        "{{project_path 'website/src'}}/{{this}}" 2>/dev/null || true
    {{/each}}
fi
{{#each (get_bin_links public.website.platform)}}

# Symlink the platform CLI assets to the project bin directory so they appear on PATH inside
# of the containers.
if [ ! -L "{{project_path 'bin'}}/{{this.name}}" ]; then
    ln -s "{{project_path 'website/src'}}/{{this.target}}" "{{project_path 'bin'}}/{{this.name}}"
fi
{{/each}}

exec "${@}"
