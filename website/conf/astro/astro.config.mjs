// @ts-check
import { defineConfig } from 'astro/config';
import node from '@astrojs/node';
import { existsSync } from 'node:fs';

// Astro doesn't load .env into its config (only into the website code's `import.meta.env`).
if (existsSync('.env')) {
  process.loadEnvFile('.env');
}

const siteUrl = URL.parse(process.env.SITE_URL ?? '');

export default defineConfig({
  site: siteUrl?.href,
  adapter: node({
    mode: 'standalone',
  }),
  server: {
    // nginx reaches the node container over the network, on this port. Used by the dev server
    // and, from the build, by the standalone server.
    host: true,
    port: 4321,
    // The dev server only answers the hosts listed here. nginx only passes the project's own
    // domains on, so it can answer any.
    allowedHosts: true,
  },
  security: {
    // Trust nginx's X-Forwarded-Host and -Proto for the site's own domain, so `Astro.url` holds
    // the public URL rather than the node container's.
    allowedDomains: siteUrl
      ? [{ hostname: siteUrl.hostname, protocol: siteUrl.protocol.slice(0, -1) }]
      : [],
  },
});
