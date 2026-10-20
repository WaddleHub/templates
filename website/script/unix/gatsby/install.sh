#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Fetch the starter. We avoid Gatsby's standard scaffolder (create-gatsby), since it clones its
# starter's unversioned default branch and makes the website a git repository of its own. Waddle
# installs the Gatsby version the user picked, and lets them choose whether website/src is
# committed with the project (see the "Gitignore website src" option). So the same starter
# (minimal, TypeScript) is taken from the Gatsby monorepo at the pinned version's tag instead,
# through a sparse clone that downloads that directory only.
echo "[WADDLE] Downloading the Gatsby starter."
docker compose exec -T node rm -rf /tmp/gatsby-repo
docker compose exec -T node git clone --quiet --depth 1 --filter=blob:none --sparse \
    --branch "{{tags.website.version.full_raw}}" https://github.com/gatsbyjs/gatsby.git /tmp/gatsby-repo
docker compose exec -T node git -C /tmp/gatsby-repo sparse-checkout set --no-cone \
    /starters/gatsby-starter-minimal-ts/
docker compose exec -T node mkdir -p "{{project_path 'website/src'}}"
docker compose exec -T node cp -a /tmp/gatsby-repo/starters/gatsby-starter-minimal-ts/. \
    "{{project_path 'website/src'}}/"
docker compose exec -T node rm -rf /tmp/gatsby-repo

# Apply configuration: the site URL .env, and the starter's gatsby-config.ts reading it.
echo "[WADDLE] Applying configuration."
cp "./website/conf/gatsby/.env" "./website/src/.env"
cp "./website/conf/gatsby/gatsby-config.ts" "./website/src/gatsby-config.ts"

# Install the dependencies, with Gatsby at the pinned version.
echo "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "gatsby@{{tags.website.version.raw}}"

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Gatsby."
docker compose restart node

# Wait for Gatsby to answer, so the build only finishes once the site is up. The first start
# bootstraps the site and builds its development bundle.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:8000/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Gatsby..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Gatsby failed to start. See: docker compose logs node"
    exit 1
fi
