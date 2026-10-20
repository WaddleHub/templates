#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Nest's own CLI (`nest new`), at the pinned major version, since each
# CLI major scaffolds a starter for its own Nest major.
echo "[WADDLE] Scaffolding the Nest starter."
docker compose exec -T node npx --yes "@nestjs/cli@{{tags.website.version.major}}" new \
    "{{project_dirname}}" --directory "{{project_path 'website/src'}}" \
{{#if (version_compare tags.website.version.raw '>=' '12.0.0')}}
    --no-observe \
{{/if}}
    --package-manager npm --skip-install --skip-git

# `--skip-git` also skips the .gitignore Nest's CLI writes, so add it: the same file, which keeps
# the dependencies and the build out of git.
echo "[WADDLE] Applying configuration."
cp "./website/conf/nest/.gitignore" "./website/src/.gitignore"

# Install dependencies.
echo "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "@nestjs/common@{{tags.website.version.raw}}" \
    "@nestjs/core@{{tags.website.version.raw}}" \
    "@nestjs/platform-express@{{tags.website.version.raw}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    --save-dev "@nestjs/testing@{{tags.website.version.raw}}"

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Nest."
docker compose restart node

# Wait for Nest to answer, so the build only finishes once the site is up. Its dev server compiles
# the website first.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:3000/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Nest..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Nest failed to start. See: docker compose logs node"
    exit 1
fi
