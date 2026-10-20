import type { Core } from '@strapi/strapi';

// Based on Strapi's own config/server.ts (create-strapi-app templates/vanilla), plus `url` and
// `proxy`: Waddle serves Strapi through nginx, so Strapi needs its public URL for absolute URLs
// (admin panel, media), and must trust nginx's X-Forwarded-* headers to know the request came in
// over https (secure session cookies).
const config = ({ env }: Core.Config.Shared.ConfigParams): Core.Config.Server => ({
  host: env('HOST', '0.0.0.0'),
  port: env.int('PORT', 1337),
  url: env('PUBLIC_URL', ''),
  proxy: { koa: env.bool('IS_PROXIED', true) },
  app: {
    keys: env.array('APP_KEYS')!,
  },
  webhooks: {
    populateRelations: env.bool('WEBHOOKS_POPULATE_RELATIONS', false),
  },
});

export default config;
