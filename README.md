# Waddle Templates

The [Handlebars](https://handlebarsjs.com/) templates [Waddle](https://waddlehub.com) uses to
generate projects. Docker Compose files, Dockerfiles, Nginx and PHP config, deploy
scripts and platform installers all start out as a template in this repository.

You don't need to clone this repository to use Waddle. Waddle keeps its own copy up to date, and
copies the templates a project needs into that project's `templates/` folder, where they're
rendered into the files your stack runs from.

## What's in here

The repository is organized by service, plus the files shared by the whole stack.

| Path | Contents |
|---|---|
| `docker-compose.yml`, `docker-compose.override.yml`, `docker-compose.prod.yml` | The base stack, the local development extras, and the remote server differences |
| `php/`, `nginx/`, `mariadb/`, `node/`, `redis/`, `opensearch/` | Each service's Dockerfile, config files and scripts |
| `composer/`, `phpmyadmin/` | Composer config and the local-only phpMyAdmin |
| `mail/`, `mailcatcher/`, `smtp/` | Outgoing mail, caught by MailCatcher locally and relayed over SMTP on remotes |
| `website/` | Install scripts and config for every supported blueprint (platform) |
| `bin/` | Deploy, rollback and backup scripts |
| `gitignore`, `gitattributes` | The project's `.gitignore` and `.gitattributes` |

Waddle ships installers for 29 platforms, from WordPress, Magento and Laravel to Strapi and
Next.js, plus two bare bases, `blank` and `webstack`.

## Template syntax

Templates use standard Handlebars, plus a set of custom helpers provided by Waddle. Each template
reads from one data object holding the project's settings and the versions Waddle resolved for its software stack.

```handlebars
{{#if public.redis.install}}
redis:
  image: {{integrity_hash 'redis/Dockerfile' project_dirname}}
{{/if}}
```

The full reference lives in the Waddle docs.

- [Handlebars Template Functions](https://waddlehub.com/docs/handlebars-template-functions.html),
  every custom helper with examples
- [Template Data](https://waddlehub.com/docs/handlebars-template-data.html), the data object every
  template can read from
- [The Public Data Object](https://waddlehub.com/docs/handlebars-data-public.html), each service's
  own settings
- [The Private Data Object](https://waddlehub.com/docs/handlebars-data-private.html), local-only
  data such as passwords and secrets

## How Waddle uses these templates

- [The Templates Repository](https://waddlehub.com/docs/templates.html) explains how Waddle picks
  the templates a project needs, and how your own changes survive template updates in the repo.
- [How Render and Build Work](https://waddlehub.com/docs/render-and-build.html) covers how
  templates become concrete files, and what happens when a project is built.
- [The Three Docker Compose Files](https://waddlehub.com/docs/docker-compose-files.html) explains
  how the local and remote stacks differ, and why they stay as close as possible.

## Using a fork

Waddle supports pointing your local templates repository at a fork of this one, if you want your
own changes to be the standard for all your projects. Waddle shows a warning when the repository's
`origin` doesn't match the official one. It's only a warning to guard against unintentional repo switches and can safely be ignored.

## License

MIT, see [LICENSE](https://github.com/WaddleHub/templates/blob/master/LICENSE).
