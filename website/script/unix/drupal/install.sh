#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Create source directory.
if [ ! -d "./website/src" ]; then
    mkdir -p "./website/src"
fi

docker compose exec -T php composer create-project \
    drupal/recommended-project:"{{tags.website.version.major}}.{{tags.website.version.minor}}.*" \
    "{{project_path 'website/src'}}" --no-interaction
