$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Next.js's own scaffolder (create-next-app) at the pinned version, which
# also pins Next.js itself to it. Dependencies are installed below, and website/src isn't made a git
# repository of its own, since Waddle lets users choose whether it is committed with the project
# (see the "Gitignore website src" option). userinfo-fallback.cjs lets it start as a user the
# container doesn't know by name (see that file).
Write-Host "[WADDLE] Scaffolding the Next.js starter."
docker compose exec -T `
    -e NODE_OPTIONS="--require={{project_path 'website/conf/nextjs/userinfo-fallback.cjs'}}" `
    node npx --yes "create-next-app@{{tags.website.version.raw}}" `
    "{{project_path 'website/src'}}" `
    --ts --tailwind --eslint --app --no-src-dir --import-alias "@/*" `
    --use-npm --skip-install --disable-git --no-agent-feedback --yes
if ($LASTEXITCODE -ne 0) { throw "Failed to scaffold the Next.js starter." }

# Apply configuration: the site URL .env, and next.config.ts reading it.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node cp "{{project_path 'website/conf/nextjs/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T -w "{{project_path 'website/src'}}" node `
    node "{{project_path 'website/conf/nextjs/allow-site-host.cjs'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Install the dependencies.
Write-Host "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to name the website package." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund
if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Next.js."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Next.js." }

# Wait for Next.js to answer, so the build only finishes once the site is up. Its dev server
# compiles a page on its first request.
$healthCheck = "fetch('http://127.0.0.1:3000/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Next.js..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Next.js failed to start. See: docker compose logs node"
}
