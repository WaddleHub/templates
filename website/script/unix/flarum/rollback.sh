#!/bin/sh -eux

echo "[WADDLE] Starting website rollback."

if [ -f "./website/src/flarum" ]; then
    # Re-run migrations against the restored database to ensure the schema matches
    # the rolled-back code version. Flarum's migrate is idempotent — safe if the
    # DB restore already left it in sync.
    echo "[WADDLE] Running database migrations."
    docker compose exec -T php php "{{project_path 'website/src'}}/flarum" migrate

    echo "[WADDLE] Clearing caches."
    docker compose exec -T php php "{{project_path 'website/src'}}/flarum" cache:clear

    echo "[WADDLE] Taking site out of maintenance mode."
    docker compose exec -T php php "{{project_path 'website/src'}}/flarum" up
fi
