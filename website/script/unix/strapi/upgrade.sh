#!/bin/sh -eux

echo "[WADDLE NOTICE] Starting website upgrade."

# Strapi's own upgrade tool updates every @strapi package to the target release and runs its
# codemods. Strapi migrates the database when it starts on the new release, after the restart below.
echo "[WADDLE] Upgrading Strapi."
docker compose exec -T -w "{{project_path 'website/src'}}" node npx --yes @strapi/upgrade to "{{tags.website.version.raw}}" --yes

echo "[WADDLE] Updating the email provider."
docker compose exec -T -w "{{project_path 'website/src'}}" node npm install --no-audit --no-fund \
    "@strapi/provider-email-nodemailer@{{tags.website.version.raw}}"

echo "[WADDLE] Restarting Strapi."
docker compose restart node
