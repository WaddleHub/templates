#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Fetch and checkout the new version tag.
# echo "[WADDLE] Fetching new version."
# git -C "./website/src/w" fetch --depth=1 origin {{tags.website.version.full_raw}}
# git -C "./website/src/w" checkout {{tags.website.version.full_raw}}

# Update the default skin to the commit pinned by the new version.
# echo "[WADDLE] Updating default skin."
# git -C "./website/src/w" submodule update --init --depth=1 -- skins/Vector

# Update PHP dependencies.
echo "[WADDLE] Updating dependencies."
docker compose exec -T php composer install --no-dev --working-dir="{{project_path 'website/src'}}/w"

# Run database updates.
echo "[WADDLE] Running database updates."
docker compose exec -T php php "{{project_path 'website/src'}}/w/maintenance/update.php" --quick
