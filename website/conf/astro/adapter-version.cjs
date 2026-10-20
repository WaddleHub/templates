// This script resolves which version of the Node adapter (@astrojs/node) goes with the configured
// version of Astro.
//
// Each adapter version only works with one Astro major version, e.g. adapter 8 with Astro 4 and
// adapter 9 with Astro 5. Installing the adapter without a version always gets the newest one,
// which fails on an older Astro. So this looks up every adapter version, keeps those that work
// with the installed Astro, and prints the newest of them. The install and upgrade scripts then
// install that version.
const { createRequire } = require('node:module');

// Resolve packages from the website (semver comes with Astro), not from this file's directory.
const websiteRequire = createRequire(`${process.cwd()}/`);
const semver = websiteRequire('semver');
const astro = websiteRequire('astro/package.json').version;

fetch('https://registry.npmjs.org/@astrojs/node')
  .then((response) => response.json())
  .then((adapter) => {
    const versions = Object.keys(adapter.versions).filter(
      (version) =>
        !semver.prerelease(version) &&
        semver.satisfies(astro, adapter.versions[version].peerDependencies?.astro ?? '*'),
    );
    const version = semver.maxSatisfying(versions, '*');

    if (!version) {
      console.error(`No @astrojs/node version supports Astro ${astro}.`);
      process.exit(1);
    }

    console.log(version);
  });
