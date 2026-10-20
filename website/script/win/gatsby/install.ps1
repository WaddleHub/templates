$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Fetch the starter. We avoid Gatsby's standard scaffolder (create-gatsby), since it clones its
# starter's unversioned default branch and makes the website a git repository of its own. Waddle
# installs the Gatsby version the user picked, and lets them choose whether website/src is
# committed with the project (see the "Gitignore website src" option). So the same starter
# (minimal, TypeScript) is taken from the Gatsby monorepo at the pinned version's tag instead,
# through a sparse clone that downloads that directory only.
#
# Arguments go straight to docker rather than through `sh -c`, since PowerShell mangles the double
# quotes such a script would need.
Write-Host "[WADDLE] Downloading the Gatsby starter."
docker compose exec -T node rm -rf /tmp/gatsby-repo
if ($LASTEXITCODE -ne 0) { throw "Failed to download the Gatsby starter." }
docker compose exec -T node git clone --quiet --depth 1 --filter=blob:none --sparse `
    --branch "{{tags.website.version.full_raw}}" https://github.com/gatsbyjs/gatsby.git /tmp/gatsby-repo
if ($LASTEXITCODE -ne 0) { throw "Failed to download the Gatsby starter." }
docker compose exec -T node git -C /tmp/gatsby-repo sparse-checkout set --no-cone `
    /starters/gatsby-starter-minimal-ts/
if ($LASTEXITCODE -ne 0) { throw "Failed to download the Gatsby starter." }
docker compose exec -T node mkdir -p "{{project_path 'website/src'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to create the website directory." }
docker compose exec -T node cp -a /tmp/gatsby-repo/starters/gatsby-starter-minimal-ts/. `
    "{{project_path 'website/src'}}/"
if ($LASTEXITCODE -ne 0) { throw "Failed to copy the Gatsby starter." }
docker compose exec -T node rm -rf /tmp/gatsby-repo
if ($LASTEXITCODE -ne 0) { throw "Failed to clean up the Gatsby starter download." }

# Apply configuration: the site URL .env, and the starter's gatsby-config.ts reading it.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node cp "{{project_path 'website/conf/gatsby/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/gatsby/gatsby-config.ts'}}" "{{project_path 'website/src'}}/gatsby-config.ts"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Install the dependencies, with Gatsby at the pinned version.
Write-Host "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to name the website package." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "gatsby@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Gatsby."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Gatsby." }

# Wait for Gatsby to answer, so the build only finishes once the site is up. The first start
# bootstraps the site and builds its development bundle.
$healthCheck = "fetch('http://127.0.0.1:8000/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Gatsby..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Gatsby failed to start. See: docker compose logs node"
}
