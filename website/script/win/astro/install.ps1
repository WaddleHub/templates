$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Astro's own scaffolder (create-astro), from its default starter
# (basics). `--ref` takes the starter from the Astro monorepo at the pinned version's tag, rather
# than from the newest release. Dependencies are installed below, at the pinned version, and
# website/src isn't made a git repository of its own, since Waddle lets users choose whether it
# is committed with the project (see the "Gitignore website src" option).
Write-Host "[WADDLE] Downloading the Astro starter."
docker compose exec -T node npx --yes create-astro@latest "{{project_path 'website/src'}}" `
    --template basics --ref "{{tags.website.version.full_raw}}" `
    --no-install --no-git --no-ai --skip-houston --yes
if ($LASTEXITCODE -ne 0) { throw "Failed to download the Astro starter." }

# Apply configuration: the site URL .env, and the astro.config.mjs reading it.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node cp "{{project_path 'website/conf/astro/.env'}}" "{{project_path 'website/src'}}/.env"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }
docker compose exec -T node cp "{{project_path 'website/conf/astro/astro.config.mjs'}}" "{{project_path 'website/src'}}/astro.config.mjs"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Install the dependencies, with Astro at the pinned version.
Write-Host "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm pkg set name="{{project_dirname}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to name the website package." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "astro@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies." }

# Add the Node adapter (@astrojs/node), at its newest version supporting the installed Astro.
$adapterVersion = docker compose exec -T -w "{{project_path 'website/src'}}" node `
    node "{{project_path 'website/conf/astro/adapter-version.cjs'}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to find a Node adapter version supporting Astro." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "@astrojs/node@$($adapterVersion.Trim())"
if ($LASTEXITCODE -ne 0) { throw "Failed to install the Node adapter." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Astro."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Astro." }

# Wait for Astro to answer, so the build only finishes once the site is up.
$healthCheck = "fetch('http://127.0.0.1:4321/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Astro..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Astro failed to start. See: docker compose logs node"
}
