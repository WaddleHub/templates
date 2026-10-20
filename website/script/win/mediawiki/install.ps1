$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download MediaWiki source via git, its default skin and PHP dependencies, from inside the php
# container for accurate permissions. Skins are git submodules, not part of the core checkout, so a
# plain clone leaves skins/ empty and the wiki has no default skin (vector-2022) to render with.
# Afterwards, drop the git metadata, so the project's repository tracks website/src as plain files.
Write-Host "[WADDLE] Downloading source."
$installScript = @'
set -eux
git clone --depth=1 --branch={{tags.website.version.full_raw}} https://github.com/wikimedia/mediawiki.git "{{project_path 'website/src'}}/w"
git -C "{{project_path 'website/src'}}/w" submodule update --init --depth=1 -- skins/Vector
composer install --no-dev --working-dir="{{project_path 'website/src'}}/w"
find "{{project_path 'website/src'}}" -name .git -prune -exec rm -rf {} +
'@
$installScript | docker compose exec -i php sh -c "tr -d '\r' | sh"
if ($LASTEXITCODE -ne 0) { throw "Failed to download MediaWiki." }

# Run CLI installer.
Write-Host "[WADDLE] Executing installer."
docker compose exec -T php php "{{project_path 'website/src'}}/w/maintenance/install.php" `
    --dbname="{{public.website.db_name}}" `
    --dbuser="$env:WADDLE_DB_USER" `
    --dbpass="$env:WADDLE_DB_PASSWORD" `
    --dbserver=db `
    --server="{{website_url}}" `
    --scriptpath=/w `
    --lang="{{public.website.language}}" `
    --pass="$env:WADDLE_ADMIN_PASSWORD" `
    "{{public.website.title}}" `
    "{{public.website.admin_username}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to run the MediaWiki installer." }

# install.php has no option for the administrator's email address, so the account is created
# without one. Set it, marked as confirmed.
Write-Host "[WADDLE] Setting administrator email."
docker compose exec -T php php "{{project_path 'website/src'}}/w/maintenance/resetUserEmail.php" `
    --no-reset-password "{{public.website.admin_username}}" "{{public.website.admin_email}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to set the administrator email." }

# install.php also leaves the wiki's sender addresses empty (MediaWiki then falls back to
# apache@<server name>).
Write-Host "[WADDLE] Configuring mail sender."
$mailSettings = @'

# Mail sender, configured by Waddle.
$wgPasswordSender = '{{coalesce public.mail.from_email public.website.admin_email}}';
$wgEmergencyContact = '{{coalesce public.mail.from_email public.website.admin_email}}';
'@
# Strip the UTF-8 BOM PowerShell prepends to native stdin when the console encoding is UTF-8 (a BOM
# mid-file is a PHP parse error that takes the whole wiki down), and its trailing "\r\n".
$mailSettings | docker compose exec -i php sh -c "sed '1s/^\xef\xbb\xbf//' | tr -d '\r' >> '{{project_path 'website/src'}}/w/LocalSettings.php'"
if ($LASTEXITCODE -ne 0) { throw "Failed to configure the mail sender." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
