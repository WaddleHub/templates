$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download ProcessWire via git, from inside the php container for accurate permissions.
# Composer's dist archive does not include the site profiles (site-default/, site-blank/, etc.),
# so git clone is required.
Write-Host "[WADDLE] Downloading ProcessWire version {{tags.website.version.full_raw}}."
docker compose exec -T php git clone --branch {{tags.website.version.full_raw}} --depth 1 `
    https://github.com/processwire/processwire.git "{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to download ProcessWire." }

# Drop the git metadata, so the project's repository tracks website/src as plain files.
Write-Host "[WADDLE] Removing git metadata."
docker compose exec -T php find "{{project_path 'website/src'}}" -name .git -prune `
    -exec rm -rf '{}' +
if ($LASTEXITCODE -ne 0) { throw "Failed to remove git metadata." }

# Copy the blank site profile to the active site directory.
Write-Host "[WADDLE] Setting up site profile."
docker compose exec -T php cp -r "{{project_path 'website/src'}}/site-blank" "{{project_path 'website/src'}}/site"
if ($LASTEXITCODE -ne 0) { throw "Failed to set up site profile." }

# Append database credentials and site settings to site/config.php. Credentials are rendered
# as literals rather than read via getenv() at runtime: PHP-FPM clears the process environment
# by default (clear_env), so a getenv() call here would see empty values on every web request
# even though the docker-compose environment passes them into the container. Appended from
# inside the container, so the file keeps its LF line endings.
Write-Host "[WADDLE] Writing configuration."
docker compose exec -T php sh -c "{ echo; cat '{{project_path 'website/conf/processwire/config-append.php'}}'; } >> '{{project_path 'website/src'}}/site/config.php'"
if ($LASTEXITCODE -ne 0) { throw "Failed to write configuration." }

# Ensure required asset directories exist.
Write-Host "[WADDLE] Creating asset directories."
docker compose exec -T php sh -c "mkdir -p '{{project_path 'website/src'}}/site/assets/cache' '{{project_path 'website/src'}}/site/assets/files' '{{project_path 'website/src'}}/site/assets/logs' '{{project_path 'website/src'}}/site/assets/sessions' '{{project_path 'website/src'}}/site/assets/tmp'"
if ($LASTEXITCODE -ne 0) { throw "Failed to create asset directories." }

# Run core and site profile SQL. Preprocess to strip WireDatabaseBackup
# header lines (--- prefix causes a MariaDB syntax error) and replace the
# latin1/MyISAM placeholders ProcessWire ships with utf8mb4/InnoDB equivalents.
#
# Also strips, per file, any DROP+CREATE TABLE block for a table listed in that file's own
# leading "excludeExportTables" JSON metadata: site profile dumps (e.g. site-blank) redundantly
# re-declare the *schema* for tables they don't own data for (already populated by
# wire/core/install.sql, processed just before the site file in this same loop), with no data of
# their own to follow. Executing that DROP+CREATE anyway silently wipes real data the core import
# just inserted.
Write-Host "[WADDLE] Creating database tables."
# Each file is preprocessed inside the php container and piped into the db container. A missing
# file (site profiles without their own install.sql) is skipped.
foreach ($sqlFile in @("{{project_path 'website/src'}}/wire/core/install.sql", "{{project_path 'website/src'}}/site/install/install.sql")) {
    $sqlScript = @'
set -eu
[ -f "SQLFILE_PLACEHOLDER" ] || exit 0
strip_script=$(mktemp)
sed -n 's/.*"excludeExportTables":\[\(.*\)\].*/\1/p' "SQLFILE_PLACEHOLDER" | tr -d '"' | tr ',' '\n' |
    while read -r excluded_table; do
        [ -n "$excluded_table" ] || continue
        printf '/^DROP TABLE IF EXISTS `%s`;/,/^) ENGINE=/d\n' "$excluded_table" >> "$strip_script"
    done
sed -f "$strip_script" -e '/^---/d' -e 's/DEFAULT CHARSET=latin1/DEFAULT CHARSET=utf8mb4/' -e 's/ENGINE=MyISAM/ENGINE=InnoDB/' "SQLFILE_PLACEHOLDER"
rm -f "$strip_script"
'@
    $sqlScript = $sqlScript.Replace("SQLFILE_PLACEHOLDER", $sqlFile)
    $sqlScript | docker compose exec -i php sh -c "tr -d '\r' | sh" |
        docker compose exec -i db mysql `
            -u "$env:WADDLE_DB_USER" `
            -p"$env:WADDLE_DB_PASSWORD" `
            "{{public.website.db_name}}"
    if ($LASTEXITCODE -ne 0) { throw "Failed to create database tables from $sqlFile." }
}

# Bootstrap ProcessWire via CLI to configure the admin user and site title.
Write-Host "[WADDLE] Configuring admin account and site title."
$phpSetup = @'
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

// Rename the admin page to match Waddle's configured admin route. Unlike platforms with a real
// admin *directory* to rename, ProcessWire's admin panel is a database page in the regular page
// tree — its URL segment is that page's `name`, which defaults to "processwire" and is otherwise
// untouched by anything above, leaving the project list's admin-panel link (built from
// admin_route) pointing at a path that was never actually applied.
$adminPage = $wire->pages->get($wire->config->adminRootPageID);
$adminPage->of(false);
$adminPage->name = getenv('PW_ADMIN_ROUTE');
$adminPage->save();

echo "[WADDLE] Admin account and site title configured.\n";
'@
$phpSetup | docker compose exec -i `
    -e PW_ADMIN_USER="{{public.website.admin_username}}" `
    -e PW_ADMIN_PASS="$env:WADDLE_ADMIN_PASSWORD" `
    -e PW_ADMIN_EMAIL="{{public.website.admin_email}}" `
    -e PW_SITE_TITLE="{{public.website.title}}" `
    -e PW_ADMIN_ROUTE="{{public.website.admin_route}}" `
    php php
if ($LASTEXITCODE -ne 0) { throw "Failed to configure the admin account and site title." }

# Create installed marker to prevent the web installer from running.
Write-Host "[WADDLE] Marking installation as complete."
docker compose exec -T php sh -c "touch '{{project_path 'website/src'}}/site/assets/installed.php'"
if ($LASTEXITCODE -ne 0) { throw "Failed to mark installation as complete." }

# Remove the web installer entry point. ProcessWire's own bootstrap treats its mere presence as
# "not yet installed" and, on every request, re-attempts installer-only checks (including trying
# to write into site/modules/) regardless of the installed.php marker above.
Write-Host "[WADDLE] Removing web installer."
docker compose exec -T php rm -f "{{project_path 'website/src'}}/install.php"
if ($LASTEXITCODE -ne 0) { throw "Failed to remove the web installer." }

# Remove installer files.
docker compose exec -T php rm -rf "{{project_path 'website/src'}}/site/install"
if ($LASTEXITCODE -ne 0) { throw "Failed to remove the site profile's install data." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
