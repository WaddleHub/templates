#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

# Download WordPress source.
#
# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
echo "[WADDLE] Downloading source."
docker compose exec -T php "{{project_path 'bin'}}/wp" core download \
    --path="{{project_path 'website/src'}}" --version={{tags.website.version.full_raw}} --allow-root

# Copy custom configuration file to WordPress directory.
echo "[WADDLE] Applying configuration."
cp "./website/conf/wordpress/wp-config.php" "./website/src/wp-config.php"

# Run installer, if database is empty.
#
# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
echo "[WADDLE] Executing installer."
docker compose exec -T php "{{project_path 'bin'}}/wp" core install \
    --title="{{public.website.title}}" \
    --path="{{project_path 'website/src'}}" \
    --admin_email="{{public.website.admin_email}}" \
    --admin_user="{{public.website.admin_username}}" \
    --admin_password="${WADDLE_ADMIN_PASSWORD}" \
    --url={{public.website.url}} \
    --allow-root

# Correct permissions of WordPress configuration file.
echo "[WADDLE] Correcting insecure permissions."
chmod 644 "./website/src/wp-config.php"
{{#if (is_equal public.website.mod 'woocommerce')}}

# Install and activate the WooCommerce plugin (the "woocommerce" platform mod).
#
# --allow-root is acceptable and necessary since the intention is to run docker as rootless on
# remote servers and locally this flag has no impact either way.
echo "[WADDLE] Installing WooCommerce."
docker compose exec -T php "{{project_path 'bin'}}/wp" plugin install woocommerce --activate \
    --path="{{project_path 'website/src'}}" --allow-root

# New stores start in "Coming soon" mode, which hides the shop from visitors. Turn it off, since
# this is a local development site.
docker compose exec -T php "{{project_path 'bin'}}/wp" option update woocommerce_coming_soon no \
    --path="{{project_path 'website/src'}}" --allow-root
{{#if public.website.deploy_sample_data}}

# Import the sample products that ship with WooCommerce. WordPress Importer is only needed for the
# import, so it's removed again afterwards.
echo "[WADDLE] Installing sample data."
docker compose exec -T php "{{project_path 'bin'}}/wp" plugin install wordpress-importer --activate \
    --path="{{project_path 'website/src'}}" --allow-root

docker compose exec -T php "{{project_path 'bin'}}/wp" import \
    "{{project_path 'website/src'}}/wp-content/plugins/woocommerce/sample-data/sample_products.xml" \
    --authors=skip --path="{{project_path 'website/src'}}" --allow-root

docker compose exec -T php "{{project_path 'bin'}}/wp" plugin deactivate wordpress-importer --uninstall \
    --path="{{project_path 'website/src'}}" --allow-root
{{/if}}
{{/if}}

# wp-content/upgrade and wp-content/upgrade-temp-backup (core's own staging areas for the
# Dashboard's "Updates" page) don't ship in the download at all — unlike the rest of the
# daemon-owned list below, which ships as a real placeholder directory the chown can act on.
docker compose exec -T php mkdir -p \
    "{{project_path 'website/src'}}/wp-content/upgrade" \
    "{{project_path 'website/src'}}/wp-content/upgrade-temp-backup"

# Ensure that daemon-owned directories are owned by the unprivileged worker user (when docker
# is running in rootless mode).
echo "[WADDLE] Fixing permissions."
docker compose exec -T php sh -c 'if [ "$(id -u)" = 0 ] && [ $# -gt 0 ]; then chown -R {{get_daemon_user public.php.docker}}:{{get_daemon_group public.php.docker}} "$@"; fi' sh \
    {{#each (get_daemon_owned_dirs public.website.platform)}}"{{project_path 'website/src'}}/{{this}}" {{/each}}
