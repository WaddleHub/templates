#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

PHPBB_SRC_CONTAINER="{{project_path 'website/src'}}/phpBB"

# Fetch tags and check out the target version.
# echo "[WADDLE] Updating phpBB source."
# git -C "./website/src" fetch --tags
# git -C "./website/src" checkout {{tags.website.version.full_raw}}

# Update PHP dependencies.
echo "[WADDLE] Updating dependencies."
docker compose exec -T php composer install --no-dev \
    --working-dir="${PHPBB_SRC_CONTAINER}"

# Run database migrations.
echo "[WADDLE] Running database migrations."
docker compose exec -T php php "${PHPBB_SRC_CONTAINER}/bin/phpbbcli.php" db:migrate \
    --safe-mode

# Clear compiled templates and cache.
echo "[WADDLE] Clearing cache."
docker compose exec -T php php "${PHPBB_SRC_CONTAINER}/bin/phpbbcli.php" cache:purge
