$ErrorActionPreference = "Stop"

Write-Host "[WADDLE NOTICE] Starting website installation."

# Download TYPO3 via Composer.
Write-Host "[WADDLE] Downloading source."
docker compose exec -T php composer create-project "typo3/cms-base-distribution:^{{tags.website.version.major}}.0" `
    "{{project_path 'website/src'}}" --no-interaction
if ($LASTEXITCODE -ne 0) { throw "Failed to download TYPO3." }

# Ensure public directory exists and mark as fresh install.
docker compose exec -T php sh -c "mkdir -p '{{project_path 'website/src'}}/public' && touch '{{project_path 'website/src'}}/public/FIRST_INSTALL'"
if ($LASTEXITCODE -ne 0) { throw "Failed to create FIRST_INSTALL marker." }

# Run CLI installer. installer.ps1 only runs this script for a fresh install, so the database is
# empty here.
Write-Host "[WADDLE] Running TYPO3 setup."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" setup `
    --driver=mysqli `
    --host=db `
    --port=3306 `
    --dbname="{{public.website.db_name}}" `
    --username="$env:WADDLE_DB_USER" `
    --password="$env:WADDLE_DB_PASSWORD" `
    --admin-username="{{public.website.admin_username}}" `
    --admin-user-password="$env:WADDLE_ADMIN_PASSWORD" `
    --admin-email="{{public.website.admin_email}}" `
    --project-name="{{public.website.title}}" `
    --create-site="{{website_url}}" `
    --server-type=other `
    --no-interaction `
    --force
if ($LASTEXITCODE -ne 0) { throw "Failed to run TYPO3 setup." }

Write-Host "[WADDLE] Flushing cache."
docker compose exec -T php "{{project_path 'website/src'}}/vendor/bin/typo3" cache:flush
if ($LASTEXITCODE -ne 0) { throw "Failed to flush cache." }
