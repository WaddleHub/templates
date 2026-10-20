#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Next.js's own scaffolder (create-next-app) at the pinned version, which
# also pins Next.js itself to it. Dependencies are installed below, and website/src isn't made a git
# repository of its own, since Waddle lets users choose whether it is committed with the project
# (see the "Gitignore website src" option). userinfo-fallback.cjs lets it start as a user the
# container doesn't know by name (see that file).
echo "[WADDLE] Scaffolding the Next.js starter."
docker compose exec -T \
    -e NODE_OPTIONS="--require={{project_path 'website/conf/nextjs/userinfo-fallback.cjs'}}" \
    node npx --yes "create-next-app@{{tags.website.version.raw}}" \
    "{{project_path 'website/src'}}" \
    --ts --tailwind --eslint --app --no-src-dir --import-alias "@/*" \
    --use-npm --skip-install --disable-git --no-agent-feedback --yes

# Apply configuration: the site URL .env, and next.config.ts reading it.
echo "[WADDLE] Applying configuration."
cp "./website/conf/nextjs/.env" "./website/src/.env"
docker compose exec -T -w "{{project_path 'website/src'}}" node \
    node "{{project_path 'website/conf/nextjs/allow-site-host.cjs'}}"

# Install the dependencies.
echo "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
echo "[WADDLE] Starting Next.js."
docker compose restart node

# Wait for Next.js to answer, so the build only finishes once the site is up. Its dev server
# compiles a page on its first request.
waitCount=180

while [ "${waitCount}" != "0" ] && ! docker compose exec -T node \
    node -e "fetch('http://127.0.0.1:3000/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"; do
    echo "[WADDLE] Waiting for Next.js..."
    waitCount=$((waitCount - 1))
    sleep 1
done

if [ "${waitCount}" = "0" ]; then
    echo "[WADDLE ERROR] Next.js failed to start. See: docker compose logs node"
    exit 1
fi
