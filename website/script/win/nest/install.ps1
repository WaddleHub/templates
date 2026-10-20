$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Scaffold the website with Nest's own CLI (`nest new`), at the pinned major version, since each
# CLI major scaffolds a starter for its own Nest major.
Write-Host "[WADDLE] Scaffolding the Nest starter."
docker compose exec -T node npx --yes "@nestjs/cli@{{tags.website.version.major}}" new `
    "{{project_dirname}}" --directory "{{project_path 'website/src'}}" `
{{#if (version_compare tags.website.version.raw '>=' '12.0.0')}}
    --no-observe `
{{/if}}
    --package-manager npm --skip-install --skip-git
if ($LASTEXITCODE -ne 0) { throw "Failed to scaffold the Nest starter." }

# `--skip-git` also skips the .gitignore Nest's CLI writes, so add it: the same file, which keeps
# the dependencies and the build out of git.
Write-Host "[WADDLE] Applying configuration."
docker compose exec -T node cp "{{project_path 'website/conf/nest/.gitignore'}}" "{{project_path 'website/src'}}/.gitignore"
if ($LASTEXITCODE -ne 0) { throw "Failed to apply configuration." }

# Install dependencies.
Write-Host "[WADDLE] Installing dependencies."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    "@nestjs/common@{{tags.website.version.raw}}" `
    "@nestjs/core@{{tags.website.version.raw}}" `
    "@nestjs/platform-express@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies." }
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund `
    --save-dev "@nestjs/testing@{{tags.website.version.raw}}"
if ($LASTEXITCODE -ne 0) { throw "Failed to install dependencies." }

# Restart the node service, which now finds the website and starts it (see node/script/run.sh).
Write-Host "[WADDLE] Starting Nest."
docker compose restart node
if ($LASTEXITCODE -ne 0) { throw "Failed to start Nest." }

# Wait for Nest to answer, so the build only finishes once the site is up. Its dev server compiles
# the website first.
$healthCheck = "fetch('http://127.0.0.1:3000/').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))"

for ($waitCount = 180; $waitCount -gt 0; $waitCount--) {
    docker compose exec -T node node -e $healthCheck
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "[WADDLE] Waiting for Nest..."
    Start-Sleep -Seconds 1
}

if ($waitCount -eq 0) {
    throw "Nest failed to start. See: docker compose logs node"
}
