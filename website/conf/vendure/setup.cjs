// Creates the shop's database schema and its initial data, the way Vendure's own scaffolder
// (@vendure/create) does at the end of creating a project. It generates the first migration and
// runs it, then imports the initial data (countries, zones, taxes, shipping and payment methods)
// and, optionally, the sample products.
//
// Run from the website's directory:
//   node setup.cjs <@vendure/create assets directory> <import sample products: true/false>
const path = require('node:path');
const { createRequire } = require('node:module');

const [assetsDir, withProducts] = process.argv.slice(2);
const cwd = process.cwd();
// Load Vendure, and the website's TypeScript config, from the website rather than from this file.
const websiteRequire = createRequire(path.join(cwd, 'package.json'));

websiteRequire('ts-node').register({ project: path.join(cwd, 'tsconfig.json'), transpileOnly: true });

const { bootstrap, generateMigration, runMigrations, JobQueueService, DefaultLogger, LogLevel } =
  websiteRequire('@vendure/core');
const { populate } = websiteRequire('@vendure/core/cli');
const { config } = websiteRequire('./src/vendure-config');

async function setup() {
  // Fail on errors rather than logging them and carrying on.
  process.env.VENDURE_RUNNING_IN_CLI = 'true';
  const migration = await generateMigration(config, {
    name: 'init',
    outputDir: path.join(cwd, 'src/migrations'),
  });

  if (!migration) {
    throw new Error('Failed to generate the initial database migration.');
  }

  await runMigrations(config);
  delete process.env.VENDURE_RUNNING_IN_CLI;

  const app = await populate(
    async () => {
      const app = await bootstrap({
        ...config,
        logger: new DefaultLogger({ level: LogLevel.Warn }),
        importExportOptions: { importAssetsDir: path.join(assetsDir, 'images') },
      });
      await app.get(JobQueueService).start();

      return app;
    },
    path.join(assetsDir, 'initial-data.json'),
    withProducts === 'true' ? path.join(assetsDir, 'products.csv') : undefined,
  );

  // Give the job queue time to finish (the search index), as @vendure/create does.
  await new Promise(resolve => setTimeout(resolve, 30000));
  await app.close();
}

setup().then(
  () => process.exit(0),
  error => {
    console.error(error);
    process.exit(1);
  },
);
