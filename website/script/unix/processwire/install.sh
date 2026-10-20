#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download ProcessWire via git, from inside the php container rather than on the host: a
# host-side git clone leaves the tree owned by whatever account ran Waddle, and a rootless-Docker
# container's root can create new files alongside them but can never chown them afterward.
echo "[WADDLE] Downloading ProcessWire version {{tags.website.version.full_raw}}."
docker compose exec -T php git clone --branch {{tags.website.version.full_raw}} --depth 1 \
    https://github.com/processwire/processwire.git "{{project_path 'website/src'}}"

# Drop the git metadata, so the project's repository tracks website/src as plain files.
echo "[WADDLE] Removing git metadata."
docker compose exec -T php find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +

# Copy the blank site profile to the active site directory.
echo "[WADDLE] Setting up site profile."
docker compose exec -T php cp -r "{{project_path 'website/src'}}/site-blank" "{{project_path 'website/src'}}/site"

# Append database credentials and site settings to site/config.php. Credentials are rendered
# as literals rather than read via getenv() at runtime: PHP-FPM clears the process environment
# by default (clear_env), so a getenv() call here would see empty values on every web request
# even though the docker-compose environment passes them into the container.
echo "[WADDLE] Writing configuration."
{ echo; cat "./website/conf/processwire/config-append.php"; } >> "./website/src/site/config.php"

# Ensure required asset directories exist, from inside the container for the same reason as the
# git clone above, a host-side mkdir here would create these fresh directories with the same
# unmappable ownership.
echo "[WADDLE] Creating asset directories."
docker compose exec -T php mkdir -p "{{project_path 'website/src'}}/site/assets/cache" \
    "{{project_path 'website/src'}}/site/assets/files" \
    "{{project_path 'website/src'}}/site/assets/logs" \
    "{{project_path 'website/src'}}/site/assets/sessions" \
    "{{project_path 'website/src'}}/site/assets/tmp"

# Run core and site profile SQL. Preprocess with sed to strip WireDatabaseBackup
# header lines (--- prefix causes a MariaDB syntax error) and replace the
# latin1/MyISAM placeholders ProcessWire ships with utf8mb4/InnoDB equivalents.
echo "[WADDLE] Creating database tables."
for sql_file in "./website/src/wire/core/install.sql" \
                                "./website/src/site/install/install.sql"; do
    [ -f "$sql_file" ] || continue

    # Site profile dumps (e.g. site-blank) declare their own excludeExportTables in a leading
    # WireDatabaseBackup JSON comment: tables whose *schema* is redundantly re-declared here via a
    # DROP+CREATE, but whose data is deliberately left out because wire/core/install.sql (processed
    # just before this file in this same loop) already owns and populates them.
    strip_script=$(mktemp)
    sed -n 's/.*"excludeExportTables":\[\(.*\)\].*/\1/p' "$sql_file" | tr -d '"' | tr ',' '\n' |
        while read -r excluded_table; do
            [ -n "$excluded_table" ] || continue
            printf '/^DROP TABLE IF EXISTS `%s`;/,/^) ENGINE=/d\n' "$excluded_table" >> "$strip_script"
        done

    sed -f "$strip_script" \
            -e '/^---/d' \
            -e 's/DEFAULT CHARSET=latin1/DEFAULT CHARSET=utf8mb4/g' \
            -e 's/ENGINE=MyISAM/ENGINE=InnoDB/g' \
            "$sql_file" | docker compose exec -i db mysql \
                -u "${WADDLE_DB_USER}" \
                -p"${WADDLE_DB_PASSWORD}" \
                "{{public.website.db_name}}"
    rm -f "$strip_script"
done

# Bootstrap ProcessWire via CLI to configure the admin user and site title.
echo "[WADDLE] Configuring admin account and site title."
cat > "./website/src/.waddle_admin_setup.php" << 'PHP'
<?php
chdir("{{project_path 'website/src'}}");
require('./wire/core/ProcessWire.php');
$config = \ProcessWire\ProcessWire::buildConfig('./');
$wire = new \ProcessWire\ProcessWire($config);

// Configure the superuser account.
$user = $wire->users->get($wire->config->superUserPageID);
$user->of(false);
$user->name = getenv('PW_ADMIN_USER');
$user->set('pass', getenv('PW_ADMIN_PASS'));
$user->set('email', getenv('PW_ADMIN_EMAIL'));
$user->save();

// Set the home page title.
$homepage = $wire->pages->get('/');
$homepage->of(false);
$homepage->title = getenv('PW_SITE_TITLE');
$homepage->save();

// Rename the admin page to match Waddle's configured admin route.
$adminPage = $wire->pages->get($wire->config->adminRootPageID);
$adminPage->of(false);
$adminPage->name = getenv('PW_ADMIN_ROUTE');
$adminPage->save();

echo "[WADDLE] Admin account and site title configured.\n";
PHP
docker compose exec -T \
    -e PW_ADMIN_USER="{{public.website.admin_username}}" \
    -e PW_ADMIN_PASS="${WADDLE_ADMIN_PASSWORD}" \
    -e PW_ADMIN_EMAIL="{{public.website.admin_email}}" \
    -e PW_ADMIN_ROUTE="{{public.website.admin_route}}" \
    -e PW_SITE_TITLE="{{public.website.title}}" \
    php php "{{project_path 'website/src'}}/.waddle_admin_setup.php"
rm -f "./website/src/.waddle_admin_setup.php"

# Create installed marker to prevent the web installer from running.
echo "[WADDLE] Marking installation as complete."
docker compose exec -T php touch "{{project_path 'website/src'}}/site/assets/installed.php"

# Remove the web installer entry point. ProcessWire's own bootstrap treats its mere presence as
# "not yet installed" and, on every request, re-attempts installer-only checks (including trying
# to write into site/modules/) regardless of the installed.php marker above.
echo "[WADDLE] Removing web installer."
docker compose exec -T php rm -f "{{project_path 'website/src'}}/install.php"

# Clear out install resources.
docker compose exec -T php rm -rf "{{project_path 'website/src'}}/site/install"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
