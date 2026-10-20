// Adds the site's own host to `allowedDevOrigins` in the website's next.config.ts, keeping
// everything create-next-app put there. The dev server only serves its resources (`/_next/*`, and
// the hot reload WebSocket) to pages on localhost and *.localhost unless told to allow other hosts.
// The host comes from SITE_URL in .env, which Next.js loads before next.config.ts.
//
// Run from the website's directory: node allow-site-host.cjs
const fs = require('node:fs');

const file = 'next.config.ts';
const exportLine = 'export default nextConfig;';
const addition = `// Allow the site's own host (SITE_URL in .env) to use the dev server's resources.
const siteHost = URL.parse(process.env.SITE_URL ?? "")?.hostname;

if (siteHost) {
  nextConfig.allowedDevOrigins = [...(nextConfig.allowedDevOrigins ?? []), siteHost];
}

`;

const config = fs.readFileSync(file, 'utf8');

if (config.includes('const siteHost')) {
  process.exit(0);
}

if (!config.includes(exportLine)) {
  console.error(`${file} has no "${exportLine}" line to add the site's host before.`);
  process.exit(1);
}

fs.writeFileSync(file, config.replace(exportLine, addition + exportLine));
