#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Fetch tags and check out the target version.
# echo "[WADDLE] Updating Kanboard source."
# git -C "./website/src" fetch --tags
# git -C "./website/src" checkout {{tags.website.version.full_raw}}

# Preserve the config.php across the checkout.
echo "[WADDLE] Re-applying configuration."
cp "./website/conf/kanboard/config.php" "./website/src/config.php"

# Run any pending database migrations.
echo "[WADDLE] Running database migrations."
docker compose exec -T php php "{{project_path 'website/src'}}/cli" db:migrate

# Clear cached assets.
echo "[WADDLE] Clearing cache."
rm -rf "./website/src/data/cache/"*
