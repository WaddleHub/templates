#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

docker compose exec -T php "{{project_path 'website/src'}}/bin/gpm" selfupgrade -f
docker compose exec -T php "{{project_path 'website/src'}}/bin/gpm" update
