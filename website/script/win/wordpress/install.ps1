$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if (-not (Test-Path ./website/src -PathType Container)) {
    New-Item -ItemType Directory -Path ./website/src -Force | Out-Null
}

# Download WordPress source.
#
# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
Write-Host "[WADDLE] Downloading source."
docker compose exec -T php "{{project_path 'bin'}}/wp" core download `
    --path="{{project_path 'website/src'}}" --version={{tags.website.version.full_raw}} --allow-root
if ($LASTEXITCODE -ne 0) { throw "Failed to download WordPress." }

# Copy custom configuration file to WordPress directory.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T php cp "{{project_path 'website/conf/wordpress/wp-config.php'}}" "{{project_path 'website/src'}}/wp-config.php"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Run installer.
#
# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
Write-Host "[WADDLE] Executing installer."
docker compose exec -T php "{{project_path 'bin'}}/wp" core install `
    --title="{{public.website.title}}" `
    --path="{{project_path 'website/src'}}" `
    --admin_email="{{public.website.admin_email}}" `
    --admin_user="{{public.website.admin_username}}" `
    --admin_password="$env:WADDLE_ADMIN_PASSWORD" `
    --url={{public.website.url}} `
    --allow-root
if ($LASTEXITCODE -ne 0) { throw "Failed to run the WordPress installer." }

# Correct permissions of WordPress configuration file.
Write-Host "[WADDLE] Correcting insecure permissions."
docker compose exec -T -u 0 php chmod 644 "{{project_path 'website/src'}}/wp-config.php"
if ($LASTEXITCODE -ne 0) { throw "Failed to correct wp-config.php permissions." }
{{#if (is_equal public.website.mod 'woocommerce')}}

# Install and activate the WooCommerce plugin (the "woocommerce" platform mod).
#
# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
Write-Host "[WADDLE] Installing WooCommerce."
docker compose exec -T php "{{project_path 'bin'}}/wp" plugin install woocommerce --activate `
    --path="{{project_path 'website/src'}}" --allow-root
if ($LASTEXITCODE -ne 0) { throw "Failed to install WooCommerce." }
{{/if}}

# wp-content/upgrade and wp-content/upgrade-temp-backup (core's own staging areas for the
# Dashboard's "Updates" page) don't ship in the download at all — unlike the rest of the
# daemon-owned list below, which ships as a real placeholder directory the chown can act on.
docker compose exec -T php mkdir -p `
    "{{project_path 'website/src'}}/wp-content/upgrade" `
    "{{project_path 'website/src'}}/wp-content/upgrade-temp-backup"
if ($LASTEXITCODE -ne 0) { throw "Failed to create wp-content upgrade directories." }

# Ensure that daemon-owned directories are owned by the unprivileged worker user.
# Skipped when the php container doesn't run as root (the default on Windows), since its workers
# then already run as the installing user. Avoid double quotes inside the sh -c script since
# PowerShell mangles them when passing arguments to docker.
Write-Host "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ $(id -u) = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} $@; fi' sh `
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
if ($LASTEXITCODE -ne 0) { throw "Failed to fix permissions." }
