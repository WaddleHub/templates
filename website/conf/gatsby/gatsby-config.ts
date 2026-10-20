import type { GatsbyConfig } from "gatsby"
import { existsSync } from "fs"

// Gatsby doesn't load .env into its Node process (only `GATSBY_*` variables for the browser).
if (existsSync(`.env`)) {
  process.loadEnvFile(`.env`)
}

const config: GatsbyConfig = {
  siteMetadata: {
    siteUrl: process.env.SITE_URL,
  },
  graphqlTypegen: true,
  plugins: [],
}

export default config
