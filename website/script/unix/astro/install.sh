#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Astro's own scaffolder (create-astro), from its default starter
# (basics). `--ref` takes the starter from the Astro monorepo at the pinned version's tag, rather
# than from the newest release. Dependencies are installed below, at the pinned version, and
# website/src isn't made a git repository of its own, since Waddle lets users choose whether it
# is committed with the project (see the "Gitignore website src" option).
echo "[WADDLE] Downloading the Astro starter."
docker compose exec -T node npx --yes create-astro@latest "{{project_path 'website/src'}}" \
    --template basics --ref "{{tags.website.version.full_raw}}" \
    --no-install --no-git --no-ai --skip-houston --yes

# Apply configuration: the site URL .env, and the astro.config.mjs reading it.
echo "[WADDLE] Applying configuration."
cp "./website/conf/astro/.env" "./website/src/.env"
cp "./website/conf/astro/astro.config.mjs" "./website/src/astro.config.mjs"

# Install the dependencies, with Astro at the pinned version.
echo "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "astro@{{tags.website.version.raw}}"

# Add the Node adapter (@astrojs/node), at its newest version supporting the installed Astro.
ADAPTER_VERSION="$(docker compose exec -T -w "{{project_path 'website/src'}}" node \
    node "{{project_path 'website/conf/astro/adapter-version.cjs'}}")"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "@astrojs/node@${ADAPTER_VERSION}"

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Astro."
docker compose restart node

# Wait for Astro to answer, so the build only finishes once the site is up.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:4321/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Astro..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Astro failed to start. See: docker compose logs node"
    exit 1
fi
