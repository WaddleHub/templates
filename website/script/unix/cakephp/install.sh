#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

docker compose exec -T php composer create-project --prefer-dist cakephp/app \
    "{{project_path 'website/src'}}" "{{tags.website.version.major}}.{{tags.website.version.minor}}.*" --no-interaction

# Replace the skeleton's config/app_local.php (placeholder database credentials and mail transport)
# with Waddle's rendered one.
echo "[WADDLE] Applying configuration."
cp "./website/conf/cakephp/app_local.php" "./website/src/config/app_local.php"
